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
| `C(1, 2)` as a value | `C.make_i32_i32(1, 2)`: the constructor a library class's interface binds, or a ported class's `make` |
| `a == b`, `v[i]`, `s += t` on a class a library gives | `a.op_eq(b)`, `v.op_index(i)`, `s.op_iadd(t)`: the member its interface binds for the operator, `op_` and the operator's name, a conversion `op_to_` and its type |

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

## Library classes

A class of a header-only C++ library the project holds as a C module (node-addon-api's
`Napi::Object`) is used as it is: port imports it from the header's module by the name its
interface gives it (`import from "node_modules/node-addon-api/napi" { Object }`). A class of
the C++ standard library is libcxx's, by its template form: `std::vector<int>` is
`std_vector[i32]`, `std::lock_guard<std::mutex>` is `std_lock_guard[std_mutex]`, `std::string`
is `std_string`. A local or field of one whose destructor runs code is bound `own`, so it is
dropped where its scope ends, as C++ destroys it.

Each constructor, method, operator and conversion a call names is the member the class's
interface binds for that very declaration, by the name the interface gives it, on each target:
`std::lock_guard<std::mutex> g(m)` is `std_lock_guard[std_mutex].make(m)`; an operator is
`op_` and its name (`v[i]` is `v.op_index(i)`, `a == b` is `a.op_eq(b)`), and a conversion
`op_to_` and its type (`int n = c;` is `n: i32 = c.op_to_i32();`). A member the interface binds
under another's name stands for it where their parameters are the same to Jac
(`push_back(const int&)` and `push_back(int&&)`); a member the interface does not bind is
refused, with the interface's reason. A parameter that is a reference to such a class
(`const C&`, `C&`) is a borrow of it, `c: &C`.

A call of a library class's member template names the instance by its type arguments, as Jac
types: `v.As<Napi::Object>()` is `v.As[Object]()`, `c.to<double>()` is `c.to[float]()`. Member
templates of one name are named as an overload set is, by the types of the parameters the
template does not make: `o.Set("k", fn)` is `o.Set_ptr_i8[Function]("k", fn)`. The program's
build makes each instance it names.

## A unity build

A file its module compiles only inside another (a source that `#include`s it) is read as that
source reads it, and ports with it: when either is refused, so is the other (E4010 for the file
included, E4043 for the source that includes it), since one without the other is compiled nowhere.

## What is refused

Anything not in the table or in C's is refused with E4001: inheritance and virtual functions of
the file's own classes, the file's own templates, an instance of a header library's class
template, a standard library class the library keeps to itself (`std::__wrap_iter`), operators
and conversions of the file's own classes, a non-member operator, destructors, references but a
library class's as a parameter, lambdas, range `for`, exceptions, `new` and `delete`, a static
data member another file defines, a member of a library class its interface does not bind
(a member template's instance whose arguments are no class or number type among them), and a
field of a record a system header declares.
