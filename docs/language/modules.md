---
description: What a module is, what its top level may hold, import and include, an import in a code body, a module's default, with entry blocks and when they run, docstrings, how a module's file is found, and impl and test annexes.
keywords: module, import, include, include from, re-export, sibling module, from, import from, relative import, import in a function, local import, module default, default export, with entry, entry point, __main__, __name__, __file__, __doc__, __init__.jac, test annex, variant
grammar: module, element, default_element, import_stmt, from_path, import_items, import_item, module_code, access_tag
---
# Modules

A module is one `.jac` file, together with its annex files. It has its own names: what it declares,
what its `import` statements bring in, and what an `archwire.jac` wires into it. A program is its
main module (the file given to `neojac build`) plus every module that one reaches by imports.

## A module's top level

```ebnf
module ::= archwire | STRING? element*

element ::=
    type_alias
    | import_stmt
    | archetype
    | enum_decl
    | test_decl
    | docstring_target
    | default_element
    | ability
    | global_vars
    | comptime_element
    | impl_def
    | sem_def
    | module_code
    | decorated
    | async_element
```

The top level holds declarations only. Code that runs goes in a function or in a `with entry`
block; a bare statement at the top level is an error (E0005).

| Element | What it declares | Page |
|---|---|---|
| `import`, `include` | Names from another module | this page |
| `glob` | Module globals | [Variables](variables.md) |
| `def`, `async def` | Functions | [Functions](functions.md), [Async](async.md) |
| `type` | A type alias | [Types](types.md) |
| `with entry` | Code that runs when the module loads | this page |
| `default` | Marks one declaration the module's default | this page |
| `test` | A test | [Tests](tests.md) |
| `obj`, `class`, `struct`, `node`, `edge`, `walker`, `enum`, `impl`, `sem` | Archetypes and their implementations | `neojac docs obj` |
| `comptime` | Compile-time declarations | `neojac docs comptime` |
| `graph layers` | The project's layers, in `archwire.jac` only | [Layers](modules-layers.md) |
| `graph import` | Import wiring, in `archwire.jac` only | [Import wiring](modules-wiring.md) |
| `graph spaces` | Spaces and apps, in `archwire.jac` only | `neojac docs space` |

```jac
# expect: E0005, E0003
print("at the top level");
import:py os;
```

The second error is an import that names no module: The reference design's `import:py os;` is written `import os;`.

## Importing

```ebnf
import_stmt ::= "comptime"? ("include" | "import" "type"?) ("from" from_path import_items? | (STRING | (NAME | KEYWORD) ("." (NAME | KEYWORD))*) ("as" NAME)? ("," (STRING | (NAME | KEYWORD) ("." (NAME | KEYWORD))*) ("as" NAME)?)* ";")

from_path ::= ("." | "...")* (STRING | (NAME | KEYWORD) ("." (NAME | KEYWORD))*)?

import_items ::= "{" (element* | import_item ("," import_item)* ","?) "}"

import_item ::= ("*" | "default" | any_word | NAME) ("as" NAME)?
```

**In a project, a module's imports of the project's other modules are wires.** The project's
`archwire.jac` states them ([Import wiring](modules-wiring.md)), and one written in the module
is E1144. The `import` statement is for everything else: the standard library, a package, a C or
Rust library. It is also how a module that is of no project imports another, and a module of a
project of fixtures that no `archwire.jac` governs
([Projects](../toolchain/projects.md#a-project-of-fixtures)); the modules on this page are such
modules.

| Form | Binds in the importing module |
|---|---|
| `import util;` | `util`, the module. Its members are `util.name`; a global of it that holds a function is called through it as its own module calls it, `util.handler(4)` of `glob handler: Callable[[int], int]`. |
| `import util as u;` | `u`, the module |
| `import os, sys;` | Each module listed |
| `import pkg.part;` | `pkg`, with the member `pkg.part` |
| `import pkg.part as p;` | `p`, the module `pkg.part` |
| `import from util { twice, Tone as Pitch }` | `twice` and `Pitch`. No `;` follows the braces. |
| `import from .sibling { name }` | `name`, from a module found relative to this file |
| `import from . { sibling }` | `sibling`, the module beside this file, whole |
| `include util;` | Every name `util` declares or imports, as if written here |
| `include from util { pad, trim as strip }` | `pad` and `strip`, as names of this module's own |

- **`import` takes modules; `import from` takes names out of one.** Python's
  `from util import twice` is written `import from util { twice }`.
- **`include`** brings in every top-level name of the module: functions, archetypes, globals. It
  is the form for "all of it"; `import from util { * }` is not (E1145). `include from` names what
  it takes ([below](#include-and-a-re-export)).
- **A module is loaded once**, however many modules import it and under however many names.
- **An imported global is the same variable**, not a copy: an assignment to `util.counter`
  anywhere is seen by every module that imported `counter`.
- **Modules may import each other.** A cycle of imports is allowed. A class may derive from a
  class of a module that imports its own module, and every class of both modules is set up before
  either module's `with entry` code runs.
- **Imports are written at the top level**, anywhere among the declarations: an import after a
  class is as good as one at the top of the file. An import in a function's body is its own, and
  starts its module where it runs ([below](#an-import-in-a-code-body)).
- **A class belongs to its module.** Two classes of one name in two modules are two types:
  `ma.Item` and `mb.Item` are not equal and neither is an instance of the other.
- **A name is declared once.** Importing a name the module also declares is E2036.

The standard library is imported the same way:

```jac
import os;
import from os { path as p, sep }

with entry {
    print(p.join("a", "b") == "a" + sep + "b");
    print(os.path.basename("/srv/app/main.jac"));
}
```

```output
True
main.jac
```

A project of several modules. `main.jac`:

<!-- example: not checked: needs the files util.jac and pkg/part.jac beside it -->
```jac
import util;
import pkg.part as p;
import from util { twice, Tone as Pitch }

with entry {
    print(util.twice(1), twice(3), Pitch().pitch, p.part_name());
}
```

`util.jac`:

```jac
obj Tone {
    has pitch: int = 440;
}

def twice(n: int) -> int {
    return 2 * n;
}

with entry {
    print("util loads");
}
```

`pkg/part.jac`:

<!-- example: not checked: a relative import needs the file util.jac in the directory above -->
```jac
import from ..util { twice }

def part_name -> str {
    return "part" + str(twice(2));
}
```

```sh
neojac build main.jac -o main && ./main
```

```text
util loads
2 6 440 part4
```

### Relative imports

Dots before the path of an `import from` make it relative to the importing file, as in Python:

| Path | Looked for |
|---|---|
| `.name` | In the importing file's directory |
| `..name` | In the directory above it |
| `...name` | Two directories above it |

A relative import looks in that one place only. One that finds nothing is E1134.

`import from . { util }` binds the module `util` beside the importing file, whole, as `import util;`
binds it by name: `util.twice(2)`. It does so in any directory, a package or not, and `as` renames
it (`import from . { util as u }`); `import from .. { util }` takes the one a directory above.

### A module whose name is no identifier

A module keeps its file's name though the stem is no identifier (`sqlite-error.jac`, as a
JavaScript package names its files), and is imported by its path, quoted, from the importing
file's directory and without the extension: `import from "./sqlite-error" { SqliteError }`. The
quoted path stands wherever a module's path does: in an import in a code body, in `include from`,
and in a wire and a layer's item, from the archwire's directory
(`"lib/sqlite-error" ++> main { SqliteError }`, `layer errors { "lib/sqlite-error"; }`). A
stem that holds a dot is no identifier either: `types.gen.jac` is imported as
`import from "./types.gen" { Row }`, since `.types.gen` would name `gen` in a package `types`, and
its wire names it so too: `"gen/types.gen" ++> main { Row }`. Its variant files keep their tags
after the stem (`types.gen.darwin.jac` is the macOS form of `types.gen`). So does a module in a
directory whose name is no identifier: `import from "./v1.2/util" { two }`. A module whose path is
all identifiers, the stem and each directory, is imported by its dotted name, and a quoted path to
one is E2310, in an import as in a wire or a layer: `import from "./util" { two }` is
`import from .util { two }`, and `"util" ++> main { two }` is `util ++> main { two }`.

In a cpython space a module is a Python module, named by its path's parts joined by `.`
(`pkg/mod.jac` is `pkg.mod`). Python cannot name a module with a dot inside a part, so a dot in a
part of the path is `_` in its Python name, as pytest names such a module: `types.gen.jac` is the
Python module `types_gen`. Two modules of one cpython program with one Python name (`types.gen.jac`
beside `types_gen.jac`) are E2300.

`sqlite-error.jac` and `main.jac`:

```jac
obj SqliteError {
    has code: int = 0;
}

default glob LIMIT: int = 3;
```

<!-- example: not checked: needs the file sqlite-error.jac beside it -->
```jac
import from "./sqlite-error" { SqliteError, default as lim }

def later -> int {
    import from "./sqlite-error" { LIMIT }
    return LIMIT;
}

with entry {
    print(SqliteError(code=5).code, lim, later());
}
```

```text
5 3 3
```

### `include` and a re-export

`include` makes another module's names this module's own, as if they were written here: a module
that imports this one takes them from it. `include util;` takes every name `util` declares, and
every name it imports (`import from .word { loud as shouted }` in `util` makes `shouted` this
module's too);
`include from util { twice, counter as count }` takes those named, under the names given. A
relative path takes no items for all of it: `include from .util`, with no `;`.

- **What it takes is the same thing**, not a copy: `count` above is `util`'s global, and an
  assignment to it either way is seen through both.
- **It is a re-export.** A module made of other modules' parts gives them on in one place, as
  JavaScript's `export { a, b as c } from "./x"` and `export * from "./x"` do. On a JavaScript host
  it is written as that ES re-export, so the binding stays live there too.
- **Under an `archwire.jac`** it is a wire: `include util ++> shapes { twice }`
  ([Import wiring](modules-wiring.md#wires)).

`lib/util.jac`, `lib/shapes.jac` and `lib/main.jac`:

```jac
glob counter: int = 0;

def twice(n: int) -> int {
    return 2 * n;
}

def bump {
    counter += 1;
}
```

<!-- example: not checked: needs the file util.jac beside it -->
```jac
include from .util { twice, counter as count, bump }

def area(n: int) -> int {
    return twice(n) * n;
}
```

<!-- example: not checked: needs the files util.jac and shapes.jac beside it -->
```jac
import from . { util }
import from . { shapes as sh }

with entry {
    print(util.twice(2), sh.area(3), sh.twice(4));
    sh.bump();
    print(sh.count, util.counter);
}
```

```text
4 18 8
1 1
```

### An import in a code body

An `import` written in a function, or in any other code, is that code's, as a Python import in a
function is:

- **Its names are the body's**, from the import on: a nested function written after it sees them
  too. A use of one anywhere else in the module, or before the import, is E2240.
- **A Jac module it names starts where the import first runs**, once, with the modules only it
  brings in, and not when the program starts. Modules that import each other this way start in
  the order Python's would. The module is made whole there, on every host: natively too, each of
  its globals gets its value where the import runs, one made with no code (`glob seen: dict[str,
  int] = {};`) as much as one code makes, so a function of it called there finds every global
  made.
- **It is synchronous on every host**: a JavaScript host starts the module at the statement, as
  a native program and a `cpython` space do.
- **A module the importing module also imports at its top** starts as a top-level import starts
  it, before the importing module's code; the import in the body binds its names there. Only a
  module that no top-level import names starts where a body's import runs. In module code,
  `import os;` or `import os.path;` again, where the top already has `import os;`, binds the
  module the top's import binds: it is no second binding of `os`, on every host.
- **On a `cpython` host** it may also name a Python module, which Python loads where the import
  runs (its names are `any` to the checker). A module of Python's that the native library does
  not have is refused in a native program (E5090), and so is, in a `cpython` space, an import in
  a code body of anything Python cannot load as it runs: a path, an `include` (E5173).
- **In a `cpython` space, an import in module code binds the module's `glob` of the name it
  gives**, where it runs, as Python's import at a module's top does: `glob json: any;` and
  `with entry { import json; }` make `json` the module's, which its functions read. An import
  whose name has no `glob` is the code's own, as above. Natively the `glob` and the import are
  two declarations of one name (E2036)
  ([An import in a code body](../interop/python-classes.md#an-import-in-a-code-body)).
- **Under an `archwire.jac`**, the wire into the module admits the import, and names what it may
  import (`units ++> shapes { label }`); the import in the body binds them where the module
  starts. A name the wire lacks is E2094, as for any wired import.

`main.jac`, `shapes.jac` and `units.jac`:

<!-- example: not checked: needs the files shapes.jac and units.jac beside it -->
```jac
import from shapes { area_of }

with entry {
    print("main starts");
    print(area_of(2));
    print(area_of(3));
}
```

<!-- example: not checked: needs the file units.jac beside it -->
```jac
def area_of(side: int) -> str {
    import from units { label }
    return label(side * side);
}
```

```jac
glob SUFFIX: str = " sq m";

with entry {
    print("units starts");
}

def label(n: int) -> str {
    return str(n) + SUFFIX;
}
```

```text
main starts
units starts
4 sq m
9 sq m
```

`units` starts at the first call of `area_of`, and its code runs once.

### A module's default

```ebnf
default_element ::= "default" (global_vars | decorated)
```

`default` before a declaration makes it the module's default: a function, a class of any kind, an
enum, or a `glob` of one name. It comes after the declaration's docstring and before its
decorators. A module has at most one (E2250), and `default` marks one declaration (E0175).

- **`import from greet { default as hello }`** binds a module's default under a name of the
  importer's, on every host, and so does a wire (`greet ++> page { default as hello }`). The
  declaration keeps its own name too, for Jac modules.
- **On a JavaScript host** it is the module's default export, and only that, as JavaScript's
  `export default function welcome` is: a JavaScript file's `import hello from "./greet.js"`
  takes it, and a CommonJS `require` gives it, but `import { welcome } from "./greet.js"` finds
  no export `welcome`, and a wire naming it to a JavaScript file is E1145.

`greet.jac`:

```jac
"""How a visitor is greeted."""
default def welcome(name: str) -> str {
    return "welcome, " + name;
}
```

`main.jac`, beside it:

<!-- example: not checked: needs the file greet.jac beside it -->
```jac
import from greet { default as hello, welcome }

with entry {
    print(hello("ann"), welcome("bo"));
}
```

```text
welcome, ann welcome, bo
```

### Other import forms

- `import from "<library file>" { def ...; }` declares functions of a C library, and an import of a
  Python or npm package reaches code in another language. See `neojac docs interop`.
- `import type` names a type of a JavaScript package or of another space, for annotations.
- `comptime import` makes a module available to compile-time code. See `neojac docs comptime`.
- `default` as an import item is a module's default: a Jac module's (above) or a JavaScript
  module's default export.

### What is rejected

```jac
# expect: W1100, E1134
import nowhere;
import from .gone { x }

with entry {
    print(1);
}
```

```jac
# expect: E1145
import from os { no_such_name }

with entry {
    print(1);
}
```

```jac
# expect: E5090
def opcodes -> any {
    import dis;
    return dis.opname;
}
```

```jac
# expect: E0175
default glob first: int = 1,
     second: int = 2;
```

```jac
# expect: E2250
default def a -> int {
    return 1;
}

default def b -> int {
    return 2;
}
```

| Code | Condition |
|---|---|
| E0003 | An import that names no module: `import;`, `import from { x }`, the reference design's `import:py os;` |
| W1100 | No module of that name is found |
| E1134 | A relative import names no module |
| E1145 | The module has no such name, as an import item or as `module.name` |
| E2036 | The imported name is already declared in this module |
| E5090 | An import in a code body of a Python module the native library does not have, natively |
| E2240 | A name an import in a code body binds, used outside that body or before the import |
| E5173 | In a `cpython` space, an import in a code body of what Python cannot load as it runs |
| E0175 | `default` on something that is not one declaration |
| E2250 | A second declaration marked `default` |
| E0157 | A backtick in a module path, where every word is taken as it stands |
| E1144, E2094 | The import is written in a module that takes its imports from wires; see [Import wiring](modules-wiring.md) |

## How a module is found

`import X` and a non-relative `import from X` resolve nearest-first:

1. `X.jac` beside the importing file.
2. `X.jac` in each directory above it, up to and including the project's root, the directory that
   holds `jac.toml`.
3. neojac's own runtime modules (such as `sys` and `os`).
4. The native standard library.

So a project's module named like a standard one (`random.jac`) is the one its modules get, and a
module in a subdirectory imports a module at the project's root by its plain name.

A dotted path names directories: `import app.deep.x` is `app/deep/x.jac`, looked for from each of
the places above.

**Packages.** A directory `X` with an `__init__.jac` is the module `X`: `import X` loads
`X/__init__.jac`, which is preferred to a file `X.jac` beside the directory. A directory needs no
`__init__.jac` for the modules inside it to be imported by dotted path.

**Variants.** A module may have a file per target. For a module `X`, the first of these that exists
is used, and the others are not compiled:

| File | Used when building for |
|---|---|
| `X.<os>.<arch>.jac` | that system and processor |
| `X.<arch>.jac` | that processor: `aarch64`, `x86_64`, `wasm32` |
| `X.<os>.jac` | that system: `darwin`, `linux`, `windows`, `wasi` |
| `X.jac` | anything else |

Every variant declares the same public names; each holds the code, and the imports, that differ on
its target. A few declarations that differ are written in the one file instead, under a
`comptime if` on `target()` among the module's declarations
([comptime if](compile-time.md#among-declarations-and-members)). A module may also exist only as a variant: with `win.windows.jac` and no `win.jac`,
`win` is a module when building for Windows, and importing it for another target is W1100. In a space that runs on another host, the variant is named by the host instead
(`X.cpython.jac`, `X.node.jac`); see `neojac docs space`.

## Module code: `with entry`

```ebnf
module_code ::= "with" ("entry" | "exit")? (":" NAME)? block
```

A `with entry` block is code the module runs when it starts. A module may have any number of them.
The main module starts when the program does. Every other module starts the first time the program
uses it, and one the program never uses never starts: its code is not in the executable.

- **What starts a module:** the first of a call of one of its functions, a read or write of one of
  its globals, or making an instance of one of its classes (or of a class derived from one).
  Importing it at the top level does not; an import in a code body does, where it runs. Its code
  then runs once, before that use goes ahead.
- **Order within a module:** globals are given their values in the order written, and `with entry`
  blocks run in the order written. Declare a global above the entry blocks that read it.
- **A module imported for what its code does** is started by calling a function of it. The
  convention is a function named `start`, which may be empty: `registry.start();`.
- **Modules that use each other:** a use of a module from inside that module's own starting code,
  on the same thread, goes ahead with the module as far as it has got, as a cycle of imports does
  in Python.
- **An exception** from a module's code is raised at the use that started it. The module has not
  started, and its next use runs its code again from the top.
- **Threads:** one thread runs a module's code. Another that uses the module meanwhile waits for
  it to end.
- **Constant globals are there from the start.** A global whose value is a constant or a display
  of constants, functions and classes has its value before any code runs.
- **Hosts:** this is how a native or wasm program starts its modules. A JavaScript or CPython
  space starts a module when it is imported, as that host does.
- **`with entry:__main__`** runs only when its module is the program's main module. It does not run
  when the module is imported, nor under `neojac test`.
- **Names assigned in an entry block** are the module code's locals. Later entry blocks of the same
  module see them, and so does a `lambda` or a `def` written inside a block, which may assign them
  too; the module's top-level functions do not (W2001). State that functions share is a `glob`.
- **A `def` in an entry block of a name the module declares a `glob` of** assigns that global,
  where the `def` stands, by its own name: under a `try` or an `if`, it is how a module chooses a
  function as it starts, and the module's functions call the one chosen (below). A `def` of any
  other name is the module code's local, as an assignment is.
- **A module whose code awaits** runs all its entry blocks as one coroutine, to its end, when it
  starts ([Async](async.md#module-code-that-awaits)).
- **`return;`** in an entry block ends its module's code there: the rest of the block, and the
  module's entry blocks after it, do not run. The modules that import it run on.
- **A module with no entry block** runs nothing; a program whose main module has none starts and
  exits.

```jac
glob greeting: str = "hello";

def greet(name: str) -> str {
    return f"{greeting}, {name}";
}

with entry {
    who = "world";
    print("first block:", greet(who));
}

with entry:__main__ {
    print("main module:", __name__);
}

with entry {
    print("last block:", who);
    if who == "world" {
        return;
    }
    print("after the return");
}

with entry {
    print("a block after the return");
}
```

```output
first block: hello, world
main module: __main__
last block: world
```

```jac
import sys;

glob speak: Callable[[str], str] | None = None;

def shout(s: str) -> str {
    return speak(s) + "!";
}

with entry {
    if len(sys.argv) > 5 {
        def speak(s: str) -> str {
            return s.upper();
        }
    } else {
        def speak(s: str) -> str {
            return s.lower();
        }
    }
    print(shout("Hi"));
}
```

```output
hi!
```

```jac
# expect: W2001
with entry {
    count = 1;
}

def read -> int {
    return count;
}
```

`with exit` and an entry block named anything but `__main__` are refused (E5090).

### Module variables

| Name | Value |
|---|---|
| `__name__` | `"__main__"` in the program's main module, and another string in every other module |
| `__file__` | The absolute path of the module's file |
| `__doc__` | The module's docstring, `""` when it has none |

These are names inside the module. `othermodule.__name__` is not a member (E1145).

## Docstrings

A docstring is a string literal written immediately before the declaration it documents; a string
that opens the file is the module's `__doc__`. The rules are in [Docstrings](modules-docstrings.md)
(`neojac docs docstring`).

## Annexes

A module's code may be split over annex files, which are part of the module: they share its names
and are compiled with it. They are found by file name; nothing imports them.

**Impl annexes** hold `impl` blocks, the bodies of functions and methods the module declares
without one (`def area -> int;`). For a module `X.jac`, the compiler loads, in this order:

1. `impl/X.impl.jac`
2. `X.impl.jac` beside it
3. `X.impl/X.impl.jac`

and, in each of those three places, any number of parts `X.<part>.impl.jac`
(`impl/scene.faces.impl.jac` is a part of `scene.jac`), sorted by name.

A part belongs to the module its longest dotted prefix names: where `fs.windows.jac` exists,
`impl/fs.windows.impl.jac` is the annex of that variant, not a part of `fs.jac`.

`shapes.jac`:

<!-- example: not checked: the bodies are in the annex impl/shapes.impl.jac -->
```jac
obj Square {
    has side: int = 1;

    def area -> int;
}

def describe(s: Square) -> str;
```

`impl/shapes.impl.jac`:

<!-- example: not checked: an annex of shapes.jac, which declares what it implements -->
```jac
impl Square.area -> int {
    return self.side * self.side;
}

impl describe(s: Square) -> str {
    return f"square of area {s.area()}";
}
```

**Test annexes** hold `test` blocks. When `neojac test` runs a module `X.jac`, it also loads
`X.test.jac` beside it and `test/X.test.jac`. A test annex is not part of the module in a build.
See [Tests](tests.md).

## Access tags

```ebnf
access_tag ::= (":" ("protect" | "pub" | "priv"))?
```

A declaration's keyword may carry a tag: `def:pub run`, `glob:priv cache`, `obj:protect Account`.
A tag says who may call the declaration from another space of an app (`:pub` anyone, `:protect` a
signed-in caller); see `neojac docs space`. It does not hide a name from other modules: within one
program, every top-level name of a module can be imported, whatever its tag.

## Differences from Python

- `from m import a, b as c` is `import from m { a, b as c }`, and `from m import *` is `include m;`.
- Importing is declarative and happens before the program runs: a missing module or name is a
  compile error, not an `ImportError`, and there is no import inside a function.
- A module's top level holds no statements. What Python runs at import time is written in
  `with entry`, and `if __name__ == "__main__":` is `with entry:__main__`.
- A module's code runs at its first use, not where it is imported, and never for a module the
  program does not use. A module imported only for its side effects needs a call: `m.start();`.
  In a serving app a module that serves an endpoint, or declares a node or an edge type the app
  [keeps](../apps/data.md), starts with the program, which reads what it kept as it starts.
- Names assigned in `with entry` are not module globals; a global is declared with `glob`.
- Lookup is nearest-first from the importing file, not along a search path.
- A module has no `__dict__` and is not an object a program can add names to.

## Differences from the reference design

- A module's code runs at the module's first use; the reference design runs it when the module is imported.
- A reserved word in a module path or an import item is taken as it stands; a backtick there is an
  error (E0157).
- A missing module is an error (W1100) where the reference design warns.
