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

## Static members

A static member function is a `static def` of its struct (`static def boxes(n: i32) -> i32`), or
its `impl` when it is defined outside the class, and a call names it by its class: `C::boxes(13)`
is `C.boxes(13)`, and inside the class an unqualified `per_box()` is `C.per_box()` too. A static
data member is a `static has` of its struct, with the value its class gives it or, when the file
defines it outside the class (`int C::shelf = 40;`), the value that definition gives it; a use
names it by its class (`C.shelf`).

## Classes a header library gives

A class of a header-only C++ library the project holds as a C module (node-addon-api's
`Napi::Object`) is used as it is: port imports it from the header's module by the name its
interface gives it (`import from "node_modules/node-addon-api/napi" { Object }`), and names its
constructors and methods as that interface does. A local or field of one whose destructor runs
code is bound `own`, so it is dropped where its scope ends, as C++ destroys it.

## A unity build

A file its module compiles only inside another (a source that `#include`s it) is read as that
source reads it, and ports with it: when either is refused, so is the other (E4010 for the file
included, E4043 for the source that includes it), since one without the other is compiled nowhere.

## What is refused

Anything not in the table or in C's is refused with E4001: inheritance and virtual functions of
the file's own classes, templates and their instantiations (the standard library's among them:
`std::string`, `std::vector`, `std::lock_guard`), overloaded operators, user-defined conversions,
destructors, references, lambdas, range `for`, exceptions, `new` and `delete`, a static data
member another file defines, a member template or a member of a header library's class its
interface does not bind, and a field of a record a system header declares.
