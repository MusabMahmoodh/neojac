// Jac Cube Shooter - the C twin of shooter.jac.
//
// The same game as the Jac program, statement for statement, so the four twins
// can be read side by side and timed against each other. Like the others it
// binds raylib by declaring the entry points it calls - here as plain C
// prototypes, the counterpart of Jac's `import from vendor.raylib { def ... }`
// block - so it includes none of raylib's headers; the symbols resolve out of
// the raylib shared library in vendor/ when the program is linked and loaded.
// Rendering goes through the same scalar rlgl immediate-mode calls
// (rlVertex3f, rlColor4ub, rlTranslatef, ...), so every twin draws the same
// frame.
//
// Build and run it with `./demo.sh --c`, which compiles it with `neojac cc`.
//
// Controls: mouse or arrows aim (click or Tab captures the cursor for
// mouse-look), WASD move, Space fires, Tab releases the cursor, Esc quits.

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>

// ── raylib bindings (resolved from the raylib library at link time) ─────────
void InitWindow(int width, int height, const char *title);
bool WindowShouldClose(void);
void CloseWindow(void);
void BeginDrawing(void);
void EndDrawing(void);
void EndMode3D(void);
void DrawFPS(int pos_x, int pos_y);
float GetFrameTime(void);
bool IsKeyDown(int key);
bool IsKeyPressed(int key);
int GetMouseX(void);
int GetMouseY(void);
bool IsMouseButtonPressed(int button);
void DisableCursor(void);
void EnableCursor(void);
void rlClearColor(unsigned char r, unsigned char g, unsigned char b, unsigned char a);
void rlClearScreenBuffers(void);
void rlEnableDepthTest(void);
void rlMatrixMode(int mode);
void rlLoadIdentity(void);
void rlPushMatrix(void);
void rlPopMatrix(void);
void rlTranslatef(float x, float y, float z);
void rlRotatef(float angle, float x, float y, float z);
void rlFrustum(double left, double right, double bottom, double top, double znear, double zfar);
void rlOrtho(double left, double right, double bottom, double top, double znear, double zfar);
void rlBegin(int mode);
void rlEnd(void);
void rlVertex3f(float x, float y, float z);
void rlColor4ub(unsigned char r, unsigned char g, unsigned char b, unsigned char a);
void rlSetLineWidth(float width);
double GetTime(void);
bool FileExists(const char *file_name);
char *LoadFileText(const char *file_name);
int TextToInteger(const char *text);
bool SaveFileText(const char *file_name, const char *text);

// raylib's GL matrix modes and primitives (the Jac twin's globals).
#define RL_MODELVIEW 0x1700
#define RL_PROJECTION 0x1701
#define RL_LINES 0x0001
#define RL_TRIANGLES 0x0004

// A colour channel: shade() keeps its values in 0..255.
static inline unsigned char u8c(int v) {
    return (unsigned char)v;
}

// ── thin wrappers, one for one with the Jac source ──────────────────────────

// Open a window. No frame-rate cap is set, so the loop runs as fast as the
// machine allows.
static void open_window(int width, int height, const char *title) {
    InitWindow(width, height, title);
}

// True once the user closes the window or presses Esc.
static bool should_close(void) {
    return WindowShouldClose();
}

// Tear the window down.
static void close_window(void) {
    CloseWindow();
}

// Seconds the previous frame took, so motion is independent of frame rate.
static double dt(void) {
    return GetFrameTime();
}

// Whether a key is held this frame, by raylib's key code.
static bool key_held(int code) {
    return IsKeyDown(code);
}

// Whether a key went down this frame.
static bool key_tapped(int code) {
    return IsKeyPressed(code);
}

// The mouse's x in pixels, as a float.
static double mouse_x(void) {
    return (double)GetMouseX();
}

// The mouse's y in pixels, as a float.
static double mouse_y(void) {
    return (double)GetMouseY();
}

// Whether a mouse button went down this frame (0 is the left one).
static bool mouse_pressed(int button) {
    return IsMouseButtonPressed(button);
}

// Hide and lock the cursor, for relative mouse-look.
static void lock_mouse(void) {
    DisableCursor();
}

// Show and release the cursor.
static void unlock_mouse(void) {
    EnableCursor();
}

// Begin a frame: clear colour and depth to (r,g,b) and turn depth testing on.
static void begin_frame(int r, int g, int b) {
    BeginDrawing();
    rlClearColor(u8c(r), u8c(g), u8c(b), 255);
    rlClearScreenBuffers();
    rlEnableDepthTest();
}

// Present the frame.
static void end_frame(void) {
    EndDrawing();
}

// End the 3D pass and switch to a 2D overlay in screen pixels, origin top-left.
static void end_camera(double width, double height) {
    EndMode3D();
    rlMatrixMode(RL_PROJECTION);
    rlLoadIdentity();
    rlOrtho(0.0, width, height, 0.0, -1.0, 1.0);
    rlMatrixMode(RL_MODELVIEW);
    rlLoadIdentity();
}

// Draw raylib's own FPS counter at (x, y), as a 2D overlay.
static void draw_fps(int x, int y) {
    DrawFPS(x, y);
}

// Install a perspective camera at (cpx,cpy,cpz) looking with yaw and pitch, in
// degrees: a frustum of 60 degrees vertical field of view, and the inverse of
// the camera's placement as the view transform.
static void set_camera(float cpx, float cpy, float cpz, float yaw_deg, float pitch_deg, float aspect) {
    const double near = 0.05;
    const double far_plane = 400.0;
    const double top = near * 0.57735026;
    const double right = top * (double)aspect;
    rlMatrixMode(RL_PROJECTION);
    rlLoadIdentity();
    rlFrustum(-right, right, -top, top, near, far_plane);
    rlMatrixMode(RL_MODELVIEW);
    rlLoadIdentity();
    rlRotatef(-pitch_deg, 1.0f, 0.0f, 0.0f);
    rlRotatef(-yaw_deg, 0.0f, 1.0f, 0.0f);
    rlTranslatef(-cpx, -cpy, -cpz);
}

// Emit one quad (corners 0, 1, 2, 3, counter-clockwise) as two triangles.
static void quad(float x0, float y0, float z0, float x1, float y1, float z1,
                 float x2, float y2, float z2, float x3, float y3, float z3) {
    rlVertex3f(x0, y0, z0);
    rlVertex3f(x1, y1, z1);
    rlVertex3f(x2, y2, z2);
    rlVertex3f(x0, y0, z0);
    rlVertex3f(x2, y2, z2);
    rlVertex3f(x3, y3, z3);
}

// Scale a 0..255 channel by a percentage: cheap shading for a face.
static int shade(int c, int pct) {
    const int v = c * pct / 100;
    return v < 255 ? v : 255;
}

// Draw an axis-aligned box centred at (cx,cy,cz) of size (sx,sy,sz). Each face
// has a fixed brightness, so the cube reads as solid without lighting, and is
// wound counter-clockwise from outside for raylib's back-face culling.
static void draw_box(float cx, float cy, float cz, float sx, float sy, float sz, int r, int g, int b) {
    const float hx = sx * 0.5f;
    const float hy = sy * 0.5f;
    const float hz = sz * 0.5f;
    rlPushMatrix();
    rlTranslatef(cx, cy, cz);
    rlBegin(RL_TRIANGLES);

    rlColor4ub(u8c(shade(r, 100)), u8c(shade(g, 100)), u8c(shade(b, 100)), 255);
    quad(-hx, hy, hz, hx, hy, hz, hx, hy, -hz, -hx, hy, -hz);
    rlColor4ub(u8c(shade(r, 85)), u8c(shade(g, 85)), u8c(shade(b, 85)), 255);
    quad(-hx, -hy, hz, hx, -hy, hz, hx, hy, hz, -hx, hy, hz);
    quad(hx, -hy, -hz, -hx, -hy, -hz, -hx, hy, -hz, hx, hy, -hz);
    rlColor4ub(u8c(shade(r, 70)), u8c(shade(g, 70)), u8c(shade(b, 70)), 255);
    quad(hx, -hy, hz, hx, -hy, -hz, hx, hy, -hz, hx, hy, hz);
    quad(-hx, -hy, -hz, -hx, -hy, hz, -hx, hy, hz, -hx, hy, -hz);
    rlColor4ub(u8c(shade(r, 45)), u8c(shade(g, 45)), u8c(shade(b, 45)), 255);
    quad(-hx, -hy, -hz, hx, -hy, -hz, hx, -hy, hz, -hx, -hy, hz);

    rlEnd();
    rlPopMatrix();
}

// Draw a flat floor grid on y = 0: `half * 2` lines an axis, `step` apart.
static void draw_floor(int half, float step) {
    const float ext = (float)half * step;
    rlSetLineWidth(1.0f);
    rlBegin(RL_LINES);
    rlColor4ub(55, 60, 75, 255);
    for (int i = -half; i <= half; i += 1) {
        const float f = (float)i * step;
        rlVertex3f(f, 0.0f, -ext);
        rlVertex3f(f, 0.0f, ext);
        rlVertex3f(-ext, 0.0f, f);
        rlVertex3f(ext, 0.0f, f);
    }
    rlEnd();
}

// The benchmark's length in seconds, or 0 for ordinary play. demo.sh writes it
// to `.bench_seconds` before it starts the program; with no such file the game
// runs until its window is closed. It is read with raylib's own file helpers,
// as every twin reads it.
static double bench_seconds(void) {
    if (FileExists(".bench_seconds")) {
        return (double)TextToInteger(LoadFileText(".bench_seconds"));
    }
    return 0.0;
}

// Hand the benchmark's result back to demo.sh in `.bench_result`, written with
// raylib's SaveFileText as every twin writes it: the average and the highest
// frame rate, the frames drawn and the seconds they took.
static void write_bench_result(double avg_fps, double max_fps, int64_t frames, double seconds) {
    char buf[192];
    snprintf(buf, sizeof buf, "BENCH_RESULT %.6f %.6f %lld %.6f", avg_fps, max_fps, (long long)frames, seconds);
    SaveFileText(".bench_result", buf);
}

// ── key codes and game state (the Jac twin's globals) ───────────────────────

enum {
    KEY_W = 87,
    KEY_A = 65,
    KEY_S = 83,
    KEY_D = 68,
    KEY_SPACE = 32,
    KEY_RIGHT = 262,
    KEY_LEFT = 263,
    KEY_DOWN = 264,
    KEY_UP = 265,
    KEY_TAB = 258,
    MOUSE_LEFT = 0,
};

static const double DEG2RAD = 0.017453292519943295;

static double px = 0.0;
static double py = 2.0;
static double pz = 12.0;
static double yaw = 0.0;
static double pitch = 0.0;
static double fire_cd = 0.0;
static double world_t = 0.0;
static int score = 0;
static int64_t rng = 987654321;
static double prev_mx = 0.0;
static double prev_my = 0.0;
static int mouse_warmup = 12;
static double mouse_sens = 0.12;
static bool mouse_captured = false;

typedef struct {
    double x, y, z;
    double base_y;
    double phase;
    bool alive;
} Target;

typedef struct {
    double x, y, z;
    double vx, vy, vz;
    double life;
} Bullet;

// One member of the flock: its position, its velocity, and the acceleration
// the steering pass works out for it before the integration pass applies it.
typedef struct {
    double x, y, z;
    double vx, vy, vz;
    double ax, ay, az;
} Boid;

// The flock's size and its steering radii. Every boid looks at every other
// boid each frame: NUM_BOIDS * NUM_BOIDS neighbour tests of plain arithmetic,
// the part of a frame that runs outside raylib.
#define NUM_BOIDS 256
static const double BOID_VIEW2 = 9.0;
static const double BOID_SEP2 = 1.0;
static const double BOID_MAX_SPEED = 5.0;
static const double BOID_MIN_SPEED = 2.0;

// cos by a range-reduced Taylor series, good to about 1e-4 on the reduced range.
static double jcos(double a) {
    const double twopi = 6.283185307179586;
    const double pi = 3.141592653589793;
    while (a > pi) {
        a -= twopi;
    }
    while (a < -pi) {
        a += twopi;
    }
    const double x2 = a * a;
    const double x4 = x2 * x2;
    const double x6 = x4 * x2;
    const double x8 = x4 * x4;
    const double x10 = x8 * x2;
    const double x12 = x8 * x4;
    return 1.0 - x2 / 2.0 + x4 / 24.0 - x6 / 720.0 + x8 / 40320.0 - x10 / 3628800.0 + x12 / 479001600.0;
}

// sin(a) is cos(a - pi/2).
static double jsin(double a) {
    return jcos(a - 1.5707963267948796);
}

// A uniform pseudo-random float in [0, 1), from a 31-bit LCG.
static double rand01(void) {
    rng = (rng * 1103515245 + 12345) % 2147483648;
    return (double)rng / 2147483648.0;
}

// A random float in [lo, hi).
static double rand_range(double lo, double hi) {
    return lo + rand01() * (hi - lo);
}

// A square root by Newton's method, twelve iterations, as every twin takes it.
static double jsqrt(double v) {
    if (v <= 0.0) {
        return 0.0;
    }
    double g = v > 1.0 ? v : 1.0;
    for (int k = 0; k < 12; k += 1) {
        g = 0.5 * (g + v / g);
    }
    return g;
}

// A boid at a random place over the arena, with a random heading.
static Boid spawn_boid(void) {
    const double x = rand_range(-12.0, 12.0);
    const double y = rand_range(1.0, 7.0);
    const double z = rand_range(-14.0, 4.0);
    const double vx = rand_range(-2.0, 2.0);
    const double vy = rand_range(-0.5, 0.5);
    const double vz = rand_range(-2.0, 2.0);
    return (Boid){.x = x, .y = y, .z = z, .vx = vx, .vy = vy, .vz = vz, .ax = 0.0, .ay = 0.0, .az = 0.0};
}

// Steer every boid by separation, alignment and cohesion over the neighbours
// in its view radius, a pass over every pair, then integrate with a speed
// clamp. Steering reads positions and velocities and writes accelerations
// only, so the result does not depend on the order the boids are visited in.
static void update_flock(Boid *flock, size_t n, double step) {
    for (size_t i = 0; i < n; i += 1) {
        Boid *b = &flock[i];
        int cnt = 0;
        double cx = 0.0;
        double cy = 0.0;
        double cz = 0.0;
        double avx = 0.0;
        double avy = 0.0;
        double avz = 0.0;
        double sx = 0.0;
        double sy = 0.0;
        double sz = 0.0;
        for (size_t j = 0; j < n; j += 1) {
            if (j != i) {
                const Boid *o = &flock[j];
                const double dx = o->x - b->x;
                const double dy = o->y - b->y;
                const double dz = o->z - b->z;
                const double d2 = dx * dx + dy * dy + dz * dz;
                if (d2 < BOID_VIEW2) {
                    cnt += 1;
                    cx += o->x;
                    cy += o->y;
                    cz += o->z;
                    avx += o->vx;
                    avy += o->vy;
                    avz += o->vz;
                    if (d2 < BOID_SEP2) {
                        const double inv = 1.0 / (d2 + 0.01);
                        sx -= dx * inv;
                        sy -= dy * inv;
                        sz -= dz * inv;
                    }
                }
            }
        }
        double ax = 0.0;
        double ay = 0.0;
        double az = 0.0;
        if (cnt > 0) {
            const double fc = (double)cnt;
            ax = (cx / fc - b->x) * 0.6 + (avx / fc - b->vx) * 0.9 + sx * 1.5;
            ay = (cy / fc - b->y) * 0.6 + (avy / fc - b->vy) * 0.9 + sy * 1.5;
            az = (cz / fc - b->z) * 0.6 + (avz / fc - b->vz) * 0.9 + sz * 1.5;
        }
        b->ax = ax - b->x * 0.08;
        b->ay = ay + (4.0 - b->y) * 0.3;
        b->az = az - (b->z + 5.0) * 0.08;
    }
    for (size_t i = 0; i < n; i += 1) {
        Boid *b = &flock[i];
        b->vx += b->ax * step;
        b->vy += b->ay * step;
        b->vz += b->az * step;
        const double s2 = b->vx * b->vx + b->vy * b->vy + b->vz * b->vz;
        if (s2 > BOID_MAX_SPEED * BOID_MAX_SPEED) {
            const double k = BOID_MAX_SPEED / jsqrt(s2);
            b->vx *= k;
            b->vy *= k;
            b->vz *= k;
        } else if (s2 > 0.0 && s2 < BOID_MIN_SPEED * BOID_MIN_SPEED) {
            const double k = BOID_MIN_SPEED / jsqrt(s2);
            b->vx *= k;
            b->vy *= k;
            b->vz *= k;
        }
        b->x += b->vx * step;
        b->y += b->vy * step;
        b->z += b->vz * step;
    }
}

// Draw each boid as a short streak trailing back along its velocity.
static void draw_flock(const Boid *flock, size_t n) {
    rlBegin(RL_LINES);
    rlColor4ub(120, 200, 255, 255);
    for (size_t i = 0; i < n; i += 1) {
        const Boid *b = &flock[i];
        rlVertex3f((float)b->x, (float)b->y, (float)b->z);
        rlVertex3f((float)(b->x - b->vx * 0.12), (float)(b->y - b->vy * 0.12), (float)(b->z - b->vz * 0.12));
    }
    rlEnd();
}

// Place a target somewhere in the arena in front of the player.
static void respawn(Target *t) {
    t->x = rand_range(-14.0, 14.0);
    t->base_y = rand_range(1.0, 5.0);
    t->z = rand_range(-16.0, 2.0);
    t->phase = rand_range(0.0, 6.28);
    t->y = t->base_y;
    t->alive = true;
}

// Fire a bullet from the eye along the aim, in a slot of the pool that is free.
static void fire(Bullet *bullets, size_t n) {
    const double yaw_r = yaw * DEG2RAD;
    const double pitch_r = pitch * DEG2RAD;
    const double cp = jcos(pitch_r);
    const double dx = -jsin(yaw_r) * cp;
    const double dy = jsin(pitch_r);
    const double dz = -jcos(yaw_r) * cp;
    const double speed = 40.0;
    for (size_t i = 0; i < n; i += 1) {
        Bullet *b = &bullets[i];
        if (b->life <= 0.0) {
            b->x = px;
            b->y = py;
            b->z = pz;
            b->vx = dx * speed;
            b->vy = dy * speed;
            b->vz = dz * speed;
            b->life = 2.0;
            return;
        }
    }
}

// Advance the bullets, resolve their hits against the targets, and keep score.
static void update_bullets(Bullet *bullets, size_t nb, Target *targets, size_t nt, double step) {
    for (size_t bi = 0; bi < nb; bi += 1) {
        Bullet *b = &bullets[bi];
        if (b->life > 0.0) {
            b->x += b->vx * step;
            b->y += b->vy * step;
            b->z += b->vz * step;
            b->life -= step;
            for (size_t ti = 0; ti < nt; ti += 1) {
                Target *t = &targets[ti];
                if (t->alive) {
                    const double ddx = b->x - t->x;
                    const double ddy = b->y - t->y;
                    const double ddz = b->z - t->z;
                    if (ddx * ddx + ddy * ddy + ddz * ddz < 1.4) {
                        t->alive = false;
                        b->life = 0.0;
                        score += 1;
                        respawn(t);
                    }
                }
            }
        }
    }
}

// Read the keyboard and the mouse, and move and turn the camera for this frame.
static void handle_input(double step) {
    const double turn = 90.0 * step;

    if (key_tapped(KEY_TAB)) {
        if (mouse_captured) {
            unlock_mouse();
            mouse_captured = false;
        } else {
            lock_mouse();
            mouse_captured = true;
            mouse_warmup = 8;
        }
    }
    if (!mouse_captured && mouse_pressed(MOUSE_LEFT)) {
        lock_mouse();
        mouse_captured = true;
        mouse_warmup = 8;
    }

    if (key_held(KEY_LEFT)) {
        yaw += turn;
    }
    if (key_held(KEY_RIGHT)) {
        yaw -= turn;
    }
    if (key_held(KEY_UP)) {
        pitch += turn;
    }
    if (key_held(KEY_DOWN)) {
        pitch -= turn;
    }

    if (mouse_captured) {
        const double mx = mouse_x();
        const double my = mouse_y();
        if (mouse_warmup > 0) {
            mouse_warmup -= 1;
        } else {
            const double ddx = mx - prev_mx;
            const double ddy = my - prev_my;
            if (ddx < 150.0 && ddx > -150.0 && ddy < 150.0 && ddy > -150.0) {
                yaw -= ddx * mouse_sens;
                pitch -= ddy * mouse_sens;
            }
        }
        prev_mx = mx;
        prev_my = my;
    }

    if (pitch > 85.0) {
        pitch = 85.0;
    }
    if (pitch < -85.0) {
        pitch = -85.0;
    }

    const double yaw_r = yaw * DEG2RAD;
    const double fwd_x = -jsin(yaw_r);
    const double fwd_z = -jcos(yaw_r);
    const double rgt_x = jcos(yaw_r);
    const double rgt_z = -jsin(yaw_r);
    const double move = 8.0 * step;
    if (key_held(KEY_W)) {
        px += fwd_x * move;
        pz += fwd_z * move;
    }
    if (key_held(KEY_S)) {
        px -= fwd_x * move;
        pz -= fwd_z * move;
    }
    if (key_held(KEY_D)) {
        px += rgt_x * move;
        pz += rgt_z * move;
    }
    if (key_held(KEY_A)) {
        px -= rgt_x * move;
        pz -= rgt_z * move;
    }
}

#define NUM_TARGETS 7
#define NUM_BULLETS 24

static Target targets[NUM_TARGETS];
static Bullet bullets[NUM_BULLETS];
static Boid flock[NUM_BOIDS];

int main(void) {
    open_window(960, 600, "Jac Cube Shooter (C)");

    for (size_t i = 0; i < NUM_TARGETS; i += 1) {
        targets[i] = (Target){.x = 0.0, .y = 0.0, .z = 0.0, .base_y = 0.0, .phase = 0.0, .alive = false};
        respawn(&targets[i]);
    }

    for (size_t i = 0; i < NUM_BULLETS; i += 1) {
        bullets[i] = (Bullet){.x = 0.0, .y = 0.0, .z = 0.0, .vx = 0.0, .vy = 0.0, .vz = 0.0, .life = 0.0};
    }

    // Flock mode, off unless `.flock` exists: spawn the flock that update_flock
    // steers every frame. Without the file the game is the plain shooter.
    const bool flock_on = FileExists(".flock");
    if (flock_on) {
        for (size_t i = 0; i < NUM_BOIDS; i += 1) {
            flock[i] = spawn_boid();
        }
    }

    const double bench = bench_seconds();
    int64_t frames = 0;
    double max_fps = 0.0;

    while (!should_close()) {
        const double step = dt();
        world_t += step;

        frames += 1;
        if (step > 0.0) {
            const double inst = 1.0 / step;
            if (inst > max_fps) {
                max_fps = inst;
            }
        }

        handle_input(step);
        fire_cd -= step;
        if (key_held(KEY_SPACE) && fire_cd <= 0.0) {
            fire(bullets, NUM_BULLETS);
            fire_cd = 0.14;
        }
        update_bullets(bullets, NUM_BULLETS, targets, NUM_TARGETS, step);

        for (size_t i = 0; i < NUM_TARGETS; i += 1) {
            Target *t = &targets[i];
            t->y = t->base_y + 0.4 * jsin(world_t * 1.5 + t->phase);
        }
        if (flock_on) {
            update_flock(flock, NUM_BOIDS, step);
        }

        begin_frame(15, 18, 28);
        set_camera((float)px, (float)py, (float)pz, (float)yaw, (float)pitch, 1.6f);
        draw_floor(20, 1.5f);

        for (size_t i = 0; i < NUM_TARGETS; i += 1) {
            const Target *t = &targets[i];
            if (t->alive) {
                draw_box((float)t->x, (float)t->y, (float)t->z, 1.4f, 1.4f, 1.4f, 235, 80, 60);
            }
        }

        for (size_t i = 0; i < NUM_BULLETS; i += 1) {
            const Bullet *b = &bullets[i];
            if (b->life > 0.0) {
                draw_box((float)b->x, (float)b->y, (float)b->z, 0.22f, 0.22f, 0.22f, 250, 220, 90);
            }
        }
        if (flock_on) {
            draw_flock(flock, NUM_BOIDS);
        }

        end_camera(960.0, 600.0);
        draw_fps(10, 10);
        end_frame();

        if (bench > 0.0 && GetTime() >= bench) {
            break;
        }
    }

    if (bench > 0.0) {
        const double elapsed = GetTime();
        const double avg_fps = elapsed > 0.0 ? (double)frames / elapsed : 0.0;
        write_bench_result(avg_fps, max_fps, frames, elapsed);
    }

    close_window();
    return 0;
}
