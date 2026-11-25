import from common.contract { Host }

obj Scheduled {
    has name: str,
        every: float,
        run: Callable[[], None];
}

obj Scheduler {
    def open(host: dyn Host) abst;
    def start(work: list[Scheduled], on_loop: Callable[[Callable[[], None]], None]) abst;
}
