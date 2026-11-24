"""Rosto dos herois do RB-R1 (criancas-herois): olhos grandes (esclera, iris, pupila, DOIS brilhos, linha de cilio),
palpebras, sobrancelhas grossas, boca com preenchimento e dentes, para falar (visemas). PROVISORIO ate o Portao 1.

Objeto unico; topologia fixa; cada chave e um conjunto de posicoes:
  expressoes: neutra (= base), atenta, surpresa, alegre, triste, brava_leve, blink
  visemas:    mouth_A, mouth_E, mouth_O, mouth_M
  olhar:      look_left (esquerda do personagem, -X), look_right (+X), look_up
Geometria 100% procedural. Frente = +Y, direita do personagem = +X.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bmesh
import bpy
from mathutils import Vector

import char_lib as cl

N_MOUTH = 16   # pontos do contorno fechado da boca (8 em cima, 8 embaixo)

BASE = dict(happy=False, mouth="neutra", brow=(0.006, 0.004, 0.010), lid=0.0, bottom=False, eye=1.0, iris=1.0, gaze=(0.0, 0.0))
STATES = {
    "neutra": {},
    "atenta": dict(mouth="atenta", brow=(0.004, -0.006, 0.004), lid=0.10),
    "surpresa": dict(mouth="surpresa", brow=(0.020, 0.004, 0.012), eye=1.10, iris=0.85),
    "alegre": dict(mouth="alegre", brow=(0.012, 0.004, 0.012), lid=1.0, happy=True),
    "triste": dict(mouth="triste", brow=(0.004, 0.016, -0.002), lid=0.22),
    "brava_leve": dict(mouth="brava", brow=(-0.002, -0.014, -0.002), lid=0.26),
    "blink": dict(lid=1.0),
    "mouth_A": dict(mouth="A"),
    "mouth_E": dict(mouth="E"),
    "mouth_O": dict(mouth="O"),
    "mouth_M": dict(mouth="M"),
    "look_left": dict(gaze=(-1.0, 0.0)),
    "look_right": dict(gaze=(1.0, 0.0)),
    "look_up": dict(gaze=(0.0, 1.0)),
}
KEYS = list(STATES.keys())


def _unit_sphere(u, v):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=u, v_segments=v, radius=1.0)
    bm.verts.ensure_lookup_table()
    pts = [Vector(x.co) for x in bm.verts]
    faces = [tuple(x.index for x in f.verts) for f in bm.faces]
    bm.free()
    return pts, faces


def _tube_pts(pts, radii, sides, n0, closed=False):
    pts = [Vector(p) for p in pts]
    out = []
    m = len(pts)
    for i, p in enumerate(pts):
        if closed:
            d = (pts[(i + 1) % m] - pts[(i - 1) % m])
        else:
            d = (pts[min(i + 1, m - 1)] - pts[max(i - 1, 0)])
        if d.length < 1e-7:
            d = Vector((1, 0, 0))
        d.normalize()
        n = (n0 - d * n0.dot(d))
        if n.length < 1e-6:
            n = Vector((0, 0, 1))
        n.normalize()
        b = d.cross(n)
        r = radii[i] if isinstance(radii, (list, tuple)) else radii
        for k in range(sides):
            a = 2 * math.pi * k / sides
            out.append(p + (n * math.cos(a) + b * math.sin(a)) * r)
    if not closed:
        out.append(pts[0].copy())
        out.append(pts[-1].copy())
    return out


def _tube_faces(n, sides, closed=False):
    f = []
    rng = n if closed else n - 1
    for i in range(rng):
        j = (i + 1) % n
        for k in range(sides):
            f.append((i * sides + k, i * sides + (k + 1) % sides, j * sides + (k + 1) % sides, j * sides + k))
    if not closed:
        c0, c1 = n * sides, n * sides + 1
        for k in range(sides):
            f.append(((k + 1) % sides, k, c0))
            f.append(((n - 1) * sides + k, (n - 1) * sides + (k + 1) % sides, c1))
    return f


def _mouth_curves(m, x):
    """(zu, zl, w) para x em [-1, 1] (canto a canto). Unidades da cabeca padrao (k = 1)."""
    s = math.sqrt(max(1 - x * x, 0.0))
    if m == "neutra":
        w = 0.026
        zu = 0.009 * x * x - 0.004
        return zu, zu - 0.0006, w
    if m == "atenta":
        w = 0.017
        zu = 0.003 * x * x - 0.003
        return zu, zu - 0.0006, w
    if m == "alegre":
        w = 0.040
        zu = 0.014 * x * x - 0.007
        return zu, zu - 0.030 * (1 - x * x) ** 0.8, w
    if m == "surpresa":
        return 0.012 * s - 0.006, -0.020 * s - 0.006, 0.016
    if m == "triste":
        w = 0.022
        zu = -0.010 * x * x + 0.0
        return zu, zu - 0.0006, w
    if m == "brava":
        w = 0.020
        zu = -0.004 * x * x - 0.002 + 0.002 * x
        return zu, zu - 0.0006, w
    if m == "A":
        return 0.004 * (1 - x * x) - 0.002, -0.032 * s ** 1.4 - 0.002, 0.026
    if m == "E":
        zu = 0.006 * x * x - 0.001
        return zu, zu - 0.013 * s, 0.034
    if m == "O":
        return 0.011 * s - 0.004, -0.017 * s - 0.004, 0.014
    if m == "M":
        zu = 0.001 * x * x - 0.001
        return zu, zu - 0.0004, 0.022
    raise KeyError(m)


def build_face(rig, name, mats, head_ob, hc, k=1.0, eye_x=0.068, eye_z=None, eye_size=1.0, mouth_z=None, brow_w=1.0,
               head_bone="head", gaze_amount=1.0):
    """mats: eye, iris, dark, skin, mouth. k escala as medidas da cabeca padrao (altura 0,36 m)."""
    from mathutils.bvhtree import BVHTree
    hc = Vector(hc)
    bvh = BVHTree.FromObject(head_ob, bpy.context.evaluated_depsgraph_get())

    def surf(x, z):
        hit = bvh.ray_cast(Vector((x, hc.y + 1.0, z)), Vector((0, -1, 0)))
        return hit[0].y if hit[0] is not None else hc.y + 0.15 * k

    eye_z = hc.z - 0.030 * k if eye_z is None else eye_z
    mouth_z = hc.z - 0.112 * k if mouth_z is None else mouth_z
    es = eye_size * k
    slots = ["eye", "iris", "dark", "skin", "mouth"]
    P, F, parts = [], [], []
    SPH = {"sclera": _unit_sphere(18, 10), "iris": _unit_sphere(16, 8), "pupil": _unit_sphere(10, 6),
           "shine": _unit_sphere(8, 5), "shine2": _unit_sphere(6, 4), "lid": _unit_sphere(12, 7), "teeth": _unit_sphere(10, 4)}

    def add_ell(kind, slot, side, un, uf):
        start = len(P)
        P.extend(Vector() for _ in un)
        for f in uf:
            F.append(([start + i for i in f], slot))
        parts.append(dict(kind=kind, side=side, start=start, count=len(un), unit=un))

    def add_tube(kind, slot, side, n, sides, closed=False):
        start = len(P)
        cnt = n * sides + (0 if closed else 2)
        P.extend(Vector() for _ in range(cnt))
        for f in _tube_faces(n, sides, closed):
            F.append(([start + i for i in f], slot))
        parts.append(dict(kind=kind, side=side, start=start, count=cnt, n=n, sides=sides))

    def add_fan(kind, slot, n):
        start = len(P)
        P.extend(Vector() for _ in range(n + 1))
        for i in range(n):
            F.append(([start + n, start + i, start + (i + 1) % n], slot))
        parts.append(dict(kind=kind, side="C", start=start, count=n + 1))

    info = {}
    for s, sx in (("R", 1), ("L", -1)):
        cx = sx * eye_x * k
        ex, ez = 0.036 * es, 0.050 * es
        cy = surf(cx, eye_z) - 0.010 * k
        info[s] = dict(sx=sx, c=Vector((cx, cy, eye_z)), ex=ex, ez=ez)
        add_ell("sclera", "eye", s, *SPH["sclera"])
        add_ell("iris", "iris", s, *SPH["iris"])
        add_ell("pupil", "dark", s, *SPH["pupil"])
        add_ell("shine", "eye", s, *SPH["shine"])
        add_ell("shine2", "eye", s, *SPH["shine2"])
        add_ell("lid", "skin", s, *SPH["lid"])
        add_tube("lash", "dark", s, 9, 5)
        add_tube("brow", "dark", s, 7, 6)
    add_fan("mfill", "mouth", N_MOUTH)
    add_ell("teeth", "eye", "C", *SPH["teeth"])
    add_tube("mouth", "dark", "C", N_MOUTH, 5, closed=True)

    def lid_profile(I, h, bottom):
        """Centro e raio z da palpebra para fechamento h (0 aberto .. 1 fechado)."""
        c, ez = I["c"], I["ez"]
        rz = ez * 1.10 * h
        czz = (c.z + ez * 1.06 - rz) if not bottom else (c.z - ez * 1.06 + rz)
        return czz, rz

    def state(name):
        st = dict(BASE)
        st.update(STATES[name])
        out = [None] * len(P)
        mouth_pts = []
        for i in range(N_MOUTH):
            # 0..8: labio de cima (canto esq -> canto dir); 8..16: de baixo (dir -> esq)
            if i <= 8:
                x = -1.0 + 2.0 * i / 8.0
                zu, zl, w = _mouth_curves(st["mouth"], x)
                z = zu
            else:
                x = 1.0 - 2.0 * (i - 8) / 8.0
                zu, zl, w = _mouth_curves(st["mouth"], x)
                z = zl
            px = x * w * k
            pz = mouth_z + z * k
            mouth_pts.append(Vector((px, surf(px, pz) + 0.0015 * k, pz)))
        open_h = max(p.z for p in mouth_pts[:9]) - min(p.z for p in mouth_pts[8:] + [mouth_pts[0]])
        for p in parts:
            kind, s = p["kind"], p["side"]
            if kind == "mouth":
                pos = _tube_pts(mouth_pts, 0.0048 * k, 5, Vector((0, 1, 0)), closed=True)
            elif kind == "mfill":
                cen = sum(mouth_pts, Vector()) / N_MOUTH
                pos = [Vector((q.x, q.y - 0.0035 * k, q.z)) for q in mouth_pts] + [Vector((cen.x, cen.y - 0.006 * k, cen.z))]
            elif kind == "teeth":
                top = mouth_pts[4]
                wide = abs(mouth_pts[2].x - mouth_pts[6].x)
                vis = 1.0 if (open_h > 0.012 * k and st["mouth"] in ("alegre", "A", "E")) else 0.0
                cc = Vector((top.x, top.y - 0.004 * k - (1 - vis) * 0.02 * k, top.z - 0.004 * k))
                pos = [Vector((cc.x + u.x * max(wide * 0.62, 0.004 * k), cc.y + u.y * 0.003 * k, cc.z + u.z * 0.0045 * k)) for u in p["unit"]]
            elif kind == "brow":
                I = info[s]
                up, tilt, arch = st["brow"]
                pts = []
                for i in range(7):
                    t = (i - 3) / 3.0
                    x = I["c"].x + t * 0.020 * brow_w * es / k * k
                    t_in = -t * I["sx"]                # +1 do lado de dentro (nariz)
                    dz = (up + arch * (1.0 - t * t) + tilt * t_in) * k
                    z = eye_z + I["ez"] + 0.020 * k + dz
                    pts.append((x, surf(x, z) + 0.002 * k, z))
                pos = _tube_pts(pts, [0.0045 * k, 0.0062 * k, 0.0072 * k, 0.0074 * k, 0.0072 * k, 0.0062 * k, 0.0045 * k], 6, Vector((0, 1, 0)))
            elif kind == "lash":
                I = info[s]
                c, ex, ez = I["c"], I["ex"], I["ez"]
                h = st["lid"]
                pts = []
                for i in range(9):
                    t = (i - 4) / 4.0
                    x = c.x + t * ex * 1.04
                    if st["happy"]:
                        zt = c.z - 0.15 * ez + 0.50 * ez * (1 - t * t)
                    elif st["bottom"] and h > 0:
                        zt = c.z + ez * math.sqrt(max(1 - t * t, 0.0)) * 0.98
                        zt = zt - (zt - c.z) * 0.15 * h
                    else:
                        zt0 = c.z + ez * math.sqrt(max(1 - t * t, 0.0)) * 0.98
                        zb = c.z - ez * 0.20 + 0.010 * k * t * t
                        zt = zt0 + (zb - zt0) * h
                    dx, dz = (x - c.x) / ex, (zt - c.z) / ez
                    y = surf(x, zt) + 0.0015 * k + 0.008 * k * math.sqrt(max(1 - dx * dx - dz * dz, 0.0)) + 0.0055 * k
                    pts.append((x, y, zt))
                r = [0.0032 * k + 0.0016 * k * (1 - abs((i - 4) / 4.0)) for i in range(9)]
                pos = _tube_pts(pts, r, 5, Vector((0, 1, 0)))
            else:
                I = info[s]
                c, ex, ez = I["c"], I["ex"], I["ez"]
                sx = I["sx"]
                gx, gz = st["gaze"]
                g = Vector((gx * ex * 0.32 * gaze_amount, 0.0, gz * ez * 0.24 * gaze_amount))
                pos = []
                fe = st["eye"]

                def conform(x, z, lift, uy, depth):
                    # superficie do olho colada ao rosto: base na pele + abaulado + camada
                    dx, dz = (x - c.x) / (ex * fe), (z - c.z) / (ez * fe)
                    bulge = 0.008 * k * math.sqrt(max(1 - dx * dx - dz * dz, 0.0))
                    if uy >= 0:
                        return surf(x, z) + 0.0015 * k + bulge + lift + uy * depth
                    return surf(x, z) - 0.006 * k + uy * 0.004 * k

                for u in p["unit"]:
                    if kind == "sclera":
                        x, z = c.x + u.x * ex * fe, c.z + u.z * ez * fe
                        q = Vector((x, conform(x, z, 0.0, u.y, 0.0005 * k), z))
                    elif kind in ("iris", "pupil"):
                        fi = fe * st["iris"]
                        sxz = (0.72, 0.72) if kind == "iris" else (0.38, 0.40)
                        cc = Vector((c.x + g.x, 0, c.z - 0.004 * k + g.z))
                        x, z = cc.x + u.x * ex * sxz[0] * fi, cc.z + u.z * ez * sxz[1] * fi
                        q = Vector((x, conform(x, z, 0.0012 * k if kind == "iris" else 0.0022 * k, u.y, 0.0004 * k), z))
                    elif kind == "shine":
                        cc = Vector((c.x + ex * 0.30 * fe + g.x * 0.5, 0, c.z + ez * 0.30 * fe + g.z * 0.5))
                        x, z = cc.x + u.x * 0.0100 * es, cc.z + u.z * 0.0115 * es
                        q = Vector((x, conform(x, z, 0.0034 * k, u.y, 0.0004 * k), z))
                    elif kind == "shine2":
                        cc = Vector((c.x - ex * 0.34 * fe + g.x * 0.5, 0, c.z - ez * 0.34 * fe + g.z * 0.5))
                        x, z = cc.x + u.x * 0.0050 * es, cc.z + u.z * 0.0050 * es
                        q = Vector((x, conform(x, z, 0.0034 * k, u.y, 0.0004 * k), z))
                    else:  # palpebra: sempre escondida; o fechamento e feito recortando o olho (sem casca translucida)
                        x, z = c.x + u.x * ex * 0.5, c.z + u.z * 0.0001
                        q = Vector((x, surf(x, z) - 0.03 * k, z))
                    h = st["lid"]
                    if kind != "lid" and h > 0.005:
                        tt = max(-1.0, min(1.0, (q.x - c.x) / (ex * 1.04)))
                        if st["bottom"]:
                            zl = c.z - ez + 2.0 * ez * h * (1.0 - 0.35 * tt * tt)
                            cov = q.z < zl
                        else:
                            zt0 = c.z + ez * math.sqrt(max(1 - tt * tt, 0.0)) * 0.98
                            zb = c.z - ez * 0.20 + 0.010 * k * tt * tt
                            zl = zt0 + (zb - zt0) * h
                            cov = q.z > zl or h >= 0.999
                        if cov:
                            q = Vector((q.x, surf(q.x, zl) - 0.03 * k, zl))
                    pos.append(q)
            for j, q in enumerate(pos):
                out[p["start"] + j] = q
        return out

    base = state("neutra")
    bm = bmesh.new()
    vs = [bm.verts.new(q) for q in base]
    for idx, slot in F:
        try:
            f = bm.faces.new([vs[i] for i in idx])
        except ValueError:
            continue
        f.material_index = slots.index(slot)
        f.smooth = True
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    me.uv_layers.new(name="UVMap")
    for s_ in slots:
        me.materials.append(mats[s_])
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    ob.shape_key_add(name="Basis", from_mix=False)
    for kname in KEYS:
        kb = ob.shape_key_add(name=kname, from_mix=False)
        kb.slider_min, kb.slider_max = 0.0, 1.0
        for i, q in enumerate(state(kname)):
            kb.data[i].co = q
    if rig is not None:
        cl.bind_to_rig(ob, rig, single_bone=head_bone)
    return ob, info





