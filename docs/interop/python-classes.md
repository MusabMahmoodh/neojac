---
description: What a cpython space makes as Python does - a class with a Python base, a Python decorator or a run-time if in its body, made where its statement runs; decorators that run as a function is made; annotations Python reads; doc strings; imports in a code body; generators and raise of any object - and what each is refused as elsewhere.
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
- **a decorator that is a Python callable** (`@dataclass`, `@functools.total_ordering`);
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

### In a space of another host

A native or JavaScript program's classes are known as it compiles, so none of these is made there:

| Code | In a native or JavaScript space |
|---|---|
| E5174 | A class or a function decorated by a Python callable |
| E5175 | An `if` among a class's members that is not `comptime` |
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
- `any` is `typing.Any`, a sized number (`i64`, `f32`) is `int` or `float`.

A Python name used as a type (`EmailStr`, `uuid.UUID`, `Literal["a", "b"]`) is `any` to the
checker, on every host.

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
| E0077 | A member declared in two arms of a class body's `if` |
