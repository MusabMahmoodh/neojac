impl parse_request(buf: bytes) -> Request | None {
    if b"\r\n\r\n" not in buf {
        if len(buf) > MAX_HEAD {
            raise Refused(status=431, detail="the request's head is too large");
        }
        return None;
    }
    at = buf.index(b"\r\n\r\n");
    if at > MAX_HEAD {
        raise Refused(status=431, detail="the request's head is too large");
    }
    head = buf[0:at].decode("latin-1").split("\r\n");
    first = head[0].split(" ");
    if len(first) != 3 or not first[1].startswith("/") or not first[2].startswith("HTTP/1.") {
        raise Refused(status=400, detail="a malformed request line");
    }
    headers: dict[str, str] = {};
    for line in head[1:len(head)] {
        (k, colon, v) = line.partition(":");
        if colon == "" or k.strip() == "" {
            raise Refused(status=400, detail="a malformed header");
        }
        headers[k.strip().lower()] = v.strip();
    }
    if "transfer-encoding" in headers {
        if headers["transfer-encoding"].lower() == "chunked" {
            raise Refused(status=411, detail="a body is read by its Content-Length, not in chunks");
        }
        raise Refused(status=501, detail="a body is read by its Content-Length alone");
    }
    length = headers.get("content-length", "0");
    if re.fullmatch("[0-9]{1,18}", length) is None {
        raise Refused(status=400, detail="a malformed Content-Length");
    }
    need = int(length);
    if need > MAX_BODY {
        raise Refused(status=413, detail="the request's body is too large");
    }
    body = buf[at + 4:len(buf)];
    if len(body) < need {
        return None;
    }
    (path, _, query) = first[1].partition("?");
    return Request(method=first[0], path=path, query=query, headers=headers, body=body[0:need]);
}

impl reads_interim(buf: bytes) -> bool {
    return not buf[0:buf.index(b"\r\n")].endswith(b" HTTP/1.0");
}

impl write_response(conn: any, r: Response, head_only: bool = False) {
    pieces = r.pieces;
    length = r.length if r.length >= 0 else len(r.body);
    lines = [
        "HTTP/1.1 " + str(r.status) + " " + http.client.responses.get(r.status, ""),
        "Content-Type: " + r.ctype,
        "Content-Length: " + str(length),
        "Connection: close",
    ];
    for (k, v) in r.headers.items() {
        lines.append(k + ": " + v);
    }
    head = ("\r\n".join(lines) + "\r\n\r\n").encode("latin-1");
    if head_only {
        conn.sendall(head);
    } elif pieces is None {
        conn.sendall(head + r.body);
    } else {
        conn.sendall(head);
        try {
            for piece in pieces {
                conn.sendall(piece);
            }
        } finally {
            pieces.close();
        }
    }
}

impl respond(handle: Callable[[Request], Response], req: Request) -> Response {
    try {
        return handle(req);
    } except Exception as e {
        print("request " + req.path + " failed: " + str(e));
        return json_fail(500, "failed", "the server failed to answer");
    }
}

impl client_of(headers: dict[str, str], peer: str, named: str) -> str {
    if named == "" or named not in headers {
        return peer;
    }
    try {
        return str(ipaddress.ip_address(headers[named].strip()));
    } except ValueError {
        return peer;
    }
}

impl Calls.take(descriptor: int, request: bytes) {
    with self.turn {
        self.tickets += 1;
        self.held[self.tickets] = request;
        self.queued.append(descriptor);
        self.queued.append(self.tickets);
        self.open += 1;
        if self.open > self.threads and self.threads < MAX_CALLS {
            self.threads += 1;
            threading.Thread(target=self.work, daemon=True).start();
        } else {
            self.turn.notify();
        }
    }
}

impl Calls.settle {
    with self.turn {
        for ticket in self.read {
            del self.held[ticket];
        }
        self.read.clear();
    }
}

impl Calls.answered {
    with self.turn {
        self.open -= 1;
    }
}

impl Calls.work {
    forever {
        descriptor = -1;
        ticket = 0;
        with self.turn {
            while len(self.queued) == 0 {
                if not self.turn.wait(IDLE_SECONDS) and len(self.queued) == 0 {
                    self.threads -= 1;
                    return;
                }
            }
            descriptor = self.queued.pop(0);
            ticket = self.queued.pop(0);
        }
        conn = socket.socket(fileno=descriptor);
        conn.settimeout(10.0);
        req: Request | None = None;
        interim = True;
        try {
            req = parse_request(self.held[ticket]);
            interim = reads_interim(self.held[ticket]);
            if req is not None {
                req.client = client_of(req.headers, str(conn.getpeername()[0]), self.client_header);
            }
        } except Exception as e {
            print("request failed: " + str(e));
        }
        with self.turn {
            self.read.append(ticket);
        }
        if req is None {
            self.answered();
            conn.close();
        } else {
            self.answer(conn, req, interim);
        }
    }
}

impl answer_on(
    conn: any,
    req: Request,
    interim: bool,
    handle: Callable[[Request], Response],
    sending: dict[int, Sending],
    calls: Calls,
) {
    told = False;
    try {
        waiting = Sending(conn=conn, turn=threading.Lock(), last=time.time(), interim=True);
        if interim {
            sending[id(waiting)] = waiting;
        }
        try {
            r = respond(handle, req);
        } finally {
            with waiting.turn {
                sending.pop(id(waiting), None);
            }
        }
        events = r.events;
        if events is None {
            told = True;
            calls.answered();
            write_response(conn, r, req.method == "HEAD");
        } else {
            lines = [
                "HTTP/1.1 " + str(r.status) + " " + http.client.responses.get(r.status, ""),
                "Content-Type: text/event-stream",
                "Cache-Control: no-cache",
                "X-Accel-Buffering: no",
                "Connection: close",
            ];
            for (k, v) in r.headers.items() {
                lines.append(k + ": " + v);
            }
            conn.sendall(("\r\n".join(lines) + "\r\n\r\n").encode("latin-1"));
            s = Sending(conn=conn, turn=threading.Lock(), last=time.time());
            sending[id(s)] = s;
            try {
                for event in events {
                    with s.turn {
                        conn.sendall(event);
                        s.last = time.time();
                    }
                }
            } finally {
                del sending[id(s)];
                events.close();
            }
        }
    } except OSError as gone {
        print("request " + req.path + ": its client went: " + str(gone));
    } except Exception as e {
        print("request " + req.path + " failed: " + str(e));
    }
    if not told {
        calls.answered();
    }
    try {
        conn.close();
    } except OSError {}
}

impl keep_alive(sending: dict[int, Sending], now: float) {
    for s in list(sending.values()) {
        if now - s.last < KEEPALIVE_SECONDS or not s.turn.acquire(False) {
            continue;
        }
        try {
            (_, ready, _) = select.select([], [s.conn.fileno()], [], 0.0);
            if len(ready) > 0 {
                s.conn.sendall(
                    b"HTTP/1.1 100 Continue\r\n\r\n" if s.interim else b": still here\n\n"
                );
            }
            s.last = now;
        } except Exception {
            s.last = now;
        } finally {
            s.turn.release();
        }
    }
}

impl events_of(r: any) -> Iterator[bytes] {
    with r {
        event = b"";
        forever {
            line: bytes = r.readline();
            if len(line) == 0 {
                return;
            }
            event = event + line;
            if line == b"\n" or line == b"\r\n" {
                yield event;
                event = b"";
            }
        }
    }
}

impl HttpTransport.postinit {
    self.work = [];
    self.wake = [];
}

impl HttpTransport.open(host: dyn Host) {}

impl HttpTransport.send(address: str, r: Request, seconds: float) -> Response {
    req = urllib.request.Request(
        address.rstrip("/") + r.path + ("?" + r.query if r.query != "" else ""),
        data=(r.body if r.method != "GET" else None),
        headers=r.headers,
        method=r.method,
    );
    got: any = None;
    try {
        got = urllib.request.urlopen(req, timeout=seconds);
    } except HTTPError as e {
        return Response(status=e.code, body=e.read());
    }
    status: int = got.status;
    ctype: str = got.headers.get("content-type", "");
    if ctype.startswith("text/event-stream") {
        return Response(status=status, ctype=ctype, events=events_of(got));
    }
    said: dict[str, str] = {};
    for (k, v) in got.headers.items() {
        said[str(k).lower()] = str(v);
    }
    with got {
        body: bytes = got.read();
        return Response(status=status, ctype=ctype, body=body, headers=said);
    }
}

impl HttpTransport.serving -> bool {
    return len(self.wake) == 2;
}

impl HttpTransport.serves_paths -> bool {
    return True;
}

impl HttpTransport.on_loop(work: Callable[[], None]) {
    self.work.append(work);
    if len(self.wake) == 2 {
        self.wake[1].send(b"!");
    }
}

impl HttpTransport.claim(address: str) -> Claim {
    (host, colon, port_text) = address.rpartition(":");
    if colon == "" or not port_text.isascii() or not port_text.isdigit() {
        raise CannotListen(reason="an address is a host and a port, as 127.0.0.1:8000");
    }
    port = int(port_text);
    if port > 65535 {
        raise CannotListen(reason="a port is a number from 0 to 65535");
    }
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM);
    try {
        s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1);
        s.bind((host, port));
        s.listen(128);
    } except OSError as e {
        s.close();
        said = e.strerror;
        raise CannotListen(reason=said if said is not None else str(e));
    }
    return Bound(sock=s);
}

impl HttpTransport.listen(
    claim: Claim,
    handle: Callable[[Request], Response],
    ticks: list[Tick],
    listening: Callable[[int], None] | None,
) {
    s: any = (claim as Bound).sock;
    accepting: int = s.fileno();
    at = s.getsockname();
    bound: int = at[1];
    print("listening on http://" + str(at[0]) + ":" + str(bound) + "/", flush=True);
    if listening is not None {
        listening(bound);
    }
    ends = socket.socketpair();
    waker: any = ends[0];
    woken: int = waker.fileno();
    self.wake.append(waker);
    self.wake.append(ends[1]);
    sending: dict[int, Sending] = {};
    answering: list[Calls] = [];
    calls = Calls(
        answer=lambda (conn: any, req: Request, interim: bool) {
            answer_on(conn, req, interim, handle, sending, answering[0])
        },
        client_header=self.client_header.strip().lower(),
    );
    answering.append(calls);
    now = time.time();
    for t in ticks {
        t.next_at = now;
    }
    socks: dict[int, any] = {};
    bufs: dict[int, bytes] = {};
    born: dict[int, float] = {};
    clients: dict[int, str] = {};
    closing: dict[int, float] = {};
    def drop(fd: int, taken: bool = False) {
        if not taken {
            socks[fd].close();
        }
        del socks[fd];
        del bufs[fd];
        del born[fd];
        del clients[fd];
        if fd in closing {
            del closing[fd];
        }
    }

    while True {
        now = time.time();
        for t in ticks {
            if t.next_at <= now {
                t.next_at = now + t.every;
                try {
                    t.run();
                } except Exception as e {
                    print(t.name + " failed: " + str(e));
                }
            }
        }
        keep_alive(sending, now);
        calls.settle();
        while len(self.work) > 0 {
            work = self.work.pop(0);
            try {
                work();
            } except Exception as e {
                print("work on the loop failed: " + str(e));
            }
        }
        (ready, _, _) = select.select([accepting, woken] + list(socks.keys()), [], [], 0.5);
        for fd in ready {
            if fd == woken {
                waker.recv(4096);
                continue;
            }
            if fd == accepting {
                if len(socks) >= MAX_CONNECTIONS {
                    drop(min(born.keys(), key=lambda (k: int) -> float { return born[k]; }));
                }
                try {
                    (conn, peer) = s.accept();
                    conn.settimeout(10.0);
                } except OSError as e {
                    print("accept failed: " + str(e));
                    if len(socks) > 0 {
                        drop(min(born.keys(), key=lambda (k: int) -> float { return born[k]; }));
                    }
                    continue;
                }
                socks[conn.fileno()] = conn;
                bufs[conn.fileno()] = b"";
                born[conn.fileno()] = time.time();
                clients[conn.fileno()] = str(peer[0]);
                continue;
            }
            if fd not in socks {
                continue;
            }
            c = socks[fd];
            done = False;
            if fd in closing {
                try {
                    done = len(c.recv(65536)) == 0;
                } except OSError as e {
                    done = True;
                }
                if done {
                    drop(fd);
                }
                continue;
            }
            try {
                chunk = c.recv(65536);
                if len(chunk) == 0 {
                    done = True;
                } else {
                    bufs[fd] = bufs[fd] + chunk;
                    if parse_request(bufs[fd]) is not None {
                        whole = bufs[fd];
                        drop(fd, taken=True);
                        calls.take(c.detach(), whole);
                    }
                }
            } except Refused as no {
                try {
                    write_response(
                        c,
                        Response(
                            status=no.status, ctype="text/plain", body=no.detail.encode("utf-8")
                        ),
                    );
                    c.shutdown(socket.SHUT_WR);
                    closing[fd] = time.time() + LINGER_SECONDS;
                } except OSError as gone {
                    print("request refused, its client gone: " + str(gone));
                    done = True;
                }
            } except Exception as e {
                print("request failed: " + str(e));
                done = True;
            }
            if done {
                drop(fd);
            }
        }
        now = time.time();
        for fd in list(socks.keys()) {
            if now - born[fd] > REQUEST_SECONDS or (fd in closing and now > closing[fd]) {
                drop(fd);
            }
        }
    }
}
