---
description: The lint rules every project keeps and those jac.toml's [check.lint] adds, human_mode and projects of fixtures, every rule by name with what it reports and whether neojac fmt --fix applies it, the notes annex that holds what comments and docstrings said, and the spellings and probable mistakes neojac always rejects.
keywords: lint, lint rules, combine-has, combine-glob, simplify-ternary, unnecessary-else-after-return, nested-if-to-elif, simplify-return-bool, unnecessary-none-return, too-many-params, no-print, strip-comments, strip-docstrings, separate-impls, impls-in-annex, precommit, human_mode, notes annex
---
# Lint rules

neojac holds source to rules of three kinds:

| Kind | Reported | Configured |
|---|---|---|
| [Spellings the language rejects](#spellings-neojac-always-rejects): where Jac had two ways to write one thing, neojac accepts one | By `check`, `build`, `run` and `test`, always | No |
| [Probable mistakes](#probable-mistakes): code that cannot be what was meant | By `check`, `build`, `run` and `test`, always | No |
| [The rules](#the-rules): style and policy, `"clean"` in every project | By `check`, `build`, `run` and `test`, in the project's own modules | `jac.toml`'s `[check.lint]` adds rules; only a project written by hand takes any away |

Every finding is an error with a code, like any other diagnostic ([check](check.md)). [`neojac fmt --fix`](#fmt---fix) rewrites most of them.

**Every project is held to `"clean"`, and that is intended.** Jac source carries no comments and
no docstrings, and a module reads as its declarations, with every body in an `impl` in its annex.
What a comment or a docstring would say goes in the module's notes annex, `notes/<module>.md`,
under the declaration it is about ([The notes annex](#the-notes-annex)). `neojac fmt --fix`
applies all of it: it moves the comments and docstrings into the notes annex and the bodies into
the impl annex. The rules are judged by every command that loads a program, so a comment in a
project's module stops its build as a type error does. A project adds rules in `[check.lint]`,
and takes none away unless it is written by hand ([below](#selecting-rules)).

## Selecting rules

```toml
[check.lint]
select = ["no-print"]   # rules added to what the project keeps
```

| Key | Type | Default | Meaning |
|---|---|---|---|
| `select` | list of strings | `[]` | Rules added to what the project keeps: rule names, `"style"` for the style rules, and `"clean"` for every rule but `no-print` and `too-many-params`. In a project of fixtures, the only rules that judge it |
| `ignore` | list of strings | `[]` | Only with `human_mode = true`: rules taken out of what the project keeps. Names and groups, as in `select` |
| `exclude` | list of strings | `[]` | Only with `human_mode = true`: fnmatch patterns of file paths, relative to the project's root, that no rule judges |

- **Every project keeps `"clean"`**, but one [of fixtures](#a-project-of-fixtures): one with no `[check.lint]`, and one whose `select` names other rules. `select` adds to it and never replaces it, so `select = []` adds nothing. Only a project written by hand takes rules out of it ([human_mode](#human_mode)).
- **A program in no project is judged by no rule**: one with no `jac.toml` at or above its main module, which needs no `archwire.jac` either. `fmt --fix` rewrites only its old spellings there.
- What `select` adds is the rules in no group, `no-print` and `too-many-params`: `select = ["no-print"]`. A name in `select` that the project is held to already (`"style"`, `"clean"`, `"strip-comments"`, in a project that is not of fixtures) is error E3058, at its place in `jac.toml`.
- Rules are selected by name, not by code. A name in `select` or `ignore` that is no rule is error E3057, at its place in `jac.toml`.
- A rule's finding is an error at the code it judges, in every command that loads the program: `neojac check`, `neojac build`, `neojac run` and `neojac test`. A finding in a body written in an annex is at the annex's line (`impl/simplify_ternary.impl.jac:2:13`), not at the declaration.
- **`neojac fmt --fix` moves every comment and docstring** of the files the rules judge into their module's notes annex, since `strip-comments` and `strip-docstrings` are among the rules every project keeps, and moves every body into its module's impl annex.
- **A module of a `cpython` space keeps its docstrings and its `-> None`.** There a docstring is
  the program's, the `__doc__` Python reads ([Classes and decorators in a cpython space](../interop/python-classes.md#doc-strings)),
  and `-> None` is the function's annotation, `f.__annotations__["return"]`, so neither
  `strip-docstrings` nor `unnecessary-none-return` judges it, in `neojac check` or in
  `neojac fmt --fix`, which reads the project's spaces to know. Its comments and bodies are judged as any module's. Its
  `import from __future__ { annotations }` is Python's too, and stays.

```text
jac.toml:5:23: error[E3057]: [check.lint] select names 'no-such-rule', which is no rule a project selects
 5 | select = ["no-print", "no-such-rule"]
   |                       ^

1 error
`neojac docs E3057` explains an error by its code.
```

```text
jac.toml:5:11: error[E3058]: [check.lint] select names 'style', which the project is held to already: `select` adds a rule to those it keeps
 5 | select = ["style", "no-print"]
   |           ^

1 error
`neojac docs E3058` explains an error by its code.
```

### human_mode

```toml
[project]
name = "notebook"
human_mode = true

[check.lint]
ignore = ["strip-comments", "strip-docstrings"]
exclude = ["drafts/*"]
```

`human_mode = true` under `[project]` says the project is written by hand. It is the one
permission to choose among the rules. By itself it changes nothing: it makes `ignore` and
`exclude` legal, and a project that says it is still held to every rule it does not name there.
`ignore = ["clean"]` takes every rule of `"clean"` out.

Without it, `ignore` and `exclude` are error E3059, each at its line of `jac.toml`. A project
`shop` whose `[check.lint]` holds `exclude = ["drafts/*"]` alone gets:

```text
jac.toml:5:1: error[E3059]: [check.lint] exclude takes rules off a project's source, which only a project written by hand may: one whose jac.toml says `human_mode = true` under [project]
 5 | exclude = ["drafts/*"]
   | ^

1 error
`neojac docs E3059` explains an error by its code.
```

`human_mode` is a statement about who writes the project, and the person who writes it by hand is
the one who makes it. A project whose code a tool or an agent writes does not say it, and keeps
the rules whole.

### A project of fixtures

```toml
[project]
name = "corpus"
kind = "fixtures"

[check.lint]
select = ["style"]
```

`kind = "fixtures"` under `[project]` says the project's programs are written to exercise a
compiler: a compiler's test corpus, programs that must fail to compile. No rule judges a project
of fixtures unless its `select` names rules, and there `select` is the whole of them: under
`select = ["style"]`, the style rules judge it and no others. It needs no `archwire.jac`
([Projects](projects.md#a-project-of-fixtures)), and no project declares it as a package.

A project is not made one of fixtures to be rid of the rules: its programs are a compiler's tests,
not a program anyone runs.

## The rules

| Rule | Code | Reports | Group | `fmt --fix` |
|---|---|---|---|---|
| `combine-has` | W3002 | A `has` right after one with the same modifiers, which it belongs in | `style`, `clean` | yes |
| `combine-glob` | W3003 | The same of a `glob` | `style`, `clean` | yes |
| `simplify-ternary` | W3008 | `a if a else b`, which is `a or b` | `style`, `clean` | yes |
| `unnecessary-else-after-return` | W3021 | An `else` after a body that ends in `return` or `raise` | `style`, `clean` | yes |
| `nested-if-to-elif` | W3022 | An `else` holding only an `if` | `style`, `clean` | yes |
| `simplify-return-bool` | W3023 | An `if` whose branches return `True` and `False` | `style`, `clean` | yes |
| `unnecessary-none-return` | W3037 | `-> None` on a function that returns no value | `style`, `clean` | yes |
| `too-many-params` | W3030 | A signature with more than 7 parameters | none | no |
| `no-print` | E3012 | A call of the builtin `print` | none | no |
| `strip-comments` | W3050 | Every comment | `clean` | yes: moves it to notes |
| `strip-docstrings` | W3051 | Every docstring, and every string written as a statement | `clean` | yes: moves it to notes |
| `separate-impls` | W3055 | A body written inline that an `impl` could hold | `clean` | yes: moves it |
| `impls-in-annex` | W3056 | An `impl` in its module, or an annex beside its module instead of in `impl/` | `clean` | yes: moves it |

`style` is the style rules. `clean` is `style` and the policies for a project's layout and its comments: no comment, no docstring, every body in an `impl` in its module's annex. `fmt --fix` applies each rule of both, so the rules a project keeps never leave work the fixer cannot do. The two rules in no group need their author, and are added by name: a project that says `select = ["no-print", "too-many-params"]` is held to every rule.

neojac's own `jac.toml` has no `[check.lint]` table, so its compiler, its runtime and its toolchain's build are held to `"clean"`, as every project is: their source holds no comment or docstring, what their comments said is in each module's notes annex, and every body is in an impl annex.

### The style group, in one program

This program compiles and runs. In the project of fixtures [above](#a-project-of-fixtures), which `select = ["style"]` holds to the style rules alone, `neojac check` reports seven findings in it; in any other project the policies of `"clean"` report its inline bodies too:

```jac
glob width: int = 1;
glob height: int = 2;

obj Point {
    has x: int = 0;
    has y: int = 0;
}

def pick(a: int, b: int) -> int {
    return a if a else b;
}

def sign(n: int) -> int {
    if n < 0 {
        return -1;
    } else {
        return 1;
    }
}

def grade(score: int) -> str {
    if score > 90 {
        print("high");
    } else {
        if score > 50 {
            print("middle");
        }
    }
    return str(score);
}

def positive(n: int) -> bool {
    if n > 0 {
        return True;
    } else {
        return False;
    }
}

def log(msg: str) -> None {
    print(msg);
}

with entry {
    log(grade(pick(0, 95) + sign(3) + width + height + Point().y));
    print(positive(1));
}
```

```output
high
99
True
```

```text
style.jac:2:1: error[W3003]: a `glob` after one with the same modifiers belongs in it: `glob a = 1, b = 2;` [combine-glob]
style.jac:6:5: error[W3002]: a `has` after one with the same modifiers belongs in it: `has a: A, b: B;` [combine-has]
style.jac:10:12: error[W3008]: 'a if a else b' is 'a or b' [simplify-ternary]
style.jac:16:7: error[W3021]: the `else` after a body that ends in `return` is unnecessary [unnecessary-else-after-return]
style.jac:24:7: error[W3022]: an `else` holding only an `if` is an `elif` [nested-if-to-elif]
style.jac:33:5: error[W3023]: an `if` whose branches return True and False returns its condition [simplify-return-bool]
style.jac:40:22: error[W3037]: '-> None' on 'log' is unnecessary: a function that declares no return type returns None [unnecessary-none-return]
7 errors
`neojac docs W3003` explains an error by its code.
```

(Each diagnostic also shows its source line; they are left out here.) The message of a rule's finding ends with the rule's name in brackets. `neojac fmt --fix style.jac` rewrites the file to:

```jac
glob width: int = 1,
     height: int = 2;

obj Point {
    has x: int = 0,
        y: int = 0;
}

def pick(a: int, b: int) -> int {
    return a or b;
}

def sign(n: int) -> int {
    if n < 0 {
        return -1;
    }
    return 1;
}

def grade(score: int) -> str {
    if score > 90 {
        print("high");
    } elif score > 50 {
        print("middle");
    }
    return str(score);
}

def positive(n: int) -> bool {
    return n > 0;
}

def log(msg: str) {
    print(msg);
}

with entry {
    log(grade(pick(0, 95) + sign(3) + width + height + Point().y));
    print(positive(1));
}
```

```output
high
99
True
```

The fixer rewrites a block after the blocks inside it, so one run reaches what a fix inside makes
fixable: where an inner `if`'s `else` after a `return` is dropped, and the inner `if` then ends in
`return` too, the outer `else` is dropped in the same run.

```jac
def k(v: int) -> int {
    if v > 1 {
        if v > 2 {
            return 2;
        }
        return 1;
    }
    return 0;
}
```

That is what `--fix` makes of `k` written with an `else` after each `return`.

### What each rule judges

| Rule | Detail |
|---|---|
| `combine-has`, `combine-glob` | A statement joins the one directly before it when both have the same modifiers (access tag, `static`), neither has a docstring and neither has accessors. A comment between them does not keep them apart. A blank line does: it starts a group of its own, which stays one |
| `simplify-ternary` | Only where writing `a` twice runs nothing twice: `a` is a name, a chain of plain attributes from a name (`b.v`), or a literal. `f() if f() else b` is left alone |
| `unnecessary-else-after-return` | The final `else` of a plain `if`. An `if`/`elif` chain is left alone |
| `nested-if-to-elif` | After an `if` or at the end of an `elif` chain. A loop's `else` is not one |
| `simplify-return-bool` | An `if` with one `else`, each branch a single `return` of `True` or `False`. Reported instead of `unnecessary-else-after-return`, which would also fit |
| `unnecessary-none-return` | Functions, methods and lambdas, in a declaration whose `impl` holds the body too. A body with `return None;` says it differently and is left alone; a nested function's `return` is its own |
| `too-many-params` | Functions and lambdas; `self` is not counted. A function declared in `import from c { ... }` has the signature its library gives it and is not judged |
| `no-print` | Only the builtin. A method named `print`, or a local bound to the name, is something else |
| `strip-docstrings` | A module's, a global's, an archetype's, a field's, an enum's and a test's docstring |
| `separate-impls` | A function's, a method's and an ability's body. An accessor's body stays with its property, and a nested function's with the function around it. A `by` function (`def f(...) -> T by e;`) has no body to move: the one it runs is the compiler's |
| `impls-in-annex` | An `impl` written in a module's own file, and an annex file `<module>.impl.jac` sitting beside its module instead of in `impl/` |

### Layout policies

`separate-impls` and `impls-in-annex` together keep every body out of a module's own file: the module declares, and `impl/<module>.impl.jac` implements. `fmt --fix` moves each body into that annex, creating it when it is not there. The comments inside a body go to the module's notes annex ([below](#the-notes-annex)), or, in a project written by hand that keeps its comments, with the body. See [Projects](projects.md#impl-annexes) for where annexes go.

A function declared in a branch of a [`comptime if`](../language/compile-time.md#among-declarations-and-members), at a module's top or among a class's members, keeps its declaration in that branch, and its body moves into the annex under the same branches, with the `jaclang.comptime` import their conditions read:

<!-- example: not checked: shows a module and the annex fmt --fix writes for it -->
```jac
import from jaclang.comptime { target }

comptime if target().os == "windows" {
    def sep -> str;
} else {
    def sep -> str;
}
```

<!-- example: not checked: the annex impl/main.impl.jac of the module above -->
```jac
import from jaclang.comptime { target }

comptime if target().os == "windows" {
    impl sep -> str {
        return "\\";
    }
} else {
    impl sep -> str {
        return "/";
    }
}
```

### The notes annex

`strip-comments` and `strip-docstrings` keep prose out of a module's source. What a comment or a
docstring would say goes in the module's notes annex, `notes/<module>.md`, beside `impl/`:
Markdown, written by a person or by `fmt --fix`, and read by people. Nothing in the compiler
reads it.

- It opens with a title line, `# <module>`, and the module's own notes: its docstring, and a comment set apart from any declaration by a blank line.
- Each declaration a note is about has a heading, `## <declaration>`, in dotted form: `## Cart` for a class, `## Cart.add` for a method, `## Cart.owner` for a field, `## TTL` for a global, `## with entry` for an entry block, `## test adds` for `test "adds"`.
- A comment directly above a declaration, one at the end of its line and one inside its body all go under that declaration, each a paragraph with its `#` taken off. A line that would start with `#` is written `\#`, so that Markdown does not read it as a heading. A string written as a statement in a body goes there too.
- A module has one notes file, and its annexes' comments go to it: an impl annex's under the declaration each `impl` is of, and a test annex's (`cart.test.jac` beside the module or in `test/`) under `## test <name>`.
- A notes file that is there already is merged into: what `fmt --fix` moves is added under its declaration's heading, and a heading the file does not have is added at its end.

A module of the project `shop`, `cart.jac`:

```jac
"""A shopping cart, and what it costs."""

# Prices are in cents, so no sum is rounded.

# How long a cart is kept, in seconds.
glob TTL: int = 3600;

obj Cart {
    has owner: str,  # the account's name
        items: list[int] = [];

    """Add one item at its price."""
    def add(price: int) {
        # A price of 0 is a gift, and is still counted.
        self.items.append(price);
    }
}

with entry {
    c = Cart(owner="ada");
    c.add(250);
    print(len(c.items), TTL);
}
```

`neojac check cart.jac` reports seven findings (each diagnostic's source line is left out here):

```text
cart.jac:1:1: error[W3051]: a docstring: what is said of a declaration goes in the module's notes annex, notes/<module>.md, not in the source, by design; `neojac fmt --fix` moves it there [strip-docstrings]
cart.jac:3:1: error[W3050]: a comment: Jac source carries none, by design; what it says goes in the module's notes annex, notes/<module>.md, under the declaration it is about; `neojac fmt --fix` moves it there [strip-comments]
cart.jac:5:1: error[W3050]: a comment: Jac source carries none, by design; what it says goes in the module's notes annex, notes/<module>.md, under the declaration it is about; `neojac fmt --fix` moves it there [strip-comments]
cart.jac:9:22: error[W3050]: a comment: Jac source carries none, by design; what it says goes in the module's notes annex, notes/<module>.md, under the declaration it is about; `neojac fmt --fix` moves it there [strip-comments]
cart.jac:12:5: error[W3051]: a docstring: what is said of a declaration goes in the module's notes annex, notes/<module>.md, not in the source, by design; `neojac fmt --fix` moves it there [strip-docstrings]
cart.jac:13:5: error[W3055]: the body of 'add' belongs in an impl: a module reads as its declarations, by design; `neojac fmt --fix` moves the body to the module's impl annex [separate-impls]
cart.jac:14:9: error[W3050]: a comment: Jac source carries none, by design; what it says goes in the module's notes annex, notes/<module>.md, under the declaration it is about; `neojac fmt --fix` moves it there [strip-comments]
7 errors
`neojac docs W3051` explains an error by its code.
```

`neojac fmt --fix --check .` lists the files `--fix` would write:

```text
cart.jac
impl/cart.impl.jac
notes/cart.md
```

`neojac fmt --fix .` leaves `cart.jac` as its declarations:

<!-- example: not checked: the module after fmt --fix, whose body is in the annex below -->
```jac
glob TTL: int = 3600;

obj Cart {
    has owner: str,
        items: list[int] = [];
    def add(price: int);
}

with entry {
    c = Cart(owner="ada");
    c.add(250);
    print(len(c.items), TTL);
}
```

`impl/cart.impl.jac` with the body:

<!-- example: not checked: the annex impl/cart.impl.jac of the module above -->
```jac
impl Cart.add(price: int) {
    self.items.append(price);
}
```

and `notes/cart.md` with what the comments and docstrings said:

```text
# cart

A shopping cart, and what it costs.

Prices are in cents, so no sum is rounded.

## TTL

How long a cart is kept, in seconds.

## Cart.owner

the account's name

## Cart.add

Add one item at its price.

A price of 0 is a gift, and is still counted.
```

## Spellings neojac always rejects

These are errors in every program, with no configuration. `fmt --fix` rewrites every one of them.

| Written | Write | Code |
|---|---|---|
| `def __init__`, `def __post_init__` | `def init`, `def postinit` | W3004 |
| `def f()`, `lambda () ...`, `obj A()`, `enum E()` | No parentheses when there is nothing in them | W3005 |
| `import from __future__ { annotations }`, outside a cpython space | Nothing | W3009 |
| An `impl` that restates its declaration's signature differently | The declaration's signature | W3010 |
| A `;` standing for nothing (stray, after accessors, after a for step) | No `;` | W3013 |
| `@staticmethod` | `static def` | W3001 |
| `@property` | `has x: T { getter { ... } }` | W3043 |
| `hasattr(x, "a") and x.a ...`, where `x`'s class has `a` | `x is not None and ...` | W3007 |
| `getattr(x, "a", None)`, where `x`'s class has `a` | `x?.a` | W3039 |
| `case (a, b):` | `case [a, b]:` | E0155 |
| `sem x is "..."` | `sem x = "...";` | E0156 |
| A backtick on a name that needs none, as on the attribute in ``obj.`type`` | The bare name | E0157 |
| `async static def` | `static async def`. Modifiers come in the order `comptime override static\|class async def` | E0158 |
| `def f -> int { e }`: a body's last expression as its value | `return e;` | E0159 |
| A block's last expression statement without `;` | With `;` | E2084 |
| `lambda (x: int) { x * 3; }`: a lambda of one expression that only computes a value | `lambda (x: int) { x * 3 }` | E0160 |
| `x = (yield v);`, `(yield v);`, `f"{(yield v)}"` | `x = yield v;`, `yield v;`, `f"{yield v}"` | E0161 |
| `R"..."`, `B"..."`, `br"..."` | `r"..."`, `b"..."`, `rb"..."` | E0162 |
| `0XFF`, `0B1`, `0O7`, `1E3` | `0xFF`, `0b1`, `0o7`, `1e3` | E0163 |
| `visit x`, `sem x = "..."` or an item of a `graph {}` block, without `;` | With `;` | E0002 |
| An enum member, the last included, or a filter's type (`[?:T x == 1]`), without `,` | With `,` | E0002 |

```jac
# expect: W3009, W3005 x5, W3013
import from __future__ { annotations }

obj Account() {
    has owner: str = "",
        balance: int = 0;

    def __post_init__() {
        self.balance += 0;
    }

    @staticmethod
    def bank() -> str {
        return "First";
    }

    @property
    def rich() -> bool {
        return self.balance > 100;
    }
}

with entry {
    a = Account(owner="ada", balance=200);
    print(a.owner, Account.bank(), a.rich);
    f = lambda () -> int { return 1; };
    print(f());;
}
```

Seven are reported at once, because they are all found while the file is read. The rest of this file's old spellings (`__post_init__`, `@staticmethod`, `@property`) are judged in a later phase and would be reported once these are gone ([check](check.md#the-order-errors-are-reported-in)). One run of `neojac fmt --fix` rewrites all ten:

```jac
obj Account {
    has owner: str = "",
        balance: int = 0;

    def postinit {
        self.balance += 0;
    }

    static def bank -> str {
        return "First";
    }

    has rich: bool {
        getter {
            return self.balance > 100;
        }
    }
}

with entry {
    a = Account(owner="ada", balance=200);
    print(a.owner, Account.bank(), a.rich);
    f = lambda -> int { return 1; };
    print(f());
}
```

```output
ada First True
1
```

A function also has one body. An `impl` of a function that was written with its own body is E2016, and a second `impl` of one function is E2017. Neither has a fix.

## Probable mistakes

Where the reference design warns about a likely mistake, neojac refuses it, each where it cannot be anything else:

| Written | Why it is refused | Code |
|---|---|---|
| `x is 1`, `x is not "a"` | `is` compares identity. Compare a value with a literal with `==` or `!=` | W3035 |
| An `if`/`elif` chain repeating a condition that only reads | Nothing run between the two could change its answer, so the second branch never runs | W3024 |
| An `if` whose branches are the same | The condition decides nothing | W3025 |
| The same name on both sides of a filter's comparison: `tasks[?:Task, owner == owner]` | The left name is the item's field and the right one is the name in scope, a mistake whichever was meant | W3040 |

```jac
# expect: W3035, W3024, W3025
def f(x: int) -> int {
    if x is 1 {
        return 1;
    } elif x > 2 {
        return 2;
    } elif x > 2 {
        return 3;
    }
    if x > 0 {
        return 5;
    } else {
        return 5;
    }
}

with entry {
    print(f(1));
}
```

These have no fix: what was meant is the author's to say.

## fmt --fix

```sh
neojac fmt --fix .            # rewrite, then format
neojac fmt --fix --check .    # list what would change; write nothing
```

`neojac fmt --fix <path>...` rewrites what can be rewritten, then formats ([fmt](fmt.md)):

- every old spelling in the table above, in every project;
- of the rules the file's project keeps, all but `too-many-params` and `no-print`.

How it works:

- A module and its annexes are fixed together. A body or an `impl` moves into `impl/<module>.impl.jac`, and a comment or a docstring into `notes/<module>.md`, under the declaration it is about ([The notes annex](#the-notes-annex)).
- Nothing is written until every file the run would write parses. A file that does not parse is reported and nothing of its module is changed.
- An `impl` whose signature differs from its declaration's gets the declaration's signature, when both name the same parameters. One naming other parameters is left for its author.
- The `hasattr` and `getattr` fixes (W3007, W3039) depend on types, so they are made only once the program has no other errors: run `fmt --fix` again after the first run has cleared the rest.
- The probable mistakes are never rewritten.

After `--fix`, run `neojac check` to see what is left for you.

## `neojac precommit`

```sh
neojac precommit                 # fix, format and check the staged .jac files
neojac precommit --verify        # change nothing: fail when a file is not as the fixer leaves it
neojac precommit --all           # the whole project in place of the staged files
neojac precommit --install       # git's hooks, once in a clone
```

`neojac precommit` is `fmt --fix` and `check` together, for a commit:

- It runs `neojac fmt --fix` on the `.jac` files staged (a module with its annexes), then checks each module as `neojac check` does, under the rules its project keeps.
- It exits with status 1 when a check fails, when `--verify` finds a file to fix, or when it rewrote a staged file, which is then to stage again.
- `--verify` refuses a staged file that has changes that are not staged: what would be committed is not what is on disk.
- `--install` writes git's `pre-commit` hook, which runs `neojac precommit --verify`, and a `commit-msg` hook that refuses a commit naming an AI as its author. A hook neojac did not install is kept unless `--force`, which saves it as a `.bak` file.

A module is checked as a program of its own. One that is no program is fixed and not checked, and precommit says how many:

| Not checked | Why | What checks it |
|---|---|---|
| Another target's variant (`host.windows.jac` on Linux) | The check is of this machine's target | `neojac check <main.jac> --target <platform>` |
| A file `jac.toml`'s `[check] exclude` names | The project says so: a fixture that must fail, say | The project's tests |

A module's untagged file names the module. On a machine the module has a file of its own for (`host.linux.jac` beside `host.jac`, on Linux), that file is what is checked, once.

A file of a project whose `archwire.jac` declares spaces is checked in its project, whose apps are its programs: precommit runs `neojac check` there once, however many of its files are staged ([Checking a project](check.md#checking-a-project)).

`[check] exclude` is read from the `jac.toml` of the project precommit runs in, and from the file's own project where that is another:

```toml
[check]
exclude = ["tests/*"]   # fnmatch patterns of file paths, relative to the project's root
```

neojac's own names `tests/*`: the suites check the tests' programs.

One of the runtime's own modules is checked as any module is. Named as a program it is the module neojac loads into every program, so its check is of the runtime it is part of.

## Which files the rules judge

The rules judge the project's own modules as their author wrote them:

- modules under the project's root (the directory of the `jac.toml`), but not what `[check.lint] exclude` names in a project that says `human_mode = true`;
- the runtime's modules only where the runtime stands in the project's own tree, as neojac's does: an installed toolchain's are outside it, and belong to the toolchain;
- not the modules of a library or a plugin the project declares, which are their package's own wherever its directory is: one installed in the project's `eco/jac/`, or one declared by a directory inside the project's tree;
- not code the compiler writes into a module.

A program outside any project (no `jac.toml` at or above its main module) is judged by no rule, in every command, and `fmt --fix` rewrites only its old spellings. A project of fixtures is judged only by the rules its `select` names.
