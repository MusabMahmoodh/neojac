impl add_todo(title: str) -> Todo {
    todo = Todo(title=title);
    root ++> todo;
    return todo;
}

impl get_todos -> list[Todo] {
    return [root -->][?:Todo];
}

impl todo_app -> JsxElement {
    has todos: list[Todo] = [];

    async can with entry {
        todos = await get_todos();
    }

    return <ul>{[<li key={jid(t)}>{t.title}</li> for t in todos]}</ul>;
}
