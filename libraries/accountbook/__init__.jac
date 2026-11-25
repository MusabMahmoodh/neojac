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
    AuthSettings,
    DeviceSignIn,
    Rejected,
    Session,
    SignIn,
    SignInAction,
    SignInField,
    bearer_token,
}

glob USERNAME: str = "[a-z0-9][a-z0-9._-]{2,31}",
     LOGIN_PER_USER: int = 5,
     LOGIN_PER_CLIENT: int = 30,
     REGISTER_PER_CLIENT: int = 10,
     LIMIT_SECONDS: int = 900,
     AWAY_SECONDS: int = 600,
     SERVICE_SECONDS: float = 20.0,
     DEVICE_SECONDS: int = 600,
     DEVICE_EVERY: int = 2,
     DEVICE_PER_CLIENT: int = 30,
     DEVICE_PER_USER: int = 10,
     DEVICE_LETTERS: str = "BCDFGHJKLMNPQRSTVWXZ",
     DEVICE_LENGTH: int = 8,
     CLOSED: str = "this app makes no new accounts: ask whoever runs it for one",
     GOOGLE_ISSUERS: list[str] = ["https://accounts.google.com", "accounts.google.com"],
     VOUCHING: list[str] = ["github", "google"],
     CHECK_SECONDS: int = 86400,
     RESET_SECONDS: int = 3600,
     MAIL_PER_USER: int = 3,
     FORGOT_PER_CLIENT: int = 10,
     FOLLOW_PER_CLIENT: int = 30,
     NO_MAIL: str = "this app mails no links",
     NO_LINK: str = "this link was followed already, or is too old: ask for another";

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

obj AccountsAuth(Auth, AuthSettings) {
    has rounds: int = 600000;

    has book: dyn Book | None postinit,
        host: dyn AuthHost | None postinit,
        data_dir: str postinit,
        windowed: bool postinit,
        github_client: str postinit,
        github_client_secret: str postinit,
        google_client: str postinit,
        google_client_secret: str postinit,
        sending: bool postinit;

    def postinit;
    def open_book(host: dyn AuthHost) -> dyn Book abst;

    def open(host: dyn AuthHost);
    def kept -> dyn Book;
    def tried(scope: str, actor: str, limit: int, seconds: int) -> int;
    def local -> bool;
    def local_file -> str;
    def local_now -> str;
    def caller(headers: dict[str, str]) -> str | None;
    def asks(headers: dict[str, str]) -> SignIn;
    def needs_address -> bool;
    def github_offered -> bool;
    def github_back -> str;
    def google_offered -> bool;
    def google_back -> str;
    def away_mark(way: str, expires: int, verifier: str) -> str;
    def away(way: str, label: str, place: str, query: dict[str, str]) -> SignInAction;
    def came_back(way: str, service: str, given: dict[str, str]) -> str;
    def github_action -> SignInAction;
    def github_answer(given: dict[str, str]) -> Session;
    def google_action -> SignInAction;
    def google_answer(given: dict[str, str]) -> Session;

    def answer(action: str, given: dict[str, str], client: str) -> Session;
    def device(client: str) -> DeviceSignIn;
    def device_answer(headers: dict[str, str], code: str, allow: bool);

    def device_session(secret: str) -> Session | None;

    def leave(headers: dict[str, str]);
    def token_for(user: str) -> str;
    def end(credential: str);

    def register(username: str, email: str, password: str) -> Session;
    def password_kept(password: str) -> str;
    def mails -> bool;

    def checked(user: str) -> bool;
    def mail_link(user: str, email: str, purpose: str);
    def mailed -> dyn AuthHost;
    def mail_check(headers: dict[str, str], address: str);

    def check(token: str, client: str);
    def forgot(name: str, client: str);

    def reset(token: str, password: str, client: str) -> Session;
    def login(username: str, password: str) -> Session;
    def external(provider: str, external_id: str, name: str = "") -> Session;
    def externals(provider: str) -> list[str];
}

def asked_json(url: str, headers: dict[str, str], body: bytes | None = None) -> dict[str, any];
def an_address(email: str);
def token_key(token: str) -> str;
def password_record(password: str, rounds: int) -> str;
def password_matches(password: str, record: str) -> bool;
