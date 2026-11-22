---
description: What neojac port makes of each C construct - the Jac it becomes, and what it refuses.
keywords: port c, porting C, C to Jac
---
# Porting C

`neojac port` translates a C source file into a Jac module that behaves as the file does, or
refuses it ([port](../toolchain/port.md)). This page is the mapping: each C construct port
translates and the Jac it becomes. It is printed from the table the translation itself reads
(`neojac port --mapping c`).

Clang reads the file once for each target neojac builds C for, with its module's flags, and
port translates each reading. Where they agree the Jac is written once. A statement that
differs by target is written under `comptime if` on `target()`, and a declaration that differs
goes to the module's target variant files (`x.windows.jac`).

A source file is ported with the header of its name, if it has one: `geom.c` and `geom.h` are
the module `geom`.

| C | Jac |
|---|---|
| `int`, `unsigned`, `long long`, `int64_t`, `signed char`, `unsigned char`, `short`, `double`, `float`, `_Bool` | `i32`, `u32`, `int`, `int`, `i8`, `u8`, `i16`, `float`, `f32`, `bool`: an integer by its width on each target, and a signed 64-bit one is `int`, as a C module's interface declares it |
| `int *`, `void *`, `const char *`, `FILE *`, `int (*)(int, int)`, `char [16]` in a record or at file scope | `ptr[i32]`, `ptr`, `ptr[i8]` on every target, `ptr[FILE]` with `obj FILE;` in `import from c`, `Callable[[i32, i32], i32]`, `array[i8, 16]` |
| `char`, whose sign is the target's: `int n = c;`, `c == 'a'` | `i8` on every target. Its value as a number is the target's: `n = i32(c);`, and `n = i32(u8.wrap(c));` where `char` is unsigned (Linux arm64), the two under `comptime if` where the targets differ |
| `int f(int a, double b) { }`, `void g(void) { }` | `def f(a: i32, b: float) -> i32 { }`, `def g { }` |
| `CFSTR("name")` (CoreFoundation's `__builtin___CFStringMakeConstantString`) | `__CFStringMakeConstantString(ptr[i8]("name"))`, the function CoreFoundation's header names for it where the compiler has no builtin, declared in `import from c` |
| `int say(const char *fmt, ...) { va_list ap; va_start(ap, fmt); n = vprintf(fmt, ap); va_end(ap); }` | `def say[*Ts](fmt: ptr[i8], *ap: *Ts) -> i32 { n = printf(fmt, *ap); }`: a pack of type parameters, compiled for each call's arguments; `va_start` and `va_end` are nothing, and a `v` function of the C library or CPython given the `va_list` is its plain one given the pack (`vsnprintf` is `snprintf`, `PyErr_FormatV` is `PyErr_Format`). C cannot call it: a C file that calls it ports in the same run (E4031) |
| `int main(void) { }` | `def main -> i32 { }` and `with entry { sys.exit(int(main())); }` |
| `int total = 0;` at file scope, `int x = 1;` in a function, `int x;`, a local of a name another variable of the function or of the file has | `glob total: i32 = 0;`, `x: i32 = 1;`, `x: i32 = 0;`, the name with `_2` (`_3`, ...): a Jac function has one variable of a name, of one type |
| `int x; f(&x);`, `int xs[3] = {1, 2};`, `char name[] = "ab";`: a local whose address is taken, a local array | `x = ptr[i32](__alloca(4)); f(x);`, `xs = ptr[i32](__alloca(12)); memset(xs, 0, 12); xs[0] = 1; xs[1] = 2;`: it lives in the function's frame, and is read and written through its address |
| `static int n = 0;` in a function `next` | `glob next_n: i32 = 0;`, beside the function |
| `struct point { double x; int n; };`, `struct point p = {1.5, 2};`, `p.x` | `struct point { has x: float = 0.0, n: i32 = 0; }`, `p: point = point(x=1.5, n=2);`, `p.x` |
| `lldiv_t q = lldiv(47, 5);`, `union sigval v; v.sival_int = 9;`: a record or a union a system header declares, held by value, or a record of no name a named one's field has (`extern_proc`'s `p_un`); a record of a header of the project's C module | `obj lldiv_t { has quot: int, rem: int; }` and `union sigval { has sival_int: i32, sival_ptr: ptr; }` in `import from c`, the fields from Clang's layout, a record of no name by the two names (`extern_proc_p_un`); the module's record by the wire from its header |
| `enum { RED, GREEN = 5 };` | `comptime RED: i32 = 0;`, `comptime GREEN: i32 = 5;` |
| `typedef struct { } point;`, `typedef int count;` | The record by its typedef's name; any other typedef is the type it names |
| `if (c) { } else if (d) { } else { }`, `while (c) { }` | `if c { } elif d { } else { }`, `while c { }`; a condition that is a number is `c != 0` |
| `for (int i = 0; i < n; i++) { }` | `for i = i32(0) while i < n with i += 1 { }` |
| `do { } while (c);`, with no `continue` of its own | `while True { ... if not c { break; } }` |
| `return v;`, `break;`, `continue;` | The same |
| `goto cleanup;` forward, to a label at the function's top level whose code runs to its end | `defer { if goto_cleanup { ... } }` where the function's variables are declared, and `goto_cleanup = True; return v;` at the `goto` |
| `cleanup: free(buf); return v;` that a forward `goto` reaches, or that none does | The code after it in a `defer`; a label no `goto` names is its statement |
| `a + b`, `a - b`, `a * b` of signed integers and of floats | `a + b`, `a - b`, `a * b`: C leaves a signed overflow undefined, and Jac raises OverflowError |
| `a + b`, `a - b`, `a * b`, `a << k` of unsigned integers | `a +% b`, `a -% b`, `a *% b`, `wrapping_shl(a, k)`: they wrap, as C defines |
| `a / b`, `a % b` of signed integers | `(a // b + 1) if (a % b != 0 and (a < 0) != (b < 0)) else (a // b)`, and the like for `%`: C rounds toward zero and Jac toward negative infinity |
| `a / b`, `a % b` of unsigned integers | `a // b`, `a % b` |
| `a / b` of floats | `a / b` where `b` is a literal other than 0; else `(a / b) if b != 0.0 else a * math.copysign(float("inf"), b)`, since Jac raises where C gives an infinity |
| `a < b`, `<=`, `>`, `>=`, `==`, `!=`, `a && b`, `a \\|\\| b`, `!a` | The same comparisons, `a and b`, `a or b`, `not a`; where C takes the result as a number, `i32(a < b)` |
| `a & b`, `a \\| b`, `a ^ b`, `~a`, `a >> k`, `-a`, `c ? a : b` | `a & b`, `a \\| b`, `a ^ b`, `~a`, `a >> k`, `-a` (`-%a` of an unsigned), `a if c else b` |
| `x = v;`, `x += v;` and the other compound assignments, `x++;`, `x--;` as statements | `x = v;`, `x += v;` (`x +%= v;` of an unsigned), `x += 1;`, `x -= 1;` |
| `5`, `5u`, `'a'`, `1.5`, `1.5f` | `5` where its type is given by what takes it, else `i32(5)`, `u32(5)`, `i32(97)`; `1.5`, `f32(1.5)` |
| `#define SHELF 12` and `SHELF` where a value is taken, a macro whose expansion is one integer | `comptime SHELF: i32 = 12;` and `SHELF`; any other macro is written as what it expands to |
| `p->x`, `*p`, `p[i]`, `&a[i]`, `&p->x`, `p + n`, `p - q`, `NULL`, `if (p)`, `!p` | `p[0].x`, `p[0]`, `p[i]`, `a + i`, `ptr[T](ptr[u8](p) + 8)` (the field's offset), `p + n`, `p - q` (an `int`), `ptr[T]()`, `if not p.is_null()`, `p.is_null()` |
| `switch (x) { case 1: case 2: f(); break; default: g(); }` | `switch x { case 1: case 2: f(); break; default: g(); }`: Jac's `switch` falls through as C's does |
| A conversion, written `(long long)x` or made by C: to a type that holds every value | `int(x)`, `float(x)` |
| A conversion to an integer type that does not hold every value; of a float to an integer | `u8.wrap(x)`, and `int(i64.wrap(x))` to a signed 64-bit integer: it keeps the low bits, as Clang defines; `i32(x)`: toward zero |
| `(char *)p`, `(void *)p`, `(intptr_t)p`, `(int *)n`, a string literal where its address is taken | `ptr[i8](p)`, `ptr(p)`, `int(p)`, `ptr[i32](int(n))`, `ptr[i8]("...")` |
| `f(a, b)`; `printf("%d\n", n)` of the C library | `f(a, b)`; `printf("%d\n", n)`, with `import from c { def printf(format: str, *args: any) -> i32; }` |
| `__builtin___strcpy_chk(d, s, n)`, `__builtin___snprintf_chk(b, n, f, k, fmt, ...)`: what `strcpy` and `snprintf` expand to where a header fortifies them | `strcpy(d, s)`, `snprintf(b, n, fmt, ...)`: the C library's function, without the check of a size the compiler would have known |
| `sizeof(int)` | Its value on each target, `u64(4)` |
| `offsetof(struct s, f)` | Its value on each target, `u64(8)` |

## What is refused

Anything not in the table is refused with E4001, and nothing is written for the file: a union,
a record with no name and a bit-field the file declares, a copy of a union a system header
declares, a `goto` other than the forward one to a function's cleanup the table maps, a
`va_list` read by `va_arg`, by `va_copy`, by more than one call or anywhere but the last argument
of a `v` function, a pointer to an array or to a function pointer, a function pointer that may
be null, a conversion of a function pointer a variable holds, a thread-local variable. So is a
construct in the table whose Jac would mean something else (E4005):

- **A division of floats whose operands have side effects.** Port tests the divisor, and would
  evaluate the operands twice. An integer division binds each operand once (`(was_1 := f(x)) %
  (was_2 := n)`) and tests those.
- **An assignment, `++` or `--` used for its value where C evaluates it only sometimes** (on
  the right of `&&` or `||`, in an arm of `?:`, in a `for`'s condition or step, in an `else if`'s
  condition), **or whose target has side effects.** Elsewhere port writes it as a statement before
  the one that uses its value.
- **A `case` label that is not directly in its `switch`'s braces.**

In a project, a C file that stays calls the Jac module's functions through its wire and the
module's header. Outside a project a function another file still calls is refused with E4002:
nothing would give that file the Jac. A call of a function a header of the project defines
`static inline` is refused with E4030 where no C module holds that header: once the file is Jac,
nothing would bind it.
