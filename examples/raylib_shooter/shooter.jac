import from vendor.raylib {
    def InitWindow(width: i32, height: i32, title: str) -> None;
    def WindowShouldClose -> bool;
    def CloseWindow -> None;
    def BeginDrawing -> None;
    def EndDrawing -> None;
    def rlClearColor(r: u8, g: u8, b: u8, a: u8) -> None;
    def rlClearScreenBuffers -> None;
    def DrawFPS(pos_x: i32, pos_y: i32) -> None;
    def IsKeyDown(key: i32) -> bool;
    def IsKeyPressed(key: i32) -> bool;
    def GetFrameTime -> f32;
    def GetMouseX -> i32;
    def GetMouseY -> i32;
    def IsMouseButtonPressed(button: i32) -> bool;
    def DisableCursor -> None;
    def EnableCursor -> None;
    def rlMatrixMode(mode: i32) -> None;
    def rlLoadIdentity -> None;
    def rlPushMatrix -> None;
    def rlPopMatrix -> None;
    def rlTranslatef(x: f32, y: f32, z: f32) -> None;
    def rlRotatef(angle: f32, x: f32, y: f32, z: f32) -> None;
    def rlFrustum(left: f64, right: f64, bottom: f64, top: f64, znear: f64, zfar: f64) -> None;
    def rlOrtho(left: f64, right: f64, bottom: f64, top: f64, znear: f64, zfar: f64) -> None;
    def rlBegin(mode: i32) -> None;
    def rlEnd -> None;
    def rlVertex3f(x: f32, y: f32, z: f32) -> None;
    def rlColor4ub(r: u8, g: u8, b: u8, a: u8) -> None;
    def rlEnableDepthTest -> None;
    def rlSetLineWidth(width: f32) -> None;
    def EndMode3D -> None;
    def GetTime -> f64;
    def FileExists(fileName: str) -> bool;
    def LoadFileText(fileName: str) -> str;
    def TextToInteger(text: str) -> i32;
    def SaveFileText(fileName: str, text: str) -> bool;
}

glob RL_MODELVIEW: int = 0x1700,
     RL_PROJECTION: int = 0x1701,
     RL_LINES: int = 0x0001,
     RL_TRIANGLES: int = 0x0004;
def open_window(width: int, height: int, title: str);
def should_close -> bool;
def close_window;
def dt -> float;
def key_held(code: int) -> bool;
def key_tapped(code: int) -> bool;
def mouse_x -> float;
def mouse_y -> float;
def mouse_pressed(button: int) -> bool;
def lock_mouse;
def unlock_mouse;
def begin_frame(r: int, g: int, b: int);
def end_frame;
def end_camera(width: float, height: float);
def draw_fps(x: int, y: int);
def set_camera(px: float, py: float, pz: float, yaw_deg: float, pitch_deg: float, aspect: float);
def _quad(
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
);
def _shade(c: int, pct: int) -> int;
def draw_box(
    cx: float, cy: float, cz: float, sx: float, sy: float, sz: float, r: int, g: int, b: int
);
def draw_floor(half: int, step: float);
def clock -> float;
def bench_seconds -> float;
def write_bench_result(avg_fps: float, peak_fps: float, frame_count: int, seconds: float);

glob flock_mode: bool = FileExists(".flock");

glob bench: float = bench_seconds(),
     frames: int = 0,
     max_fps: float = 0.0;

glob KEY_W: int = 87,
     KEY_A: int = 65,
     KEY_S: int = 83,
     KEY_D: int = 68,
     KEY_SPACE: int = 32,
     KEY_RIGHT: int = 262,
     KEY_LEFT: int = 263,
     KEY_DOWN: int = 264,
     KEY_UP: int = 265,
     KEY_TAB: int = 258,
     MOUSE_LEFT: int = 0,
     DEG2RAD: float = 0.017453292519943295,
     px: float = 0.0,
     py: float = 2.0,
     pz: float = 12.0,
     yaw: float = 0.0,
     pitch: float = 0.0,
     fire_cd: float = 0.0,
     world_t: float = 0.0,
     score: int = 0,
     rng: int = 987654321,
     prev_mx: float = 0.0,
     prev_my: float = 0.0,
     mouse_warmup: int = 12,
     mouse_sens: float = 0.12,
     mouse_captured: bool = False;

obj Target {
    has x: float,
        y: float,
        z: float,
        base_y: float,
        phase: float,
        alive: bool;
}

obj Bullet {
    has x: float,
        y: float,
        z: float,
        vx: float,
        vy: float,
        vz: float,
        life: float;
}

obj Boid {
    has x: float,
        y: float,
        z: float,
        vx: float,
        vy: float,
        vz: float,
        ax: float,
        ay: float,
        az: float;
}

glob NUM_BOIDS: int = 256,
     BOID_VIEW2: float = 9.0,
     BOID_SEP2: float = 1.0,
     BOID_MAX_SPEED: float = 5.0,
     BOID_MIN_SPEED: float = 2.0;
def jcos(a: float) -> float;
def jsin(a: float) -> float;
def rand01 -> float;
def rand_range(lo: float, hi: float) -> float;
def jsqrt(v: float) -> float;
def spawn_boid -> Boid;
def update_flock(flock: list[Boid], step: float);
def draw_flock(flock: list[Boid]);
def respawn(t: Target);
def fire(bullets: list[Bullet]);
def update_bullets(bullets: list[Bullet], targets: list[Target], step: float);
def handle_input(step: float);

glob targets: list[Target] = [],
     bullets: list[Bullet] = [],
     flock: list[Boid] = [];

with entry {
    open_window(960, 600, "Jac Cube Shooter");

    for n in range(7) {
        t = Target(x=0.0, y=0.0, z=0.0, base_y=0.0, phase=0.0, alive=False);
        respawn(t);
        targets.append(t);
    }

    for n in range(24) {
        bullets.append(Bullet(x=0.0, y=0.0, z=0.0, vx=0.0, vy=0.0, vz=0.0, life=0.0));
    }

    if flock_mode {
        for n in range(NUM_BOIDS) {
            flock.append(spawn_boid());
        }
    }

    while not should_close() {
        step = dt();
        world_t += step;

        frames += 1;
        if step > 0.0 {
            inst = 1.0 / step;
            if inst > max_fps {
                max_fps = inst;
            }
        }

        handle_input(step);
        fire_cd -= step;
        if key_held(KEY_SPACE) and fire_cd <= 0.0 {
            fire(bullets);
            fire_cd = 0.14;
        }
        update_bullets(bullets, targets, step);

        ti = 0;
        while ti < len(targets) {
            t = targets[ti];
            t.y = t.base_y + 0.4 * jsin(world_t * 1.5 + t.phase);
            ti += 1;
        }
        if flock_mode {
            update_flock(flock, step);
        }

        begin_frame(15, 18, 28);
        set_camera(px, py, pz, yaw, pitch, 1.6);
        draw_floor(20, 1.5);

        ti = 0;
        while ti < len(targets) {
            t = targets[ti];
            if t.alive {
                draw_box(t.x, t.y, t.z, 1.4, 1.4, 1.4, 235, 80, 60);
            }
            ti += 1;
        }

        bi = 0;
        while bi < len(bullets) {
            b = bullets[bi];
            if b.life > 0.0 {
                draw_box(b.x, b.y, b.z, 0.22, 0.22, 0.22, 250, 220, 90);
            }
            bi += 1;
        }
        if flock_mode {
            draw_flock(flock);
        }

        end_camera(960.0, 600.0);
        draw_fps(10, 10);
        end_frame();

        if bench > 0.0 and clock() >= bench {
            break;
        }
    }

    if bench > 0.0 {
        elapsed = clock();
        avg_fps = 0.0;
        if elapsed > 0.0 {
            avg_fps = float(frames) / elapsed;
        }
        write_bench_result(avg_fps, max_fps, frames, elapsed);
    }

    close_window();
}
