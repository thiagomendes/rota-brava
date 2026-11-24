"""Herois do RB-R1 (criancas-herois de ~1,10 m): corpo, uniforme de equipe com emblema, equipamento, rig e pesos.
PROVISORIO ate o Portao 1 (aprovacao de Thiago). Geometria 100% procedural: modificador SKIN + SUBSURF, metaballs
(cabelo), torno (chapeus), bmesh. Nada baixado ou importado. Nao reaproveita o visual do RB-04: so a infraestrutura
(char_lib: skin_obj, pesos, Rigger).

Convencao: Blender Z-up, frente = +Y (vira -Z na Godot), direita do personagem (.R) = +X. Origem nos pes.
Variacoes de proporcao: A "brinquedo brilhante", B "aventura", C "meio-termo" (ver VARIANTS).
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bmesh
import bpy
from mathutils import Matrix, Vector

import char_lib as cl
import hero_face
from rbart import mat, new_object

# ------------------------------------------------------------------ proporcoes
VARIANTS = {
    #       cabeca(m)  perna(quadril z) tronco  barriga  ombro_x  membro   mao   bota  olho
    "A": dict(head=0.420, leg=0.320, torso=0.255, belly=0.150, sh_x=0.118, limb=0.044, hand=1.18, boot=1.16, eye=1.10, layers=False, label="brinquedo brilhante"),
    "B": dict(head=0.380, leg=0.345, torso=0.290, belly=0.124, sh_x=0.132, limb=0.036, hand=1.00, boot=1.00, eye=0.96, layers=True, label="aventura"),
    "C": dict(head=0.395, leg=0.350, torso=0.272, belly=0.138, sh_x=0.124, limb=0.040, hand=1.10, boot=1.08, eye=1.04, layers=False, label="meio-termo"),
}

CAST = {
    "rastro": dict(display="Rastro", K=1.0, hat="wide", hair="pigtails", gear=("bag", "notebook", "lupa"), gloves=False,
                   pal=dict(pele="#C98B60", cabelo="#3A2419", iris="#8A5426", uniforme="#FF8A1F", creme="#FFF1D6",
                            calca="#2E4A70", botas="#7A4529", chapeu="#F6C877", couro="#94592F", emblema="#123A5E",
                            ouro="#FFC83D", olhos="#FFFFFF", escuro="#2A1A14", boca="#9C3341", rubor="#F08A7A", vidro="#BFEFFF")),
    "pico": dict(display="Pico", K=0.955, hat="helmet", hair="tufts", gear=("rope", "carabiners"), gloves=True,
                 pal=dict(pele="#F3C9A2", cabelo="#D8612A", iris="#2F7FC9", uniforme="#3DBE5A", creme="#FFD23F",
                          calca="#35506B", botas="#5B3A26", chapeu="#3DBE5A", couro="#2B7F46", emblema="#123A5E",
                          ouro="#FFC83D", olhos="#FFFFFF", escuro="#3A1E12", boca="#A63A3F", rubor="#F49A8A", metal="#D6DEE6",
                          corda="#FFD23F", luz="#FFF6B0")),
    "leme": dict(display="Leme", K=1.04, hat="cap", hair="curls", gear=("lifevest", "compass"), gloves=False,
                 pal=dict(pele="#7A4A2E", cabelo="#18110E", iris="#5A3418", uniforme="#2F8CFF", creme="#F7FBFF",
                          calca="#22416B", botas="#3E2A20", chapeu="#F7FBFF", couro="#123A5E", emblema="#123A5E",
                          ouro="#FFC83D", olhos="#FFFFFF", escuro="#120B08", boca="#8E2F38", rubor="#C9705E", refletivo="#E3ECF2",
                          colete="#F7FBFF")),
}


def V(*a):
    return Vector(a)


class Frame:
    """Pontos-chave do corpo para uma variacao (a escala 1; o K do personagem e aplicado no fim)."""

    def __init__(self, v):
        self.v = v
        self.hz = v["leg"]                       # articulacao do quadril
        self.nz = self.hz + v["torso"]           # base do pescoco
        self.head_h = v["head"]
        self.chin = self.nz + 0.012
        self.hc = V(0.0, 0.008, self.chin + self.head_h / 2)
        self.hr = (self.head_h * 0.50, self.head_h * 0.475, self.head_h / 2)
        self.k = self.head_h / 0.36              # escala do rosto em relacao a cabeca padrao
        self.sh = V(v["sh_x"], 0.0, self.nz - 0.042)
        self.wrist_z = self.hz - 0.005
        al = self.sh.z - self.wrist_z
        self.wrist = V(v["belly"] + v["limb"] + 0.040, 0.012, self.wrist_z + 0.02)
        self.elbow = V((v["sh_x"] + self.wrist.x) * 0.5 + 0.004, -0.012, self.sh.z - al * 0.48)
        self.hip_x = 0.064 + (v["belly"] - 0.13) * 0.4
        self.knee_z = self.hz * 0.52
        self.ankle_z = 0.085 * v["boot"]
        self.heel_y = -0.060 * v["boot"]
        self.ball_y = 0.090 * v["boot"]
        self.toe_y = 0.160 * v["boot"]

    def hand_frame(self, sx):
        W = V(sx * self.wrist.x, self.wrist.y, self.wrist.z)
        d = V(sx * 0.30, 0.12, -1.0).normalized()
        f = (V(0, 1, 0) - d * d.y).normalized()
        n = d.cross(f) * sx
        if n.x * sx > 0:
            n = -n
        return W, d, f, n


# ------------------------------------------------------------------ rig (mesmos 28 ossos + ponteiras do RB-04)
def bone_table(F):
    v = F.v
    hk = v["hand"]
    B = [("root", (0, 0, 0), (0, 0, 0.10), None, False),
         ("hips", (0, 0, F.hz), (0, 0, F.hz + 0.07), "root", True),
         ("spine", (0, 0, F.hz + 0.07), (0, 0, F.hz + 0.16), "hips", True),
         ("chest", (0, 0, F.hz + 0.16), (0, 0, F.nz - 0.01), "spine", True),
         ("neck", (0, 0, F.nz - 0.01), (0, 0, F.chin + 0.03), "chest", True),
         ("head", (0, 0, F.chin + 0.03), (0, 0, F.chin + F.head_h), "neck", True)]
    for sx, s in ((1, "R"), (-1, "L")):
        sh = V(sx * F.sh.x, F.sh.y, F.sh.z)
        el = V(sx * F.elbow.x, F.elbow.y, F.elbow.z)
        W, d, f, n = F.hand_frame(sx)
        Ht = W + d * 0.105 * hk
        B += [("shoulder." + s, (sx * 0.035, 0, F.sh.z + 0.005), tuple(sh), "chest", True),
              ("upper_arm." + s, tuple(sh), tuple(el), "shoulder." + s, True),
              ("forearm." + s, tuple(el), tuple(W), "upper_arm." + s, True),
              ("hand." + s, tuple(W), tuple(Ht), "forearm." + s, True),
              ("hand_tip." + s, tuple(Ht), tuple(Ht + d * 0.02), "hand." + s, False),
              ("thigh." + s, (sx * F.hip_x, 0, F.hz - 0.02), (sx * F.hip_x, 0.006, F.knee_z), "hips", True),
              ("shin." + s, (sx * F.hip_x, 0.006, F.knee_z), (sx * F.hip_x, 0, F.ankle_z), "thigh." + s, True),
              ("foot." + s, (sx * F.hip_x, 0, F.ankle_z), (sx * F.hip_x, F.ball_y, 0.0), "shin." + s, True),
              ("toe." + s, (sx * F.hip_x, F.ball_y, 0.0), (sx * F.hip_x, F.toe_y, 0.0), "foot." + s, True),
              ("toe_tip." + s, (sx * F.hip_x, F.toe_y, 0.0), (sx * F.hip_x, F.toe_y + 0.02, 0.0), "toe." + s, False),
              ("heel." + s, (sx * F.hip_x, F.heel_y, 0.0), (sx * F.hip_x, F.heel_y, 0.03), "foot." + s, False)]
    return B


def make_rig(name, F, K):
    arm = bpy.data.armatures.new(name + "_Armature")
    ob = bpy.data.objects.new(name, arm)
    bpy.context.scene.collection.objects.link(ob)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.mode_set(mode="EDIT")
    for (n, h, t, p, d) in bone_table(F):
        b = arm.edit_bones.new(n)
        b.head = Vector(h) * K
        b.tail = Vector(t) * K
        b.use_deform = d
        if p:
            b.parent = arm.edit_bones[p]
            b.use_connect = False
    bpy.ops.object.mode_set(mode="OBJECT")
    arm.display_type = "STICK"
    return ob


def bone_radii(F):
    v = F.v
    L, b = v["limb"], v["belly"]
    return {"hips": b, "spine": b, "chest": b * 0.95, "neck": 0.045, "head": F.head_h * 0.5, "shoulder": L * 1.3,
            "upper_arm": L * 1.35, "forearm": L * 1.05, "hand": 0.040 * v["hand"], "thigh": 0.070, "shin": 0.058,
            "foot": 0.065 * v["boot"], "toe": 0.055 * v["boot"]}


def geom_weights(ob, rig, F, power=6.0, max_inf=3, only=None):
    """Pesos pela distancia ao segmento do osso NORMALIZADA pela espessura real daquela parte do corpo."""
    rad = bone_radii(F)
    for g in list(ob.vertex_groups):
        ob.vertex_groups.remove(g)
    bones = [bb for bb in rig.data.bones if bb.use_deform]
    groups = {bb.name: ob.vertex_groups.new(name=bb.name) for bb in bones}
    segs = [(bb.name, Vector(bb.head_local), Vector(bb.tail_local), rad.get(bb.name.split(".")[0], 0.06)) for bb in bones
            if only is None or bb.name in only]
    mw = ob.matrix_world
    for vtx in ob.data.vertices:
        p = mw @ vtx.co
        ws = []
        for (n, h, t, r) in segs:
            d = t - h
            u = max(0.0, min(1.0, (p - h).dot(d) / max(d.length_squared, 1e-9)))
            dist = (p - (h + d * u)).length
            ws.append((n, 1.0 / ((dist / r) ** power + 1e-4)))
        ws.sort(key=lambda a: -a[1])
        ws = ws[:max_inf]
        tot = sum(w for _, w in ws)
        for n, w in ws:
            if w / tot > 0.02:
                groups[n].add([vtx.index], w / tot, "REPLACE")
    mod = ob.modifiers.new("Armature", "ARMATURE")
    mod.object = rig
    ob.parent = rig


def auto_weights(ob, rig):
    """Pesos por difusao de calor do Blender (Armature > Automatic Weights), limitados a 4 e normalizados."""
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    ob.select_set(True)
    rig.select_set(True)
    bpy.context.view_layer.objects.active = rig
    try:
        bpy.ops.object.parent_set(type="ARMATURE_AUTO")
    except RuntimeError as e:
        print("aviso:", e)
        return False
    me = ob.data
    empty = sum(1 for v in me.vertices if not v.groups)
    if empty > len(me.vertices) * 0.02:
        for g in list(ob.vertex_groups):
            ob.vertex_groups.remove(g)
        for m in list(ob.modifiers):
            ob.modifiers.remove(m)
        ob.parent = None
        return False
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.vertex_group_limit_total(group_select_mode="ALL", limit=4)
    bpy.ops.object.vertex_group_normalize_all(group_select_mode="ALL", lock_active=False)
    ob.select_set(False)
    rig.select_set(False)
    return True


# ------------------------------------------------------------------ utilidades
def join_bm(dst, src):
    me = bpy.data.meshes.new("tmp")
    src.to_mesh(me)
    src.free()
    dst.from_mesh(me)
    bpy.data.meshes.remove(me)


def bake(ob):
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


def bisect_keep(bm, co, no, keep_above=True):
    g = bm.verts[:] + bm.edges[:] + bm.faces[:]
    bmesh.ops.bisect_plane(bm, geom=g, plane_co=co, plane_no=no, clear_inner=keep_above, clear_outer=not keep_above)


def metaball_obj(name, elems, material, res=0.012, thresh=0.6):
    """elems: (tipo, co, raio, (sx, sy, sz) ou None, negativo). Converte para malha."""
    mb = bpy.data.metaballs.new(name + "_mb")
    mb.resolution = res
    mb.render_resolution = res
    mb.threshold = thresh
    for kind, co, r, size, neg in elems:
        e = mb.elements.new(type=kind)
        e.co = co
        e.radius = r * 1.74    # raio visivel ~ raio informado (campo com limiar 0,6)
        e.use_negative = neg
        if size is not None:
            e.size_x, e.size_y, e.size_z = size
    tmp = bpy.data.objects.new(name + "_mbo", mb)
    bpy.context.scene.collection.objects.link(tmp)
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(tmp.evaluated_get(dg))
    bpy.data.objects.remove(tmp)
    bpy.data.metaballs.remove(mb)
    bm = bmesh.new()
    bm.from_mesh(me)
    bpy.data.meshes.remove(me)
    return new_object(name, bm, material)


def prism(bm, outline, depth, center, normal_y=True, bevel=0.0):
    """Extruda um poligono 2D (x, z) em +Y a partir de center (face frontal em center.y + depth)."""
    c = Vector(center)
    back = [bm.verts.new((c.x + x, c.y, c.z + z)) for x, z in outline]
    front = [bm.verts.new((c.x + x, c.y + depth, c.z + z)) for x, z in outline]
    n = len(outline)
    bm.faces.new(list(reversed(back)))
    bm.faces.new(front)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((back[i], back[j], front[j], front[i]))


def emblem_outline(w, h, n=28):
    """Escudo-gota da Rota Brava: base redonda, laterais que sobem e topo em onda suave."""
    m = n // 2
    right = []
    for i in range(m + 1):
        s = i / m
        right.append((w * 0.5 * (1 - s ** 2.6) ** 0.5 * (1 - 0.15 * s), h * 0.5 - s * h))
    left = [(-x, z) for x, z in reversed(right[:-1])]
    top = []
    for i in range(1, 8):
        u = i / 8
        top.append((-w * 0.5 + u * w, h * 0.5 - 0.10 * h * math.sin(math.pi * u) + 0.03 * h * math.sin(2 * math.pi * u)))
    # canto sup. direito -> ponta de baixo -> canto sup. esquerdo -> topo em onda (esquerda -> direita)
    return right + left + top


def star4(r_out, r_in, rot=0.0):
    pts = []
    for i in range(8):
        a = rot + math.pi / 2 + i * math.pi / 4
        r = r_out if i % 2 == 0 else r_in
        pts.append((math.cos(a) * r, math.sin(a) * r))
    return pts


# ------------------------------------------------------------------ partes
class Builder:
    def __init__(self, cid, variant):
        self.cid = cid
        self.cfg = CAST[cid]
        self.v = VARIANTS[variant]
        self.F = Frame(self.v)
        self.S = self.cfg["display"]
        self.M = {}
        rough = dict(olhos=0.15, iris=0.25, vidro=0.05, metal=0.3)
        for role, col in self.cfg["pal"].items():
            self.M[role] = mat("mat_%s_%s" % (cid, role), col, rough.get(role, 0.75))
        self.parts = []     # (ob, modo, osso)  modo: dist | single | xfer:<parte>

    def reg(self, ob, mode="dist", bone=None):
        self.parts.append((ob, mode, bone))
        return ob

    def name(self, n):
        return self.S + "_" + n

    # ---- cabeca
    def head(self):
        F = self.F
        bm = bmesh.new()
        cl.ellipsoid(bm, (0, 0, 0), (1, 1, 1), 32, 20)
        for v in bm.verts:
            x, y, z = v.co
            if z < 0:                                      # mandibula arredondada de crianca (pouco afunilada)
                x *= 1.0 - 0.13 * (-z) ** 1.6
                y *= 1.0 - 0.04 * (-z)
            x *= 1.0 + 0.06 * math.exp(-((z + 0.30) ** 2) / 0.04) * max(y, 0.0)   # bochechas cheias
            if y > 0 and z > 0.05:                         # testa ampla
                y *= 1.0 + 0.03 * z
            v.co = V(F.hc.x + x * F.hr[0], F.hc.y + y * F.hr[1], F.hc.z + z * F.hr[2])
        k = F.k
        for sx in (1, -1):   # orelhas
            cl.ellipsoid(bm, (sx * F.hr[0] * 0.97, F.hc.y - 0.006, F.hc.z - 0.030 * k), (0.016 * k, 0.026 * k, 0.034 * k), 12, 8)
        ob = new_object(self.name("Head"), bm, self.M["pele"])
        # nariz botao e rubor
        bm = bmesh.new()
        ny = cl.snap_y(ob, 0.0, F.hc.z - 0.075 * k) or F.hc.y + F.hr[1]
        cl.ellipsoid(bm, (0, ny + 0.002 * k, F.hc.z - 0.073 * k), (0.019 * k, 0.015 * k, 0.014 * k), 14, 8)
        nose = new_object(self.name("Nose"), bm, self.M["pele"])
        bm = bmesh.new()
        for sx in (1, -1):
            x, z = sx * 0.095 * k, F.hc.z - 0.085 * k
            yy = cl.snap_y(ob, x, z) or F.hc.y + 0.1
            tb = bmesh.new()
            cl.ellipsoid(tb, (0, 0, 0), (0.022 * k, 0.0025 * k, 0.013 * k), 10, 5)
            q = V(sx * 0.55, 1.0, -0.15).normalized().to_track_quat("Y", "Z").to_matrix().to_4x4()
            cl.transform_bm(tb, Matrix.Translation((x, yy - 0.0005, z)) @ q)
            join_bm(bm, tb)
        blush = new_object(self.name("Blush"), bm, self.M["rubor"])
        self.head_ob = ob
        self.reg(ob, "single", "head")
        self.reg(nose, "single", "head")
        self.reg(blush, "single", "head")
        return ob

    def hair(self):
        F, k, kind = self.F, self.F.k, self.cfg["hair"]
        hc, hr = F.hc, F.hr
        E = [("ELLIPSOID", (hc.x, hc.y - 0.012 * k, hc.z + 0.020 * k), 1.0, (hr[0] * 1.04, hr[1] * 1.02, hr[2] * 1.0), False)]
        # franja: mechas arredondadas na testa
        bangs = []
        for bx, bz, bs in bangs:
            x = bx * k
            z = hc.z + bz * k
            E.append(("ELLIPSOID", (x, hc.y + hr[1] * 0.68, z), 1.0, (bs * k, 0.040 * k, 0.034 * k), False))
        E.append(("ELLIPSOID", (hc.x, hc.y + hr[1] * 0.25, hc.z - 0.20 * k), 1.0, (hr[0] * 1.3, hr[1] * 0.75, 0.13 * k), True))  # rosto livre
        if kind == "pigtails":
            for sx in (1, -1):
                E.append(("BALL", (sx * (hr[0] + 0.045 * k), hc.y - 0.045 * k, hc.z - 0.030 * k), 0.058 * k, None, False))
            E.append(("ELLIPSOID", (0, hc.y - hr[1] * 0.55, hc.z - 0.08 * k), 1.0, (hr[0] * 0.85, 0.07 * k, 0.12 * k), False))
        elif kind == "tufts":
            for ax, az in ((-0.13, 0.02), (0.13, 0.02), (-0.06, -0.03), (0.09, -0.06), (0.0, 0.02)):
                E.append(("BALL", (ax * k, hc.y + 0.13 * k, hc.z + 0.10 * k + az * k), 0.050 * k, None, False))
            for sx in (1, -1):
                E.append(("BALL", (sx * hr[0] * 0.95, hc.y - 0.02 * k, hc.z - 0.02 * k), 0.050 * k, None, False))
            E.append(("ELLIPSOID", (0, hc.y - hr[1] * 0.6, hc.z - 0.05 * k), 1.0, (hr[0] * 0.8, 0.06 * k, 0.10 * k), False))
        elif kind == "curls":
            for i in range(9):
                a = -math.pi * 0.85 + i * math.pi * 1.7 / 8
                E.append(("BALL", (math.sin(a) * hr[0] * 0.92, hc.y + math.cos(a) * hr[1] * 0.75 - 0.03 * k, hc.z + 0.10 * k), 0.058 * k, None, False))
            for sx in (1, -1):
                E.append(("BALL", (sx * hr[0] * 0.92, hc.y - 0.03 * k, hc.z + 0.0), 0.055 * k, None, False))
        ob = metaball_obj(self.name("Hair"), E, self.M["cabelo"], res=0.020 * k, thresh=0.6)
        # remove o que invade o rosto (mantem franja acima das sobrancelhas)
        bm = bmesh.new()
        bm.from_mesh(ob.data)
        brow_top = hc.z + 0.062 * k
        kill = [v for v in bm.verts if (v.co.y > hc.y + hr[1] * 0.35 and v.co.z < brow_top and abs(v.co.x) < hr[0] * 0.80)
                or (self.cfg["hat"] != "none" and v.co.y > hc.y + hr[1] * 0.45 and abs(v.co.x) < hr[0] * 0.70)]
        bmesh.ops.delete(bm, geom=kill, context="VERTS")
        bm.to_mesh(ob.data)
        bm.free()
        self.reg(ob, "single", "head")
        if kind == "pigtails":   # prendedores laranja
            bm = bmesh.new()
            for sx in (1, -1):
                tb = bmesh.new()
                cl.torus_z(tb, 0.026 * k, 0.010 * k, 0.0, major=12, minor=5)
                cl.transform_bm(tb, Matrix.Translation((sx * (hr[0] + 0.004 * k), hc.y - 0.035 * k, hc.z - 0.030 * k)) @ cl.rot_y(90))
                join_bm(bm, tb)
            self.reg(new_object(self.name("HairTies"), bm, self.M["uniforme"]), "single", "head")
        return ob

    def hat(self):
        F, k, kind = self.F, self.F.k, self.cfg["hat"]
        hc, hr = F.hc, F.hr
        M = self.M
        out = []
        top = hc.z + hr[2]
        if kind == "wide":
            R = hr[0] * 1.02
            prof = [(0.0, 0.150), (0.07, 0.147), (0.118, 0.130), (0.146, 0.092), (0.153, 0.040), (0.154, 0.010), (0.19, 0.006),
                    (0.222, 0.016), (0.229, 0.010), (0.223, 0.001), (0.19, -0.006), (0.154, -0.008), (0.0, -0.008)]
            s = R / 0.150

            def deform(r, z, a):
                # dente no topo (amassado do chapeu de explorador) e aba levemente virada para cima na frente
                if z > 0.10:
                    z -= 0.016 * math.exp(-(r * r) / 0.003) * (0.5 + 0.5 * abs(math.sin(a)))
                if r > 0.16:
                    t = (r - 0.16) / 0.10
                    front = 0.5 + 0.5 * math.sin(a)      # 1 na frente (+Y)
                    z += 0.020 * t * t * (front - 0.25)
                return r, z
            bm = bmesh.new()
            cl.lathe(bm, [(r * s, z * s) for r, z in prof], 40, lambda r, z, a: tuple(v * s for v in deform(r / s, z / s, a)))
            tilt, pos = -20.0, V(0.0, hc.y - 0.030 * k, top - 0.085 * k)
            ob = new_object(self.name("Hat"), bm, M["chapeu"])
            m = Matrix.Translation(pos) @ cl.Matrix.Rotation(math.radians(tilt), 4, "X")
            ob.data.transform(m)
            out.append(ob)
            # faixa (azul-marinho) com a rosa dos ventos amarela na frente
            bm = bmesh.new()
            cl.torus_z(bm, 0.149 * s, 0.0085 * s, 0.024 * s, major=36, minor=6)
            cl.transform_bm(bm, m)
            out.append(new_object(self.name("HatBand"), bm, M["emblema"]))
            bm = bmesh.new()
            prism(bm, star4(0.020 * s, 0.007 * s), 0.006 * s, (0, 0.150 * s - 0.002, 0.024 * s))
            cl.transform_bm(bm, m)
            out.append(new_object(self.name("HatStar"), bm, M["ouro"]))
        elif kind == "helmet":
            R = hr[0] * 1.06
            s = R / 0.150
            prof = [(0.0, 0.140), (0.07, 0.137), (0.118, 0.118), (0.145, 0.078), (0.153, 0.030), (0.155, 0.0), (0.150, -0.008), (0.0, -0.008)]
            bm = bmesh.new()
            cl.lathe(bm, [(r * s, z * s) for r, z in prof], 40)
            for v in bm.verts:                                     # viseira curta na frente
                if v.co.z < 0.02 * s and v.co.y > 0:
                    v.co.y *= 1.0 + 0.18 * max(0.0, v.co.y / (0.155 * s)) ** 3
            pos = V(0.0, hc.y - 0.010 * k, top - 0.090 * k)
            m = Matrix.Translation(pos) @ cl.Matrix.Rotation(math.radians(-6), 4, "X")
            cl.transform_bm(bm, m)
            out.append(new_object(self.name("Hat"), bm, M["chapeu"]))
            bm = bmesh.new()                                       # aro e faixa amarela + lanterna
            cl.torus_z(bm, 0.152 * s, 0.009 * s, 0.006 * s, major=36, minor=6)
            cl.ellipsoid(bm, (0, 0.0, 0.142 * s), (0.016 * s, 0.11 * s, 0.010 * s), 10, 6)
            cl.transform_bm(bm, m)
            out.append(new_object(self.name("HatBand"), bm, M["creme"]))
            bm = bmesh.new()
            cl.Vector = Vector
            tb = bmesh.new()
            cl.lathe(tb, [(0.0, 0.03), (0.026, 0.03), (0.030, 0.018), (0.024, 0.0), (0.0, 0.0)], 20)
            cl.transform_bm(tb, Matrix.Translation((0, 0.138 * s, 0.075 * s)) @ cl.Matrix.Rotation(math.radians(-80), 4, "X") @ Matrix.Scale(s * 0.9, 4))
            join_bm(bm, tb)
            cl.transform_bm(bm, m)
            out.append(new_object(self.name("Lamp"), bm, M["metal"]))
            bm = bmesh.new()
            cl.ellipsoid(bm, (0, 0.166 * s, 0.081 * s), (0.022 * s, 0.006 * s, 0.022 * s), 14, 6)
            cl.transform_bm(bm, m)
            out.append(new_object(self.name("LampLight"), bm, M["luz"]))
        else:  # cap: bone nautico (copa branca, aba e faixa azul-marinho, ancora-estrela dourada)
            R = hr[0] * 1.02
            s = R / 0.150
            prof = [(0.0, 0.090), (0.12, 0.092), (0.180, 0.084), (0.186, 0.070), (0.160, 0.045), (0.152, 0.010), (0.150, -0.006), (0.0, -0.006)]
            bm = bmesh.new()
            cl.lathe(bm, [(r * s, z * s) for r, z in prof], 40)
            pos = V(0.0, hc.y - 0.020 * k, top - 0.060 * k)
            m = Matrix.Translation(pos) @ cl.Matrix.Rotation(math.radians(-8), 4, "X")
            cl.transform_bm(bm, m)
            out.append(new_object(self.name("Hat"), bm, M["chapeu"]))
            bm = bmesh.new()
            cl.torus_z(bm, 0.152 * s, 0.014 * s, 0.022 * s, major=36, minor=6)
            # aba (pala) curva na frente
            pts = []
            tb = bmesh.new()
            rows = []
            for i in range(9):
                a = math.radians(30 + i * 15)
                ring = []
                for rr, zz in ((0.150, 0.006), (0.215, -0.004), (0.235, -0.012)):
                    ring.append(tb.verts.new((math.cos(a) * rr * s, math.sin(a) * rr * s, zz * s)))
                rows.append(ring)
            for i in range(8):
                for j in range(2):
                    tb.faces.new((rows[i][j], rows[i + 1][j], rows[i + 1][j + 1], rows[i][j + 1]))
            tb.normal_update()
            me_t = bpy.data.meshes.new("t")
            tb.to_mesh(me_t)
            tb.free()
            bm.from_mesh(me_t)
            bpy.data.meshes.remove(me_t)
            cl.transform_bm(bm, m)
            ob = new_object(self.name("HatBand"), bm, M["couro"], recalc=False)
            sol = ob.modifiers.new("sol", "SOLIDIFY")
            sol.thickness = 0.010
            bake(ob)
            out.append(ob)
            bm = bmesh.new()
            prism(bm, star4(0.020 * s, 0.007 * s), 0.006 * s, (0, 0.158 * s, 0.050 * s))
            cl.transform_bm(bm, m)
            out.append(new_object(self.name("HatStar"), bm, M["ouro"]))
        for o in out:
            self.reg(o, "single", "head")
        return out

    # ---- corpo
    def body(self):
        F, v, M = self.F, self.v, self.M
        hz, nz, b, L = F.hz, F.nz, v["belly"], v["limb"]
        # pescoco (pele)
        nodes = [((0, 0.004, nz - 0.03), 0.040), ((0, 0.006, F.chin + 0.04), 0.036)]
        neck = cl.skin_obj(self.name("Neck"), nodes, [(0, 1)], M["pele"], levels=1)
        self.reg(neck, "dist")
        # maos com 4 dedos (polegar + 3), grandes e redondas
        for sx, sd in ((1, "R"), (-1, "L")):
            W, d, f, n = F.hand_frame(sx)
            k = v["hand"]
            nn, ee = [], []

            def add(co, r, link=None):
                nn.append((tuple(co), r))
                if link is not None:
                    ee.append((link, len(nn) - 1))
                return len(nn) - 1
            w0 = add(W - d * 0.020, 0.028 * k)
            palm = add(W + d * 0.034 * k, 0.036 * k, w0)
            t0 = add(W + d * 0.030 * k + f * 0.030 * k + n * 0.004, 0.016 * k, palm)
            add(W + d * 0.054 * k + f * 0.046 * k + n * 0.010, 0.0135 * k, t0)
            for off, ln in ((0.019, 0.040), (0.0, 0.046), (-0.019, 0.040)):
                base = add(W + d * 0.064 * k + f * off * k, 0.0150 * k, palm)
                add(W + d * (0.064 + ln) * k + f * off * k + n * 0.012 * k, 0.0135 * k, base)
            mat_h = M["couro"] if self.cfg["gloves"] else M["pele"]
            self.reg(cl.skin_obj(self.name("Hand" + sd), nn, ee, mat_h, levels=2), "dist")
        # jaqueta de equipe (tronco + mangas inteiras)
        tw = 1.0
        nodes = [((0, 0, hz - 0.13), b * 0.90), ((0, 0.004, hz + 0.03), b * 1.0), ((0, 0, nz - 0.08), b * 0.90),
                 ((0, 0, nz - 0.020), 0.070)]
        edges = [(0, 1), (1, 2), (2, 3)]
        for sx in (1, -1):
            i0 = len(nodes)
            sh = V(sx * F.sh.x * 0.82, 0, F.sh.z)
            el = V(sx * F.elbow.x, F.elbow.y, F.elbow.z)
            W = V(sx * F.wrist.x, F.wrist.y, F.wrist.z)
            nodes += [(tuple(sh), L * 1.40), (tuple(el), L * 1.05), (tuple(W.lerp(el, 0.12)), L * 0.98)]
            edges += [(3, i0), (i0, i0 + 1), (i0 + 1, i0 + 2)]
        jk = cl.skin_obj(self.name("Jacket_g"), nodes, edges, M["uniforme"], levels=2, scale=(1, 0.86, 1))
        bm = bmesh.new()
        bm.from_mesh(jk.data)
        hem = hz - (0.105 if v["layers"] else 0.080)
        bisect_keep(bm, (0, 0, hem), (0, 0, 1), keep_above=True)
        jme = jk.data
        bpy.data.objects.remove(jk)
        jme.name = "tmp_jk"
        jacket = new_object(self.name("Jacket"), bm, M["uniforme"], recalc=False)
        self.jacket = jacket
        self.reg(jacket, "dist")
        # calca (por baixo da jaqueta) ate dentro das botas
        hem = hz - (0.105 if v["layers"] else 0.080)
        prx, pry = self.jacket_radius(hem + 0.006)
        nodes = [((0, 0, hz + 0.01), min(prx, pry / 0.92) * 0.80)]
        edges = []
        for sx in (1, -1):
            i0 = len(nodes)
            nodes += [((sx * F.hip_x, 0, hz - 0.05), 0.072), ((sx * F.hip_x, 0.006, F.knee_z), 0.058),
                      ((sx * F.hip_x, 0.0, F.ankle_z + 0.06), 0.052)]
            edges += [(0, i0), (i0, i0 + 1), (i0 + 1, i0 + 2)]
        self.reg(cl.skin_obj(self.name("Pants"), nodes, edges, M["calca"], levels=2, scale=(1, 0.92, 1)), "dist")
        # botas grandes com sola clara
        bk = v["boot"]
        for sx, sd in ((1, "R"), (-1, "L")):
            x = sx * F.hip_x
            nn = [((x, -0.004, F.ankle_z + 0.085 * bk), 0.060 * bk), ((x, -0.008, F.ankle_z + 0.005), 0.066 * bk),
                  ((x, F.ball_y * 0.75, 0.050 * bk), 0.064 * bk), ((x, F.toe_y - 0.040 * bk, 0.050 * bk), 0.055 * bk)]
            boot = cl.skin_obj(self.name("Boot" + sd), nn, [(0, 1), (1, 2), (2, 3)], M["botas"], levels=2, floor=0.022 * bk)
            self.reg(boot, "dist")
            bm = bmesh.new()
            pts = []
            n_ = 20
            for i in range(n_):
                a = 2 * math.pi * i / n_
                cy = (F.heel_y + F.toe_y) * 0.5 - 0.006
                ry = (F.toe_y - F.heel_y) * 0.5 + 0.014 * bk
                rx = 0.064 * bk * (1.0 + 0.10 * math.sin(a))
                pts.append((math.cos(a) * rx, cy + math.sin(a) * ry))
            back = [bm.verts.new((x + px, py, 0.0)) for px, py in pts]
            front = [bm.verts.new((x + px * 1.02, py * 1.0, 0.030 * bk)) for px, py in pts]
            bm.faces.new(list(reversed(back)))
            bm.faces.new(front)
            for i in range(n_):
                j = (i + 1) % n_
                bm.faces.new((back[i], back[j], front[j], front[i]))
            bmesh.ops.bevel(bm, geom=bm.edges[:], offset=0.006, segments=1, affect="EDGES")
            self.reg(new_object(self.name("Sole" + sd), bm, M["creme"]), "dist")

    def jacket_radius(self, z, band=0.012):
        xs = [abs(v.co.x) for v in self.jacket.data.vertices if abs(v.co.z - z) < band and abs(v.co.x) < self.v["belly"] * 1.12]
        ys = [abs(v.co.y) for v in self.jacket.data.vertices if abs(v.co.z - z) < band and abs(v.co.x) < 0.03]
        rx = max(xs) if xs else self.v["belly"]
        ry = max(ys) if ys else self.v["belly"] * 0.86
        return max(rx, 0.06), max(ry, 0.05)

    def uniform_details(self):
        """Gola creme, ziper, barra, punhos, cinto com fivela-bussola e EMBLEMA em relevo no peito esquerdo."""
        F, v, M, k = self.F, self.v, self.M, self.F.k
        hz, nz = F.hz, F.nz
        jk = self.jacket
        bm = bmesh.new()
        # gola: anel grosso inclinado + duas abas
        tb = bmesh.new()
        cl.torus_z(tb, 0.058, 0.020, 0.0, sy=0.92, major=22, minor=6)
        cl.transform_bm(tb, Matrix.Translation((0, 0.004, nz - 0.010)) @ cl.Matrix.Rotation(math.radians(10), 4, "X"))
        join_bm(bm, tb)
        for sx in (1, -1):
            x = sx * 0.040
            z = nz - 0.045
            y = (cl.snap_y(jk, x, z) or 0.09) + 0.004
            tb = bmesh.new()
            prism(tb, [(0, 0.022), (sx * 0.045, 0.004), (sx * 0.028, -0.030), (0, -0.012)], 0.006, (x - sx * 0.028, y - 0.003, z))
            join_bm(bm, tb)
        # barra da jaqueta
        hem = hz - (0.105 if v["layers"] else 0.080)
        rx, ry = self.jacket_radius(hem + 0.004)
        tb = bmesh.new()
        cl.torus_z(tb, rx, 0.012, hem + 0.006, sy=ry / rx, major=28, minor=5)
        join_bm(bm, tb)
        # ziper central
        pts = []
        for i in range(7):
            z = nz - 0.05 - (nz - 0.05 - hem - 0.01) * i / 6
            pts.append((0.0, (cl.snap_y(jk, 0.0, z) or 0.1) + 0.003, z))
        tb = bmesh.new()
        cl.tube(tb, pts, 0.0065, 6, True)
        join_bm(bm, tb)
        self.reg(new_object(self.name("Collar"), bm, M["creme"]), "torso")
        # punhos creme
        for sx, sd in ((1, "R"), (-1, "L")):
            el = V(sx * F.elbow.x, F.elbow.y, F.elbow.z)
            W = V(sx * F.wrist.x, F.wrist.y, F.wrist.z)
            c = W.lerp(el, 0.12)
            bm = bmesh.new()
            cl.torus_z(bm, v["limb"] * 0.98, 0.012, 0.0, major=20, minor=6)
            q = (W - el).normalized().to_track_quat("Z", "Y").to_matrix().to_4x4()
            cl.transform_bm(bm, Matrix.Translation(c) @ q)
            self.reg(new_object(self.name("Cuff" + sd), bm, M["creme"]), "single", "forearm." + sd)
        # cinto com fivela-bussola
        bz = hz - 0.012
        rx, ry = self.jacket_radius(bz)
        bm = bmesh.new()
        cl.torus_z(bm, rx + 0.002, 0.017, bz, sy=(ry + 0.002) / (rx + 0.002), major=28, minor=5)
        self.reg(new_object(self.name("Belt"), bm, M["couro"]), "torso")
        by = (cl.snap_y(jk, 0.0, bz + 0.004) or 0.11) + 0.012
        bm = bmesh.new()
        cl.lathe(bm, [(0.0, 0.010), (0.024, 0.010), (0.028, 0.005), (0.028, 0.0), (0.0, 0.0)], 24)
        cl.transform_bm(bm, Matrix.Translation((0, by - 0.006, bz)) @ cl.Matrix.Rotation(math.radians(-90), 4, "X"))
        prism(bm, star4(0.018, 0.006), 0.004, (0, by + 0.003, bz))
        self.reg(new_object(self.name("Buckle"), bm, M["ouro"]), "single", "hips")
        # emblema: escudo-gota azul-marinho + rosa dos ventos amarela + faixa curva branca (peito ESQUERDO = -X)
        ex, ez = -0.060, nz - 0.100
        ey = (cl.snap_y(jk, ex, ez) or 0.1) + (0.040 if "lifevest" in self.cfg["gear"] else 0.0)
        nrm_t = V(-0.35, 1.0, 0.1).normalized()
        q = nrm_t.to_track_quat("Y", "Z").to_matrix().to_4x4()
        T = Matrix.Translation((ex, ey - 0.002, ez)) @ q
        w, h = 0.080, 0.090
        bm = bmesh.new()
        prism(bm, emblem_outline(w, h), 0.006, (0, 0, 0))
        bmesh.ops.bevel(bm, geom=[e for e in bm.edges if len(e.link_faces) == 2 and e.calc_face_angle(0) > 0.6], offset=0.0018, segments=2, affect="EDGES")
        cl.transform_bm(bm, T)
        self.reg(new_object(self.name("Emblem"), bm, M["emblema"]), "torso")
        bm = bmesh.new()
        prism(bm, star4(0.027, 0.009), 0.004, (0, 0.006, 0.008))
        cl.transform_bm(bm, T)
        self.reg(new_object(self.name("EmblemStar"), bm, M["ouro"]), "torso")
        bm = bmesh.new()
        band = []
        for i in range(9):
            t = (i / 8) * 2 - 1
            band.append((t * w * 0.36, -0.024 + 0.008 * t * t))
        for i in range(8, -1, -1):
            t = (i / 8) * 2 - 1
            band.append((t * w * 0.36, -0.031 + 0.008 * t * t))
        prism(bm, band, 0.003, (0, 0.006, 0))
        cl.transform_bm(bm, T)
        self.reg(new_object(self.name("EmblemBand"), bm, M["creme"]), "torso")

    def gear(self):
        F, v, M = self.F, self.v, self.M
        hz, nz, jk = F.hz, F.nz, self.jacket
        g = self.cfg["gear"]
        b = v["belly"]
        if "bag" in g:
            # bolsa-carteira no quadril direito (+X) com alca a tiracolo (ombro esquerdo -> quadril direito)
            bx = b * 0.98 + 0.020
            bm = bmesh.new()
            cl.rounded_box(bm, (bx, 0.020, hz - 0.035), (0.050, 0.120, 0.105), 0.018)
            cl.rounded_box(bm, (bx + 0.003, 0.020, hz + 0.000), (0.054, 0.126, 0.050), 0.014)
            self.reg(new_object(self.name("Bag"), bm, M["couro"]), "single", "hips")
            bm = bmesh.new()
            cl.ellipsoid(bm, (bx + 0.030, 0.020, hz - 0.015), (0.006, 0.012, 0.012), 8, 5)
            self.reg(new_object(self.name("BagClasp"), bm, M["ouro"]), "single", "hips")
            if "notebook" in g:
                bm = bmesh.new()
                cl.rounded_box(bm, (bx - 0.004, -0.010, hz + 0.040), (0.026, 0.080, 0.100), 0.006, rot=cl.rot_y(-8))
                self.reg(new_object(self.name("Notebook"), bm, M["uniforme"]), "single", "hips")
                bm = bmesh.new()
                cl.rounded_box(bm, (bx - 0.004, -0.010, hz + 0.044), (0.020, 0.072, 0.098), 0.003, rot=cl.rot_y(-8))
                self.reg(new_object(self.name("NotebookPages"), bm, M["creme"]), "single", "hips")
            pts = []
            for i in range(11):
                u = i / 10
                x = -0.075 * (1 - u) + (bx - 0.02) * u
                z = (nz - 0.015) * (1 - u) + (hz + 0.015) * u
                yy = cl.snap_y(jk, x, z)
                pts.append((x, (yy if yy is not None else 0.09) + 0.007, z))
            back = []
            for i in range(7):
                u = i / 6
                x = -0.075 * (1 - u) + (bx - 0.02) * u
                z = (nz - 0.015) * (1 - u) + (hz + 0.015) * u
                hit = None
                from mathutils.bvhtree import BVHTree
                bvh = BVHTree.FromObject(jk, bpy.context.evaluated_depsgraph_get())
                hit = bvh.ray_cast(V(x, -1.0, z), V(0, 1, 0))[0]
                back.append((x, (hit.y if hit else -0.09) - 0.007, z))
            bm = bmesh.new()
            cl.tube(bm, pts, 0.008, 6, True)
            cl.tube(bm, back, 0.008, 6, True)
            cl.tube(bm, [(-0.075, pts[0][1], pts[0][2]), (-0.085, 0.0, nz + 0.005), (-0.075, back[0][1], back[0][2])], 0.008, 6, True)
            self.reg(new_object(self.name("Strap"), bm, M["couro"]), "torso")
        if "lupa" in g:
            # lupa pendurada no cinto, quadril esquerdo
            lx = -(b * 0.93 + 0.004)
            bm = bmesh.new()
            cl.torus_z(bm, 0.030, 0.0065, 0.0, major=24, minor=6)
            cl.transform_bm(bm, Matrix.Translation((lx - 0.006, 0.040, hz - 0.095)) @ cl.rot_y(90))
            cl.tube(bm, [(lx - 0.006, 0.040, hz - 0.064), (lx - 0.006, 0.040, hz - 0.020)], 0.0075, 8, True)
            self.reg(new_object(self.name("Lupa"), bm, M["ouro"]), "single", "hips")
            bm = bmesh.new()
            cl.ellipsoid(bm, (lx - 0.006, 0.040, hz - 0.095), (0.004, 0.027, 0.027), 12, 6)
            self.reg(new_object(self.name("LupaGlass"), bm, M["vidro"]), "single", "hips")
        if "rope" in g:
            bm = bmesh.new()
            # rolo de corda a tiracolo: tres voltas grossas em torno do tronco (ombro direito -> quadril esquerdo)
            axis = V(0.55, 0.0, 1.0).normalized()
            q = axis.to_track_quat("Z", "Y").to_matrix().to_4x4()
            for i in range(3):
                tb = bmesh.new()
                cl.torus_z(tb, b * 1.30 + 0.010 * i, 0.016, 0.0, sy=0.80, major=36, minor=8)
                cl.transform_bm(tb, Matrix.Translation((0.0, -0.005, (hz + nz) * 0.5 + 0.02 - 0.012 * i)) @ q)
                join_bm(bm, tb)
            self.reg(new_object(self.name("RopeCoil"), bm, M["corda"]), "torso")
        if "carabiners" in g:
            bm = bmesh.new()
            for x in (b * 0.78, -b * 0.78):
                y = (cl.snap_y(jk, x, hz - 0.04) or 0.1) + 0.012
                tb = bmesh.new()
                cl.torus_z(tb, 0.030, 0.0085, 0.0, sy=0.62, major=20, minor=6)
                cl.transform_bm(tb, Matrix.Translation((x, y, hz - 0.075)) @ cl.Matrix.Rotation(math.radians(90), 4, "X") @ cl.Matrix.Rotation(math.radians(90), 4, "Z"))
                join_bm(bm, tb)
            self.reg(new_object(self.name("Carabiners"), bm, M["metal"]), "single", "hips")
        if v["layers"] and "lifevest" not in g:
            # variacao B: colete utilitario creme por cima da jaqueta (mais camadas)
            bmv = bmesh.new()
            bmv.from_mesh(jk.data)
            kill = [f for f in bmv.faces if f.calc_center_median().z < hz - 0.06 or f.calc_center_median().z > nz - 0.035
                    or abs(f.calc_center_median().x) > b * 0.95 or (abs(f.calc_center_median().x) < 0.03 and f.calc_center_median().y > 0)]
            bmesh.ops.delete(bmv, geom=kill, context="FACES")
            bmv.normal_update()
            for vtx in bmv.verts:
                vtx.co += vtx.normal * 0.010
            vest = new_object(self.name("Vest"), bmv, M["creme"], recalc=False)
            s_ = vest.modifiers.new("sol", "SOLIDIFY")
            s_.thickness = 0.008
            s_.offset = -1
            bake(vest)
            self.reg(vest, "torso")
        if "lifevest" in g:
            # colete salva-vidas: casca da jaqueta (cortes retos por planos) deslocada, grossa e com faixas refletivas
            bmv = bmesh.new()
            bmv.from_mesh(jk.data)
            cx = b * 0.97
            for co, no, keep in (((0, 0, hz - 0.04), (0, 0, 1), True), ((0, 0, nz - 0.035), (0, 0, 1), False),
                                 ((cx, 0, 0), (1, 0, 0), False), ((-cx, 0, 0), (1, 0, 0), True)):
                bisect_keep(bmv, co, no, keep_above=keep)
            bmv.normal_update()
            # descarta a casca interna do solidify (normais para dentro)
            kill = [f for f in bmv.faces if f.normal.dot(Vector((f.calc_center_median().x, f.calc_center_median().y, 0.0))) < 0]
            bmesh.ops.delete(bmv, geom=kill, context="FACES")
            for vtx in bmv.verts:
                vtx.co += vtx.normal * 0.022
            vest = new_object(self.name("LifeVest"), bmv, M["colete"], recalc=False)
            s_ = vest.modifiers.new("sol", "SOLIDIFY")
            s_.thickness = 0.018
            s_.offset = -1
            bake(vest)
            self.reg(vest, "torso")
            bm = bmesh.new()
            for z in (hz + 0.04, hz + 0.11):
                rx, ry = self.jacket_radius(z)
                tb = bmesh.new()
                cl.torus_z(tb, rx + 0.031, 0.010, z, sy=(ry + 0.031) / (rx + 0.031), major=36, minor=6)
                join_bm(bm, tb)
            self.reg(new_object(self.name("Reflective"), bm, M["refletivo"]), "torso")
        if "compass" in g:
            el = V(-F.elbow.x, F.elbow.y, F.elbow.z)
            W = V(-F.wrist.x, F.wrist.y, F.wrist.z)
            c = W.lerp(el, 0.30)
            q = (W - el).normalized().to_track_quat("Z", "Y").to_matrix().to_4x4()
            bm = bmesh.new()
            cl.torus_z(bm, v["limb"] * 1.02, 0.008, 0.0, major=20, minor=6)
            cl.transform_bm(bm, Matrix.Translation(c) @ q)
            self.reg(new_object(self.name("CompassStrap"), bm, M["couro"]), "single", "forearm.L")
            bm = bmesh.new()
            cl.lathe(bm, [(0.0, 0.012), (0.022, 0.012), (0.026, 0.006), (0.026, 0.0), (0.0, 0.0)], 24)
            out = V(-0.9, 0.3, 0.0).normalized()
            cl.transform_bm(bm, Matrix.Translation(c + out * v["limb"] * 0.9) @ out.to_track_quat("Z", "Y").to_matrix().to_4x4())
            self.reg(new_object(self.name("Compass"), bm, M["ouro"]), "single", "forearm.L")

    def face(self, rig):
        F, M = self.F, self.M
        mats = dict(eye=M["olhos"], iris=M["iris"], dark=M["escuro"], skin=M["pele"], mouth=M["boca"])
        ob, info = hero_face.build_face(rig, self.name("Face"), mats, self.head_ob, F.hc, k=F.k, eye_size=self.v["eye"])
        self.face_ob = ob
        self.eye_info = info
        return ob

    # ---- montagem
    def build(self, with_rig=True):
        K = self.cfg["K"]
        self.head()
        self.hair()
        self.hat()
        self.body()
        self.uniform_details()
        self.gear()
        for ob, _, _ in self.parts:
            if ob.modifiers:
                bake(ob)
        rig = make_rig(self.S, self.F, 1.0) if with_rig else None
        self.face(rig if False else None)
        byname = {}
        for ob, mode, bone in self.parts:
            byname[ob.name[len(self.S) + 1:]] = ob
        if rig is not None:
            for ob, mode, bone in self.parts:
                if mode == "single":
                    cl.bind_to_rig(ob, rig, single_bone=bone)
                elif mode == "dist":
                    geom_weights(ob, rig, self.F)
                    cl.smooth_weights(ob, 2, 0.5)
            for ob, mode, bone in self.parts:
                if mode == "torso":
                    geom_weights(ob, rig, self.F, only=("hips", "spine", "chest", "neck"))
                    cl.smooth_weights(ob, 1, 0.5)
            for ob, mode, bone in self.parts:
                if mode.startswith("xfer:"):
                    cl.transfer_weights(byname[mode[5:]], ob, rig)
            cl.bind_to_rig(self.face_ob, rig, single_bone="head")
        objs = [o for o, _, _ in self.parts] + [self.face_ob]
        if K != 1.0:
            for o in objs:
                o.data.transform(Matrix.Scale(K, 4), shape_keys=(o == self.face_ob))
            if rig is not None:
                rig.data.transform(Matrix.Scale(K, 4)) if hasattr(rig.data, "transform") else None
        self.rig = rig
        self.objs = objs
        return rig, objs


def build_hero(cid, variant="C", with_rig=True):
    b = Builder(cid, variant)
    b.build(with_rig)
    return b

















