impl run_to_log(
    in_path: str, log_path: str, run: Callable[[any, Callable[[str, str], None]], any]
) {
    with open(in_path) as f {
        input: any = json.loads(f.read());
    }
    log = open(log_path, "a");

    def write(item: dict[str, any]) {
        log.write(json.dumps(item) + "\n");
        log.flush();
    }

    try {
        write({
            "result": run(input, lambda (phase: str, text: str) { write({"note": [phase, text]}) }),
        });
    } except Exception as e {
        write({"error": type(e).__name__ + ": " + str(e)});
    }
    log.close();
}

impl ProcessJobs.postinit {
    self.runs = {};
    self.made = 0;
    self.host = None;
}

impl ProcessJobs.open(host: dyn JobsHost) {
    self.host = host;
}

impl ProcessJobs.program -> dyn JobsHost {
    host = self.host;
    if host is None {
        raise RuntimeError("process_jobs was asked before it was opened");
    }
    return host;
}

impl ProcessJobs.start(name: str, input: any) -> str {
    program = self.program();
    d = self.dir if self.dir != "" else os.path.join(program.data_dir(), "jobs");
    os.makedirs(d, exist_ok=True);
    self.made += 1;
    id = f"{name}-{os.getpid()}-{self.made}";
    stem = os.path.join(d, id);
    in_path = stem + ".in.json";
    log_path = stem + ".log";
    with open(in_path, "w") as f {
        f.write(json.dumps(input));
    }
    proc = subprocess.Popen(
        program.command() + ["--job", program.owner() or "-", name, in_path, log_path]
    );
    self.runs[id] = Run(proc=proc, in_path=in_path, log_path=log_path);
    return id;
}

impl ProcessJobs.read(id: str) -> JobState {
    st = JobState();
    if id not in self.runs {
        st.done = True;
        st.failed = "no such job";
        return st;
    }
    r = self.runs[id];
    code = r.proc.poll();
    if os.path.exists(r.log_path) {
        with open(r.log_path, "rb") as f {
            f.seek(r.seen);
            data: bytes = f.read();
        }
        end = data.rfind(b"\n");
        if end >= 0 {
            r.seen += end + 1;
            for line in data[:end].decode("utf-8").split("\n") {
                item: dict[str, any] = json.loads(line);
                if "note" in item {
                    n: list[any] = item["note"];
                    st.notes.append((str(n[0]), str(n[1])));
                } elif "result" in item {
                    r.result = item["result"];
                    r.ended = True;
                } else {
                    r.failed = str(item["error"]);
                    r.ended = True;
                }
            }
        }
    }
    if code is None {
        return st;
    }
    st.done = True;
    st.result = r.result;
    st.failed = r.failed if r.ended else "the job exited with " + str(code);
    for path in [r.in_path, r.log_path] {
        if os.path.exists(path) {
            os.remove(path);
        }
    }
    del self.runs[id];
    return st;
}

impl ProcessJobs.work -> bool {
    if len(sys.argv) != 6 or sys.argv[1] != "--job" {
        return False;
    }
    owner = sys.argv[2];
    name = sys.argv[3];
    program = self.program();
    run_to_log(
        sys.argv[4],
        sys.argv[5],
        lambda (input: any, note: Callable[[str, str], None]) -> any {
            if owner == "-" {
                return program.run(name, input, note);
            }
            return program.run_space(owner, name, input, note);
        },
    );
    return True;
}
