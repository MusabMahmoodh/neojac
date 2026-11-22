---
description: Using npm packages and Node's built-in modules from a native Jac program - imports by quoted name, how their names are checked from TypeScript declarations, how values cross, Node's loop, and neojac node, npm and npx.
keywords: npm, npm package, Node.js, JsObject, JsNull, js_error, js, node:, Node-API, TypeScript declarations, js_add, js_truthy, js_item, js_method, js_iter, js_for_in, js_typeof, js_meta, js_global, js_mod, js_shl, js_band, js_new_target, new.target, extends, CommonJS, require
---
# npm and Node

A native Jac program imports an npm package, or one of Node's built-in modules, by its quoted
name. Node then runs inside the program's own process, and what the module gives is used from Jac
directly.

```jac
import from "node:path" { basename, join }
import from "node:url" { URL }
import from "node:util" { format }

with entry {
    print(join("docs", "interop"), basename("/x/y.txt"));
    print(format("%s is %d", "x", 5));
    u = URL.new("https://example.org:8080/docs?q=jac");
    print(u.hostname, u.searchParams.get("q"), type(u).__name__);
    port: int = int(u.port);
    print(port + 1);
}
```

```output
docs/interop y.txt
x is 5
example.org jac JsObject
8081
```

Node is neojac's own: nothing needs installing on the machine. A package from the registry is
listed in the project's `jac.toml` and installed with `neojac install`, by npm on that Node.

This page is about JavaScript a native program calls. A space whose host is `node` or `browser`,
whose own Jac is compiled to JavaScript, is described in [Apps](../apps/index.md)
(`neojac docs apps`).

## Installing packages

A project's npm packages are an npm tree of its `jac.toml`: a `[npm."<directory>"]` table, which
is the `package.json` of that directory ([Packages](../toolchain/packages.md)):

```sh
neojac install --npm nanoid lodash --tree eco/app    # the first packages name the directory of the tree they make
neojac install --npm @types/lodash               # declarations, for a package that ships none
```

```toml
[npm."eco/app".dependencies]
nanoid = "^5.1.0"
lodash = "^4.17.21"
"@types/lodash" = "^4.17.0"
```

They are installed in `eco/app/node_modules`, and `jac.lock` records what npm resolved. On a fresh
clone, `neojac install` installs them again. `main.jac`, in that project:

<!-- example: not checked: needs nanoid and lodash installed in node_modules -->
```jac
import from "lodash" { default as _ }
import from "nanoid" { customAlphabet, nanoid }

with entry {
    pairs: list[list[int]] = _.chunk([1, 2, 3, 4], 2);
    make = customAlphabet("abc", 8);
    id: str = make();
    print(pairs, len(nanoid(10)), len(id));
}
```

```text
[[1, 2], [3, 4]] 10 8
```

## How an import is resolved

- `import from "pkg" { a, b }` imports the module as an ES `import` of that specifier does on Node:
  Node's own resolution and export conditions, from the directory of the project's npm tree: its
  only tree, or the one the module's space names in `jac.toml`.
  It is settled as the program starts, before its entry code runs.
- Each name is the module's export of that name. A CommonJS module's `module.exports` is its
  `default`: `import from "lodash" { default as _ }` is the form to write, and `_.chunk` its
  function. Its properties are not named exports, as in Node's ES modules, so
  `import from "lodash" { chunk }` raises `ImportError: cannot import name 'chunk' from 'lodash'`
  as the program starts. Checking catches that only where the package has declarations
  (`@types/lodash` makes it E1145); without them the import passes `neojac check`.
- `import "pkg";` imports a module for its effect.
- `node:` names Node's built-in modules (`node:path`, `node:fs/promises`, `node:events`, ...).
- The program reads its packages from the tree's `node_modules` in the project as it runs,
  wherever the program itself is. An app's artifact carries them with it
  ([Building apps](../apps/building.md)). Node starts the first time the program imports a JavaScript module.

## A project's own JavaScript

A JavaScript or TypeScript file of the project is a module of it, named by its path from
`archwire.jac` as a Jac module is (`kit/loud.js` is `kit.loud`). A Jac module takes its exports
through a [wire](../language/modules-wiring.md), as it takes another Jac module's:

<!-- example: not checked: a graph import block is valid only in a file named archwire.jac, beside the modules it wires -->
```jac
graph import {
    kit.loud ++> page { shout, default as pick }
    kit.loud as loud ++> page;
    kit.marks --> kit.loud { mark }
}
```

- `{ shout }` binds the export `shout`, `{ default as pick }` the default export, and a wire with
  no names the module's namespace, under the name `as` gives it. A module wired whole under a
  dotted name and no `as` is loaded for its effect.
- A wired name the file does not export is E1145, read from the file by TypeScript. A CommonJS
  file states no exports, so any name is taken of it.
- The file writes its own imports, of packages and of other files of the project. Each import of
  another file of the project is declared by a `-->` wire, which TypeScript holds to the source
  ([Declared wires](../language/modules-wiring.md#declared-wires---)).
- Under an `archwire.jac` the file is not imported by its path: `import from "./kit/loud.js"
  { shout }` is E1144, whose message gives the wire to write. A path import stays for what is no
  module: a stylesheet or an asset a browser space's bundler takes.
- **A file imports the space's Jac modules** as JavaScript modules: in a node space, `tone.jac`
  is the module `tone.js` beside it, so `kit/echo.js` writes `import { tone, bump } from
  "../tone.js";`, which the wire `tone --> kit.echo { tone, bump }` declares, and its names are
  held to the Jac module. A module's [default](../language/modules.md#a-modules-default) is its
  default export.
- **A CommonJS file** (`.cjs`, or a `.js` where Node reads the place as CommonJS) that `require`s
  a Jac module is given it as CommonJS: its exports, and for `require` itself the module's
  default where it has one.
- **A Jac module's `with entry` code runs once JavaScript first reaches the module**; the space's
  entry module's runs at the end of its loading.
- A node space carries the file, and every file of the project it imports, beside its own modules,
  each at its path in the project, as it is: Node runs it, so what it imports must resolve on
  Node. A browser space's bundler reads it where it is. A native program imports it from where it
  is, and an app's artifact carries it at the same path.

## How names are checked

neojac reads a package's TypeScript declarations: its own `.d.ts` files, or those of
`@types/<pkg>` when it ships none. It resolves the package as an ES import does, under the
`import` condition, so a package with separate ES and CommonJS builds is checked against its ES
build's declarations.

- A name the declarations don't export is refused where it is imported (E1145).
- A package with no declarations is dynamic: its names are not checked, and a name it lacks is an
  `ImportError` as the program starts.
- Node's built-in modules are not checked: `import from "node:path" { nope }` builds, and raises
  `ImportError` as the program starts.
- Only the imported names are checked. An attribute of a JavaScript value (`_.nope`) is looked up
  as the program runs, an `AttributeError` when the object has no such property.
- Types are not checked. The declarations' parameter and return types are not applied to a call,
  whether the function is a named import (`nanoid` of `import from "nanoid" { nanoid }`) or a
  member of a default import (`_.kebabCase`): `nanoid("ten")` passes `neojac check`, and so does
  `n: int = _.kebabCase("A B")`. A call's result is a JavaScript value, converted where a Jac type
  is wanted ([below](#javascripts-values-in-jac)); that one is a `TypeError` as the program runs
  (`expected int, found str`). Annotate what a call returns with the type it is.
- A build reads the declarations again when they change.
- The host's own names (`Date`, `RegExp`, `Symbol`, `isNaN`) are its declarations' globals. A name
  that is Jac's wins: `Number` is Jac's interface of the number types, so `Number.isNaN(x)` is
  E1030. JavaScript's `Number` is `globalThis.Number`, as every global is `globalThis`'s:
  `globalThis.Number.isNaN(x)`, `globalThis.Number.MAX_SAFE_INTEGER`.

neojac reads declarations with TypeScript 6.0.3, which it fetches the first time it needs it: that
first check needs the network.

## JavaScript's values in Jac

An object, function or symbol JavaScript gives is a `JsObject`. Its properties are its attributes
(`o.n`) and its items (`o["n"]`); calling a function read from an object, either way, calls it with
that object as `this`. `C.new(args)` is JavaScript's `new C(args)`. Iterating it iterates it as
JavaScript does, and `len()` reads its `length`.

A primitive is the Jac value it is:

| JavaScript | Jac |
|---|---|
| `undefined` | `None` |
| `null` | `JsNull`, from the runtime's `js` module (`import from js { JsNull }`) |
| a boolean | `bool` |
| a number | `int` when it is whole and an int holds it (`2**60` is `1152921504606846976`), else `float` (`-0` is `-0.0`, `2**63` is `9.223372036854776e+18`) |
| a BigInt | `int`; `OverflowError` past 64 bits |
| a string | `str`; `ValueError` for one holding a lone surrogate |

A `JsObject` fits wherever a Jac type is wanted, and becomes a Jac value as it arrives there,
copied: an array a `list` of what its items become, a plain object (whose prototype is
`Object.prototype` or `null`) or a `Map` a `dict`, a `Uint8Array` (a `Buffer` among them)
`bytes`. Any other object is a `TypeError` where another type is wanted. A cycle the copy reaches
is one value, reached again.

A `JsObject` equals only itself: `a == b` is whether they are the same JavaScript value, so two
objects with the same properties are not equal. `copy.copy` of one is that same value.

## Jac's values in JavaScript

| Jac | JavaScript |
|---|---|
| `None` | `undefined` |
| `JsNull` | `null` |
| `bool`, `float`, `str` | a boolean, a number, a string |
| `int` | a number; `OverflowError` past 2**53, where a number stops being exact |
| `bytes`, `bytearray` | a new `Buffer` of its bytes |
| `list`, `tuple` | a new array of what its items become |
| `dict` | a new plain object when its keys are all strs (each an own data property, `__proto__` among them), else a new `Map` |
| a function or lambda | a JavaScript function that calls it with every argument JavaScript passes |
| any other Jac object | a JavaScript object wrapping it |
| a `JsObject` | what it holds |

A Jac function or object stays one JavaScript value for as long as JavaScript holds it, and comes
back to Jac as itself: `ee.off("x", cb)` removes the listener `ee.on("x", cb)` added. A JavaScript
caller may pass more arguments than a Jac function names (`array.map` passes three), so a callback
takes `*rest`.

```jac
import from js { JsNull }
import from "node:vm" { runInThisContext }

obj Thing {
    has x: int = 1;
}

with entry {
    kind = runInThisContext(
        "(x) => x === null ? 'null' : Array.isArray(x) ? 'array' : x instanceof Map ? 'map' : Buffer.isBuffer(x) ? 'buffer' : typeof x",
    );
    keyed: dict[any, any] = {1: "a"};
    print(kind(None), kind(JsNull), kind(True), kind(5), kind(1.5), kind("s"));
    print(kind([1]), kind((1, 2)), kind({"a": 1}), kind(keyed), kind(b"ab"), kind(Thing()));
    back = runInThisContext("(x) => x");
    t = Thing(x=7);
    print(back(t) is t, back(None) is None, back(JsNull) is JsNull);
    arr = runInThisContext("[1, 2, 3]");
    xs: list[int] = arr;
    d: dict[str, any] = runInThisContext("({ a: 1, b: [2] })");
    print(xs, d, arr[0], len(arr), [x * 2 for x in arr]);
    print(
        runInThisContext("1.5"),
        runInThisContext("2"),
        runInThisContext("2n ** 40n"),
        runInThisContext("undefined"),
    );
    o = runInThisContext("({ n: 3, f() { return this.n; } })");
    print(o.n, o["n"], o.f(), o["f"]());
}
```

```output
undefined null boolean number number string
array array object map buffer object
True True True
[1, 2, 3] {'a': 1, 'b': [2]} 1 3 [2, 4, 6]
1.5 2 1099511627776 None
3 3 3 3
```

A function whose first parameter is named `self`, outside a class, is called from Jac with the
object first, as any function is (`bump(o, 2)`). Called by JavaScript (handed to a JavaScript
function, stored on a JavaScript object, or imported by a JavaScript file), `self` is
JavaScript's `this`: `{ n: 1, bump }.bump(2)` calls it with the object as `self`. A lambda takes
no `this`, as a JavaScript arrow function takes none.

## JavaScript's own operators: the `js` module

Jac's operators mean what Jac says of Jac's types. Where a program needs what JavaScript does
with values of any type (code `neojac port` made of untyped JavaScript), the runtime's `js`
module gives JavaScript's own operations, each a function. On a JavaScript host each is the
operator it names; natively each runs in the program's Node.

| Function | JavaScript |
|---|---|
| `js_truthy(x)` | `!!x`: false for `undefined`, `null`, `false`, `0`, `NaN` and `""` |
| `js_add(a, b)`, `js_sub(a, b)`, `js_mul`, `js_div`, `js_pow` | `a + b` (a string where either is one), `a - b`, `*`, `/`, `**`, converting as JavaScript does |
| `js_lt`, `js_le`, `js_gt`, `js_ge` | `<`, `<=`, `>`, `>=`: strings by their UTF-16 code units, else as numbers |
| `js_mod(a, b)` | `a % b`: the remainder, with the dividend's sign |
| `js_shl`, `js_shr`, `js_ushr`, `js_band`, `js_bor`, `js_bxor` | `<<`, `>>`, `>>>`, `&`, `\|`, `^`: each operand made a 32-bit integer (both BigInts, or neither), `>>>`'s result unsigned |
| `js_inc(x)`, `js_dec(x)`, `js_number(x)` | What `x++` and `x--` make `x`; `+x` |
| `js_same(a, b)` | `a === b` |
| `js_typeof(x)` | `typeof x` |
| `js_item(o, k)`, `js_set_item(o, k, v)` | `o[k]`, `o[k] = v` |
| `js_method(o, name, ...)` | `o[name](...)`, an array's or a string's own method among them |
| `js_iter(x)`, `js_for_in(o)` | `x[Symbol.iterator]()`, what `for ... of` steps through; the keys `for (k in o)` visits |
| `js_meta()` | The calling module's `import.meta`: its `url`, `filename`, `dirname` and `main` |
| `js_new_target()` | `new.target` of the call that reached the function it is written in: the function JavaScript called with `new`, else `None` ([below](#a-class-with-a-javascript-base)) |
| `js_global(name)` | The global `name` read where the call is written |
| `js_error(e)` | What JavaScript threw that the Jac exception `e` is |
| `JsNull` | `null` |

```jac
import from js {
    js_add,
    js_band,
    js_bor,
    js_bxor,
    js_for_in,
    js_lt,
    js_method,
    js_mod,
    js_same,
    js_shl,
    js_shr,
    js_truthy,
    js_typeof,
    js_ushr,
}

with entry {
    print(js_add(1, "a"), js_add(2, 3), js_lt("10", "9"), js_lt(10, 9));
    print(js_truthy([]), js_truthy(""), js_typeof(None), js_same(0.0, -0.0));
    print(js_method([3, 1, 2], "join", "-"), list(js_for_in({"a": 1, "b": 2})));
    print(js_mod(-7, 2), js_mod(7.5, 2), js_shl(1, 33), js_shr(-8, 1), js_ushr(-1, 0));
    print(js_band("6", 3), js_bor(4, "3"), js_bxor(5, 1));
}
```

```output
1a 5 True False
True False undefined True
3-1-2 ['a', 'b']
-1 1.5 2 -4 4294967295
2 7 4
```

## A class with a JavaScript base

On a JavaScript host, a class whose base is a JavaScript class (a global such as `Error`, or one an
npm package exports) is made by JavaScript: it is a JavaScript `class ... extends`, and its objects
are JavaScript's, so `instanceof`, a stack trace and the base's own methods see what they expect.

- **Its `init` is the constructor**, and `super.init(...)` is `super(...)`, which makes the
  object. `init` calls it once, as a statement of its own body (E2253), and reads or sets `self`
  only after it (E2252): what an argument needs is worked out before it.
- **Its `has` fields are the object's**, its methods the class's, and the base's are inherited as
  JavaScript inherits them.
- **It derives from the JavaScript class alone** (E2251).
- **`js_new_target()`** of `js` is JavaScript's `new.target` where it is written: the class or
  function JavaScript called with `new`, and `None` where it was called without `new` or by Jac.
- A raised instance is the JavaScript exception, caught by its class as any Jac exception is.

<!-- example: not checked: runs in a node space -->
```jac
import from js { js_new_target }

class AppError(Error) {
    has code: int = 0;

    def init(m: str, code: int) {
        super.init(m);
        self.code = code;
        print("made by new:", js_new_target() is not None);
    }

    def describe -> str {
        return f"{self.message} ({self.code})";
    }
}

def plain -> any {
    return js_new_target();
}

with entry {
    e = AppError("bad", 7);
    print(e.describe(), isinstance(e, Error), plain());
    try {
        raise AppError("thrown", 2);
    } except Error as err {
        print("caught", err.message);
    }
}
```

```text
made by new: True
bad (7) True None
made by new: True
caught thrown
```

## Exceptions

A JavaScript exception reaching Jac is a `TypeError` for a `TypeError`, a `ValueError` for a
`RangeError`, and a `RuntimeError`, its message prefixed with the error's name, for anything else.
`js_error(e)` is what was thrown, a `JsObject` whose `.name`, `.code` and other properties read as
in JavaScript, or `None` for an exception that did not come from JavaScript. A Jac exception thrown
into JavaScript is a `TypeError`, a `RangeError` (for a `ValueError`) or an `Error` named after its
class, with its message; it is the same Jac exception again if it comes back.

```jac
import from js { js_error }
import from "node:vm" { runInThisContext }

with entry {
    for src in [
        "null.x",
        "new Array(-1)",
        "(() => { const e = new Error('nope'); e.code = 'E_NOPE'; throw e; })()",
    ] {
        try {
            runInThisContext(src);
        } except Exception as e {
            print(type(e).__name__, "|", e, "|", js_error(e).name);
        }
    }
    try {
        runInThisContext("(() => { const e = new Error('x'); e.code = 'ENOENT'; throw e; })()");
    } except RuntimeError as e {
        print(js_error(e).code);
    }
    catcher = runInThisContext(
        "(f) => { try { f(); } catch (e) { return e.constructor.name + ': ' + e.message; } }"
    );
    print(catcher(lambda (*rest: any) -> any { raise ValueError("bad value"); }));
    try {
        runInThisContext("({})").missing;
    } except AttributeError as e {
        print("AttributeError:", e);
    }
    try {
        runInThisContext("(x) => x")(2 ** 53 + 1);
    } except OverflowError as e {
        print("OverflowError");
    }
}
```

```output
TypeError | Cannot read properties of null (reading 'x') | TypeError
ValueError | Invalid array length | RangeError
RuntimeError | Error: nope | Error
ENOENT
RangeError: bad value
AttributeError: 'Object' object has no attribute 'missing'
OverflowError
```

## Node's loop

Node's event loop runs as it does in `node`:

- The program's code between two waits is one task of the loop. What its calls queue (promise
  reactions, `process.nextTick` callbacks) runs when it waits or ends.
- `await` of a `JsObject` that is a promise, in an async function, runs the loop until the promise
  settles, and gives its value or raises its rejection. Waiting inside a Jac function that
  JavaScript called is a `RuntimeError`: the loop cannot run there.
- A rejection no handler took is reported as Node reports it, and ends the program.
- When the entry code ends normally, the loop runs out: timers and callbacks still pending run,
  then `beforeExit` and `exit`, as Node's main ends.
- `sys.exit()` and an uncaught Jac exception end the program as `process.exit()` does: `exit`
  handlers run, the loop does not. An uncaught JavaScript exception, and `process.exit()` called
  from JavaScript, end it as they end Node.
- Node is used from the thread that started it. A call from another thread is a `RuntimeError`.

```jac
import from "node:events" { EventEmitter }
import from "node:timers" { setTimeout }

with entry {
    ee = EventEmitter.new();
    seen: list[any] = [];
    cb = lambda (*args: any) -> any {
        seen.append(args[0]);
        return None;
    };
    ee.on("tick", cb);
    ee.emit("tick", 7);
    ee.off("tick", cb);
    ee.emit("tick", 9);
    print(seen, ee.listenerCount("tick"));
    setTimeout(lambda -> None { print("timer fired") }, 5);
    print("end of entry");
}
```

```output
[7] 0
end of entry
timer fired
```

## neojac node, npm and npx

`neojac node` runs Node 26 with its own command line, and `neojac npm` and `neojac npx` run the npm
it ships:

```sh
neojac node -e 'console.log(process.version)'
neojac node app.ts                 # TypeScript's types stripped, as Node does
neojac npm ls
neojac npx tsc --version
```

- Node is built into neojac and runs in neojac's own process, with its own C++ and libuv compiled
  by neojac, V8, ICU with every locale's data, and the OpenSSL, zlib, Zstandard, SQLite and libffi
  the toolchain also gives CPython. Its built-in modules are all there, `node:worker_threads`,
  `node:zlib`'s Brotli and `node:sqlite`'s sessions among them, and so is `Temporal` (dates,
  durations, time zones' rules and other calendars).
- `lib/node/bin/node` in the toolchain is a link to neojac, which started by that name is that
  Node; it is the path `process.execPath` names, by which npm and `child_process` start Node again.
  `neojac node`, `npm` and `npx` put its directory first on `PATH`, so a script npm runs finds
  `node` there.
- npm is the one Node ships, in the toolchain's `lib/node/npm/`. In a Jac project, `neojac npm`
  and `neojac npx` run in an npm tree of `jac.toml`, in its directory, and `jac.toml` and `jac.lock`
  take what they wrote there ([Packages](../toolchain/packages.md#running-npm)). Where there is no
  `jac.toml`, they are npm as it is anywhere.
- Node exports Node-API, Node's C++ API, V8's and libuv's (what their headers mark for export), as
  Node's own Windows build does. So the native addons packages ship load as they do on Node:
  Node-API addons, and V8 addons built against the same C++ library, libc++. Their headers are in
  `lib/node/include/`; build one with [`neojac cc`](c-and-cpp.md) (`-shared -fPIC` on Linux,
  `-bundle -undefined dynamic_lookup` on macOS). An addon of Node's C++ API and V8's (`node.h`,
  `v8.h`) builds with `neojac c++` as node-gyp builds one: in C++20, with the module's name
  defined.

```sh
neojac c++ -std=c++20 -DNODE_GYP_MODULE_NAME=hello -bundle -undefined dynamic_lookup \
    -I <toolchain>/lib/node/include hello.cc -o hello.node
neojac node -e 'console.log(require("./hello.node").hello(14))'
```

## Platforms and size

Node is in the toolchain for Linux (x86_64 and arm64) and macOS on Apple silicon. On Windows,
`neojac node` says the toolchain has no Node. A program can import JavaScript only when it is built
for the platform neojac runs on, with that platform's Node; a build for another platform refuses
each such import (E5090).

A program that imports JavaScript links Node, so it is large: over 100 MB.

## What is rejected

| Code | Condition |
|---|---|
| E1145 | A name the package's declarations don't export |
| W1100 | A package that is not installed, or not among the packages of the tree the import resolves in: `cannot find module` |
| E1287, E1288 | The module's space names a tree `jac.toml` does not declare, or none of several |
| E5160 | The tree's packages are not installed as `jac.toml` and `jac.lock` say |
| E5090 | A JavaScript import in a build for a platform without the toolchain's Node |

As the program runs: `ImportError` for an export an undeclared package or a built-in module
lacks, `AttributeError` for a property an object lacks, `OverflowError` for an int past 2**53 sent
to JavaScript.

## Differences from Python and from the reference design

- Pyodide's `JsProxy` is the nearest thing in Python. As there, a missing property is an
  `AttributeError` rather than `undefined`, and `C.new(...)` is `new C(...)`.
- `import from "lodash" { chunk }` fails for a CommonJS package whose exports Node cannot list,
  exactly as `import { chunk } from "lodash"` fails in an ES module on Node: import its `default`.
- `str()` of a `JsObject` is JavaScript's `String()` of it: an array prints as `1,2,3`. Convert it
  to a Jac value first (`xs: list[int] = arr`) to print it as a list.
