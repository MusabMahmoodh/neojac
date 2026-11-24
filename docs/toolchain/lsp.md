---
description: neojac lsp, the language server an editor runs - setting an editor up, which program a file is checked in, what the server answers (diagnostics, navigation, hover, completion, rename, formatting, code actions), its settings and commands, and neojac query for the same answers from the command line.
keywords: language server, LSP, editor, IDE, go to definition, find references, hover, completion, rename, code action, quick fix, semantic tokens, inlay hints, neojac query, neojac.lint, neojac.index
---
# lsp and query

`neojac lsp` is a language server: an editor starts it and speaks the [Language Server Protocol](https://microsoft.github.io/language-server-protocol/) to it on stdin and stdout. It checks the programs the open files belong to as they are edited, with what is unsaved, and answers the editor from what the checks found. Nothing it answers is worked out apart from the compiler: a diagnostic is what `neojac check` reports, and a definition is what the checker resolved the name to.

`neojac query` asks the same questions from the command line ([below](#query)).

## Setting an editor up

The server takes no argument and no option. Any editor with a Language Server Protocol client runs it as `neojac lsp` for files ending in `.jac`, with the project's directory as the workspace folder.

Neovim (0.11 or later):

```lua
vim.filetype.add({ extension = { jac = "jac" } })
vim.lsp.config("neojac", {
  cmd = { "neojac", "lsp" },
  filetypes = { "jac" },
  root_markers = { "jac.toml", "archwire.jac", ".git" },
})
vim.lsp.enable("neojac")
```

Helix (`languages.toml`):

```toml
[language-server.neojac]
command = "neojac"
args = ["lsp"]

[[language]]
name = "jac"
scope = "source.jac"
file-types = ["jac"]
roots = ["jac.toml", "archwire.jac"]
language-servers = ["neojac"]
```

Emacs (eglot):

```text
(add-to-list 'eglot-server-programs '(jac-mode . ("neojac" "lsp")))
```

VS Code runs a language server through an extension. A minimal one passes `{ command: "neojac", args: ["lsp"] }` as the server options of `vscode-languageclient`, with `{ scheme: "file", language: "jac" }` as its document selector.

The server writes nothing but the protocol on stdout. What a tool it runs prints (a C compiler, cargo) goes to stderr.

## Which program a file is checked in

A Jac file is checked as part of a program, and the server picks the program:

| The file | Its program |
|---|---|
| A module | The module as its own program: it and what it imports, as `neojac check <module>` checks it |
| A module of the runtime that is no program itself (`rt/core.jac`) | The largest program the server knows that holds it |
| An impl annex (`impl/x.impl.jac`) or a test annex (`x.test.jac`) | Its module's. A test annex is checked with its module as the main module, so its tests are checked |
| A module of a project whose `archwire.jac` declares spaces | The program of the space that places it, on that space's host (as `neojac check --space <space>`) |
| A target variant (`x.windows.jac`) | The variant as the main module of its own program, checked for its target (as `neojac check --target`) |
| `archwire.jac` | A program it governs |

A module is checked as its own program so that an edit to it costs a check of what it imports, and not of everything that imports it. What only a larger program can say of the module comes in two ways:

- **Its uses.** References, rename, implementations, and the call and type hierarchies are answered from the largest program the server knows that holds the module. That program is checked when one of them is asked for, and the index answers for the programs beyond it.
- **Its diagnostics.** What the check of a larger program finds in the file comes from the index, of the file as saved.

The server has every program of the workspace folders indexed once: each main module nothing else reaches, leaving out what `jac.toml`'s `[check] exclude` leaves out, and each space of an archwire that declares spaces. The index of a program is its files, its diagnostics, the names it declares and a table of its references. It is what makes references, rename and workspace symbols reach files that are not open, and what tells the server that the program of `main.jac` holds `core/clock.jac`.

- **Each program is indexed by a process of its own,** a [`neojac query index`](#query) the server starts, as many at a time as half the machine's processors. The server goes on answering meanwhile, and what a process checked is given back when it ends.
- **What a process found is kept in the [build cache](cache.md),** with the size and time of every file the program read. A server started again takes each index whose files are as they were, and runs nothing for it.
- **The index is of what is saved.** A program is indexed again when a file of it changes on disk. A document being edited is answered from the check of its own program, and what the index says of that file is left out until it is saved.
- **The main modules and the spaces go first,** and the other files after them, so that a file a program already holds is not indexed as a program of its own.

- **The server checks names and types, as the text is typed.** Its own check of a program reads every module and settles every declaration, with the documents as the editor holds them, and checks the bodies of functions as they are needed: the function a hover or a definition is asked in, at once; the other bodies of the open documents when the server is next idle, or when another answer needs them; those of another file when an answer needs them (a reference into it, a parameter of one of its functions). That is what hover, completion, navigation and the diagnostics of syntax, names and types are answered from.
- **The later phases are found of the program as it is saved.** Ownership, what a place provides, the lint rules and the other whole-program judgments are the full check's, which the process that indexes a program runs. Their diagnostics are published when that process ends: after a file is opened, and again each time one is saved. While a document differs from its saved file, the saved file's findings are not shown for it.
- **An edit inside function bodies is answered from the check the server holds.** When what changed in a file is the bodies of its functions and nothing else, the file is read again, the bodies that changed are put in place of the old ones and checked, and the rest of the program stands: tens of milliseconds, whatever the program's size. An edit that changes a declaration, an import, or a body the compiler runs or copies (a `comptime` function, a generic one, a kernel) is a check of the program again.
- **A check gives way to typing.** A check is abandoned when a newer edit arrives, and starts again once the edits pause (150 ms by default).
- **The server is two processes, and a third that waits.** The one an editor starts keeps the documents, the workspace's index and every file of the checked program parsed and untouched. It forks a second, which checks the program and answers; a fork shares the first's memory until it writes to it, so the second starts with those trees at no cost and changes only its own copy. When it is idle it forks a standby as well: a process that reads, declares and settles everything the module last edited imports, and then waits.
- **An edit that needs the program checked again is taken by the standby.** It has what the module imports settled already, so it parses the module's own files again and checks them: the edit costs the module, not the program. The process that answered before ends, and the memory of its check goes with it: there is no pause while it is freed. A request that was waiting is asked again of the new one, and a standby that is called leaves another waiting in its place.
- **Where no standby fits, a process is forked that checks the program from the start.** That is the first edit to a module, a module of a space, an edit made after a file the standby read has changed, and a module that has to be settled together with what it imports (such as one that gives another module's declaration its body, declares a class with several bases, imports Python, or imports a C++ module or a Rust crate). Nothing is read or parsed again but the files that changed.
- **When a check stands that the edit did not touch, or a command the server started is still running,** the program is checked again in the same process instead, and the superseded check is freed when the server is idle (0.4 s after the last message; when two wait, before the next check). On Windows, where a process is not forked, this is every edit.
- **A check keeps going past errors.** `neojac check` stops at the first phase that finds errors; the server reports every phase's, so a syntax error in one file does not hide a type error in another. Inside a statement the parser had to skip, only the syntax error is reported.
- **A check runs what a build's check runs.** A program with C or Rust modules has them compiled the first time, from the [build cache](cache.md) afterwards.
- **At most four checked programs are kept** in memory, the least recently used let go first.

## What it answers

| Request | Answer |
|---|---|
| Diagnostics, pushed or pulled, for a document and for the workspace | Every error and warning, in every file of a checked program, with its code linked to its page of the reference: those of syntax, names and types as the text is typed, those of the later phases as the file is saved |
| Definition | Where the name is defined: for a declaration with an `impl`, the `impl` |
| Declaration | The declaration itself: the `def` in the module |
| Implementation | A function's `impl`; the overrides below a method; the subclasses of a class; for a walker, `spawn` or `visit`, the abilities that fire; for a node or an edge, the abilities it triggers |
| Type definition | The class of what is at the cursor |
| References, document highlights | Every use, in every program of the workspace |
| Document symbols, workspace symbols | A file's outline; the declarations of every program |
| Call hierarchy, type hierarchy | Callers and callees; supertypes and subtypes |
| Hover | The kind, the signature or type, a constant's value, the docstring and what a `sem` says; for a keyword or operator, its page of the documentation; for any other expression, its type |
| Signature help | The function or class being called, and the parameter the cursor is at |
| Completion | After `.`: the members of the receiver's type, a module's names, a class's statics and enum members. Elsewhere: the locals in scope, the module's names, the builtins, and the keywords the grammar takes there. After two letters, what other modules declare: accepting one adds its wire or its import |
| Rename | Every use, in every program; a method is renamed with its overrides |
| Formatting | The document, a range, or the statement just typed, as `neojac fmt` lays it out |
| Semantic tokens | What each name is: a class, a parameter, a field, a method, a module, and whether it is declared, written or the library's |
| Inlay hints | The type of a local bound without one; the parameter a positional argument is bound to |
| Folding and selection ranges | The brackets, comment runs, strings and imports; each enclosing piece of syntax |
| Document links | An import's module |
| Code lens | `Run test` over a `test`, `Run` over `with entry` |
| Renaming a file | A module renamed where it is has its imports, its wires and rules in `archwire.jac`, and its annexes and tests renamed with it |

A name from a C module, a Rust module, a Python package or an npm package resolves to the interface neojac made of it, not to the header or the source it was read from.

### Architecture

The server answers one request that is not the protocol's own, `neojac/architecture`, and says so in its capabilities: `experimental.architectureProvider` is `true`. It is what [`neojac arch`](arch.md) draws, for the document an editor is in.

| Parameter | Meaning |
|---|---|
| `textDocument.uri` | The document. A module's file asks for that module; `archwire.jac` for its project |
| `position.line` | In `archwire.jac`, the line of a `layer` asks for that layer, opened. Not needed otherwise |
| `view` | `layers` (the default) or `spaces` |
| `profile` | With `spaces`, the profile that arranges them |

The answer is `null` for a file no `archwire.jac` governs, and otherwise an object:

| Member | Holds |
|---|---|
| `picture` | What `neojac arch --json` prints: the boxes, the arrows with their wires, and the wiring's errors |
| `svg` | The picture, as `neojac arch --svg` writes it. Each box is a `<g>` with a `data-id` and each arrow one with a `data-key`, so a panel can tell what was clicked |

It is drawn from the text the editor holds, saved or not, so a panel that asks again after each edit follows the project.

### Code actions

| For | Action |
|---|---|
| An unknown name (W2001) | Wire it from the module that declares it, into the wire `archwire.jac` already has for that provider and consumer or a new one in the block they share; where no archwire governs the module, import it |
| A crossing no edge rule admits (E2099) | Add the rule the message names |
| An import written in a governed module (E1144, E2094) | Move it into `archwire.jac` |
| A name a wire binds and nothing uses (E1146) | Remove it from the wire |
| A lint diagnostic, or `source.fixAll` | Apply what `neojac fmt --fix` does to the module and its annexes |
| A declaration with no `impl` | Write the `impl` into the module's annex |
| The leading imports, or `source.organizeImports` | Put them in order |

## Settings

The server reads the `neojac` section of the editor's settings, through `workspace/configuration` and `workspace/didChangeConfiguration`, and the same keys from `initializationOptions`:

| Key | Default | Meaning |
|---|---|---|
| `lint` | `true` | Check the lint rules `jac.toml` selects |
| `index` | `true` | Check the programs of the workspace that are not open |
| `programs` | `4` | How many checked programs are kept in memory |
| `settle` | `150` | Milliseconds without an edit before a check starts |

## Commands

`workspace/executeCommand` runs:

| Command | Arguments | Does |
|---|---|---|
| `neojac.test` | The file | `neojac test <file>` in the workspace folder, in the background; its output is logged and its result shown when it ends |
| `neojac.run` | The file | `neojac run <file>`, the same way |
| `neojac.bring` | The file, a name, the module that declares it | Wires or imports the name, through `workspace/applyEdit` |

## query

```sh
neojac query <what> <file>[:<line>[:<column>]]
neojac query index <program> [--no-lint]
```

`neojac query` checks the file as the server does, in the program it belongs to, and prints one answer. Lines and columns count from 1. It is for scripts and for agents that have no editor.

| `<what>` | Prints |
|---|---|
| `definition`, `declaration`, `implementation`, `type`, `references` | Places, one to a line: `<file>:<line>:<column>-<line>:<column>` |
| `hover` | What hover shows, as Markdown |
| `symbols` | The file's outline |
| `completion` | What completion offers there, a label and its detail to a line |
| `signature` | The signature being called and the parameter at the cursor |
| `diagnostics` | The diagnostics of the file's program |
| `arch` | The JSON of the architecture picture the document is in ([arch](arch.md)): a module's file gives its module, the line of a `layer` in `archwire.jac` that layer, anywhere else there the project |
| `index` | The JSON of a whole program's index, as the server keeps it. The program is its main module, or `archwire.jac#<space>` for a space |

A program's index holds:

| Member | What it is |
|---|---|
| `main` | The program |
| `stamps` | Every file the program read, with its size and time: the index stands while they do |
| `files`, `owned` | The files of the program, and those of them that are its own |
| `found` | Each file's diagnostics |
| `names` | What a reference can be to, each as `<kind>:<file>:<line>:<column>` of its declaration |
| `paths`, `at` | The references: seven lists of one length, a reference's file (a place in `paths`), line, column, length, role (0 a read, 1 a write, 2 a declaration, 3 an impl), what it is to and what it is within (places in `names`, -1 for nothing) |
| `named` | The declarations: name, kind, detail, file, line, column |

`--no-lint` leaves the project's lint rules out, as a server whose `lint` setting is off asks.

```sh
neojac query definition main.jac:12:9
neojac query references core/clock.jac:3:5
neojac query symbols main.jac
```
