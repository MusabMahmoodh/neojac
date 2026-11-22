"""The standard files: each file's bytes in a file of its own, in a
directory of the app's data, and what is known of each (its type, its size,
when it was begun, whether it is whole) in a SQLite file beside them, which
several programs on one machine may open at once.

A file's bytes are at `<directory>/<the id's first two digits>/<id>`, so no
directory holds them all. A file being written is there too: nothing reads
one before the SQLite file says it is whole."""

import os;
import threading;
import time;
import from common.contract { Host }
import from files.contract { Files, Kept }
import from sqlfile { open_db }

"""The layout of the SQLite file, as its `user_version`."""
glob FILES_FORMAT: int = 1;

glob FILES_TABLES: list[str] = [
    "create table files (id text primary key, type text not null, size integer not null, made real not null, whole integer not null)",
];

glob COLUMNS: str = "id, size, type, made, whole";

"""The file a result's line holds."""
def kept_of(r: any) -> Kept {
    return Kept(id=str(r[0]), size=int(r[1]), ctype=str(r[2]), made=float(r[3]), whole=int(r[4]) != 0);
}

obj LocalFiles(Files) {
    """The directory: `files` in the app's data directory when it is not
    said."""
    has path: str = "";

    has db: any postinit;
    # The app's data directory, as the program it was opened in says.
    has data_dir: str postinit;
    # What holds the SQLite file and a file's bytes for one of its users at
    # a time: a program's threads give way where they wait for a disk.
    has turn: any postinit;

    def postinit {
        self.db = None;
        self.data_dir = "";
        self.turn = threading.Lock();
    }

    def kept_as -> str {
        return self.path if self.path != "" else os.path.join(self.data_dir, "files");
    }

    def open(host: dyn Host) {
        self.data_dir = host.data_dir();
        self.db = open_db(
            os.path.join(self.kept_as(), "files.db"), FILES_FORMAT, FILES_TABLES, [], host
        );
        # (Its writers wait their turn at the file, and a reader reads beside
        # a writer.)
        self.db.execute("pragma busy_timeout = 30000");
        self.db.execute("pragma journal_mode = wal");
        self.db.commit();
    }

    """Where the bytes of the file `id` are."""
    def bytes_at(id: str) -> str {
        return os.path.join(self.kept_as(), id[0:2], id);
    }

    """What the SQLite file says of `id`. (Asked with `turn` held.)"""
    def known(id: str) -> Kept | None {
        for r in self.db.execute(f"select {COLUMNS} from files where id = ?", (id,)) {
            return kept_of(r);
        }
        return None;
    }

    def begin(id: str, ctype: str) {
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

    def append(id: str, offset: int, piece: bytes) -> int {
        with self.turn {
            k = self.known(id);
            if k is None or k.whole {
                raise LookupError(f"no file {id} is being written");
            }
            if offset != k.size or len(piece) == 0 {
                return k.size;
            }
            # (Written where it goes, never at the end: a piece another
            # program wrote meanwhile is written over with the same bytes.)
            with open(self.bytes_at(id), "r+b") as f {
                f.seek(offset);
                f.write(piece);
            }
            size = offset + len(piece);
            self.db.execute(
                "update files set size = ? where id = ? and size = ? and whole = 0",
                (size, id, offset),
            );
            self.db.commit();
            return size;
        }
    }

    def finish(id: str) -> Kept {
        with self.turn {
            k = self.known(id);
            if k is None {
                raise LookupError(f"no file {id}");
            }
            if k.whole {
                return k;
            }
            # (On the disk before it is called whole.)
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

    def stat(id: str) -> Kept | None {
        with self.turn {
            return self.known(id);
        }
    }

    def read(id: str, start: int, most: int) -> bytes {
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

    def drop(ids: list[str]) {
        with self.turn {
            for id in ids {
                # (What it knows of the file first: bytes nothing names are
                # no file, and a name with no bytes would be a broken one.)
                self.db.execute("delete from files where id = ?", (id,));
                self.db.commit();
                try {
                    os.remove(self.bytes_at(id));
                } except FileNotFoundError {
                    # (Gone already.)
                }
            }
        }
    }

    def every -> Iterator[Kept] {
        # (Read at once: what asks for them may drop some as it goes.)
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
}
