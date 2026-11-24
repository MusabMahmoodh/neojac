"""Accounts of a username and a password, and their sessions, over a book
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
  (GitHub, Google) is checked as it is."""

import base64;
import hashlib;
import hmac;
import json;
import os;
import re;
import secrets;
import time;
import urllib.request;
import from urllib.error { HTTPError }
import from urllib.parse { urlencode, urlsplit }
import from auth.contract {
    Auth,
    AuthHost,
    DeviceSignIn,
    Rejected,
    Session,
    SignIn,
    SignInAction,
    SignInField,
    bearer_token,
}
import from common.contract { Secret }

glob USERNAME: str = "[a-z0-9][a-z0-9._-]{2,31}",
     # Sign-in attempts allowed in each LIMIT_SECONDS: for one username (or
     # email) from one client address, and from one client address in all;
     # and registrations from one client address. Each attempt costs a
     # password hash.
     LOGIN_PER_USER: int = 5,
     LOGIN_PER_CLIENT: int = 30,
     REGISTER_PER_CLIENT: int = 10,
     LIMIT_SECONDS: int = 900,
     # How long a caller sent to another service has to come back, and how
     # long that service is waited for, in seconds.
     AWAY_SECONDS: int = 600,
     SERVICE_SECONDS: float = 20.0,
     # A program that shows no page: how long it waits to be signed in, and
     # how long it leaves between asking whether it is, in seconds; how many
     # may begin from one client address in each LIMIT_SECONDS, and how many
     # codes one account may answer; and the letters of a code, which are
     # the consonants no one takes for another or reads a word in.
     DEVICE_SECONDS: int = 600,
     DEVICE_EVERY: int = 2,
     DEVICE_PER_CLIENT: int = 30,
     DEVICE_PER_USER: int = 10,
     DEVICE_LETTERS: str = "BCDFGHJKLMNPQRSTVWXZ",
     DEVICE_LENGTH: int = 8,
     # What one the app does not know is told where they may not make
     # themselves an account.
     CLOSED: str = "this app makes no new accounts: ask whoever runs it for one",
     # Who writes the ID token Google's token endpoint gives: the two ways it
     # writes itself
     # (https://developers.google.com/identity/openid-connect/openid-connect#validatinganidtoken).
     GOOGLE_ISSUERS: list[str] = ["https://accounts.google.com", "accounts.google.com"],
     # The services whose accounts' addresses are checked as they are: each
     # says only an address that is someone's.
     VOUCHING: list[str] = ["github", "google"],
     # How long a link mailed to check an address lasts, and one that sets a
     # password, in seconds; how many links one account is mailed in each
     # LIMIT_SECONDS; how many asks for a password's link one client address
     # makes, and how many links it follows (each a password's hash, for a
     # reset).
     CHECK_SECONDS: int = 86400,
     RESET_SECONDS: int = 3600,
     MAIL_PER_USER: int = 3,
     FORGOT_PER_CLIENT: int = 10,
     FOLLOW_PER_CLIENT: int = 30,
     # What a step that mails is refused with where nothing is mailed.
     NO_MAIL: str = "this app mails no links",
     # What a link that is not one, is used or is too old is refused with.
     NO_LINK: str = "this link was followed already, or is too old: ask for another";

"""Where accounts are kept, as `AccountsAuth` asks it. Each method is one
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
  a key that names no such link."""
obj Book {
    def session(key: str) -> tuple[str, float] | None abst;
    def begin(key: str, user: str, expires: float, now: float) abst;
    def end(key: str) abst;
    def account(name: str) -> tuple[str, str] | None abst;
    def add(username: str, email: str, password: str, now: float) -> bool abst;
    def known(provider: str, external_id: str) -> str abst;
    def identity(provider: str, external_id: str, user: str, now: float) -> str abst;
    def identities(provider: str) -> list[str] abst;
    def away_key -> bytes abst;
    def expect(code: str, key: str, expires: float, now: float) -> bool abst;
    def decide(code: str, user: str, now: float) -> bool abst;
    def collect(key: str, now: float) -> tuple[bool, str] | None abst;
    def address(user: str) -> tuple[str, bool] abst;
    def give_address(user: str, email: str) -> bool abst;
    def link(key: str, user: str, purpose: str, expires: float, now: float) abst;
    def check(key: str, now: float) -> str abst;
    def reset(key: str, password: str, now: float) -> str abst;
}

"""An `auth` plugin's class, but for `open_book`, which the plugin gives: its
fields are the plugin's settings, beside the plugin's own."""
obj AccountsAuth(Auth) {
    # How a password is kept: PBKDF2-HMAC-SHA256 with a salt of its own, at
    # OWASP's 600,000 rounds. A hash keeps its rounds, so raising this
    # applies to a password when it is next set.
    has rounds: int = 600000,
        # How long a session lasts: a week.
        session_seconds: float = 604800.0,
        # Whether the people at the machine are the users of an app in a
        # window of its own, with no password.
        local_users: bool = False,
        # Whether an account is made only with an email address.
        email_required: bool = False,
        # Whether one the app does not know may make themselves an account:
        # by registering, or by signing in through another service for the
        # first time. Where they may not, the accounts are the ones there
        # are, and whoever runs the app makes any other.
        registration: bool = True,
        # A GitHub OAuth app's client ID and secret: signing in through
        # GitHub is offered where both are given.
        github_id: Secret = Secret(variable="SSO_GITHUB_CLIENT_ID"),
        github_secret: Secret = Secret(variable="SSO_GITHUB_CLIENT_SECRET"),
        # Where GitHub is, and its API: another for GitHub Enterprise.
        github: str = "https://github.com",
        github_api: str = "https://api.github.com",
        # A Google OAuth client's ID and secret: signing in through Google
        # is offered where both are given, and `origin`.
        google_id: Secret = Secret(variable="SSO_GOOGLE_CLIENT_ID"),
        google_secret: Secret = Secret(variable="SSO_GOOGLE_CLIENT_SECRET"),
        # Where Google signs a caller in, and where its tokens are had.
        google: str = "https://accounts.google.com",
        google_api: str = "https://oauth2.googleapis.com",
        # Where callers reach the app (`https://example.org`), for the place
        # another service sends them back to. Not said, they are sent to the
        # callback the service has registered: GitHub's has one, and
        # Google is not offered.
        origin: str = "";

    # Where the accounts are kept, once it is opened.
    has book: dyn Book | None postinit;
    # The program it was opened in, and what that says of it: the app's
    # data directory, and whether the app shows itself in a window.
    has host: dyn AuthHost | None postinit;
    has data_dir: str postinit;
    has windowed: bool postinit;
    # The GitHub OAuth app's and the Google OAuth client's IDs and secrets,
    # as the program gives them: "" for one it gives none of.
    has github_client: str postinit;
    has github_client_secret: str postinit;
    has google_client: str postinit;
    has google_client_secret: str postinit;
    # Whether the program sends mail, as it said when it was opened.
    has sending: bool postinit;

    def postinit {
        self.book = None;
        self.host = None;
        self.data_dir = "";
        self.windowed = False;
        self.github_client = "";
        self.github_client_secret = "";
        self.google_client = "";
        self.google_client_secret = "";
        self.sending = False;
    }

    """The book the accounts are kept in, made ready in the program `host`:
    what a plugin gives. DataError (`common.contract`) for one it can't start
    with."""
    def open_book(host: dyn AuthHost) -> dyn Book abst;

    def open(host: dyn AuthHost) {
        self.host = host;
        self.data_dir = host.data_dir();
        self.windowed = host.windowed();
        self.github_client = host.secret(self.github_id);
        self.github_client_secret = host.secret(self.github_secret);
        self.google_client = host.secret(self.google_id);
        self.google_client_secret = host.secret(self.google_secret);
        self.sending = host.sends_mail();
        self.book = self.open_book(host);
    }

    """The book the accounts are kept in: asked for once they were opened."""
    def kept -> dyn Book {
        book = self.book;
        if book is None {
            raise RuntimeError("accounts was asked before it was opened");
        }
        return book;
    }

    """Counts a use of `scope` by `actor` with the program's limits: how many
    seconds until it is within `limit` uses in `seconds`, 0 while it is."""
    def tried(scope: str, actor: str, limit: int, seconds: int) -> int {
        host = self.host;
        if host is None {
            raise RuntimeError("accounts was asked before it was opened");
        }
        return host.consume_limit(scope, actor, limit, seconds);
    }

    """Whether this app takes the people at its machine as its users: one in
    a window of its own, asked to."""
    def local -> bool {
        return self.local_users and self.windowed;
    }

    """Where an app with local users keeps who is using it now."""
    def local_file -> str {
        return os.path.join(self.data_dir, "local-user");
    }

    """Who of the app's local users is using it now: "" for no one."""
    def local_now -> str {
        try {
            with open(self.local_file()) as f {
                name = f.read().strip();
                return name if name in self.externals("local") else "";
            }
        } except OSError {
            return "";
        }
    }

    """The user ID the session a request carries names, while the session
    lasts."""
    def caller(headers: dict[str, str]) -> str | None {
        credential = bearer_token(headers);
        if credential == "" {
            return None;
        }
        key = token_key(credential);
        held = self.kept().session(key);
        if held is None {
            return None;
        }
        (user, expires) = held;
        if expires <= time.time() {
            self.kept().end(key);
            return None;
        }
        return user;
    }

    """A username and a password, to sign in or to make an account; or, for
    an app with local users, the name of who is at the machine, and a
    session at once for the one who was there last."""
    def asks(headers: dict[str, str]) -> SignIn {
        if self.local() {
            now = self.local_now();
            if now != "" {
                return SignIn(session=self.external("local", now, now));
            }
            return SignIn(
                fields=[
                    SignInField(name="name", label="Your name", choices=self.externals("local")),
                ],
                actions=[SignInAction(name="local", label="Continue", needs=["name"])],
            );
        }
        actions = [SignInAction(name="login", label="Sign in", needs=["username", "password"])];
        if self.registration {
            actions.append(
                SignInAction(
                    name="register", label="Create account", needs=["username", "email", "password"]
                ),
            );
        }
        if self.github_offered() {
            actions.append(self.github_action());
        }
        if self.google_offered() {
            actions.append(self.google_action());
        }
        return SignIn(
            fields=[
                SignInField(name="username", label="Username"),
                SignInField(
                    name="email", label="Email" if self.needs_address() else "Email (optional)"
                ),
                SignInField(name="password", label="Password", secret=True),
            ],
            actions=actions,
            forgot="username" if self.mails() else "",
        );
    }

    """Whether an account is made only with an address: where it is said
    to be, and where an address is checked."""
    def needs_address -> bool {
        return self.email_required or self.mails();
    }

    """Whether a caller may sign in through GitHub: where the program runs
    gives the OAuth app's client ID and its secret."""
    def github_offered -> bool {
        return self.github_client != "" and self.github_client_secret != "";
    }

    """Where GitHub sends a caller back to, when this app says where it is
    reached: "" for the callback the OAuth app registers."""
    def github_back -> str {
        return self.origin.rstrip("/") + "/__jac/auth/github" if self.origin != "" else "";
    }

    """Whether a caller may sign in through Google: where the program runs
    gives the OAuth client's ID and its secret, and the app says where it is
    reached, which Google is told to send them back to."""
    def google_offered -> bool {
        return self.google_client != "" and self.google_client_secret != "" and self.origin != "";
    }

    """Where Google sends a caller back to: its client's redirect URI."""
    def google_back -> str {
        return self.origin.rstrip("/") + "/__jac/auth/google";
    }

    """What signs a `state` of the way `way` that lasts until `expires` for
    the page that keeps `verifier`, with the book's key."""
    def away_mark(way: str, expires: int, verifier: str) -> str {
        said = (way + "." + str(expires) + "." + verifier).encode("utf-8");
        return hmac.new(self.kept().away_key(), said, hashlib.sha256).hexdigest();
    }

    """Signing in by `way` at another service: its page `place` with
    `query`, a `state` only the book's key makes, and a verifier the page
    that leaves keeps. The service is given the verifier's hash now and the
    verifier when the caller is back (PKCE), and the state is signed over
    it: so the session is given to the page that left, and never to one that
    was only handed the way back."""
    def away(way: str, label: str, place: str, query: dict[str, str]) -> SignInAction {
        verifier = secrets.token_urlsafe(48);
        expires = int(time.time()) + AWAY_SECONDS;
        query["state"] = str(expires) + "." + self.away_mark(way, expires, verifier);
        query["code_challenge"] = base64.urlsafe_b64encode(
            hashlib.sha256(verifier.encode("ascii")).digest()
        ).decode("ascii").rstrip("=");
        query["code_challenge_method"] = "S256";
        return SignInAction(
            name=way,
            label=label,
            redirect=place + "?" + urlencode(query),
            keeps={"verifier": verifier},
        );
    }

    """The verifier the page that left by `way` kept, where `given`, what the
    caller came back from `service` with, shows that page is theirs and was
    left long enough ago; Rejected otherwise, and where they were turned
    away there."""
    def came_back(way: str, service: str, given: dict[str, str]) -> str {
        if given.get("error", "") != "" {
            raise Rejected(detail=f"signing in through {service} was turned away there");
        }
        verifier = given.get("verifier", "");
        (expires_said, dot, mark) = given.get("state", "").partition(".");
        if dot == ""
            or not expires_said.isdigit()
            or verifier == ""
            or not hmac.compare_digest(mark, self.away_mark(way, int(expires_said), verifier))
        {
            raise Rejected(detail="this sign-in was not begun here: try again");
        }
        if int(expires_said) < time.time() {
            raise Rejected(detail="this sign-in took too long: try again");
        }
        return verifier;
    }

    """Signing in through GitHub, at its OAuth app's page."""
    def github_action -> SignInAction {
        query: dict[str, str] = {"client_id": self.github_client};
        back = self.github_back();
        if back != "" {
            query["redirect_uri"] = back;
        }
        return self.away(
            "github",
            "Continue with GitHub",
            self.github.rstrip("/") + "/login/oauth/authorize",
            query,
        );
    }

    """The session of the GitHub user a caller came back as: `given` holds
    the `code` and `state` GitHub sent them back with, and the `verifier`
    their page kept."""
    def github_answer(given: dict[str, str]) -> Session {
        verifier = self.came_back("github", "GitHub", given);
        exchange: dict[str, str] = {
            "client_id": self.github_client,
            "client_secret": self.github_client_secret,
            "code": given.get("code", ""),
            "code_verifier": verifier,
        };
        back = self.github_back();
        if back != "" {
            exchange["redirect_uri"] = back;
        }
        try {
            got = asked_json(
                self.github.rstrip("/") + "/login/oauth/access_token",
                {"Accept": "application/json"},
                urlencode(exchange).encode("utf-8"),
            );
            access = str(got.get("access_token", ""));
            if access == "" {
                raise Rejected(detail="GitHub did not accept the sign-in");
            }
            me = asked_json(
                self.github_api.rstrip("/") + "/user",
                {
                    "Authorization": "Bearer " + access,
                    "Accept": "application/vnd.github+json",
                    "User-Agent": "neojac-accounts",
                },
            );
        } except OSError {
            raise Rejected(detail="GitHub could not be reached: try again");
        } except ValueError {
            raise Rejected(detail="GitHub's answer could not be read: try again");
        }
        if "id" not in me {
            raise Rejected(detail="GitHub did not say who signed in");
        }
        return self.external("github", str(me["id"]), str(me.get("login", "")));
    }

    """Signing in through Google, at its page that asks the person which of
    their accounts, and their address (OpenID Connect's code flow)."""
    def google_action -> SignInAction {
        return self.away(
            "google",
            "Continue with Google",
            self.google.rstrip("/") + "/o/oauth2/v2/auth",
            {
                "client_id": self.google_client,
                "redirect_uri": self.google_back(),
                "response_type": "code",
                "scope": "openid email",
            },
        );
    }

    """The session of the Google account a caller came back as: `given`
    holds the `code` and `state` Google sent them back with, and the
    `verifier` their page kept. Who they are is the ID token Google's token
    endpoint gives for the code: read as it comes, over TLS straight from
    Google, which stands for its signature (OpenID Connect Core 1.0,
    3.1.3.7), and held to this client, to Google and to its time."""
    def google_answer(given: dict[str, str]) -> Session {
        verifier = self.came_back("google", "Google", given);
        exchange: dict[str, str] = {
            "client_id": self.google_client,
            "client_secret": self.google_client_secret,
            "code": given.get("code", ""),
            "code_verifier": verifier,
            "grant_type": "authorization_code",
            "redirect_uri": self.google_back(),
        };
        try {
            got = asked_json(
                self.google_api.rstrip("/") + "/token",
                {"Accept": "application/json"},
                urlencode(exchange).encode("utf-8"),
            );
            parts = str(got.get("id_token", "")).split(".");
            if len(parts) != 3 {
                raise Rejected(detail="Google did not accept the sign-in");
            }
            said: any = json.loads(
                base64.urlsafe_b64decode(parts[1] + "=" * (-len(parts[1]) % 4)).decode("utf-8")
            );
        } except HTTPError {
            # (A code it does not take is a 400 of Google's.)
            raise Rejected(detail="Google did not accept the sign-in");
        } except OSError {
            raise Rejected(detail="Google could not be reached: try again");
        } except ValueError {
            raise Rejected(detail="Google's answer could not be read: try again");
        }
        if not isinstance(said, dict) {
            raise Rejected(detail="Google's answer could not be read: try again");
        }
        token: dict[str, any] = said;
        expires: any = token.get("exp", 0);
        if str(token.get("iss", "")) not in GOOGLE_ISSUERS
            or str(token.get("aud", "")) != self.google_client
            or not isinstance(expires, (int, float))
            or float(expires) < time.time()
        {
            raise Rejected(detail="Google's answer was not for this app: try again");
        }
        if str(token.get("sub", "")) == "" {
            raise Rejected(detail="Google did not say who signed in");
        }
        return self.external("google", str(token["sub"]), str(token.get("email", "")));
    }

    def answer(action: str, given: dict[str, str], client: str) -> Session {
        name = given.get("username", "");
        retry = 0;
        if action == "local" and self.local() {
            who = given.get("name", "").strip();
            s = self.external("local", who, who);
            os.makedirs(self.data_dir, exist_ok=True);
            with open(self.local_file(), "w") as f {
                f.write(who + "\n");
            }
            return s;
        }
        if action == "login" {
            # The client's attempts first: a client over its limit counts
            # against no username. Then this username's from this client
            # (its address, which holds no space, ahead of the name): a
            # username's attempts from elsewhere are their own, so guessing
            # wrong locks no one else out.
            retry = self.tried("login", "client " + client, LOGIN_PER_CLIENT, LIMIT_SECONDS);
            if retry == 0 {
                retry = self.tried(
                    "login",
                    "user " + client + " " + name.strip().lower(),
                    LOGIN_PER_USER,
                    LIMIT_SECONDS,
                );
            }
        } elif action == "register" and self.registration {
            retry = self.tried("register", client, REGISTER_PER_CLIENT, LIMIT_SECONDS);
        } elif action == "register" {
            raise Rejected(detail=CLOSED);
        } elif action == "github" and self.github_offered() {
            # (Each costs two requests of GitHub.)
            retry = self.tried("github", client, LOGIN_PER_CLIENT, LIMIT_SECONDS);
        } elif action == "google" and self.google_offered() {
            retry = self.tried("google", client, LOGIN_PER_CLIENT, LIMIT_SECONDS);
        } else {
            raise Rejected(detail=f"no way of signing in is '{action}'");
        }
        if retry > 0 {
            raise Rejected(detail="too many attempts: try again later", retry_after=retry);
        }
        if action == "login" {
            return self.login(name, given.get("password", ""));
        }
        if action == "github" {
            return self.github_answer(given);
        }
        if action == "google" {
            return self.google_answer(given);
        }
        return self.register(name, given.get("email", ""), given.get("password", ""));
    }

    """A program that shows no page begins to be signed in: its code, of
    letters alone and shown in two halves, and its secret."""
    def device(client: str) -> DeviceSignIn {
        retry = self.tried("device", client, DEVICE_PER_CLIENT, LIMIT_SECONDS);
        if retry > 0 {
            raise Rejected(detail="too many attempts: try again later", retry_after=retry);
        }
        now = time.time();
        secret = secrets.token_hex(32);
        # (A code is one of 25 thousand million; one that another program
        # waits under is not kept, and another is tried.)
        for attempt in range(8) {
            code = "".join([secrets.choice(DEVICE_LETTERS) for k in range(DEVICE_LENGTH)]);
            if self.kept().expect(code, token_key(secret), now + DEVICE_SECONDS, now) {
                half = DEVICE_LENGTH // 2;
                return DeviceSignIn(
                    code=code[:half] + "-" + code[half:],
                    secret=secret,
                    lasts=DEVICE_SECONDS,
                    every=DEVICE_EVERY,
                );
            }
        }
        raise Rejected(detail="no code could be made: try again");
    }

    """The caller's answer for the program showing `code`, as they typed it:
    in either case, with or without what parts its halves. What one account
    may answer is counted, so no one finds a code by trying them."""
    def device_answer(headers: dict[str, str], code: str, allow: bool) {
        who = self.caller(headers);
        if who is None {
            raise Rejected(detail="sign in first");
        }
        retry = self.tried("device code", "user " + who, DEVICE_PER_USER, LIMIT_SECONDS);
        if retry > 0 {
            raise Rejected(detail="too many attempts: try again later", retry_after=retry);
        }
        said = "".join([c for c in code.upper() if c in DEVICE_LETTERS]);
        if not self.kept().decide(said, who if allow else "", time.time()) {
            raise Rejected(
                detail="no program is waiting with that code: check it, or begin again from the program",
            );
        }
    }

    def device_session(secret: str) -> Session | None {
        found = self.kept().collect(token_key(secret), time.time());
        if found is None {
            raise Rejected(detail="this sign-in waited too long, or was never begun: begin again");
        }
        (answered, user) = found;
        if not answered {
            return None;
        }
        if user == "" {
            raise Rejected(detail="this sign-in was turned away");
        }
        return Session(user=user, token=self.token_for(user));
    }

    def leave(headers: dict[str, str]) {
        self.end(bearer_token(headers));
        if self.local() and os.path.exists(self.local_file()) {
            os.remove(self.local_file());
        }
    }

    """A new session for `user`: its token."""
    def token_for(user: str) -> str {
        now = time.time();
        t = secrets.token_hex(32);
        self.kept().begin(token_key(t), user, now + self.session_seconds, now);
        return t;
    }

    """End the session `credential` names, if it is one."""
    def end(credential: str) {
        self.kept().end(token_key(credential));
    }

    def register(username: str, email: str, password: str) -> Session {
        u = username.strip().lower();
        if re.fullmatch(USERNAME, u) is None {
            raise Rejected(
                detail="a username is 3 to 32 letters, digits, '.', '_' or '-', starting with a letter or a digit",
            );
        }
        e = email.strip().lower();
        if e == "" and self.needs_address() {
            raise Rejected(detail="an account needs an email address");
        }
        if e != "" {
            an_address(e);
        }
        # (Hashed before the book is asked: it takes a while, by design.)
        record = self.password_kept(password);
        if not self.kept().add(u, e, record, time.time()) {
            raise Rejected(detail="that username or email is taken");
        }
        if self.mails() {
            self.mail_link(u, e, "check");
        }
        return Session(user=u, token=self.token_for(u));
    }

    """`password` as the book keeps it: Rejected for one that is too short."""
    def password_kept(password: str) -> str {
        if len(password) < 8 {
            raise Rejected(detail="a password has at least 8 characters");
        }
        return password_record(password, self.rounds);
    }

    """Whether links are mailed here: where the program sends mail, and the
    app says where it is reached, which a link names. Never to the people
    at an app's machine, who have no address."""
    def mails -> bool {
        return self.sending and self.origin != "" and not self.local();
    }

    def checked(user: str) -> bool {
        (provider, colon, rest) = user.partition(":");
        if colon != "" {
            return provider in VOUCHING;
        }
        return self.kept().address(user)[1];
    }

    """Mail `email`, the address of the account `user`, a link for
    `purpose` ("check" or "reset"), which lasts as long as such a link
    does. A letter not sent is the program's to say: the caller is told
    nothing different."""
    def mail_link(user: str, email: str, purpose: str) {
        token = secrets.token_hex(32);
        now = time.time();
        lasts = CHECK_SECONDS if purpose == "check" else RESET_SECONDS;
        self.kept().link(token_key(token), user, purpose, now + lasts, now);
        site = self.origin.rstrip("/");
        place = urlsplit(site).netloc or site;
        link = f"{site}/__jac/auth/{purpose}#{token}";
        if purpose == "check" {
            self.mailed().send_mail(
                email,
                f"Check your address at {place}",
                f"Follow this link within a day to check that this address is yours, for the account {user} at {site}:\n\n{link}\n\nIf you made no such account, do nothing.\n",
            );
        } else {
            self.mailed().send_mail(
                email,
                f"Set a new password at {place}",
                f"Follow this link within an hour to set a new password for the account {user} at {site}:\n\n{link}\n\nIf you did not ask for one, do nothing: the password stays as it is.\n",
            );
        }
    }

    """The program it was opened in, which sends its mail."""
    def mailed -> dyn AuthHost {
        host = self.host;
        if host is None {
            raise RuntimeError("accounts was asked before it was opened");
        }
        return host;
    }

    """The caller's address is mailed a link that checks it; one with none
    gives itself `address` first."""
    def mail_check(headers: dict[str, str], address: str) {
        if not self.mails() {
            raise Rejected(detail=NO_MAIL);
        }
        who = self.caller(headers);
        if who is None {
            raise Rejected(detail="sign in first");
        }
        if ":" in who {
            raise Rejected(
                detail="this account is one another service vouches for, and has no address to check here",
            );
        }
        retry = self.tried("mail", "user " + who, MAIL_PER_USER, LIMIT_SECONDS);
        if retry > 0 {
            raise Rejected(detail="too many attempts: try again later", retry_after=retry);
        }
        (email, ok) = self.kept().address(who);
        given = address.strip().lower();
        if ok {
            raise Rejected(detail="this account's address is checked already");
        }
        if email == "" {
            if given == "" {
                raise Rejected(detail="this account has no address: give it one");
            }
            an_address(given);
            if not self.kept().give_address(who, given) {
                raise Rejected(detail="that email is taken");
            }
            email = given;
        } elif given != "" and given != email {
            raise Rejected(detail="this account has an address already");
        }
        self.mail_link(who, email, "check");
    }

    def check(token: str, client: str) {
        if not self.mails() {
            raise Rejected(detail=NO_MAIL);
        }
        retry = self.tried("follow", client, FOLLOW_PER_CLIENT, LIMIT_SECONDS);
        if retry > 0 {
            raise Rejected(detail="too many attempts: try again later", retry_after=retry);
        }
        if self.kept().check(token_key(token), time.time()) == "" {
            raise Rejected(detail=NO_LINK);
        }
    }

    """The account `name` names (its username or its address) is mailed a
    link that sets a new password, where it has an address and was mailed
    no more than its share of links lately. What the caller sees is the same
    in every case. (That an address has an account a registration says,
    which refuses it.)"""
    def forgot(name: str, client: str) {
        if not self.mails() {
            raise Rejected(detail=NO_MAIL);
        }
        retry = self.tried("forgot", client, FORGOT_PER_CLIENT, LIMIT_SECONDS);
        if retry > 0 {
            raise Rejected(detail="too many attempts: try again later", retry_after=retry);
        }
        found = self.kept().account(name.strip().lower());
        if found is None {
            return;
        }
        user = found[0];
        email = self.kept().address(user)[0];
        if email == "" or self.tried("mail", "user " + user, MAIL_PER_USER, LIMIT_SECONDS) > 0 {
            return;
        }
        self.mail_link(user, email, "reset");
    }

    def reset(token: str, password: str, client: str) -> Session {
        if not self.mails() {
            raise Rejected(detail=NO_MAIL);
        }
        retry = self.tried("follow", client, FOLLOW_PER_CLIENT, LIMIT_SECONDS);
        if retry > 0 {
            raise Rejected(detail="too many attempts: try again later", retry_after=retry);
        }
        record = self.password_kept(password);
        user = self.kept().reset(token_key(token), record, time.time());
        if user == "" {
            raise Rejected(detail=NO_LINK);
        }
        return Session(user=user, token=self.token_for(user));
    }

    """A session for the account `username` (or its email) names, if
    `password` is its password. An unknown account costs the same hash, so the
    time taken doesn't say which accounts exist."""
    def login(username: str, password: str) -> Session {
        u = username.strip().lower();
        user = "";
        record = "pbkdf2_sha256$" + str(self.rounds) + "$" + "00" * 16 + "$" + "00" * 32;
        found = self.kept().account(u);
        if found is not None {
            (user, record) = found;
        }
        if not password_matches(password, record) or user == "" {
            raise Rejected(detail="incorrect username or password");
        }
        return Session(user=user, token=self.token_for(user));
    }

    """A session for the user `provider` (a name of a-z, 0-9, `_` and `-`)
    knows as `external_id` and calls `name`, their account made the first
    time: its user ID is `provider:external_id`."""
    def external(provider: str, external_id: str, name: str = "") -> Session {
        if re.fullmatch("[a-z0-9_-]{1,32}", provider) is None
            or external_id == ""
            or len(external_id) > 256
        {
            raise Rejected(
                detail="an external identity is a provider's name and its ID for the user"
            );
        }
        if not self.registration and self.kept().known(provider, external_id) == "" {
            raise Rejected(detail=CLOSED);
        }
        user = self.kept().identity(
            provider, external_id, provider + ":" + external_id, time.time()
        );
        return Session(user=user, token=self.token_for(user), name=name);
    }

    """Each user `provider` knows, by its ID for them, in the order their
    accounts were made."""
    def externals(provider: str) -> list[str] {
        return self.kept().identities(provider);
    }
}

"""What the service at `url` answers a request with `headers`, a JSON
object: a POST of `body` when there is one. OSError where it is not reached
or refuses, ValueError for an answer that is not one."""
def asked_json(url: str, headers: dict[str, str], body: bytes | None = None) -> dict[str, any] {
    req = urllib.request.Request(url, data=body, headers=headers);
    with urllib.request.urlopen(req, timeout=SERVICE_SECONDS) as r {
        got: any = json.loads(r.read().decode("utf-8"));
    }
    if not isinstance(got, dict) {
        raise ValueError("not a JSON object");
    }
    made: dict[str, any] = got;
    return made;
}

"""`email`, an address an account may have: Rejected for one that is none."""
def an_address(email: str) {
    if len(email) > 254 or re.fullmatch(r"[^@\s]+@[^@\s]+", email) is None {
        raise Rejected(detail="that isn't an email address");
    }
}

"""What a book keeps of a session's token, and of a link's."""
def token_key(token: str) -> str {
    return hashlib.sha256(token.encode("utf-8")).hexdigest();
}

"""How a book keeps `password`: `pbkdf2_sha256$<rounds>$<salt>$<key>`, the
salt fresh and both in hex."""
def password_record(password: str, rounds: int) -> str {
    salt = secrets.token_bytes(16);
    key = hashlib.pbkdf2_hmac("sha256", password.encode("utf-8"), salt, rounds);
    return "pbkdf2_sha256$" + str(rounds) + "$" + salt.hex() + "$" + key.hex();
}

"""Whether `password` is the one `record` keeps, compared in constant time."""
def password_matches(password: str, record: str) -> bool {
    parts = record.split("$");
    if len(parts) != 4 or parts[0] != "pbkdf2_sha256" {
        raise ValueError("a password record of an unknown kind");
    }
    key = hashlib.pbkdf2_hmac(
        "sha256", password.encode("utf-8"), bytes.fromhex(parts[2]), int(parts[1])
    );
    return hmac.compare_digest(key, bytes.fromhex(parts[3]));
}
