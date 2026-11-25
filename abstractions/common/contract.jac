obj Secret {
    has variable: str = "";
}

obj Host {
    def data_dir -> str abst;
    def upgraded(what: str) abst;
    def secret(s: Secret) -> str abst;
}

obj DataError(Exception) {
    has path: str,
        problem: str;

    def __str__ -> str;
}
