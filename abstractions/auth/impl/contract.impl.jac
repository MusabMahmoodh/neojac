impl Rejected.__str__ -> str {
    return self.detail;
}

impl bearer_token(headers: dict[str, str]) -> str {
    return headers.get("authorization", "").removeprefix("Bearer ").strip();
}
