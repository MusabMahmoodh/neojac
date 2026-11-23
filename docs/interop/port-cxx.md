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
| `virtual ~Shape() { ... }` of a class with virtual functions | `def destroy { ... }`, which ends with `super.destroy();` where the base declares a destructor: C++'s destructor, run where `delete` runs it |
| `Shape *s = new Square(2.0);` of a class with virtual functions | `s: Shape = Square(2.0);`: the object, which Jac counts and frees when nothing holds it |
| `delete s;` | `s.destroy();` where the class or a base declares a destructor, and nothing where none does |
| `C c(1);`, `C c;`, `C d = c;`, `c.get()`, `this->n`, `true` | `c: C = C.make(1);`, `c: C = C();`, `d: C = c;`, `c.get()`, `self.n`, `True` |
| `C(1, 2)` as a value | `C.make_i32_i32(1, 2)`: the constructor a library class's interface binds, or a ported class's `make` |
| `a == b`, `v[i]`, `s += t` on a class a library gives | `a.op_eq(b)`, `v.op_index(i)`, `s.op_iadd(t)`: the member its interface binds for the operator, `op_` and the operator's name, a conversion `op_to_` and its type |
| `reinterpret_cast<File *>(f)`, `reinterpret_cast<uintptr_t>(p)` | `ptr[File](f)`, `u64.wrap(int(p))`: C's cast of a pointer to another pointer or to an integer, and back; one of a reference, of a function pointer a variable holds or of a pointer to an object of a class with virtual functions is refused |

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

An instance of a header library's class template is named by its template form, its arguments
Jac types: `Napi::Reference<Napi::String>` is `Reference[String]`, `tally::Box<int>` is
`Box[i32]`; the program's build makes each instance the library does not. A free function of
the library is named as its interface names it (an overload set's member by its parameters,
`twice_i32`), wherever in the library's directory it is defined, and the wire names the set by
its C++ name (`tally.tally ++> app.use { twice }`).

## A unity build

A file its module compiles only inside another (a source that `#include`s it) is read as that
source reads it, and ports with it: when either is refused, so is the other (E4010 for the file
included, E4043 for the source that includes it), since one without the other is compiled nowhere.
In a unity build a function or a variable one file declares `static` is still every file's, so
the module of the file that defines it gives it to the others.

## Classes with virtual functions

A class of the file with virtual functions is an `obj`, held by reference as C++ holds it by
pointer: `Shape *`, `Shape &` and `const Shape &` are all `Shape`, and a call of a virtual
function dispatches as C++'s does. Its one base, if it has one, is its base in Jac, from another
file's module where that file declares it. Its constructor is its `init`, a base class
initializer `super.init(...)` (and `super.init()` where C++ runs the base's default
constructor), and `new Square(2.0)` is `Square(2.0)`. Its destructor is `def destroy`, ending
with `super.destroy();` where a base declares one, and `delete s;` is `s.destroy();`: the
destructors run where `delete` runs them, the subclass's first, and Jac frees the object when
nothing holds it. A pure virtual function is `abst`, and `Base::area()` called on an object is
`Base.area(s)`, which does not dispatch.

An object made by `new` and given where C takes a `void *` (a callback's user data) is lent to
C: `hold(Tally())`, a counted reference C holds. `static_cast<Tally *>(ctx)` of that address is
`held[Tally](ctx)`, the object again, and `delete static_cast<Tally *>(ctx);` is
`held[Tally](ctx).destroy(); release(ctx);`: the destructors run there, once, and C's
reference goes.

A local of such a class made by a constructor, `TempConverter conv(this);`, is
`conv: TempConverter = TempConverter(self);` where no class of it declares a destructor, so
nothing runs where its scope ends, and `&conv` is `conv`.

An object of such a class held by value where its destructor would run, copied, a pointer to
one that may be null, a call
of a member function on `this` in its constructor or destructor (C++ dispatches there as the
class being made), an overloaded virtual function, more than one base or constructor and a
`return` in its destructor are refused.

## What is refused

Anything not in the table or in C's is refused with E4001: inheritance from a class without
virtual functions, the file's own templates, a header library's function template, a
standard library class the library keeps to itself (`std::__wrap_iter`), operators
and conversions of the file's own classes, a non-member operator, the destructor of a class
without virtual functions, references but a library class's as a parameter and a class's with
virtual functions, lambdas, range `for`, exceptions, `new` and `delete` of anything but one
object of a class with virtual functions, a static data member another file defines, a member
of a library class its interface does not bind (a member template's instance whose arguments
are no class or number type among them), and a field of a record a system header declares.
