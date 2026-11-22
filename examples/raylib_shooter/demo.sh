#!/usr/bin/env bash
#
# Build and run the raylib cube shooter, with neojac for every language.
#
#   default     benchmark all four twins (Jac, C, Rust, Python) in both modes,
#               the plain shooter and flock mode: each runs for a fixed number
#               of seconds, then a table for each mode gives the average and
#               the highest frame rate side by side
#   --jac       build and play the Jac shooter (shooter.jac)
#   --c         build and play the C shooter (shooter.c)
#   --rust      build and play the Rust shooter (shooter.rs)
#   --python    play the Python shooter (shooter.py)
#   --flock     with one of the four above: play in flock mode
#   --headless  build the headless twin (shooter_headless.jac) under each
#               memory profile, time them, and compare their digests
#
# neojac is the only tool it needs, and builds and runs all four:
#
#   Jac     neojac build shooter.jac --release
#   C       neojac cc shooter.c
#   Rust    neojac rustc shooter.rs
#   Python  neojac python shooter.py
#
# NEOJAC names the neojac to use (default: the one on PATH). raylib itself is
# not built here: the script downloads raylib's own release for this machine
# and puts its shared library in vendor/, where every twin finds it.
#
# Flock mode: a file `.flock` beside this script turns on a flock of 256 boids
# in every twin. Each boid steers against every other boid each frame, so a
# frame spends real time in each language's own arithmetic, where the plain
# shooter spends nearly all of it inside raylib and the graphics driver.
#
# The benchmark's switch: the script writes the seconds to run for into
# `.bench_seconds` before it starts a twin, and removes it after. A twin that
# finds the file stops after that long and writes its result to
# `.bench_result`; one that does not runs until its window is closed.
#
set -euo pipefail

MODE="bench" # bench | jac | c | rust | python | headless
FLOCK=0      # 1: a twin that is played is played in flock mode
BENCH_SECONDS="${BENCH_SECONDS:-8}"
HEADLESS_FRAMES="${HEADLESS_FRAMES:-100000}"
NEOJAC="${NEOJAC:-neojac}"
RAYLIB_VERSION="6.0"
RAYLIB_URL="https://github.com/raysan5/raylib/releases/download/${RAYLIB_VERSION}"

for arg in "$@"; do
  case "$arg" in
    --jac) MODE="jac" ;;
    --c) MODE="c" ;;
    --rust) MODE="rust" ;;
    --python) MODE="python" ;;
    --flock) FLOCK=1 ;;
    --bench) MODE="bench" ;;
    --headless) MODE="headless" ;;
    -h | --help)
      echo "Usage: ${0##*/} [--jac | --c | --rust | --python | --bench | --headless] [--flock]"
      echo "  (default)   benchmark all four twins for ${BENCH_SECONDS}s each, as the plain shooter"
      echo "              and in flock mode, and print each mode's frame rates"
      echo "              (BENCH_SECONDS sets the seconds)"
      echo "  --jac       build and play the Jac shooter"
      echo "  --c         build and play the C shooter"
      echo "  --rust      build and play the Rust shooter"
      echo "  --python    play the Python shooter"
      echo "  --flock     with one of those four: turn on the flock of 256 boids"
      echo "  --bench     the default, said outright"
      echo "  --headless  time the headless twin under each memory profile, with no"
      echo "              window and no raylib (HEADLESS_FRAMES sets the frames,"
      echo "              ${HEADLESS_FRAMES} unless it is set)"
      echo "  NEOJAC names the neojac that builds and runs them (default: neojac)."
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg (try --help)" >&2
      exit 1
      ;;
  esac
done

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HERE"
FETCHED="$HERE/.build"
OUT="$HERE/build"
VENDOR="$HERE/vendor"
mkdir -p "$FETCHED" "$OUT" "$VENDOR"

if ! command -v "$NEOJAC" >/dev/null 2>&1; then
  echo "Could not find '$NEOJAC'. Install neojac, or set NEOJAC to where it is:" >&2
  echo "  curl -fsSL https://github.com/jaseci-labs/neojac/releases/latest/download/install.sh | bash" >&2
  exit 1
fi
echo ">> neojac   : $("$NEOJAC" version | head -1)"

os="$(uname -s)"
arch="$(uname -m)"

# ── Headless: no window and no raylib, so it is done before raylib is fetched ─
#
# shooter_headless.jac is the shooter's game loop with a scripted pilot for the
# player and a digest of every vertex for the renderer. It keeps the ownership
# contract, so it builds with nothing counted (nogc), and the same source
# builds under rc and managed: equal digests from the three say the profile
# changes nothing the program computes.
if [ "$MODE" = "headless" ]; then
  profiles="nogc rc managed"
  for profile in $profiles; do
    echo ">> building : neojac build shooter_headless.jac --memory $profile --release"
    "$NEOJAC" build shooter_headless.jac --memory "$profile" --release -o "$OUT/shooter_headless_$profile"
  done

  echo ">> running  : $HEADLESS_FRAMES frames for each build, at a 240 Hz game tick ..."
  printf '\n'
  printf '==== headless shooter benchmark (%s frames, 240 Hz game tick) ====\n' "$HEADLESS_FRAMES"
  printf '  %-9s %11s %11s %8s %12s\n' "profile" "frames/s" "ns/frame" "score" "digest"
  digests=""
  for profile in $profiles; do
    out="$("$OUT/shooter_headless_$profile" "$HEADLESS_FRAMES")"
    digest="$(printf '%s\n' "$out" | sed -n 's/^shooter://p')"
    score="$(printf '%s\n' "$out" | sed -n 's/^score:\([0-9]*\).*/\1/p')"
    ns="$(printf '%s\n' "$out" | sed -n 's/^ns=//p')"
    fps="$(awk -v f="$HEADLESS_FRAMES" -v n="$ns" 'BEGIN { printf "%.0f", f * 1e9 / n }')"
    nsf="$(awk -v f="$HEADLESS_FRAMES" -v n="$ns" 'BEGIN { printf "%.0f", n / f }')"
    printf '  %-9s %11s %11s %8s %12s\n' "$profile" "$fps" "$nsf" "$score" "$digest"
    digests="$digests $digest"
  done
  # shellcheck disable=SC2086
  distinct="$(printf '%s\n' $digests | sort -u | wc -l | tr -d ' ')"
  if [ "$distinct" = "1" ]; then
    echo "  the three digests are equal"
  else
    echo "  !! the digests differ between memory profiles"
  fi
  printf '==================================================================\n'
  [ "$distinct" = "1" ]
  exit $?
fi

# ── raylib: its release for this machine, its shared library put in vendor/ ──
case "$os" in
  Linux)
    case "$arch" in
      x86_64 | amd64) asset="raylib-${RAYLIB_VERSION}_linux_amd64.tar.gz" ;;
      aarch64 | arm64) asset="raylib-${RAYLIB_VERSION}_linux_arm64.tar.gz" ;;
      *)
        echo "raylib has no release for Linux on $arch" >&2
        exit 1
        ;;
    esac
    lib_glob="libraylib.so*"
    run_path="\$ORIGIN/../vendor"
    ;;
  Darwin)
    # One library for both architectures.
    asset="raylib-${RAYLIB_VERSION}_macos.tar.gz"
    lib_glob="libraylib*.dylib"
    run_path="@loader_path/../vendor"
    ;;
  *)
    echo "This demo runs on Linux and macOS, and this is $os" >&2
    exit 1
    ;;
esac

echo ">> platform : $os / $arch"
tarball="$FETCHED/$asset"
if [ ! -f "$tarball" ]; then
  echo ">> fetching : $RAYLIB_URL/$asset"
  curl -fL --retry 3 -o "$tarball.part" "$RAYLIB_URL/$asset"
  mv "$tarball.part" "$tarball"
fi
extracted="$FETCHED/extracted"
rm -rf "$extracted"
mkdir -p "$extracted"
tar xzf "$tarball" -C "$extracted"
lib_file="$(find "$extracted" -type f -name "$lib_glob" | sort | head -1)"
if [ -z "$lib_file" ]; then
  echo "raylib's release holds no $lib_glob" >&2
  exit 1
fi
# The library and the links that name its versions. The Jac twin asks for it
# by its plain name (libraylib.so), and the C and Rust twins by the name the
# library gives itself (libraylib.so.600); both are found here.
cp -P "$(dirname "$lib_file")"/$lib_glob "$VENDOR/"
echo ">> raylib   : $RAYLIB_VERSION, in vendor/"

# ── Building each twin, with neojac ─────────────────────────────────────────

# shooter.jac binds raylib as `vendor.raylib`, a library of the project: the
# build finds vendor/'s library by that name and gives the program a run path
# to it.
build_jac() {
  echo ">> building : neojac build shooter.jac --release"
  "$NEOJAC" build shooter.jac --release -o "$OUT/shooter_jac"
}

# shooter.c, with the Clang and the linker neojac carries. It declares the
# raylib functions it calls, so it needs none of raylib's headers.
build_c() {
  echo ">> building : neojac cc -O3 shooter.c"
  "$NEOJAC" cc -std=c11 -O3 -Wall -Wextra shooter.c \
    -L"$VENDOR" -lraylib "-Wl,-rpath,$run_path" \
    -o "$OUT/shooter_c"
}

# shooter.rs, one file with the rustc neojac carries: no cargo and no crates.
build_rust() {
  echo ">> building : neojac rustc -C opt-level=3 shooter.rs"
  "$NEOJAC" rustc --edition 2024 -C opt-level=3 -C codegen-units=1 -C panic=abort \
    -L "$VENDOR" -l raylib -C "link-arg=-Wl,-rpath,$run_path" \
    shooter.rs -o "$OUT/shooter_rust"
}

# shooter.py is not built: it runs on the CPython neojac carries, and loads
# vendor/'s raylib through ctypes.
say_python() {
  echo ">> python   : $("$NEOJAC" python --version 2>&1), neojac's"
}

# Make or remove `.flock`. $1: 1 for flock mode, 0 for the plain shooter.
set_flock() {
  if [ "$1" = "1" ]; then
    printf '1' >"$HERE/.flock"
  else
    rm -f "$HERE/.flock"
  fi
}

# Run one twin as a benchmark for $BENCH_SECONDS and print its result line,
# "BENCH_RESULT <average> <highest> <frames> <seconds>", or nothing if it gave
# none. $1: its name, for the message; $2: 1 for flock mode; the rest: the
# command that runs it.
#
# The result comes through a file because raylib writes its own log to stdout:
# each twin saves the line with raylib's SaveFileText, and is told how long to
# run the same way, through `.bench_seconds`.
run_bench() {
  local label="$1" flock="$2" status line
  shift 2
  rm -f "$HERE/.bench_result"
  printf '%s' "$BENCH_SECONDS" >"$HERE/.bench_seconds"
  set_flock "$flock"
  set +e
  # A twin stops by itself after $BENCH_SECONDS; the limit is for one that
  # hangs, or has no display to draw on.
  if command -v timeout >/dev/null 2>&1; then
    timeout "$((BENCH_SECONDS + 15))" "$@" >/dev/null 2>&1
  else
    "$@" >/dev/null 2>&1
  fi
  status=$?
  set -e
  rm -f "$HERE/.bench_seconds"
  set_flock 0
  if [ ! -f "$HERE/.bench_result" ]; then
    echo "!! $label gave no result (exit status $status): is there a display to draw on?" >&2
    return 1
  fi
  line="$(cat "$HERE/.bench_result")"
  rm -f "$HERE/.bench_result"
  echo "$line"
}

# Print one row of a table. $1: the twin; $2: its result line, which may be
# empty; $3: the Python twin's, for the last column, which may be empty.
print_bench_row() {
  local label="$1" line="$2" base="${3:-}" avg max frames ratio="n/a" base_avg
  if [ -z "$line" ]; then
    printf '  %-6s %12s %12s %10s %10s\n' "$label" "n/a" "n/a" "n/a" "n/a"
    return
  fi
  # shellcheck disable=SC2034
  read -r _tag avg max frames _secs <<<"$line"
  if [ -n "$base" ]; then
    # shellcheck disable=SC2034
    read -r _tag base_avg _rest <<<"$base"
    ratio="$(awk -v a="$avg" -v b="$base_avg" 'BEGIN { if (b > 0) printf "%.1fx", a / b; else print "n/a" }')"
  fi
  printf '  %-6s %12.1f %12.1f %10s %10s\n' "$label" "$avg" "$max" "$frames" "$ratio"
}

# Benchmark every twin in one mode and print its table. $1: 1 for flock mode.
bench_mode() {
  local flock="$1" title jac_line c_line rust_line py_line
  if [ "$flock" = "1" ]; then
    title="flock mode: 256 boids steering every frame"
  else
    title="the plain shooter: rendering only"
  fi
  echo ">> timing   : ${BENCH_SECONDS}s for each twin, $title (a window opens for each) ..." >&2
  jac_line="$(run_bench Jac "$flock" "$OUT/shooter_jac" || true)"
  c_line="$(run_bench C "$flock" "$OUT/shooter_c" || true)"
  rust_line="$(run_bench Rust "$flock" "$OUT/shooter_rust" || true)"
  py_line="$(run_bench Python "$flock" "$NEOJAC" python shooter.py || true)"

  printf '\n'
  printf '====== raylib cube shooter benchmark (%ss each, uncapped) ======\n' "$BENCH_SECONDS"
  printf '  %s\n' "$title"
  printf '  %-6s %12s %12s %10s %10s\n' "twin" "avg FPS" "max FPS" "frames" "vs Python"
  print_bench_row "Jac" "$jac_line" "$py_line"
  print_bench_row "C" "$c_line" "$py_line"
  print_bench_row "Rust" "$rust_line" "$py_line"
  print_bench_row "Python" "$py_line" "$py_line"
  printf '================================================================\n'
}

# Play one twin, in flock mode when $1 is 1, and remove `.flock` after it, so
# the next run starts as the plain shooter. The rest: the command that runs it.
play() {
  local flock="$1" status
  shift
  rm -f "$HERE/.bench_seconds"
  set_flock "$flock"
  echo ">> playing  : mouse or arrows aim, WASD move, Space fires, Esc quits"
  set +e
  "$@"
  status=$?
  set -e
  set_flock 0
  return "$status"
}

case "$MODE" in
  jac)
    build_jac
    play "$FLOCK" "$OUT/shooter_jac"
    ;;
  c)
    build_c
    play "$FLOCK" "$OUT/shooter_c"
    ;;
  rust)
    build_rust
    play "$FLOCK" "$OUT/shooter_rust"
    ;;
  python)
    say_python
    play "$FLOCK" "$NEOJAC" python shooter.py
    ;;
  bench)
    build_jac
    build_c
    build_rust
    say_python
    bench_mode 0
    bench_mode 1
    ;;
esac
