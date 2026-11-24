import json;
import os;
import subprocess;
import sys;
import from jobs.contract { JobState, Jobs, JobsHost }

obj Run {
    has proc: any,
        in_path: str,
        log_path: str,
        seen: int = 0,
        ended: bool = False,
        result: any = None,
        failed: str = "";
}

def run_to_log(in_path: str, log_path: str, run: Callable[[any, Callable[[str, str], None]], any]);

obj ProcessJobs(Jobs) {
    has dir: str = "";

    has runs: dict[str, Run] postinit,
        made: int postinit,
        host: dyn JobsHost | None postinit;

    def postinit;

    def open(host: dyn JobsHost);
    def program -> dyn JobsHost;

    def start(name: str, input: any) -> str;

    def read(id: str) -> JobState;

    def work -> bool;
}
