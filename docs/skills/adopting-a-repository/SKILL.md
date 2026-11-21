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
before: `git diff` on one shows nothing. If a step fails, every file is as it was.

3. **Read what stands between the archwire and a check that passes.** `absorb` prints the
   diagnostics every command would give and exits 1 when there are any. Each is at a wire or at
   a source's import.

| Diagnostic | Usually means |
|---|---|
| E1145 at a wire, `module 'pkg' has no '_ext'` | The source imports a module no file of the project is: an extension module a build makes. It is the `build` open item's |
| E2224 | Two files of one name and two languages in one directory |
| E1575, E1147 | A wire and a source that disagree: `neojac fmt --fix archwire.jac` |

4. **Close each open item**, one at a time, and check after each.

| Kind | What it is | What closes it today |
|---|---|---|
| `lock` | Another tool's lock (`uv.lock`, `bun.lock`, `pnpm-lock.yaml`) | Not yet closed by neojac. Keep the file: its pins are what an install has to land on |
| `form` | A manifest form npm does not read (`workspace:` links, `pnpm.*`, `pnpm-workspace.yaml`) | Not yet rewritten by neojac. Do not hand-edit the table to make npm take it: say what you found |
| `build` | A program that builds native code (`setup.py`, `binding.gyp`) | Not yet recorded by neojac. Leave the program in place |
| `tests` | No manifest says how a Python project's tests are run | Find the command the repository itself uses: its CI, its `Makefile`, `[tool.cibuildwheel] test-command`. Report it; `jac.toml` has no key for it yet |

An item neojac cannot close yet is reported, not worked around. Changing a manifest so that a
tool stops complaining changes what the repository builds.

5. **Draw it.**

```sh
neojac arch --text
```

## What a correct result looks like

- `neojac absorb --check` and `neojac absorb` name the same trees.
- `git status --short` shows `.gitignore` modified and `jac.toml`, `archwire.jac` (and `jac.lock`)
  new, and nothing else.
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
