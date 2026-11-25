import json;
import from common.contract { Host }

obj Request {
    has method: str,
        path: str,
        query: str = "",
        headers: dict[str, str] = {},
        body: bytes = b"",
        client: str = "";
}

obj Response {
    has status: int = 200,
        ctype: str = "application/json",
        body: bytes = b"",
        headers: dict[str, str] = {},
        events: Iterator[bytes] | None = None,
        pieces: Iterator[bytes] | None = None,
        length: int = -1;
}

obj Tick {
    has name: str,
        every: float,
        run: Callable[[], None],
        next_at: float = 0.0;
}

obj Claim {}

obj CannotListen(Exception) {
    has reason: str;

    def __str__ -> str;
}

obj Transport {
    def open(host: dyn Host) abst;
    def send(address: str, r: Request, seconds: float) -> Response abst;
    def claim(address: str) -> Claim abst;
    def listen(
        claim: Claim,
        handle: Callable[[Request], Response],
        ticks: list[Tick],
        listening: Callable[[int], None] | None,
    ) abst;
    def on_loop(work: Callable[[], None]) abst;
    def serving -> bool abst;
    def serves_paths -> bool abst;
}

def json_fail(status: int, kind: str, detail: str) -> Response;
