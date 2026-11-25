import from "@jac/wasm_host" { bind_na_host }

obj Shim(WebGLHost) {
    has game: Game | None = None,
        on_tick: Callable[[int, float, int, int], None] | None = None,
        stopped: bool = True,
        session: int = 0,
        raf: float = 0.0;
}

glob _shim: Shim | None = None;
def _stop(sh: Shim, session: int);

async def _frame_tick(sh: Shim, session: int, ts: float);

async def _boot(sh: Shim, session: int);

def:pub run_game(
    canvas: HTMLCanvasElement, on_tick: Callable[[int, float, int, int], None] | None = None
) -> Callable[[], None];
