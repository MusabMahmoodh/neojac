impl static_file(top: str, path: str, headers: dict[str, str] = {}) -> Response {
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
    if rel == "." or not os.path.isfile(full) {
        ext = os.path.splitext(rel)[1].lower();
        page = os.path.join(served, "index.html");
        if ext in CONTENT_TYPES and ext != ".html" or not os.path.isfile(page) {
            return Response(status=404, ctype="text/plain", body=b"not found", headers=sent);
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
        ctype=CONTENT_TYPES.get(ext, "application/octet-stream"), body=data, headers=sent
    );
}
