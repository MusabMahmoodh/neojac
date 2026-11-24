import http.client;
import ipaddress;
import re;
import select;
import socket;
import threading;
import time;
import urllib.request;
import from urllib.error { HTTPError }
import from common.contract { Host }
import from transport.contract {
    CannotListen,
    Claim,
    Request,
    Response,
    Tick,
    Transport,
    json_fail,
}

glob MAX_HEAD: int = 1048576,
     MAX_BODY: int = 16777216,
     MAX_CONNECTIONS: int = 512,
     REQUEST_SECONDS: float = 60.0,
     LINGER_SECONDS: float = 2.0,
     MAX_CALLS: int = 256,
     IDLE_SECONDS: float = 30.0,
     KEEPALIVE_SECONDS: float = 15.0;

obj Refused(Exception) {
    has status: int,
        detail: str;
}

def parse_request(buf: bytes) -> Request | None;
def reads_interim(buf: bytes) -> bool;
def write_response(conn: any, r: Response, head_only: bool = False);
def respond(handle: Callable[[Request], Response], req: Request) -> Response;
def client_of(headers: dict[str, str], peer: str, named: str) -> str;

obj Sending {
    has conn: any,
        turn: any,
        last: float,
        interim: bool = False;
}

obj Calls {
    has answer: Callable[[any, Request, bool], None],
        client_header: str = "",
        turn: any = threading.Condition(),
        queued: list[int] = [],
        held: dict[int, bytes] = {},
        read: list[int] = [],
        tickets: int = 0,
        threads: int = 0,
        open: int = 0;
    def take(descriptor: int, request: bytes);
    def settle;
    def answered;
    def work;
}

def answer_on(
    conn: any,
    req: Request,
    interim: bool,
    handle: Callable[[Request], Response],
    sending: dict[int, Sending],
    calls: Calls,
);
def keep_alive(sending: dict[int, Sending], now: float);
def events_of(r: any) -> Iterator[bytes];

obj Bound(Claim) {
    has sock: any;
}

obj HttpTransport(Transport) {
    has client_header: str = "";

    has work: list[Callable[[], None]] postinit,
        wake: list[any] postinit;

    def postinit;
    def open(host: dyn Host);
    def send(address: str, r: Request, seconds: float) -> Response;

    def serving -> bool;
    def serves_paths -> bool;

    def on_loop(work: Callable[[], None]);
    def claim(address: str) -> Claim;
    def listen(
        claim: Claim,
        handle: Callable[[Request], Response],
        ticks: list[Tick],
        listening: Callable[[int], None] | None,
    );
}
