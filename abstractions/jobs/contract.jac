import from common.contract { Host }

obj JobState {
    has notes: list[tuple[str, str]] = [],
        done: bool = False,
        result: any = None,
        failed: str = "";
}

obj JobsHost(Host) {
    def command -> list[str] abst;
    def owner -> str abst;
    def run(name: str, input: any, note: Callable[[str, str], None]) -> any abst;
    def run_space(owner: str, name: str, input: any, note: Callable[[str, str], None]) -> any abst;
}

obj Jobs {
    def open(host: dyn JobsHost) abst;
    def start(name: str, input: any) -> str abst;
    def read(id: str) -> JobState abst;
    def work -> bool abst;
}
