impl add_task.create with Root entry {
    task = Task(title=self.title);
    root ++> task;
    report {"id": jid(task)};
}

impl list_tasks.fetch with Root entry {
    report [t.title for t in [-->][?:Task]];
}
