"""Rosto com shape keys (RB-04-chars): olhos grandes (esclera/iris/pupila/brilho), palpebras, cilios, sobrancelhas e boca.

Objeto unico por personagem. Chaves: neutra (= base), atenta, surpresa, alegre, blink. A topologia e fixa; cada expressao
e apenas um conjunto de posicoes. PROVISORIO.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bmesh
import bpy
from mathutils import Vector

import char_lib as cl

STATES = {
    "neutra":   dict(mouth="neutra", brow=(0.0, 0.0, 0.006), lid=0.0, bottom=False, lash=False, eye=1.0, iris=1.0),
    "atenta":   dict(mouth="atenta", brow=(-0.004, 0.012, 0.002), lid=0.22, bottom=False, lash=False, eye=1.0, iris=1.0),
    "surpresa": dict(mouth="surpresa", brow=(0.022, -0.004, 0.012), lid=0.0, bottom=False, lash=False, eye=1.13, iris=0.82),
    "alegre":   dict(mouth="alegre", brow=(0.008, -0.003, 0.010), lid=0.36, bottom=True, lash=False, eye=1.0, iris=1.0),
    "blink":    dict(mouth="neutra", brow=(0.0, 0.0, 0.006), lid=1.0, bottom=False, lash=True, eye=1.0, iris=1.0),
}


def _unit_sphere(u, v):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=u, v_segments=v, radius=1.0)
    bm.verts.ensure_lookup_table()
    pts = [Vector(x.co) for x in bm.verts]
    faces = [tuple(x.index for x in f.verts) for f in bm.faces]
    bm.free()
    return pts, faces


def _tube_pts(pts, radii, sides, n0=None):
    pts = [Vector(p) for p in pts]
    out = []
    prev = n0
    for i, p in enumerate(pts):
        d = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
        n = prev if prev is not None else (Vector((0, 0, 1)) if abs(d.z) < 0.9 else Vector((1, 0, 0)))
        n = (n - d * n.dot(d)).normalized()
        b = d.cross(n)
        prev = n
        r = radii[i] if isinstance(radii, (list, tuple)) else radii
        for k in range(sides):
            a = 2 * math.pi * k / sides
            out.append(p + (n * math.cos(a) + b * math.sin(a)) * r)
    out.append(pts[0].copy())
    out.append(pts[-1].copy())
    return out


def _tube_faces(n, sides):
    f = []
    for i in range(n - 1):
        for k in range(sides):
            f.append((i * sides + k, i * sides + (k + 1) % sides, (i + 1) * sides + (k + 1) % sides, (i + 1) * sides + k))
    c0, c1 = n * sides, n * sides + 1
    for k in range(sides):
        f.append(((k + 1) % sides, k, c0))
        f.append(((n - 1) * sides + k, (n - 1) * sides + (k + 1) % sides, c1))
    return f


def build_face(rig, name, mats, hc=(0, 0, 1.06), hr=(0.165, 0.17, 0.18), eye_x=0.062, eye_z=1.085, eye_size=1.0,
               brow_w=1.0, brow_thick=0.0075, mouth_z=0.972, mouth_w=1.0, iris_rot=0.0):
    hc = Vector(hc)

    def surf(x, z):
        t = 1.0 - ((x - hc.x) / hr[0]) ** 2 - ((z - hc.z) / hr[2]) ** 2
        return hc.y + hr[1] * math.sqrt(max(t, 0.02))

    es = eye_size
    slots = ["eye", "iris", "dark", "skin"]
    P = []          # posicoes neutras
    F = []          # (indices, slot)
    parts = []      # dicts: kind, start, count, params
    sph_u, sph_v = 18, 10
    unit, ufaces = _unit_sphere(sph_u, sph_v)
    lunit, lfaces = _unit_sphere(14, 8)

    def add_ellipsoid(kind, slot, side, un, uf, **kw):
        start = len(P)
        P.extend(Vector((0, 0, 0)) for _ in un)
        for f in uf:
            F.append(([start + i for i in f], slot))
        parts.append(dict(kind=kind, side=side, start=start, count=len(un), unit=un, **kw))

    def add_tube(kind, slot, side, n, sides):
        start = len(P)
        cnt = n * sides + 2
        P.extend(Vector((0, 0, 0)) for _ in range(cnt))
        for f in _tube_faces(n, sides):
            F.append(([start + i for i in f], slot))
        parts.append(dict(kind=kind, side=side, start=start, count=cnt, n=n, sides=sides))

    info = {}
    for s, sx in (("R", 1), ("L", -1)):
        cx, cz = sx * eye_x, eye_z
        cy = surf(cx, cz) - 0.012
        ex, ez = 0.040 * es, 0.050 * es
        info[s] = dict(sx=sx, c=Vector((cx, cy, cz)), ex=ex, ez=ez)
        add_ellipsoid("sclera", "eye", s, unit, ufaces)
        add_ellipsoid("iris", "iris", s, unit, ufaces)
        add_ellipsoid("pupil", "dark", s, unit, ufaces)
        add_ellipsoid("shine", "eye", s, unit, ufaces)
        add_ellipsoid("shine2", "eye", s, unit, ufaces)
        add_ellipsoid("lid", "skin", s, lunit, lfaces)
        add_tube("lash", "dark", s, 7, 4)
        add_tube("brow", "dark", s, 7, 6)
    add_tube("mouth", "dark", "C", 11, 6)

    def state_positions(st):
        out = [None] * len(P)
        for p in parts:
            s = p["side"]
            k = p["kind"]
            if k == "mouth":
                pts = []
                for i in range(11):
                    t = i / 10.0
                    x = (t - 0.5) * 2.0
                    m = st["mouth"]
                    if m == "neutra":
                        px, pz = x * 0.030 * mouth_w, 0.010 * x * x - 0.004
                    elif m == "atenta":
                        px, pz = x * 0.022 * mouth_w, 0.003 * x * x - 0.004
                    elif m == "alegre":
                        px, pz = x * 0.046 * mouth_w, 0.030 * x * x - 0.010
                    else:
                        a = math.pi / 2 + 0.25 + t * (2 * math.pi - 0.5)
                        px, pz = math.cos(a) * 0.016, math.sin(a) * 0.021 - 0.010
                    z = mouth_z + pz
                    pts.append((px, surf(px, z) + 0.001, z))
                pos = _tube_pts(pts, 0.0058, 6, n0=Vector((0, 1, 0)))
            elif k == "brow":
                I = info[s]
                up, tilt, arch = st["brow"]
                pts = []
                for i in range(7):
                    dx = (i - 3) * 0.012 * brow_w * es
                    t_in = -(i - 3) / 3.0 * I["sx"]
                    dz = up + arch * (1.0 - ((i - 3) / 3.0) ** 2) - tilt * t_in
                    x = I["c"].x + dx
                    z = eye_z + 0.062 * es + dz
                    pts.append((x, surf(x, z) + 0.0005, z))
                pos = _tube_pts(pts, brow_thick, 6, n0=Vector((0, 1, 0)))
            elif k == "lash":
                I = info[s]
                c, ex, ez = I["c"], I["ex"], I["ez"]
                if st["lash"]:
                    rz = ez * 1.10
                    czz = c.z + ez * 1.06 - rz
                    pts = []
                    for i in range(7):
                        t = (i - 3) / 3.0
                        x = c.x + t * ex * 1.02
                        z = c.z - ez * 0.28 + 0.013 * t * t
                        dx = (x - c.x) / (ex * 1.16)
                        dz = (z - czz) / rz
                        y = c.y + 0.012 + 0.028 * math.sqrt(max(1 - dx * dx - dz * dz, 0.0)) + 0.001
                        pts.append((x, y, z))
                else:
                    pts = [(c.x + (i - 3) / 3.0 * ex * 0.2, c.y - 0.03, c.z) for i in range(7)]
                pos = _tube_pts(pts, 0.0032, 4, n0=Vector((0, 1, 0)))
            else:
                I = info[s]
                c, ex, ez = I["c"], I["ex"], I["ez"]
                sx = I["sx"]
                f_eye = st["eye"]
                pos = []
                for u in p["unit"]:
                    if k == "sclera":
                        q = Vector((c.x + u.x * ex, c.y + u.y * 0.024, c.z + u.z * ez))
                    elif k == "iris":
                        cc = Vector((c.x + sx * 0.001 + iris_rot, c.y + 0.016, c.z - 0.004))
                        q = Vector((cc.x + u.x * ex * 0.68, cc.y + u.y * 0.014, cc.z + u.z * ez * 0.70))
                    elif k == "pupil":
                        cc = Vector((c.x + sx * 0.001 + iris_rot, c.y + 0.026, c.z - 0.004))
                        q = Vector((cc.x + u.x * ex * 0.34, cc.y + u.y * 0.009, cc.z + u.z * ez * 0.36))
                    elif k == "shine":
                        cc = Vector((c.x - sx * 0.011, c.y + 0.032, c.z + ez * 0.28))
                        q = Vector((cc.x + u.x * 0.0075 * es, cc.y + u.y * 0.005, cc.z + u.z * 0.0085 * es))
                    elif k == "shine2":
                        cc = Vector((c.x + sx * 0.012, c.y + 0.030, c.z - ez * 0.32))
                        q = Vector((cc.x + u.x * 0.0035 * es, cc.y + u.y * 0.004, cc.z + u.z * 0.0035 * es))
                    else:  # lid
                        h = st["lid"]
                        if h < 0.005:
                            q = Vector((c.x + u.x * ex * 1.16, c.y - 0.03 + u.y * 0.0001, c.z + ez + u.z * 0.0001))
                        else:
                            rz = ez * 1.10 * h
                            czz = (c.z + ez * 1.06 - rz) if not st["bottom"] else (c.z - ez * 1.06 + rz)
                            q = Vector((c.x + u.x * ex * 1.16, c.y + 0.012 + u.y * 0.028, czz + u.z * rz))
                    if k in ("sclera", "iris", "pupil", "shine", "shine2") and f_eye != 1.0:
                        fi = f_eye * (st["iris"] if k in ("iris", "pupil") else 1.0)
                        q = c + (q - c) * fi
                    pos.append(q)
            for j, q in enumerate(pos):
                out[p["start"] + j] = q
        return out

    base = state_positions(STATES["neutra"])
    bm = bmesh.new()
    vs = [bm.verts.new(q) for q in base]
    bm.verts.ensure_lookup_table()
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
    for kname in ("neutra", "atenta", "surpresa", "alegre", "blink"):
        k = ob.shape_key_add(name=kname, from_mix=False)
        k.slider_min, k.slider_max = 0.0, 1.0
        pos = state_positions(STATES[kname])
        for i, q in enumerate(pos):
            k.data[i].co = q
    ob.parent = rig
    cl.bind_to_rig(ob, rig, single_bone="head")
    return ob


