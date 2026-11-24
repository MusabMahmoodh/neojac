# store

The standard store: a space's rows in a SQLite file, which several
programs may open at once.

- **Each row has a version,** which a write raises: a write that finds a row
  at another version than it read is refused whole (StoreConflict).
- **Each write has a mark,** one more than the last: each row keeps the mark
  it was last written at, and each row taken out leaves its id and its
  mark, so that a program asks what was written since it last looked. What
  was taken out is kept that long for KEPT_GONE writes.

## STORE_FORMAT

The layout of the file, as its `user_version`: 3, each row with its
version and the mark it was written at, how many rows there are of each
type and the shape each was written in, and what was taken out.

## KEPT_GONE

How many writes back the ids of the rows taken out are kept: a program
that last looked longer ago reads again all it holds.

## from_layout_2

Layout 2, rows with no versions and no marks, to layout 3: each row is at
its first version, written before every mark.

## STORE_UPGRADES

The steps from each layout of the file a release wrote to the next.

## row_of

The row a result's line holds.

## SqliteStore.path

The file: `graph.db` in the app's data directory when it is not said.

## SqliteStore.data_dir

The app's data directory, as the program it was opened in says.

## SqliteStore.open

(Its writers wait their turn at the file, and a reader reads beside
a writer.)

## SqliteStore.edges

(Each end by its own index; an edge from a node to itself once.)

## SqliteStore.write

(Its turn at the file from here, whoever else has it open.)

(Another took it out: gone, as this write wants it.)
