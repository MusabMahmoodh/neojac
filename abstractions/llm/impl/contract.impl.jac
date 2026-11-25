impl ByUsage.add(more: ByUsage) {
    if more.requests > 0 {
        mine = self.cost;
        theirs = more.cost;
        if self.requests == 0 {
            self.cost = theirs;
        } elif mine is None or theirs is None {
            self.cost = None;
        } else {
            self.cost = mine + theirs;
        }
    }
    self.requests += more.requests;
    self.input_tokens += more.input_tokens;
    self.output_tokens += more.output_tokens;
    self.cache_read_tokens += more.cache_read_tokens;
    self.cache_write_tokens += more.cache_write_tokens;
    self.seconds += more.seconds;
    if more.model != "" {
        self.model = more.model;
    }
}
