import from common.contract { Host }

obj Kept {
    has id: str,
        size: int,
        ctype: str,
        made: float,
        whole: bool = True;
}

obj Files {
    def open(host: dyn Host) abst;
    def kept_as -> str abst;
    def piece -> int abst;
    def begin(id: str, ctype: str) abst;
    def append(id: str, offset: int, piece: bytes) -> int abst;
    def finish(id: str) -> Kept abst;
    def stat(id: str) -> Kept | None abst;
    def read(id: str, start: int, most: int) -> bytes abst;
    def drop(ids: list[str]) abst;
    def every -> Iterator[Kept] abst;
}
