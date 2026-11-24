import from "@jac/mobui" {
    View,
    Text,
    Pressable,
    ActivityIndicator,
    ScrollView,
    StatusBar,
    useWindowDimensions,
}
def AuthScreen(
    error: str,
    loading: bool,
    onSignIn: Callable[[], Coroutine[any, any, None]],
    embedded: bool = False,
) -> JsxElement;
