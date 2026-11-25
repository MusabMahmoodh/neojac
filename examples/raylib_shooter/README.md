# Jac Cube Shooter

One small first-person 3D shooter, written four times: in Jac, in C, in Rust and in Python. Each
twin is the same program statement for statement, draws through the same precompiled
[raylib](https://www.raylib.com) shared library, and is built and run by neojac, so the four can
be read side by side and timed against each other.

| Twin | Source | neojac builds or runs it with |
|---|---|---|
| Jac | `shooter.jac`, `impl/shooter.impl.jac` | `neojac build shooter.jac --release` |
| C | `shooter.c` | `neojac cc -O3 shooter.c` |
| Rust | `shooter.rs` | `neojac rustc -C opt-level=3 shooter.rs` |
| Python | `shooter.py` | `neojac python shooter.py` |

A fifth program, `shooter_headless.jac`, is the game loop with no window, held to Jac's ownership
contract: [The headless twin](#the-headless-twin).

## Run it

neojac is the only tool it needs ([install](../../docs/start/install.md)). On Linux or macOS, with
a display:

```sh
./demo.sh              # benchmark all four twins, 8 seconds each, in both modes
./demo.sh --jac        # build and play the Jac shooter
./demo.sh --c          # build and play the C shooter
./demo.sh --rust       # build and play the Rust shooter
./demo.sh --python     # play the Python shooter
./demo.sh --jac --flock  # any of those four, with the flock of 256 boids turned on
./demo.sh --headless   # time the headless twin under each memory profile: no window
```

Mouse or arrows aim (a click or Tab captures the cursor for mouse-look), WASD move, Space fires,
Tab releases the cursor, Esc quits.

`demo.sh`:

1. downloads raylib's own release for this machine and puts its shared library in `vendor/`;
2. builds each twin it needs into `build/`, with the commands of the table above;
3. plays one twin, or benchmarks all four.

`NEOJAC` names the neojac to use when it is not the one on `PATH`, `BENCH_SECONDS` the seconds
each benchmark runs for, and `HEADLESS_FRAMES` the frames the headless twin simulates.

## How each twin reaches raylib

No twin uses a binding package or raylib's headers. Each declares the functions it calls and
links the library in `vendor/`.

Jac declares them in an import block. `vendor.raylib` names a library the project provides,
`vendor/libraylib.so` on Linux and `vendor/libraylib.dylib` on macOS, and the build gives the
program a run path to it, so it is found wherever the program is started from
(`neojac docs project library`):

```jac
import from vendor.raylib {
    def InitWindow(width: i32, height: i32, title: str) -> None;
    def rlVertex3f(x: f32, y: f32, z: f32) -> None;
    def rlColor4ub(r: u8, g: u8, b: u8, a: u8) -> None;
}
```

A call is a direct C call. An `int` or a `float` given to one of those parameters narrows to the
C type by itself, so the game's code passes its own 64-bit values.

C declares the same functions as prototypes, Rust in an `unsafe extern "C"` block, and Python
through the standard library's `ctypes`:

```c
void InitWindow(int width, int height, const char *title);
void rlVertex3f(float x, float y, float z);
void rlColor4ub(unsigned char r, unsigned char g, unsigned char b, unsigned char a);
```

```rust
#[link(name = "raylib")]
unsafe extern "C" {
    fn InitWindow(width: c_int, height: c_int, title: *const c_char);
    fn rlVertex3f(x: f32, y: f32, z: f32);
    fn rlColor4ub(r: u8, g: u8, b: u8, a: u8);
}
```

```python
rl = ctypes.CDLL(os.path.join(HERE, "vendor", _LIBNAME))
rlVertex3f = _bind("rlVertex3f", None, c_float, c_float, c_float)
```

The C and the Rust twin are linked by `neojac cc` and `neojac rustc` against `vendor/` with a run
path to it. They record the name the library gives itself (`libraylib.so.600`), and the Jac twin
its plain name (`libraylib.so`), so `vendor/` holds the library and the links that name it.

## What the game does

Every twin draws with raylib's scalar rlgl calls (`rlBegin`, `rlVertex3f`, `rlColor4ub`,
`rlTranslatef`, ...) and not with the calls that take a `Vector3` or a `Camera3D` by value, so
the four make exactly the same calls in the same order:

- **The camera** is a frustum of 60 degrees vertical field of view (`rlFrustum`), and a view
  transform that is the inverse of where the player stands and looks: two `rlRotatef` and one
  `rlTranslatef`.
- **A cube** is six quads of two triangles each, wound counter-clockwise from outside for
  raylib's back-face culling. Each face has a fixed brightness, so a cube reads as solid with no
  lighting.
- **The floor** is a grid of lines on `y = 0`.
- **The frame-rate counter** is raylib's own, drawn after the 3D pass in a projection of screen
  pixels.
- **Sine, cosine and square root** are the program's own: a range-reduced Taylor series and
  twelve steps of Newton's method. So each twin's arithmetic is its language's, and none of it a
  call into a mathematics library.
- **Random numbers** are a 31-bit linear congruential generator with one seed, so every twin
  places its targets, and its flock, in the same places.

The one difference of structure is Rust's: the player and world state that the Jac, C and Python
twins keep in module globals is one `Game` struct there, passed by `&mut`.

### Flock mode

The plain shooter spends nearly all of a frame inside raylib and the graphics driver, so it says
that the four twins drive raylib equally well and little about the languages. Flock mode adds
work that runs in each language's own code: 256 boids that each steer, every frame, against
every other boid. A boid moves away from those too close, matches the heading of those in view
and moves toward their centre, and is pulled back toward the arena. That is 65,280 neighbour
tests of floating-point arithmetic a frame, then an integration pass with a speed clamp. The
boids are drawn as short streaks, 512 vertices more a frame.

A file `.flock` beside the programs turns it on, which each twin looks for once as it starts.
Without it no flock is made, steered or drawn.

## The benchmark

`./demo.sh` runs each twin for 8 seconds as the plain shooter, then for 8 seconds in flock mode,
with no frame-rate cap, and prints a table for each mode:

```text
====== raylib cube shooter benchmark (8s each, uncapped) ======
  the plain shooter: rendering only
  twin        avg FPS      max FPS     frames  vs Python
  Jac           604.7        820.4       4838       1.1x
  C             618.2        883.6       4946       1.2x
  Rust          606.1        822.0       4849       1.1x
  Python        532.5        699.4       4261       1.0x
================================================================

====== raylib cube shooter benchmark (8s each, uncapped) ======
  flock mode: 256 boids steering every frame
  twin        avg FPS      max FPS     frames  vs Python
  Jac           504.1        620.0       4033       5.0x
  C             533.1        711.3       4265       5.3x
  Rust          529.6        683.4       4237       5.3x
  Python        100.2        121.3        803       1.0x
================================================================
```

Those are from neojac 0.4.0, which built the Rust twin without `-C panic=abort`, on an AMD Ryzen
Threadripper 9980X under WSL2, where OpenGL is Mesa's software renderer (llvmpipe). There the renderer takes most of every frame, so the three
compiled twins are within a run's noise of each other in both modes, and a run moves by a tenth
or more from one to the next; what the tables do show is the cost of Python's calls in the plain
shooter and of its arithmetic in flock mode. Yours will differ: a machine that draws on its GPU
gives far higher rates, and leaves more of a flock-mode frame to each language's own code.
`max FPS` is the single fastest frame and is mostly noise.

How a twin is timed without changing how it plays: raylib paints the frame rate onto the frame
and writes its own log to stdout, so a twin does not print its result. `demo.sh` writes the
seconds to run for into `.bench_seconds` before it starts a twin. A twin that finds that file
(read with raylib's `FileExists`, `LoadFileText` and `TextToInteger`) times itself with raylib's
`GetTime`, stops after that long, and writes `BENCH_RESULT <average> <highest> <frames> <seconds>`
into `.bench_result` with raylib's `SaveFileText`, which `demo.sh` reads back. Without
`.bench_seconds` a twin runs until its window is closed. Every twin does this through raylib, so
the four stay the same program.

## The headless twin

`shooter_headless.jac` is the shooter's game loop with the window taken away and every binding
that holds memory annotated: `w: own World`, `&World` and `&mut World` parameters, `f(&mut w)`
at each call. So the whole program keeps Jac's ownership contract, and builds under the `nogc`
memory profile, with no collector and nothing reference-counted
(`neojac docs memory`):

```sh
neojac build shooter_headless.jac --memory nogc --release -o build/shooter_headless_nogc
```

It runs what `shooter.jac` runs each frame (input, the fire cooldown, the bullets and their hit
tests, the targets' respawn and bob) at a fixed 240 Hz tick, with two things replaced so that it
needs no window:

- **The player** is a scripted pilot, made of the same turn and move constants as the game's
  input: sweeps of yaw, tilts of pitch, strides, and the trigger held.
- **The renderer** folds the vertices the game would draw (the grid's lines, six shaded quads a
  cube, the camera's pose) into one integer digest, in place of each `rlVertex3f`.

The targets and the bullets are parallel lists in one owned `World`, indexed by slot, so every
change goes through a `&mut World` borrow.

`./demo.sh --headless` builds the same source under each memory profile, runs each for 100,000
frames, and prints:

```text
==== headless shooter benchmark (100000 frames, 240 Hz game tick) ====
  profile      frames/s    ns/frame    score       digest
  nogc           121734        8215       34    502241830
  rc             112129        8918       34    502241830
  managed        107696        9285       34    502241830
  the three digests are equal
```

Equal digests say the memory profile changes nothing the program computes. This mode needs no
display and no raylib, so it runs anywhere.

## The project

`jac.toml` makes this directory a project, which is what `vendor.raylib` is found from.
`archwire.jac` puts the two Jac programs in one layer and has no wires: they import nothing of
each other. `jac.toml`'s `[project] exclude` sets the C, Rust and Python twins aside: they are
programs of their own that stand beside them, and no modules of the project.

The Jac source holds no comments and no docstrings, and each module's bodies are in its annex
under `impl/`: the layout `neojac fmt --fix` gives every project, with what a comment would say
written here.

| Path | What it is |
|---|---|
| `shooter.jac`, `impl/shooter.impl.jac` | The Jac twin |
| `shooter.c`, `shooter.rs`, `shooter.py` | The C, Rust and Python twins |
| `shooter_headless.jac`, `impl/shooter_headless.impl.jac` | The headless twin |
| `demo.sh` | Fetches raylib, builds, plays and benchmarks |
| `vendor/`, `build/`, `.build/` | raylib's library, the built programs, and raylib's download: made by `demo.sh`, not tracked |

[`examples/jaclang_org`](../jaclang_org/) holds a larger game over the same rlgl calls, in
`core/site/game`, which also runs in a browser, where a WebGL host stands in for raylib.
