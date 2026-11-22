"""The contract of the `files` abstraction: `Files`, the interface of the
plugin that keeps a project's files, and what crosses it.

A file is bytes kept whole under an id, with the type they are and when the
file was begun. It never changes: a program that wants other bytes makes
another file. The runtime above a plugin owns the ids, who may read a file,
what a caller may send, and which files a kept graph still holds; a plugin
keeps bytes, and knows nothing of what they are for.

- **An id is 64 hex digits,** which the runtime makes and no one can guess.
  A plugin is asked for no other, and may keep a file by it as it is
  written.
- **A file is written in pieces, and is no file until it is finished.** Each
  piece says where in the file it goes, so one sent twice is written once.
- **What is finished is whole,** and stays as it is until it is dropped."""

import from common.contract { Host }

"""What a plugin knows of one file: its id, how many bytes it has (so far,
for one still being written), the type they are (`ctype`: `image/png`), when it was
begun as seconds since 1970, and whether it is finished (`whole`)."""
obj Kept {
    has id: str,
        size: int,
        ctype: str,
        made: float,
        whole: bool = True;
}

"""What keeps a project's files: the interface of the `files` abstraction's
plugins. One is made with its settings and does nothing until it is
opened."""
obj Files {
    """Make ready to keep files, in the program `host`: open the directory,
    reach the service. The first thing asked of it. DataError
    (`common.contract`) for data it holds that it can't be opened with."""
    def open(host: dyn Host) abst;

    """What its data is called, where an app says what is wrong with what
    it kept: a directory's path, a bucket's address."""
    def kept_as -> str abst;

    """Begin the file `id`, of the type `ctype`, with no bytes yet: one being
    written. ValueError for an id it already has."""
    def begin(id: str, ctype: str) abst;

    """Write `piece` into the file `id`, which is being written, at
    `offset`, when that is how many bytes it has: how many it has after.
    For any other `offset` it writes nothing and gives how many it has, so a
    piece sent again is no harm, and what sends pieces learns where to go on
    from. LookupError for an id that names no file being written."""
    def append(id: str, offset: int, piece: bytes) -> int abst;

    """Finish the file `id`: it is whole from now on, and is written no
    more. One already whole is left as it is. LookupError for an id it has
    nothing of."""
    def finish(id: str) -> Kept abst;

    """What it knows of the file `id`, whole or being written; None for an
    id it has nothing of."""
    def stat(id: str) -> Kept | None abst;

    """At most `most` bytes of the whole file `id`, from `start`: fewer
    where the file ends, none past its end. LookupError for an id that
    names no whole file."""
    def read(id: str, start: int, most: int) -> bytes abst;

    """Take out the files `ids`, whole or being written, with their bytes.
    An id it has nothing of is passed over."""
    def drop(ids: list[str]) abst;

    """Every file it has, whole or being written: what a sweep reads, a
    file at a time."""
    def every -> Iterator[Kept] abst;
}
