---
description: neojac test, how it finds test modules, the [test] table of jac.toml, -k, -j and -o, the runners it builds in .jac/test, its output and exit statuses, and running tests as WebAssembly.
keywords: test runner, runner, deselected
---
# test

`neojac test` builds and runs the `test` blocks of a project. Each module that has tests is built into one program, its test runner, and the runners are built and run in parallel: a module's tests start when its own runner is built, while others are still building.

This page is the command. The `test` block itself is in [Tests](../language/tests.md) (`neojac docs language/tests`).

## The shortest example

A module holds its tests beside the code they test:

```jac
obj Cart {
    has items: dict[str, int] = {};

    def add(name: str, count: int = 1) {
        self.items[name] = self.items.get(name, 0) + count;
    }

    def total -> int {
        return sum(self.items.values());
    }
}

test "an empty cart holds nothing" {
    assert Cart().total() == 0;
}

test "adding twice adds up" {
    c = Cart();
    c.add("pen");
    c.add("pen", 2);
    assert c.total() == 3;
}
```

```sh
neojac test cart.jac
```

```text
neojac test: 1 module with tests, 1 to build, on macos-aarch64
cart.jac: 2 passed

2 passed; 1 of 1 module passed in 1.22s
```

## Forms and options

```sh
neojac test [<path>...] [<option>...]
neojac test <file.jac> -o <runner> [<option>...]
```

| Option | What it does |
|---|---|
| `-k <text>` | Run only the tests whose names contain `<text>`; a module with none is not built |
| `-j <jobs>` | Build and run this many modules at once, each told it has this many processors (default: one for each core). A build or a runner sizes what it runs at once by its processors, so a test that runs commands of its own runs no more than `<jobs>` of them at once ([`PYTHON_CPU_COUNT`](../reference/environment.md#set-by-neojac-for-what-it-runs)) |
| `-o <runner>` | Build the one module's test runner, and do not run it |
| `--target <platform>` | Build the runners for another platform ([build](build.md#--target-building-for-another-platform)) |
| `--rt <dir>` | The runtime to build against (default: the `rt/` beside neojac) |
| `--diagnostics <form>` | How diagnostics and test results are written on stderr: `human` (the default), or `json`, one record a line ([check](check.md#diagnostics-as-json)) |

## Which modules are tested

**With paths**, the modules there:

- A `.jac` file names its module. A test annex names the module it belongs to, so `neojac test src/cart.test.jac` tests `src/cart.jac`.
- A directory means every module under it that has at least one `test` block.

**With no paths**, the directories `jac.toml` lists, relative to the project's root (the nearest directory at or above the current one that holds a `jac.toml`):

```toml
[test]
directories = ["src", "tests"]
exclude = ["tests/reject/*"]
```

| Key | Meaning | Default |
|---|---|---|
| `directories` | The directories `neojac test` searches when it is given no paths | The project's root |
| `directory` | One directory, read when `directories` is absent or empty | |
| `exclude` | fnmatch patterns of paths, relative to the project's root, that a directory search leaves out | Nothing |

A directory search looks at every `.jac` file under the directory, in sorted order, and leaves out:

- files and directories whose names start with `.`;
- directories named `__pycache__`, `node_modules` or `fixtures`;
- impl annexes (`*.impl.jac`), which are part of their modules;
- what `[test] exclude` matches. `exclude` applies to directory searches only: a file named on the command line is tested whatever `exclude` says.

A module's tests are the `test` blocks in the module itself and in its test annexes, `<name>.test.jac` beside it and `test/<name>.test.jac`. A test annex is part of its module: it sees the module's names without importing them.

<!-- example: not checked: a test annex of cart.jac, which is compiled with that module -->
```jac
test "a cart counts each name" {
    c = Cart();
    c.add("pen");
    c.add("ink");
    assert len(c.items) == 2;
}
```

## What a run does

1. Finds the modules, and with `-k` keeps those with a matching test.
2. Builds each module's runner into `.jac/test/<platform>/` under the project's root, at the module's path: `src/cart.jac` becomes `.jac/test/macos-aarch64/src/cart`. A runner is rebuilt only when something its last build read has changed; the header line says how many are built this time.
3. Runs every runner that built, from the project's root, with the environment variable `NEOJAC` set to the neojac that is running. A test that builds programs of its own runs that compiler.
4. Shows each module's result, in the order the modules were found, then the summary.

Inside a runner, the module's own code (its globals and plain `with entry` blocks, its test annexes' included) runs first, then each test in source order. Everything a test prints is captured; it is shown only for a test that fails, under the failure. What the module's code prints is not shown.

`with entry:__main__` does not run in a runner, so a module that is a program keeps its main code there: what it does when it is run, as opposed to the setup its tests rely on.

```jac
def greeting(name: str) -> str {
    return f"hello, {name}";
}

with entry:__main__ {
    print(greeting("world"));
}

test "greets by name" {
    assert greeting("ann") == "hello, ann";
}
```

```output
hello, world
```

`neojac build` makes the program, which prints its greeting; `neojac test` runs only the test. See [Tests](../language/tests.md#a-programs-main-code-and-its-tests) for which entry blocks run when.

Beside each runner are two logs: `<runner>.build.log`, what its build printed, and `<runner>.log`, what its last run printed.

## Reading the output

```text
neojac test: 4 modules with tests, 4 to build, on macos-aarch64
tests/reject/broken.jac:2:12: error[E1110]: '+' is not supported between int and str
 2 |     assert 1 + "a" == 2;
   |            ^^^^^^^
    in module 'tests/reject/broken.jac'

tests/reject/broken.jac: the test runner failed to build
src/cart.jac: 3 passed
tests/names.jac: 1 passed

tests/prices.jac:10:5: FAILED[rt AssertionError]: cents of nothing: expected no cents
 10 |     assert cents(0.0) == 0, "expected no cents";
    |     ^
    in module 'tests/prices.jac'
    Traceback (most recent call last):
      File "tests/prices.jac", line 10, in test cents of nothing
        assert cents(0.0) == 0, "expected no cents";
tests/prices.jac: 1 passed, 1 failed

5 passed, 1 failed; 2 of 4 modules passed in 1.19s
FAILED tests/reject/broken.jac (did not build)
FAILED tests/prices.jac::cents of nothing
```

- The first line: how many modules have tests, how many runners have to be built, and the platform.
- A runner that does not build is shown with its diagnostics, each noted `in module '<module>'`, then `<module>: the test runner failed to build`. It counts as a failed module.
- Each module that ran has one line, `<module>: N passed`, with `, N failed` when any did.
- Each failure is shown above its module's line as a diagnostic ([check](check.md#the-format-of-a-diagnostic)) at the line the test stopped at: `FAILED[rt <exception>]` for an assertion that failed and `ERRORED[rt <exception>]` for any other exception, then the test's name and the exception's message. Under it are the source line, the module, the traceback, and after `output:` what the test printed.
- The last lines: the tests' totals (`N passed`, with `, N failed` and `, N deselected` when there are any), how many modules passed, how long the run took, and each failure by name: `FAILED <module>::<test name>` for a test, `FAILED <module> (did not build)` for a runner that did not build, `FAILED <module> (its runner failed)` for one that stopped before its tests were done ([below](#a-runner-that-dies)), and `FAILED <module> (its runner reported no test)` for one that ended with status 0 and sent no result of the module's tests, so nothing says they passed.

With `--diagnostics json` each test's result, passed or failed, is a record a line on stderr instead, with the test's name and outcome in its `result`; the modules' lines and the last lines are still printed.

### A runner that dies

A runner that stops before its tests are done, killed by a signal or ended by a crash, reports no
failure of a test. Its module's line counts the tests that finished; then comes the status the
runner ended with, minus a signal's number when a signal killed it, and what the runner had
printed, a mark for each test that finished. The summary counts the module as failed:

```text
neojac test: 1 module with tests, 1 to build, on macos-aarch64
dies.jac: 1 passed

dies.jac: its runner exited with status -6
.

1 passed; 0 of 1 module passed in 1.22s
FAILED dies.jac (its runner failed)
```

Here the second of three tests raised `SIGABRT` (`signal.raise_signal(signal.SIGABRT)`), signal 6. An
exception, `SystemExit` from `sys.exit` among them, is not this case: it fails its test with an
`E` mark and the run goes on.

To find out why the runner stopped, build it with `-o` and run it by hand, where its exit status
shows:

```sh
neojac test dies.jac -o dies-tests
./dies-tests; echo $?
```

```text
.134
```

In the shell, a status above 128 is a signal, numbered the status minus 128: 134 is signal 6, `SIGABRT`, and 139
is signal 11, `SIGSEGV`, a crash. Run the runner under a debugger (`lldb ./dies-tests` on macOS,
`gdb ./dies-tests` on Linux) to see where it stopped; `./dies-tests -k <text>` runs one test alone.
What the runner printed before it stopped, as `neojac test` ran it, is in its log, `<runner>.log`
beside the runner in `.jac/test/`.

## -k: some of the tests

`-k <text>` runs the tests whose names contain the text, exactly as written. A module with no such test is neither built nor run.

```sh
neojac test -k rounds
```

```text
neojac test: 1 module with a test whose name contains 'rounds', 1 to build, on macos-aarch64
tests/prices.jac: 1 passed

1 passed, 6 deselected; 1 of 1 module passed in 1.18s
```

The last line counts the tests left out across the whole project.

## -o: one runner, not run

```sh
neojac test tests/prices.jac -o prices-tests
./prices-tests
./prices-tests -k rounds
```

`-o` builds one module's runner to the file named and does not run it. The runner is an ordinary program: it runs the module's tests, prints a mark for each (`.` passed, `F` an assertion failed, `E` any other exception was raised), then the failures and the totals, and exits with status 1 when a test failed. Its only option is `-k <text>`. Run it from the project's root when its tests open files by relative path.

```text
.F.                                                                      [100%]

FAILED tests/prices.jac::cents of nothing
E   AssertionError: expected no cents

2 passed, 1 failed
```

This is how to build runners for a platform the tests cannot run on here, and to run a test under a debugger.

## Exit statuses

| Status | Meaning |
|---|---|
| 0 | Every module's tests passed, and every suite of the project's own |
| 1 | A test failed, a suite of the project's own did, a runner did not build, or the command line was wrong |
| 5 | No tests: nothing under the paths has a `test` block, or `-k` matches no test's name |

```text
neojac test: no tests found
neojac test: no test's name contains 'multiplies'
```

## --target wasm32-wasi

Runners for another platform cannot run here, with one exception. `neojac test --target wasm32-wasi` builds each runner as a WebAssembly module and runs it on neojac's own Node, which is a WASI runtime (`rt/node/wasi.mjs`), as `neojac node <rt>/node/wasi.mjs --env NEOJAC_DIAGNOSTICS_TO=<file> <runner>.wasm` from the project's root (`<rt>` is neojac's runtime directory). The project's files are therefore the runner's, and the file its tests' results are sent to is named to it: a program run that way has only the environment it is told to be given.

Nothing else needs installing. neojac has no Node for Windows yet, so there it stops:

```text
neojac: test: wasm32-wasi test runners run on neojac's Node, which Windows has none of; build one with `neojac test <module> -o <runner> --target wasm32-wasi`
```

For any other platform that is not this machine's, `neojac test` stops and says how to build a runner instead:

```text
neojac: test: linux-x86_64 test runners don't run on macos-aarch64; build one with `neojac test <module> -o <runner> --target linux-x86_64`
```

## A project's own suites

A project that holds trees of other ecosystems has their suites too, which `neojac test` runs
after the Jac tests where `jac.toml` names them. A tree with no table is not tested, whatever
its manifest says: a `test` script written for another tool is simply not named. `neojac absorb`
writes the table where the tree says how it is tested: an npm tree's `[test.npm."<directory>"]`
where its `package.json` has a `test` script, and a Python project's `[test.pypi."<directory>"]`
from its `[tool.cibuildwheel] test-command`, `{project}` and `{package}` read as the tree's own
directory (`pytest {project}/tests` is `command = ["pytest", "tests"]`). What cibuildwheel installs
for the tests, its `test-requires` and the packages of a `before-test` that is `pip install ...`,
becomes the tree's `test` dependency group (`[dependency-groups] test = ["pytest",
"hypothesis"]`) where it has none, which the table names in `groups`, so `neojac install` then
`neojac test` runs the suite with nothing written by hand.

| Table | The tree | What is run, in the tree's directory |
|---|---|---|
| `[test.pypi."<directory>"]` | A Python project | Its `command`, against what `neojac build` makes of the project ([Packages](packages.md#building-and-testing-a-python-project)) |
| `[test.npm."<directory>"]` | An npm tree | `neojac npm run <script>` |
| `[test.cargo."<directory>"]` | A crate | `neojac cargo test`, with its `args` |

```toml
[test.pypi.backend]
command = ["pytest", "tests"]
groups = ["dev"]

[test.npm."."]
script = "test"
```

```text
$ neojac test
neojac test: 2 modules with tests, 0 to build, on macos-aarch64
shapes.jac: 3 passed
main.jac: 1 passed

backend/pyproject.toml: pytest tests
...
============================== 12 passed in 0.41s ==============================

4 passed; 2 of 2 modules passed, 1 of 1 suite of the project's own passed in 1.2s
```

- **A Python project is built first** (`neojac build backend/pyproject.toml`), and its suite runs
  against that build, with `.jac/venv` first on `PATH`.
- **A Python project some of whose modules are Jac runs its command over what its spaces emit.**
  Where a space holding the tree's modules holds a Jac module (one `neojac port` made), the
  command runs in the tree laid at its own place under its laid top (`.jac/test/trees/backend/backend/`
  for `backend`, `.jac/test/trees/<the top's name>/` for a tree at the top): the Python that the tree's client space
  (`<space>_dev`, its tests and scripts) emits, with the tree's other files laid over it, and
  nothing of what the built package holds at its top. The package is the build's, first on
  Python's path, in the suite's process and in every Python the suite starts, and the client
  space shares the package's runtime, so a test and the package it imports are one program.
- **An npm tree's script and a crate's tests run as `neojac npm` and `neojac cargo` run
  anything**: the tree's manifest written first, with the toolchain's compilers. A tree's
  extension modules, its addons, are built first (`neojac build <directory>/package.json`).
- **An npm tree whose space holds a Jac module runs its script on what the space emits**, laid
  out so that the tree's own tools see what they saw. Once `neojac port` has made a file of the
  tree Jac, its tests still `require('../lib')`: the tree is laid in
  `.jac/test/spaces/<space>/<tree>/` (at `.jac/test/spaces/<space>/` for a tree at the project's
  root), its own files there as they are, with no `jac.toml` or `jac.lock` among them and
  `node_modules` linked, not copied. Each Jac file of the tree stands at its own place too, a
  link to the project's file (an annex directory with its files), and the source maps of what
  the space emits name it there: a test runner reports a failure at `tests/login.spec.jac:24:5`,
  relative to its own test directory, as it reported `tests/login.spec.ts:24:5` of the source.
  A link the tree holds is laid as the link it is, one to a directory included. At each ported
  source's place stands a forwarder that
  gives the module, under the source's own name and extension (`lib/twice.js`, `lib/kinds.ts`,
  `src/main.tsx`, `tests/auth.setup.ts`), so that what the tree's tools find by a source's name
  (a test runner's pattern, an `index.html`'s script, an import by `./counter.mts`) is there. A
  TypeScript source's forwarder is a TypeScript module of ES syntax (a `.cts` source's is
  CommonJS, as Node runs it), typed by the module's
  [face](../interop/npm.md#a-projects-own-javascript): a function as
  `export const bump: typeof $m.bump = ...`, a class and a value the module assigns again
  re-exported live (`export { count, Box } from ...`), a type by `export type { Kind } from ...`.
  A forwarder declares in its own text each value the module gives and never assigns again
  (`export const start = $m.start;`), so a tool that reads the file's text (a router reading a
  route file's exports) finds them, and gives any other global live from the module. Everything
  else emitted, the modules, their maps and the runtime, is apart in the laid tree's `.jac/`,
  imported by relative paths. Each module's face is laid there beside its emission, under the
  name TypeScript pairs with it (`.jac/lib/kinds.d.mts` beside `.jac/lib/kinds.mjs`), its
  relative specifiers re-based from the face's place: a ported module by its emission beside it
  (`./kinds.mjs`), a file that stays by its path in the laid tree (`../../lib/shape`). A module
  with no face of its own gets the declarations of what it gives. No face stands among the
  tree's own files; a declaration file the tree had (`env.d.ts`) stays. An emitted module imports a file of
  the tree (a stylesheet, a file that stays JavaScript) by its relative path to that file's place
  in the laid tree, not through an alias of neojac's own. The tree's configuration is not
  changed, and its own files are not touched. Where the package's dev space
  (`<space>_dev: node`, its tests and benchmarks) holds Jac too, the script runs in the dev
  space's laid tree, which holds the package's modules too: one copy of each module in the
  process, the one the tests import. A ported file that Node runs by its path (a test file)
  starts when it is required, not with the package.
  `neojac npm run`, `run-script`, `test` and `start`, and `neojac npx`, run in the same laid
  tree ([Running npm](packages.md#running-npm)), so `neojac npm run build` builds the tree its
  own way on the port.
- **A laid tree is laid again in place.** Each command lays it anew from what the space emits now,
  and changes in the laid tree only the files whose bytes (or links whose targets) differ, and
  removes only what an earlier lay wrote that this one does not. What a tool wrote there, such as
  a test runner's `test-results/`, stays, as it would in the tree. So a dev server serving the
  laid tree (`neojac npx vite`) sees a file change only where its source did, while another
  command runs in the same tree.
- **The laid top stands for the project's top.** A tree is laid at its own place under a laid
  top: `.jac/test/spaces/<space>/` for an npm tree, and for a Python tree below the project's top
  `.jac/test/trees/<its directory, / written %2F>/`, a laid top of its own, so that no two trees
  share one. At each level from the laid top down to the tree, every entry of the project beside
  the tree's path is there as a link to the project's own entry: `.jac/test/spaces/frontend_dev/.env`
  is a link to the project's `.env`, so `path.join(__dirname, "../../.env")` from
  `frontend/tests/` reads the project's file, and writes it, as it did from the source tree. Two
  entries are not linked: `.jac/`, which holds the laid top, and `.git`, so that git, walking up
  from the laid tree, finds the project's own repository and work tree and a script that stages
  or commits never writes laid files into its index. Inside the tree nothing is linked but
  `node_modules`, the Jac files and the tree's own links. On Windows a link is a symbolic link, of the directory kind for a directory,
  which needs Developer Mode or the privilege to make symbolic links.
- **Nothing walks the laid top following its links.** They lead out of the tree into the project
  itself: a walk that followed them would read the whole project as the tree's files, and one
  that wrote or removed through them would change the project. neojac lays the top again before
  each run by unlinking each link, never entering it, and the tree's own tools run inside the
  tree.
- **Its output is its own**, printed as it runs. neojac counts the suite, not its tests.
- **A suite that exits with another status than 0 fails the run**:
  `FAILED backend/pyproject.toml (its suite exited with status 1)`.
- **A path that is a tree's manifest runs that suite alone**:
  `neojac test backend/pyproject.toml`, `neojac test package.json`. Any other path, and `-k`,
  run no suite.
- **What the command needs is installed by `neojac install`**, which reads the table's `groups`
  and `extras`. A command that is not there is said to be:
  `'pytest' is not installed: neojac install installs what the project's tests need`.

## What goes wrong

| Message | Cause |
|---|---|
| `test: no such test module or directory: <path>` | A path that is neither a `.jac` file nor a directory |
| `[test] directory 'x' (resolved to '...') does not exist` | `jac.toml` lists a directory that is not there |
| `[test] directories must be a list of strings` | `directories` is not a list of strings |
| `[test] directory must be a string` | `directory` is not a string |
| `[test] is not a table` | `test` is a key with a value, not a table |
| `[test] exclude must be a list of strings` | `exclude` is not a list of strings |
| `-j takes how many modules to build and run at once: -j 4` | `-j` without a positive number |
| `<module>: the test runner failed to build` | The module, or its tests, has errors. They are shown above the line; `neojac check <module>` reports the same |
