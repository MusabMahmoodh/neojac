# contract

The contract of the `schedule` abstraction: `Scheduler`, the interface of
the plugin that runs a program's scheduled functions when they are due, and
what crosses it.

## Scheduled

A scheduled function: its `name` (its module's and its own), how often it
runs, and `run`, which runs it once: for no caller, with what it changed in
the graph kept.

## Scheduler

What runs a program's scheduled functions when they are due: the
interface of the `schedule` abstraction's plugins. `open` is the first thing
asked of it, given the program it runs in. `start` is given each scheduled
function, and `on_loop`, which has the thread the program listens on run a
piece of work: where a scheduled function of a space the program runs in
its own process must run.
