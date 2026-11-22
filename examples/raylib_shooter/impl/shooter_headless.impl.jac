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

impl rand01(w: &mut World) -> float {
    w.rng = (w.rng * 1103515245 + 12345) % 2147483648;
    return float(w.rng) / 2147483648.0;
}

impl rand_range(w: &mut World, lo: float, hi: float) -> float {
    return lo + rand01(w) * (hi - lo);
}

impl respawn(w: &mut World, i: int) {
    w.tx[i] = rand_range(w, -14.0, 14.0);
    w.tbase[i] = rand_range(w, 1.0, 5.0);
    w.tz[i] = rand_range(w, -16.0, 2.0);
    w.tphase[i] = rand_range(w, 0.0, 6.28);
    w.ty[i] = w.tbase[i];
    w.talive[i] = True;
}

impl fire(w: &mut World) {
    yaw_r = w.yaw * DEG2RAD;
    pitch_r = w.pitch * DEG2RAD;
    cp = jcos(pitch_r);
    dx = -jsin(yaw_r) * cp;
    dy = jsin(pitch_r);
    dz = -jcos(yaw_r) * cp;
    speed = 40.0;
    for i in range(len(w.blife)) {
        if w.blife[i] <= 0.0 {
            w.bpx[i] = w.px;
            w.bpy[i] = w.py;
            w.bpz[i] = w.pz;
            w.bvx[i] = dx * speed;
            w.bvy[i] = dy * speed;
            w.bvz[i] = dz * speed;
            w.blife[i] = 2.0;
            w.shots += 1;
            return;
        }
    }
}

impl update_bullets(w: &mut World, step: float) {
    for bi in range(len(w.blife)) {
        if w.blife[bi] > 0.0 {
            w.bpx[bi] += w.bvx[bi] * step;
            w.bpy[bi] += w.bvy[bi] * step;
            w.bpz[bi] += w.bvz[bi] * step;
            w.blife[bi] -= step;
            for ti in range(len(w.talive)) {
                if w.talive[ti] {
                    ddx = w.bpx[bi] - w.tx[ti];
                    ddy = w.bpy[bi] - w.ty[ti];
                    ddz = w.bpz[bi] - w.tz[ti];
                    if ddx * ddx + ddy * ddy + ddz * ddz < 1.4 {
                        w.talive[ti] = False;
                        w.blife[bi] = 0.0;
                        w.score += 1;
                        respawn(w, ti);
                    }
                }
            }
        }
    }
}

impl bob_targets(w: &mut World) {
    for ti in range(len(w.talive)) {
        w.ty[ti] = w.tbase[ti] + 0.4 * jsin(w.world_t * 1.5 + w.tphase[ti]);
    }
}

impl sim_input(w: &mut World, frame: int, step: float) {
    turn = 90.0 * step;
    w.yaw += turn;
    if w.yaw >= 360.0 {
        w.yaw -= 360.0;
    }
    tilt = (frame // 420) % 3;
    if tilt == 0 {
        w.pitch += turn * 0.25;
    } elif tilt == 1 {
        w.pitch -= turn * 0.25;
    }
    if w.pitch > 85.0 {
        w.pitch = 85.0;
    }
    if w.pitch < -85.0 {
        w.pitch = -85.0;
    }

    yaw_r = w.yaw * DEG2RAD;
    fwd_x = -jsin(yaw_r);
    fwd_z = -jcos(yaw_r);
    rgt_x = jcos(yaw_r);
    rgt_z = -jsin(yaw_r);
    move = 8.0 * step;
    stride = (frame // 240) % 4;
    if stride == 0 {
        w.px += fwd_x * move;
        w.pz += fwd_z * move;
    } elif stride == 1 {
        w.px += rgt_x * move;
        w.pz += rgt_z * move;
    } elif stride == 2 {
        w.px -= fwd_x * move;
        w.pz -= fwd_z * move;
    } else {
        w.px -= rgt_x * move;
        w.pz -= rgt_z * move;
    }
    if w.px > 20.0 {
        w.px = 20.0;
    }
    if w.px < -20.0 {
        w.px = -20.0;
    }
    if w.pz > 20.0 {
        w.pz = 20.0;
    }
    if w.pz < -20.0 {
        w.pz = -20.0;
    }
}

impl mix3(digest: int, x: float, y: float, z: float) -> int {
    ix = int(x * 8.0) + 8000;
    iy = int(y * 8.0) + 8000;
    iz = int(z * 8.0) + 8000;
    return (((digest * 31 + ix) * 31 + iy) * 31 + iz) % DIGEST_MOD;
}

impl quad(
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
) -> int {
    digest = mix3(digest, x0, y0, z0);
    digest = mix3(digest, x1, y1, z1);
    digest = mix3(digest, x2, y2, z2);
    digest = mix3(digest, x0, y0, z0);
    digest = mix3(digest, x2, y2, z2);
    digest = mix3(digest, x3, y3, z3);
    return digest;
}

impl shade(c: int, pct: int) -> int {
    v = c * pct // 100;
    return v if v < 255 else 255;
}

impl mix_color(digest: int, r: int, g: int, b: int, pct: int) -> int {
    return (((digest * 31 + shade(r, pct)) * 31 + shade(g, pct)) * 31 + shade(b, pct)) % DIGEST_MOD;
}

impl emit_box(
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
) -> int {
    hx = sx * 0.5;
    hy = sy * 0.5;
    hz = sz * 0.5;
    x0 = cx - hx;
    x1 = cx + hx;
    y0 = cy - hy;
    y1 = cy + hy;
    z0 = cz - hz;
    z1 = cz + hz;

    digest = mix_color(digest, r, g, b, 100);
    digest = quad(digest, x0, y1, z1, x1, y1, z1, x1, y1, z0, x0, y1, z0);
    digest = mix_color(digest, r, g, b, 85);
    digest = quad(digest, x0, y0, z1, x1, y0, z1, x1, y1, z1, x0, y1, z1);
    digest = quad(digest, x1, y0, z0, x0, y0, z0, x0, y1, z0, x1, y1, z0);
    digest = mix_color(digest, r, g, b, 70);
    digest = quad(digest, x1, y0, z1, x1, y0, z0, x1, y1, z0, x1, y1, z1);
    digest = quad(digest, x0, y0, z0, x0, y0, z1, x0, y1, z1, x0, y1, z0);
    digest = mix_color(digest, r, g, b, 45);
    digest = quad(digest, x0, y0, z0, x1, y0, z0, x1, y0, z1, x0, y0, z1);
    return digest;
}

impl emit_floor(digest: int, half: int, step: float) -> int {
    ext = float(half) * step;
    i = -half;
    while i <= half {
        f = float(i) * step;
        digest = mix3(digest, f, 0.0, -ext);
        digest = mix3(digest, f, 0.0, ext);
        digest = mix3(digest, -ext, 0.0, f);
        digest = mix3(digest, ext, 0.0, f);
        i += 1;
    }
    return digest;
}

impl emit_frame(w: &World, digest: int) -> int {
    digest = mix3(digest, w.px, w.py, w.pz);
    digest = mix3(digest, w.yaw, w.pitch, 1.6);
    digest = emit_floor(digest, 20, 1.5);
    for ti in range(len(w.talive)) {
        if w.talive[ti] {
            digest = emit_box(digest, w.tx[ti], w.ty[ti], w.tz[ti], 1.4, 1.4, 1.4, 235, 80, 60);
        }
    }
    for bi in range(len(w.blife)) {
        if w.blife[bi] > 0.0 {
            digest = emit_box(
                digest, w.bpx[bi], w.bpy[bi], w.bpz[bi], 0.22, 0.22, 0.22, 250, 220, 90
            );
        }
    }
    return digest;
}

impl run(frames_n: int) -> int {
    w: own World = World();
    for i in range(7) {
        w.tx.append(0.0);
        w.ty.append(0.0);
        w.tz.append(0.0);
        w.tbase.append(0.0);
        w.tphase.append(0.0);
        w.talive.append(False);
        respawn(&mut w, i);
    }
    for i in range(24) {
        w.bpx.append(0.0);
        w.bpy.append(0.0);
        w.bpz.append(0.0);
        w.bvx.append(0.0);
        w.bvy.append(0.0);
        w.bvz.append(0.0);
        w.blife.append(0.0);
    }

    step = 1.0 / 240.0;
    digest = 0;
    frame = 0;
    while frame < frames_n {
        w.world_t += step;
        sim_input(&mut w, frame, step);
        w.fire_cd -= step;
        if w.fire_cd <= 0.0 {
            fire(&mut w);
            w.fire_cd = 0.14;
        }
        update_bullets(&mut w, step);
        bob_targets(&mut w);
        digest = emit_frame(&w, digest);
        frame += 1;
    }

    print("score:" + str(w.score) + " shots:" + str(w.shots));
    return (digest * 31 + w.score) % DIGEST_MOD;
}
