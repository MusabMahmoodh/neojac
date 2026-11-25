---
description: Installing a neojac release with the installer, its options, where it puts things, checking that it works, its usage statistics, and uninstalling.
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
3. Downloads `neojac-<version>-<platform>.gz` and its `.sha256`, and stops unless the download matches the checksum. On a terminal it shows the download's progress.
4. Unpacks it as `~/.local/bin/neojac`, in place of the neojac that was there: the file is written under another name beside it and renamed, so a neojac that is running is never a file half written.
5. Builds and runs a one-line program with the installed compiler, started by its name as you will start it, with `NEOJAC_TELEMETRY=off`: the installer's build records nothing of its use. If that fails, the installer says so and exits with status 1; the file stays where it was put.
6. Says that neojac collects anonymous usage statistics, and how to turn that off.
7. If `~/.local/bin` is not on `PATH`, prints the line to add to your shell's profile.

It needs `curl`, `gzip`, and `sha256sum` or `shasum`. Nothing else is installed: a release is that one file.

neojac carries its runtime, its documentation and its toolchain inside itself ([What one download contains](index.md#what-one-download-contains)). It needs no configuration file and no environment variable, and it runs from wherever the file is put.

## Usage statistics

A release of neojac counts what it is used for (which commands run, the codes of the diagnostics they report, its version and platform) and nothing a command was given: no file names, no source, no arguments. Its first run prints a notice saying so. `neojac telemetry` shows what is recorded, `neojac telemetry off` stops it and deletes what is recorded, and `NEOJAC_TELEMETRY=off` or `DO_NOT_TRACK=1` keeps it off wherever it is set. [telemetry](../toolchain/telemetry.md) (`neojac docs telemetry`) lists every field of a report.

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
| `NEOJAC_BIN_DIR` | Where `neojac` goes | `~/.local/bin` |
| `GITHUB_TOKEN`, `GH_TOKEN` | Sent with the request for the latest release, so the request is not held to GitHub's unauthenticated rate limit | none |

These are read by the installer only. neojac itself reads none of them.

## Where things are

```text
~/.local/bin/neojac
```

That file is the install. Installing another version replaces it, so one version is installed at a time; `--version` puts a named release in its place.

Three more places are written when neojac runs, not when it is installed:

- Its cache, in your per-user cache directory (`~/Library/Caches/neojac` on macOS, `$XDG_CACHE_HOME/neojac` or `~/.cache/neojac` on Linux): what builds keep, and what neojac writes out of itself the first time a tool has to read it as a file. All of it is made again when it is missing. See [The build cache](../toolchain/cache.md).
- A `.jac/` directory in each project you build or test. See [Projects](../toolchain/projects.md).
- `~/.neojac/telemetry/`, what is recorded of neojac's use and whether recording is on. See [telemetry](../toolchain/telemetry.md#where-it-is-kept).

## Uninstalling

`--uninstall` removes `$NEOJAC_BIN_DIR/neojac`, neojac's cache (the directory `NEOJAC_CACHE_DIR` names, if it is set) and `~/.neojac`, what is recorded of neojac's use. It leaves your projects' `.jac/` directories; delete those yourself.

## Platforms the installer does not cover

| Platform | What to do |
|---|---|
| Windows | Each release has `neojac-<version>-windows-x86_64.exe.gz`, which unpacks to the one file `neojac.exe`; it is built on Linux and not yet tested on Windows. The installer refuses to run under MSYS, MinGW or Cygwin and points at that download; under WSL2 it installs the Linux release |
| macOS on Intel | No release. A neojac on another platform builds programs for it: `--target macos-x86_64` |
| Anything else | The installer stops with `Unsupported operating system` or `Unsupported architecture` |

## What goes wrong

| Message | Cause |
|---|---|
| `Required command not found: curl` (or `gzip`) | Install the command and run the installer again |
| `Failed to query GitHub for the latest release.` | No connection, or the rate limit: name a version with `--version`, or set `GITHUB_TOKEN` |
| `Failed to download ...` | The release does not exist, or has no neojac for this platform |
| `Checksum verification failed.` | The download does not match the release's `.sha256`. Nothing is installed |
| `Failed to unpack ...` | The directory neojac goes in cannot be written, or the disk is full. The neojac that was there is as it was |
| `... could not compile and run a test program on this machine.` | The release was installed but cannot build a program here |

After installing, continue with [A first program](first-program.md) (`neojac docs first-program`).
