# Contributing

`abstractions/`, `stdjac/`, `libraries/`, `docs/` and `examples/` are what neojac is released
with. This repository holds the real copy of each: a change to one is a pull request here, and a
release of neojac ships the commit of this repository it was built with.

- **`abstractions/`** holds the language's abstractions, a directory each. Its `jac.toml` declares
  the abstraction: the interface a plugin of it implements, the version of that interface
  (`interface_ver`), and its standard plugin. Its `contract.jac` is the contract: that interface
  and the types that cross it. A change that a plugin written for an interface would not survive
  raises its version. `common/contract.jac` is what every plugin may use, whatever it fills.
- **The standard plugins** are the directories beside those two files
  (`abstractions/store/sqlite`), each a package with its own `jac.toml`. A plugin imports its
  abstraction's contract, `common.contract`, the libraries it declares and the standard library,
  and nothing else of neojac's. [Writing a plugin](docs/skills/writing-a-plugin/SKILL.md) says
  what one is made of.
- **`stdjac/`** is stdjac: what a program's source says of the abstractions (`root`, `by llm()`,
  `:prot`, `@job`) and what connects that to the plugin a project binds for each. A release ships
  it as the runtime's `rt/stdjac/`. It imports the contracts and nothing of a plugin, and its
  `surface.toml` lists the names a program says or imports of it, each with the module that
  holds it. The compiler calls into some of its modules by name: `app`, `bound`, `by`, `codec`,
  `crossing`, `desktop`, `graph`, `jsx`, `plan`, `remote`, the space hosts (`cpython_space`,
  `node_space`) and `surface.toml`. A rename there, or a change to the signature of a function
  the compiler calls, breaks the compiler, and is caught only when the compiler's tests are run
  against the change.
- **`libraries/`** holds the libraries those plugins declare, each a package of
  `kind = "library"`: `sqlfile` and `accountbook`.
- **`docs/`** is what `neojac docs` prints. A page's `jac` examples are whole programs that neojac
  compiles as the page says, and a page is listed in `docs/nav.json`.
- **`examples/`** holds programs written in Jac.

The compiler that builds these is not in this repository, and this repository runs no check of
its own on them yet. A pull request is checked when the compiler's own tests are run against it,
which a maintainer starts, and is merged when they pass.

Install neojac to try a change yourself. `neojac check` in a plugin's directory holds the plugin
to what it may import, and a project uses a copy of a plugin by declaring it by its directory,

```toml
[packages]
sqlite_mine = { path = "../neojac/abstractions/store/sqlite_mine" }

[store]
plugin = "sqlite_mine"
```

with the copy's `[project] name` and its class's path changed to match. A plugin declares the
libraries it uses by their place from its own directory (`sqlfile`, in `sqlite`'s `[packages]`),
so a copy made elsewhere says where they are from there.
