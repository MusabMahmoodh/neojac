---
description: Generator functions and yield, send and the value of a yield, yield from as a delegation, the Iterator and Iterable types, iterating with next and for, writing an iterable class, and generator expressions.
keywords: yield, yield from, generator, generator function, Iterator, Iterable, Generator, iterator, iterable, iteration protocol, __next__, send, PEP 380, StopIteration value
grammar: yield_expr
---
# Generators

A generator function is a function whose body contains `yield`. Calling it runs none of its body;
it returns a generator, an iterator that runs the body a step at a time, each time an item is asked
for, and pauses at each `yield` to hand out a value.

## Syntax

```ebnf
yield_expr ::= "yield" "from"? expression?
```

`yield` is a statement (`yield x;`), the value of an assignment (`got = yield x;`) or of an f-string's
field (`f"{yield x}"`), or, in parentheses, part of a larger expression (`(yield x) + 1`). It takes
parentheses only there, as Python requires them: `x = (yield v);` is an error (E0161).

## Generator functions

A generator function is declared to return `Iterator[T]`, where `T` is the type of what it yields,
or `Generator[Y, S, R]`, which also names what it is sent (`S`, [Sending values in](#sending-values-in))
and what it returns (`R`). `yield` in a function declared otherwise is an error (E1202), and each
yielded value must be a `T` (E1001).

1. Calling the function creates the generator; the body has not started.
2. Each time an item is asked for (`next(g)`, a pass of a `for` loop), the body runs from where it
   paused to the next `yield`, whose value is the item.
3. When the body ends, or runs `return;`, the generator is exhausted: `next(g)` raises
   `StopIteration`, and a `for` loop over it ends.

A generator can be iterated once. A second loop over an exhausted generator gets no items, and
asking a finished generator again runs nothing: the code after its last `yield` has run once, and
every later `next` only reports that it is finished.

A generator function that is a server's endpoint is a stream: each item is sent to the caller as
the function yields it, and a caller in another space reads them with a loop
([Serving a space](../apps/server.md#streams), [Crossings](../apps/crossings.md#calling-a-stream)).

```jac
def count_to(n: int) -> Iterator[int] {
    print("started");
    i = 1;
    while i <= n {
        yield i;
        i += 1;
    }
    print("finished");
}

with entry {
    g = count_to(2);
    print("made");
    for v in g {
        print("got", v);
    }
    print(list(g));
    it = count_to(3);
    print(next(it), next(it), next(it), next(it, -1));
    try {
        next(it);
    } except StopIteration {
        print("StopIteration");
    }
}
```

```output
made
started
got 1
got 2
finished
[]
started
finished
1 2 3 -1
StopIteration
```

`next(it, default)` gives `default` instead of raising when the iterator is exhausted.

A generator may run forever; the code that iterates it decides how many items to take:

```jac
def naturals -> Iterator[int] {
    n = 0;
    forever {
        yield n;
        n += 1;
    }
}

def until_negative(xs: list[int]) -> Iterator[int] {
    for x in xs {
        if x < 0 {
            return;
        }
        yield x;
    }
}

with entry {
    out: list[int] = [];
    for k in naturals() {
        if k > 4 {
            break;
        }
        out.append(k);
    }
    print(out, list(until_negative([1, 2, -3, 4])));
}
```

```output
[0, 1, 2, 3, 4] [1, 2]
```

## `yield from`

`yield from it;` yields every item of `it` in turn, then goes on. `it` is any iterable: another
generator, a list, a `range`. Where `it` is a generator, the generator that delegates to it is a
pipe: what is sent, thrown or closed reaches `it` (see [below](#yield-from-delegates)).

```jac
def inner -> Iterator[int] {
    yield 1;
    yield 2;
}

def chained -> Iterator[int] {
    yield 0;
    yield from inner();
    yield from [10, 20];
    yield from range(3);
}

with entry {
    print(list(chained()));
}
```

```output
[0, 1, 2, 10, 20, 0, 1, 2]
```

## Sending values in

A `yield` is also an expression: `got = yield total;` pauses the generator, and when it resumes,
`got` is the value it was resumed with.

- **`g.send(v)` resumes `g` with the paused `yield` giving `v`**, and gives the next value `g`
  yields, as `next(g)` does. `next(g)` is `g.send(None)`: the `yield` gives `None`.
- **The first resume must send `None`.** A generator that has not started is paused at no `yield`,
  so `g.send(v)` of any other value raises `TypeError: can't send non-None value to a
  just-started generator`, and leaves `g` unstarted.
- **A send to a generator that has ended raises `StopIteration`**, as `next` does. The
  `StopIteration` that ends a generator declared `-> Generator[Y, S, R]` carries what it returned,
  as its `value`.
- **The type of a `yield` is `S`** in a generator declared `-> Generator[Y, S, R]`: `got: int =
  yield 0;` checks, and a sent value of another type raises `TypeError` where the `yield` gives it
  (`expected int, found str`), as a value of type `any` does wherever a typed place takes it. A
  union is checked so too, on every host: a generator declared `-> Generator[int, int | None, str]`
  sent a `str` raises `TypeError: expected int | None, found str` at its `yield`. In a
  generator declared `-> Iterator[Y]` a `yield` is of type `any`, since nothing declares what it
  may be sent.
- **`send` of an iterator that is no generator** (`iter(xs)`, a `map`) raises `AttributeError`.

```jac
def totals -> Generator[int, int | None, str] {
    total = 0;
    while True {
        got = yield total;
        if got is None {
            return f"ended at {total}";
        }
        total += got;
    }
}

with entry {
    g = totals();
    print(next(g), g.send(3), g.send(4));
    try {
        g.send(None);
    } except StopIteration as e {
        print("returned", e.value);
    }
    h = totals();
    try {
        h.send(5);
    } except TypeError as e {
        print("TypeError:", e);
    }
    print(next(h), h.send(2));
}
```

```output
0 3 7
returned ended at 7
TypeError: can't send non-None value to a just-started generator
0 2
```

### `yield from` delegates

While `r = yield from inner();` runs, the outer generator is a pipe to `inner`, as Python's PEP 380
defines it:

- **What the outer generator is sent goes to `inner`**: `send(v)` resumes `inner`'s `yield` with
  `v`, and `next` with `None`.
- **What is thrown into it is thrown into `inner`**, at the `yield` where `inner` is paused, and
  **`close()` closes `inner`** before the outer generator ends.
- **`r` is what `inner` returned**, of type `any`; `None` where it returned nothing.
- Over an iterator that is no generator, a `send` of a value raises `AttributeError` naming the
  iterable's own class (`'list' object has no attribute 'send'`, `'range'`, `'dict_keys'`), and an
  exception thrown in is raised where the `yield from` stands. A `yield from` over a list, a range
  or a dict's view is the direct loop over it.

This holds on every host: natively, on a JavaScript host and in a cpython space.

```jac
def inner -> Generator[int, int, str] {
    a = yield 1;
    print("inner got", a);
    try {
        b = yield 2;
        print("inner got", b);
    } except ValueError as e {
        print("inner caught", e);
        yield 3;
    }
    return "inner done";
}

def outer -> Generator[int, int, None] {
    r = yield from inner();
    print("outer got", r);
}

with entry {
    o = outer();
    print(next(o), o.send(10));
    print(o.throw(ValueError("bad")));
    try {
        next(o);
    } except StopIteration {
        print("ended");
    }
}
```

```output
inner got 10
1 2
inner caught bad
3
outer got inner done
ended
```

## What a generator offers

A generator is an `Iterator[T]`: what it supports is iteration, by `for`, by `next`, and by
everything that takes an iterable (`list(g)`, `sum(g)`, `sorted(g)`, `", ".join(g)`). It does not
unpack into targets (E1020): `(a, b) = tuple(g);` does (see
[Variables](variables.md#unpacking)).

- A generator is its own iterator: `iter(g) is g`, so two loops or two `iter`s over one generator
  share its position, and an inner `for` over the iterator an outer `for` walks takes items from
  it.
- `yield` used as a value, as in `got = yield x;`, gives what the generator is resumed with:
  `None` for `next`, `v` for `send(v)` ([Sending values in](#sending-values-in)). Inside a larger
  expression, the operands to the left of `(yield x)` are evaluated before the generator pauses
  and kept while it is paused.
- `str(g)` is `<generator object>`, with no name or address.
- An iterator's class is Python's, on every host: `type(g).__name__` is `generator` for every
  generator and generator expression, and an iterator `iter()` gives is named by what it walks:
  `list_iterator`, `tuple_iterator`, `set_iterator`, `bytes_iterator`, `str_ascii_iterator` (or
  `str_iterator` for text that is not all ASCII), `dict_keyiterator`, `range_iterator`; `enumerate`
  and `zip` are their own. `type(iter([1])) is type(iter(["a"]))`, and a message names the class
  (`'list_iterator' object has no attribute 'send'`).
- A paused generator keeps the values of its frame alive, and an iterator keeps the collection it
  walks alive, wherever it is held.
- `return value;` is written in a generator declared `-> Generator[Y, S, R]`, whose `R` is the
  value's type: it ends the generator, and the value is what an `await` of the object whose
  `__await__` the generator is gives (see [Async](async.md)). In a generator that declares no
  result (`-> Iterator[Y]`, or an `R` of `None`) it is refused (E5090); `return;` ends any.
- A generator has `send(v)` ([Sending values in](#sending-values-in)), `close()` and
  `throw(exc)` ([Closing a generator](#closing-a-generator)).
- `Generator[Y, S, R]` is accepted as a return type. A value of it is an `Iterator[Y]`, and an
  `Iterator[Y]` may be given where one is taken; `S` and `R` say what the generator's own body is
  sent and returns.

```jac
def count_to(n: int) -> Iterator[int] {
    i = 1;
    while i <= n {
        yield i;
        i += 1;
    }
}

def neighbours(xs: list[int]) -> list[tuple[int, int]] {
    it = iter(xs);
    pairs: list[tuple[int, int]] = [];
    for a in it {
        for b in it {
            pairs.append((a, b));
            break;
        }
    }
    return pairs;
}

def mid(word: str) -> Iterator[str] {
    print("mid:", word.upper() + "!", (yield "first"), word);
    yield "second";
}

with entry {
    g = count_to(3);
    a = iter(g);
    b = iter(g);
    print(next(a), next(b), next(a), next(b, -1), a is g, str(g));
    print(neighbours([1, 2, 3, 4, 5]));
    m = mid("ab");
    print("got", next(m));
    print("got", next(m));
}
```

```output
1 2 3 -1 True <generator object>
[(1, 2), (3, 4)]
got first
mid: AB! None ab
got second
```

## Closing a generator

A generator paused at a `yield` may hold things it means to give back: an open file, a lock, a
row it marked. Closing it lets it:

- **`g.close()` raises `GeneratorExit` at the `yield` where `g` is paused.** Its `finally` blocks
  and its `with` statements run, and the generator is ended: it gives no more items.
- **A generator must let `GeneratorExit` out, or end.** One that answers it with another item is
  refused: `RuntimeError: generator ignored GeneratorExit`. `GeneratorExit` is a `BaseException`,
  so `except Exception` does not catch it.
- **A generator that has not started runs nothing** when it is closed, and one that has ended
  stays ended. Closing twice is fine.
- **A paused generator that is let go is closed first**: one a `for` loop leaves by `break` or
  `return`, one whose last holder drops it. So what a generator's `finally` owes is paid whether
  it is read to its end or not.
- **`g.throw(exc)` raises any exception at the `yield`** and gives the next item the generator
  yields, raises `StopIteration` if it ends instead, or lets out what the generator lets out.
- **`close()` on an iterator that is no generator** (`iter(xs)`, a `map`) does nothing.

```jac
def rows(log: list[str]) -> Iterator[int] {
    log.append("opened");
    try {
        for i in range(100) {
            yield i;
        }
    } finally {
        log.append("closed");
    }
}

def first_over(limit: int, log: list[str]) -> int {
    for r in rows(log) {
        if r > limit {
            return r;
        }
    }
    return -1;
}

with entry {
    log: list[str] = [];
    g = rows(log);
    print(next(g), next(g));
    g.close();
    print(log, list(g));
    log.clear();
    found = first_over(2, log);
    print(found, log);
}
```

```output
0 1
['opened', 'closed'] []
3 ['opened', 'closed']
```

## Iterator and Iterable

| Type | What it is | Examples |
|---|---|---|
| `Iterator[T]` | A value `next()` takes items of type `T` from, one at a time, once | A generator, `iter(xs)`, `enumerate(xs)`, `zip(a, b)` |
| `Iterable[T]` | A value a `for` loop can take items of type `T` from | A list, tuple, set, dict (its keys), str, bytes, range, iterator |

A parameter typed `Iterable[T]` takes any of them, an object whose class defines `__iter__`, and
an `any`. `iter(x)` gives an iterator over an iterable.

- A collection gives its items each time it is iterated; an iterator only the first time. A
  function that loops twice over an `Iterable[int]` sees `[1, 2]` twice from a list and once from
  a generator.
- A `str` iterates by code point (`"héllo"` gives `'é'` as one item); `bytes` and `bytearray`
  iterate as `int`s.
- An `any` holding an iterator may be given to an `Iterator[int]`; each item is checked as it is
  read, so a `str` item raises `TypeError: expected int, found str` at the `next` that reads it,
  not at the assignment. An `Iterable[int]` holding the wrong items fails the same way.

```jac
def total(src: Iterable[int]) -> int {
    t = 0;
    for v in src {
        t += v;
    }
    return t;
}

with entry {
    print(total([1, 2]), total(range(4)), total({5, 6}), total(x * 2 for x in [1, 2]));
    it = iter("ab");
    print(next(it), next(it), next(it, "done"));
}
```

```output
3 6 11 6
a b done
```

### Making a class iterable

A class is iterable when it defines `__iter__`. The simplest `__iter__` is a generator method. A
class that is its own iterator defines `__iter__` returning `self` and `__next__`, which returns
the next item or raises `StopIteration()`.

```jac
obj Countdown {
    has n: int;

    def __iter__ -> Iterator[int] {
        k = self.n;
        while k > 0 {
            yield k;
            k -= 1;
        }
    }
}

obj Falling {
    has n: int;

    def __iter__ -> Falling {
        return self;
    }

    def __next__ -> int {
        if self.n == 0 {
            raise StopIteration();
        }
        self.n -= 1;
        return self.n;
    }
}

with entry {
    c = Countdown(n=3);
    print(list(c), [x * 10 for x in c], sum(c));
    print(list(Falling(n=3)));
}
```

```output
[3, 2, 1] [30, 20, 10] 6
[2, 1, 0]
```

## Generator expressions

`(e for x in xs if cond)` is a generator written as an expression: lazy, iterable once, and needing
no parentheses of its own as a call's only argument (`sum(x * x for x in xs)`). It is described with
the comprehensions in [Collections](collections.md#generator-expressions).

Asynchronous generators, declared `async def ... -> AsyncIterator[T]`, are in [Async](async.md).

## What is rejected

| Code | Condition |
|---|---|
| E1202 | `yield` in a function not declared to return `Iterator[T]`, or outside a function |
| E1001 | A yielded value of the wrong type |
| E1004 | A generator declared to return something else, which then lacks a `return` |
| E5090 | `return value;` in a generator that declares no result |

```jac
# expect: E1202, E1001
def evens(n: int) -> list[int] {
    yield n;
    return [];
}

def words -> Iterator[str] {
    yield 1;
}
```

## Differences from Python

- A generator function declares its type, `-> Iterator[T]`, and every `yield` is checked against
  it.
- A generator returns a value only where it is declared `-> Generator[Y, S, R]`, and the value a
  `yield` gives is checked against `S` there.
- `str(g)` names neither the function nor an address.
- A `send` through `yield from [1, 2, 3]` names the list in its `AttributeError` (`'list' object
  has no attribute 'send'`), where CPython, which folds the literal into a tuple, names `'tuple'`.
