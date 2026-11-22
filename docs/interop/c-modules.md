---
description: C and C++ source compiled into a Jac program as a module - the cmodule.toml manifest and its keys, what Jac binds from the headers, wiring C modules together, C calling Jac, inline modules, C++ classes used and derived by Jac, and what goes wrong.
keywords: C module, cmodule.toml, {lib}, {platform}, {dir}, whole archive, inline C module, C++ module, C interface, calling Jac from C, jac/ header, static inline, C++ class, init_base, CRTP, header-only library, C data, extern, std_string, headers per target
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
| Its interface | What its own files declare: the headers its `headers` key lists, per target, or every header in its directory where it lists none; and each function and variable its C sources define, whether a header declares it or not | The headers its `headers` key lists |
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
| A function | A function; a variadic one takes extra arguments as `*args` does |
| `int32_t`, `int` | `i32`; `int64_t`, `long long` are `int`, the other integer types their sized type |
| `double`, `float` | `float`, `f32` |
| `const char *` parameter | `str \| bytes \| bytearray \| ptr[i8] \| None`: the text, the bytes of a buffer, a pointer passed as it is, or `NULL` |
| `const char *` result | `str \| None`, `None` for `NULL` |
| `char *` | `ptr[i8]`, whatever the target's `char` signedness |
| Any other pointer `T *` | `ptr[T]`; a parameter also takes `&x` or `&mut x` of a `T` variable, its address for the call |
| A pointer to a function | `Callable[[P, ...], R] \| None`, which a named Jac function is passed as, or `None` for `NULL`; a record's field also takes a function of a C module, as its own address |
| A `struct` | A record, constructed by keyword (`point(x=1.0, y=2.0)`, fields left out are zero), passed and returned by value |
| A `struct` declared but not defined (`typedef struct polygon polygon;`) | An opaque type, held as `ptr[polygon]`; its name is importable |
| A `struct` holding bit-fields or arrays of numbers | A record with [bit-fields and arrays](c-libraries.md#bit-fields-and-arrays), checked against Clang's layout |
| A trailing array of no length (`int32_t data[];`) | Left out of the record, whose size stays C's: it is the memory past the record |
| A `union`, a `typedef union` | A [union](../language/structs.md#unions), used by address and as a field |
| A record with no name that is a field's type (`struct { union { ... } amount; }`) | A record named by its record and field (`shape_tagged_amount`), reached through the field |
| A `struct` declared but not defined (`typedef struct polygon polygon;`) | An opaque type, held as `ptr[polygon]`; its name is importable |
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
- a record whose bound fields do not make C's size: an array of anything but numbers, a
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
inline = true                      # compiled to bitcode, inlined with the Jac (below)
export = true                      # the program exports its symbols (below)
shared = "counter"                 # built into a shared library beside the program (below)

[files."counter.c"]                # flags for one source, besides the module's:
defines = ["COUNTER_FAST"]         # include, defines and cflags

[target.linux]                     # added for one target
sources = ["counter_posix.c"]

[target.darwin]
frameworks = ["CoreFoundation"]    # macOS frameworks its code calls
```

- Every key is optional. A dependency with no `headers` (one that is only `archives`, say: a
  library built elsewhere) has no interface: a program binds its functions by declaring them
  (below). A module of the project's own takes its interface from its files: the `headers` it
  lists, which may differ by target (`[target.linux] headers = [...]`), as
  `neojac absorb --record` writes them from what each platform's build read; where it lists none,
  every header of its directory. A directory that holds every platform's headers
  (`arch/linux/init.h` beside `arch/osx/init.h`) names each target's, so that no target reads
  another's.
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
| A constructor | `C.make(args)`; a class that declares none has `make()` |
| A copy | `v.__copy__()`; the C++ object is destroyed where its `own` owner's scope ends when its destructor runs code ([below](#c-values-whose-destructor-runs-code)), and by `__del__`, when the Jac object is freed, when it does not |
| Single inheritance | The Jac classes derive each other: a `Rect` is a `Figure`, and a virtual call runs C++'s final overrider |
| An overload set | One function a member, named by its parameters' interface types: `scaled(double)` is `scaled_f64`, `scaled(int, int)` `scaled_i32_i32`, a second constructor `make_i32`; a name with one member keeps it |
| A result by value | Owned by Jac; a result by reference is borrowed |
| `std::string`, `std::vector<int>` | libc++'s own classes, instantiated where the module's signatures reach them: `v.push_back(i32(42))`, `s.c_str()` |
| A thrown exception | A Jac exception: `std::out_of_range` is `IndexError` |
| A class template | Instantiated only by a Jac class deriving it with itself (below) |

A wire may name an overload set by its C++ name, and binds each member.

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
`Counted`'s virtual methods call Heavy's. Only an instance whose arguments name the deriving
class itself, besides number types, is made; any other instance of a C++ template is refused by
name. A program whose C++ instances do not compile (a Jac method's types disagree with the
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
that frees what it holds) is an [owned value](../language/ownership.md): a local or a field holding
one is declared `own`, and the C++ object is destroyed where its owner's scope ends, as C++
destroys it (E1256 without `own`). A Jac class deriving such a class is one too.

- **A C++ function's class parameters are borrows** (`def described(f: &Figure)` in the
  interface): an owner is lent for the call, and C++ copies a by-value parameter itself.
- **A wire may name a class the file's interface reaches** though its source declares no class of
  that name: `shapes.figures ++> main { std_string, text }` binds libc++'s `std::string`, which
  `text` returns, so that a local holding one can be declared `sep: own std_string = text(" ");`.

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
  `async` (E1249).
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
