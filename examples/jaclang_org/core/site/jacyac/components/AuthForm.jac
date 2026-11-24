import from "lucide-react" { AlertCircle }
def:pub AuthForm(
    error: str, loading: bool, onSignIn: Callable[[], Coroutine[any, any, None]]
) -> JsxElement;
