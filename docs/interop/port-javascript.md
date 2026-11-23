---
description: What neojac port makes of each JavaScript and TypeScript construct - the Jac it becomes, and what it refuses.
keywords: port javascript, porting JavaScript and TypeScript, JavaScript and TypeScript to Jac
---
# Porting JavaScript and TypeScript

`neojac port` translates a JavaScript or TypeScript source file into a Jac module that behaves
as the file does on a `node` space, or refuses it ([port](../toolchain/port.md)). This page is
the mapping: each construct port translates and the Jac it becomes. It is printed from the table
the translation itself reads (`neojac port --mapping javascript`).

The pinned TypeScript reads the file, a JavaScript file too, and gives every expression its
type. Port keeps those types, and writes Jac's own operator only where they say it does what
JavaScript's does: `+` of two numbers is an addition and of two strings a concatenation. Of
anything else it is JavaScript's own operator, a function of `js` (`js_add`), which converts
an operand as JavaScript does.

| JavaScript and TypeScript | Jac |
|---|---|
| `const x = 1;` at the top, of a literal, before any other code | `glob x: float = 1.0;` |
| Any other statement at the top | A statement of the module's one `with entry { }` |
| `function f(a: number, b = 2, c?: string): number { }` | `def f(a: float, b: float = 2.0, c: str \| None = None) -> float { }` |
| `(a: number) => a + 1`, `function (a) { }`, `async (a) => { }` | `lambda (a: float) -> float { return a + 1.0; }`; a function in a function is a closure in both; one made in a loop that uses the pass's `const` variables takes them as its own, `(lambda (k: str) -> any { return lambda -> str { return k; }; })(k)`, as each pass has its own |
| `const f = (a) => { };`, `const f = function (a) { };` at the top | `def f(a: any) { }` |
| A parameter of untyped JavaScript, `function f(a) { }` | `def f(a: any = None) { }`: JavaScript passes `undefined` for an argument a call leaves out |
| `function f(this: T, a) { this.x }` outside a class, or one whose body reads `this`; `f.call(o, a)` | `def f(self: T, a: any) { self.x }`, its `self` the object JavaScript calls it on (`any` where nothing types `this`); `f(o, a)` |
| `class C { x: number; constructor(x) { this.x = x; } m() { } }`; `class D extends C { y = 1; constructor() { super(2); } }` of the file's `C`; `class E extends Error { constructor(m) { check(m); super(m); this.c = 1; } }` of a JavaScript class; `static n = 0;`, `static f() { }`; `get p() { }`, `set p(v) { }`; no constructor | `obj C { has x: float; def init(x: float) { self.x = x; } def m { } }`; `obj D(C) { has y: float; def init { super.init(2.0); self.y = 1.0; } }`, `super.m()`; `obj E(globalThis.Error) { def init(m: any) { check(m); super.init(m); self.c = 1.0; } }`, a class JavaScript makes, whose `init` is its constructor and `super.init(...)` its `super(...)`; `static has n: float = 0.0;`, `static def f { }`; `has p: T { getter { } setter(v: T) { } }`; `def init(*args: any) { }`, which takes what a call gives as JavaScript's does |
| `let x = v;`, `const x: T = v;`, `let x;` | `x: T = v;`, with the type TypeScript gives `x`; `let x;` is `x: any = None;` |
| `import.meta`; a CommonJS module's `__filename`, `__dirname`, `require.main === module`; `new.target`; `F.prototype` of a function used as a constructor | `js_meta()` of `js`, `import.meta` of the module on a JS host; `js_meta().filename`, `js_meta().dirname`, `js_meta().main`; `new.target` is `js_new_target()` of `js`, the `new.target` of the call that reached the function: a function's, and a constructor's of a class JavaScript makes; `F.prototype` is `js_prototype(F)` of `js`, the prototype of the function's JavaScript face, which JavaScript's `new` constructs with |
| `require(spec)` in a function, or after the file's code has started, of a package, a Node addon or a path the program computes; `require` as a value | `createRequire(js_meta().url)(spec)`, `import from "node:module" { createRequire }`: Node's own `require` of the module |
| `if (c) { } else if (d) { } else { }`, `while (c) { }`, of a boolean | `if c { } elif d { } else { }`, `while c { }` |
| `switch (s) { case "a": f(); break; default: g(); }`, of string literals, or of number or boolean literals where TypeScript types `s` so | `switch s { case "a": f(); break; default: g(); }`: Jac's falls through as JavaScript's does |
| `for (let i = 0; i < n; i++) { }` | `for i = 0.0 while i < n with i += 1.0 { }` |
| `for (const x of xs) { }`, `for (const [k, v] of Object.entries(o)) { }`, `for await (const x of g) { }` | `for x in xs { }`; of any other value `for x in js_iter(v) { }`, JavaScript's iterator of it (a Map's entries); a pattern is taken apart first in the body, as a declaration's is; `for await` is `async for x in g { }`, which takes a Jac async generator and JavaScript's async iterable |
| `for (const k in o) { }` | `for k in js_for_in(o) { }`: the keys JavaScript visits, as it visits them |
| `return v;`, `break;`, `continue;` | The same |
| `3`, `2.5`, `0xff` | `3.0`, `2.5`, `255.0`: a number is a float |
| `"a"`, `'a'`, `` `a${s}b` `` of strings | `"a"`, `"a" + s + "b"` |
| `null`, `x === null`, `x == null` | `JsNull`, `x is JsNull`, `(x is None or x is JsNull)`, of `import from js { JsNull }` |
| `if (x)`, `!x`, `a \|\| b`, `a && b` of values that are not booleans; `o[k]`, `o[k] = v` but of an array's literal index | `if js_truthy(x)`, `not js_truthy(x)`, `(a if js_truthy(a) else b)`, `(b if js_truthy(a) else a)`; `js_item(o, k)`, `js_set_item(o, k, v);`, of `js` |
| `catch (e) { use(e); }`; Node's `process`, `Buffer`, `setImmediate`, `setTimeout` | `except BaseException as caught { e: any = js_error(caught); use(e); }`; imported from `node:process`, `node:buffer`, `node:timers` |
| `true`, `false`, `undefined`, `this` | `True`, `False`, `None`, `self` |
| `a + b`, `a - b`, `a * b`, `a ** b` of numbers; `s + t` of strings | The same operators |
| `{ a: 1, "b": 2, 3: 4 }`, of any type, a table's (`Record<string, number>`, an index signature) too; `d[k]`, `d[k] = v;` of a table | `globalThis.Object.fromEntries([("a", 1.0), ("b", 2.0), (globalThis.String(3.0), 4.0)])`, JavaScript's own object, a number as a key the string JavaScript makes of it; `js_item(d, k)`, `js_set_item(d, k, v);`, of `js` |
| An object literal's method: `{ m(x) { return this.n + x; } }`, `*m() { }`, `async m() { }`, `[k]() { }` of a key that reads a name or a property | `def m_1(self: any, x: any) -> any { return self.n + x; }` before the statement and `("m", js_as_method(m_1, "m"))` of `js` in the object's entries: the object is `self`, and JavaScript cannot construct the method; a generator `def`, an `async def`; `(k, js_as_method(method_1, k))` |
| Any other object literal: `{ a: 1, b, [k]: v, ...o }` | `globalThis.Object.assign(globalThis.Object.fromEntries([("a", 1.0), ("b", b), (k, v)]), o)`: JavaScript's own object |
| `o.p` where `o`'s type declares `p`; where it declares it optional; where `o` is untyped, and `o.m(a)` | `o.p`; `getattr(o, "p", None)`; `js_item(o, "p")` and `js_method(o, "m", a)`, JavaScript's read and call, a TypeError of `null` |
| `const { a, b: c = 1, ...rest } = o;`, `const [x, y] = xs;`, `function f({ a }) { }` | `a = getattr(o, "a", None);` (`js_item(o, "a")` of an untyped `o`), `c = 1.0 if got is None else got;`, `rest = js_rest(o, ["a", "b"]);`, `x = xs[0] if len(xs) > 0 else None;`; a parameter's pattern is taken apart first in the body |
| `f(...xs)`, `[...xs, 1]`, `function f(...xs: number[]) { }`; `[...v]` of a value that is not an array | `f(*xs)`, `[*xs, 1.0]`, `def f(*xs: float) { }`; `[*js_iter(v)]` |
| A global of JavaScript's own libraries: `JSON`, `Object`, `String`, `Number` | `globalThis.JSON`, `globalThis.Object`, ... |
| The types `number`, `string`, `boolean`, `T[]`, a class, `T \| undefined` | `float`, `str`, `bool`, `list[T]`, the class, `T \| None`; anything else is `any`, a table (`Record<string, T>`) too, which is JavaScript's object |
| `a / b` of numbers | `a / b` where `b` is a literal other than 0; else `(a / b) if b != 0.0 else a * (float("-inf") if Object.is(b, -0.0) else float("inf"))`, since Jac raises where JavaScript gives an infinity |
| `a < b`, `<=`, `>`, `>=` of numbers; `===`, `!==` of two numbers, strings or booleans | `a < b`, `<=`, `>`, `>=`; `==`, `!=` |
| `a + b`, `a - b`, `a < b`, `<=`, `>`, `>=`, `x += v`, `x -= v`, `+a` of operands TypeScript does not type as the operator's own; `a === "s"` of an untyped `a`; `a % b`, `a << b`, `>>`, `>>>`, `&`, `\|`, `^` of any operands; a compound assignment or `++`/`--` of a property or an index | `js_add(a, b)`, `js_sub(a, b)`, `js_mul(a, b)`, `js_div(a, b)`, `js_pow(a, b)`, `x = js_inc(x);` for `x++;`, `x = js_dec(x);`, `js_lt(a, b)`, `js_le`, `js_gt`, `js_ge`, `x = js_add(x, v);`, `x = js_sub(x, v);`, `js_number(a)`; `js_same(a, "s")`; `js_mod(a, b)`, `js_shl`, `js_shr`, `js_ushr`, `js_band`, `js_bor`, `js_bxor`; `js_set_item(o, "p", js_inc(js_item(o, "p")));` for `o.p++;`, `js_set_item(o, k, js_mod(js_item(o, k), v));` for `o[k] %= v;` (the object and the key held first where they are more than names), of `js`: JavaScript's own operators |
| `===`, `!==` of two objects or arrays; `x === undefined` | `is`, `is not`; `x is None` |
| `!c`, `c && d`, `c \\|\\| d` of booleans; `c ? a : b`; `-a` | `not c`, `c and d`, `c or d`; `a if c else b`; `-a` |
| `x = v;`, `x += v;`, `x -= v;`, `x *= v;`, `x++;`, `x--;` as statements | `x = v;`, `x += v;`, `x -= v;`, `x *= v;`, `x += 1.0;`, `x -= 1.0;` |
| `f(a)`, `o.m(a)`, `new C(a)`, `o.x` | `f(a)`, `o.m(a)`, `C(a)`, `o.x` |
| `console.log(a, b)`, `Math.sqrt(x)`, `Math.PI` | The same, on JavaScript's own `console` (`import from "node:console" { default as console }`) and `Math` |
| `[a, b]`, `xs[0]`, `xs.length`, `xs.push(v);` | `[a, b]`, `(xs[0] if len(xs) > 0 else None)` (`xs[0] = v;` assigned), `float(len(xs))`, `xs.append(v);` |
| Any other method of an array or a string, `xs.join(", ")`, `s.split("")`; a string's `length` | `js_method(xs, "join", ", ")`, `js_method(s, "split", "")`, `js_item(s, "length")`, of `js`: JavaScript's own method, called on the value |
| `a ?? b`; `o?.x`, `o?.m(a)`, `xs?.[0]` of a value TypeScript types; `f?.(a)` of a name | `a ?? b`; `o?.x`, `o?.m(a)`, `xs?[0]`; `f(a) if f is not None else None` |
| `export default function f() { }`, `export default class C { }`, `export default f;` of a function, class or variable of the file | `default def f { }`, `default obj C { }`: the module's default |
| `<div className="a" {...rest}>text {v}<C x={1} /></div>`, `<></>`; a type `JSX.Element` | The same JSX; `JsxElement`; a function returning one, of one parameter `props`, takes `**props`: its props, as the JSX runtime gives them |
| `` tag`a${x}b` `` of a function the file declares | `tag(["a", "b"], x)`: the parts, then the values |
| `v as T`, `<T>v`, `v!`, `v satisfies T` | `v`: TypeScript erases them |
| `await p`; `async function f() { }`; `async () => { }`; `await p` in a module's code | `await p`; `async def f { }`; an `async def` of its own, declared before the statement that makes it; `await p` in `with entry`, which makes the module's code a coroutine run to its end |
| `function* f() { yield v; yield* xs; }`, a generator's method or function expression; `async function* f() { yield v; }`, and `g.next(v)`, `g.return(v)`, `g.throw(e)` of an async generator | `def f -> Iterator[any] { yield v; yield from xs; }`; a function expression is a `def` of its own, declared before the statement that makes it; an async generator is `async def f -> AsyncIterator[any] { yield v; }`, which is JavaScript's own async generator where it crosses to JavaScript, and its `next` `js_method(js_async_generator(g), "next", v)` |
| `throw new TypeError(m);` | `raise new(globalThis.TypeError, m);` |
| `try { } catch { } finally { }`, and `catch (e)` where the block does not use `e` | `try { } except BaseException { } finally { }` |
| `/a+/g` | `new(globalThis.RegExp, "a+", "g")` |
| `new C(a)` of a class that is not the file's | `new(C, a)` |
| `typeof x === "string"`, `"boolean"`, `"number"`, `"undefined"`, `"function"`, `"object"` | `isinstance(x, str)`, `isinstance(x, bool)`, `(isinstance(x, float) or globalThis.Number.isInteger(x))`, `x is None`, `callable(x)`; of any other name `js_typeof(x) == "object"`, JavaScript's `typeof` |
| `typeof x` but compared with a string literal | `js_typeof(x)` |
| `delete o.p`, `delete o[k]`, in a module or a strict script | `js_delete(o, "p")`, JavaScript's `delete`, of a table's key too |
| `x instanceof C`, `k in o`, `a === b` of values TypeScript does not type, `` `n=${n}` `` of a number | `isinstance(x, C)`, `globalThis.Reflect.has(o, k)`, `a is b`, `"n=" + globalThis.String(n)` |
| `import { a, b as c } from "pkg";`, `import d from "pkg";`, `import * as ns from "pkg";`, `import "pkg";`, `import { f } from "./helper.js";`; `export function f`, `export const x`, `export class C`; `export { f as g };` of a function or class | `import from "pkg" { a, b as c }`, `{ default as d }`, `{ * as ns }`, `import "pkg";`, `import from "./helper.js" { f }` of a file that stays JavaScript, `import from .helper { f }` of a Jac module of the program (one the run ports, or a module a path alias of `tsconfig.json` names, `@/lib/utils`); the declaration, a Jac module's names being its own; `glob g: any = f;` |
| `const fs = require("fs");` at the top; `exports.f = f;`, `exports.f = function () { };` | `import from "fs" { default as fs }`; nothing, `f` is the module's; `def f { }` |
| `module.exports = f;`, `module.exports = function f() { };`, `module.exports = v;` before the file's code | `default def f { }`; `default glob <file's stem>: any = v;`: the module's default, which a `require` of it gives |
| `const x = require("./m");`, `const { a } = require("./m");` of a file ported with it | `import from .m { default as x }` of a module that gives one value; `import from . { m as x }` of one that gives its names, the module whole; `import from .m { a }`; a module whose file's stem is no identifier by its quoted path, `import from "./sqlite-error" { default as x }`, and taken whole it is refused |
| `type T = ...;`, `interface I { }`, `import type`, `export type`, `declare ...`, an overload's signature | Nothing: TypeScript erases them, and a value of such a type is typed as TypeScript resolves it |

## What is refused

Anything not in the table is refused with E4001, and nothing is written for the file. So is a
construct in the table whose Jac would mean something else (E4005):

- **A function made in a loop that uses a `let` variable of the loop's body.** Each pass of a
  JavaScript loop has its own, which the pass may change; a Jac function has one.
- **`yield*` in an async generator.** Jac's async generator has no `yield from`.
- **A getter, a setter or `super` in an object literal.**
- **A variable declared again inside the block of another of its name.** A Jac function has
  one variable of a name. (One a function inside another declares, where the other has a
  variable of its name, is a variable of another name, as a Jac closure shares the variables
  of the functions around it.)
- **A top-level variable that functions use, made by code after the file's other code, or
  from what is made after it.** A Jac global has its value before the module's code runs.
- **A function called before a variable it reads is declared.** Jac declares it after them.
- **A property a method binds that the constructor does not.**
- **A step after `?.` in one chain, and `?.()` of a function that is more than a name.**
- **A call of an async function of the file that is not awaited where it is made.**
- **`delete` in a script that is not strict.** It gives false there where a module throws.

Each construct the table lists keeps its meaning: a property of `undefined` or `null` throws
JavaScript's TypeError, an element past an array's end and a key an object lacks are `undefined`,
and `?.` stops at `null` as well as `undefined`.
