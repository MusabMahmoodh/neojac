---
description: C and C++ source compiled into a Jac program as a module - the cmodule.toml manifest and its keys, what Jac binds from the headers, wiring C modules together, C calling Jac, inline modules, C++ classes used and derived by Jac, and what goes wrong.
keywords: C module, cmodule.toml, {lib}, {platform}, {dir}, whole archive, inline C module, C++ module, C interface, calling Jac from C, jac/ header, static inline, C++ class, init_base, CRTP, libcxx, std_vector, header-only library, C data, extern, std_string, headers per target
---
# C modules

A directory holding a `cmodule.toml` is a C module: C (or C++) source that a program compiles with
it and imports as it imports a Jac module. In a project (a directory with a `jac.toml`) the manifest
is a table of `jac.toml`, `[c."<directory>"]`, which neojac writes as that file: `neojac absorb
<directory>` takes an existing one in ([Packages](../toolchain/packages.md#rust-crates-c-modules-and-python-projects)). Clang, inside neojac, reads the module's headers, so the
program binds what they declare without writing declarations of its own, and compiles its sources
into the program. To call a library that is already built, declare its functions instead: see
[C libraries](c-libraries.md) (`neojac docs C library`).

A C module is one of two things, by who holds its manifest:

| | The project's own | A dependency |
|---|---|---|
| Its manifest | A table of `jac.toml`, `[c."<directory>"]` | A `cmodule.toml` in its directory that `jac.toml` does not hold: a vendored library, a loose module beside a program with no `jac.toml` |
| Its interface | What its own files declare: the headers its `headers` key lists, per target, or every header in its directory where it has no `headers` key; and each function and variable its C sources define, whether a header declares it or not | The headers its `headers` key lists |
| Under an `archwire.jac` | Its files are modules, and a wire names the file that defines what it brings ([below](#wiring-c-modules)) | One module, whole |

## The shortest example

A program with a C module `geom`, a directory beside `main.jac`. It needs no `jac.toml`: a loose
`main.jac` builds with the module beside it, as a project's does.

`geom/cmodule.toml`:

```toml
headers = ["geom.h"]
sources = ["geom.c"]
libs = ["m"]
```

`geom/geom.h`:

```c
#include <stdint.h>

#define GEOM_VERSION 2

typedef enum { SHAPE_SQUARE = 1, SHAPE_CIRCLE = 2 } shape_kind;

typedef struct {
    double x;
    double y;
} point;

typedef struct polygon polygon;

extern int64_t points_made;

point point_new(double x, double y);
double point_length(const point *p);
const char *shape_name(int32_t kind);
int64_t geom_sum(int32_t n, ...);
int64_t geom_fold(int64_t start, int32_t times, int64_t (*step)(int64_t, int64_t));
polygon *polygon_new(void);
void polygon_add(polygon *poly, point p);
double polygon_perimeter(const polygon *poly);
void polygon_free(polygon *poly);
```

`geom/geom.c` defines them. `main.jac`, beside `geom/`:

<!-- example: not checked: needs the C module geom beside the program -->
```jac
import from geom {
    GEOM_VERSION,
    SHAPE_CIRCLE,
    geom_fold,
    geom_sum,
    point,
    point_length,
    point_new,
    points_made,
    polygon,
    polygon_add,
    polygon_free,
    polygon_new,
    polygon_perimeter,
    shape_name,
}

def add(acc: int, i: int) -> int {
    return acc + i;
}

def square(side: float) -> ptr[polygon] {
    poly = polygon_new();
    polygon_add(poly, point(x=0.0, y=0.0));
    polygon_add(poly, point(x=side, y=0.0));
    polygon_add(poly, point_new(side, side));
    polygon_add(poly, point_new(0.0, side));
    return poly;
}

with entry {
    p = point_new(3.0, 4.0);
    print(GEOM_VERSION, p.x, point_length(&p), shape_name(i32(SHAPE_CIRCLE)));
    print(geom_sum(i32(3), 10, 20, 12), geom_fold(100, i32(4), add));
    sq = square(2.5);
    print(polygon_perimeter(sq), points_made);
    polygon_free(sq);
}
```

```sh
neojac build main.jac -o main && ./main
```

```text
2 3.0 5.0 circle
42 106
10.0 3
```

`import geom;` works too, and the names are then `geom.point_new` and so on. A C module is found as
any import's module is: by its dotted path from the importing file's directory or the project's
root (`import from vendor.zlib { ... }` for `vendor/zlib/cmodule.toml`).

## What Jac binds from the headers

Clang reads the headers for the program's target. What they declare in files under the module's
directory, and under the directory of each header they name outside it (a library's installed
API, such as Node-API's `node_api.h`), becomes Jac declarations, in the types a
[C library](c-libraries.md#types-in-a-declaration) declaration takes. Declarations of the system's
headers (`<stdio.h>`, `<stdint.h>`) are not part of the module.

| C | Jac |
|---|---|
| A function | A function; a variadic one takes extra arguments as `*args` does. One declared without a prototype (`long long count();`) takes no parameters where the module's definition of it takes none, as C reads an empty list in a definition |
| `int32_t`, `int` | `i32`; `int64_t`, `long long` are `int`, the other integer types their sized type |
| `double`, `float` | `float`, `f32` |
| `const char *` parameter | `str \| bytes \| bytearray \| ptr[i8] \| None`: the text, the bytes of a buffer, a pointer passed as it is, or `NULL` |
| `const unsigned char *` parameter | `str \| bytes \| bytearray \| ptr[u8] \| None`, as a `const char *` is, with a pointer to bytes passed as it is: `shape_octet_sum(b"\x01\x02\x03", 3)` |
| `const char *` result | `str \| None`, `None` for `NULL` |
| `char *` | `ptr[i8]`, whatever the target's `char` signedness |
| Any other pointer `T *` | `ptr[T]`; a parameter also takes `&x` or `&mut x` of a `T` variable, its address for the call |
| A pointer to a function | `Callable[[P, ...], R] \| None`, which a named Jac function is passed as, or `None` for `NULL`; a C function of a module is passed as its own address, to a parameter or a record's field: with `int64_t pick(int64_t (*f)(int64_t), int64_t x)` and `twice` of one module wired in, `pick(twice, 21)` is C's `pick(twice, 21)` |
| A `struct` | A record, constructed by keyword (`point(x=1.0, y=2.0)`, fields left out are zero), passed and returned by value |
| A `struct` declared but not defined (`typedef struct polygon polygon;`) | An opaque type, held as `ptr[polygon]`; its name is importable |
| A `struct` holding bit-fields, or arrays of numbers or pointers | A record with [bit-fields and arrays](c-libraries.md#bit-fields-and-arrays), checked against Clang's layout |
| A trailing array of no length (`int32_t data[];`) | Left out of the record, whose size stays C's: it is the memory past the record |
| A `union`, a `typedef union` | A [union](../language/structs.md#unions), used by address and as a field |
| A record with no name that is a field's type (`struct { union { ... } amount; }`) | A record named by its record and field (`shape_tagged_amount`), reached through the field |
| An anonymous member, a record with no name and no field name (`struct value { int32_t kind; union { int64_t whole; double real; }; }`) | A field `anon0` (the next one `anon1`) of a record named by its record and that name (`value_anon0`): C's `v.whole` is `v.anon0.whole`. Where the record has a field of its own named `anon0`, the member stays unnamed, and `neojac port` refuses a use of it |
| A record whose tag is also a function's name (`struct extent` beside `int64_t extent(struct extent *e)`) | A record named `struct_` and its tag, `obj extent as struct_extent` in the interface: `struct_extent(w=i32(6), h=i32(7))`. It is the one type `struct extent` is across the program, and a wire names it `struct_extent` (see [A record named in Jac other than by its tag](c-libraries.md#a-record-named-in-jac-other-than-by-its-tag)) |
| An `extern` variable | A global the program reads and assigns in place; one of an opaque type is used through `addressof()` |
| An enum constant, an integer `#define` | An `int` constant; a sign and a suffix (`(-17)`, `0xff00u`) are kept |
| A `static inline` function of a header | A function of its C name, called through a C shim the module compiles |

**A header's `static inline` function** defines no symbol, so neojac writes a shim for it: a C
function that calls it, compiled with the module's flags (as bitcode in an inline module, so the
call costs nothing once LLVM inlines it). The interface declares it under its own name, and the
program calls it as any C function: `shapes_point_sum(&pt)`. Only the shims of the functions a
Jac module imports are compiled, those of an included header (`Py_INCREF` of `<Python.h>`)
among them.

A declaration the interface cannot express is left out, and a module that imports it is told why
(E5133):

- a function taking or returning a union by value, or a record holding one: the calling
  convention of such a record is not bound;
- a `static inline` function taking C's `...`, which a shim cannot pass on;
- a record whose bound fields do not make C's size: an array of anything but numbers and pointers, a
  bit-field with no name, a layout that differs from Clang's;
- a global C array.

A name the headers do not declare at all is E1145.

## The manifest

```toml
headers = ["counter.h"]            # a dependency's interface, read with Clang
sources = ["counter.c"]            # compiled into every program using it
include = ["include"]              # header directories
defines = ["NDEBUG", "LEVEL=2"]    # -D, as NAME or NAME=VALUE
cflags = ["-fwrapv"]               # other Clang flags, for every source
cxxflags = ["-std=c++20"]          # Clang flags for its C++ sources alone
libs = ["m"]                       # C libraries its code calls
ldflags = ["-Wl,--gc-sections"]    # options for the linker of what it is linked into (below)
archives = ["lib/libfoo.a"]        # static libraries linked with its code
whole_archives = ["lib/libapi.a"]  # static libraries linked whole
also_in = ["vendor.engine"]        # C modules whose archives hold this code already (below)
crates = ["{lib}/node/crates"]     # Rust crates outside the project its code links (below)
inline = true                      # compiled to bitcode, inlined with the Jac (below)
export = true                      # the program exports its symbols (below)
shared = "counter"                 # built into a shared library beside the program (below)
vendored = true                    # another project's code, kept in this one (below)
interpreter = true                 # an interpreter's C API: an extension module links none of it (below)

[files."counter.c"]                # flags for one source, besides the module's:
defines = ["COUNTER_FAST"]         # include, defines and cflags

[target.linux]                     # added for one target
sources = ["counter_posix.c"]

[target.darwin]
frameworks = ["CoreFoundation"]    # macOS frameworks its code calls
```

- `name` (in a project's table) gives the module a key of its own, by which a wire names it
  (`[c."psutil/arch"] name = "_psutil"`, `_psutil ++> main { ... }`); the table stays keyed by its
  directory. It is identifiers joined by `.`, and a key no Jac or Python module of the program
  has (E2270). `neojac absorb --record` writes it, as the last part of the extension module the
  module is built into. Without it the module's key is its directory. A program that reaches the
  module both by its `name` and through the wires of the files it holds (a ported file's
  `_psutil ++> psutil.arch.osx { ... }` beside a C file's own `-->` wires) reaches one module,
  built and linked once. A wire from the module, where its directory is also a Python package,
  names it by its `name`: the directory's dotted name is the package's (E2270).
- `headers`, where the table has the key, is the module's whole list of headers. An entry is a
  path from the module's directory, or `<name>`, a header found on the module's include path,
  the system's included (`headers = ["<Python.h>"]`). A module whose sources are all gone (every
  one ported to Jac) stays a module over such headers: its interface binds what the wires name,
  their `static inline` functions included, through a shim neojac compiles. A header beside a
  Jac module of its stem is that module's face to C ([below](#calling-jac-from-c)), never one of
  a C module's headers.
- Every key is optional. A dependency with no `headers` (one that is only `archives`, say: a
  library built elsewhere) has no interface: a program binds its functions by declaring them
  (below). A module of the project's own takes its interface from its files: the `headers` it
  lists, which may differ by target (`[target.linux] headers = [...]`), as
  `neojac absorb --record` writes them from what each platform's build read; where it has no
  `headers` key, every header of its directory. A module an extension module's record names is
  read for the platforms that record lists alone (`[extensions."<path>"] recorded`), as its build
  and `neojac port` read it; one no record names is read for every platform. A directory that holds every platform's headers
  (`arch/linux/init.h` beside `arch/osx/init.h`) names each target's, so that no target reads
  another's. A header of the project outside the module's directory that its build reads
  (`../include/clamp.h`) is the module's when `headers` names it: its `static inline` functions
  are bound with the module's, and a header of the project that defines such functions belongs
  to one C module, the one whose build reads it, as `absorb --record` writes it.
- Paths in `headers`, `sources`, `include`, `archives`, `whole_archives`, a files table's name
  and its `include` are relative to the module's directory, and may climb out of it
  (`archives = ["../../api/libplain.a"]`). A files table's `include` must name a directory
  (E5132).
- A target table is named by an operating system (`darwin`, `linux`, `windows`), an architecture
  (`x86_64`, `aarch64`) or both (`"darwin.aarch64"`). What it holds is added to the module's lists
  when the program is built for that target; it may hold files tables too.
- `frameworks` names the macOS frameworks the module's code calls, so it belongs in
  `[target.darwin]`. At the top level it
  is refused (E5132, `macOS's go in [target.darwin]`) in a build for another operating system.
- `{lib}` in a path is the toolchain's `lib/` directory, and `{platform}` the program's platform
  (`linux-x86_64`, `macos-aarch64`, `windows-x86_64`, ...). So a module builds on the C libraries
  the toolchain ships for each platform:

  ```toml
  include = ["{lib}/clibs/{platform}/include"]
  archives = ["{lib}/clibs/{platform}/lib/libz.a"]
  ```

  A path naming any other place (`{root}`) is E5132.
- A define's value may name `{lib}`, `{platform}` and `{dir}`, the module's own directory, each as
  a C string's contents: `defines = ['DATA_DIR="{dir}/data"']`.
- An assembly source (`.S`, `.s`) is compiled too.
- `prebuilt_shared = "lib/foo"` (Windows) links `lib/foo.lib` and copies `lib/foo.dll` beside the
  program.
- An archive may have a shared library that holds the same code: a file `<archive>.shared` beside
  it names the library, by a path from the archive's directory (`libfoo.a.shared` holding
  `libfoo.so`). On Linux a plain build then links the library, not the archive, and the program
  finds it where it was at the build; a `--release` build links the archive in
  ([build](../toolchain/build.md#--release)). neojac's own `lib/` says this of LLVM's archives.
- `crates` names Rust crates the module's code links, by their directories, each holding a
  `Cargo.toml`: each is built in the program's one Rust link, against its one standard library,
  and wired whole into the C module, as `crate ++> cmod` does. It is for a crate the project's
  `archwire.jac` cannot name, outside the project (the toolchain's own: Node's crate is
  `{lib}/node/crates`); the project's own crate there is E5132, since its wire is the one way.
- `vendored = true` says the module is another project's code kept in this repository (a
  library's amalgamation, a dependency's sources): it is built as it is, and
  [`neojac port`](../toolchain/port.md#in-a-project) reads none of it (a path into it is E4011).
  No tool can tell that from the files, so `absorb` never writes it: the project says it.
- `interpreter = true` says the module is an interpreter's C API, which the interpreter that
  loads an extension module gives it: a program that is an extension module
  ([Extension modules](../toolchain/packages.md#extension-modules)) compiles against the
  module's headers and links nothing of it, neither its sources nor its archives, libraries and
  frameworks, and takes those functions from the interpreter that loads it (on macOS it is linked
  as a bundle whose undefined symbols the loader resolves, as a C extension is). neojac's CPython
  says it of itself.
- A key the manifest does not know is E5132.

### Shared, exported and whole

- **`shared = "<name>"`** builds the module's code into a shared library, `lib<name>.so`,
  `lib<name>.dylib` or `<name>.dll`, which the build writes beside the program and the program
  loads. Every module naming the same `shared` goes into the same library. A build writes the
  library again when it is missing, and programs built into one directory share it.
- **`export = true`** makes the program export the module's symbols, those of its sources and of
  the static libraries it links, as an interpreter linked with `--export-dynamic` does, for the
  shared libraries the program loads to link against. Nothing else of the program is exported:
  its Jac, the other C modules (what their assembly sources define included) and its Rust
  modules are linked hidden. That holds for an ELF or Mach-O program. A Windows program exports nothing this way: there what an interpreter exports
  is its DLL's, as CPython's C API is `python315.dll`'s.
- **`ldflags`** are options for the linker of what the module is linked into: the program, or the
  extension module built from it. One written as a compiler driver is told, `-Wl,a,b`, is the
  options `a` and `b`. They are the linker's own (ld64's on macOS, ld's on Linux), so they belong
  under `[target.<os>]` wherever they differ, and an option the linker has none of fails the link.
- **`whole_archives`** links every object of an archive, not only those the link reaches. That is
  what a module that exports a C API needs of a library whose functions it exports though nothing
  in the program calls them.
- **An archive several modules name**, by one path or by several leading to the same file, is
  linked once into each output (the program, or a `shared` library), and whole if any of them
  lists it in `whole_archives`.
- **`also_in`** names, by their dotted names, the C modules that already hold this module's
  code: a library another module links whole that was built with these same sources. In a
  program with one of them the sources are not compiled, and the functions the headers declare
  are that module's; the code is in the program once either way. The runtime's expat is such a
  module: the interpreter a program using Python links has expat built in, under the same
  names.

## Inline modules

A module whose manifest says `inline = true` compiles to LLVM bitcode instead of objects, and the
program's module links it in, each source a unit of its own. The optimizer then inlines across its
C and the Jac, as it does between Jac modules, at the cost of optimizing its code again with the
program's on every build. C's own constructs carry through: `__attribute__((constructor))` functions run before
the program's code and `destructor` ones after it, and `used` data, weak references and computed
gotos are kept. `neojac build --c-archive` builds no program, so there an inline module compiles to
objects, which the archive holds with every other module's.

## C++ sources

A source Clang takes for C++ by its name (`.cc`, `.cpp`, `.cxx`, ...) compiles as
[`neojac c++`](c-and-cpp.md) compiles it, with libc++ and the module's `cxxflags` besides its
`cflags`. A header ending in `.h` that is C++ (a header-only library) is read as C++ when the
module's table says `language = "c++"`; a module with no sources may list its `headers` alone.

C++ static objects are constructed before the program's code runs. Every program and shared
library links the toolchain's C++ runtime (libc++, libc++abi, and libunwind except on macOS)
statically, after everything else, so the linker takes only what something references, and a
program that references none of it links none.

### What Jac uses of C++

A C++ file is wired into Jac as a C file is (`shapes.figures ++> main { Figure, Rect, scaled }`),
and Jac uses what it declares as C++ means it, through C-ABI shims neojac compiles from it.
Nothing needs to be `extern "C"`.

| C++ | Jac |
|---|---|
| A class | An `obj`, its methods called as Jac's: `r.area()`, `Figure.alive()` for a static one |
| A constructor | `C.make(args)`; a class that declares none has `make()`. `C()` is the default constructor, where the class has one the interface binds; a call of the class with arguments, or of one with no default constructor, is E1621 |
| A constructor template | Each instance the program's C++ or its port names, a constructor named by its parameters as any other: `std::string s(p)` is `std_string.make_ptr_i8(p)` |
| A copy, a destructor | `v.__copy__()`. An object whose destructor runs code is destroyed where its `own` owner's scope ends ([below](#c-values-whose-destructor-runs-code)); any other by `__del__`, when the Jac object is freed |
| Single inheritance | The Jac classes derive each other: a `Rect` is a `Figure`, and a virtual call runs C++'s final overrider |
| An overload set | One function a member, named by its parameters' interface types: `scaled(double)` is `scaled_f64`, `scaled(int, int)` `scaled_i32_i32`, a second constructor `make_i32`; a name with one member keeps it |
| An operator, a conversion | A method named `op_` and the operator's word: `c[i]` is `c.op_index(i)`, `a == b` `a.op_eq(b)`, `s += t` `s.op_iadd(t)`, `c = d` `c.op_assign(d)`; a conversion `op_to_` and its type, `operator int()` `c.op_to_i32()`. Overloads are named apart as any member's. A non-member operator is not bound |
| A result by value | Owned by Jac; a result by reference is borrowed |
| A result that is a reference to a number or a pointer (`int &operator[](size_t)`, `int &at(size_t)`) | The read, and beside it the store through the reference, the member's name and `_set`: `v.op_index_set(i, x)` for `v[i] = x`, `v.at_set(i, x)` for `v.at(i) = x`. None where a member of that name exists, and none for `const char *&` |
| A pointer parameter or result | Typed as C++ types it: `int *` is `ptr[i32]`, `napi_value` (`struct napi_value__ *`) `ptr[napi_value__]`, `X **` `ptr[ptr[X]]`; a C record no header of the module declares is declared by the interface (`obj napi_value__;`), one type across the program with C's |
| A parameter that is a reference to a class (`const C&`, `C&`) | A borrow, `c: &C`: the Jac object is lent for the call, and an assignment through the reference is `op_assign` |
| A pointer to a record no header gives the members of (`napi_value`) | C's opaque handle, as a C function's is ([above](#what-jac-binds-from-the-headers)): a member taking or giving one is bound |
| `std::string`, `std::vector<int>`, `std::lock_guard<std::mutex>` | `std_string`, `std_vector[i32]`, `std_lock_guard[std_mutex]`: libc++'s classes, of the module `libcxx` ([below](#the-c-standard-librarys-classes)) |
| A thrown exception | A Jac exception: `std::out_of_range` is `IndexError` |
| A member function template | `o.m[A, B](args)`, the instance `m<A, B>`, made for the program ([below](#member-function-templates)) |
| A class template of the module | `T[A, B]`, the class `T<A, B>` by its template form, made for the program ([below](#class-templates)); a Jac class may derive one made with itself (CRTP, below); the standard library's are `libcxx`'s |

A wire may name an overload set by its C++ name, and binds each member: `tally.tally ++> main {
twice }` binds `twice_i32` and `twice_f64`, which the Jac code calls.

A header library's function is the module's wherever in its directory it is defined: node-addon-api's
`napi.h` declares functions that `napi-inl.h`, a header only `napi.h` includes, defines. A wire
names it from the header the module lists (`headers = ["napi.h"]`), and so does a use of it from
another C++ file of the project.

### Member function templates

A call of a C++ class's member function template names its instance by type arguments in brackets,
as a call of a Jac generic method may ([Generics](../language/generics.md)): `o.m[A, B](args)` calls
`m<A, B>`, and a static one is called by its class, `C.m[A](args)`.

- **Its type arguments are Jac types**, as the interface writes C++ types: a class of the module, a
  `libcxx` class, or a number type (`i32` for `int`, `int` for a 64-bit integer, `float` for
  `double`).
- **A template is named by its C++ name** where the class has one template of that name. Templates
  of one name are named as an overload set's members are, by the types of the parameters that do
  not name the template's own: `add(const T &)` is `add_`, `add(const char *, const T &)` is
  `add_ptr_i8`.
- **The program's build makes each instance it names**, though nothing in the C++ makes it: the
  module's headers are read again with the instance asked for, and the interface binds it as a
  member of the class. A result of a class type is owned, as any result by value is.
- An instance the template does not take, or whose argument is no class or number type of C++, is
  E1620 where the program names another instance of the template that the build makes. Where it
  names none, the class has no member of that name, and the call is E1030 (`Counter has no field
  'to'`).

The header library `tally/tally.h`, a C module of the project with `language = "c++"`:

```cpp
class Counter {
public:
    explicit Counter(int start) : count(start) {}
    int value() const { return count; }
    template <class T> T to() const { return T(count); }
    template <class T> int add(const T &x) { count += int(x); return count; }
    template <class T> int add(const char *why, const T &x) { count += int(x) * 2; return count; }

private:
    int count;
};
```

<!-- example: not checked: needs the C module tally, wired tally.tally ++> main { Counter } -->
```jac
with entry {
    c = Counter.make(i32(7));
    again = c.to[Counter]();
    print(c.to[float](), again.value());
    print(c.add_[i32](i32(2)), c.add_ptr_i8[float]("half", 1.5));
}
```

```text
7.0 7
9 11
```

### Class templates

A class template of the module is named by its template form, as the standard library's are
([below](#the-c-standard-librarys-classes)): `T[A, B]` is the C++ class `T<A, B>`, its arguments
Jac types as the interface writes C++ types (a class of the module, a `libcxx` class, a number
type). It is the module's own class, the same Jac class its functions take and give, with its
constructors, methods and operators bound as any class's are. The program's build makes each
instance the program names, whether or not the module's C++ reaches it.

With `tally/tally.h` holding

```cpp
template <class T> class Box {
public:
    explicit Box(const T &v) : held(v) {}
    T get() const { return held; }

private:
    T held;
};

inline Box<int> boxed(int v) { return Box<int>(v); }
```

<!-- example: not checked: needs the C module tally, wired tally.tally ++> main { Box, Counter, boxed } -->
```jac
with entry {
    bx: Box[i32] = boxed(i32(5));
    print(bx.get(), Box[i32].make(i32(6)).get());
    tc = Counter.make(i32(13));
    made = Box[Counter].make(tc);
    print(made.get().value());
}
```

```text
5 6
13
```

`Box[i32]` is the class `boxed` gives; `Box[Counter]` is an instance nothing in the C++ makes.
An instance whose argument is no class or number type of C++ is refused by name.

### A Jac class deriving a C++ class

A Jac class may list a C++ class as its base, where C++ allows a class to be derived: it is
polymorphic, not `final`, and its destructor is public or protected. Its `postinit` makes the
object's C++ part with `C.init_base(self, args)`, C++'s `: Figure(4)`: one `init_base` for each
constructor a subclass may call, public or protected, named as `make`'s overloads are.

<!-- example: not checked: needs the C module whose figures.hpp declares Figure and described -->
```jac
obj Square(Figure) {
    has side: float = 1.0;

    def postinit {
        Figure.init_base(self, i32(4));
    }

    override def area -> float {
        return self.side * self.side;
    }
}

with entry {
    sq: own Square = Square(side=3.0);
    print(described(sq).c_str(), sq.sides());
}
```

```text
figure/4/9 4
```

`described` is C++, and calls `area`, which Jac overrides, and `name`, which `Figure` defines.

- **The C++ part is a subclass of `C`** whose overrides of every virtual method of `C` and its
  bases call the Jac object's method of that name. A method the Jac class does not override, and
  `super.area()`, run C++'s own definition. A pure virtual method the Jac class does not
  override raises `NotImplementedError` when called.
- **`init_base` raises** `TypeError` when the object's nearest C++ class is not `C`, and
  `RuntimeError` the second time.
- **The Jac object owns its C++ part**, which is deleted when the Jac object is dropped: a class
  whose destructor runs code makes the deriving class an owned value too, bound `own`.
- **A virtual method takes** numbers, C strings, pointers and classes (given to Jac borrowed), and
  gives nothing, a number, a pointer or a copyable class by value. A class with any other
  virtual method cannot be derived, and its interface says why (E5133).

**A class template made with the deriving class**, C++'s CRTP, is a base too:
`obj Heavy(Counted[Heavy])` is `Counted<H>`, where `H` is Heavy's C++ part, a C++ class the
program's own C++ unit declares. Its members are Heavy's methods of number and `bool` types, each
calling the Jac method, so what the template calls on `T` reaches Jac, and its overrides of
`Counted`'s virtual methods call Heavy's. As a base, only an instance whose arguments name
the deriving class itself, besides number types, is made; a Jac class deriving any other
instance, or a class template a C++ source rather than a header defines, is refused by name. A program whose C++ instances do not compile (a Jac method's types disagree with the
template's virtual of that name) is E5200.

<!-- example: not checked: needs the C module whose figures.hpp declares Counted -->
```jac
obj Heavy(Counted[Heavy]) {
    has w: int = 5;

    def postinit {
        Heavy.init_base(self);
    }

    def weight -> int {
        return self.w;
    }

    override def unit -> i32 {
        return i32(3);
    }
}

with entry {
    hv: own Heavy = Heavy(w=7);
    print(hv.tally(i32(2)), hv.unit());
}
```

```text
13 3
```

### C++ values whose destructor runs code

A C++ class whose destructor is not trivial (`std::string`, `std::vector`, a class of the module
that frees what it holds) is an [owned value](../language/ownership.md): a local holding one is
declared `own`, and the C++ object is destroyed where its owner's scope ends, as C++ destroys it
(E1256 without `own`). A field with no ownership annotation is a managed place: it holds one
counted, and destroys it when its last reference goes, or at `del o.f`. A Jac class deriving such
a class is one too.

- **A C++ function's class parameters are borrows** (`def described(f: &Figure)` in the
  interface): an owner is lent for the call, and C++ copies a by-value parameter itself.
- **The C++ standard library's classes are `libcxx`'s** (below): a local holding the string
  `text` returns is declared `sep: own std_string = text(" ");`, with `std_string` imported from
  `libcxx`.

### The C++ standard library's classes

The classes of the C++ standard library a program uses have one home, the module `libcxx`, which
neojac makes for each program from the libc++ it ships: `import from libcxx { std_string,
std_vector }`. A C module's interface names them rather than declaring its own, so the string one
module's function gives is the string another's takes.

- **A class is named `std_` and its C++ name**: `std::string` is `std_string`, `std::mutex`
  `std_mutex`.
- **A class template is named by its template form**, as a program's own C++ template is:
  `std::vector<int>` is `std_vector[i32]`, `std::lock_guard<std::mutex>` is
  `std_lock_guard[std_mutex]`. libcxx makes each instance the program names, whether or not any
  C++ of the program reaches it.
- **Its members are bound as a C++ class's are**: overloads by their parameters' types, so a
  `std::vector`'s default constructor is `make_()`, which `std_vector[i32]()` calls; `at` past the
  end raises `IndexError`, and `v.at_set(i, x)` and `v.op_index_set(i, x)` store as `v.at(i) = x`
  and `v[i] = x` do.
- **A class whose destructor runs code is bound `own`** (below).
- A name that is no class of the standard library, or a type argument its template does not
  take, does not compile in libcxx: E5200.

```jac
import from libcxx { std_lock_guard, std_mutex, std_string, std_vector }

def guarded(mu: &std_mutex) -> int {
    lk: own std_lock_guard[std_mutex] = std_lock_guard[std_mutex].make(mu);
    return 1;
}

def main {
    v: own std_vector[i32] = std_vector[i32].make_();
    v.push_back(i32(42));
    v.push_back(i32(7));
    v.at_set(u64(1), i32(8));
    names: own std_vector[std_string] = std_vector[std_string]();
    mu: own std_mutex = std_mutex();
    print(v.size(), v.at(u64(1)), names.size(), guarded(&mu), mu.try_lock());
    mu.unlock();
    try {
        v.at(u64(5));
    } except IndexError {
        print("IndexError");
    }
}

with entry {
    main();
}
```

```output
2 8 0 1 True
IndexError
```

`libcxx` also gives C++'s replaceable allocation functions, so that memory C++ allocates is freed
as C++ frees it, and the reverse: `op_new(n)` and `op_delete(p)` are `::operator new` and
`::operator delete`, `op_new_array(n)` and `op_delete_array(p)` `::operator new[]` and
`::operator delete[]`. `n` is a `u64` count of bytes and the result a `ptr`; where C++ would throw
`std::bad_alloc`, they raise `MemoryError`. This is what `neojac port` writes for C++'s `new[]`
and `delete[]` of numbers and pointers ([Porting C++](port-cxx.md)).

```jac
import from jaclang.comptime { sizeof }
import from libcxx { op_new, op_delete, op_new_array, op_delete_array }

with entry {
    xs = ptr[i32](op_new_array(u64(4) * u64(sizeof(i32))));
    for i in range(4) {
        xs[i] = i32(i * 10);
    }
    print(xs[3]);
    op_delete_array(ptr(xs));
    try {
        op_new(u64(1) << u64(62));
    } except MemoryError {
        print("MemoryError");
    }
}
```

```output
30
MemoryError
```

## Wiring C modules

In a project with an `archwire.jac`, wires connect C modules as they connect Jac modules (see
[Import wiring](../language/modules-wiring.md), `neojac docs graph import`).

A C module of the project's own is wired by its files:

- **A C file to Jac** (`shapes.shapes ++> main { point, point_add }`): binds those names in the
  Jac module, as `import from` does. The provider is the file that gives the name: the source that
  defines a function or a variable, whichever header declares it, and the file that holds a type,
  an enumerator or a macro. A name another file gives is E1145.
- **A C file to a C file** (`shapes.shapes --> geom.geom { shape }`): declares what `geom.c` uses of
  `shapes.h`, which Clang holds to the sources ([A C module's files](#a-c-modules-files)). The
  module that holds `geom.c` is then built with the other on its include path, and the other is
  in every program it is in.
- A wire from the module itself (`shapes ++> main { point }`, `shapes ++> geom;`) is E1576, whose
  message gives the wires to write in its place.

A dependency is wired whole, and so is a crate:

- **C to Jac** (`zlib ++> main { crc32 }`): binds those names in the Jac module.
- **C to C** (`zlib ++> png;`): `png`'s sources may include `zlib`'s headers, `zlib` is built into
  every program `png` is in, and `png`'s interface uses `zlib`'s records rather than declaring its
  own.
- **Rust to C** (`tally ++> geom;`): links the crate into every program the C module is in, where
  the C module's code calls its `extern "C"` functions by name. See
  [Rust modules](rust-modules.md).

A C module takes another C module's interface and a Rust module whole, and a Jac module's
functions by name ([Calling Jac from C](#calling-jac-from-c)): a wire of a whole Jac module into
it, or one naming items of a Rust module, is E5136. A Jac module importing a C module of its
own top-level package must use a wire (E1144); across top-level packages, an import is governed by
the edge rules as any other.

## Calling Jac from C

A C module calls a Jac function as it calls any C function, once a wire gives it the function:

- **into a C module of the project's own**, by its file, declared as the C file's own use
  (`jhelp --> shapes.shapes { jhelp_calls, jhelp_scale }`), since the C source writes the calls;
- **into a dependency C module**, whole (`helper ++> c { helper_value }`).

<!-- example: not checked: needs the C module shapes and the archwire.jac that wires jhelp into it -->
```jac
glob calls: list[int] = [0];

def:pub jhelp_scale(x: float, times: i32, seen: ptr[int]) -> float {
    calls[0] += 1;
    seen[0] = 10;
    return x * float(times);
}

def:pub jhelp_calls -> int {
    return calls[0];
}
```

neojac writes the header `jac/jhelp.h`, which declares exactly the functions the wires give that
C module, before Clang reads any of its files:

```c
int64_t jhelp_calls(void);
double jhelp_scale(double, int32_t, int64_t *);
```

and `shapes.c` includes it:

```c
#include "jac/jhelp.h"

double shapes_jac_scaled(double x, int32_t *calls) {
    int64_t seen = 0;
    double out = jhelp_scale(x, 3, &seen);
    *calls = (int32_t)(seen + jhelp_calls());
    return out;
}
```

- **The named functions are C functions of the program** of those names, as a wire into a crate
  makes them. A C file's use of one is held to its wires as any import of C is (E1575, E1147).
- **A function C calls takes and gives** `int`, `i8` to `u64`, `float`, `f32` and `ptr[...]` (a
  pointer to anything but a number is `void *` in the header), and is neither generic nor
  `async` (E1249). It also takes a `Callable[[P, ...], R]` of those types, a function pointer:
  `def:pub twice_with(f: Callable[[int], int], x: int) -> int` is
  `int64_t twice_with(int64_t (*)(int64_t), int64_t);` in the header, and calls what C passed
  as C's function, `f(f(x))`. `ptr(f)` is the address C passed (see
  [Callbacks](c-libraries.md#callbacks)).
- **A header beside a Jac module of its stem** (`cpu.h` beside `cpu.jac`) is that module's face to
  C: a C use of a name it declares is a use of the Jac module. This is how a C file that
  [`neojac port`](../toolchain/port.md#in-a-project) made Jac is still called by the C of its
  module that stays.
- **A C module built into a shared library** cannot call the program's Jac (E5183): a C module
  that calls Jac is linked into the program.
- **The face header may give C macros of its own**: a wire from the Jac module into a C file
  names them beside the module's functions (`native.count --> native.unity { TWICE_BY, twice }`
  where `count.h` beside `count.jac` defines `TWICE_BY`). A name neither the module nor its face
  gives is E1145.

### C data a Jac module gives C

A `glob` a Jac module declares in `import from c` is C data of the program, and a wire gives it to
C as it gives a function: `jac/<module>.h` declares it `extern`, and the C files read and assign
the one variable the Jac module does.

<!-- example: not checked: needs the C module calc and the archwire.jac that wires knobs into it -->
```jac
import from c {
    glob bias: float = 0.25;
}

def:pub scale(x: float) -> float {
    return x * 2.0;
}
```

with `knobs --> calc.calc { bias, scale }` in `archwire.jac`, `jac/knobs.h` holds

```c
extern double bias;
double scale(double);
```

and `calc.c`'s `return scale(x) + bias;` gives `2.25` for `1.0`. C data a wire gives C is of
`int`, `i8` to `u64`, `float`, `f32` or `ptr[...]` (E1237).

An extension module of Python whose C calls Jac is built the same way: with
`counted --> csrc.spam { counted_words }` in `archwire.jac`, `csrc/spam.c` keeps its
`PyInit__spam` and calls `counted_words`, and `neojac build pyproject.toml` builds the extension
with the Jac and the runtime linked in ([Python](python.md#a-python-project-of-the-repository)).

## A C module's files

A C module of the project's own is what its table builds, and its files are modules of the project
besides: `geom/geom.c` with `geom/geom.h`, the header of its name, is `geom.geom`, and
`shapes/private/circle.h`, a header no source has the name of, is `shapes.private.circle`. Where
one file uses what another declares, a `-->` wire says so, as for a file in any other language
([Declared wires](../language/modules-wiring.md#declared-wires---)):

<!-- example: not checked: a graph import block is valid only in a file named archwire.jac, beside the modules it wires -->
```jac
graph import {
    shapes.shapes --> geom.geom { SHAPE_SQUARE, shape }
    shapes.private.circle --> shapes.shapes { SHAPES_CIRCLE_FACTOR }
}
```

`geom.c` uses the type `shape` and the enumerator `SHAPE_SQUARE` that `shapes.h` declares, and
`shapes.c` the macro `SHAPES_CIRCLE_FACTOR` of `private/circle.h`.

- Clang reads each of the module's sources as it compiles it, for every platform neojac builds C
  for, since each compiles code the others do not. An import is a use Clang resolved: of a
  function, a variable, a type (a `struct`, a `union`, an `enum`, a `typedef`), an enumerator or
  a macro. An `#include` is not one: it names a header, and says nothing of which file the code
  comes from.
- A function or a variable belongs to the file that defines it, whichever header declares it. A
  type, an enumerator and a macro belong to the file that holds them.
- A name each platform defines in a file of its own, `heap_info` in `arch/linux/heap.c` and in
  `arch/osx/heap.c`, is wired from each: a use belongs to the file that defines the name for
  the platform the use was read for. Where a platform has no file that defines it, the use is
  of the header that declares it.
- A platform's sources that this machine cannot read are not read: macOS's that use a framework
  the toolchain carries no headers of (IOKit), on a machine without the macOS SDK. What such a
  file gives is then not known there, so wires written on one system may not hold on another
  for those files.
- A C module is the project's own where `jac.toml` holds its table (`[c."geom"]`). One with a
  `cmodule.toml` that `jac.toml` does not hold is a dependency, one module whole, and so are a
  system's and a library's headers.
- These wires are checked by every command ([What a command judges](../language/modules-wiring.md#what-a-command-judges)), whether the program at hand uses the module or not, and mended by `neojac fmt --fix`.

## Declaring a C module's functions yourself

A module of another top-level package, or of a project that says `archwire = false`, may also bind a C
module's functions by declaring them, in the form that binds a [C library](c-libraries.md). The
dotted name names the C module, which the program then builds. Under an `archwire.jac` this is a
dependency's form alone: for a C module of the project's own it is E1144, since a wire from the
file that defines a function brings it, declared in a header or not.

<!-- example: not checked: needs the C module ext/plain beside the program -->
```jac
import from ext.plain {
    def plain_twice(x: i32) -> i32;
    def plain_offset(x: int) -> int;
}

with entry {
    print(plain_twice(i32(21)), plain_offset(24));
}
```

- Where the headers declare the function, the declaration must agree with theirs: the same
  parameters, each of the same type and passed the same way, the same result, and variadic only
  if theirs is (E5145, whose message gives the headers' signature). A `const char *` parameter
  may be declared as any one of `str`, `bytes` and `bytearray`.
- A function no header declares, such as one only a source defines, is the declaration's alone
  to describe.
- A record the declarations name is their own, never the headers' record of that name; bind a
  function that takes or returns a record through a wire or an import of the module instead.
- A dotted name that names a C module binds it even where a [project library](c-libraries-linking.md#a-library-the-project-provides)
  of that name exists too.

## Building

- Each source compiles with the Clang in neojac to an object the link takes, as a C build compiles
  it, for the program's target.
- Clang's output is cached under a key of what alone decides it: the Clang version, the command
  line and the content of every file the compilation read. The toolchain's and the project's
  directories enter the key as what they are, not where they are. So an unchanged file compiles
  once, for every neojac with the same Clang, every install of the toolchain and every copy of the
  project; a new neojac with the same Clang compiles no C again.
- C modules build for every target [`neojac cc`](c-and-cpp.md) builds for. `wasm32-wasi` takes none
  yet (E5090).
- `neojac build --c-archive` writes a program's C modules as one static library for another build
  system to link; see [Building programs](../toolchain/build.md) (`neojac docs build`).

## What goes wrong

| Code | Cause |
|---|---|
| E5132 | The manifest has a key neojac does not know, a value of the wrong kind, a place other than `{lib}` and `{platform}` in a path, a files table's `include` that is no directory, or `frameworks` outside `[target.darwin]` in a build for another operating system |
| E5134 | The interface headers do not compile; Clang's errors are printed first |
| E5135 | A source does not compile; Clang's errors are printed first |
| E5133 | The name is something the interface cannot express, and the message says what |
| E1145 | The headers declare no such name |
| E5145 | A declaration that disagrees with the headers |
| E5136 | A wire of a whole Jac module into a C module, or one naming items of a Rust module |
| E1249 | A Jac function a wire gives C takes or gives a type C cannot pass, or is generic or `async` |
| E5183 | A C module built into a shared library is given a Jac function by a wire |
| E5200 | The C++ instances of class templates Jac classes derive do not compile |
| E1144 | A Jac module imports its own package's C module instead of taking a wire, or declares the functions of a C module of the project's own |
| E1576 | A wire from a C module of the project's own, where its files are its modules |
| E5158 | A key of a C module's table in `jac.toml` of the wrong kind |
| E1236 | Two declarations of one C record that disagree |
| E1237 | C data a Jac module gives C of a type C cannot read |
| E1256 | A C++ value whose destructor runs code, bound without `own` |
| E5090 | A C module in a build for `wasm32-wasi` |

`neojac docs E5133` prints any of these with its message.

## Differences from Python and from the reference design

- In Python, C code reaches a program as an extension module written against CPython's C API, or
  through `ctypes` or `cffi`. Here plain C is compiled into the program and called directly, with
  its types read from its headers.
- The reference design has no C modules.
