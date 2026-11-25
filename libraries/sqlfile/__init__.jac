"""A SQLite file a plugin keeps beside the program, at a layout: opened, made
when it is new, and brought up to the layout its reader reads. The `sqlite`
store and the `accounts` auth each keep one."""

import os;
import shutil;
import sqlite3;
import from common.contract { DataError, Host }

"""One step of bringing a file up to the layout its reader
reads: `apply`, given the open database, makes a file of layout `since` one
of layout `since` + 1. A layout that changes ships the step from the one
before it, so that no one's data stops at a release."""
obj Upgrade {
    has since: int,
        apply: Callable[[any], None];
}

"""The layout `db` says it is of (its `user_version`), and how many tables
and indexes it holds: the two read in one statement, so of the file at one
moment. A program that looks as another makes the file sees it unmade or
made, never with its tables and not yet its layout."""
def laid_out(db: any) -> tuple[int, int] {
    for r in db.execute(
        "select user_version, (select count(*) from sqlite_master) from pragma_user_version"
    ) {
        return (int(r[0]), int(r[1]));
    }
    return (0, 0);
}

"""Open the SQLite file at `path`, made with `tables` if it is new: one of
layout `format` (its `user_version`).

A file of an older layout is upgraded, when `upgrades` has the step from each
layout between its own and `format`: the file is first copied beside itself
(`<path>.layout<n>`, the file as it was), then every step runs in one
transaction, so a step that fails leaves the file as it was. What was done is
told to `host`, the program the plugin was opened in, when it is given: a
sentence without its subject ("upgraded accounts.db from layout 1 to 2; the
file as it was is kept as accounts.db.layout1"), which the program says as
it starts.

DataError (`common.contract`) for a file that can't be brought to `format`:
one of a newer layout, one of an older layout no steps lead from, and one
whose upgrade failed."""
def open_db(
    path: str,
    format: int,
    tables: list[str],
    upgrades: list[Upgrade] = [],
    host: dyn Host | None = None,
) -> any {
    d = os.path.dirname(path);
    if d != "" {
        os.makedirs(d, exist_ok=True);
    }
    # (One connection, for whichever thread is at the file: its users take
    # turns at it.)
    db = sqlite3.connect(path, check_same_thread=False);
    (version, made) = laid_out(db);
    if version == 0 and made == 0 {
        # (All of it at once: a table made on its own is a write to disk of its
        # own, and a file of a dozen takes a dozen times as long to make. And
        # as the file's one writer, looked at again once it is: of the
        # programs that start at once on no file, one makes it.)
        db.execute("begin immediate");
        (version, made) = laid_out(db);
        if version == 0 and made == 0 {
            for t in tables {
                db.execute(t);
            }
            db.execute("pragma user_version = " + str(format));
            db.commit();
            return db;
        }
        db.rollback();
    }
    if version == format {
        return db;
    }
    db.close();
    reads = f"(layout {version}; this one reads layout {format})";
    if version > format {
        raise DataError(path=path, problem=f"is laid out as a newer neojac writes it {reads}");
    }
    # The step from each layout between the file's and this one, in order.
    steps: list[Upgrade] = [];
    for n in range(version, format) {
        step = [u for u in upgrades if u.since == n];
        if len(step) != 1 {
            raise DataError(
                path=path,
                problem=f"is laid out as an older neojac wrote it, which this one can't upgrade {reads}",
            );
        }
        steps.append(step[0]);
    }
    kept = f"{path}.layout{version}";
    db = sqlite3.connect(path, check_same_thread=False);
    # (As the file's one writer from before it is copied: of the programs
    # that start at once on a file of an older layout, one upgrades it, and
    # the others find it done.)
    db.execute("begin immediate");
    if laid_out(db)[0] == format {
        db.rollback();
        return db;
    }
    shutil.copyfile(path, kept);
    try {
        for u in steps {
            u.apply(db);
        }
        db.execute("pragma user_version = " + str(format));
        db.commit();
    } except Exception as e {
        db.rollback();
        db.close();
        os.remove(kept);
        raise DataError(
            path=path,
            problem=f"could not be upgraded {reads}, and is as it was: {type(e).__name__}: {e}",
        );
    }
    if host is not None {
        host.upgraded(
            f"upgraded {os.path.basename(path)} from layout {version} to {format}; the file as it was is kept as {os.path.basename(kept)}",
        );
    }
    return db;
}
