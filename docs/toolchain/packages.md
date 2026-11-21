---
description: A project's packages and manifests from every ecosystem in jac.toml and jac.lock - Jac packages ([packages]), libraries and plugins alike, by a version, a directory or a repository, the installed packages of eco/jac and what a version requirement means, what a library is and what it may not hold, npm trees ([npm."<dir>"]), each the package.json of its directory, written where it stands, Rust crates ([cargo."<dir>"]), C modules ([c."<dir>"]) and Python projects ([pypi."<dir>"]) written where they stand, PyPI packages, neojac install, remove, absorb, npm and cargo, what is tracked, and what is refused.
keywords: packages, [packages], libraries, Jac library, Jac package, version, version requirement, installed package, jac.lock, eco, eco/jac, npm tree, package.json, package-lock.json, node_modules, install, remove, absorb, frozen, Cargo.lock
---
# Packages

A project says which packages it takes, from every ecosystem, in `jac.toml`, and `jac.lock` records
exactly what was installed. The files another ecosystem's tools read (`package.json`,
`package-lock.json`) are not written by hand and not tracked: neojac writes them from `jac.toml`
and `jac.lock` before it runs a tool, and takes back what the tool changed as it ends.

| Ecosystem | In `jac.toml` | In `jac.lock` | Installed in |
|---|---|---|---|
| Jac | `[packages]`, each package by its version or by where it is | `[jac.<name>]`, for each installed one, whoever installed it | `eco/jac/<name>`, for one declared by a version or a repository |
| npm | `[npm."<directory>"]`, one for each tree of packages | `[npm."<directory>"]` | `<directory>/node_modules` |
| PyPI | `[dependencies.pypi]`, and what each Python project below depends on | `[pypi]` | `.jac/venv` ([Python](../interop/python.md#pypi-packages)) |
| Rust | `[cargo."<directory>"]`, a crate's or a workspace's `Cargo.toml` | `[cargo."<directory>"]`, its `Cargo.lock` | nothing: cargo builds from the crate's directory |
| C and C++ | `[c."<directory>"]`, a C module's `cmodule.toml` | | nothing |
| A Python project | `[pypi."<directory>"]`, its `pyproject.toml` | | nothing of its own: what it depends on is in `.jac/venv` |

```sh
neojac install                        # everything jac.toml lists
neojac install --frozen               # exactly what jac.lock pins, as on a fresh clone
```

## Jac packages

A Jac package is a directory with a `jac.toml` and its modules. It is one of two kinds, which its
own `jac.toml` says, and never both ([Principles](../language/principles.md)):

| | Library | Plugin |
|---|---|---|
| Its `jac.toml` says | `kind = "library"` | `kind = "plugin"`, and what it fills ([Plugins](../apps/plugins.md#writing-a-plugin)) |
| It is declared in `[packages]` by | Each package whose modules import it | The project that binds it, and no other package |
| It is named by | A module's `import` | A binding in `jac.toml`, never an import |
| It may declare | Libraries | Libraries |

A package declares each package it uses in its `[packages]`: by its version, a string, or by
where it is, a table that names a directory or a repository at a revision. The table does not say
which kind a package is: the package's own `jac.toml` does.

```toml
[project]
name = "shop"

[packages]
grid = "1.2"
shapes = { path = "../shapes" }
units = { git = "https://example.com/units.git", rev = "v1.2.0" }
```

| A declaration | Means | The package is |
|---|---|---|
| `"1.2"` | Version 1.2.0 or later, below 2.0.0 ([Versions](#versions)) | [Installed](#installed-packages) in the project's `eco/jac/<name>` |
| `{ path = "..." }` | The package in that directory, from the directory of this `jac.toml` | Used where it is |
| `{ git = "...", rev = "..." }` | The package at that revision of a repository | [Fetched](#fetching-and-pinning) by `neojac install` into `eco/jac/<name>` |

and its modules import the library's under its name:

<!-- example: not checked: needs the library beside the project -->
```jac
import shapes;
import from shapes.area { square }

with entry {
    print(square(3), shapes.NAME);
}
```

The library is a project like any other, published as it stands:

```toml
# ../shapes/jac.toml
[project]
name = "shapes"
kind = "library"
version = "0.1.0"

[packages]
units = { git = "https://example.com/units.git", rev = "v1.2.0" }

[dependencies.pypi]
numpy = ">=2"
```

- **A package's `version` is three numbers,** `MAJOR.MINOR.PATCH`, as
  [Semantic Versioning](https://semver.org) has it, with an optional pre-release (`1.3.0-rc.1`).
  One that is written and is not that is E2228.
- **A package may say the oldest neojac it builds with,** `neojac = "0.4"` in its `[project]`.
  It is a least version and no more: no author knows which later neojac will break a package. A
  release of neojac older than that refuses the package where it says so (E2229). A neojac built
  from source is no release, and refuses none.
- **`shapes.area` is `area.jac` in the library's directory,** and `import shapes;` its
  `__init__.jac`. Inside the library, its modules import each other as a project's do: by the
  wires of the library's own `archwire.jac`, or, in a library that says `archwire = false`, by a
  relative import (`import from .names { label }`) or from the library's root.
- **A module imports the libraries its own package declares.** `shapes` uses `units`, so `shapes`
  declares it. A module of the project that imports `units` is E2219 until the project declares it
  too: what a dependency brought is not the project's to use by accident.
- **A program holds one copy of a package.** Where the project declares `units`, the copy is the
  one the project names, and otherwise the one the first package to declare it names. Every other
  declaration of `units` has to hold of that copy, or the build is refused (E2220): a version
  requirement of its version, and a place by being the same place. A class belongs to its module,
  so two copies would be two types.
- **A library depends on no plugin.** Its `[packages]` declares none and its `jac.toml` binds no
  abstraction (E2221), and none of its modules imports one (E2218). It uses the language's
  abstractions (`root`, `by llm()`), and the project that uses it says what carries them out.
- **A library's name is its own.** A directory or a module of the project named as a declared
  library is E2222: an import would name either.
- **A plugin declares libraries the same way,** in its own `[packages]`, and no plugin: only a
  project declares one (E2221), and a plugin it declares is one it binds or lists (E2227,
  [Plugins](../apps/plugins.md#binding-a-plugin)).
- **A plugin's modules import its abstraction's contract, `common.contract`, the libraries it
  declares and the standard library,** and nothing else of neojac's: no module of stdjac, and no
  other abstraction's contract (E2233). A library a plugin declares is held to the same, with
  `common.contract` the one contract it imports
  ([Plugins](../apps/plugins.md#what-a-plugin-imports)). neojac's own library `sqlfile`, which its
  `sqlite` and `accounts` plugins declare by its place in neojac's tree, is such a library.
- **No package declares an abstraction** (E2217). The abstractions are neojac's own, each a directory
  of its `abstractions/` ([Plugins](../apps/plugins.md#the-abstractions)).
- **`[libraries]` and `[plugins]` are no tables of a `jac.toml`** (E2226): a package's packages
  are in `[packages]`.

### Versions

- **A requirement is the least version asked for:** `"1"`, `"1.2"` or `"1.2.3"`. It is satisfied
  by that version and every later one in which its left-most number that is not zero is
  unchanged:

  | Requirement | Satisfied by |
  |---|---|
  | `"1.2"`, `"1.2.0"` | 1.2.0 or later, below 2.0.0 |
  | `"1"` | 1.0.0 or later, below 2.0.0 |
  | `"0.4"` | 0.4.0 or later, below 0.5.0 |
  | `"0.0.3"` | 0.0.3 alone |

- **There is no other form:** no range, no exact version, no exclusion (E2228). An exact version
  is what a lock pins. A release that breaks its users and has to live beside the one before it
  takes a new name (`shapes2`), since a program holds one copy of a name.
- **A pre-release** (`1.3.0-rc.1`) satisfies only a requirement that names a pre-release of the
  same version (`"1.3.0-rc.1"`).
- **A package asked for by version states one.** One whose `jac.toml` has no `version` satisfies
  no requirement.

neojac says what a version and a requirement are because the compiler checks one against the
other. It does not choose a version: that is a package manager's work.

### Installed packages

A package declared by its version is an installed one. The compiler finds it in the project's
`eco/jac/<name>`, a directory holding the package's files with its `jac.toml` at the top, and
does not ask how it came to be there: a package manager is a program of its own, which puts
packages in that directory ([Writing a package manager](package-managers.md)).

- **The directory is the project's:** the one being built. A package's own requirements are found
  there too, never in the package's directory. So one directory holds one version of each name,
  libraries and plugins alike.
- **It may be a link** to a directory a package manager keeps elsewhere. The compiler reads
  through it, and writes nothing in it.
- **Beside it is a record of what installed it,** `eco/jac/<name>.json`:

  ```json
  { "format": 1, "installer": "jacpm", "from": { "registry": "https://packages.example.org" } }
  ```

  `installer` is the name of the program that put the package there, `from` is that program's
  own, which neojac does not read, and `format` is the record's format, 1. An installed package
  with no record is refused (E5163), and so is a record of another format (E5164): a package
  someone keeps by hand is declared by `path`.
- **An installer touches only the packages whose record names it.** `neojac install` leaves
  another's packages and records as they are, and does not fetch over one (E5165).
- **Nothing is machine-wide:** no directory outside the project is searched, and no environment
  variable adds one.
- **What is not there is said where it was asked for** (E5161), with what was asked and by which
  package, and so is a copy whose version does not satisfy a declaration (E2220).
- **A project builds against its own checkout of a package** by declaring it by `path`. The
  project's declaration decides the copy the whole program holds, so an installed package that
  asks for `units = "0.3"` uses the project's `units = { path = "../units" }`, whose version has
  to satisfy that.

### Fetching and pinning

A package declared by its directory is used where it is. One declared by a repository is fetched by
`neojac install`:

```text
$ neojac install
neojac install: the library units at 6c8f55b32d8a in eco/jac/units
```

- **It is fetched into `eco/jac/<name>`,** which is not tracked: `neojac install` adds `eco/jac/`
  to the project's `.gitignore`. neojac is the installer of what it fetches, and records it as
  any installer does: `eco/jac/<name>.json` names `neojac`, and its `from` holds the repository,
  the revision asked for and the commit. A build that finds it missing, or fetched for another `git` or
  `rev` than `jac.toml` now has, is E5161, and `neojac install` is the fix.
- **`jac.lock` pins the commit,** as it pins every installed package ([below](#the-lock)). A `rev`
  that is a branch is pinned at the commit it named when it was first fetched, and stays there
  until `jac.toml` asks for another `rev`.
- **`neojac install --frozen`** fetches exactly the commits `jac.lock` pins, and fails for a package
  it pins nothing for, or whose files are not the ones it pinned.
- **Every package the project's packages declare is fetched too,** each once, into the same
  directory.

### The lock

`jac.lock` holds one entry for each installed package the program needs, whoever installed it. A
package declared by its directory has none.

```toml
[jac.grid]
version = "1.4.0"
digest = "sha256:9f2c5a0f6f1d7c1f3f0f8a4a1c6c4a0d6f6b6f0c3a8a3c1e7b2d5e9f4a1b0c3d"
installer = "jacpm"

[jac.grid.from]
registry = "https://packages.example.org"

[jac.units]
version = "0.1.0"
digest = "sha256:ebe3029117f00a21e55d5167bcfea5d77279d74f1eb847daf0195c67eca3aecd"
installer = "neojac"

[jac.units.from]
git = "https://example.com/units.git"
rev = "v1.2.0"
commit = "6c8f55b32d8a611f0d288e5035357a17934bfd9b"
```

- **`neojac install` is the one writer of `jac.lock`.** It pins each installed package from what
  is in `eco/jac/` and from the record beside it: the package's `version`, its `installer`, the
  installer's `from`, and a `digest` of its files. A package manager reads the entries that name
  it, to install exactly what they pin.
- **The digest is SHA-256,** and any program can compute it. For each file of the package, a line:
  its path from the package's directory, with `/` between its parts, a zero byte, the SHA-256 of
  the file's bytes in hexadecimal, and a newline. The digest is `sha256:` and the SHA-256 of
  those lines, in the order of their paths. A link to a directory inside a package is not
  followed.
- **`neojac install` pins a package again** when its version or its `from` changed. It refuses
  one whose files changed under the same version from the same place (E5166): that is not the
  package that was pinned.
- **A declared package that is not installed stops it** (E5161): it names every one, with who
  asks for it and for what.
- **`neojac install --frozen` writes nothing.** Every package the program needs is installed and
  pinned, and its version, its record and its files are what is pinned, or it stops (E5166),
  naming the package and what installed it.
- **What nothing declares any more is no longer pinned.** neojac removes the package if it
  fetched it, and leaves another installer's where it is.
- **On a fresh clone,** the project's package manager installs what `jac.lock` pins for it, and
  `neojac install --frozen` fetches neojac's own and verifies them all.
- **The lock's format is 2.** A lock of another format is E5164.

### What a project's packages are: neojac packages

```text
$ neojac packages
grid 1.4.0: a library, found, in eco/jac/grid, which 'jacpm' installed
    the project asks for version 1.2 or later, below 2.0.0
cells: a package, missing, in eco/jac/cells
    the library 'grid' asks for version 0.3 or later, below 0.4.0: not met

Interfaces: auth 1, bundler 1, jobs 1, limits 1, llm 1, schedule 1, store 1, transport 1, ui 1

eco/jac/grid/jac.toml:7:1: error[E5161]: the package 'cells' is not installed as the library 'grid' asks, version 0.3 or later, below 0.4.0: nothing is at 'eco/jac/cells'
```

- **It prints the project's Jac packages as the compiler finds them:** each one's name, version
  and kind (and what a plugin fills), where its copy is and what installed it, every package that
  asks for it and for what, and whether it is found, missing, or wrong.
- **Then the version of each abstraction's interface** in this neojac, which is what a plugin's
  `interface_ver` has to be ([Plugins](../apps/plugins.md#the-abstractions)), and every problem
  with its place in a `jac.toml`: the ones `neojac check` reports.
- **It reads and changes nothing:** it fetches no package, writes no lock, hashes no file.
- **It exits 1 when a package is missing or a check fails,** so a script can ask whether a
  project's packages are installed.
- **`--json` prints the same as one document,** for a program to read
  ([Writing a package manager](package-managers.md#neojac-packages---json)).

### What a package needs of npm and PyPI

A library or a plugin says what it needs of other ecosystems as a project does, and
`neojac install` installs it with the project's own:

- **Its `[dependencies.pypi]`** is resolved together with the project's, into the project's
  `.jac/venv`, and pinned in `jac.lock`'s `[pypi]`.
- **The `dependencies` of its `[npm."<directory>"]` tables** are written into every npm tree of
  the project, with the tree's own. Two askers of one npm package agree on its range (E5162).
- **Neither is written into the project's `jac.toml`.** What `neojac npm` takes back from a tree is
  the project's own packages.

## npm trees

An npm tree is one package and the packages it depends on: one `package.json`, one lock, one
`node_modules`, in one directory. A tree is named by that directory, from the project's root with
`/` between its parts (`.` is the root itself), and `jac.toml`'s `[npm."<directory>"]` table is the
`package.json` there, key for key, with npm's own names for its keys:

```toml
[npm."eco/web"]
private = true
type = "module"

[npm."eco/web".dependencies]
nanoid = "^5.1.0"
lodash = "^4.17.21"

[npm."eco/web".devDependencies]
"@types/lodash" = "^4.17.0"
```

```sh
neojac install --npm nanoid lodash --tree eco/web    # add packages, making the tree if it is new
neojac remove --npm lodash                           # take one out
```

`--tree` names the tree's directory, as a path from where the command is run. A project's only
tree needs no naming.

A tree may be any directory of the project. One made for a Jac project's own pages is by
convention `eco/<name>`, beside the project's modules and apart from them. One taken in from a
repository that already had a `package.json` is wherever that file stands, its sources beside it:
`[npm."frontend"]`, or `[npm."."]` for a package at the root.

### Workspaces

A tree whose `package.json` has `workspaces` is a workspace: several packages installed as one.
Its root is a tree, and so is each member, a table for each:

```toml
[npm."."]
name = "shop"
private = true
workspaces = ["frontend", "packages/*"]

[npm."frontend"]
name = "frontend"

[npm."frontend".dependencies]
emails = "*"

[npm."packages/emails"]
name = "emails"
```

- **Which directories are members is npm's own answer.** neojac asks the workspace mapper npm
  itself uses, which reads the root's `workspaces` and finds the `package.json` files it reaches.
  A `package.json` it does not reach (a test fixture, a template) is no tree, and none is made
  of it.
- **A workspace has one lock,** the root's, and `jac.lock` holds it under the root's name. A
  member has none.
- **It is installed as one.** `neojac install` runs npm at the root, once, and prints the
  members with it. A space that names a member (`npm = "frontend"`) finds its packages as Node
  does, from the member's directory upward, and is built only when the workspace is installed as
  `jac.toml` and `jac.lock` say (E5160).
- **`neojac npm` in a member's directory** is npm run in that workspace. What it writes to any of
  the workspace's `package.json` files, and to the root's lock, is taken back.
- **Every member is a table.** A member npm finds that `jac.toml` holds none for is E5159:
  `neojac absorb` of the root's directory takes each in.
- **An app's artifact does not carry a member's packages yet.** An app whose node space runs on a
  member's tree is refused (E5090).

### Which tree a space's imports use

A project with one tree uses it everywhere: for every space, and for a program of no space. A
project with several says which is each space's, in `jac.toml`:

```toml
[spaces.site]
npm = "eco/web"

[spaces.phone]
npm = "eco/mobile"
```

A space naming a tree `jac.toml` does not declare is E1287, and a module importing from npm where
nothing says which of several trees is its own is E1288.

## A tree's directory

A tree's directory is where its tools run. Here the tree is `eco/web`:

```text
shop/
    jac.toml
    jac.lock
    main.jac
    eco/
        web/
            vite.config.ts        yours, tracked
            index.html            yours, tracked
            package.json          written by neojac from jac.toml
            package-lock.json     written by neojac from jac.lock
            node_modules/         installed by neojac install
            .jac/                 the tree's spaces, compiled
```

- **What you write there** is what a tool's own configuration is written in, and any file of
  yours that imports the tree's packages: a bundler's configuration, `tsconfig.json`,
  `index.html`, a stylesheet that imports a package. A tool finds a file's packages by looking in
  the directories above the file, so such a file is under its tree.
- **What neojac writes there** is not tracked. The first time it writes a tree it adds the three
  to the project's `.gitignore`, by their paths from the root:

  ```text
  /eco/web/package.json
  /eco/web/package-lock.json
  /eco/web/node_modules/
  ```

  `.jac/` is ignored as the project's own is.
- **A JavaScript space is compiled there**, into `<directory>/.jac/build`, so that its modules
  find the tree's packages and its `tsconfig.json` as any file of the tree does.
- **`eco/` is not the project's source**: a file under it is in no layer of `archwire.jac`
  ([Projects](projects.md#what-is-not-the-projects-source)). A tree anywhere else stands among
  the project's files, and its JavaScript and TypeScript are modules of the project.

## Rust crates, C modules and Python projects

A crate's `Cargo.toml`, the `Cargo.lock` beside it, a [C module](../interop/c-modules.md)'s
`cmodule.toml` and a Python project's `pyproject.toml` are tables of `jac.toml` and `jac.lock`
too, each named by its directory from the project's root:

```toml
[cargo.adder]
[cargo.adder.package]
name = "adder"
version = "0.1.0"
edition = "2024"

[c.geom]
sources = ["geom.c"]

[c.geom.target.linux]
libs = ["m"]

[pypi.backend]
[pypi.backend.project]
name = "app"
version = "0.1.0"
dependencies = ["fastapi>=0.141"]
```

- **A table is the manifest's own text**, its tables named under the directory's. Comments are
  kept, and the file neojac writes from it is the file that was taken in, byte for byte.
- **The files are written where they stand**, `adder/Cargo.toml` and `geom/cmodule.toml`, not
  under `eco/`: cargo finds a crate's sources, and its workspace, from where its manifest is.
  neojac writes them before any command looks for them, making a directory that holds nothing
  else, and lists each in the project's `.gitignore`.
- **`neojac absorb <directory>`** takes in every `Cargo.toml`, `cmodule.toml` and `pyproject.toml`
  under a directory, into the `jac.toml` of the project each is in. A workspace is a table for
  its root and one for each member.
- **A `pyproject.toml`'s table is the project's manifest as its own tools read it**: its build
  backend's, pytest's, a linter's. `neojac install` installs what it depends on, beside what
  `[dependencies.pypi]` lists ([Python](../interop/python.md#a-python-project-of-the-repository)).
- **`neojac cargo`** writes the project's manifests first, and takes back what cargo changed as it
  ends (`cargo add`, `cargo update`).

A program with no `jac.toml` above it keeps its manifests as files: a loose `main.jac` beside a
`geom/cmodule.toml` builds as it did.

## Extension modules

A Python package's module may be native code that a build makes: tiktoken's `tiktoken._tiktoken`
is a Rust crate, psutil's `psutil._psutil` a C library. No file of the project is that module, so
`jac.toml` says which unit is:

```toml
[extensions."tiktoken/_tiktoken"]
cargo = "."
features = ["python"]
```

- **It is named by the module's path** from the project's root, and names the crate
  (`cargo`, with the `features` it is built with) or the C module (`c`) of the project it is built
  from, by the directory of that unit's table.
- **It is a module of the project.** A file that imports it is wired from it, and until the table
  is there the import names nothing: `neojac absorb` reports it (E1145).
- **`neojac absorb --record` writes the table**, for a module linked from a crate or from C,
  from what the repository's own build does ([Recording a build](#recording-a-build)).
- **neojac does not build one yet.**

## Running npm

`neojac npm` and `neojac npx` run in a tree: the one whose directory they are run in or under
(the nearest, where one tree's directory holds another's), or the project's only tree. neojac writes the tree's `package.json` and lock first, and when npm ends
it takes what npm wrote back into `jac.toml` and `jac.lock`:

```text
$ neojac npm pkg set description="A shop"
neojac: jac.toml took what npm wrote in eco/web
```

Only the tree's table changes. The rest of `jac.toml`, its comments with it, is as it was.

In a directory that is no Jac project (no `jac.toml` in it or above it), `neojac npm` is npm as it
is anywhere, on that directory's own `package.json`.

## Taking in a repository: neojac absorb

`neojac absorb` takes the manifests a repository already has into `jac.toml`, each where it
stands, and writes the project's `archwire.jac`. No source file changes.

```sh
neojac absorb --check          # what this repository is: nothing is written
neojac absorb                  # make it a project
neojac absorb --record         # and run its build, to write what that links
neojac absorb crates           # the manifests under crates/, into the project this directory is in
```

A directory with no `jac.toml` in it or above it becomes a project: `absorb` makes the file.

### Which manifests are the project's

Each ecosystem answers for its own:

| Manifest | Becomes | Its workspaces, asked of |
|---|---|---|
| `package.json`, with its `package-lock.json` | `[npm."<directory>"]` | npm's own workspace mapper ([Workspaces](#workspaces)) |
| `pyproject.toml` | `[pypi."<directory>"]` | The members and exclusions `[tool.uv.workspace]` lists |
| `Cargo.toml`, with its `Cargo.lock` | `[cargo."<directory>"]` | `cargo metadata` |
| `cmodule.toml` | `[c."<directory>"]` | A C module has none |

- **The first manifest of an ecosystem met from the top is a tree**, and under it only the
  workspaces its own tool names are trees too.
- **Any other manifest under a tree is data**: a test fixture's `package.json`, a template's.
  Nothing under its directory is taken, and the directory is added to `jac.toml`'s
  `[project] exclude`, so its files are no modules of the project
  ([Projects](projects.md#what-is-not-the-projects-source)).
- **Nothing moves.** A manifest names its files by path, so it stays beside them. From then on
  neojac writes it there from its table, and lists it in `.gitignore`.
- **A directory with a `jac.toml` of its own is another project**, and is passed by.

### The archwire it writes

Where the project has no `archwire.jac`, `absorb` writes one with a single layer,
`layer all { *; }`: nothing of the project's layering is known yet. It then writes a wire for
every import between the project's files, as each language's own engine reads them
([Declared wires](../language/modules-wiring.md#declared-wires---)), which is what
`neojac fmt --fix archwire.jac` does. A project that says `archwire = false` gets none.

What still stands between the archwire and a check that passes is printed as the diagnostics
every command would give, and `absorb` then exits with status 1. The files it wrote stay.

### Open items

What no manifest says, and only a program of the repository or a person knows, is an **open
item**. `absorb` lists each at its file, and does not guess:

| Kind | Reported for | What closes it |
|---|---|---|
| `build` | A `setup.py` beside a `pyproject.toml`, or a `pyproject.toml` whose build backend is in the repository (`backend-path`); a `binding.gyp` beside a `package.json` | For a Python project, `neojac absorb --record` ([Recording a build](#recording-a-build)), for a module linked from a crate or from C. A `binding.gyp` is not recorded yet |
| `lock` | `uv.lock`, `poetry.lock`, `pdm.lock`, `Pipfile.lock`; `bun.lock`, `pnpm-lock.yaml`, `yarn.lock` | The same versions pinned by pip or npm in `jac.lock` |
| `form` | `pnpm-workspace.yaml`, a `pnpm` table in `package.json`, a `workspace:` dependency | The form npm reads |
| `tests` | A Python project | The command that runs its tests |

```text
$ neojac absorb --check
tiktoken is a Python project (pyproject.toml) and a Rust package (Cargo.toml)

  jac.toml     [pypi."."]   pyproject.toml, as it stands
               [cargo."."]  Cargo.toml, as it stands
  archwire.jac one layer, and a wire for every import between its files

open items
   1  setup.py: a program that builds this project: no manifest says what it compiles, or into which module
   2  pyproject.toml: no manifest says how this tree's tests are run

nothing written
```

### Recording a build

What a build program compiles is in no manifest, and is not read out of the program: neojac runs
it and watches.

```text
$ neojac absorb --record
...
recorded
  [extensions."tiktoken/_tiktoken"]  the crate ., with pyo3/extension-module, python
```

- **It runs the project's own build**, the wheel its build backend makes, on neojac's CPython in
  a virtual environment of its own (`.jac/absorb/`), with the toolchain's `cc` and `cargo`
  [recording each run](../interop/c-and-cpp.md#recording-what-a-build-ran). That needs what the
  build needs: the network, for the packages its backend asks for.
- **A native module the wheel holds is traced to what linked it**: the library whose bytes it is,
  the run of cargo whose target directory that library is in, and so the crate and the features
  it was built with. `jac.toml` gains `[extensions."<path>"]`
  ([Extension modules](#extension-modules)), and the `build` open item is closed.
- **The features are cargo's arguments as given**, a dependency's feature among them
  (`pyo3/extension-module`): nothing is left out for being the build tool's own.
- **A module linked from C becomes a C module of the project**: its sources are the units
  compiled into the library, in the order they were linked, with the directory they share as the
  module's. The flags every unit was given are the module's `include`, `defines` and `cflags`,
  and what one unit alone was given is in its `[files."<source>"]`. The interpreter's own headers
  are named as the toolchain's (`{lib}/cpython/include/python3.15`), and the frameworks and
  libraries of the link are the module's.

  ```toml
  [c.psutil.target.darwin]
  sources = ["_psutil_osx.c", "arch/all/errors.c", "arch/osx/cpu.c"]
  include = ["{lib}/cpython/include/python3.15"]
  defines = ["PSUTIL_POSIX=1", "PSUTIL_MACOS=1"]
  frameworks = ["CoreFoundation", "IOKit"]

  [extensions."psutil/_psutil"]
  c = "psutil"
  ```

- **A record is of the system it was made on**, so the whole of it is under that system's
  `[target.<os>]`: what another system compiles is not known until the build is recorded there.
- **What a table cannot say is reported, and the module is not taken**: an object no recorded run
  compiled, a source or a header directory outside the project and the toolchain, a flag of the
  link that is none of a library, a framework or how an extension links, and a crate built with
  `--no-default-features` or `--all-features`.
- **The build's own leavings stay**: `build/`, `target/`, an `.egg-info`, which the repository's
  `.gitignore` usually names already. neojac adds `.jac/` to it.
- **It is a program of the repository that runs**, as it does under `pip install`: record a
  repository you would build.

- **`--check` writes nothing.** It finds the trees, the data and the open items. It does not
  read the sources for their imports, so what the wires would say it does not judge.
- **`--json` prints the same as one document**: `trees` (each with its `ecosystem`, `directory`,
  `manifest`, `table`, `lock` and the tree it is a `member_of`), `data`, `open` (each with its
  `kind`, the file it is `at`, and what it `says`), and after an `absorb` that wrote, `wrote` and
  the count of `problems`.
- **A step that fails leaves every file as it was**: a manifest that cannot be taken whole
  (E5156, E5157) is refused, and nothing of the others stays written.
- **Absorbing again changes nothing**, and takes in what was added since.

`neojac absorb` does not yet write the project's spaces, install from a `pyproject.toml`, or
build what a `build` item names: a project it makes is one neojac holds and draws
(`neojac arch`), not yet one it builds.

## What keeps the two in step

- **What neojac writes is `jac.toml` and `jac.lock`, and nothing else.** A tree's `package.json`
  holds what its table holds, in the order the table has it.
- **npm resolves, neojac records.** `jac.lock`'s `[npm."<directory>"]` is the lock npm wrote, key for key.
  Written back, it is the same file byte for byte.
- **What one side cannot hold is refused, never dropped.** JSON's `null` has no value in TOML
  (E5156), and TOML's dates, `inf` and `nan` have none in JSON (E5155).
- **A build checks what is installed.** A tree whose `node_modules` was not installed from
  `jac.toml` and `jac.lock` as they are now is E5160, and `neojac install` is the fix. It runs npm
  only for a tree that is not as pinned.

## What goes wrong

| What neojac says | Why |
|---|---|
| `install: jac.toml declares no npm tree: name the directory of the one to make, --tree <directory> (eco/web, say)` | `--npm` in a project with no tree yet |
| `install: jac.toml declares the npm trees eco/web, eco/mobile: say which, --tree <directory>` | `--npm` in a project with several |
| `install: --tree names a directory of the project, and '../web' is outside it` | A tree is a directory of the project |
| `npm: jac.toml declares the npm trees eco/web, eco/mobile: run it in the directory of the one it is for` | `neojac npm` where no tree's directory is, in a project with several |
| `install --frozen: jac.lock pins nothing for the npm tree 'eco/web'; run neojac install` | `--frozen` before the tree was ever locked |
| E5155, E5156, E5157, E5158 | A value or a form one file cannot hold of the other: `neojac docs E5156`. E5157 is also a `Cargo.toml` or `cmodule.toml` whose text cannot be moved under a table's name as it is |
| E5159 | A workspace npm finds that `jac.toml` holds no table for: `neojac absorb` of the root's directory |
| E5160 | A tree not installed as pinned: `neojac install` |
| E5161 | A package that is not installed as a declaration asks: one declared by a version that is not in `eco/jac/`, or one from a repository that is not fetched (`neojac install`) |
| E5162 | Two askers of one npm package, at different ranges |
| E5163, E5164, E5165 | An installed package with no record of what installed it, a record or a `jac.lock` of another format, and a package another installer put where `neojac install` is asked to fetch one |
| E5166 | An installed package that is not what `jac.lock` pins: its files changed, or under `--frozen` its version or where it came from |
| `install --frozen: jac.lock pins nothing for the package 'units' as jac.toml asks for it; run neojac install` | `--frozen` after `jac.toml` came to ask for a package, or for another `git` or `rev` of one |
| E2216, E2219, E2220, E2221, E2222 | A package that is not where it is declared or is neither a library nor a plugin, a library imported that the package does not declare, a declaration that does not hold of the copy the program holds (another place, or a version that does not satisfy it), a library or a plugin that declares or binds a plugin, a library whose name the project's tree also has: `neojac docs E2219` |
| E2226, E2227, E2228, E2229 | A `[libraries]` or a `[plugins]` table, a plugin a project declares and never uses, a version or a requirement that is not one, a package that needs a later neojac |
| E2217, E2233 | A package that declares an abstraction; a plugin, or a library a plugin declares, that imports a module of stdjac or the contract of an abstraction it does not fill |
| E1287, E1288 | A space's tree is not declared, or not named among several |
