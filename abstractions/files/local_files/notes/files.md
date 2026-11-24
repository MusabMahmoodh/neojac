# files

The standard files: each file's bytes in a file of its own, in a
directory of the app's data, and what is known of each (its type, its size,
when it was begun, whether it is whole) in a SQLite file beside them, which
several programs on one machine may open at once.

A file's bytes are at `<directory>/<the id's first two digits>/<id>`, so no
directory holds them all. A file being written is there too: nothing reads
one before the SQLite file says it is whole.

## FILES_FORMAT

The layout of the SQLite file, as its `user_version`.

## PIECE

How many bytes a piece of a file is: 4 MiB, what a request holds with
ease. A directory takes a piece of any size.

## kept_of

The file a result's line holds.

## LocalFiles.path

The directory: `files` in the app's data directory when it is not
said.

## LocalFiles.data_dir

The app's data directory, as the program it was opened in says.

## LocalFiles.turn

What holds the SQLite file and a file's bytes for one of its users at
a time: a program's threads give way where they wait for a disk.

## LocalFiles.open

(Its writers wait their turn at the file, and a reader reads beside
a writer.)

## LocalFiles.bytes_at

Where the bytes of the file `id` are.

## LocalFiles.known

What the SQLite file says of `id`. (Asked with `turn` held.)

## LocalFiles.append

(Written where it goes, never at the end: a piece another
program wrote meanwhile is written over with the same bytes.)

## LocalFiles.finish

(On the disk before it is called whole.)

## LocalFiles.drop

(What it knows of the file first: bytes nothing names are
no file, and a name with no bytes would be a broken one.)

(Gone already.)

## LocalFiles.every

(Read at once: what asks for them may drop some as it goes.)
