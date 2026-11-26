impl static_file(
    top: str, path: str, headers: dict[str, str] = {}, routes: list[str] = []
) -> Response {
    if top == "" {
        raise ValueError("static_file needs the directory it serves");
    }
    sent: dict[str, str] = {"X-Content-Type-Options": "nosniff"};
    cached = "";
    for (name, value) in headers.items() {
        if name.lower() == "cache-control" {
            cached = value;
        } else {
            sent[name] = value;
        }
    }
    served = os.path.realpath(top);
    full = os.path.realpath(os.path.join(served, path.lstrip("/")));
    under = False;
    try {
        under = os.path.commonpath([served, full]) == served;
    } except ValueError {
        under = False;
    }
    if not under {
        return Response(status=403, ctype="text/plain", body=b"forbidden", headers=sent);
    }
    rel: str = os.path.relpath(full, served);
    status = 200;
    if rel == "." or not os.path.isfile(full) {
        ext = os.path.splitext(rel)[1].lower();
        page = os.path.join(served, "index.html");
        if ext in CONTENT_TYPES and ext != ".html" or not os.path.isfile(page) {
            return Response(status=404, ctype="text/plain", body=b"not found", headers=sent);
        }
        if len(routes) > 0 and not routed(path, routes) {
            status = 404;
        }
        full = page;
        rel = "index.html";
    }
    with open(full, "rb") as f {
        data = f.read();
    }
    ext = os.path.splitext(full)[1].lower();
    if rel.split(os.sep)[0] == "assets" {
        sent["Cache-Control"] = "public, max-age=31536000, immutable";
    } elif cached != "" {
        sent["Cache-Control"] = cached;
    } elif ext == ".html" {
        sent["Cache-Control"] = "no-cache";
    }
    return Response(
        status=status,
        ctype=CONTENT_TYPES.get(ext, "application/octet-stream"),
        body=data,
        headers=sent,
    );
}

impl routed(path: str, routes: list[str]) -> bool {
    got = [urllib.parse.unquote(x) for x in path.split("/") if x != ""];
    for r in routes {
        segs = [x for x in r.split("/") if x != ""];
        ok = True;
        rest = False;
        i = 0;
        while i < len(segs) and ok {
            if segs[i] == "*" {
                rest = True;
                break;
            }
            if i >= len(got) {
                ok = False;
            } elif not segs[i].startswith(":") and segs[i].lower() != got[i].lower() {
                ok = False;
            }
            i += 1;
        }
        if ok and (rest or i == len(got)) {
            return True;
        }
    }
    return False;
}
