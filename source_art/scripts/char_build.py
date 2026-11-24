"""Constroi um personagem organico do Rota Brava (RB-04-chars): malha, rig, pesos, rosto, animacoes, .blend e GLB. PROVISORIO.

Uso: tools/blender.ps1 --background --factory-startup --python source_art/scripts/char_build.py -- --id rastro|leme|extra_a|extra_b|extra_c
        [--blend X.blend] [--glb Y.glb] [--noanim]
Geometria 100% procedural (SKIN + SUBSURF + bmesh). Frente +Y no Blender = -Z na Godot. Origem nos pes.
"""
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bmesh
import bpy
from mathutils import Matrix, Vector

import char_face
import char_lib as cl
from rbart import REPO, arg_value, mat, new_object, reset_scene, tri_count, world_bbox

CHARS = {
    "rastro": dict(
        display="Rastro", K=1.0, levels=2, detail="hero", head_hat="wide", hair="bob", braid=True, glove="fingerless",
        vest="orange", notebook=True, bag=True, belt=True, scarf=False, tunic=False, torso_w=1.0, lean=True,
        brow_w=1.0, eye_size=1.0, iris_rot=0.0,
        pal=dict(skin="#E8B48A", hair="#4A2C20", shirt="#4FB3A5", vest="#F28C28", pants="#3F5B73", leather="#7A4B2A",
                 hat="#D9B56B", iris="#3E8E6A", eye="#FFFFFF"),
        anims=["idle", "walk", "crouch", "inspect_touch", "look_to_leme", "react_surprise"]),
    "leme": dict(
        display="Leme", K=1.03, levels=2, detail="hero", head_hat="dixie", hair="short", braid=False, glove="none",
        vest="cream", notebook=False, bag=False, belt=True, scarf=True, tunic=False, torso_w=1.12, lean=False,
        brow_w=1.25, eye_size=1.12, hands_big=1.4, iris_rot=0.0,
        pal=dict(skin="#C98E63", hair="#5A4636", shirt="#4C86C8", vest="#F2EEDC", pants="#2B4570", leather="#4A3426",
                 hat="#F7F7F2", band="#2B4570", scarf="#F26B5B", iris="#6B4423", eye="#FFFFFF"),
        anims=["idle", "walk", "idle_wheel", "steer_left", "steer_right", "react_horn"]),
    "extra_a": dict(
        display="ExtraA", K=1.03, levels=1, detail="simple", head_hat="straw", hair="short", braid=False, glove="none",
        vest="none", notebook=False, bag=False, belt=False, scarf=False, tunic=False, torso_w=1.0, lean=False,
        brow_w=1.0, eye_size=0.95, iris_rot=0.0,
        pal=dict(skin="#E0A877", hair="#2B2B30", shirt="#E86F5B", pants="#E8DCC0", leather="#B88B5A",
                 hat="#F0D060", iris="#3A3A3A", eye="#FFFFFF"),
        anims=["idle", "walk"]),
    "extra_b": dict(
        display="ExtraB", K=1.06, levels=1, detail="simple", head_hat="scarf", hair="ponytail", braid=False, glove="none",
        vest="none", notebook=False, bag=False, belt=False, scarf=False, tunic=True, torso_w=0.95, lean=False,
        brow_w=0.9, eye_size=1.05, iris_rot=0.0,
        pal=dict(skin="#8D5A3B", hair="#1E1E24", shirt="#8E6BBF", pants="#2F8F83", leather="#5A3A2A",
                 hat="#E0457B", iris="#2A1A10", eye="#FFFFFF"),
        anims=["idle", "walk"]),
    "extra_c": dict(
        display="ExtraC", K=1.04, levels=1, detail="simple", head_hat="beret", hair="short", braid=False, glove="none",
        vest="none", notebook=False, bag=False, belt=False, scarf=False, tunic=False, torso_w=1.18, lean=False,
        brow_w=1.15, eye_size=0.95, iris_rot=0.0,
        pal=dict(skin="#F3D2B3", hair="#B7B7B7", shirt="#3A7D44", pants="#4B4B5A", leather="#2B2B2B",
                 hat="#C0392B", iris="#4A6A8A", eye="#FFFFFF"),
        anims=["idle", "walk"]),
}

HEAD_C = (0.0, 0.0, 1.06)
HEAD_R = (0.165, 0.17, 0.18)


def V(*a):
    return Vector(a)


def hand_frame(sx):
    """Pulso W, direcao d da mao e eixos (f = frente/polegar, n = para dentro) em repouso (K=1)."""
    W = V(sx * 0.34, 0.03, 0.43)
    d = (V(sx * 0.37, 0.05, 0.34) - W).normalized()
    f = (V(0, 1, 0) - d * d.y).normalized()
    n = d.cross(f) * sx   # aponta para o corpo (palma)
    if n.x * sx > 0:
        n = -n
    return W, d, f, n


def make_skin_parts(cfg, M, S):
    """Retorna lista (nome, objeto, modo_de_peso)."""
    lv = cfg["levels"]
    P = cfg["pal"]
    tw = cfg["torso_w"]
    parts = []
    simple = cfg["detail"] == "simple"

    # --- corpo de pele: pescoco + antebracos (do cotovelo ao pulso; o resto fica sob a manga, evita pele vazando em poses extremas)
    nodes = [((0, 0, 0.855), 0.052), ((0, 0, 0.935), 0.046)]
    edges = [(0, 1)]
    roots = [0]
    for sx in (1, -1):
        base = len(nodes)
        roots.append(base)
        nodes += [((sx * 0.262, -0.002, 0.65), 0.034), ((sx * 0.27, 0.0, 0.62), 0.036), ((sx * 0.34, 0.03, 0.43), 0.029)]
        edges += [(base, base + 1), (base + 1, base + 2)]
    parts.append(("Body", cl.skin_obj(S + "_Body", nodes, edges, M["skin"], levels=lv, scale=(1, 0.9, 1), roots=roots), "dist"))
    # --- maos: cada uma e um objeto (duas raizes)
    for sx, sd in ((1, "R"), (-1, "L")):
        sub_n, sub_e = [], []
        W, d, f, n = hand_frame(sx)
        k = cfg.get("hands_big", 1.0)

        def add(co, r, link=None):
            sub_n.append((tuple(co), r))
            if link is not None:
                sub_e.append((link, len(sub_n) - 1))
            return len(sub_n) - 1
        w0 = add(W - d * 0.03, 0.030)
        palm = add(W + d * 0.040 * k, 0.036 * k, w0)
        if simple:
            blk = add(W + d * 0.075 * k + n * 0.005, 0.030 * k, palm)
            add(W + d * 0.102 * k + n * 0.012, 0.023 * k, blk)
            t0 = add(W + d * 0.040 * k + f * 0.028 * k, 0.017 * k, palm)
            add(W + d * 0.076 * k + f * 0.046 * k, 0.012 * k, t0)
        else:
            t0 = add(W + d * 0.040 * k + f * 0.026 * k, 0.019 * k, palm)
            t1 = add(W + d * 0.062 * k + f * 0.044 * k, 0.015 * k, t0)
            add(W + d * 0.080 * k + f * 0.052 * k + n * 0.006, 0.012 * k, t1)
            for off, ln in ((0.021, 0.050), (0.007, 0.058), (-0.007, 0.054), (-0.021, 0.044)):
                base = add(W + d * 0.072 * k + f * off * k, 0.0105 * k, palm)
                add(W + d * (0.072 + ln) * k + f * off * k + n * 0.012 * k, 0.0085 * k, base)
        parts.append(("Hand" + sd, cl.skin_obj(S + "_Hand" + sd, sub_n, sub_e, M["skin"], levels=max(lv - 1, 1) if not simple else 1), "dist"))

    # --- camisa (torso + mangas) ou tunica
    nodes = [((0, 0, 0.50), 0.125 * tw), ((0, 0, 0.60), 0.105 * tw), ((0, 0, 0.76), 0.118 * tw), ((0, 0, 0.855), 0.10 * tw)]
    edges = [(0, 1), (1, 2), (2, 3)]
    if cfg["tunic"]:
        nodes[0] = ((0, 0, 0.30), 0.135)
        nodes.insert(1, ((0, 0, 0.42), 0.125))
        edges = [(0, 1), (1, 2), (2, 3), (3, 4)]
    top_i = len(nodes) - 1
    chest_i = top_i - 1
    for sx in (1, -1):
        b = len(nodes)
        nodes += [((sx * 0.13 * (0.5 + tw * 0.5), 0, 0.845), 0.058), ((sx * 0.20, 0, 0.825), 0.056), ((sx * 0.27, 0, 0.62), 0.047),
                  ((sx * 0.305, 0.012, 0.53), 0.046)]
        edges += [(top_i, b), (b, b + 1), (b + 1, b + 2), (b + 2, b + 3)]
    parts.append(("Shirt", cl.skin_obj(S + "_Shirt", nodes, edges, M["shirt"], levels=lv, scale=(1, 0.80, 1)), "dist"))

    # --- colete: casca da propria camisa deslocada pela normal (nunca fica atras dela) com furos de manga e espessura
    if cfg["vest"] != "none":
        shirt = parts[-1][1]
        bmv = bmesh.new()
        bmv.from_mesh(shirt.data)
        cx = 0.150 * (0.5 + tw * 0.5)
        for pt, no, inner, outer in (((cx, 0, 0), (1, 0, 0), False, True), ((-cx, 0, 0), (-1, 0, 0), False, True),
                                     ((0, 0, 0.535), (0, 0, 1), True, False), ((0, 0, 0.865), (0, 0, 1), False, True)):
            g = bmv.verts[:] + bmv.edges[:] + bmv.faces[:]
            bmesh.ops.bisect_plane(bmv, geom=g, plane_co=pt, plane_no=no, clear_inner=inner, clear_outer=outer)
        bmv.normal_update()
        for v in bmv.verts:
            v.co += v.normal * 0.014
        vo = new_object(S + "_Vest", bmv, M["vest"], recalc=False)
        sol = vo.modifiers.new("sol", "SOLIDIFY")
        sol.thickness = 0.012
        sol.offset = -1
        parts.append(("Vest", vo, "dist"))
    # --- calca
    nodes = [((0, 0, 0.58), 0.108)]
    edges = []
    for sx in (1, -1):
        b = len(nodes)
        nodes += [((sx * 0.075, 0, 0.46), 0.088), ((sx * 0.085, 0.005, 0.30), 0.066 if not cfg["tunic"] else 0.058),
                  ((sx * 0.085, 0, 0.13), 0.062 if not cfg["tunic"] else 0.052)]
        edges += [(0, b), (b, b + 1), (b + 1, b + 2)]
    parts.append(("Pants", cl.skin_obj(S + "_Pants", nodes, edges, M["pants"], levels=lv, scale=(1, 0.9, 1)), "dist"))

    # --- botas
    nodes = []
    edges = []
    for sx in (1, -1):
        b = len(nodes)
        nodes += [((sx * 0.085, 0.0, 0.215), 0.063), ((sx * 0.085, 0.0, 0.105), 0.068), ((sx * 0.085, 0.075, 0.052), 0.068),
                  ((sx * 0.085, 0.145, 0.040), 0.054)]
        edges += [(b, b + 1), (b + 1, b + 2), (b + 2, b + 3)]
    # duas componentes: duas raizes -> cria dois objetos e junta? usamos uma por pe
    for sx, sd in ((1, "R"), (-1, "L")):
        b = [((sx * 0.085, 0.0, 0.215), 0.063), ((sx * 0.085, 0.0, 0.105), 0.068), ((sx * 0.085, 0.075, 0.052), 0.068),
             ((sx * 0.085, 0.145, 0.040), 0.054)]
        parts.append(("Boot" + sd, cl.skin_obj(S + "_Boot" + sd, b, [(0, 1), (1, 2), (2, 3)], M["leather"], levels=lv + 0, floor=0.0), "dist"))

    # --- luvas sem dedos (Rastro)
    if cfg["glove"] == "fingerless":
        for sx, sd in ((1, "R"), (-1, "L")):
            W, d, f, n = hand_frame(sx)
            nn = [(tuple(W - d * 0.04), 0.036), (tuple(W + d * 0.005), 0.039), (tuple(W + d * 0.050), 0.042), (tuple(W + d * 0.040 + f * 0.026), 0.024)]
            parts.append(("Glove" + sd, cl.skin_obj(S + "_Glove" + sd, nn, [(0, 1), (1, 2), (1, 3)], M["leather"], levels=lv), "dist"))
    return parts


def make_head(cfg, M, S):
    bm = bmesh.new()
    cl.ellipsoid(bm, (0, 0, 0), (1, 1, 1), 32, 20)
    for v in bm.verts:
        x, y, z = v.co
        if z < 0:
            taper = 1.0 - 0.20 * (-z) ** 1.3
            x *= taper
            y *= 1.0 - 0.07 * (-z)
        # bochechas ligeiramente cheias
        x *= 1.0 + 0.05 * math.exp(-((z + 0.25) ** 2) / 0.05)
        v.co = V(HEAD_C[0] + x * HEAD_R[0], HEAD_C[1] + y * HEAD_R[1], HEAD_C[2] + z * HEAD_R[2])
    # orelhas e nariz
    for sx in (1, -1):
        cl.ellipsoid(bm, (sx * 0.166, -0.004, 1.055), (0.015, 0.03, 0.040), 12, 8)
    sy = HEAD_C[1] + HEAD_R[1] * math.sqrt(max(1 - (0.0 / HEAD_R[0]) ** 2 - ((1.03 - HEAD_C[2]) / HEAD_R[2]) ** 2, 0.02))
    cl.ellipsoid(bm, (0, sy + 0.004, 1.034), (0.020, 0.022, 0.017), 14, 8)
    return new_object(S + "_Head", bm, M["skin"])


def make_hair(cfg, M, S):
    style = cfg["hair"]
    bm = bmesh.new()
    sc = (HEAD_R[0] * 1.07, HEAD_R[1] * 1.07, HEAD_R[2] * 1.06)
    cl.ellipsoid(bm, HEAD_C, sc, 32, 18)
    kill = []
    for f in bm.faces:
        c = f.calc_center_median() - Vector(HEAD_C)
        nx, ny, nz = c.x / sc[0], c.y / sc[1], c.z / sc[2]
        face_open = ny > 0.36 and abs(nx) < 0.84 and nz < 0.56 + 0.07 * math.sin(nx * 15)
        ear = abs(nx) > 0.80 and -0.25 < ny < 0.4 and -0.45 < nz < 0.15
        low = nz < (-0.74 if style in ("bob", "ponytail") else -0.12)
        top = nz > (0.25 if cfg["head_hat"] == "scarf" else 0.80)
        if face_open or ear or low or top:
            kill.append(f)
    bmesh.ops.delete(bm, geom=kill, context="FACES")
    # bob / volume dos lados
    for v in bm.verts:
        x, y, z = v.co - Vector(HEAD_C)
        if style == "bob" and z < 0.0 and y < 0.05:
            v.co.x += math.copysign(0.012, x) * (-z / sc[2])
            v.co.y -= 0.012 * (-z / sc[2])
    if style == "ponytail":
        cl.tube(bm, [(0, -0.15, 1.10), (0, -0.215, 1.07), (0, -0.25, 0.99), (0, -0.23, 0.90), (0, -0.20, 0.82)], [0.03, 0.036, 0.034, 0.028, 0.012], 8, True)
    ob = new_object(S + "_Hair", bm, M["hair"], recalc=False)
    sub = ob.modifiers.new("sub", "SUBSURF")
    sub.levels = 1
    # espessura visual: solidify fino
    sol = ob.modifiers.new("sol", "SOLIDIFY")
    sol.thickness = 0.008
    sol.offset = -1
    return ob


def make_hat(cfg, M, S, rig_K):
    kind = cfg["head_hat"]
    bm = bmesh.new()
    extra = []
    if kind == "wide":
        prof = [(0.0, 0.150), (0.075, 0.147), (0.130, 0.130), (0.162, 0.082), (0.170, 0.030), (0.175, 0.012), (0.23, 0.003), (0.30, -0.012),
                (0.306, -0.020), (0.30, -0.026), (0.23, -0.016), (0.172, -0.008), (0.165, 0.0), (0.0, 0.0)]

        def droop(r, z, a):
            if r > 0.17:
                t = (r - 0.17) / 0.14
                front = 0.5 - 0.5 * math.cos(a - math.pi / 2)       # 0 na frente (+Y), 1 atras
                k = 0.30 + 0.70 * front
                side = 1.0 + 0.45 * abs(math.cos(a))
                rr = r * (0.80 + 0.20 * front)
                return rr, z - 0.075 * t * t * k * side - 0.01 * t * math.sin(2 * a + 0.6)
            if z > 0.14:
                return r, z - 0.012 * math.exp(-(r * r) / 0.002) + 0.0
            return r, z
        cl.lathe(bm, prof, 40, droop)
        pos = (0, -0.005, 1.172)
        tilt = 1.0
        band = ("torus", 0.168, 0.016, 0.040)
    elif kind == "dixie":
        prof = [(0.0, 0.140), (0.080, 0.137), (0.128, 0.120), (0.150, 0.075), (0.158, 0.030), (0.185, 0.012), (0.215, 0.026), (0.222, 0.020),
                (0.19, 0.0), (0.165, -0.004), (0.0, -0.004)]
        cl.lathe(bm, prof, 40)
        pos, tilt = (0, -0.005, 1.150), -2.0
        band = ("torus", 0.160, 0.012, 0.028)
    elif kind == "straw":
        prof = [(0.0, 0.115), (0.09, 0.113), (0.14, 0.10), (0.158, 0.055), (0.162, 0.018), (0.19, 0.008), (0.245, -0.002), (0.25, -0.010),
                (0.24, -0.016), (0.19, -0.002), (0.162, 0.0), (0.0, 0.0)]

        def droop(r, z, a):
            if r > 0.17:
                t = (r - 0.17) / 0.12
                return r, z - 0.035 * t * t
            return r, z
        cl.lathe(bm, prof, 32, droop)
        pos, tilt = (0, -0.012, 1.18), 8.0
        band = ("torus", 0.160, 0.011, 0.030)
    elif kind == "beret":
        prof = [(0.0, 0.050), (0.09, 0.048), (0.165, 0.030), (0.205, 0.008), (0.200, -0.012), (0.165, -0.020), (0.0, -0.020)]
        cl.lathe(bm, prof, 32)
        cl.ellipsoid(bm, (0.0, 0.0, 0.058), (0.012, 0.012, 0.016), 8, 6)
        pos, tilt = (0.025, 0.0, 1.215), -10.0
        band = None
    else:  # scarf: lenco na cabeca com no atras
        cl.ellipsoid(bm, HEAD_C, (HEAD_R[0] * 1.10, HEAD_R[1] * 1.09, HEAD_R[2] * 1.09), 28, 16)
        kill = []
        for f in bm.faces:
            c = f.calc_center_median() - Vector(HEAD_C)
            nx, ny, nz = c.x / HEAD_R[0], c.y / HEAD_R[1], c.z / HEAD_R[2]
            if nz < 0.30 or (ny > 0.20 and nz < 0.62 + 0.05 * math.sin(nx * 9)):
                kill.append(f)
        bmesh.ops.delete(bm, geom=kill, context="FACES")
        cl.ellipsoid(bm, (0, -0.19, 1.11), (0.05, 0.045, 0.04), 12, 8)
        cl.ellipsoid(bm, (0.045, -0.215, 1.07), (0.03, 0.025, 0.055), 10, 6)
        cl.ellipsoid(bm, (-0.045, -0.215, 1.07), (0.03, 0.025, 0.055), 10, 6)
        ob = new_object(S + "_Hat", bm, M["hat"], recalc=False)
        sol = ob.modifiers.new("sol", "SOLIDIFY")
        sol.thickness = 0.008
        sol.offset = -1
        return ob
    if band is not None:
        cl_t = bmesh.new()
    ob = new_object(S + "_Hat", bm, M["hat"])
    ob.location = pos
    ob.rotation_euler = (math.radians(tilt), 0, 0)
    # aplica a transformacao na malha
    bpy.context.view_layer.update()
    ob.data.transform(ob.matrix_world)
    ob.location = (0, 0, 0)
    ob.rotation_euler = (0, 0, 0)
    objs = [ob]
    if band is not None:
        bb = bmesh.new()
        cl.torus_z(bb, band[1], band[2], band[3])
        bm2 = bb
        ob2 = new_object(S + "_HatBand", bm2, M["band"] if "band" in M else M["leather"])
        ob2.location = (0, 0, 0)
        ob2.data.transform(Matrix.Translation(pos) @ Matrix.Rotation(math.radians(tilt), 4, "X"))
        objs.append(ob2)
    return objs


def bake_modifiers(ob):
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
    old = ob.data
    for m in list(ob.modifiers):
        ob.modifiers.remove(m)
    ob.data = me
    me.name = old.name
    for p in me.polygons:
        p.use_smooth = True
    if not me.uv_layers:
        me.uv_layers.new(name="UVMap")
    bpy.data.meshes.remove(old)


def build(cid, blend_path=None, glb_path=None, with_anim=True):
    cfg = CHARS[cid]
    S = cfg["display"]
    K = cfg["K"]
    sc = reset_scene()
    sc.render.fps = 30
    pal = cfg["pal"]
    M = {}
    rough = {"skin": 0.7, "hair": 0.6, "shirt": 0.85, "vest": 0.8, "pants": 0.85, "leather": 0.7, "hat": 0.85, "iris": 0.35,
             "eye": 0.25, "band": 0.7, "scarf": 0.8}
    for role, col in pal.items():
        M[role] = mat("mat_%s_%s" % (cid, role), col, rough.get(role, 0.8))
    M["dark"] = M["hair"]
    if "vest" not in M:
        M["vest"] = M["shirt"]
    rig = cl.make_rig(S, K, cfg.get("hands_big", 1.0))
    rig["provisional"] = True
    rig["agent"] = "art3d"
    objs = []

    def reg(ob, mode="dist", bone=None):
        objs.append((ob, mode, bone))
        return ob

    skinparts = make_skin_parts(cfg, M, S)
    for name, ob, mode in skinparts:
        reg(ob, mode)
    reg(make_head(cfg, M, S), "single", "head")
    reg(make_hair(cfg, M, S), "single", "head")
    hat = make_hat(cfg, M, S, K)
    for h in (hat if isinstance(hat, list) else [hat]):
        reg(h, "single", "head")
    # acessorios
    acc = make_accessories(cfg, M, S, {n: o for n, o, _ in skinparts})
    for ob, bone in acc:
        reg(ob, "single", bone)
    # aplica modificadores de forma (solidify/subsurf) na malha: o GLB e exportado sem aplicar modificadores
    for ob, _, _ in objs:
        if any(m.type in ("SOLIDIFY", "SUBSURF") for m in ob.modifiers):
            bake_modifiers(ob)
    # escala do personagem (K) nas malhas (rig ja nasce escalado)
    for ob, _, _ in objs:
        ob.data.transform(Matrix.Scale(K, 4))
    face_ob = char_face.build_face(rig, S + "_Face", dict(eye=M["eye"], iris=M["iris"], dark=M["hair"], skin=M["skin"]),
                                   HEAD_C, HEAD_R, eye_size=cfg["eye_size"], eye_z=cfg.get("eye_z", 1.07), brow_w=cfg["brow_w"],
                                   brow_thick=0.0075 * (1.3 if cid == "leme" else 1.0))
    face_ob.data.transform(Matrix.Scale(K, 4), shape_keys=True)
    bpy.context.view_layer.update()
    XFER = {"Vest": "Shirt", "GloveR": "HandR", "GloveL": "HandL", "Belt": "Shirt", "VestDetails": "Shirt", "Scarf": "Shirt"}
    byname = {}
    for ob, mode, bone in objs:
        key = ob.name[len(S) + 1:]
        byname[key] = ob
        if key in XFER:
            continue
        if mode == "single":
            cl.bind_to_rig(ob, rig, single_bone=bone)
        else:
            cl.bind_to_rig(ob, rig)
            try:
                cl.smooth_weights(ob, 2, 0.5)
            except Exception as e:  # noqa
                print("aviso: suavizacao de pesos falhou", ob.name, e)
    for key, srcname in XFER.items():
        if key in byname and srcname in byname:
            cl.transfer_weights(byname[srcname], byname[key], rig)    # normaliza escala do .blend
    bpy.context.view_layer.update()
    allm = [o for o, _, _ in objs] + [face_ob]
    if with_anim:
        import char_anim
        char_anim.author(rig, face_ob, cfg, cid)
    bpy.context.view_layer.update()
    lo, hi = world_bbox(allm)
    mats = sorted({m.name for o in allm for m in o.data.materials if m})
    bones = [b.name for b in rig.data.bones]
    acts = {a.name: [round(a.frame_range[0]), round(a.frame_range[1])] for a in bpy.data.actions if not a.name.endswith("_key")}
    info = {"tris": tri_count(allm), "materials": mats, "height_m": round(hi.z - lo.z, 4), "min_z": round(lo.z, 4),
            "objects": sorted(o.name for o in allm), "bones": bones, "bone_count": len(bones), "animations": acts,
            "shape_keys": [k.name for k in face_ob.data.shape_keys.key_blocks]}
    print("CHAR_INFO", json.dumps(info))
    if blend_path:
        os.makedirs(os.path.dirname(blend_path), exist_ok=True)
        bpy.ops.wm.save_as_mainfile(filepath=blend_path)
        with open(os.path.splitext(blend_path)[0] + ".info.json", "w", encoding="utf-8") as f:
            json.dump(info, f, indent=2)
    if glb_path:
        os.makedirs(os.path.dirname(glb_path), exist_ok=True)
        bpy.ops.export_scene.gltf(filepath=glb_path, export_format="GLB", use_selection=False, export_yup=True,
                                  export_apply=False, export_morph=True, export_materials="EXPORT", export_cameras=False,
                                  export_lights=False, export_extras=True, export_skins=True, export_animations=True,
                                  export_animation_mode="NLA_TRACKS", export_force_sampling=True, export_frame_range=False,
                                  export_optimize_animation_size=False, export_def_bones=False)
    return rig


def make_accessories(cfg, M, S, body):
    out = []
    if cfg["belt"]:
        bm = bmesh.new()
        cl.torus_z(bm, 0.118 * cfg["torso_w"] * 0.95, 0.014, 0.585, sy=0.82)
        by = cl.snap_y(body["Vest"] if "Vest" in body else body["Shirt"], 0.0, 0.585)
        cl.rounded_box(bm, (0, by + 0.002, 0.585), (0.04, 0.016, 0.034), 0.004)
        ob = new_object(S + "_Belt", bm, M["leather"])
        out.append((ob, "spine"))
    if cfg["vest"] != "none":
        bm = bmesh.new()
        tw = cfg["torso_w"]
        vest = body["Vest"]
        for sx in (1, -1):
            x = sx * 0.066 * tw
            cl.rounded_box(bm, (x, cl.snap_y(vest, x, 0.665) - 0.002, 0.665), (0.062, 0.022, 0.056), 0.006)
        for z in (0.73, 0.79):
            cl.ellipsoid(bm, (0.0, cl.snap_y(vest, 0.0, z) - 0.001, z), (0.011, 0.007, 0.011), 8, 6)
        ob = new_object(S + "_VestDetails", bm, M["leather"])
        out.append((ob, "chest"))
    if cfg["notebook"]:
        bm = bmesh.new()
        # caderno no quadril esquerdo (-X), preso ao cinto por cordao
        cl.rounded_box(bm, (-0.178, 0.02, 0.47), (0.034, 0.17, 0.215), 0.007, rot=cl.rot_y(-6))
        ob = new_object(S + "_Notebook", bm, M["shirt"])
        out.append((ob, "hips"))
        bm = bmesh.new()
        cl.rounded_box(bm, (-0.1605, 0.02, 0.47), (0.004, 0.158, 0.2), 0.001)
        out.append((new_object(S + "_NotebookPages", bm, M["leather"] if False else M["hat"]), "hips"))
        bm = bmesh.new()
        cl.tube(bm, [(-0.15, 0.10, 0.585), (-0.19, 0.115, 0.56), (-0.185, 0.095, 0.53), (-0.178, 0.09, 0.55)], 0.0035, 6, True)
        out.append((new_object(S + "_Cord", bm, M["leather"]), "hips"))
    if cfg["bag"]:
        bm = bmesh.new()
        cl.rounded_box(bm, (0.135, -0.085, 0.50), (0.09, 0.075, 0.095), 0.015)
        cl.rounded_box(bm, (0.135, -0.085, 0.555), (0.095, 0.082, 0.03), 0.01)
        cl.ellipsoid(bm, (0.135, -0.124, 0.545), (0.012, 0.006, 0.012), 8, 6)
        out.append((new_object(S + "_Bag", bm, M["leather"]), "hips"))
    if cfg["scarf"]:
        bm = bmesh.new()
        cl.torus_z(bm, 0.075, 0.026, 0.885)
        cl.ellipsoid(bm, (0.0, 0.085, 0.865), (0.035, 0.022, 0.035), 10, 8)
        cl.tube(bm, [(0.0, 0.085, 0.86), (0.015, 0.095, 0.815), (0.03, 0.095, 0.78)], [0.022, 0.02, 0.012], 8, True)
        out.append((new_object(S + "_Scarf", bm, M["scarf"]), "chest"))
    if cfg["braid"]:
        bm = bmesh.new()
        pts = [(0.075, -0.15, 1.00), (0.09, -0.175, 0.95), (0.092, -0.185, 0.89), (0.09, -0.185, 0.835), (0.088, -0.18, 0.79)]
        cl.tube(bm, pts, [0.026, 0.028, 0.026, 0.024, 0.016], 8, True)
        cl.ellipsoid(bm, (0.088, -0.18, 0.775), (0.022, 0.022, 0.016), 8, 6)
        out.append((new_object(S + "_Braid", bm, M["hair"]), "head"))
    return out


def main():
    cid = arg_value("--id", "rastro")
    blend = arg_value("--blend", os.path.join(REPO, "source_art", "characters", "rb04", cid, cid + ".blend"))
    build(cid, blend, arg_value("--glb"), with_anim="--noanim" not in sys.argv)


main()






















