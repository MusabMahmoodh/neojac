impl CannotListen.__str__ -> str {
    return self.reason;
}

impl json_fail(status: int, kind: str, detail: str) -> Response {
    return Response(
        status=status,
        body=json.dumps({"ok": False, "kind": kind, "detail": detail}).encode("utf-8"),
    );
}
