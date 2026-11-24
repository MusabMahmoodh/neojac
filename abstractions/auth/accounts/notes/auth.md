# auth

The standard auth: accounts of a username and a password, and their
sessions, in a SQLite file. What the accounts are, how one signs in and what
is refused is the library `accountbook`'s: this is the file it keeps them
in, which is one program's.

## DEVICES

The table of the programs that show no page and wait to be signed in:
what layout 2 has that 1 did not.

## with_devices

A file of layout 1 made one of layout 2.

## LINKS

The table of the links mailed to accounts' addresses: what layout 3 has
that 2 did not, beside whether an account's address is checked.

## with_links

A file of layout 2 made one of layout 3.

## ACCOUNTS_FORMAT

The steps from each layout of the accounts file a release wrote to the
next.

## FileBook

The accounts file, as the accounts ask it.

## FileBook.turn

What a call holds while it is at the file: the calls a server answers
at once share its one connection.

## FileBook.key

What signs the `state` a caller sent to another service carries there
and back: this process's alone, so one who left comes back to it.

## FileBook.followed

The user of the link `key` for `purpose` that lasts at `now`, taken
out as it is followed, in the transaction this begins: "" where there
is none, or another program took it out first.

## Accounts.path

The file: `accounts.db` in the app's data directory when it is not
said.

## Accounts.open_book

An account another service vouches for: its own namespace,
which no username reaches, since its user ID holds a `:`.
