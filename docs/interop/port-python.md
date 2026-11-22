---
description: What neojac port makes of each Python construct - the Jac it becomes, and what it refuses.
keywords: port python, porting Python, Python to Jac
---
# Porting Python

`neojac port` translates a Python source file into a Jac module that behaves as the file does,
or refuses it ([port](../toolchain/port.md)). This page is the mapping: each Python construct
port translates and the Jac it becomes. It is printed from the table the translation itself
reads (`neojac port --mapping python`).

Every name is `any`, which is what a name in Python is: its operations are resolved as the
program runs, and raise `TypeError` where Python does. Annotations are not carried over yet.
Scaffolding keeps Python's meaning where Jac's would differ: a name the module's code binds is a
`glob` the code assigns, a local a nested function takes is declared at the top of its
function, a default that is not a constant is held in a variable made where the `def` runs.

| Python | Jac |
|---|---|
| A module's docstring | The module's docstring |
| `import m`, `import m as n` | `import m;`, `import m as n;` |
| `from m import a, b as c`, `from .m import a`, `from .. import a`; `from m import *` of a module of the project | `import from m { a, b as c }`, `import from .m { a }`, `import from .. { a }`; `import from m { ... }` of the names `m`'s `__all__` lists, or else of every name `m` binds that does not begin with `_` |
| `x = v` at module level: of a literal before any module code, or bound by the module's code | `glob x: any = v;`; or `glob x: any = None;`, and `x = v;` in the module's code |
| Any other statement at module level | A statement of the module's one `with entry { }` |
| `if __name__ == "__main__":` at module level; an `if` whose every test is the platform (`sys.platform == "win32"`, `sys.platform.startswith("linux")`, `os.name == "nt"`, a module's name bound once to one, `not`, `and`, `or`), at module level, in a class body or in code | `with entry:__main__ { }`; `comptime if target().os == "windows" { }` (`target` from `jaclang.comptime`): at module level, among the declarations for its defs, classes and imports and in the module's code for its statements; in a class body, among the members; a name a def binds under one test and a value under another, a `glob` of the branches that bind the value. A class body's `if` on anything else is the same `if` among the members, of a class Python makes where its statement runs (a cpython space) |
| `def f(a, b=1):` with a docstring, at module level or in a function; a `def` in the module's code (under an `if`, in a loop or a `try`); `@d` on a `def` at module level, in a function or in a class, with `@staticmethod` or `@classmethod` among them; `@property` alone, and its `@f.setter` | The docstring, then `def f(a: any, b: any = 1) -> any { }`; a local a nested function takes is declared at the top of the function; in the module's code, `def f_(...) { }` and `f = f_;` where the `def` runs, `f` a `glob`; `@d` on the `def`, which a cpython space makes where it stands with its decorators applied (a `static def` or a `class def`, with `@builtins.staticmethod` or `@builtins.classmethod` where the source has it under another decorator; `@builtins.property` under another decorator); a field with a `getter` and a `setter` |
| `def f(a, /, b, *args, c, d=1, **kw):` | `def f(a: any, /, b: any, *args_: any, c: any, d: any = 1, **kw: any) -> any { args: any = tuple(args_); }`: `*args` is a tuple |
| `class C(B):` with `__init__` binding `self.x` | `obj C(B) { has x: any; def init(...) { } }`, with an `__eq__` and a `__hash__` of identity when the class defines no `__eq__` |
| `x = v`, `x: T = v` (a first binding) | `x: any = v;` |
| `x += v`, and the other augmented assignments | `x += v;` |
| `a, b = v`, `(a, b)`, `return a, b`; `first, *rest = v`, `a, (b, c) = v`; `a = b = v` | `(a, b) = v as any;` (Jac unpacks only a tuple or a list it knows, and an `any` holding any iterable, as Python unpacks it), `(a, b)`, `return (a, b);`; a starred or nested target takes the items of `list(v)` one at a time, raising Python's `ValueError` when they do not fit; `v` is held in a variable and assigned to each target in turn |
| `if`/`elif`/`else`, `while`, a loop's `else` | The same, with braces |
| `for x in xs:`, `for k, v in d.items():` | `for x in xs { }`, `for (k, v) in d.items() { }` |
| `return`, `break`, `continue`, `assert c, m` | The same, each with its `;` |
| `pass` | Nothing: an empty block is `{}` |
| `raise E(...)`, `raise E`, `raise E(...) from c`, `raise` | `raise E(...);`, `raise E();` for a class, `raise E(...) from c;`, `raise;` |
| `with a() as x, b():`, a tuple of targets after `as` | `with a() as x, b() { }`, each name bound by `as` declared before it |
| `try:` with `except E as e:`, `except (A, B):`, `except:`, `else:` and `finally:` | `try { } except E as e { } except (A, B) { } except BaseException { } else { } finally { }` |
| `global x`, `nonlocal x` | Nothing: assigning a global's name, or an enclosing function's local, assigns it |
| `lambda x, y=1: x + y` | `lambda (x: any, y: any = 1) -> any { x + y }` |
| `f(*xs, **kw)`, `[*xs, y]`, `{**d, k: v}` | The same |
| `(x := v)` | `(x := v)` |
| `yield v`, `yield from xs` as statements | `yield v;`, `yield from xs;`, in a function that returns `Generator[any, any, any]` |
| `async def`, `await`, `async with`, `async for` | The same |
| `del x, xs[i], d[k]`; `del o.a` | `del x, xs[i], d[k];`; `delattr(o, "a");` |
| An int, a float, a str, bytes, `True`, `False`, `None`, `...` | The same literal |
| A name that is a Jac keyword, such as `by` | The name behind a backtick, `` `by `` |
| `+ - * / // % ** @ << >> & \| ^`, `- + ~ not`, `and`, `or` | The same operators |
| `== != < <= > >= in`, `not in`, `is`, `is not`, chained | The same comparisons |
| `f(a, k=v)`, `o.m(a)`, `C(a)` | The same call |
| `o.a`, `xs[i]`, `xs[a:b:c]`; `f.a` of a function `f` declared by `def` with no decorator, read, assigned or augmented | The same; `getattr(f as any, "a")`, `setattr(f as any, "a", v);`, which a Jac function value has on a cpython space |
| `[a, b]`, `{k: v}`, `{a, b}` | The same displays |
| `a if c else b` | `a if c else b` |
| `f"{x!r:>4} and {y}"` | The same f-string |
| `[e for x in xs if c]`, and the set, dict and generator forms | The same comprehension, a tuple of targets in parentheses |

## What is refused

Anything not in the table is refused with E4001, and nothing is written for the file. So is a
construct in the table whose Jac would mean something else (E4005):

- **A default value that is not a constant, of a function made in a loop.** Python makes one
  for each function it makes; the variable port holds it in would be shared.
- **A comprehension whose variable a function made in it takes.** Python's comprehension has
  one variable, and Jac's a variable for each pass.
- **`global x` in a function inside one whose local `x` is.** Assigning `x` in Jac assigns the
  enclosing function's local.
- **The value of a `yield`.** A Jac generator's `yield` gives None, and it has no `send`.
- **A member declared in two arms of a class body's `if` whose test only the running program
  knows.** A Jac class declares each member once.
- **A module-level function, class or import that the module's code binds again.** Its Jac
  name is bound once, as the program starts.
- **An attribute a method binds that `__init__` does not always bind.** A Jac object has exactly
  its declared fields.
- **`from m import *` whose names port cannot know:** of a module not of the project, or of
  one whose `__all__` is not one list of names written out, that imports `*` itself, reaches
  its names through `globals()`, binds one only in a function or deletes one in a block; and
  one that binds a name the importing module also binds.
- **Python's `tuple`, `type`, `frozenset`, `bytearray` and `complex` used as values**
  (`defaultdict(tuple)`); `int`, `float`, `str`, `bytes` and `bool` are written as they are,
  and `list`, `set` and `dict` as `list[any]`, `set[any]` and `dict[any, any]`.
- **A variable or a parameter of two leading underscores in a class's code** (`__x`), which
  Python renames with the class's name; an attribute, a field or a method so named is written
  as Python renames it (`self.__x` in `class C` is `self._C__x`).
- **A read of a name nothing in the module binds, nor Python's builtins** (`left_out()`): Python
  raises NameError where it runs.
- **A method named `init` or `postinit`, `x is 1`, an int literal past 64 bits.**

## What differs in what is written

- **An int is 64 bits.** Arithmetic past that raises `OverflowError` where Python grows the int.
- **An object with no `__repr__` prints as Jac prints it** (`Counter(count=3)`), where Python
  prints its class and address.
- **A name is bound from the start of its scope.** A module-level name bound by the module's
  code is a `glob` that is None until the code binds it, and a local declared at the top of its
  function is None until its first binding; reading one earlier gives None (or the literal it
  was declared with), where Python raises `NameError` or `UnboundLocalError`.

Each is a gap to close before Python's port is complete.
