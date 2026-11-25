import threading;
import time;
import from common.contract { Host }
import from limits.contract { Limits }

obj Uses {
    has seconds: int,
        times: list[float] = [];
}

obj MemoryLimits(Limits) {
    has sweep_at: int = 1024;

    has kept: dict[str, Uses] postinit,
        turn: any postinit,
        next_sweep: int postinit;

    def postinit;
    def open(host: dyn Host);
    def held -> int;

    def consume(scope: str, actor: str, limit: int, seconds: int) -> int;
}
