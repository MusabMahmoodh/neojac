# schedule

The standard scheduler: each scheduled function is run every so
many seconds by the thread the program listens on, the first time as it
starts. A thread of its own keeps the time, and hands each function that is
due to that thread: so a scheduled function of a space the program runs in
its own process runs where the space's code must, and one that runs long
holds up no other's clock.

## LoopSchedule.tick

How often the clock looks for a function that is due, in seconds.

## LoopSchedule.open

Nothing to open: it asks nothing of the program until it is given
what to run (`start`).

## run_once

Run `s` once: a failure of its own is said, and it runs again at its next
turn.

## turn_of

One turn of `s`, for the listening thread to take: it runs `s`, and then
says that `s` waits no longer. (Made here, one for each turn, so that each
holds its own function: a lambda written in the clock's loop would hold the
loop's variables, and run whichever function the loop came to last.)

## keep_time

The clock's life: each of `work` handed to `on_loop` when it is due, a
function still waiting for its last turn not handed again.
