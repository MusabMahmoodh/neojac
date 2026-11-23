---
description: neojac arch, a project's architecture drawn from its archwire.jac - the layers, one layer or module opened, the spaces under each profile; a page that follows the project as it is edited, and the picture as text, SVG, PNG, Mermaid and JSON.
keywords: arch, architecture, diagram, picture, viewer, mermaid, svg, png, architecture diagram
---
# arch

`neojac arch` draws a project's architecture, and draws it from `archwire.jac` and nothing else.
Its [layers](../language/modules-layers.md) are the boxes. Its [wires](../language/modules-wiring.md)
are the arrows, each with the edge rule that admits it at that level of the layers beside it. Nothing in the picture is written
down a second time anywhere, so the picture cannot say something the code does not.

```sh
neojac arch                  # serve the picture as a page
neojac arch --text           # print it on the terminal
neojac arch platform --text  # one layer, opened
```

Run it from anywhere inside a project. For the project of [Layers](../language/modules-layers.md),
`neojac arch platform --text` prints:

```text
platform
What the program stands on.

          ┌─ time ────────────────────┐
          │ Clocks, and nothing else. │
          │                           │
          │ core.clock                │
          └───┬───────────┬───────────┘
              │ Time      │ Clock
              │           └───────────┐
              ▼                       │
┌─ machine ────────────────────────┐  │
│ The machine the program runs on. │  │
│                                  │  │
│ host · posix · shared · win      │  │
└────────────┬─────────────────────┘  │
             │ Machine                │
             └─────────────┐        ┌─┘
                           ▼        ▼
                ┌╌ screen ╌╌╌╌╌╌╌╌╌╌╌╌┐
                ╎ What the user sees. ╎
                ╎                     ╎
                ╎ app.view · main     ╎
                └╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌┘
```

## What is drawn

| In the picture | Where it comes from |
|---|---|
| A box | A layer, with its docstring and what it holds. Opened, a layer's boxes are the layers it holds, or its modules |
| A module's words | The first sentence of the module's own docstring |
| An arrow | The wires between the two boxes' modules, from the provider to the consumer |
| A dotted arrow, its head hollow in `--text` (`▽`) | An arrow whose every wire is [declared](../language/modules-wiring.md#declared-wires---) (`-->`): the consumer is a file in another language, whose own source writes the import. A solid arrow has a wire that is the import (`++>`). In `--json` the arrow's `declared` says which, and each wire's `how` |
| `a JavaScript module`, `a Python module`, `a Rust module`, `a C file`, `a C++ file`, `a C module`, `a Rust crate` in a module's box | The module is a file of the project in that language, a C module, or a crate |
| The words beside an arrow | The edge rule that admits those wires between those two boxes: a wire has [a rule at every level](../language/modules-layers.md#a-rule-at-every-level), and each picture shows its own level's |
| A dashed box | Something outside what is opened: another layer, or what the project imports from outside itself |
| A box across the picture's width | A layer that provides to nearly every other, or takes from nearly every other. It names them in place of an arrow to each |

- **What a project imports from outside itself** is drawn too, by where it comes from: the runtime
  and standard library, npm, Python, C libraries. These imports are written in the modules; the
  picture is read from them.
- **`--view spaces`** draws an app project's [spaces](../apps/archwire.md): each space with its
  host, its entry and how many modules run in it, each app with what it runs and serves, and an
  arrow between two spaces for the wires that cross between them. `--profile <name>` draws them as
  that profile arranges them.

## What it takes

```text
neojac arch [<layer> | <module>] [--mermaid | --json | --text]
neojac arch [<layer> | <module>] --svg <file> | --png <file>
neojac arch --view spaces [--profile <profile>] [<output>]
```

| Argument | The picture |
|---|---|
| none | The project's layers |
| a layer's name | That layer, opened |
| a module's name, as wires write it (`core.clock`) | That module, with everything it takes from and gives to |
| `--view spaces` | The spaces, as the unnamed `graph spaces` block arranges them |
| `--profile <name>` | The spaces, as that profile does |

| Output | What is written |
|---|---|
| none | The picture is served as a page: see [The viewer](#the-viewer) |
| `--text` | The picture, on the terminal |
| `--svg <file>` | The same picture as an SVG. It is the same bytes each time for the same project |
| `--png <file>` | The SVG as the browser [`neojac browse`](browse.md) drives draws it. The first use fetches that browser |
| `--mermaid` | A Mermaid flowchart, for a README, an issue or a pull request, where GitHub draws it |
| `--json` | What the picture is drawn from: each box and what it holds, each arrow with its wires, the names each carries, the rule that admits it at each level of the layers (`levels`), and its file and line |

The layout of `--text`, `--svg` and `--png` is neojac's own, and all three are one layout. Mermaid
lays its flowchart out itself, so it looks different and says the same.

## The whole project is checked

`neojac arch` reads **every** file under `archwire.jac`, whether or not any program loads it,
and every target's files, as [every command does](../language/modules-wiring.md#what-a-command-judges).
So before it draws, it has held the whole project to the wiring's rules:

- a wired name its module never spells, on any target (E1146);
- an import of a project module written where a wire belongs (E1144);
- a module in no layer (E2201);
- an import from outside the project with no rule, where `jac.toml` asks one for each (E2211);
- an edge rule, or a part of one, that nothing uses (E2205, E2206, E2207), an import in a module's
  text included.

**An output option refuses a project whose wiring has errors.** It prints them, writes nothing and
exits with 1: a picture that leaves the terminal is of a project that checks. `--diagnostics json`
prints them as records.

## The viewer

With no output option, `neojac arch` serves the picture and prints where:

```text
The architecture of shop is at http://127.0.0.1:8090/
```

- **A click on a layer or a module opens it.** The line above the picture says where it is, and
  each part of that line goes back.
- **The arrows are listed beside the picture.** A click on one, or on its line, shows its wires:
  the two modules with the wire's own arrow between them (`++>`, or `-->` where the consumer's
  source writes the import), the names that cross, the rules that admit them, from the outermost
  level in, and the line of `archwire.jac` that holds the wire.
- **Layers and Spaces** switch the view, and a project with profiles has a list of them.
- **The code is beside the picture, and goes where the picture is clicked.** A layer opened is
  shown where `archwire.jac` writes it, the whole of it marked; a module opened is its file; an
  arrow is its first wire, and each wire in the list, and each error, is a link to its line. **Code**
  puts the code away and brings it back, and the browser's Back returns to what was shown before.
- **A name in the code is what the language server says of it.** Resting on a name shows what it
  is. A click lists, beside the picture, where it is defined, declared and implemented and every
  place it is used, each a link; a click with Ctrl or Cmd held, or a double click, goes to its
  definition. **Outline** lists what the file declares. Names are colored by what they are, and a
  diagnostic is underlined where it is. When the code is of another module than the picture's,
  **Show ... in the picture** opens that module.
- **The page follows the project.** It asks the server each second whether a file it read has
  changed, and the server reads the project again when one has.
- **A wiring error is drawn where it is.** The viewer does not refuse a project with errors: it
  draws the wire or the box in red and lists each error with its code and its place.
- **The page loads nothing from anywhere else.** Its code is a Jac program, compiled for the
  browser when neojac is built, and it is served from the same address as the picture.

The code view is a client of [the language server](lsp.md): the viewer starts a `neojac lsp` of
its own the first time code is shown, and relays between it and the page. So what a name is said
to be is what an editor is told, and the first answer about a file waits for its program to be
checked, which the code view says while it lasts (`checking main.jac...`). The server also indexes
the project's other programs in the background, as it does for an editor. A file that is not Jac
is shown as it is, with no answers. Only files of the project and of neojac's runtime are shown.

`--listen <address>` says where it serves (`127.0.0.1:8090` when not given; port 0 is any free
port). It serves until it is interrupted. It opens no browser: open the address in one, or have
[`neojac browse`](browse.md) do it.

## For editors

- **`neojac query arch <file>[:<line>]`** prints the JSON of the picture a document is in: a
  module's file gives its module, the line of a `layer` in `archwire.jac` that layer, and anywhere
  else in `archwire.jac` the project.
- **The language server** answers the request `neojac/architecture` the same way, with the text
  the editor holds, saved or not. See [The language server](lsp.md#architecture).

## What the picture does not show

- **The order things run in.** A module that reads what another recorded depends on it, and
  imports nothing from it. Wires are who may name whom, and that is all the picture says.
- **Plans.** A box for something not built has no source to be drawn from.
- **Imports that files in another language write**: a space's `.py`, `.js` and `.ts` files. A
  wire's consumer is a Jac or C module.
