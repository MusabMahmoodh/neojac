impl open_window(width: int, height: int, title: str) {
    InitWindow(width, height, title);
}

impl should_close -> bool {
    return WindowShouldClose();
}

impl close_window {
    CloseWindow();
}

impl dt -> float {
    return float(GetFrameTime());
}

impl key_held(code: int) -> bool {
    return IsKeyDown(code);
}

impl key_tapped(code: int) -> bool {
    return IsKeyPressed(code);
}

impl mouse_x -> float {
    return float(GetMouseX());
}

impl mouse_y -> float {
    return float(GetMouseY());
}

impl mouse_pressed(button: int) -> bool {
    return IsMouseButtonPressed(button);
}

impl lock_mouse {
    DisableCursor();
}

impl unlock_mouse {
    EnableCursor();
}

impl begin_frame(r: int, g: int, b: int) {
    BeginDrawing();
    rlClearColor(r, g, b, 255);
    rlClearScreenBuffers();
    rlEnableDepthTest();
}

impl end_frame {
    EndDrawing();
}

impl end_camera(width: float, height: float) {
    EndMode3D();
    rlMatrixMode(RL_PROJECTION);
    rlLoadIdentity();
    rlOrtho(0.0, width, height, 0.0, -1.0, 1.0);
    rlMatrixMode(RL_MODELVIEW);
    rlLoadIdentity();
}

impl draw_fps(x: int, y: int) {
    DrawFPS(x, y);
}

impl set_camera(px: float, py: float, pz: float, yaw_deg: float, pitch_deg: float, aspect: float) {
    near = 0.05;
    far_plane = 400.0;
    top = near * 0.57735026;
    right = top * aspect;
    rlMatrixMode(RL_PROJECTION);
    rlLoadIdentity();
    rlFrustum(-right, right, -top, top, near, far_plane);
    rlMatrixMode(RL_MODELVIEW);
    rlLoadIdentity();
    rlRotatef(-pitch_deg, 1.0, 0.0, 0.0);
    rlRotatef(-yaw_deg, 0.0, 1.0, 0.0);
    rlTranslatef(-px, -py, -pz);
}

impl _quad(
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
) {
    rlVertex3f(x0, y0, z0);
    rlVertex3f(x1, y1, z1);
    rlVertex3f(x2, y2, z2);
    rlVertex3f(x0, y0, z0);
    rlVertex3f(x2, y2, z2);
    rlVertex3f(x3, y3, z3);
}

impl _shade(c: int, pct: int) -> int {
    v = c * pct // 100;
    return v if v < 255 else 255;
}

impl draw_box(
    cx: float, cy: float, cz: float, sx: float, sy: float, sz: float, r: int, g: int, b: int
) {
    hx = sx * 0.5;
    hy = sy * 0.5;
    hz = sz * 0.5;
    rlPushMatrix();
    rlTranslatef(cx, cy, cz);
    rlBegin(RL_TRIANGLES);

    rlColor4ub(_shade(r, 100), _shade(g, 100), _shade(b, 100), 255);
    _quad(-hx, hy, hz, hx, hy, hz, hx, hy, -hz, -hx, hy, -hz);
    rlColor4ub(_shade(r, 85), _shade(g, 85), _shade(b, 85), 255);
    _quad(-hx, -hy, hz, hx, -hy, hz, hx, hy, hz, -hx, hy, hz);
    _quad(hx, -hy, -hz, -hx, -hy, -hz, -hx, hy, -hz, hx, hy, -hz);
    rlColor4ub(_shade(r, 70), _shade(g, 70), _shade(b, 70), 255);
    _quad(hx, -hy, hz, hx, -hy, -hz, hx, hy, -hz, hx, hy, hz);
    _quad(-hx, -hy, -hz, -hx, -hy, hz, -hx, hy, hz, -hx, hy, -hz);
    rlColor4ub(_shade(r, 45), _shade(g, 45), _shade(b, 45), 255);
    _quad(-hx, -hy, -hz, hx, -hy, -hz, hx, -hy, hz, -hx, -hy, hz);

    rlEnd();
    rlPopMatrix();
}

impl draw_floor(half: int, step: float) {
    ext = float(half) * step;
    rlSetLineWidth(1.0);
    rlBegin(RL_LINES);
    rlColor4ub(55, 60, 75, 255);
    i = -half;
    while i <= half {
        f = float(i) * step;
        rlVertex3f(f, 0.0, -ext);
        rlVertex3f(f, 0.0, ext);
        rlVertex3f(-ext, 0.0, f);
        rlVertex3f(ext, 0.0, f);
        i += 1;
    }
    rlEnd();
}

impl clock -> float {
    return GetTime();
}

impl bench_seconds -> float {
    if FileExists(".bench_seconds") {
        return float(TextToInteger(LoadFileText(".bench_seconds")));
    }
    return 0.0;
}

impl write_bench_result(avg_fps: float, peak_fps: float, frame_count: int, seconds: float) {
    SaveFileText(".bench_result", f"BENCH_RESULT {avg_fps} {peak_fps} {frame_count} {seconds}");
}

impl jcos(a: float) -> float {
    twopi = 6.283185307179586;
    pi = 3.141592653589793;
    while a > pi {
        a -= twopi;
    }
    while a < -pi {
        a += twopi;
    }
    x2 = a * a;
    x4 = x2 * x2;
    x6 = x4 * x2;
    x8 = x4 * x4;
    x10 = x8 * x2;
    x12 = x8 * x4;
    return 1.0
        - x2 / 2.0
        + x4 / 24.0
        - x6 / 720.0
        + x8 / 40320.0
        - x10 / 3628800.0
        + x12 / 479001600.0;
}

impl jsin(a: float) -> float {
    return jcos(a - 1.5707963267948796);
}

impl rand01 -> float {
    rng = (rng * 1103515245 + 12345) % 2147483648;
    return float(rng) / 2147483648.0;
}

impl rand_range(lo: float, hi: float) -> float {
    return lo + rand01() * (hi - lo);
}

impl jsqrt(v: float) -> float {
    if v <= 0.0 {
        return 0.0;
    }
    g = v if v > 1.0 else 1.0;
    k = 0;
    while k < 12 {
        g = 0.5 * (g + v / g);
        k += 1;
    }
    return g;
}

impl spawn_boid -> Boid {
    x = rand_range(-12.0, 12.0);
    y = rand_range(1.0, 7.0);
    z = rand_range(-14.0, 4.0);
    vx = rand_range(-2.0, 2.0);
    vy = rand_range(-0.5, 0.5);
    vz = rand_range(-2.0, 2.0);
    return Boid(x=x, y=y, z=z, vx=vx, vy=vy, vz=vz, ax=0.0, ay=0.0, az=0.0);
}

impl update_flock(flock: list[Boid], step: float) {
    n = len(flock);
    i = 0;
    while i < n {
        b = flock[i];
        cnt = 0;
        cx = 0.0;
        cy = 0.0;
        cz = 0.0;
        avx = 0.0;
        avy = 0.0;
        avz = 0.0;
        sx = 0.0;
        sy = 0.0;
        sz = 0.0;
        j = 0;
        while j < n {
            if j != i {
                o = flock[j];
                dx = o.x - b.x;
                dy = o.y - b.y;
                dz = o.z - b.z;
                d2 = dx * dx + dy * dy + dz * dz;
                if d2 < BOID_VIEW2 {
                    cnt += 1;
                    cx += o.x;
                    cy += o.y;
                    cz += o.z;
                    avx += o.vx;
                    avy += o.vy;
                    avz += o.vz;
                    if d2 < BOID_SEP2 {
                        inv = 1.0 / (d2 + 0.01);
                        sx -= dx * inv;
                        sy -= dy * inv;
                        sz -= dz * inv;
                    }
                }
            }
            j += 1;
        }
        ax = 0.0;
        ay = 0.0;
        az = 0.0;
        if cnt > 0 {
            fc = float(cnt);
            ax = (cx / fc - b.x) * 0.6 + (avx / fc - b.vx) * 0.9 + sx * 1.5;
            ay = (cy / fc - b.y) * 0.6 + (avy / fc - b.vy) * 0.9 + sy * 1.5;
            az = (cz / fc - b.z) * 0.6 + (avz / fc - b.vz) * 0.9 + sz * 1.5;
        }
        b.ax = ax - b.x * 0.08;
        b.ay = ay + (4.0 - b.y) * 0.3;
        b.az = az - (b.z + 5.0) * 0.08;
        i += 1;
    }
    i = 0;
    while i < n {
        b = flock[i];
        b.vx += b.ax * step;
        b.vy += b.ay * step;
        b.vz += b.az * step;
        s2 = b.vx * b.vx + b.vy * b.vy + b.vz * b.vz;
        if s2 > BOID_MAX_SPEED * BOID_MAX_SPEED {
            k = BOID_MAX_SPEED / jsqrt(s2);
            b.vx *= k;
            b.vy *= k;
            b.vz *= k;
        } elif s2 > 0.0 and s2 < BOID_MIN_SPEED * BOID_MIN_SPEED {
            k = BOID_MIN_SPEED / jsqrt(s2);
            b.vx *= k;
            b.vy *= k;
            b.vz *= k;
        }
        b.x += b.vx * step;
        b.y += b.vy * step;
        b.z += b.vz * step;
        i += 1;
    }
}

impl draw_flock(flock: list[Boid]) {
    rlBegin(RL_LINES);
    rlColor4ub(120, 200, 255, 255);
    i = 0;
    while i < len(flock) {
        b = flock[i];
        rlVertex3f(b.x, b.y, b.z);
        rlVertex3f(b.x - b.vx * 0.12, b.y - b.vy * 0.12, b.z - b.vz * 0.12);
        i += 1;
    }
    rlEnd();
}

impl respawn(t: Target) {
    t.x = rand_range(-14.0, 14.0);
    t.base_y = rand_range(1.0, 5.0);
    t.z = rand_range(-16.0, 2.0);
    t.phase = rand_range(0.0, 6.28);
    t.y = t.base_y;
    t.alive = True;
}

impl fire(bullets: list[Bullet]) {
    yaw_r = yaw * DEG2RAD;
    pitch_r = pitch * DEG2RAD;
    cp = jcos(pitch_r);
    dx = -jsin(yaw_r) * cp;
    dy = jsin(pitch_r);
    dz = -jcos(yaw_r) * cp;
    speed = 40.0;
    i = 0;
    while i < len(bullets) {
        b = bullets[i];
        if b.life <= 0.0 {
            b.x = px;
            b.y = py;
            b.z = pz;
            b.vx = dx * speed;
            b.vy = dy * speed;
            b.vz = dz * speed;
            b.life = 2.0;
            return;
        }
        i += 1;
    }
}

impl update_bullets(bullets: list[Bullet], targets: list[Target], step: float) {
    bi = 0;
    while bi < len(bullets) {
        b = bullets[bi];
        if b.life > 0.0 {
            b.x += b.vx * step;
            b.y += b.vy * step;
            b.z += b.vz * step;
            b.life -= step;
            ti = 0;
            while ti < len(targets) {
                t = targets[ti];
                if t.alive {
                    ddx = b.x - t.x;
                    ddy = b.y - t.y;
                    ddz = b.z - t.z;
                    if ddx * ddx + ddy * ddy + ddz * ddz < 1.4 {
                        t.alive = False;
                        b.life = 0.0;
                        score += 1;
                        respawn(t);
                    }
                }
                ti += 1;
            }
        }
        bi += 1;
    }
}

impl handle_input(step: float) {
    turn = 90.0 * step;

    if key_tapped(KEY_TAB) {
        if mouse_captured {
            unlock_mouse();
            mouse_captured = False;
        } else {
            lock_mouse();
            mouse_captured = True;
            mouse_warmup = 8;
        }
    }
    if not mouse_captured and mouse_pressed(MOUSE_LEFT) {
        lock_mouse();
        mouse_captured = True;
        mouse_warmup = 8;
    }

    if key_held(KEY_LEFT) {
        yaw += turn;
    }
    if key_held(KEY_RIGHT) {
        yaw -= turn;
    }
    if key_held(KEY_UP) {
        pitch += turn;
    }
    if key_held(KEY_DOWN) {
        pitch -= turn;
    }

    if mouse_captured {
        mx = mouse_x();
        my = mouse_y();
        if mouse_warmup > 0 {
            mouse_warmup -= 1;
        } else {
            ddx = mx - prev_mx;
            ddy = my - prev_my;
            if ddx < 150.0 and ddx > -150.0 and ddy < 150.0 and ddy > -150.0 {
                yaw -= ddx * mouse_sens;
                pitch -= ddy * mouse_sens;
            }
        }
        prev_mx = mx;
        prev_my = my;
    }

    if pitch > 85.0 {
        pitch = 85.0;
    }
    if pitch < -85.0 {
        pitch = -85.0;
    }

    yaw_r = yaw * DEG2RAD;
    fwd_x = -jsin(yaw_r);
    fwd_z = -jcos(yaw_r);
    rgt_x = jcos(yaw_r);
    rgt_z = -jsin(yaw_r);
    move = 8.0 * step;
    if key_held(KEY_W) {
        px += fwd_x * move;
        pz += fwd_z * move;
    }
    if key_held(KEY_S) {
        px -= fwd_x * move;
        pz -= fwd_z * move;
    }
    if key_held(KEY_D) {
        px += rgt_x * move;
        pz += rgt_z * move;
    }
    if key_held(KEY_A) {
        px -= rgt_x * move;
        pz -= rgt_z * move;
    }
}
