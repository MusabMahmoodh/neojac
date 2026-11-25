node Task {
    has title: str,
        done: bool = False;
}

walker:pub add_task {
    has title: str,
        reports: list[dict[str, str]] = [];

    can create with Root entry;
}

walker:pub list_tasks {
    has reports: list[list[str]] = [];

    can fetch with Root entry;
}
