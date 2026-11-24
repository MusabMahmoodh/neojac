# __init__

Accounts of a username and a password, and their sessions, over a book
that keeps them: what an `auth` plugin that keeps accounts is, but for where
it keeps them. A plugin's class is an `AccountsAuth` that gives its `Book`:
neojac's `accounts` gives a SQLite file. A session's token is the caller's
alone: the book keeps its SHA-256.

- **A username** is 3 to 32 of `a-z`, `0-9`, `.`, `_` and `-`, starting with a
  letter or a digit, compared lowercased. So it is never an email address,
  which signing in also takes, and never holds `:`.
- **A password** has at least 8 characters, and is kept as a salted
  PBKDF2-HMAC-SHA256 hash.
- **Attempts are limited** in each 15 minutes, by the project's limits.
- **With `local_users`,** an app in a window of its own takes the people at
  its machine as its users, by a name each gives and no password: accounts
  whose provider is `local`.
- **With a GitHub OAuth app's client ID and secret where the program runs,**
  a caller may also sign in through GitHub: an account whose provider is
  `github`, known by GitHub's ID for the user and called by their login
  there. The caller is sent to GitHub and comes back to
  `/__jac/auth/github`, which is what the OAuth app registers as its
  callback.
- **With a Google OAuth client's ID and secret, and `origin`,** a caller may
  also sign in through Google: an account whose provider is `google`, known
  by Google's ID for the person and called by their address. The caller
  comes back to `/__jac/auth/google` at `origin`, which is what the client
  registers as its redirect URI.
- **A program that shows no page** is signed in by someone at one: it shows
  a code of eight letters, and whoever is signed in at the app's page and
  gives the page that code says whether the program is theirs. It then
  collects a session of its own, with a secret it alone holds, of which the
  book keeps the SHA-256. A program waits ten minutes.
- **Where the program sends mail and `origin` says where the app is
  reached,** an account is made only with an address, and a link mailed to
  it checks it; one who forgot their password is mailed a link that sets
  another. A link is `origin`'s, its token in its fragment, and the book
  keeps the token's SHA-256: a check link lasts a day, a reset link an hour,
  and each is followed once. An account another service vouches for
  (GitHub, Google) is checked as it is.

## USERNAME

Sign-in attempts allowed in each LIMIT_SECONDS: for one username (or
email) from one client address, and from one client address in all;
and registrations from one client address. Each attempt costs a
password hash.

How long a caller sent to another service has to come back, and how
long that service is waited for, in seconds.

A program that shows no page: how long it waits to be signed in, and
how long it leaves between asking whether it is, in seconds; how many
may begin from one client address in each LIMIT_SECONDS, and how many
codes one account may answer; and the letters of a code, which are
the consonants no one takes for another or reads a word in.

What one the app does not know is told where they may not make
themselves an account.

Who writes the ID token Google's token endpoint gives: the two ways it
writes itself
(https://developers.google.com/identity/openid-connect/openid-connect#validatinganidtoken).

The services whose accounts' addresses are checked as they are: each
says only an address that is someone's.

How long a link mailed to check an address lasts, and one that sets a
password, in seconds; how many links one account is mailed in each
LIMIT_SECONDS; how many asks for a password's link one client address
makes, and how many links it follows (each a password's hash, for a
reset).

What a step that mails is refused with where nothing is mailed.

What a link that is not one, is used or is too old is refused with.

## Book

Where accounts are kept, as `AccountsAuth` asks it. Each method is one
step, done whole whoever else is at the book: the calls a server answers at
once, and every other program that keeps its accounts there. A `key` is a
session's token as the book keeps it, its SHA-256, and a time is in seconds
as `time.time` counts them.

- `session` is the user a session is of and when it ends, or None for a key
  that names none.
- `begin` keeps a session of `user` under `key` until `expires`, and drops
  the sessions that ended by `now`.
- `end` drops the session `key` names, if it is one.
- `account` is the account whose username or email is `name`: its username
  and its password as it is kept, or None.
- `add` makes an account with `password` as it is kept, unless its username
  is taken, or its email when it has one: whether it was made.
- `known` is the user ID of the one `provider` knows as `external_id`, or
  "" for one it was never asked of.
- `identity` is the same, made where there is none: `user`, from the first
  time it is asked.
- `identities` are the IDs `provider` has for the ones it knows, in the
  order each was first asked for.
- `away_key` signs what a caller carries to another service and back: one
  key, for every program that may be the one the caller comes back to.
- `expect` keeps a program that shows no page waiting under `code`, to be
  collected with `key` (its secret's SHA-256) until `expires`, and drops the
  ones that waited until `now`: whether it was kept, which it is not under
  a code another waits under.
- `decide` says of the one waiting under `code` that it is `user`'s, or,
  with "" for `user`, that it is turned away: whether one waited there that
  nothing was said of yet.
- `collect` is what was said of the one that collects with `key`: whether
  anything was, and the user ("" for one turned away); None for none that
  waits. One something was said of is dropped as it is collected, so it is
  collected once.
- `address` is the address of the account `user` and whether it is
  checked: ("", False) for one with none, and for no account.
- `give_address` gives the account `user`, which has no address, the
  address `email`, unless another account has it: whether it was given.
- `link` keeps a link mailed for `purpose` ("check" or "reset") for the
  account `user`, which `key` (its token's SHA-256) follows until
  `expires`, and drops the links that ended by `now`.
- `check` follows the check link `key`, while it lasts at `now`: its
  account's address is checked, and its check links are dropped. The user,
  or "" for a key that names no such link.
- `reset` follows the reset link `key`, while it lasts at `now`: its
  account's password is `password` (as it is kept), its address is
  checked, and its sessions and its links are dropped. The user, or "" for
  a key that names no such link.

## AccountsAuth

An `auth` plugin's class, but for `open_book`, which the plugin gives: its
fields are the plugin's settings, beside the plugin's own.

## AccountsAuth.rounds

How a password is kept: PBKDF2-HMAC-SHA256 with a salt of its own, at
OWASP's 600,000 rounds. A hash keeps its rounds, so raising this
applies to a password when it is next set.

## AccountsAuth.session_seconds

How long a session lasts: a week.

## AccountsAuth.local_users

Whether the people at the machine are the users of an app in a
window of its own, with no password.

## AccountsAuth.email_required

Whether an account is made only with an email address.

## AccountsAuth.registration

Whether one the app does not know may make themselves an account:
by registering, or by signing in through another service for the
first time. Where they may not, the accounts are the ones there
are, and whoever runs the app makes any other.

## AccountsAuth.github_id

A GitHub OAuth app's client ID and secret: signing in through
GitHub is offered where both are given.

## AccountsAuth.github

Where GitHub is, and its API: another for GitHub Enterprise.

## AccountsAuth.google_id

A Google OAuth client's ID and secret: signing in through Google
is offered where both are given, and `origin`.

## AccountsAuth.google

Where Google signs a caller in, and where its tokens are had.

## AccountsAuth.origin

Where callers reach the app (`https://example.org`), for the place
another service sends them back to. Not said, they are sent to the
callback the service has registered: GitHub's has one, and
Google is not offered.

## AccountsAuth.book

Where the accounts are kept, once it is opened.

## AccountsAuth.host

The program it was opened in, and what that says of it: the app's
data directory, and whether the app shows itself in a window.

## AccountsAuth.github_client

The GitHub OAuth app's and the Google OAuth client's IDs and secrets,
as the program gives them: "" for one it gives none of.

## AccountsAuth.sending

Whether the program sends mail, as it said when it was opened.

## AccountsAuth.open_book

The book the accounts are kept in, made ready in the program `host`:
what a plugin gives. DataError (`common.contract`) for one it can't start
with.

## AccountsAuth.kept

The book the accounts are kept in: asked for once they were opened.

## AccountsAuth.tried

Counts a use of `scope` by `actor` with the program's limits: how many
seconds until it is within `limit` uses in `seconds`, 0 while it is.

## AccountsAuth.local

Whether this app takes the people at its machine as its users: one in
a window of its own, asked to.

## AccountsAuth.local_file

Where an app with local users keeps who is using it now.

## AccountsAuth.local_now

Who of the app's local users is using it now: "" for no one.

## AccountsAuth.caller

The user ID the session a request carries names, while the session
lasts.

## AccountsAuth.asks

A username and a password, to sign in or to make an account; or, for
an app with local users, the name of who is at the machine, and a
session at once for the one who was there last.

## AccountsAuth.needs_address

Whether an account is made only with an address: where it is said
to be, and where an address is checked.

## AccountsAuth.github_offered

Whether a caller may sign in through GitHub: where the program runs
gives the OAuth app's client ID and its secret.

## AccountsAuth.github_back

Where GitHub sends a caller back to, when this app says where it is
reached: "" for the callback the OAuth app registers.

## AccountsAuth.google_offered

Whether a caller may sign in through Google: where the program runs
gives the OAuth client's ID and its secret, and the app says where it is
reached, which Google is told to send them back to.

## AccountsAuth.google_back

Where Google sends a caller back to: its client's redirect URI.

## AccountsAuth.away_mark

What signs a `state` of the way `way` that lasts until `expires` for
the page that keeps `verifier`, with the book's key.

## AccountsAuth.away

Signing in by `way` at another service: its page `place` with
`query`, a `state` only the book's key makes, and a verifier the page
that leaves keeps. The service is given the verifier's hash now and the
verifier when the caller is back (PKCE), and the state is signed over
it: so the session is given to the page that left, and never to one that
was only handed the way back.

## AccountsAuth.came_back

The verifier the page that left by `way` kept, where `given`, what the
caller came back from `service` with, shows that page is theirs and was
left long enough ago; Rejected otherwise, and where they were turned
away there.

## AccountsAuth.github_action

Signing in through GitHub, at its OAuth app's page.

## AccountsAuth.github_answer

The session of the GitHub user a caller came back as: `given` holds
the `code` and `state` GitHub sent them back with, and the `verifier`
their page kept.

## AccountsAuth.google_action

Signing in through Google, at its page that asks the person which of
their accounts, and their address (OpenID Connect's code flow).

## AccountsAuth.google_answer

The session of the Google account a caller came back as: `given`
holds the `code` and `state` Google sent them back with, and the
`verifier` their page kept. Who they are is the ID token Google's token
endpoint gives for the code: read as it comes, over TLS straight from
Google, which stands for its signature (OpenID Connect Core 1.0,
3.1.3.7), and held to this client, to Google and to its time.

(A code it does not take is a 400 of Google's.)

## AccountsAuth.answer

The client's attempts first: a client over its limit counts
against no username. Then this username's from this client
(its address, which holds no space, ahead of the name): a
username's attempts from elsewhere are their own, so guessing
wrong locks no one else out.

(Each costs two requests of GitHub.)

## AccountsAuth.device

A program that shows no page begins to be signed in: its code, of
letters alone and shown in two halves, and its secret.

(A code is one of 25 thousand million; one that another program
waits under is not kept, and another is tried.)

## AccountsAuth.device_answer

The caller's answer for the program showing `code`, as they typed it:
in either case, with or without what parts its halves. What one account
may answer is counted, so no one finds a code by trying them.

## AccountsAuth.token_for

A new session for `user`: its token.

## AccountsAuth.end

End the session `credential` names, if it is one.

## AccountsAuth.register

(Hashed before the book is asked: it takes a while, by design.)

## AccountsAuth.password_kept

`password` as the book keeps it: Rejected for one that is too short.

## AccountsAuth.mails

Whether links are mailed here: where the program sends mail, and the
app says where it is reached, which a link names. Never to the people
at an app's machine, who have no address.

## AccountsAuth.mail_link

Mail `email`, the address of the account `user`, a link for
`purpose` ("check" or "reset"), which lasts as long as such a link
does. A letter not sent is the program's to say: the caller is told
nothing different.

## AccountsAuth.mailed

The program it was opened in, which sends its mail.

## AccountsAuth.mail_check

The caller's address is mailed a link that checks it; one with none
gives itself `address` first.

## AccountsAuth.forgot

The account `name` names (its username or its address) is mailed a
link that sets a new password, where it has an address and was mailed
no more than its share of links lately. What the caller sees is the same
in every case. (That an address has an account a registration says,
which refuses it.)

## AccountsAuth.login

A session for the account `username` (or its email) names, if
`password` is its password. An unknown account costs the same hash, so the
time taken doesn't say which accounts exist.

## AccountsAuth.external

A session for the user `provider` (a name of a-z, 0-9, `_` and `-`)
knows as `external_id` and calls `name`, their account made the first
time: its user ID is `provider:external_id`.

## AccountsAuth.externals

Each user `provider` knows, by its ID for them, in the order their
accounts were made.

## asked_json

What the service at `url` answers a request with `headers`, a JSON
object: a POST of `body` when there is one. OSError where it is not reached
or refuses, ValueError for an answer that is not one.

## an_address

`email`, an address an account may have: Rejected for one that is none.

## token_key

What a book keeps of a session's token, and of a link's.

## password_record

How a book keeps `password`: `pbkdf2_sha256$<rounds>$<salt>$<key>`, the
salt fresh and both in hex.

## password_matches

Whether `password` is the one `record` keeps, compared in constant time.
