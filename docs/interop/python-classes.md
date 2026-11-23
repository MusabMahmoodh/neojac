---
description: What a cpython space makes as Python does - a class with a Python base, a Python decorator or a run-time if in its body, and a class in a code body, made where its statement runs; decorators that run as a function is made; annotations Python reads; doc strings; imports in a code body; generators and raise of any object - and what each is refused as elsewhere.
keywords: host-made class, Python base, NamedTuple, dataclass, total_ordering, class decorator, run-time decorator, staticmethod, classmethod, annotations, inspect.signature, __annotations__, Annotated, typing.Any, Python class in Jac
---
# Classes and decorators in a cpython space

A space whose host is `cpython` is Jac lowered to Python and run on neojac's CPython
([Hosts](../apps/hosts.md#cpython)). There, Python's own machinery runs on Jac's declarations: a
class can be made by a Python base or a Python decorator, a function's decorators run as Python
runs them, and Python reads a function's annotations and doc string. This page says what Python
makes in such a space, and what the same program is in a space of another host.

The examples on this page are the module `main` of a project whose `archwire.jac` says

<!-- example: not checked: a project's archwire.jac, which names main.jac beside it -->
```jac
graph layers {
    layer all { *; }
}

graph spaces {
    space s: cpython { entry main; }

    app s { run s; }
}
```

and each prints what is shown under it with `neojac run s`.

## Classes Python makes

A class is made by Python, as its `class` statement runs, when it has any of these:

- **a base that is a Python name** (`NamedTuple`, `enum.Flag`, a SQLModel or pydantic model), or
  a base that is such a class;
- **keywords** after its bases (`class Item(Base, table=True)`);
- **a decorator that is not a compile-time function of the program**: a Python callable
  (`@dataclass`, `@functools.total_ordering`), or a function of the program's own
  (`@retry_on_failure()`, [below](#a-class-decorated-by-a-function-of-the-program));
- **an `if` among its members that is not `comptime`**, whose test is known only as the program
  runs.

Such a class is Python's, from its body:

- **Its `has` fields are the class body's annotated names**, with their values, evaluated once as
  the class is made, and its annotations as written (`any` is `typing.Any`).
- **Its static fields are the body's plain assignments**, and its keywords are the class
  statement's.
- **Its methods are as written.** Jac generates no constructor, `__eq__`, `__hash__` or
  `__repr__` for it: its base's or its decorator's machinery reads the fields. A Python
  `__init__` is its constructor.
- **It is made where its statement stands**, in order with the module's `with entry` code, as
  Python makes a class where its `class` statement runs.
- **Its comparisons, arithmetic and attributes are Python's.** A call of the class, and a member
  it does not declare (one its base gives it), are dynamic to the checker; an operator no Jac
  method of the class defines is too (`total_ordering`'s `>=`). An instance takes any attribute:
  `self.pid = pid` in an `__init__` adds one.

<!-- example: not checked: runs in a cpython space -->
```jac
import builtins;
import functools;
import from dataclasses { dataclass, field }
import from typing { NamedTuple }

@functools.total_ordering
@dataclass(frozen=True)
class Ver {
    has major: int;
    has minor: int = 0;
    has tags: list[str] = field(default_factory=builtins.list);

    def __lt__(other: any) -> bool {
        return (self.major, self.minor) < (other.major, other.minor);
    }
}

class Pair(NamedTuple) {
    has left: int;
    has right: str | None = None;

    def both -> str {
        return str(self.left) + "/" + str(self.right);
    }
}

with entry {
    print(Ver(1) < Ver(1, 2), Ver(2) >= Ver(1, 9), Ver(1, 2) == Ver(1, 2), Ver(3));
    p = Pair(1);
    print(p, p.both(), p._replace(left=2));
}
```

```text
True True True Ver(major=3, minor=0, tags=[])
Pair(left=1, right=None) 1/None Pair(left=2, right=None)
```

`Ver(1).major = 2` raises `dataclasses.FrozenInstanceError`, as Python's does.

### A class decorated by a function of the program

A decorator of the program's own that is not a compile-time function (a function that takes the
class and gives one back, or a call that makes such a function) is Python's too: it runs as the
class is made, as `@retry_on_failure()` runs on a test class in Python. The class is then made by
Python, as with a Python decorator, so Jac generates no constructor for it.

<!-- example: not checked: runs in a cpython space -->
```jac
def tagged(label: str) -> any {
    def mark(cls: any) -> any {
        cls.label = label;
        return cls;
    }
    return mark;
}

@tagged("slow")
obj Probe {
    has n: int = 0;

    def twice -> int {
        return self.n * 2;
    }
}

with entry {
    p = Probe();
    p.n = 4;
    print(Probe.label, p.twice());
}
```

```text
slow 8
```

In a native or JavaScript space the same decorator is E1490: a decorator there is a
compile-time function.

### A class body's run-time `if`

An `if` among a class's members runs as the class is made, and the members of the arm it takes are
the class's. A member declared in two arms is refused: a Jac class declares each member once.

<!-- example: not checked: runs in a cpython space -->
```jac
import math;

glob HAS_EXTRA: bool = math.pi > 3;

class Proc {
    def __init__(pid: int) -> None {
        self.pid = pid;
    }

    if HAS_EXTRA {
        def extra -> int {
            return self.pid * 2;
        }
    } else {
        static has kind: str = "none";
    }
}

with entry {
    print(Proc(3).extra(), hasattr(Proc, "kind"));
}
```

```text
6 False
```

An `if` that tests the platform is a `comptime if`, which every host decides as the program
compiles ([comptime if](../language/compile-time.md#among-declarations-and-members)).

### A class in a code body

A class declared in a function, a method or a `with entry` block is made by Python where its
statement runs, each time it runs, as a Python `class` statement in a function is: two calls make
two classes.

<!-- example: not checked: runs in a cpython space -->
```jac
import reprlib;

def shower -> any {
    class Short(reprlib.Repr) {
        has kind: str = "short";

        def repr_str(x: any, level: any) -> str {
            return x[:3];
        }
    }
    return Short;
}

with entry {
    first = shower();
    print(first().repr("abcdef"), first.kind, first is shower());
}
```

```text
abc short False
```

A class there that reads a name of the body it is in (a parameter, a local) is not made yet
(E5177): Python would close over the name, and neojac does not check a class's methods as
closures of the body.

### In a space of another host

A native or JavaScript program's classes are known as it compiles, so none of these is made there:

| Code | In a native or JavaScript space |
|---|---|
| E5174 | A class or a function decorated by a Python callable |
| E1490 | A class or a function decorated by a function of the program that is not compile-time |
| E5175 | An `if` among a class's members that is not `comptime` |
| E5176 | A class in a code body: declare it at the module's top level |
| E2101 | Keywords after a class's bases |

A class whose base is a Python class is, natively, a subclass of it in the embedded interpreter
([Python](python.md)).

## Decorators

In a cpython space, a decorator that is not a compile-time function of the program
([Decorators](../language/decorators.md)) runs as Python runs it: on the function as it is made,
the nearest the `def` first, and its result is what the name holds. A function decorated so is
made where its `def` stands; a method, as its class is made.

<!-- example: not checked: runs in a cpython space -->
```jac
import functools;

def twice(f: any) -> any {
    @functools.wraps(f)
    def wrapper(*args: any) -> any {
        return f(*args) * 2;
    }
    return wrapper;
}

@twice
def area(w: int, h: int) -> int {
    return w * h;
}

obj Box {
    @functools.cache
    static def made(n: int) -> int {
        return n + 1;
    }
}

with entry {
    print(area(3, 4), area.__name__, Box.made(1), Box.made.cache_info().misses);
}
```

```text
24 area 2 1
```

A `static def` is Python's `staticmethod` and a `class def` its `classmethod`, made one after
its decorators run. Where Python would apply the wrapper among other decorators, the method names
it in its place: `@builtins.staticmethod` on a `static def`, `@builtins.classmethod` on a
`class def`. On any other method it is E2241.

## Annotations

Every function's annotations are Python's, as `inspect.signature` and `typing.get_type_hints`
read them, so a library that reads them (FastAPI's parameters and dependencies, pydantic's
fields) finds what the source said:

- a Jac class is the class, and a Python name is its value;
- `Annotated[T, ...]` is carried with its metadata, and to the checker it is `T`;
- a `type` alias over Python names is its value: `type SessionDep = Annotated[Session,
  Depends(get_db)];`;
- `any` is `typing.Any`, a sized number (`i64`, `f32`) is `int` or `float`;
- a parameter written with no annotation, `def f(a, b: int)`, has none: `check` reads it as `any`,
  and `__annotations__` holds no entry for it, as Python's own `def f(a, b: int)` holds none. On
  every other host it is E0052.

<!-- example: not checked: runs in a cpython space -->
```jac
import inspect;

def twice(x, y: int = 2) -> any {
    return x * y;
}

with entry {
    print(twice("ab"), twice(3, 3));
    print((twice as any).__annotations__);
    print(inspect.signature(twice));
}
```

```text
abab 9
{'y': <class 'int'>, 'return': typing.Any}
(x, y: int = 2) -> Any
```

A Python name used as a type (`EmailStr`, `uuid.UUID`, `Literal["a", "b"]`) is `any` to the
checker, on every host.

`import from __future__ { annotations }` is Python's own future statement in a cpython space:
Python postpones the module's annotations, keeping each as its text, so a raw `__annotations__`
read gives strings and `typing.get_type_hints` gives the objects. It governs the whole module, its
classes too, and `neojac fmt --fix` keeps it there. In a program of any other host it does
nothing, and is W3009.

In such a module every annotation is the text written, and nothing more: `check` reads each as
`any` and resolves no name in it, as Python does not, so an annotation may name what only an
`if TYPE_CHECKING:` import would bind, or nothing at all. The module's program hands Python the
text as written:

<!-- example: not checked: runs in a cpython space -->
```jac
import from __future__ { annotations }

def f(x: int, ys: list[Undefined]) -> list[str] {
    return [str(x)];
}

with entry {
    print((f as any).__annotations__);
    print(f("a", []));
}
```

```text
{'x': 'int', 'ys': 'list[Undefined]', 'return': 'list[str]'}
['a']
```

## Doc strings

A doc string is the program's in a cpython space: a function's, a class's and a module's is its
`__doc__`, as in Python, and neither a lint rule nor `neojac fmt --fix` removes it there.

<!-- example: not checked: runs in a cpython space -->
```jac
import inspect;
import from typing { Annotated }

obj Point {
    has x: int = 0;
}

type Tag = Annotated[str, "a tag"];

"""Where a point is placed."""
def placed(p: Point | None, n: int, tag: Tag = "") -> list[Point] {
    return [];
}

with entry {
    print(inspect.signature(placed));
    print((placed as any).__doc__);
}
```

```text
(p: __main__.Point | None, n: int, tag: Annotated[str, 'a tag'] = '') -> list[__main__.Point]
Where a point is placed.
```

## An import in a code body

An `import` in a function loads its module where it runs, as on every host
([Modules](../language/modules.md#an-import-in-a-code-body)). In a cpython space it may also name
a Python module, which Python loads there; its names are `any` to the checker. What Python cannot
load as it runs, a path or an `include`, is E5173.

<!-- example: not checked: runs in a cpython space -->
```jac
def address(text: str) -> any {
    import ipaddress;
    import from os.path { basename as base }
    return [str(ipaddress.ip_address(text)), base("/a/b.txt")];
}

with entry {
    print(address("127.0.0.1"));
}
```

```text
['127.0.0.1', 'b.txt']
```

## A module's `__file__`

In a cpython space a module's `__file__` is its Jac source's whole path, as natively
([Modules](../language/modules.md#module-variables)): `os.path.basename(__file__)` is `main.jac`,
and a module that finds its files beside itself (`os.path.dirname(__file__)`) finds them there.

## Generators and `raise`

- **A function whose result is `any` and that yields is a generator**, as a Python `def` is: a
  function ported with `-> Generator[Session]` is one.
- **`raise` takes any object**, as Python's does: a Python exception class's instance
  (`raise HTTPException(status_code=404)`) is raised as it is, and an object that is no exception
  raises Python's `TypeError`.

## What is rejected

| Code | Condition |
|---|---|
| E2241 | `@builtins.staticmethod` or `@builtins.classmethod` on a method that is not a `static def` or a `class def` |
| E5173 | An import in a code body of what Python cannot load as it runs |
| E5174 | Outside a cpython space: a class or function decorated by a Python callable |
| E5175 | Outside a cpython space: an `if` among a class's members that is not `comptime` |
| E5176 | Outside a cpython space: a class in a code body |
| E5177 | A class in a code body that reads a name of that body |
| E0077 | A member declared in two arms of a class body's `if` |
