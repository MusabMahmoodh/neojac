---
description: Installing a neojac release with the installer, its options, where it puts things, checking that it works, and uninstalling.
keywords: installer, install.sh, uninstall
---
# Install

One command installs the latest release on Linux (x86_64 or arm64) and on macOS (Apple Silicon):

```sh
curl -fsSL https://github.com/jaseci-labs/neojac/releases/latest/download/install.sh | bash
```

Then check it:

```sh
neojac --version
echo 'with entry { print("hello from neojac"); }' > hello.jac
neojac build hello.jac -o hello
./hello
```

```text
hello from neojac
```

`neojac --version` prints `neojac <version> (<platform>, <commit>)`. A neojac that was built from a checkout instead of installed from a release prints `neojac, built from source (<platform>)`.

The documentation came with it. `neojac docs` prints the map of its pages, and `neojac docs <word>` the page that defines a word, an error code or a command; see [docs and skills](../toolchain/docs.md) (`neojac docs toolchain/docs`).

## What the installer does

1. Works out the platform from `uname`: `linux-x86_64`, `linux-aarch64` or `macos-aarch64`.
2. Asks GitHub for the latest release of `jaseci-labs/neojac`, unless `--version` names one.
3. Downloads `neojac-<version>-<platform>.tar.gz` and its `.sha256`, and stops unless the archive matches the checksum. On a terminal it shows the download's progress.
4. Unpacks the archive as `~/.neojac/<version>/`, replacing a copy of the same version.
5. Points the link `~/.neojac/current` at that version, and the link `~/.local/bin/neojac` at `~/.neojac/current/bin/neojac`.
6. Builds and runs a one-line program with the installed compiler, started by its name as you will start it. If that fails, the installer says so and exits with status 1; the release stays unpacked.
7. If `~/.local/bin` is not on `PATH`, prints the line to add to your shell's profile.

It needs `curl`, `tar`, and `sha256sum` or `shasum`. Nothing else is installed and nothing outside those two directories is written.

neojac finds its runtime (`rt/`), its documentation (`docs/`) and its toolchain (`lib/`) from where its own executable is, through the links. It reads no configuration file and needs no environment variable.

## Options

Options go after `bash -s --`:

```sh
curl -fsSL https://github.com/jaseci-labs/neojac/releases/latest/download/install.sh | bash -s -- --version 0.1.1
curl -fsSL https://github.com/jaseci-labs/neojac/releases/latest/download/install.sh | bash -s -- --uninstall
```

| Option | What it does |
|---|---|
| `--version <V>` | Install release `V` (`0.1.1` or `v0.1.1`) instead of the latest |
| `--uninstall` | Remove neojac (below) |
| `--help`, `-h` | Print the installer's usage |

| Environment variable | What it changes | Default |
|---|---|---|
| `NEOJAC_HOME` | Where releases are unpacked | `~/.neojac` |
| `NEOJAC_BIN_DIR` | Where the `neojac` link goes | `~/.local/bin` |
| `GITHUB_TOKEN`, `GH_TOKEN` | Sent with the request for the latest release, so the request is not held to GitHub's unauthenticated rate limit | none |

These are read by the installer only. neojac itself reads none of them.

## Where things are

```text
~/.local/bin/neojac -> ~/.neojac/current/bin/neojac
~/.neojac/current   -> ~/.neojac/<version>
~/.neojac/<version>/
    bin/neojac
    rt/
    docs/
    lib/
    README.md
    VERSION
```

Installing another version adds a directory beside the first and moves the two links; the older version stays until you delete its directory or uninstall.

Two more places are written when neojac runs, not when it is installed:

- The build cache, in your per-user cache directory (`~/Library/Caches/neojac` on macOS, `$XDG_CACHE_HOME/neojac` or `~/.cache/neojac` on Linux). See [The build cache](../toolchain/cache.md).
- A `.jac/` directory in each project you build or test. See [Projects](../toolchain/projects.md).

## Uninstalling

`--uninstall` removes the link `$NEOJAC_BIN_DIR/neojac` and the whole of `$NEOJAC_HOME`, every installed version with it. It leaves the build cache and your projects' `.jac/` directories; delete those yourself.

## Platforms the installer does not cover

| Platform | What to do |
|---|---|
| Windows | Each release has `neojac-<version>-windows-x86_64.zip`, built on Linux and not yet tested on Windows. The installer refuses to run under MSYS, MinGW or Cygwin and points at the zip; under WSL2 it installs the Linux release |
| macOS on Intel | No release. A neojac on another platform builds programs for it: `--target macos-x86_64` |
| Anything else | The installer stops with `Unsupported operating system` or `Unsupported architecture` |

## What goes wrong

| Message | Cause |
|---|---|
| `Required command not found: curl` (or `tar`) | Install the command and run the installer again |
| `Failed to query GitHub for the latest release.` | No connection, or the rate limit: name a version with `--version`, or set `GITHUB_TOKEN` |
| `Failed to download ...` | The release does not exist, or has no archive for this platform |
| `Checksum verification failed.` | The download does not match the release's `.sha256`. Nothing is installed |
| `... could not compile and run a test program on this machine.` | The release was unpacked but cannot build a program here |

After installing, continue with [A first program](first-program.md) (`neojac docs first-program`).
