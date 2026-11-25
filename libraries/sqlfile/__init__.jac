import os;
import shutil;
import sqlite3;
import from common.contract { DataError, Host }

obj Upgrade {
    has since: int,
        apply: Callable[[any], None];
}

def laid_out(db: any) -> tuple[int, int];
def open_db(
    path: str,
    format: int,
    tables: list[str],
    upgrades: list[Upgrade] = [],
    host: dyn Host | None = None,
) -> any;
