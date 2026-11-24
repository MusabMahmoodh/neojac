# jobs

The standard jobs: each job runs in a copy of the program, apart
from the program that started it and its graph. The copy is told which job
it is for, reads its input from a file, and writes what it says and its
result to another, which the program that started it reads.

## Run

A job a copy of the program runs: the copy, its files, and how much of
what it wrote was read.

## Run.proc

(CPython's Popen on cpython, whose classes can't be named as types yet.)

## Run.ended

What it ended with, once it has written it: its result as JSON's
values, or what it failed with.

## run_to_log

Run a job on the input in file `in_path`, writing what it says and its
result to `log_path`: `run` runs it, given its input and a `note`.

## ProcessJobs.dir

Where a job's input and what it says are kept while it runs: `jobs` in
the app's data directory when it is not said.

## ProcessJobs.host

The program it was opened in.

## ProcessJobs.program

The program it was opened in.
