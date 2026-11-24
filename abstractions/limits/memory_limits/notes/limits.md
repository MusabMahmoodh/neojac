# limits

The standard limits: each actor's uses within its window, kept in
the program's memory. They are one program's own: two instances of an app
count apart.

## Uses

The uses of one scope by one actor within its window.

## MemoryLimits.sweep_at

How many actors' uses are kept before those whose window has passed
are let go.

## MemoryLimits.open

Nothing to open: it keeps its counts in memory, and asks nothing of
the program.

## MemoryLimits.held

How many actors' uses are kept now.

## MemoryLimits.consume

Twice what is left: a sweep's cost is paid for by as many uses.
