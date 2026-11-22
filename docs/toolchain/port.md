---
description: neojac port, which translates C, C++, Rust, Python, JavaScript and TypeScript source into Jac that behaves as the source does or refuses it - in a project, a file read as the project builds it and its module moved in one change with its wires and tables; outside one, the Jac written beside the source; the plan --check prints, what is refused and why, and how each language is read.
keywords: port, porting, transpile, transpiler, translate source, neojac port, --mapping, port plan, replaced-by-neojac
---
# port

`neojac port` translates source in another language into Jac. A port behaves as its source does,
or it is refused: port never writes Jac that is only close.

```sh
neojac port tools/gcd.py            # writes tools/gcd.jac
neojac port vendor/shelf            # every source under a directory
neojac port --check src             # write nothing: what would port, what is refused, the plan
neojac port src/half.c -o build/jac # outside a project: write under another directory
```

| Language | Files | Read by | Mapping |
|---|---|---|---|
| C | `.c`, `.h` | Clang: in a project for every target its C module compiles it for, else for every target neojac builds C for | [Porting C](../interop/port-c.md) |
| C++ | `.cc`, `.cpp`, `.cxx`, `.hpp` | Clang, the same way | [Porting C++](../interop/port-cxx.md) |
| Rust | A crate, by its `src/lib.rs` | rustc, for every target neojac builds Rust for | [Porting Rust](../interop/port-rust.md) |
| Python | `.py` | CPython | [Porting Python](../interop/port-python.md) |
| JavaScript, TypeScript | `.js`, `.mjs`, `.cjs`, `.ts`, `.jsx`, `.tsx` | TypeScript | [Porting JavaScript and TypeScript](../interop/port-javascript.md) |

Each language is read by its own compiler, the one neojac ships, so port sees a source exactly as
a build of it does: its types, what every name refers to, its macros expanded. A language's
mapping page lists what it translates, and port refuses the rest.

## A port

`gcd.py`:

```python
"""Greatest common divisors."""


def gcd(a, b):
    # Euclid's algorithm.
    while b != 0:
        a, b = b, a % b
    return a


if __name__ == "__main__":
    print(gcd(1071, 462))
```

`neojac port gcd.py` writes `gcd.jac`:

```jac
"""Greatest common divisors."""

def gcd(a: any, b: any) -> any {
    # Euclid's algorithm.
    while b != 0 {
        (a, b) = (b, a % b);
    }
    return a;
}

with entry:__main__ {
    print(gcd(1071, 462));
}
```

- **The Jac is in neojac's one layout**, as [`neojac fmt`](fmt.md) writes it, with the source's
  comments and docstrings at the declarations and statements they belong to.
- **It is checked before it is written.** Port runs everything [`neojac check`](check.md) runs on
  what it made, and writes it only when that finds nothing: outside a project, a Python file's
  Jac as a module of a `cpython` space and a `.tsx` or `.jsx` file's as one of a browser space,
  where what they use runs; in a project, the project as the port leaves it.
- **The same source gives the same Jac.** Nothing in a port is a guess: every fact comes from the
  source's own compiler.

## Same behavior

A port prints what its source prints, exits as it exits and raises where it raises. Where Jac
means something else than the source, port writes the Jac that keeps the source's meaning, even
when no one would write it by hand. C's `/` rounds toward zero and Jac's `//` toward negative
infinity, so `n / 2` of a signed `n` is written with a test of its sign:

```c
static int half(int n) {
    return n / 2;
}
```

```jac
def half(n: i32) -> i32 {
    return n // 2 + 1 if n % 2 != 0 and n < 0 else n // 2;
}

with entry {
    print(half(7), half(-7));
}
```

```output
3 -3
```

- **What the source leaves undefined may become defined.** A signed overflow is undefined in C,
  and the Jac raises `OverflowError`.
- **What has no such Jac is refused.** The value of a Python `yield` is what `send` gave the
  generator, and a Jac generator has no `send`, so port writes no Jac for it yet (E4005).

## What a path names

- **A file** is known by its extension, and one port does not translate is E4004.
- **A directory** is every source under it that port translates.
- **A C or C++ source is ported with the header of its name**: `geom.c` and `geom.h` are the
  module `geom`.
- **A directory with a `Cargo.toml` is a Rust crate**, ported from its `src/lib.rs`.

How each source is read, and where its Jac goes, depends on whether it is in a project: a
directory with a `jac.toml` above it ([Projects](projects.md)).

## In a project

A project's sources are read as the project builds them, and porting one moves its module from
its language to Jac in one change.

**What a path names is what `jac.toml` says.** A directory is every source of the trees
`jac.toml` describes under it, in every language, and not what `[project] exclude` leaves out
nor what neojac set aside in `replaced-by-neojac/`. A path that is no source of the project is
E4006.

**Each file is read as its build reads it.** Python with its package, so a relative import names
a module of the project; C with its module's table in `jac.toml` (its includes, its defines, its
own file's flags), for the platforms the module compiles it for (one compiled for none is E4007);
TypeScript with its `tsconfig.json`. A C file a unity build compiles only through another
source's `#include` is read in that source's translation unit, and ports with it (E4010 alone).

**The plan.** `neojac port --check` prints what would port and what is refused, and in a project
the plan: each module after the modules of the project it imports, so that each step leaves a
project that builds, and modules that import each other as one group that ports together.
`--json` prints the same as data.

```text
$ neojac port --check shop
the plan, each module after those it imports; a group ports together:
  1. shop: now
  2. shop.mathx: now
  3. shop.ping, shop.pong (together): now
  4. shop.report, after shop.mathx
  5. shop.use, after shop.mathx
port: 6 sources would port
```

**A port is one change.** Porting a file in a project:

- writes its Jac beside it, under its name, laid out as the project's lint wants it (under
  `separate-impls`, the declarations in the module and the bodies in its annex, `impl/`);
- moves the source to `replaced-by-neojac/`, at its path in the project;
- writes its imports of the project's modules as wires in `archwire.jac`: a module that
  `shop/use.py` imported, `from .mathx import gcd`, is the wire `shop.mathx ++> shop.use { gcd }`,
  and the module's Jac imports nothing of the project;
- keeps the wires of the files that stay in their language and use it: a `-->` wire declares an
  import their own source writes (C's `#include` and calls, JavaScript's `import`), and it now
  names what they take of a Jac module; a C source leaves its module's table in `jac.toml`;
- and makes all of it only if the project then checks (E4008). Otherwise nothing is written:
  the source stays, and `archwire.jac` and `jac.toml` are as they were.

```text
$ neojac port shop/use.py
shop/use.py -> shop/use.jac
shop/use.py -> replaced-by-neojac/shop/use.py
```

- **The C that stays calls the Jac.** A C source of the module that is not ported, and called a
  function of the ported file, calls the Jac module's function through its wire, by the header
  beside the Jac module ([C modules](../interop/c-modules.md#calling-jac-from-c)).
- **A module imported by a file of no space** (a script beside the project) is refused (E4009):
  that file would have nothing to import.
- **`-o` is for sources outside a project.** In one, the Jac is written beside its source.

## Outside a project

A source outside any project is read as `neojac build` reads it alone, for every target neojac
builds its language for, and its Jac is written beside it, under its name: `tools/gcd.py`
becomes `tools/gcd.jac`. Directories whose names start with a dot, and `node_modules`, `build`,
`target`, `dist` and `__pycache__`, are left out. A C source is read with the flags of the C
module it is in (the `cmodule.toml` above it).

| `-o` | Writes |
|---|---|
| A name ending in `.jac` | That file, for one source |
| Anything else | A directory: a file's port in it, and a directory's sources under it as they are under the directory |

- **An output that is already there is refused** (E4003), so a port someone has edited is never
  written over. Remove it to port again.
- **The source is never changed**, and neither is a `cmodule.toml`, a `Cargo.toml`, an
  `archwire.jac` or a `jac.toml`.
- **The files of a C module port together.** Nothing wires a Jac module into the C that stays,
  so a file is refused while a source that calls it stays C (E4002).

## Platforms

**C, C++, Rust and Python that differ by platform** port to one module where every target agrees.
A statement that differs is written under `comptime if` on `target()`, and so is a declaration
that differs, among the module's declarations or a class's members
([comptime if](../language/compile-time.md#among-declarations-and-members)); C and Rust whose
declarations differ throughout go to the module's target variant files (`geom.windows.jac`),
which [Modules](../language/modules.md) describes. Python's tests of `sys.platform` and
`os.name` port to `comptime if` the same way.

## What is refused

A file ports whole or not at all. Port reports every construct it refuses, each at its place in
the source with what to do instead, writes nothing for that file, and exits with status 1.

```text
$ neojac port gen.py
gen.py:2:11: error[E4005]: port writes no Jac yet that keeps the meaning of the value of a `yield`: a Jac generator's `yield` gives None, and `send` is no method of one
 2 |     got = yield 1
   |           ^
    = help: Use the `yield` as a statement of its own.

1 source refused, nothing written for it
`neojac docs port` says what port translates and what it refuses.
```

| Code | Refuses |
|---|---|
| E4001 | A construct outside the language's mapping |
| E4002 | Outside a project, a C file whose functions a source left in C still calls |
| E4003 | An output that is already there |
| E4004 | A file that is no source port translates |
| E4005 | A construct whose Jac would mean something else |
| E4006 | In a project, a path that is no source of it |
| E4007 | In a project, a C source its module compiles for no platform |
| E4008 | In a project, a port after which the project would not check |
| E4009 | In a project, a module a file of no space imports |
| E4010 | A file a unity build compiles only inside a source not ported with it |

- **A source its own compiler rejects** is reported by that compiler, under its own code
  (`error[cpython SyntaxError]`, `error[tsc TS2322]`, Clang's and rustc's own messages).
- **`neojac port --check`** reports the same and writes nothing: run on a codebase, it lists what
  stands between it and a port, and in a project the plan.

## Reading a mapping

`neojac port --mapping <language>` prints a language's mapping page: `c`, `c++`, `rust`, `python`
or `javascript`. The pages under [Using other languages](../interop/index.md) are those, printed
from the tables the translations read.
