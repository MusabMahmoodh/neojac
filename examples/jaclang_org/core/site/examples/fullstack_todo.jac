node Todo {
    has title: str;
}

def:pub add_todo(title: str) -> Todo;

def:pub get_todos -> list[Todo];

def:pub todo_app -> JsxElement;
