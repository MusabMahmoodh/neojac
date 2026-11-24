"""The contract of the `auth` abstraction: `Auth`, the interface of the plugin
that says who a caller is and signs one in, what crosses it, and `AuthHost`,
what such a plugin may ask of the program it runs in."""

import from common.contract { Host }

"""Something a caller gives to sign in: its `name`, what a page calls it,
whether it is kept from sight as it is typed, and, when only some values are
taken, which."""
obj SignInField {
    has name: str,
        label: str = "",
        secret: bool = False,
        choices: list[str] = [];
}

"""A way of signing in a page offers: its `name`, which `Auth.answer` is
given, what a page calls it, and the fields it takes; or, for one done
elsewhere, the place to go, `redirect`, from which the caller comes back to
`/__jac/auth/<name>` with what that place gave them. What `keeps` holds
stays with the page that left, and is given to `Auth.answer` beside what the
caller came back with: so a plugin can tell the caller who left from one who
was only handed the way back."""
obj SignInAction {
    has name: str,
        label: str = "",
        needs: list[str] = [],
        redirect: str = "",
        keeps: dict[str, str] = {};
}

"""A caller signed in: who they are, the credential their calls carry from
now on ("" where the plugin knows a caller by something else its requests
carry), and what they are called, where that is not who they are (the name
another service knows them by)."""
obj Session {
    has user: str,
        token: str = "",
        name: str = "";
}

"""What signing in takes, as a page shows it: a form of `fields` with its
`actions`; or a place to go, `redirect`; or nothing, for a caller the plugin
knows already, whose `session` it is. `forgot` is the field whose value a
page gives `Auth.forgot`, for one who forgot their password: "" where the
plugin mails no link that sets one."""
obj SignIn {
    has fields: list[SignInField] = [],
        actions: list[SignInAction] = [],
        redirect: str = "",
        session: Session | None = None,
        forgot: str = "";
}

"""A program that shows no page, waiting to be signed in by someone at one:
the `code` it shows them, which they give the page; the `secret` it alone
holds, which it collects its session with; how many seconds the wait
`lasts`; and how many seconds it leaves between one asking and the next
(`every`)."""
obj DeviceSignIn {
    has code: str,
        secret: str,
        lasts: int,
        every: int;
}

"""A sign-in the plugin refuses, saying why: and, for one made too often, how
many seconds to wait."""
obj Rejected(Exception) {
    has detail: str,
        retry_after: int = 0;

    def __str__ -> str {
        return self.detail;
    }
}

"""What an `auth` plugin may ask of the program it runs in: what every
plugin may (`Host`), and

- `windowed`, whether the app shows itself in a window of its own, on its
  user's machine: where a plugin may know its one user without a password.
- `consume_limit`, which counts a use of `scope` by `actor` with the
  project's `limits`, and gives 0 while that is within `limit` uses in
  `seconds`, else the seconds until it is: how a plugin holds sign-ins to
  so many tries.
- `sends_mail`, whether the project's `mail` sends mail where the program
  runs.
- `send_mail`, which sends a letter of plain `text` to the address `to`
  with the project's `mail`. One that was not sent is said where the
  program says what went wrong, and to no caller: the plugin is told
  nothing different."""
obj AuthHost(Host) {
    def windowed -> bool abst;
    def consume_limit(scope: str, actor: str, limit: int, seconds: int) -> int abst;
    def sends_mail -> bool abst;
    def send_mail(to: str, subject: str, text: str) abst;
}

"""Who a caller is, and how one signs in: the interface of the `auth`
abstraction's plugins. `headers` are a request's, their names lowercased.

- `open` makes it ready, in the program `host`: the first thing asked of
  it. DataError (`common.contract`) for data it keeps that it can't start
  with.
- `caller` is who a request's caller is, or None for one it does not know.
- `asks` is what signing in takes, for a page to show.
- `answer` signs a caller in by `action` with what they gave, from the
  client at `client`: their session, or Rejected.
- `leave` ends the session a request carries.

A program that shows no page (a command in a terminal) is signed in by
someone at a page, who is signed in there and says the program is theirs.
These are the three steps of it, and each is Rejected by a plugin that signs
no such program in:

- `device` begins it, for the program at `client`: what the program shows
  and what it collects with.
- `device_answer` is the answer of a request's caller, who is signed in, for
  the program showing `code`: that it is theirs (`allow`), and gets a
  session of them, or that it is turned away. Rejected for a caller no one
  knows, and for a code no program waits under.
- `device_session` is the session of the program that holds `secret`, once:
  None while no one has answered, Rejected where it was turned away, or
  waited too long.

An account's address is checked by a link mailed to it, and a password set
again by one. A plugin that keeps addresses mails them where the program
sends mail (`AuthHost.sends_mail`) and knows where it is reached, which a
link names. These are what it says of them, and each step of them is
Rejected by a plugin that mails no links:

- `checked` is whether the address of the account `user` is checked: a link
  mailed to it was followed, or the account is one another service vouches
  for. False for a user no one knows, and for one with no address.
- `mails` is whether the plugin mails links: whether an account can be
  checked here at all.
- `mail_check` mails the address of a request's caller a link that checks
  it, which they followed none of yet. `address` is the address an account
  that has none gives itself, and "" for one that has one. Rejected for a
  caller no one knows, one checked already, and an address that is taken
  or is none.
- `check` checks the address the link that holds `token` was mailed to,
  for the client at `client`. Rejected for a token no link holds, or one
  too old.
- `forgot` mails the address of the account `name` names (its username, or
  the address) a link that sets a new password, for the client at
  `client`. It does the same, as the caller sees it, whether or not there
  is such an account, so nothing is learnt of which accounts there are.
- `reset` sets `password` for the account whose link holds `token`, for the
  client at `client`: the account's address is checked, every session of
  it ends, and the caller is given a new one. Rejected for a token no link
  holds, one too old, and a password the plugin refuses."""
obj Auth {
    def open(host: dyn AuthHost) abst;
    def caller(headers: dict[str, str]) -> str | None abst;
    def asks(headers: dict[str, str]) -> SignIn abst;
    def answer(action: str, given: dict[str, str], client: str) -> Session abst;
    def leave(headers: dict[str, str]) abst;
    def device(client: str) -> DeviceSignIn abst;
    def device_answer(headers: dict[str, str], code: str, allow: bool) abst;
    def device_session(secret: str) -> Session | None abst;
    def checked(user: str) -> bool abst;
    def mails -> bool abst;
    def mail_check(headers: dict[str, str], address: str) abst;
    def check(token: str, client: str) abst;
    def forgot(name: str, client: str) abst;
    def reset(token: str, password: str, client: str) -> Session abst;
}

"""The credential a request with `headers` carries as a bearer token, or ""."""
def bearer_token(headers: dict[str, str]) -> str {
    return headers.get("authorization", "").removeprefix("Bearer ").strip();
}
