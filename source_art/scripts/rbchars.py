"""Elenco de Rota Brava (PROVISORIO): construtor procedural de personagens estilizados.

Cabeca grande (~1:3,4), origem nos pes, frente em +Y (Blender) = -Z na Godot.
Cada integrante tem 3 candidatas (A/B/C) com silhuetas distintas. Geometria 100% propria.
"""
import math

import bmesh
import bpy
from mathutils import Matrix, Vector

from rbart import (box, cyl, mat, new_object, rot_x, rot_y, rot_z, sph, torus, empty)

MEMBERS = {"tracker": "Rastro", "climber": "Pico", "pilot": "Leme"}
JACKET = {"tracker": "#F28C28", "climber": "#5AA469", "pilot": "#3F7FD0"}
SKIN = {"tracker": "#C98E64", "climber": "#EAC39A", "pilot": "#8E5B3C"}

HEAD_C = Vector((0.0, 0.01, 0.98))
HEAD_R = (0.21, 0.19, 0.19)
HIP = Vector((0.0, 0.0, 0.40))

# parametros por candidata. arms: (ombro_dx, cotovelo, mao) no referencial do tronco (antes da inclinacao)
VARIANTS = {
    ("tracker", "A"): dict(scale=1.00, lean=16, stance=0.075, hat="wide", notebook="hip",
                           arms=[((0.05, 0.0, -0.18), (0.25, 0.02, 0.46)), ((0.08, 0.04, -0.14), (0.30, 0.05, 0.52))]),
    ("tracker", "B"): dict(scale=0.90, lean=6, stance=0.07, hat="tufts", notebook="hand",
                           arms=[((0.05, 0.0, -0.18), (0.25, 0.02, 0.46)), ((0.08, 0.12, -0.12), (0.20, 0.34, 0.74))]),
    ("tracker", "C"): dict(scale=1.06, lean=24, stance=0.08, hat="bun", notebook="big",
                           arms=[((0.05, 0.04, -0.17), (0.28, 0.06, 0.56)), ((0.05, 0.0, -0.18), (0.25, 0.02, 0.46))]),
    ("climber", "A"): dict(scale=1.00, lean=0, stance=0.08, hat="helmet", pack="coil",
                           arms=[((0.08, 0.0, -0.17), (0.30, 0.0, 0.46)), ((0.08, 0.0, -0.17), (0.30, 0.0, 0.46))]),
    ("climber", "B"): dict(scale=1.12, lean=-4, stance=0.075, hat="beanie", pack="bandolier",
                           arms=[((0.12, 0.05, 0.12), (0.34, 0.06, 1.30)), ((0.12, 0.05, 0.12), (0.34, 0.06, 1.30))]),
    ("climber", "C"): dict(scale=0.94, lean=2, stance=0.09, hat="mane", pack="tall",
                           arms=[((0.06, 0.0, -0.18), (0.27, 0.0, 0.46)), ((0.14, 0.08, 0.14), (0.32, 0.10, 1.28))]),
    ("pilot", "A"): dict(scale=1.00, lean=0, stance=0.085, hat="cap", pack=None,
                         arms=[((0.18, 0.08, -0.02), (0.55, 0.22, 0.70)), ((0.18, 0.08, -0.02), (0.55, 0.22, 0.70))]),
    ("pilot", "B"): dict(scale=1.08, lean=-3, stance=0.075, hat="quiff", pack="pockets",
                         arms=[((0.17, -0.03, -0.10), (0.12, 0.08, 0.46)), ((0.10, 0.18, 0.02), (0.20, 0.62, 0.80))]),
    ("pilot", "C"): dict(scale=1.00, lean=-4, stance=0.14, hat="sou", pack=None,
                         arms=[((0.20, -0.03, -0.10), (0.14, 0.08, 0.46)), ((0.20, -0.03, -0.10), (0.14, 0.08, 0.46))]),
}

def _bm():
    return bmesh.new()


class Char:
    def __init__(self, member, variant, prefix, display, hat_height=1.0, root=None, scale=None):
        self.member, self.variant, self.prefix, self.display = member, variant, prefix, display
        self.p = VARIANTS[(member, variant)]
        self.hat_h = hat_height
        s = scale if scale else self.p["scale"]
        self.G = Matrix.Diagonal((s, s, s, 1.0))
        lean = self.p["lean"]
        # inclinacao para frente em torno do quadril; positivo = curvado para +Y
        self.U = Matrix.Translation(HIP) @ rot_x(-lean) @ Matrix.Translation(-HIP)
        self.root = root or empty(display, kind="PLAIN_AXES", size=0.3)
        self.objs = []
        self.mats = {}

    def m(self, role, hexcol, rough=0.85):
        name = "mat_%s_%s" % (self.display.lower() if self.prefix == self.display else self.member, role)
        if name not in self.mats:
            self.mats[name] = mat(name, hexcol, rough)
        return self.mats[name]

    def add(self, part, bm, mat_obj, upper=False, smooth=True):
        bm.transform(self.G @ (self.U if upper else Matrix.Identity(4)))
        ob = new_object("%s_%s" % (self.prefix, part), bm, mat_obj, smooth=smooth, parent=self.root)
        self.objs.append(ob)
        return ob

    def pt(self, v, upper=True):
        """Ponto no referencial do tronco -> mundo (para empties)."""
        return self.G @ ((self.U if upper else Matrix.Identity(4)) @ Vector(v))

    # ------------------------------------------------------------ corpo
    def body(self):
        mem, p = self.member, self.p
        jacket = self.m("jacket", JACKET[mem])
        pants = self.m("pants", {"tracker": "#6B5A44", "climber": "#4A5568", "pilot": "#2F3B52"}[mem])
        boots = self.m("boots", "#5A3A22")
        skin = self.m("skin", SKIN[mem], 0.7)
        st = p["stance"]
        for side, nm in ((-1, "L"), (1, "R")):
            bm = _bm(); cyl(bm, (side * st, 0.0, 0.10), (side * st, 0.0, 0.43), 0.060, 0.066, seg=14)
            self.add("Leg" + nm, bm, pants)
            bm = _bm(); sph(bm, (side * st, 0.03, 0.056), (0.07, 0.11, 0.055), 14, 8)
            self.add("Boot" + nm, bm, boots)
        bm = _bm(); sph(bm, (0, 0, 0.44), (0.15, 0.12, 0.10), 18, 10)
        self.add("Pants", bm, pants, upper=True)
        bm = _bm(); sph(bm, (0, 0, 0.62), (0.17, 0.13, 0.24), 20, 12)
        self.add("Body", bm, jacket, upper=True)
        # cabeca, nariz
        bm = _bm(); sph(bm, HEAD_C, HEAD_R, 24, 14)
        self.add("Head", bm, skin, upper=True)
        bm = _bm(); sph(bm, (0, HEAD_C.y + HEAD_R[1] - 0.012, HEAD_C.z - 0.02), (0.03, 0.04, 0.032), 10, 6)
        self.add("Nose", bm, self.m("skin_dark", {"tracker": "#B27A52", "climber": "#D3A67C", "pilot": "#7A4A2E"}[mem], 0.7), upper=True)
        # bracos: ombro -> cotovelo -> mao
        for side, nm, (elb, hand) in zip((-1, 1), ("L", "R"), p["arms"]):
            sh = Vector((side * 0.17, 0.0, 0.72))
            e = Vector((side * (0.17 + elb[0]), elb[1], sh.z + elb[2]))
            h = Vector((side * hand[0], hand[1], hand[2]))
            bm = _bm(); cyl(bm, sh, e, 0.052, 0.046, seg=12); cyl(bm, e, h, 0.046, 0.042, seg=12)
            sph(bm, e, 0.047, 10, 6)
            self.add("Arm" + nm, bm, jacket, upper=True)
            bm = _bm(); sph(bm, h, 0.056, 12, 8)
            self.add("Hand" + nm, bm, skin, upper=True)
        getattr(self, "acc_" + mem)()

    # ------------------------------------------------------------ Rastro
    def acc_tracker(self):
        v, hh = self.variant, self.hat_h
        hat = self.m("hat", "#7A5A2E")
        paper = self.m("paper", "#FFF3C4")
        cover = self.m("notebook", "#2F6F73")
        hc = HEAD_C
        if v == "A":
            tilt = Matrix.Translation(hc) @ rot_x(11) @ Matrix.Translation(-hc)   # chapeu mais alto na testa
            bm = _bm(); cyl(bm, (0, hc.y, 1.125), (0, hc.y, 1.145), 0.33, 0.31, seg=28); bm.transform(tilt)
            self.add("HatBrim", bm, hat, upper=True)
            bm = _bm(); sph(bm, (0, hc.y, 1.125), (0.205, 0.195, 0.125 * hh), 22, 10); bm.transform(tilt)
            self.add("Hat", bm, hat, upper=True)
            bm = _bm(); box(bm, (0.30, 0.03, 0.46), (0.05, 0.22, 0.30), bevel=0.012)
            self.add("Notebook", bm, cover, upper=True, smooth=False)
            bm = _bm(); box(bm, (0.272, 0.03, 0.46), (0.03, 0.20, 0.27))
            self.add("NotebookPages", bm, paper, upper=True, smooth=False)
        elif v == "B":
            bm = _bm(); sph(bm, (0, hc.y - 0.01, 1.08), (0.225, 0.21, 0.11 * hh), 20, 8)
            self.add("Hair", bm, hat, upper=True)
            for i, ang in enumerate((-50, -25, 0, 25, 50)):
                bm = _bm()
                a = math.radians(ang)
                cyl(bm, (math.sin(a) * 0.12, hc.y, 1.20), (math.sin(a) * 0.30, hc.y, 1.20 + 0.20 * math.cos(a) * hh), 0.06, 0.005, seg=8)
                self.add("HairTuft%d" % i, bm, hat, upper=True)
            bm = _bm(); box(bm, (0.20, 0.34, 0.74), (0.04, 0.22, 0.30), rot_z(-20), bevel=0.012)
            self.add("Notebook", bm, cover, upper=True, smooth=False)
            bm = _bm(); box(bm, (0.19, 0.335, 0.74), (0.025, 0.20, 0.27), rot_z(-20))
            self.add("NotebookPages", bm, paper, upper=True, smooth=False)
        else:
            bm = _bm(); sph(bm, (0, hc.y - 0.01, 1.08), (0.22, 0.20, 0.10 * hh), 20, 8)
            self.add("Hair", bm, hat, upper=True)
            bm = _bm(); sph(bm, (0, hc.y - 0.02, 1.27 + 0.0 * hh), (0.09, 0.09, 0.09 * hh), 12, 8)
            self.add("HairBun", bm, hat, upper=True)
            bm = _bm(); cyl(bm, (0, hc.y - 0.17, 1.06), (0, hc.y - 0.44, 0.74), 0.07, 0.015, seg=10)
            self.add("Ponytail", bm, hat, upper=True)
            bm = _bm(); box(bm, (-0.30, 0.06, 0.42), (0.05, 0.30, 0.40), rot_y(8), bevel=0.012)
            self.add("Notebook", bm, cover, upper=True, smooth=False)
            bm = _bm(); box(bm, (-0.272, 0.06, 0.42), (0.03, 0.27, 0.36), rot_y(8))
            self.add("NotebookPages", bm, paper, upper=True, smooth=False)

    # ------------------------------------------------------------ Pico
    def acc_climber(self):
        v = self.variant
        rope = self.m("rope", "#FFD24D")
        gear = self.m("gear", "#C9CED6", 0.4)
        hat = self.m("hat", "#E04F3A")
        pack = self.m("pack", "#7A4E2D")
        hc = HEAD_C
        def carab(c, rot):
            bm = _bm(); torus(bm, c, 0.05, 0.014, rot, 16, 6)
            self.add("Carabiner%d" % (len([o for o in self.objs if "Carabiner" in o.name]) + 1), bm, gear, upper=True)
        if v == "A":
            bm = _bm(); sph(bm, (0, hc.y, 1.08), (0.235, 0.215, 0.15), 22, 10)
            self.add("Helmet", bm, hat, upper=True)
            bm = _bm(); sph(bm, (0, hc.y, 1.23), (0.04, 0.04, 0.03), 8, 6)
            self.add("HelmetKnob", bm, gear, upper=True)
            for k, y in enumerate((-0.20, -0.27)):
                bm = _bm(); torus(bm, (0, y, 0.66), 0.25, 0.055, rot_x(90), 24, 8)
                self.add("RopeCoil%d" % k, bm, rope, upper=True)
            carab((-0.19, 0.0, 0.46), rot_y(90)); carab((0.19, 0.0, 0.46), rot_y(90))
        elif v == "B":
            bm = _bm(); sph(bm, (0, hc.y - 0.005, 1.08), (0.225, 0.205, 0.13), 22, 10)
            self.add("Beanie", bm, hat, upper=True)
            bm = _bm(); sph(bm, (0, hc.y, 1.28), 0.075, 12, 8)
            self.add("Pompom", bm, rope, upper=True)
            bm = _bm(); torus(bm, (0, 0.0, 0.62), 0.25, 0.045, rot_y(38) @ rot_x(80), 28, 8)
            self.add("RopeCoil0", bm, rope, upper=True)
            carab((0.20, 0.13, 0.42), rot_x(70)); carab((-0.12, 0.13, 0.38), rot_x(70))
        else:
            for i, (x, ln) in enumerate(((-0.14, 0.17), (-0.07, 0.27), (0.0, 0.32), (0.07, 0.27), (0.14, 0.17))):
                bm = _bm(); cyl(bm, (x * 0.7, hc.y - 0.02, 1.12), (x * 1.9, hc.y - 0.09, 1.12 + ln), 0.05, 0.004, seg=8)
                self.add("Mane%d" % i, bm, pack, upper=True)
            bm = _bm(); sph(bm, (0, hc.y, 1.10), (0.22, 0.20, 0.08), 20, 8)
            self.add("Hair", bm, pack, upper=True)
            bm = _bm(); box(bm, (0, -0.21, 0.70), (0.34, 0.18, 0.46), bevel=0.03)
            self.add("Backpack", bm, pack, upper=True, smooth=False)
            bm = _bm(); torus(bm, (0, -0.21, 0.97), 0.13, 0.045, rot_x(0), 24, 8)
            self.add("RopeCoil0", bm, rope, upper=True)
            carab((0.18, -0.05, 0.38), rot_y(90))

    # ------------------------------------------------------------ Leme
    def acc_pilot(self):
        v = self.variant
        vest = self.m("vest", "#F4F4F4")
        hat = self.m("hat", "#1F2A44")
        trim = self.m("trim", "#F5C518")
        hc = HEAD_C
        bm = _bm(); sph(bm, (0, 0.025, 0.64), (0.185, 0.14, 0.215), 20, 12)
        self.add("Vest", bm, vest, upper=True)
        bm = _bm(); box(bm, (0.0, 0.14, 0.64), (0.025, 0.02, 0.36))
        self.add("VestZip", bm, trim, upper=True, smooth=False)
        if v == "A":
            bm = _bm(); sph(bm, (0, hc.y, 1.09), (0.225, 0.205, 0.12), 22, 10)
            self.add("Cap", bm, hat, upper=True)
            bm = _bm(); box(bm, (0, hc.y + 0.22, 1.10), (0.28, 0.20, 0.025), rot_x(-8), bevel=0.01)
            self.add("CapVisor", bm, hat, upper=True, smooth=False)
        elif v == "B":
            bm = _bm(); sph(bm, (0, hc.y, 1.09), (0.225, 0.205, 0.10), 22, 8)
            self.add("Hair", bm, hat, upper=True)
            bm = _bm(); cyl(bm, (-0.05, hc.y + 0.06, 1.18), (-0.30, hc.y + 0.10, 1.30), 0.10, 0.025, seg=10)
            self.add("Quiff", bm, hat, upper=True)
            for s, nm in ((-1, "L"), (1, "R")):
                bm = _bm(); box(bm, (s * 0.12, 0.145, 0.50), (0.12, 0.03, 0.12), bevel=0.01)
                self.add("Pocket" + nm, bm, trim, upper=True, smooth=False)
        else:
            bm = _bm(); sph(bm, (0, hc.y, 1.10), (0.235, 0.215, 0.14), 22, 10)
            self.add("Souwester", bm, trim, upper=True)
            bm = _bm(); cyl(bm, (0, hc.y - 0.12, 1.10), (0, hc.y - 0.34, 0.82), 0.16, 0.28, seg=24)
            self.add("SouwesterBrim", bm, trim, upper=True)
            bm = _bm(); cyl(bm, (0, hc.y + 0.12, 1.10), (0, hc.y + 0.30, 1.07), 0.10, 0.18, seg=20)
            self.add("SouwesterFront", bm, trim, upper=True)

    def finish(self):
        for o in self.objs:
            o.select_set(False)
        return self.objs


def build(member, variant, prefix=None, display=None, hat_height=1.0, root=None, scale=None):
    display = display or MEMBERS[member]
    c = Char(member, variant, prefix or "%s_%s" % (member, variant), display, hat_height, root, scale)
    c.body()
    return c


# ---------------------------------------------------------------- rosto com shape keys
EXPRESSIONS = {
    #            olho(rx,rz) | sobrancelha(z,inclinacao,arco) | boca(w,h,curva)
    "neutra":   dict(eye=(0.022, 0.030), brow=(0.080, 0.000, 0.004), mouth=(0.032, 0.007, 0.010)),
    "atenta":   dict(eye=(0.026, 0.034), brow=(0.088, 0.016, 0.000), mouth=(0.022, 0.006, 0.000)),
    "surpresa": dict(eye=(0.034, 0.046), brow=(0.100, -0.004, 0.012), mouth=(0.021, 0.031, 0.000)),
}


def _surf_y(x, z):
    cx, cy, cz = HEAD_C
    rx, ry, rz = HEAD_R
    t = 1.0 - (x / rx) ** 2 - ((z - cz) / rz) ** 2
    return cy + ry * math.sqrt(max(t, 0.0)) + 0.004


def face_geometry(expr, nose_z_off=0.0):
    """Mesma topologia para todas as expressoes. Retorna (verts, faces)."""
    e = EXPRESSIONS[expr]
    cz = HEAD_C.z
    verts, faces = [], []

    def vtx(x, z, dy=0.0):
        verts.append((x, _surf_y(x, z) + dy, z))
        return len(verts) - 1

    # olhos: leque de 12
    for sx in (-1, 1):
        ex, ez = sx * 0.078, cz + 0.02
        c = vtx(ex, ez, 0.002)
        ring = [vtx(ex + math.cos(2 * math.pi * i / 12) * e["eye"][0], ez + math.sin(2 * math.pi * i / 12) * e["eye"][1], 0.002) for i in range(12)]
        for i in range(12):
            faces.append((c, ring[i], ring[(i + 1) % 12]))
    # sobrancelhas: faixa de 5 pontos
    bz, tilt, arch = e["brow"]
    for sx in (-1, 1):
        top, bot = [], []
        for i in range(5):
            t = i / 4.0 - 0.5            # -0.5 (interno) .. 0.5 (externo)
            x = sx * (0.045 + 0.075 * (t + 0.5))
            z = cz + bz + arch * (1 - (2 * t) ** 2) - tilt * (0.5 - t)
            top.append(vtx(x, z + 0.009, 0.003)); bot.append(vtx(x, z - 0.009, 0.003))
        for i in range(4):
            faces.append((top[i], top[i + 1], bot[i + 1], bot[i]))
    # boca: leque de 14
    w, h, curve = e["mouth"]
    mz = cz - 0.085
    c = vtx(0.0, mz, 0.002)
    ring = []
    for i in range(14):
        a = 2 * math.pi * i / 14
        x = math.cos(a) * w
        ring.append(vtx(x, mz + math.sin(a) * h + curve * (x / 0.032) ** 2 * 1.0 - curve * 0.5, 0.002))
    for i in range(14):
        faces.append((c, ring[i], ring[(i + 1) % 14]))
    return verts, faces


def add_face(ch, name="Face"):
    """Cria o objeto de rosto (olhos+sobrancelhas+boca) com shape keys neutra/atenta/surpresa."""
    dark = ch.m("face", "#2B1D16", 0.9)
    xf = ch.G @ ch.U
    base_v, faces = face_geometry("neutra")
    me = bpy.data.meshes.new("%s_%s" % (ch.prefix, name))
    me.from_pydata([xf @ Vector(v) for v in base_v], [], faces)
    # normais para fora (+Y local do rosto)
    for p in me.polygons:
        p.use_smooth = False
    me.update()
    me.uv_layers.new(name="UVMap")
    me.materials.append(dark)
    ob = bpy.data.objects.new("%s_%s" % (ch.prefix, name), me)
    bpy.context.scene.collection.objects.link(ob)
    ob.parent = ch.root
    # garante normais voltadas para o lado da frente do personagem
    fwd = (ch.G @ ch.U).to_3x3() @ Vector((0, 1, 0))
    bm = bmesh.new(); bm.from_mesh(me); bm.normal_update()
    for f in bm.faces:
        if f.normal.dot(fwd) < 0:
            f.normal_flip()
    bm.to_mesh(me); bm.free()
    ob.shape_key_add(name="neutra", from_mix=False)
    for ex in ("atenta", "surpresa"):
        k = ob.shape_key_add(name=ex, from_mix=False)
        vs, _ = face_geometry(ex)
        for i, v in enumerate(vs):
            k.data[i].co = xf @ Vector(v)
    ch.objs.append(ob)
    return ob







