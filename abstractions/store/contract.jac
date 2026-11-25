import from common.contract { Host }

obj Row {
    has id: str,
        kind: str,
        type_name: str,
        data: str,
        src: str = "",
        dst: str = "",
        ord: int = 0,
        version: int = 0;
}

obj Changed {
    has rows: list[Row] = [],
        gone: list[str] = [];
}

obj Writing {
    has rows: list[Row] = [],
        gone: list[Row] = [],
        roots: dict[str, str] = {},
        shared: str = "",
        shapes: dict[str, str] = {};
}

obj StoreConflict(Exception) {
    has ids: list[str] = [];

    def __str__ -> str;
}

obj Store {
    def open(host: dyn Host) abst;
    def kept_as -> str abst;
    def types -> dict[str, int] abst;
    def shapes -> dict[str, str] abst;
    def of_type(type_name: str) -> list[Row] abst;
    def rows(ids: list[str]) -> list[Row] abst;
    def edges(id: str) -> list[Row] abst;
    def mark -> int abst;
    def since(mark: int) -> Changed | None abst;
    def write(w: Writing) -> int abst;
    def every -> Iterator[Row] abst;
    def root_of(user: str) -> str abst;
    def roots -> list[str] abst;
    def shared_root -> str abst;
}
