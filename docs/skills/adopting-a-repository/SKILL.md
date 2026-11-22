---
name: adopting-a-repository
description: Use when a repository written in Python, JavaScript, TypeScript, Rust, C or C++ is to become a neojac project as it stands - neojac absorb --check, what it takes and what it leaves as data, the archwire it writes, and each kind of open item with what closes it and what proves it.
---
# Adopting a repository

## When to use this

Use it when a repository that neojac did not make is to become a neojac project: its manifests
held by `jac.toml`, its files wired in `archwire.jac`, and no source file changed.

- Translating its source into Jac comes after, a file at a time: `porting-from-python`, and
  `neojac docs toolchain/port`.
- Adding a package to a project that is already neojac's is `using-npm-packages` or
  `using-python-packages`, not this.

## Before you start

```sh
neojac docs toolchain/packages     # jac.toml's tables, and the section on neojac absorb
neojac docs toolchain/projects     # what a project is, and what is not its source
neojac docs modules-wiring         # wires, and how a file in another language declares one
```

**The tools do the work, and you close the open items.** `neojac absorb` takes every manifest its
own engines read, and writes every wire. Never write a table it could have written, and never
edit `archwire.jac`'s wires by hand: `neojac fmt --fix archwire.jac` writes them from the
sources. What is yours is each fact no manifest states.

Work in a clean checkout, so that `git status` shows exactly what a step changed.

## Steps

1. **Look before anything is written.**

```sh
neojac absorb --check              # for a person
neojac absorb --check --json       # for a program: trees, data, open
```

Read three things in what it prints:

- **The trees.** Each manifest that is the project's, and the table it becomes. If one you
  expected is missing, its ecosystem's own workspace does not name it: fix that in the
  repository's manifest (a root's `workspaces`, `[tool.uv.workspace]`, cargo's `[workspace]`),
  not in `jac.toml`.
- **The data.** Directories whose manifest no workspace names: fixtures, templates. Nothing under
  them becomes a module. If one of them is real source, it is a workspace member the root does
  not list.
- **The open items**, each at its file.

2. **Take it in.**

```sh
neojac absorb
git status --short
```

It writes `jac.toml`, `jac.lock` where a lock neojac's engines read was there, `archwire.jac`, and
the lines of `.gitignore` for the manifests it now writes. Each manifest is the same bytes as
before, so `git diff` on one shows nothing, with two exceptions it tells you of: a
`package.json` whose `pnpm.overrides` it rewrote as npm's (listed under `rewritten`), and one
with a `workspace:` link, which npm is given as a range. If a step fails, every file is as it was.

3. **Read what stands between the archwire and a check that passes.** `absorb` prints the
   diagnostics every command would give and exits 1 when there are any. Each is at a wire or at
   a source's import.

| Diagnostic | Usually means |
|---|---|
| E1145 at a wire, `module 'pkg' has no '_ext'` | The source imports a module no file of the project is: an extension module a build makes. `neojac absorb --record` finds which crate it is linked from and writes `[extensions."pkg/_ext"]`; for one it does not take, write the table (`neojac docs toolchain/packages`, "Extension modules") and absorb again |
| E2224 | Two files of one name and two languages in one directory |
| E1575, E1147 | A wire and a source that disagree: `neojac fmt --fix archwire.jac` |

4. **Close each open item**, one at a time, and check after each.

| Kind | What it is | What closes it today |
|---|---|---|
| `lock` | Another tool's lock (`uv.lock`, `bun.lock`, `pnpm-lock.yaml`) | For `uv.lock`: `neojac install`, which holds pip to its pins and builds from source a pin with no wheel for neojac's CPython. Then `neojac absorb --check`: its `locks` line counts the pins reproduced, and the item names each one that was not, with the version installed. Read the log the install named (`.jac/pins/<name>-<version>.log`) and report why; accept one only when the user agrees, in `jac.toml`'s `[lock.pypi] accept = ["<name>"]`. Keep the file until the item is closed. `bun.lock` and `pnpm-lock.yaml` are not yet closed by neojac: keep them |
| `form` | A manifest form npm does not read and neojac does not rewrite (`pnpm-workspace.yaml`, `pnpm.packageExtensions`) | Do not hand-edit the table to make npm take it: say what you found. `pnpm.overrides` and `workspace:` links are no open item: absorb rewrites the first, and prints what it rewrote, and `jac.toml` keeps the second as written |
| `build` | A program that builds native code (`setup.py`, an in-tree build backend, `binding.gyp`) | For a Python project: `neojac absorb --record`, which runs the build and writes `[extensions."<path>"]` for a module linked from a crate or from C, with the C module's table, and `[wheel."<directory>"]`, what the project's wheel holds. For an npm tree with a `binding.gyp`: `neojac install`, then `neojac absorb --record`, which runs npm's node-gyp and writes each addon the same way, with the C module of every library it links. A record is of the system it runs on. It says what of a build a table cannot hold: leave those programs in place and report what it said |
| `tests` | No manifest says how a Python project's tests are run | Write `[test.pypi."<directory>"]` (below), from the command the repository itself uses: its CI, its `Makefile`, `[tool.cibuildwheel] test-command` |

An item neojac cannot close yet is reported, not worked around. Changing a manifest so that a
tool stops complaining changes what the repository builds.

5. **Say how each tree's tests are run**, and run them. A tree is tested only where `jac.toml`
   names its suite.

```toml
[test.pypi."."]                    # a Python project: its command
command = ["pytest", "tests", "--import-mode=append"]
groups = ["test"]                  # the [dependency-groups] the command needs

[test.npm."."]                     # an npm tree: a script of its package.json
script = "test"

[test.cargo."."]                   # a crate: neojac cargo test
```

```sh
neojac absorb --record             # every Python project: what its wheel holds, [wheel]
neojac install                     # its dependencies, and the groups and extras the table names
neojac test                        # builds the project from the tables, then runs the command
```

- **Record every Python project**, one with no native code too: `neojac build` and
  `neojac test` need its `[wheel."<directory>"]`, and refuse without it (E5167).
- **The suite runs against the build**, not against the package's directory beside the tests,
  which holds no extension module. Where the tests' directory has an `__init__.py`, pytest puts
  the project's directory first on Python's path unless it is told `--import-mode=append` (or
  `importlib`): give it that.
- **What the tests need that no group or extra lists** (tiktoken's `pytest` and `hypothesis`
  are named only in its `[tool.cibuildwheel]`) goes in `[dependencies.pypi]`:
  `neojac install --pypi pytest hypothesis`.
- **An npm tree's addon is built from its recorded tables** before its suite runs: record it
  first (`neojac install`, then `neojac absorb --record`). Leave a script that needs a tool
  neojac does not ship (`bun`, `turbo`) unnamed, and report it.
- **Compare with the repository's own run.** The bar is the same tests passing. A test that
  fails the same way under the repository's own tools on this machine is not yours to fix:
  report it, and deselect it in the command only if the repository's own run does.
- **Programs the tests start** (`sysctl`, `ifconfig`) must be on `PATH` as they are for the
  repository's own run.

6. **Build what it publishes.**

```sh
neojac build                       # dist/<name>-<version>-<tags>.whl
```

`neojac absorb --record` declared, in `archwire.jac`, a `cpython` space that holds each Python
project and a `package` that ships it, named for the project. The wheel holds the files the
repository's own wheel does (`.jac/absorb/*/dist/` has that one, to compare), but for files only
its build backend writes into the metadata directory (setuptools' `top_level.txt`).

7. **Draw it.**

```sh
neojac arch --text
```

## When the repository is to stay on neojac

Only once every step above holds, and only where the maintainers mean neojac to be the build
from now on:

```sh
git rm --cached pyproject.toml Cargo.toml     # the command absorb printed: neojac writes these now
git rm setup.py MANIFEST.in                   # what absorb listed as replaced by the record
```

- **Untrack a manifest; do not delete it.** npm, pip and cargo still read it, and neojac writes
  it again in a fresh clone.
- **Delete a build script only when every system the project is built for is recorded.** A
  record is of one system, and the script is the only description of the others until then.
- **Prove it from a fresh clone** of the commit: `neojac install --frozen`, `neojac build`,
  `neojac test`, with the same tests passing.
- **Say what the repository gives up**: an install from its source by pip or npm, and tools
  that read its manifests without neojac.

## What a correct result looks like

- `neojac absorb --check` and `neojac absorb` name the same trees.
- `git status --short` shows `.gitignore` modified and `jac.toml`, `archwire.jac` (and `jac.lock`)
  new, and nothing else.
- `neojac test` passes the tests the repository's own run passes, for each Python project.
- A second `neojac absorb` prints `nothing changed`.
- `neojac arch --text` draws the project, with one layer, `all`.
- Every open item is either closed, or listed in your report with what the repository says
  about it.

## Mistakes to expect

| Symptom | Means | Fix |
|---|---|---|
| `absorb: ... holds no manifest to take into jac.toml` | No `package.json`, `pyproject.toml`, `Cargo.toml` or `cmodule.toml` in the directory or under it | Run it at the repository's root |
| The tables landed in a `jac.toml` above the repository | A `jac.toml` above it made that directory the project | Run it in a checkout that is under no other project |
| A fixture's files show up as modules | Its directory holds no manifest, so nothing marks it as data | Add it to `[project] exclude` in `jac.toml` |
| E5156 `... is null` | A `package.json` holds a `null`, which TOML has no value for | Take the `null` out of the manifest: npm reads an absent key the same way |
| E5157 | A manifest's text cannot be moved under a table's name as it is | Reformat that part of the manifest as plain tables |
| `cargo cannot read it` | `cargo metadata` refused the `Cargo.toml` | Fix what cargo says: neojac asks cargo which crates are the workspace's |
| After `--record` on macOS: `'IOKit/IOKitLib.h' file not found` at a C module's `cmodule.toml` | The C uses a framework the toolchain carries no headers of | Set `SDKROOT` to a macOS SDK, for every command in the project (`neojac docs interop/c-and-cpp`) |
| `--record` says `no run that was recorded linked it` | The build found the module already made, from before any record was kept | Remove what the build left in the repository (`build/`, `target/`) and record again |
| The suite fails with `cannot import name '_ext' from 'pkg'`, at a path in the repository | Python imported the package's directory, not the build | `--import-mode=append` for pytest; a test that starts `python -m` in the repository needs the build to hold that module |
| E5167 | A Python project has no `[wheel."<directory>"]` | `neojac absorb --record` |
