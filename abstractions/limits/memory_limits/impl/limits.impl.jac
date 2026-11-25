impl MemoryLimits.postinit {
    self.kept = {};
    self.turn = threading.Lock();
    self.next_sweep = self.sweep_at;
}

impl MemoryLimits.open(host: dyn Host) {}

impl MemoryLimits.held -> int {
    return len(self.kept);
}

impl MemoryLimits.consume(scope: str, actor: str, limit: int, seconds: int) -> int {
    key = scope + "|" + actor;
    now = time.time();
    with self.turn {
        if len(self.kept) >= self.next_sweep {
            for k in [
                k
                for (k, u) in self.kept.items()
                if now - u.times[len(u.times) - 1] >= u.seconds
            ] {
                del self.kept[k];
            }
            self.next_sweep = max(self.sweep_at, 2 * len(self.kept));
        }
        was = self.kept.get(key, None);
        uses = [t for t in was.times if now - t < seconds] if was is not None else [];
        if len(uses) >= limit {
            self.kept[key] = Uses(seconds=seconds, times=uses);
            return int(seconds - (now - uses[0])) + 1;
        }
        uses.append(now);
        self.kept[key] = Uses(seconds=seconds, times=uses);
        return 0;
    }
}
