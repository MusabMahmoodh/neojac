import from common.contract { Host }

obj Limits {
    def open(host: dyn Host) abst;
    def consume(scope: str, actor: str, limit: int, seconds: int) -> int abst;
}
