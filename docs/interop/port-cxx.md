---
description: What neojac port makes of each C++ construct - the Jac it becomes, and what it refuses.
keywords: port c++, porting C++, C++ to Jac
---
# Porting C++

`neojac port` translates a C++ source file into a Jac module that behaves as the file does, or
refuses it ([port](../toolchain/port.md)). This page is what port translates of C++ beyond
[C](port-c.md), whose mapping a C++ file's functions, statements and expressions follow. It is
printed from the table the translation itself reads (`neojac port --mapping c++`).

| C++ | Jac |
|---|---|
| `class C { int n; public: C(int n) : n(n) { } int get() { return n; } };` | `struct C { has n: i32 = 0; static def make(n: i32) -> C { made: C = C(); made.n = n; return made; } def get -> i32 { return self.n; } }`: a C++ object is a value, as a Jac struct is, and a struct is made from its fields |
| `int C::get() { return n; }`, defined outside its class | `def get -> i32;` in the struct, and `impl C.get -> i32 { return self.n; }` |
| `C c(1);`, `C c;`, `C d = c;`, `c.get()`, `this->n`, `true` | `c: C = C.make(1);`, `c: C = C();`, `d: C = c;`, `c.get()`, `self.n`, `True` |

## Overloads

Jac has one function to a name, so port names each member of a C++ overload set, a class's
constructors included, by the interface types of its parameters, joined by `_`: `scaled(double)`
is `scaled_f64`, `scaled(int, int)` is `scaled_i32_i32`, and a second constructor `C(int)` is
`C.make_i32`. A name with one member keeps its name. Clang says which member a call names, and
a C++ module's native import names its members the same way.

## What is refused

Anything not in the table or in C's is refused with E4001: inheritance and virtual functions,
templates, overloaded operators, destructors, references, namespaces, exceptions, `new` and
`delete`, static members, and the standard library.
