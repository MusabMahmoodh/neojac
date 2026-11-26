impl restspec(
    f: Callable,
    method: HTTPMethod,
    path: str,
    produces: str = "text/plain",
    envelope: bool = True,
    headers: dict[str, str] | None = None,
) {
    comptime assert len(path) > 0 and path[0] == "/", "@restspec's path starts with '/'";
    note(f, "restspec", (method, path, produces, envelope, headers));
}

impl routes -> list[RestRoute] {
    if len(_routes_read) == 0 {
        _routes_read.append(True);
        comptime for n in noted("restspec") {
            sent_with: dict[str, str] | None = n.value[4];
            takes: list[str] = [];
            texts: list[str] = [];
            comptime for p in params(n.decl) {
                takes.append(p.name);
                comptime if kind(p.type) == Kind.STR {
                    texts.append(p.name);
                }
            }
            _routes.append(
                RestRoute(
                    method=n.value[0],
                    path=n.value[1],
                    produces=n.value[2],
                    envelope=n.value[3],
                    headers=sent_with,
                    module=n.module,
                    name=n.name,
                    takes=takes,
                    texts=texts,
                    run=lambda (given: dict[str, any]) -> any {
                        a = decode[args_type(n.decl)](given);
                        return apply(n.decl, a);
                    },
                ),
            );
        }
    }
    return _routes;
}

impl route_of(method: str, path: str) -> RestRoute | None {
    for r in routes() {
        if r.path == path and r.method.value == method {
            return r;
        }
    }
    return None;
}

impl route_answer(
    r: RestRoute, query: str, body: bytes, caller: str, trusted: bool
) -> tuple[int, str, bytes, dict[str, str]] {
    e = endpoint_named(r.module, r.name);
    (given, problem) = route_args(r, query, body);
    status = 200;
    reply = b"";
    if e is not None {
        sent = body if problem != "" else json.dumps({"args": given}).encode("utf-8");
        (status, reply) = answer(e.path(), sent, caller, trusted);
    } elif not trusted {
        (status, reply) = reply_fail(403, "rejected", "an internal endpoint");
    } elif problem != "" {
        (status, reply) = reply_fail(400, "rejected", problem);
    } elif any(name not in r.takes for name in given) {
        stray = [name for name in given if name not in r.takes][0];
        (status, reply) = reply_fail(400, "rejected", f"{r.name}: no parameter '{stray}'");
    } else {
        try {
            out: any = kept_call(caller, lambda -> any { return json_values(r.run(given)); });
            reply = json.dumps({"ok": True, "data": out}).encode("utf-8");
        } except CodecError as c {
            (status, reply) = reply_fail(400, "rejected", f"{r.name}: {c}");
        } except Exception as x {
            print(f"route {r.path} failed: {type(x).__name__}: {x}{raised_at(x)}");
            (status, reply) = reply_fail(500, "failed", r.path + " failed");
        }
    }
    if r.envelope or status != 200 {
        return (status, "application/json", reply, {});
    }
    data: any = json.loads(reply.decode("utf-8"))["data"];
    if not isinstance(data, str) {
        print(
            f"route {r.path} failed: its function gives a {type(data).__name__}, not the str its body is",
        );
        (status, reply) = reply_fail(500, "failed", r.path + " failed");
        return (status, "application/json", reply, {});
    }
    text: str = data;
    return (200, r.produces, text.encode("utf-8"), r.headers or {});
}

impl route_args(r: RestRoute, query: str, body: bytes) -> tuple[dict[str, any], str] {
    given: dict[str, any] = {};
    for (name, text) in urllib.parse.parse_qsl(query, keep_blank_values=True) {
        if name not in r.takes {
            continue;
        }
        if name in r.texts {
            given[name] = text;
        } else {
            try {
                given[name] = json.loads(text);
            } except ValueError {
                given[name] = text;
            }
        }
    }
    if len(body) == 0 {
        return (given, "");
    }
    got: any = None;
    try {
        got = json.loads(body.decode("utf-8"));
    } except ValueError {
        return (given, "the request is not JSON");
    }
    if not isinstance(got, dict) {
        return (given, "the request is not a JSON object");
    }
    held: dict[str, any] = got;
    for (name, value) in held.items() {
        given[name] = value;
    }
    return (given, "");
}
