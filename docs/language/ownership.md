---
description: Ownership states on parameters, fields and bindings (own, lin, imm, & and &mut), moves, borrows and what the borrow checker refuses, take and swap, and owned fields and containers.
keywords: ownership, own, lin, imm, mut, move, moved, owner, linear
grammar: ownership_prefix, ref
---
# Ownership

An ownership state says who is responsible for a value on the heap. A
binding marked `own` is the value's one owner, and assigning it elsewhere
moves the value; `&` and `&mut` lend a value without giving it up; `lin` is
an owner that must be passed on; `imm` is a value that never changes. The
checker proves the rules when the program compiles, and the compiler drops
an owned value at its owner's last use.

A binding with no state is managed: the program holds a counted reference,
as Python does (see [Memory](memory.md)). States are optional under the
`managed` and `rc` memory profiles, where a program uses them where they
help, and required under `nogc` (see
[The nogc contract](ownership-contract.md)).

```jac
obj Buffer {
    has n: int = 0;
}

def consume(b: own Buffer) -> int {
    return b.n;
}

def peek(b: &Buffer) -> int {
    return b.n;
}

def bump(b: &mut Buffer) {
    b.n += 1;
}

with entry {
    a: own Buffer = Buffer(n=1);
    b = a;
    a = Buffer(n=2);
    print("move and revive:", a.n, b.n);
    v1 = &a;
    v2 = &a;
    print("shared borrows:", peek(v1) + peek(v2));
    bump(&mut a);
    bump(&mut a);
    print("after two bumps:", a.n);
    print("consumed:", consume(a));
}
```

```output
move and revive: 2 1
shared borrows: 4
after two bumps: 4
consumed: 4
```

## Syntax

A state is written before a type, on a parameter, a field, a local or a
global:

```ebnf
ownership_prefix ::= ("own" | "lin" | "imm" | "&" "mut"?)?
```

In an expression, `&x` and `&mut x` lend a value, `imm x` freezes one, and
`own (x)` makes an owner of a value leaving a region (see
[Regions](memory-regions.md)):

```ebnf
ref ::=
    dyn_type
    | ("own" | "imm") await_expr
    | "&" ("mut" await_expr | await_expr)
    | await_expr
```

A prefix `&` is a borrow however it is spaced: `&x`, `& x` and `&(x)` are
one borrow. A binary `&` is the bitwise and.

## The states

| State | Written | Meaning |
|---|---|---|
| owned | `own T` | The binding is the value's one owner. Assigning it to another binding, or passing it to an `own` parameter, moves the value: the first binding holds nothing until it is assigned again. The value is dropped at the owner's last use. |
| linear | `lin T` | An owner that must be consumed on every path: returned as `own`, or given to an `own` or `lin` parameter (E1305 otherwise). |
| immutable | `imm T` | A value nothing changes, deeply: a field written through it is E1309. `imm a` freezes an owner into one; a value something else may still write, such as a parameter its caller may alias, cannot be frozen (E1311). |
| shared borrow | `&T`, `&x` | Reads the value while its owner keeps it. Any number may be live at once. |
| mutable borrow | `&mut T`, `&mut x` | Reads and writes the value while its owner keeps it. Exclusive: no other borrow of it is live at the same time. |
| managed | no prefix | A counted reference, as in Python. |

A struct is a value its place holds, not a reference, so `own`, `lin` and
`imm` mark no binding of one (E1507); see [Structs](structs.md).

## Moves

- **Assigning an owner moves it**: after `b = a`, reading `a` is E1301
  until `a` is assigned again, which revives it.
- **Passing an owner to an `own` parameter consumes it.** A function that
  only reads takes a borrow (`&T`) instead.
- **A builtin that only reads borrows**: `hay.find("x")`, a slice,
  `hay.startswith(...)` and `len` leave an `own str` usable.
- **A function value may consume its argument**: `Callable[[own Buffer],
  int]`.
- **A method may consume its receiver**: `def into_total(self: own
  Counter)`. Its other methods are called through a borrow.
- **A walker owner is consumed by `spawn`**, which gives it back:
  `res = w spawn s`.
- **An owner given to a managed place is handed to the managed runtime**: passed to a parameter
  with no state, appended to a managed container, stored in a managed field or local. From there
  it is counted, as any managed value is, and it is dropped, its `__del__` run, when its last
  reference goes.
- **A value whose drop runs code is not taken back out of a managed place** into an `own` local
  or an `own` or `lin` parameter (E1637): the owner would end it while the place still refers to
  it ([below](#values-whose-drop-runs-code-dropped-where-their-scope-ends)).

```jac
obj Guard {
    has name: str = "";

    def __del__ {
        print("  release", self.name);
    }
}

def look(g: Guard) -> str {
    return g.name;
}

def main {
    held: list[Guard] = [];
    g: own Guard = Guard(name="a");
    held.append(g);
    print("handed");
    held.clear();
    print("cleared");
    h: own Guard = Guard(name="b");
    print(look(h));
    print("looked");
}

with entry {
    main();
}
```

```output
handed
  release a
cleared
b
  release b
looked
```

```jac
obj Counter {
    has n: int = 0;

    def inc {
        self.n += 1;
    }

    def into_total(self: own Counter) -> int {
        return self.n * 100;
    }
}

def apply(f: Callable[[own str], int], s: own str) -> int {
    return f(s);
}

def size(s: own str) -> int {
    return len(s);
}

with entry {
    hay: own str = "ownership";
    print(hay.find("ship"), hay[0:3], hay.startswith("own"), hay);
    print(apply(size, hay));
    c: own Counter = Counter();
    c.inc();
    c.inc();
    print(c.into_total());
}
```

```output
5 own True ownership
9
200
```

## Borrows and owned places

`&x` and `&mut x` lend a value; a field or a container may own what it
holds, emptied with `take()` and exchanged with `swap()`. Both are on
[Borrows and owned places](ownership-borrows.md) (`neojac docs borrow`).

## lin and imm

```jac
obj Ticket {
    has id: int = 0;
}

obj Buffer {
    has n: int = 0;
}

def redeem(t: own Ticket) -> int {
    return t.id;
}

def issue(id: int) -> own Ticket {
    t: lin Ticket = Ticket(id=id);
    return t;
}

def settle(t: lin Ticket) -> int {
    return redeem(t) + 1;
}

with entry {
    t: lin Ticket = issue(7);
    print(settle(t));
    frozen: imm Buffer = Buffer(n=8);
    a: own Buffer = Buffer(n=9);
    d = imm a;
    print(frozen.n, d.n);
}
```

```output
8
8 9
```

An `imm` value may be read from a `flow for` body and sent to a `flow` task
(see `neojac docs "flow for"`).

## Drops

An owned value is dropped right after its owner's last use, not at the end
of its scope (but for a scoped class's, below), and an owner never read again is dropped as soon as it is
made. (A name bound in module code, a `with entry` block, is a module
global, which lives as long as the program.) A borrow of it keeps it alive while the borrow lives, and so does a pointer a C++ class's member gives into it where C++ declares it so ([A pointer into an object](../interop/c-modules.md#a-pointer-into-an-object)). An owner is
dropped too when an exception leaves its scope, before a handler outside
it runs. Its `__del__` runs when it is dropped (see [Memory](memory.md)).

```jac
obj Guard {
    has name: str = "";

    def __del__ {
        print("  release", self.name);
    }
}

def parse_port(s: &str) -> int {
    if len(s) == 0 {
        raise ValueError("empty port");
    }
    return int(s);
}

def load(s: &str) -> int {
    _guard: own Guard = Guard(name="[" + s + "]");
    return parse_port(s) + 1;
}

def load_or_default(s: &str) -> int {
    try {
        return load(s);
    } except ValueError {
        return 8080;
    }
}

with entry {
    good: own str = "80";
    print(load_or_default(&good));
    bad: own str = "";
    print(load_or_default(&bad));
}
```

```output
  release [80]
81
  release []
8080
```

### Values whose drop runs code: dropped where their scope ends

A class is **scoped** when dropping one does something a program can see: a Rust type whose drop
rustc reports as significant (a guard, a lock, a collection that frees its items), a C++ class
whose destructor is not trivial (`std::string`, a class that frees what it holds;
[C modules](../interop/c-modules.md#c-values-whose-destructor-runs-code)), a Jac class deriving
one, and a class that owns (`has x: own T`) a field of a scoped class. An owner of a scoped class
is dropped where its scope ends, as Rust and C++ drop it, not at its last use:

- at the end of the smallest block that holds all its uses, and on each `break` and `continue`
  that leaves that block, owners of one block in the reverse order they were bound;
- on a `return` and as an exception passes, as every owner is;
- not at all once it is moved: `b = a`, an `own` parameter and a Rust parameter taken by value
  empty it, as Rust's drop flags do.

A local and a field are each one of two places:

- **A local declared `own`** (`seen: own HashSet[u32] = ...`) is the value's one owner, which
  drops it where its scope ends.
- **A field declared `own`** (`has s: own HashSet[u32];`) owns its value: the object holding it
  drops it with itself, and makes its own class scoped.
- **A local, a parameter or a field with no ownership annotation is a managed place**, as a
  managed container's item is: it shares its value, which is counted, and is dropped when its
  last reference goes, wherever that is. An owner stored there is handed over. A local of a
  scoped class need not be `own`: `s = HashSet[u32].new()` shares the set with a field it is
  stored in, and the set outlives the local.

An `own` binding takes a value of a scoped class only from where it is made (the call that
makes it) or from another owner. One taken from a managed place is E1637: the
place still refers to the value, which the owner would end at its scope's end. A call is such a
place where the function's result may be a managed place's value: where a `return` gives a field,
a global, a parameter with no ownership annotation, `self`, or a local that took one of those
(`def kept(k: Seen) -> HashSet[u32] { return k.s; }`). A constructor, a function declared
`-> own T`, and one whose `return`s give only what it made give a value an owner may take.

`del o.f` ends a field's value where it is written: its drop runs at once where the field held the
only reference, and reading the field before it is assigned again raises `AttributeError`.

```jac
obj Guard {
    has name: str = "";

    def __del__ {
        print("  release", self.name);
    }
}

obj Gate {
    has g: Guard;
}

with entry {
    k = Gate(g=Guard(name="first"));
    del k.g;
    print("after del");
    try {
        print(k.g.name);
    } except AttributeError {
        print("AttributeError");
    }
    k.g = Guard(name="second");
    print(k.g.name);
}
```

```output
  release first
after del
AttributeError
second
```

```jac
import from std.collections { HashSet }

obj Seen {
    has s: HashSet[u32];
}

obj Kept {
    has s: own HashSet[u32];
}

def shared -> Seen {
    s = HashSet[u32].new();
    s.insert(u32(4));
    k = Seen(s=s);
    s.insert(u32(5));
    print(k.s.len(), s.len());
    return k;
}

def distinct(xs: list[int]) -> int {
    seen: own HashSet[u32] = HashSet[u32].new();
    for x in xs {
        seen.insert(u32(x));
    }
    return int(seen.len());
}

with entry {
    print(shared().s.len());
    print(distinct([3, 1, 3, 2, 1]));
    k = Kept(s=HashSet[u32].new());
    print(k.s.is_empty());
}
```

```output
2 2
2
3
True
```

`shared`'s local and the field share one set, which outlives the local; `distinct`'s owner drops
its set where the function's scope ends.

See [Rust modules](../interop/rust-modules.md) for the Rust types a program uses.

## What is rejected

```jac
# expect: E1637
import from std.collections { HashSet }

def taken -> bool {
    s = HashSet[u32].new();
    t: own HashSet[u32] = s;
    return t.is_empty();
}
```

```jac
# expect: E1301, E1305, E1309, E1311
obj Buffer {
    has n: int = 0;
}

def finish(b: own Buffer) {
    print(b.n);
}

def use_after_move {
    a: own Buffer = Buffer();
    b = a;
    print(a.n, b.n);
}

def lin_dropped(flag: bool) {
    f: lin Buffer = Buffer();
    if flag {
        finish(f);
    }
}

def imm_written {
    v: imm Buffer = Buffer();
    v.n = 5;
}

def frozen_param(b: Buffer) {
    d = imm b;
    print(d.n);
}
```

| Code | Meaning |
|---|---|
| E1301 | An owner is read after its value was moved. |
| E1305 | A `lin` binding is not consumed on every path. |
| E1308 | A live borrow is sent across a `flow` boundary. |
| E1309 | A field is written through an `imm` binding. |
| E1311 | `imm` of a value that may be aliased, such as a parameter. |
| E1507 | A struct binding is marked `own`, `lin` or `imm`. |
| E1637 | A value of a scoped class is taken from a managed place into an owner. |

The errors of borrows and owned places (E1302 to E1304, E1306, E1315 to
E1323, E1328, E1330) are on
[Borrows and owned places](ownership-borrows.md).

## On other hosts

The checks run for every host. A `cpython`, `node`, `browser` or `hermes`
space then erases the states: its host frees an owned value when its last
reference goes, as its garbage collector does, not right after its owner's
last use, so `__del__` may run later there.

## Differences from Python and the reference design

- Python has no ownership: every binding is a counted reference, which is
  what an unmarked binding is here.
- A prefix `&` is always a borrow, however it is spaced (`& x`, `&(x)`).
