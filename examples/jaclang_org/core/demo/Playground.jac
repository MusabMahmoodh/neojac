obj Tally {
    has total: int,
        bump: Callable[[int], None];
}

def use_tally(start: int) -> Tally;

def Row(label: str) -> JsxElement;

def Playground(lib: str, step: int = 2) -> JsxElement;
