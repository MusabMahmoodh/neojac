import sys;
import time;

glob DEG2RAD: float = 0.017453292519943295,
     DIGEST_MOD: int = 1000000007;
def jcos(a: float) -> float;
def jsin(a: float) -> float;

obj World {
    has px: float = 0.0,
        py: float = 2.0,
        pz: float = 12.0,
        yaw: float = 0.0,
        pitch: float = 0.0,
        fire_cd: float = 0.0,
        world_t: float = 0.0,
        score: int = 0,
        shots: int = 0,
        rng: int = 987654321,
        tx: list[float] = [],
        ty: list[float] = [],
        tz: list[float] = [],
        tbase: list[float] = [],
        tphase: list[float] = [],
        talive: list[bool] = [],
        bpx: list[float] = [],
        bpy: list[float] = [],
        bpz: list[float] = [],
        bvx: list[float] = [],
        bvy: list[float] = [],
        bvz: list[float] = [],
        blife: list[float] = [];
}

def rand01(w: &mut World) -> float;
def rand_range(w: &mut World, lo: float, hi: float) -> float;
def respawn(w: &mut World, i: int);
def fire(w: &mut World);
def update_bullets(w: &mut World, step: float);
def bob_targets(w: &mut World);
def sim_input(w: &mut World, frame: int, step: float);
def mix3(digest: int, x: float, y: float, z: float) -> int;
def quad(
    digest: int,
    x0: float,
    y0: float,
    z0: float,
    x1: float,
    y1: float,
    z1: float,
    x2: float,
    y2: float,
    z2: float,
    x3: float,
    y3: float,
    z3: float,
) -> int;
def shade(c: int, pct: int) -> int;
def mix_color(digest: int, r: int, g: int, b: int, pct: int) -> int;
def emit_box(
    digest: int,
    cx: float,
    cy: float,
    cz: float,
    sx: float,
    sy: float,
    sz: float,
    r: int,
    g: int,
    b: int,
) -> int;
def emit_floor(digest: int, half: int, step: float) -> int;
def emit_frame(w: &World, digest: int) -> int;
def run(frames_n: int) -> int;

with entry {
    frames_n = 100000;
    if len(sys.argv) > 1 {
        frames_n = int(sys.argv[1]);
    }
    t0 = time.perf_counter_ns();
    digest = run(frames_n);
    t1 = time.perf_counter_ns();
    print("shooter:" + str(digest));
    print("frames=" + str(frames_n));
    print("ns=" + str(t1 - t0));
}
