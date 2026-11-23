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
| `let x = 1;`, `let mut x: i64 = 1;`, `let x = x + 1;` in the same block | `x: i32 = 1;`, `x: i64 = 1;`, `x: i32 = x + 1;` |
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
| `5`, `5u8`, `1.5`, `true` | `5` where its type is given by what takes it, else `i32(5)`, `u8(5)`; `1.5`, `True` |
| `b"ab"` given as a `&[u8]` | `b"ab"` |
| `Vec<u32>`, `HashMap<Vec<u8>, u32, FxBuildHasher>`, `v.push(x)`, `Vec::with_capacity(4)`, `v[i]`, `v[i] = x`: another crate's types, the standard library's among them | `Vec[u32]`, `HashMap[Vec[u8], u32, FxBuildHasher]`, each imported by its Rust path (`import from std.vec { Vec }`), `v.push(x)`, `Vec[u32].with_capacity(4)`, `v[i]`, `v[i] = x`: Rust's own items, called natively ([Rust modules](rust-modules.md)) |
| A value whose drop is significant (`HashSet`, `Regex`): a `let`, a by-value parameter, a struct's field | An `own` binding, dropped where its scope ends as Rust drops it; a struct of the crate holding one is an `obj` with an `own` field |
| `&str`, a string literal, `s.len()`; `&[u8]`, `b"ab"`, `&piece[a..b]`, `&text[..i]` | `str` (its `len` the UTF-8 length); `bytes`; a range through `rust`'s `slice_bytes`, `slice_str` and their `_from` forms, which panic where Rust panics |
| `m.get(k)` and `m[k]` of a map by its key's borrowed form, `if let Some(&r) = m.get(k)`, `*m.get(k).unwrap_or(&7)`, `.copied()` | The native call by the borrowed form; an `Option<&N>` of a number is the `Option[N]` its `copied` gives: `is_some()`/`unwrap()`, `m.get(k).unwrap_or(7)` |
| `if let Some(x) = e { } else { }`, `while let Some(x) = e { }` over another crate's `Option`; `match e { Some(x) => a, None => b }`, `match r { Ok(x) => a, Err(e) => b }` | `if e.is_some() { x = e.unwrap(); ... } else { }`, and the `while` likewise, `e` evaluated once; a `Result`'s `x = r.ok().unwrap()`, `e = r.err().unwrap()` |
| `let x = f()?;`, `Ok(a + g()?)` of another crate's `Result` (the function's own error) or `Option` | `tried: Result[T, E] = f(); if tried.is_err() { return Result[U, E].Err(tried.err().unwrap()); } x: T = tried.ok().unwrap();`: the test and the return before the statement, refused where that would evaluate something before what precedes it, or where the operand is evaluated on some paths only |
| A value of another crate that borrows (`m.get(k)`'s `Option<&Vec<u8>>`, `std::str::from_utf8(b)`'s `Result<&str, Utf8Error>`) in a local | A local of its type (`text: Result[&str, Utf8Error] = from_utf8(b);`), which Jac holds to borrowing what Rust says it borrows; refused in a field, a parameter or a result |
| `HashSet<&str>`, `Vec<&[u8]>` only built and read: `insert(s)`, `contains(k)`, `len()`, given by `&` to a function of the crate | `HashSet[String]`, `Vec[Vec[u8]]`, each element made a `String` or a `Vec[u8]` before the statement that inserts it: nothing done with the set can tell the two apart |
| `vec![a, b]`, `let x;`, a `#[should_panic(expected = "m")]` test | `made: Vec[T] = Vec[T].with_capacity(2); made.push(a); made.push(b);` before the statement; `x: T;`; a test that passes when a `RustPanic` or `AssertionError` holding `m` is raised |
| `(a, b)`, `t.0`, `t.1 += 1`, `Vec<(usize, u32)>` | `(a, b)`, `t[0]`, `t = (t[0], t[1] + 1)`, `Vec[tuple[u64, u32]]` |
| `impl Ord for Merge { fn cmp(&self, o: &Self) -> Ordering { } }`, `#[derive(PartialEq, Eq)]`, `BinaryHeap<Merge>` | `struct Merge(Ord, PartialOrd, Eq, PartialEq) { def cmp(other: &Merge) -> Ordering { } }`: the struct conforms to Rust's traits, which Rust's generic code calls |
| `assert!(c)` outside a test | `if not c { raise RustPanic("assertion failed: c"); }`, `RustPanic` imported from `rust` |
| `impl Display for E { fn fmt(&self, f: &mut Formatter) -> fmt::Result { write!(f, "e {} {{x}}", self.code) } }`, `e.to_string()` | `impl E.__str__ -> str { return "e " + str(self.code) + " {x}"; }`, the String made of `str(e)` before the statement; `{}` of an integer, a `str`, a `String` or such a type only, and any other `fmt` body refused |
| `Result<(u32, u32), Fault>`, `Option<Shelf>` of what is Jac's after the port (the crate's own types, tuples): `Ok(x)`, `Err(e)`, `?`, `match`, `unwrap()` | `Result[tuple[u32, u32], Fault]` of the `rust` module, Jac's own, with `Ok`, `Err` and std's `is_ok`, `is_err`, `ok`, `err`, `unwrap`, `unwrap_err`, `expect`, `unwrap_or`; `Shelf \| None`, and an `Option` of what can itself be None refused |
| A file of the crate (`pub mod extra;` in `src/extra.rs`) | Its own Jac file, `src/extra.jac`; a file the crate does not compile with the features the project builds it with (its extension module's, else its defaults) is refused |

## What is refused

Anything not in the table is refused with E4001, and nothing is written for the file: among
them enums whose variants hold fields and their patterns, generics and another crate's
generic methods (`collect`, `map`, `find_iter::<str>`), a `for` over another iterator (a
slice's, another crate's), a `?` that converts the error, `Display` impls (`Formatter`), a
value that borrows kept past a local, `char`, raw pointers and `unsafe`, and a call of another
crate whose types Jac does not hold or that the import of Rust leaves out (its result
borrows from other than its receiver and its str or bytes arguments, or it may keep a
borrow of what it is given).
So is a construct in the table whose Jac would mean something else (E4005):

- **A float converted to an integer.** Rust stops at the type's ends and Jac raises.
- **A division whose operands are more than names.** Port tests the operands, and would
  evaluate them twice.
- **A method named `init` or `postinit`**, which is a Jac object's constructor.
