---
description: What neojac port makes of each Rust construct - the Jac it becomes, and what it refuses.
keywords: port rust, porting Rust, Rust to Jac
---
# Porting Rust

`neojac port` translates a Rust crate into a Jac module that behaves as the crate does, or
refuses it ([port](../toolchain/port.md)). This page is the mapping: each Rust construct port
translates and the Jac it becomes. It is printed from the table the translation itself reads
(`neojac port --mapping rust`).

rustc reads the crate, as it does to compile it, once for each target neojac builds Rust for,
and port translates the typed tree rustc checks: macros expanded, every expression with its
type. Where the readings agree the Jac is written once; where they differ it is written as
[C's](port-c.md) is.

A crate's every file under `src/` is ported, each to a Jac file of its own, and the crate is
read with the features the project builds it with: its extension module's (`[extensions]`),
else its defaults.

| Rust | Jac |
|---|---|
| `i32`, `u8`, `i64`, `usize`, `f64`, `f32`, `bool` | `i32`, `u8`, `i64`, `u64` (by the target's width), `float`, `f32`, `bool` |
| `fn f(a: i32, b: f64) -> i32 { ... a }` | `def f(a: i32, b: float) -> i32 { ... return a; }`: a body's last expression is what it returns |
| `struct P { x: f64, n: i32 }`, `P { x: 1.5, n: 2 }`, `p.x` | `struct P { has x: float = 0.0, n: i32 = 0; }`, `P(x=1.5, n=2)`, `p.x` |
| `impl P { fn area(&self) -> f64 { } fn new(x: f64) -> P { } }`, `p.area()`, `P::new(1.0)` | `def area -> float;` and `static def new(x: float) -> P;` in the struct, each with its `impl P.area -> float { }`; `p.area()`, `P.new(1.0)` |
| `#[derive(Clone, Copy)]` | Nothing: a Jac struct is copied where it is assigned or passed |
| `const N: i32 = 5;`, `static LIMIT: i32 = 9;` | `comptime N: i32 = 5;`, `glob LIMIT: i32 = 9;` |
| `enum Color { Red, Green = 4 }` (no variant holds fields), `Color::Red` | `enum Color { Red = 0, Green = 4, }`, `Color.Red` |
| `type Rank = u32;` | `type Rank = u32;` |
| `use std::collections::HashSet;` | Nothing: rustc has resolved every path a `use` names |
| `match n { 0 => a, 1 \| 2 => b, k if k > 9 => c, _ => d }` over integers, bools and enums of the crate, as a statement or as a `let`'s value | `match n { case 0: ... case 1 \| 2: ... case k if k > 9: ... case _: ... }` |
| `#[cfg(test)] mod tests { #[test] fn adds() { assert!(add(1, 2) == 3); } }` | `test "adds" { if not (add(1, 2) == 3) { raise AssertionError("assertion failed: add(1, 2) == 3"); } }`: the crate is read once more as a test; a helper function of the module is a function of the file |
| `let x = 1;`, `let mut x: i64 = 1;`, `let x = x + 1;` in the same block; `let (a, mut b) = t;` | `x: i32 = 1;`, `x: i64 = 1;`, `x: i32 = x + 1;`; `unpacked: tuple[u32, u64] = t; a: u32 = unpacked[0]; b: u64 = unpacked[1];` |
| `if c { } else if d { } else { }`; `let x = if c { a } else { b };` | `if c { } elif d { } else { }`; `x: T = a if c else b;` |
| `while c { }`, `loop { }`, `break`, `continue` | `while c { }`, `while True { }`, `break;`, `continue;` |
| `for i in a..b { }`, `for _ in 0..n { }`; `for x in v`, `v.iter()`, `v[a..b].iter()` and their `enumerate()`, over a `Vec` | `for i = a while i < b with i += 1 { }`; a walk by index, `for at = u64(0) while at < u64(v.len()) with at += 1 { x = v[at]; }`, a range checked first by `rust.within` as Rust checks it |
| `return v;`, `x = v;`, `x += v;` and the other compound assignments | The same |
| `a + b`, `a - b`, `a * b` of integers and of floats | `a + b`, `a - b`, `a * b`: an overflow is an error in Rust, and Jac raises OverflowError |
| `a / b`, `a % b` of signed integers | `(a // b + 1) if (a % b != 0 and (a < 0) != (b < 0)) else (a // b)`, and the like for `%`: Rust rounds toward zero and Jac toward negative infinity |
| `a / b` of floats | `a / b` where `b` is a literal other than 0; else `(a / b) if b != 0.0 else a * math.copysign(float("inf"), b)` |
| `a << k`, `a >> k`, `a & b`, `a \\| b`, `a ^ b`, `!a` of integers | `wrapping_shl(a, k)`, `a >> k`, `a & b`, `a \\| b`, `a ^ b`, `~a` |
| `a < b`, `<=`, `>`, `>=`, `==`, `!=`, `a && b`, `a \\|\\| b`, `!a`, `-a` | The same comparisons, `a and b`, `a or b`, `not a`, `-a` |
| `x as i64`, `x as f64` (a type that holds every value); `x as u8` | `i64(x)`, `float(x)`; `u8.wrap(x)`: it keeps the low bits |
| `f(a, b)` | `f(a, b)` |
| `\|x\| x + 1`, given to another crate's method that calls it before it returns | `lambda (x: i32) -> i32 { return x + 1; }` |
| `fn f(t: &[u32])`, `t[i]`, `t.len()`, `for &x in t`; `f(&v)`, `&v[a..b]`, `&v[a..]`, `&t[..b]` of a `Vec` or a slice of numbers; `&v[i]` of a `Vec` of another crate's values, `v[i].len()`; `v[i].1 = x` of a `Vec` of tuples | `def f(t: Slice[u32])`, `t[i]`, `t.len()`, a walk by index; `f(v.as_slice())`, `v.as_slice().sub(a, b)`, `.sub_from(a)`, `t.sub(u64(0), b)`: `rust.Slice[T]`, the native `&[T]`, which borrows what it is a slice of and panics where Rust panics; `v[i]`, the item the `Vec` lends, which borrows it; `v[i] = (v[i][0], x)`, `x` held first where it has an effect |
| `5`, `5u8`, `1.5`, `true` | `5` where its type is given by what takes it, else `i32(5)`, `u8(5)`; `1.5`, `True` |
| `b"ab"` given as a `&[u8]` | `b"ab"` |
| `Vec<u32>`, `HashMap<Vec<u8>, u32, FxBuildHasher>`, `v.push(x)`, `Vec::with_capacity(4)`, `v[i]`, `v[i] = x`: another crate's types, the standard library's among them | `Vec[u32]`, `HashMap[Vec[u8], u32, FxBuildHasher]`, each imported by its Rust path (`import from std.vec { Vec }`), `v.push(x)`, `Vec[u32].with_capacity(4)`, `v[i]`, `v[i] = x`: Rust's own items, called natively ([Rust modules](rust-modules.md)) |
| A value whose drop is significant (`HashSet`, `Regex`): a `let`, a by-value parameter, a struct's field | An `own` binding, dropped where its scope ends as Rust drops it; a struct of the crate holding one is an `obj` with an `own` field |
| `&str`, a string literal, `s.len()`; `&[u8]`, `b"ab"`, `&piece[a..b]`, `&text[..i]` | `str` (its `len` the UTF-8 length); `bytes`; a range through `rust`'s `slice_bytes`, `slice_str` and their `_from` forms, which panic where Rust panics |
| `m.get(k)` and `m[k]` of a map by its key's borrowed form, `if let Some(&r) = m.get(k)`, `*m.get(k).unwrap_or(&7)`, `.copied()` | The native call by the borrowed form; an `Option<&N>` of a number is the `Option[N]` its `copied` gives: `is_some()`/`unwrap()`, `m.get(k).unwrap_or(7)` |
| `if let Some(x) = e { } else { }`, `while let Some(x) = e { }` over another crate's `Option`, `if let Ok(x) = r { }`; `match e { Some(x) => a, None => b }`, `match r { Ok(x) => a, Err(e) => b }`, `Ok((x, _))` | `if e.is_some() { x = e.unwrap(); ... } else { }`, and the `while` likewise, `e` evaluated once; a `Result`'s `if r.is_ok()`, `x = r.ok().unwrap()`, `e = r.err().unwrap()`; a tuple pattern taken apart from its value, item by item |
| `let x = f()?;`, `Ok(a + g()?)` of another crate's `Result` (the function's own error) or `Option` | `tried: Result[T, E] = f(); if tried.is_err() { return Result[U, E].Err(tried.err().unwrap()); } x: T = tried.ok().unwrap();`: the test and the return before the statement, refused where that would evaluate something before what precedes it, or where the operand is evaluated on some paths only |
| A value of another crate that borrows (`m.get(k)`'s `Option<&Vec<u8>>`, `std::str::from_utf8(b)`'s `Result<&str, Utf8Error>`) in a local | A local of its type (`text: Result[&str, Utf8Error] = from_utf8(b);`), which Jac holds to borrowing what Rust says it borrows; refused in a field, a parameter or a result |
| `HashSet<&str>`, `Vec<&[u8]>` only built and read: `insert(s)`, `contains(k)`, `len()`, given by `&` to a function of the crate | `HashSet[String]`, `Vec[Vec[u8]]`, each element made a `String` or a `Vec[u8]` before the statement that inserts it: nothing done with the set can tell the two apart |
| `vec![a, b]`, `let x;`, a `#[should_panic(expected = "m")]` test | `made: Vec[T] = Vec[T].with_capacity(2); made.push(a); made.push(b);` before the statement; `x: T;`; a test that passes when a `RustPanic` or `AssertionError` holding `m` is raised |
| `for m in re.find_iter(text) { }` over another crate's iterator; `re.find_from_pos(text, at)`, generic over its input; `v.extend(&w)`, `v.extend(f())` of a `Vec` of numbers; `text.as_bytes()` | `steps: Matches[str] = re.find_iter[str](text); while True { got = steps.next(); if got.is_none() { break; } m = got.unwrap(); }`, the native `Iterator::next`; `re.find_from_pos[str](text, at)`, the instance named at the call; the loop that pushes each of `w`'s items; `text.encode()` |
| An iterator chain: `v.iter().map(\|x\| *x * 2).collect::<Vec<u32>>()`, `v.windows(2).map(\|w\| w[1] - w[0])`, `(0..n).map(\|_\| 7)`, `m.keys().cloned()`, `v.iter().rev()`, `enumerate()`, `all`, `any`, `HashMap::from_iter([(1, 2)])`, `o.map_or(d, \|x\| x + 1)`, `o.map(f).unwrap_or(d)`, `o.ok_or(e)` | The loop it runs, before its statement: `made: Vec[u32] = Vec[u32].new(); for at = u64(0) while at < u64(v.len()) with at += 1 { x: u32 = v[at]; mapped: u32; mapped = x * 2; made.push(mapped); }`; a window read by its items' places (`v[at + 1] - v[at + 0]`); another crate's iterator stepped by `next()`, whose items borrow what the iterator borrows (a `HashMap`'s keys and values; a tuple of references to numbers copied; a `HashMap<Vec<u8>, u32>`'s item, a `tuple[&Vec[u8], u32]` with the key lent); an `Option` tested once; a closure's body run in the loop, and refused where it assigns what it captured or returns |
| `&v`, `v.as_slice()`, `&v[a..b]`, `&v[a..]` of a `Vec<u8>` as a `&[u8]`; `s.as_bytes()` of another crate's value | The bytes read out of it: `bytes(v.as_slice())`, `bytes(v.as_slice().sub(a, b))`, `bytes(v.as_slice().sub_from(a))` (the range panics as Rust's does, and only it is copied); `bytes(s.as_bytes())` |
| A slice's method on a `Vec`: `v.sort()`, `v.starts_with(&w)`, `v.contains(&x)`, `b"ab".to_vec()`, `[a, b].concat()`, `[b' ', b'\n'].contains(&b)`, `v.partition_point(\|x\| x.as_slice() < w.as_slice())`, `a < b` of two `&[u8]` | The `Vec`'s own method of the import (`v.sort()`, `v.starts_with(bytes(w.as_slice()))`); the `Vec<u8>` made and extended; `(b in [32, 10])`; the search Rust's `binary_search_by` runs, its probes in Rust's order with the closure's body at each; `bytes` compared |
| `(a, b)`, `t.0`, `t.1 += 1`, `Vec<(usize, u32)>` | `(a, b)`, `t[0]`, `t = (t[0], t[1] + 1)`, `Vec[tuple[u64, u32]]` |
| `impl Ord for Merge { fn cmp(&self, o: &Self) -> Ordering { } }`, `#[derive(PartialEq, Eq)]`, `BinaryHeap<Merge>` | `struct Merge(Ord, PartialOrd, Eq, PartialEq) { def cmp(other: &Merge) -> Ordering { } }`: the struct conforms to Rust's traits, which Rust's generic code calls |
| `assert!(c)` outside a test | `if not c { raise RustPanic("assertion failed: c"); }`, `RustPanic` imported from `rust` |
| `impl Display for E { fn fmt(&self, f: &mut Formatter) -> fmt::Result { write!(f, "e {} {{x}}", self.code) } }`, `e.to_string()` | `impl E.__str__ -> str { return "e " + str(self.code) + " {x}"; }`, the String made of `str(e)` before the statement; `{}` of an integer, a `str`, a `String` or such a type only, and any other `fmt` body refused |
| `Result<(u32, u32), Fault>`, `Option<Shelf>` of what is Jac's after the port (the crate's own types, tuples): `Ok(x)`, `Err(e)`, `?`, `match`, `unwrap()` | `Result[tuple[u32, u32], Fault]` of the `rust` module, Jac's own, with `Ok`, `Err` and std's `is_ok`, `is_err`, `ok`, `err`, `unwrap`, `unwrap_err`, `expect`, `unwrap_or`; `Shelf \| None`, and an `Option` of what can itself be None refused |
| A file of the crate (`pub mod extra;` in `src/extra.rs`) | Its own Jac file, `src/extra.jac`; a file the crate does not compile with the features the project builds it with (its extension module's, else its defaults) is refused |
| PyO3: `#[pyclass(frozen)] struct CoreBPE` (in `lib.rs`) with `#[pymethods] impl CoreBPE` (in `py.rs`), the `#[pymodule]` that adds it | `obj CoreBPE { static has __module__: str = "builtins"; has:priv core: CoreBPE_2; ... }` in the module the extension is built from (`[extensions."m/_x"] jac = "src/py.jac"`), holding the crate's value; `:priv`, so Python sees only its methods (`dir`, AttributeError); every class the `#[pymodule]` does not add is `obj:priv` |
| PyO3: `#[new] fn py_new(..) -> PyResult<Self>`, `#[pyo3(name = "encode")] fn py_encode(&self, py: Python, ..)`, `self.field` | `def init(..)`, its tail setting `self.core`; `def encode(..)`, Python's name, with no `py` parameter; `self.core.field`; any other helper attribute, a static method or `self` by value refused |
| PyO3: `&str`, `&[u8]`, `u32`, `Vec<u32>`, `(Vec<u32>, ..)`, `HashMap<Vec<u8>, u32>`, `HashMap<String, u32, FxBuildHasher>`, `HashSet<PyBackedStr>`, `Py<PyBytes>` as a parameter or a result | `str`, `bytes`, `u32`, `list[u32]`, `tuple[..]`, `dict[bytes, u32]` made into the crate's `HashMap` before the body (a map with a hasher of its own made by its `default()`, as PyO3 makes it by the hasher's `Default`; a `String` key made from the `str`), `set[str]` made into a `HashSet[String]` (and its `iter().map(\|s\| s.as_ref()).collect::<HashSet<&str>>()` that set), `bytes`; `PyBytes::new(py, &v).into()` of a `Vec<u8>` the Jac `bytes` of its items. A value of the wrong type raises TypeError with Jac's message, where PyO3's message is its own; a `Vec<u8>` key or item is taken from `bytes`, where PyO3 also takes any sequence of ints |
| PyO3: `PyResult<T>`, `Err(PyErr::new::<PyKeyError, _>(piece.to_owned()))`, `PyValueError::new_err(m)`, `r.map_err(\|e\| PyErr::new::<PyValueError, _>(e.to_string()))` | The method's `T`; `raise KeyError(piece)`, `raise ValueError(m)`, with the arguments Python's has (`bytes` for a `Vec<u8>`); `tried = r; if tried.is_err() { raise ValueError(str(tried.unwrap_err())); }` |
| PyO3: `py.detach(\|\| body)`, `let x = py.detach(\|\| { stmts; value })` | `body`, in place (a block given to a `let` run before the `let` takes its value): a Jac extension never holds the GIL while Jac runs. The extension's Jac runs under its one lock, so two Python threads in its methods take turns, where PyO3's run at once; each gets what it alone would get |
| PyO3: a class's default `repr`, a `#[pyclass]` with no `module =` | Jac's default repr, `<CoreBPE object at ..>`, where PyO3's is `<builtins.CoreBPE object at ..>`; `__module__` `builtins`, as PyO3's |

## What is refused

Anything not in the table is refused with E4001, and nothing is written for the file: among
them enums whose variants hold fields and their patterns, generics, another crate's methods
generic over a closure or a trait object but in the chains the table names (`filter`,
`sum`, `for_each`, `fold`), a `for` over an iterator that borrows its source mutably
(`drain()`), a slice of other than numbers and bytes, a `?` that converts the error, a `Display` impl of more than one `write!`, a value
that borrows kept past a local, `char`, raw pointers and `unsafe`, and a call of another
crate whose types Jac does not hold or that the import of Rust leaves out (its result
borrows from other than its receiver and its str or bytes arguments, or it may keep a
borrow of what it is given).
So is a construct in the table whose Jac would mean something else (E4005):

- **A float converted to an integer.** Rust stops at the type's ends and Jac raises.
- **A division whose operands are more than names.** Port tests the operands, and would
  evaluate them twice.
- **A method named `init` or `postinit`**, which is a Jac object's constructor.
