impl kept_of(r: any) -> Kept {
    return Kept(
        id=str(r[0]), size=int(r[1]), ctype=str(r[2]), made=float(r[3]), whole=int(r[4]) != 0
    );
}

impl LocalFiles.postinit {
    self.db = None;
    self.data_dir = "";
    self.turn = threading.Lock();
}

impl LocalFiles.kept_as -> str {
    return self.path if self.path != "" else os.path.join(self.data_dir, "files");
}

impl LocalFiles.open(host: dyn Host) {
    self.data_dir = host.data_dir();
    self.db = open_db(
        os.path.join(self.kept_as(), "files.db"), FILES_FORMAT, FILES_TABLES, [], host
    );
    self.db.execute("pragma busy_timeout = 30000");
    self.db.execute("pragma journal_mode = wal");
    self.db.commit();
}

impl LocalFiles.bytes_at(id: str) -> str {
    return os.path.join(self.kept_as(), id[0:2], id);
}

impl LocalFiles.known(id: str) -> Kept | None {
    for r in self.db.execute(f"select {COLUMNS} from files where id = ?", (id,)) {
        return kept_of(r);
    }
    return None;
}

impl LocalFiles.piece -> int {
    return PIECE;
}

impl LocalFiles.begin(id: str, ctype: str) {
    with self.turn {
        if self.known(id) is not None {
            raise ValueError(f"the file {id} is kept already");
        }
        where = self.bytes_at(id);
        os.makedirs(os.path.dirname(where), exist_ok=True);
        with open(where, "wb") as f {
            f.write(b"");
        }
        self.db.execute(
            "insert into files (id, type, size, made, whole) values (?, ?, 0, ?, 0)",
            (id, ctype, time.time()),
        );
        self.db.commit();
    }
}

impl LocalFiles.append(id: str, offset: int, piece: bytes) -> int {
    with self.turn {
        k = self.known(id);
        if k is None or k.whole {
            raise LookupError(f"no file {id} is being written");
        }
        if offset != k.size or len(piece) == 0 {
            return k.size;
        }
        with open(self.bytes_at(id), "r+b") as f {
            f.seek(offset);
            f.write(piece);
        }
        size = offset + len(piece);
        self.db.execute(
            "update files set size = ? where id = ? and size = ? and whole = 0", (size, id, offset)
        );
        self.db.commit();
        return size;
    }
}

impl LocalFiles.finish(id: str) -> Kept {
    with self.turn {
        k = self.known(id);
        if k is None {
            raise LookupError(f"no file {id}");
        }
        if k.whole {
            return k;
        }
        with open(self.bytes_at(id), "r+b") as f {
            f.flush();
            os.fsync(f.fileno());
        }
        self.db.execute("update files set whole = 1 where id = ?", (id,));
        self.db.commit();
        k.whole = True;
        return k;
    }
}

impl LocalFiles.stat(id: str) -> Kept | None {
    with self.turn {
        return self.known(id);
    }
}

impl LocalFiles.read(id: str, start: int, most: int) -> bytes {
    with self.turn {
        k = self.known(id);
        if k is None or not k.whole {
            raise LookupError(f"no file {id}");
        }
        if start >= k.size or most <= 0 {
            return b"";
        }
        with open(self.bytes_at(id), "rb") as f {
            f.seek(start);
            return f.read(min(most, k.size - start));
        }
    }
}

impl LocalFiles.drop(ids: list[str]) {
    with self.turn {
        for id in ids {
            self.db.execute("delete from files where id = ?", (id,));
            self.db.commit();
            try {
                os.remove(self.bytes_at(id));
            } except FileNotFoundError {}
        }
    }
}

impl LocalFiles.every -> Iterator[Kept] {
    all: list[Kept] = [];
    with self.turn {
        for r in self.db.execute(f"select {COLUMNS} from files order by made") {
            all.append(kept_of(r));
        }
    }
    for k in all {
        yield k;
    }
}
