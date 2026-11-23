"""Adercos do cais (PROVISORIO): caixotes, barris, rolo de corda, lampiao, rede, placa, balde, remo, boia, cabana, pegada.
Metros, espaco Godot, origem = base (ou ponto de uso). Uso: blender --background --factory-startup --python build_props.py -- --blend X --glb-dir Y
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bmesh
from mathutils import Vector
from envlib import (REPO, Asset, arg_value, gbox, gcyl, gsph, lathe, materials, reset_scene, save_all, sweep)
from rbart import torus


def crate(M, info, glb, name, size, peach, seed):
    """Caixote ripado: miolo escuro, ripas levemente desalinhadas, cantoneiras. Origem na base."""
    a = Asset(name, M, seed)
    sx, sy, sz = size
    bm = bmesh.new()
    gbox(bm, (0, sy / 2 - 0.01, 0), (sx - 0.1, sy - 0.04, sz - 0.1))
    a.part("Core", bm, "mat_env_wood_dark", jit=0.2, ao=0.5)
    bm = bmesh.new()
    nsl = 4 if sy > 0.6 else 3
    h = (sy - 0.06) / nsl
    for k in range(nsl):
        y = 0.04 + h * (k + 0.5) + 0.01
        for side in (-1, 1):
            before = set(bm.verts)
            gbox(bm, (0, y, side * (sz / 2 - 0.018)), (sx - 0.06 + a.rng.uniform(-0.01, 0.01), h - 0.022, 0.034),
                 rz=a.rng.uniform(-0.8, 0.8))
            a.paint_new(bm, before, jit=0.22, ao=0.2, ao_h=sy)
            before = set(bm.verts)
            gbox(bm, (side * (sx / 2 - 0.018), y, 0), (0.034, h - 0.022, sz - 0.06 + a.rng.uniform(-0.01, 0.01)),
                 rx=a.rng.uniform(-0.8, 0.8))
            a.paint_new(bm, before, jit=0.22, ao=0.2, ao_h=sy)
    a.part("Slats", bm, "mat_env_wood_light", bevel=0.007, bseg=1, paint=False)
    bm = bmesh.new()
    for ix in (-1, 1):
        for iz in (-1, 1):
            gbox(bm, (ix * (sx / 2 - 0.04), sy / 2, iz * (sz / 2 - 0.04)), (0.08, sy, 0.08))
    gbox(bm, (0, 0.03, 0), (sx - 0.02, 0.05, sz - 0.02))
    a.part("Frame", bm, "mat_env_wood_deck", bevel=0.01, bseg=2, jit=0.18, ao=0.3, ao_h=sy)
    if peach:
        bm = bmesh.new()
        lv = bmesh.new()
        n = 0
        for layer in range(2):
            nx, nz = (4, 4) if layer == 0 else (3, 3)
            y = sy - 0.1 + layer * 0.11
            for i in range(nx):
                for j in range(nz):
                    px = (i - (nx - 1) / 2) * (sx - 0.16) / (nx - 1 if nx > 1 else 1) * (1.0 if layer == 0 else 0.8)
                    pz = (j - (nz - 1) / 2) * (sz - 0.16) / (nz - 1 if nz > 1 else 1) * (1.0 if layer == 0 else 0.8)
                    r = a.rng.uniform(0.085, 0.1)
                    before = set(bm.verts)
                    gsph(bm, (px + a.rng.uniform(-0.01, 0.01), y + 0.05, pz + a.rng.uniform(-0.01, 0.01)),
                         (r, r * 0.92, r), 12, 8)
                    a.paint_new(bm, before, jit=0.25, ao=0.35, tint=(1.0, 0.95, 0.9), ao_h=2 * r)
                    if a.rng.random() < 0.4:
                        gbox(lv, (px, y + 0.05 + r * 0.9, pz + 0.02), (0.07, 0.008, 0.035), ry=a.rng.uniform(0, 180),
                             rz=a.rng.uniform(-18, 18))
        a.part("Peaches", bm, "mat_env_peach", sub=0, jit=0.0, ao=0.0, paint=False)
        a.part("Leaves", lv, "mat_env_leaf", jit=0.2, ao=0.0)
    a.point("TopPoint", (0, sy, 0))
    a.finish(glb, info)


def barrel(M, info, glb):
    a = Asset("Barrel", M, 21)
    bm = bmesh.new()
    prof = []
    for k in range(13):
        t = k / 12
        prof.append((0.29 + 0.07 * math.sin(math.pi * t) ** 0.9 - 0.02 * (1 - abs(2 * t - 1)) * 0, 0.84 * t))
    prof = [(0.0, 0.0)] + [(r, y) for r, y in prof] + [(0.0, 0.84)]
    prof[1] = (0.27, 0.0)
    prof[-2] = (0.27, 0.84)
    # tampa levemente afundada
    prof = prof[:-1] + [(0.24, 0.82), (0.0, 0.815)]
    lathe(bm, prof, seg=20)
    a.part("Staves", bm, "mat_env_barrel", bevel=0.0, jit=0.2, ao=0.45, ao_h=0.8, sub=1, crease=0.0)
    bm = bmesh.new()
    for y in (0.1, 0.29, 0.55, 0.74):
        t = y / 0.84
        r = 0.29 + 0.07 * math.sin(math.pi * t) ** 0.9
        lathe(bm, [(r + 0.012, y - 0.022), (r + 0.02, y - 0.015), (r + 0.02, y + 0.015), (r + 0.012, y + 0.022),
                   (r - 0.01, y + 0.022), (r - 0.01, y - 0.022)][:6] + [(r + 0.012, y - 0.022)], seg=20)
    a.part("Hoops", bm, "mat_env_metal", jit=0.1, ao=0.1, ao_h=0.84)
    a.finish(glb, info)


def rope_coil(M, info, glb):
    a = Asset("Rope_Coil", M, 22)
    bm = bmesh.new()
    pts = []
    turns, per = 4.2, 22
    for k in range(int(turns * per) + 1):
        t = k / (turns * per)
        ang = t * turns * 2 * math.pi
        rad = 0.2 + 0.07 * math.sin(t * 9) * 0.3 + 0.1 * t
        pts.append(Vector((math.cos(ang) * rad, 0.032 + 0.046 * turns * t * 0.55 + 0.01 * math.sin(ang * 2), math.sin(ang) * rad)))
    tail = [pts[-1] + Vector((0.12 * k, -0.01 * k, 0.1 * k)) for k in range(1, 5)]
    pts += [Vector((p.x, max(0.03, p.y), p.z)) for p in tail]
    sweep(bm, pts, lambda t: 0.032, seg=6)
    a.part("Rope", bm, "mat_env_rope", jit=0.2, ao=0.4, ao_h=0.3)
    a.finish(glb, info)


def lantern_post(M, info, glb):
    """Poste com lampiao a 2,1 m. Origem no pe; LampPoint no vidro."""
    a = Asset("Lantern_Post", M, 23)
    bm = bmesh.new()
    gbox(bm, (0, 1.05, 0), (0.12, 2.1, 0.12), cuts=(0, 3, 0))
    for v in bm.verts:
        v.co.x += 0.012 * math.sin(v.co.y * 2.2)
    gbox(bm, (0, 0.06, 0), (0.26, 0.12, 0.26))
    a.part("Pole", bm, "mat_env_wood_dark", bevel=0.012, bseg=2, jit=0.15, ao=0.5, ao_h=2.1)
    bm = bmesh.new()
    gbox(bm, (0.17, 1.98, 0), (0.4, 0.07, 0.07))
    gbox(bm, (0.09, 1.9, 0), (0.22, 0.05, 0.05), rz=-38)
    a.part("Arm", bm, "mat_env_wood_dark", bevel=0.01, bseg=2, jit=0.1, ao=0.0)
    bm = bmesh.new()
    gbox(bm, (0.34, 1.82, 0), (0.16, 0.025, 0.16))
    gbox(bm, (0.34, 1.57, 0), (0.18, 0.025, 0.18))
    for sx in (-1, 1):
        for sz in (-1, 1):
            gbox(bm, (0.34 + sx * 0.075, 1.695, sz * 0.075), (0.016, 0.25, 0.016))
    gcyl(bm, (0.34, 1.82, 0), (0.34, 1.90, 0), 0.03, 0.012, seg=8)
    a.part("Cage", bm, "mat_env_metal", bevel=0.004, bseg=1, jit=0.1, ao=0.0)
    bm = bmesh.new()
    gbox(bm, (0.34, 1.695, 0), (0.12, 0.22, 0.12))
    a.part("Glass", bm, "mat_env_lamp_glass", bevel=0.01, bseg=2, jit=0.0, ao=0.0)
    bm = bmesh.new()
    gcyl(bm, (0.34, 1.83, 0), (0.34, 1.97, 0), 0.115, 0.02, seg=4)
    a.part("Hat", bm, "mat_env_metal", jit=0.1, ao=0.1)
    a.point("LampPoint", (0.34, 1.7, 0), kind="PLAIN_AXES")
    a.finish(glb, info)


def fishing_net(M, info, glb):
    """Rede pendurada num cabo; origem no centro do cabo (topo). Plano xy, 1,8 m x 1,3 m."""
    a = Asset("Fishing_Net", M, 24)
    bm = bmesh.new()
    nx, ny = 15, 10
    W, H = 1.8, 1.3
    vs = []
    for j in range(ny + 1):
        row = []
        for i in range(nx + 1):
            u = i / nx
            drop = H * (0.82 + 0.18 * (math.sin(u * math.pi * 3.0) * 0.5 + 0.5)) if True else H
            y = -0.05 - drop * j / ny
            x = (u - 0.5) * W * (1 - 0.16 * j / ny)
            z = 0.045 * math.sin(j * 0.9 + u * 6) * (j / ny) + 0.02 * (j / ny)
            row.append(bm.verts.new((x, y, z)))
        vs.append(row)
    for j in range(ny):
        for i in range(nx):
            bm.faces.new((vs[j][i], vs[j][i + 1], vs[j + 1][i + 1], vs[j + 1][i]))
    # rasga um pedaco (remendo) para parecer usada
    for f in list(bm.faces):
        c = f.calc_center_median()
        if (c.x - 0.45) ** 2 + (c.y + 0.9) ** 2 < 0.02:
            bm.faces.remove(f)
    ob = a.part("Mesh", bm, "mat_env_net", jit=0.2, ao=0.35, ao_h=1.3)
    md = ob.modifiers.new("Wire", "WIREFRAME")
    md.thickness = 0.014
    md.use_even_offset = True
    md.use_replace = True
    bm = bmesh.new()
    sweep(bm, [Vector((-0.92 + 1.84 * k / 10, -0.01 + 0.03 * math.sin(k * 1.3), 0.0)) for k in range(11)], 0.022, seg=6)
    a.part("Rope", bm, "mat_env_rope", jit=0.12, ao=0.0)
    bm = bmesh.new()
    for k in range(5):
        gsph(bm, (-0.7 + 0.35 * k, -0.07, 0.03), (0.05, 0.035, 0.035), 10, 6)
    a.part("Floats", bm, "mat_env_cork", jit=0.2, ao=0.1)
    a.point("HangPoint", (0, 0, 0))
    a.finish(glb, info)


def sign_board(M, info, glb):
    """Placa de madeira (sem texto) num poste; origem no pe; face para -Z."""
    a = Asset("Sign_Board", M, 25)
    bm = bmesh.new()
    gbox(bm, (0, 0.8, 0.06), (0.11, 1.6, 0.11), cuts=(0, 3, 0))
    for v in bm.verts:
        v.co.x += 0.01 * math.sin(v.co.y * 3)
    a.part("Post", bm, "mat_env_wood_dark", bevel=0.012, bseg=2, jit=0.15, ao=0.5, ao_h=1.6)
    bm = bmesh.new()
    gbox(bm, (0.02, 1.32, -0.01), (1.1, 0.46, 0.05), rz=1.2, cuts=(5, 0, 0))
    for v in bm.verts:
        v.co.y += 0.012 * math.sin(v.co.x * 5)
    a.part("Board", bm, "mat_env_hut_door", bevel=0.012, bseg=2, jit=0.15, ao=0.2, ao_h=0.5)
    bm = bmesh.new()
    gbox(bm, (0.02, 1.32, -0.045), (1.18, 0.54, 0.03), rz=1.2)
    a.part("Frame", bm, "mat_env_wood_light", bevel=0.01, bseg=2, jit=0.15, ao=0.1)
    bm = bmesh.new()   # pictograma sem texto: peixe estilizado (elipse + cauda)
    gsph(bm, (-0.06, 1.32, -0.07), (0.2, 0.09, 0.012), 14, 8)
    gbox(bm, (0.2, 1.32, -0.07), (0.14, 0.14, 0.012), rz=45)
    a.part("Icon", bm, "mat_env_boat_name", jit=0.1, ao=0.0)
    a.finish(glb, info)


def bucket(M, info, glb):
    a = Asset("Bucket", M, 26)
    bm = bmesh.new()
    lathe(bm, [(0.0, 0.0), (0.13, 0.0), (0.145, 0.02), (0.17, 0.3), (0.175, 0.31), (0.158, 0.31), (0.15, 0.28), (0.0, 0.26)], seg=18)
    a.part("Body", bm, "mat_env_bucket", jit=0.18, ao=0.4, ao_h=0.3, sub=1)
    bm = bmesh.new()
    pts = [Vector((0.17 * math.cos(math.pi * k / 12), 0.30 + 0.17 * math.sin(math.pi * k / 12), 0.0)) for k in range(13)]
    sweep(bm, pts, 0.008, seg=6)
    a.part("Handle", bm, "mat_env_metal", jit=0.1, ao=0.0)
    a.finish(glb, info)


def oar(M, info, glb):
    """Remo em pe (eixo y); origem na ponta da pa."""
    a = Asset("Oar", M, 27)
    bm = bmesh.new()
    gcyl(bm, (0, 0.52, 0), (0, 1.95, 0), 0.027, 0.022, seg=10)
    gcyl(bm, (0, 1.78, 0), (0, 1.98, 0), 0.034, 0.034, seg=10)
    a.part("Shaft", bm, "mat_env_wood_light", jit=0.2, ao=0.1, ao_h=1.9)
    bm = bmesh.new()
    gbox(bm, (0, 0.27, 0), (0.15, 0.55, 0.026), cuts=(2, 4, 0))
    for v in bm.verts:
        t = v.co.y / 0.55
        v.co.x *= 0.9 + 0.12 * math.sin(t * math.pi)
        v.co.z += 0.01 * math.sin(v.co.x * 20)
    a.part("Blade", bm, "mat_env_boat_trim", bevel=0.008, bseg=2, sub=1, crease=0.5, jit=0.15, ao=0.25, ao_h=0.55)
    a.finish(glb, info)


def cork_buoy(M, info, glb):
    a = Asset("Cork_Buoy", M, 28)
    bm = bmesh.new()
    prof = [(0.0, 0.0), (0.09, 0.0), (0.17, 0.05), (0.2, 0.13), (0.2, 0.2), (0.17, 0.28), (0.09, 0.33), (0.0, 0.33)]
    lathe(bm, prof, seg=16)
    a.part("Float", bm, "mat_env_cork", jit=0.22, ao=0.4, ao_h=0.33, sub=1)
    bm = bmesh.new()
    gcyl(bm, (0, 0.0, 0), (0, 0.34, 0), 0.03, seg=8)
    sweep(bm, [Vector((0.1 * math.sin(math.pi * k / 10), 0.33 + 0.16 * math.sin(math.pi * k / 10) ** 0.8, 0.0))
               for k in range(11)], 0.017, seg=6)
    a.part("Rope", bm, "mat_env_rope", jit=0.15, ao=0.0)
    a.finish(glb, info)


def hut(M, info, glb):
    """Cabana de barcos: 3,4 x 2,2 (paredes) x 2,8 m, cumeeira em x, porta e janela na face -Z. Origem: centro da base."""
    a = Asset("Boat_Hut", M, 29)
    W, D, WH, RH = 3.4, 2.8, 2.2, 0.95
    bm = bmesh.new()
    prof = [bm.verts.new(p) for p in ((-W / 2, 0.0, D / 2), (W / 2, 0.0, D / 2), (W / 2, WH, D / 2), (0.0, WH + RH, D / 2), (-W / 2, WH, D / 2))]
    f = bm.faces.new(prof)
    r = bmesh.ops.extrude_face_region(bm, geom=[f])
    bmesh.ops.translate(bm, vec=(0, 0, -D), verts=[v for v in r["geom"] if isinstance(v, bmesh.types.BMVert)])
    a.part("Walls", bm, "mat_env_hut_wall", bevel=0.03, bseg=2, jit=0.12, ao=0.35, ao_h=1.2)
    # tabuas verticais sobrepostas na frente (-Z) e atras
    bm = bmesh.new()
    n = 17
    for sgn in (-1, 1):
        for i in range(n):
            x = -W / 2 + 0.1 + (W - 0.2) * i / (n - 1)
            hh = WH + (RH * (1 - abs(x) / (W / 2)))
            before = set(bm.verts)
            gbox(bm, (x, hh / 2 + 0.02, sgn * (D / 2 + 0.012)), (0.205, hh - 0.02 + a.rng.uniform(-0.01, 0.0), 0.024), rz=a.rng.uniform(-0.4, 0.4))
            a.paint_new(bm, before, jit=0.18, ao=0.3, ao_h=hh)
    a.part("Boards", bm, "mat_env_hut_wall", bevel=0.006, bseg=1, paint=False)
    # telhado: duas aguas com sobressalto + cumeeira
    ang = math.degrees(math.atan2(RH, W / 2))
    L = math.hypot(W / 2, RH) + 0.28
    bm = bmesh.new()
    for s in (-1, 1):
        cx = s * (W / 4 + 0.09)
        gbox(bm, (cx, WH + RH / 2 + 0.06, 0), (L, 0.09, D + 0.5), rz=-s * ang, cuts=(2, 0, 3))
    a.part("Roof", bm, "mat_env_hut_roof", bevel=0.02, bseg=2, jit=0.16, ao=0.0)
    bm = bmesh.new()
    gbox(bm, (0, WH + RH + 0.1, 0), (0.22, 0.1, D + 0.55), rz=0)
    a.part("Ridge", bm, "mat_env_wood_dark", bevel=0.025, bseg=2, jit=0.12, ao=0.0)
    # porta e janela (-Z)
    fz = -D / 2 - 0.03
    bm = bmesh.new()
    gbox(bm, (-0.7, 0.9, fz - 0.015), (0.88, 1.8, 0.04), cuts=(0, 4, 0))
    a.part("Door", bm, "mat_env_hut_door", bevel=0.012, bseg=2, jit=0.12, ao=0.25, ao_h=1.8)
    bm = bmesh.new()
    gbox(bm, (-0.7, 0.94, fz - 0.045), (1.04, 1.88, 0.03))
    gbox(bm, (0.75, 1.22, fz - 0.03), (0.82, 0.74, 0.03))
    gbox(bm, (0.75, 0.82, fz - 0.07), (0.98, 0.07, 0.12))
    gbox(bm, (0.5, 1.22, fz - 0.07), (0.05, 0.84, 0.045))
    gbox(bm, (1.0, 1.22, fz - 0.07), (0.05, 0.84, 0.045))
    gbox(bm, (-0.45, 0.85, fz - 0.06), (0.05, 0.12, 0.05))
    a.part("Frames", bm, "mat_env_wood_light", bevel=0.01, bseg=2, jit=0.15, ao=0.2, ao_h=1.0)
    bm = bmesh.new()
    gbox(bm, (0.75, 1.22, fz - 0.055), (0.64, 0.56, 0.015))
    a.part("Window", bm, "mat_env_hut_glass", jit=0.1, ao=0.0)
    # base de pedra e caixa de flores
    bm = bmesh.new()
    gbox(bm, (0, 0.1, 0), (W + 0.16, 0.2, D + 0.16), cuts=(3, 0, 3))
    for v in bm.verts:
        v.co.y += 0.012 * math.sin(v.co.x * 3 + v.co.z * 2)
    a.part("Plinth", bm, "mat_env_rock", bevel=0.03, bseg=2, jit=0.18, ao=0.4, ao_h=0.2)
    bm = bmesh.new()
    gbox(bm, (0.75, 0.62, fz - 0.14), (0.9, 0.14, 0.16))
    a.part("FlowerBox", bm, "mat_env_wood_dark", bevel=0.01, bseg=2, jit=0.1, ao=0.3)
    bm = bmesh.new()
    fl = bmesh.new()
    for k in range(7):
        x = 0.75 + (k - 3) * 0.12
        gsph(bm, (x, 0.74, fz - 0.14 + a.rng.uniform(-0.03, 0.03)), (0.07, 0.07, 0.07), 8, 6)
        gsph(fl, (x + a.rng.uniform(-0.03, 0.03), 0.8, fz - 0.14), (0.03, 0.03, 0.03), 8, 6)
    a.part("Plants", bm, "mat_env_leaf", jit=0.2, ao=0.3)
    a.part("Flowers", fl, "mat_env_bush_flower", jit=0.1, ao=0.0)
    a.point("DoorPoint", (-0.7, 0.0, fz - 0.4), kind="PLAIN_AXES")
    a.finish(glb, info)


def boot_print(M, info, glb):
    """Pegada de bota (relevo raso, 0,36 m, ponta para -Z). Origem no centro, y = 0 do chao."""
    a = Asset("Boot_Print", M, 30)
    bm = bmesh.new()
    gsph(bm, (0, 0.012, -0.06), (0.095, 0.011, 0.14), 16, 8)
    gsph(bm, (0, 0.012, 0.15), (0.075, 0.011, 0.075), 14, 8)
    a.part("Sole", bm, "mat_env_bootprint", jit=0.1, ao=0.0)
    bm = bmesh.new()
    for k in range(6):
        z = -0.17 + 0.05 * k
        w = 0.08 * math.sqrt(max(0.1, 1 - ((z + 0.06) / 0.14) ** 2))
        gbox(bm, (0, 0.02, z), (w * 1.5, 0.007, 0.018), rz=0)
    gbox(bm, (0, 0.02, 0.16), (0.1, 0.007, 0.018))
    a.part("Tread", bm, "mat_env_bootprint", bevel=0.002, bseg=1, jit=0.25, ao=0.0, tint=(1.2, 1.2, 1.2))
    a.finish(glb, info)


def main():
    reset_scene()
    M = materials()
    info = {}
    glb = arg_value("--glb-dir", os.path.join(REPO, "game", "assets", "models", "environment"))
    crate(M, info, glb, "Crate_L", (0.9, 0.8, 0.9), False, 31)
    crate(M, info, glb, "Crate_S", (0.62, 0.5, 0.62), False, 32)
    crate(M, info, glb, "Crate_Peach", (0.7, 0.42, 0.7), True, 33)
    barrel(M, info, glb)
    rope_coil(M, info, glb)
    lantern_post(M, info, glb)
    fishing_net(M, info, glb)
    sign_board(M, info, glb)
    bucket(M, info, glb)
    oar(M, info, glb)
    cork_buoy(M, info, glb)
    hut(M, info, glb)
    boot_print(M, info, glb)
    blend = arg_value("--blend", os.path.join(REPO, "source_art", "environment", "props.blend"))
    save_all(blend, info, os.path.splitext(blend)[0] + ".info.json")


main()
