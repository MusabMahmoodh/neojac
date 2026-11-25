import from "@jac/runtime" {
    RemoteRejected,
    sign_in,
    sign_out,
    signed_in_name,
    __removeLocalStorage,
}

obj Session {
    has loggedIn: bool,
        checking: bool,
        username: str,
        error: str,
        busy: bool,
        login: Callable[[], Coroutine[any, any, None]],
        logout: Callable[[], Coroutine[any, any, None]];
}

def useSession -> Session;
