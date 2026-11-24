# __init__

A SQLite file a plugin keeps beside the program, at a layout: opened, made
when it is new, and brought up to the layout its reader reads. The `sqlite`
store and the `accounts` auth each keep one.

## Upgrade

One step of bringing a file up to the layout its reader
reads: `apply`, given the open database, makes a file of layout `since` one
of layout `since` + 1. A layout that changes ships the step from the one
before it, so that no one's data stops at a release.

## laid_out

The layout `db` says it is of (its `user_version`), and how many tables
and indexes it holds.

## open_db

Open the SQLite file at `path`, made with `tables` if it is new: one of
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
whose upgrade failed.

(One connection, for whichever thread is at the file: its users take
turns at it.)

(All of it at once: a table made on its own is a write to disk of its
own, and a file of a dozen takes a dozen times as long to make. And
as the file's one writer, looked at again once it is: of the
programs that start at once on no file, one makes it.)

The step from each layout between the file's and this one, in order.

(As the file's one writer from before it is copied: of the programs
that start at once on a file of an older layout, one upgrades it, and
the others find it done.)
