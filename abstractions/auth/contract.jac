import from common.contract { Host, Secret }

obj SignInField {
    has name: str,
        label: str = "",
        secret: bool = False,
        choices: list[str] = [];
}

obj SignInAction {
    has name: str,
        label: str = "",
        needs: list[str] = [],
        redirect: str = "",
        keeps: dict[str, str] = {};
}

obj Session {
    has user: str,
        token: str = "",
        name: str = "";
}

obj SignIn {
    has fields: list[SignInField] = [],
        actions: list[SignInAction] = [],
        redirect: str = "",
        session: Session | None = None,
        forgot: str = "";
}

obj DeviceSignIn {
    has code: str,
        secret: str,
        lasts: int,
        every: int;
}

obj Rejected(Exception) {
    has detail: str,
        retry_after: int = 0;

    def __str__ -> str;
}

obj AuthSettings {
    has session_seconds: float = 604800.0,
        local_users: bool = False,
        email_required: bool = False,
        registration: bool = True,
        origin: str = "",
        github: str = "https://github.com",
        github_api: str = "https://api.github.com",
        github_id: Secret = Secret(variable="SSO_GITHUB_CLIENT_ID"),
        github_secret: Secret = Secret(variable="SSO_GITHUB_CLIENT_SECRET"),
        google: str = "https://accounts.google.com",
        google_api: str = "https://oauth2.googleapis.com",
        google_id: Secret = Secret(variable="SSO_GOOGLE_CLIENT_ID"),
        google_secret: Secret = Secret(variable="SSO_GOOGLE_CLIENT_SECRET");
}

obj AuthHost(Host) {
    def windowed -> bool abst;
    def consume_limit(scope: str, actor: str, limit: int, seconds: int) -> int abst;
    def sends_mail -> bool abst;
    def send_mail(to: str, subject: str, text: str) abst;
}

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

def bearer_token(headers: dict[str, str]) -> str;
