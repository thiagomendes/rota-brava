"""Leme v2 (RB-R1 D11/D13): geometria da heroina piloto. PROPOSTA PROVISORIA, lado a lado com a Leme do jogo.

Traje proprio (D13: nao e o macacao do Rastro recolorido): camisa de capitania branca de manga curta, colete salva-vidas azul
de placas de espuma (abertura na frente, laterais com tiras, gola-travesseiro em ferradura atras do pescoco, faixas refletivas),
bermuda azul, meias de meio cano listradas, botinas nauticas com sola branca e cadarco, bone nautico de capitania, cabelo
cacheado com volume (cachos nas laterais e um puff grande atras), bussola de pulso e pulseira de corda, apito no cordao.

Toda geometria e gerada aqui do zero: grafo de pele (modificador SKIN) + SUBSURF para o corpo inteirico (tronco, bracos e
pernas numa malha so, cortada depois em camisa, bermuda, pele e meia), superficie parametrica sobre o corpo (raycast em BVH)
para o colete, metaballs para o cabelo, torno (lathe), toros, tubos e bmesh para o resto. Cabeca, rosto (expressoes, visemas,
olhar) e esqueleto de 28 ossos vem da biblioteca dos herois (source_art/scripts/hero_lib.py, hero_face.py). Nada baixado.

Convencao: Blender Z-up, frente = +Y (vira -Z na Godot), direita da personagem (.R) = +X. Origem nos pes. Metros.
Pernas em leve "A": quadril em +-hip_x, tornozelos em +-foot_x (mais largos) para as botas nunca se tocarem.
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPTS = os.path.abspath(os.path.join(HERE, "..", "..", "scripts"))
for p in (HERE, SCRIPTS):
    if p not in sys.path:
        sys.path.insert(0, p)

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

import char_lib as cl
import hero_lib
from rbart import new_object

# ------------------------------------------------------------------ proporcao (mesma familia do Rastro v2; Leme e a mais velha)
LV2 = dict(head=0.390, leg=0.392, torso=0.272, belly=0.130, sh_x=0.128, limb=0.040, hand=1.22, boot=1.06, eye=1.08, layers=False,
           label="v2 heroina piloto")
hero_lib.VARIANTS["LV2"] = LV2
PAL = dict(pele="#8C5634", cabelo="#1E1410", iris="#5A3418", uniforme="#2F8CFF", creme="#F7FBFF", calca="#1F5FBF",
           botas="#1F3A5F", chapeu="#F7FBFF", couro="#1F3A5F", emblema="#123A5E", ouro="#FFC83D", olhos="#FFFFFF",
           escuro="#140C09", boca="#7A2E36", rubor="#B8624F", vidro="#DFF4FF")
hero_lib.CAST["leme_v2"] = dict(display="Leme", K=1.04, head_k=0.965, hat="cap", hair="curls", gear=(), gloves=False, pal=PAL)

DECIMATE = {"body": 0.27, "hand": 0.31, "boot": 0.36, "hair": 0.18, "sole": 0.8, "belt": 0.35, "collar_pillow": 0.30,
            "cap_crown": 0.62, "cap_band": 0.6, "shirt_collar": 0.6}

GROUP_OF_PART = {}


def V(*a):
    return Vector(a)


def smooth(t, a, b):
    u = np.clip((t - a) / (b - a), 0.0, 1.0)
    return u * u * (3 - 2 * u)


def sm1(t, a, b):
    u = min(max((t - a) / (b - a), 0.0), 1.0)
    return u * u * (3 - 2 * u)


def bump(u, c, w):
    return np.exp(-((u - c) / w) ** 2)


def verts_np(ob):
    a = np.empty(len(ob.data.vertices) * 3)
    ob.data.vertices.foreach_get("co", a)
    return a.reshape(-1, 3)


def set_verts(ob, P):
    ob.data.vertices.foreach_set("co", P.astype(np.float64).ravel())
    ob.data.update()


def decimate(ob, ratio):
    m = ob.modifiers.new("dec", "DECIMATE")
    m.decimate_type = "COLLAPSE"
    m.ratio = ratio
    m.use_collapse_triangulate = False
    hero_lib.bake(ob)


def tag(ob, part, group):
    GROUP_OF_PART[part] = group
    ob["rbpart"] = part
    ob["rbgroup"] = group
    return ob


def seg_frame(P, a, b):
    a, b = np.asarray(a, float), np.asarray(b, float)
    d = b - a
    L = np.linalg.norm(d)
    dn = d / L
    u = (P - a) @ dn / L
    proj = a + np.outer(np.clip(u, 0, 1), d)
    rv = P - proj
    r = np.linalg.norm(rv, axis=1)
    rn = rv / np.maximum(r[:, None], 1e-9)
    return u, r, rn, dn, L


def ref_dirs(dn, sx):
    fr = np.array([0.0, 1.0, 0.0]) - dn * dn[1]
    fr /= np.linalg.norm(fr)
    out = np.array([sx, 0.0, 0.0]) - dn * dn[0] * sx
    out = out - fr * (out @ fr)
    out /= max(np.linalg.norm(out), 1e-9)
    return fr, out


def bone_table_lv2(F):
    """Os mesmos 28 ossos do hero_lib.bone_table, com as pernas em leve A (tornozelo mais aberto que o quadril)."""
    B = hero_lib._orig_bone_table(F)
    out = []
    fx = F.foot_x
    for (n, h, t, p, d) in B:
        side = n.split(".")[-1] if "." in n else None
        sx = 1 if side == "R" else -1
        base = n.split(".")[0]
        if base == "thigh":
            h, t = (sx * F.hip_x, 0, F.hz - 0.02), (sx * F.knee_x, 0.006, F.knee_z)
        elif base == "shin":
            h, t = (sx * F.knee_x, 0.006, F.knee_z), (sx * fx, 0, F.ankle_z)
        elif base == "foot":
            h, t = (sx * fx, 0, F.ankle_z), (sx * fx, F.ball_y, 0.0)
        elif base == "toe":
            h, t = (sx * fx, F.ball_y, 0.0), (sx * fx, F.toe_y, 0.0)
        elif base == "toe_tip":
            h, t = (sx * fx, F.toe_y, 0.0), (sx * fx, F.toe_y + 0.02, 0.0)
        elif base == "heel":
            h, t = (sx * fx, F.heel_y, 0.0), (sx * fx, F.heel_y, 0.03)
        out.append((n, h, t, p, d))
    return out


if not hasattr(hero_lib, "_orig_bone_table"):
    hero_lib._orig_bone_table = hero_lib.bone_table


class LV2B(hero_lib.Builder):
    """Construtor da Leme v2. Reusa cabeca, rosto e rig do Builder dos herois; traje, cabelo e equipamento novos."""

    def __init__(self):
        super().__init__("leme_v2", "LV2")
        self.S = "Leme"
        GROUP_OF_PART.clear()
        F = self.F
        k = self.cfg["K"]
        # pernas em A: quadril um pouco mais aberto que o do Rastro, tornozelo bem mais aberto (vao entre as botas)
        F.hip_x = 0.070 * k
        F.foot_x = 0.088 * k
        F.knee_x = F.hip_x + (F.foot_x - F.hip_x) * (F.hz - F.knee_z) / (F.hz - F.ankle_z)

    # ------------------------------------------------------------ cabeca
    def head_parts(self):
        self.head()
        keep = []
        for ob, mode, bone in self.parts:
            n = ob.name
            if n.endswith("_Blush"):
                bpy.data.objects.remove(ob)        # rubor pintado na textura da pele
                continue
            tag(ob, "skin_head", "skin")
            keep.append((ob, mode, bone))
        self.parts = keep
        self.hair_lv2()
        self.cap()

    def hair_lv2(self):
        """Cachos com volume: calota sob o bone, cachos em anel na linha do cabelo (laterais ate a mandibula), puff grande
        atras (rabo de cavalo cacheado saindo da abertura do bone) e cachinhos de franja sob a pala."""
        F, k = self.F, self.F.k
        hc, hr = F.hc, F.hr
        E = [("ELLIPSOID", (hc.x, hc.y - 0.014 * k, hc.z + 0.022 * k), 1.0, (hr[0] * 1.03, hr[1] * 1.02, hr[2] * 0.98), False)]
        rng = np.random.RandomState(7)
        curls = []

        def curl(p, r):
            E.append(("BALL", tuple(p), r, None, False))
            curls.append((Vector(p), r))
        # anel alto (logo abaixo da faixa do bone) e anel baixo (laterais e nuca), deixando a frente livre para o rosto
        for ring, (zc, rad_k, a_lim, rr) in enumerate(((0.020, 1.00, 66, 0.040), (-0.045, 1.02, 74, 0.044), (-0.110, 0.92, 84, 0.040))):
            n = 13 if ring < 2 else 11
            for i in range(n):
                a = math.radians(a_lim + (360 - 2 * a_lim) * (i + 0.5 * (ring % 2)) / n)
                jit = rng.uniform(-0.010, 0.010, 3) * k
                z = hc.z + zc * k
                if ring == 2:
                    z += 0.020 * k * math.cos(a)          # mais curto na nuca, desce nas laterais ate a mandibula
                p = V(math.sin(a) * hr[0] * rad_k, hc.y - 0.010 * k + math.cos(a) * hr[1] * rad_k * 0.98, z) + V(*jit)
                curl(p, rr * k * rng.uniform(0.85, 1.12))
        # puff grande atras, um pouco acima do meio da cabeca, com cachos na superficie (silhueta irregular)
        pc = V(0.0, hc.y - hr[1] * 1.10, hc.z + 0.010 * k)
        self.puff = (pc, 0.090 * k)
        E.append(("BALL", tuple(pc), 0.086 * k, None, False))
        for i in range(16):
            u = (i + 0.5) / 16
            th = math.acos(1 - 2 * u)
            ph = i * 2.399963
            d = V(math.sin(th) * math.cos(ph), math.sin(th) * math.sin(ph), math.cos(th))
            if d.y > 0.55:            # nao entra na cabeca
                continue
            curl(pc + d * 0.078 * k, 0.036 * k * rng.uniform(0.85, 1.15))
        # cachinhos de franja logo abaixo da pala (acima das sobrancelhas)
        for sxx in (-1, 1):           # cachinho na tempora (moldura do rosto, abaixo da faixa do bone)
            curl(V(sxx * hr[0] * 0.86, hc.y + hr[1] * 0.42, hc.z + 0.030 * k), 0.030 * k)
        # janela do rosto (elipsoide negativo): recorta lisa a linha do cabelo
        E.append(("ELLIPSOID", (0, hc.y + hr[1] * 0.80, hc.z - 0.060 * k), 1.0, (hr[0] * 0.78, hr[1] * 0.55, 0.125 * k), True))
        E.append(("ELLIPSOID", (hc.x, hc.y + hr[1] * 0.25, hc.z - 0.215 * k), 1.0, (hr[0] * 1.3, hr[1] * 0.75, 0.10 * k), True))
        ob = hero_lib.metaball_obj(self.name("Hair"), E, self.M["cabelo"], res=0.0125 * k, thresh=0.6)
        bm = bmesh.new()
        bm.from_mesh(ob.data)
        for _ in range(2):
            bmesh.ops.smooth_vert(bm, verts=bm.verts[:], factor=0.5, use_axis_x=True, use_axis_y=True, use_axis_z=True)
        bm.to_mesh(ob.data)
        bm.free()
        self.curls = curls
        self.hair_ob = ob
        tag(ob, "hair", "hair")
        self._hair_E = E
        self.reg(ob, "single", "head")
        # elastico do puff (azul) na base do rabo
        bm = bmesh.new()
        cl.torus_z(bm, 0.040 * k, 0.010 * k, 0.0, major=20, minor=6)
        d = (pc - V(hc.x, hc.y, hc.z + 0.01 * k)).normalized()
        q = d.to_track_quat("Z", "Y").to_matrix().to_4x4()
        cl.transform_bm(bm, Matrix.Translation(V(hc.x, hc.y, hc.z + 0.01 * k) + d * hr[1] * 0.98) @ q)
        tie = new_object(self.name("HairTie"), bm, self.M["uniforme"])
        tag(tie, "hair_tie", "gear")
        self.reg(tie, "single", "head")

    def cap(self):
        """Bone nautico de capitania: copa branca alta e mais larga em cima (silhueta), faixa azul-marinho, pala curva
        envernizada, cordao dourado com botoes e o emblema da equipe na frente. Inclinado para tras (rosto livre)."""
        F, k = self.F, self.F.k
        hc, hr = F.hc, F.hr
        R = hr[0] * 0.95
        tilt = math.radians(9)             # frente sobe (rotacao +X leva +Y para +Z)
        roll = math.radians(-4)
        pos = V(0.0, hc.y - 0.004 * k, hc.z + 0.080 * k)
        m = Matrix.Translation(pos) @ Matrix.Rotation(tilt, 4, "X") @ Matrix.Rotation(roll, 4, "Y") @ Matrix.Diagonal((1.0, 0.97, 1.0, 1.0))
        self.cap_m = m
        self.cap_R = R
        # ponto da pala do lado direito (alvo da continencia e do toque na pala), referencial de repouso
        a = math.radians(50)
        rr = R * 0.99 + 0.62 * 0.068 * k * (0.35 + 0.65 * math.cos(a * 0.72))
        F.brim_r = m @ V(math.sin(a) * rr, math.cos(a) * rr, 0.004 * k - 0.012 * k)
        # copa (tecido branco): faixa reta ate 0,036, abre para 1,16 R no alto, topo levemente abaulado
        prof = [(0.0, 0.112), (0.40, 0.111), (0.75, 0.106), (1.02, 0.096), (1.15, 0.084), (1.17, 0.074), (1.12, 0.062),
                (1.03, 0.046), (1.00, 0.034), (0.985, 0.0), (0.0, 0.0)]
        bm = bmesh.new()

        def deform(r, z, a):
            # copa um pouco mais alta e mais avancada na frente (bone de capitania)
            fr = 0.5 + 0.5 * math.sin(a)
            if z > 0.05:
                z += 0.010 * fr * (z - 0.05) / 0.06
            return r, z
        cl.lathe(bm, [(r * R, z * k) for r, z in prof], 34, lambda r, z, a: deform(r, z, a))
        # remove o fundo (abre a copa: o cabelo entra)
        bot = [f for f in bm.faces if all(v.co.z < 0.001 for v in f.verts)]
        bmesh.ops.delete(bm, geom=bot, context="FACES")
        cl.transform_bm(bm, m)
        crown = new_object(self.name("CapCrown"), bm, self.M["chapeu"], recalc=False)
        sol = crown.modifiers.new("sol", "SOLIDIFY")
        sol.thickness = 0.004
        sol.offset = -1.0
        hero_lib.bake(crown)
        tag(crown, "cap_crown", "suit")
        self.reg(crown, "single", "head")
        # faixa azul-marinho (um pouco saliente) ao redor da base
        bm = bmesh.new()
        cl.torus_z(bm, R * 1.005, 0.0105 * k, 0.020 * k, sy=1.0, major=44, minor=6)
        for vv in bm.verts:                      # achata o toro em faixa (altura maior que espessura)
            dz = vv.co.z - 0.020 * k
            vv.co.z = 0.020 * k + dz * 1.45
            rr = math.hypot(vv.co.x, vv.co.y)
            s = (R * 1.004 + (rr - R * 1.005) * 0.55) / max(rr, 1e-9)
            vv.co.x *= s
            vv.co.y *= s
        cl.transform_bm(bm, m)
        band = new_object(self.name("CapBand"), bm, self.M["couro"])
        tag(band, "cap_band", "gear")
        self.reg(band, "single", "head")
        # pala curva (secao com espessura), presa na frente da faixa, inclinada para baixo
        bm = bmesh.new()
        rows = []
        nu = 22
        for i in range(nu + 1):
            a = math.radians(-62 + 124 * i / nu)
            w = math.cos(a * 0.72)
            ring = []
            for t, dz in ((0.0, 0.0), (0.5, -0.010), (1.0, -0.024)):
                rr = R * 0.99 + t * 0.068 * k * (0.35 + 0.65 * w)
                ring.append(V(math.sin(a) * rr, math.cos(a) * rr, 0.004 * k + dz * k * (0.6 + 0.4 * w)))
            rows.append(ring)
        top_v = [[bm.verts.new(p + V(0, 0, 0.0035)) for p in r] for r in rows]
        bot_v = [[bm.verts.new(p - V(0, 0, 0.0035)) for p in r] for r in rows]
        for i in range(nu):
            for j in range(2):
                bm.faces.new((top_v[i][j], top_v[i][j + 1], top_v[i + 1][j + 1], top_v[i + 1][j]))
                bm.faces.new((bot_v[i][j], bot_v[i + 1][j], bot_v[i + 1][j + 1], bot_v[i][j + 1]))
        for i in range(nu):
            bm.faces.new((top_v[i][2], bot_v[i][2], bot_v[i + 1][2], top_v[i + 1][2]))
            bm.faces.new((top_v[i][0], top_v[i + 1][0], bot_v[i + 1][0], bot_v[i][0]))
        for end in (0, nu):
            f = [top_v[end][0], top_v[end][1], top_v[end][2], bot_v[end][2], bot_v[end][1], bot_v[end][0]]
            bm.faces.new(f if end == nu else list(reversed(f)))
        cl.transform_bm(bm, m)
        visor = new_object(self.name("CapVisor"), bm, self.M["couro"])
        tag(visor, "cap_visor", "gear")
        self.reg(visor, "single", "head")
        # cordao dourado na frente da faixa + dois botoes
        bm = bmesh.new()
        pts = []
        for i in range(15):
            a = math.radians(-50 + 100 * i / 14)
            pts.append(V(math.sin(a) * (R * 1.03 + 0.004), math.cos(a) * (R * 1.03 + 0.004), 0.031 * k - 0.004 * k * math.cos(a * 1.4)))
        cl.tube(bm, pts, 0.0034, 6, True)
        for sxx in (-1, 1):
            a = math.radians(sxx * 54)
            c = V(math.sin(a) * (R * 1.03 + 0.003), math.cos(a) * (R * 1.03 + 0.003), 0.028 * k)
            tb = bmesh.new()
            cl.lathe(tb, [(0.0, 0.004), (0.006, 0.0035), (0.0075, 0.0), (0.0, 0.0)], 14)
            dd = V(math.sin(a), math.cos(a), 0)
            cl.transform_bm(tb, Matrix.Translation(c) @ dd.to_track_quat("Z", "Y").to_matrix().to_4x4())
            hero_lib.join_bm(bm, tb)
        cl.transform_bm(bm, m)
        cord = new_object(self.name("CapCord"), bm, self.M["ouro"])
        tag(cord, "cap_cord", "gear")
        self.reg(cord, "single", "head")
        # emblema da equipe na frente da copa (escudo-gota azul-marinho + rosa dos ventos dourada)
        fz = 0.066 * k
        fr = R * 1.14 + 0.002
        T = m @ Matrix.Translation((0, fr + 0.001, fz)) @ V(0, 1.0, -0.25).normalized().to_track_quat("Y", "Z").to_matrix().to_4x4()
        bm = bmesh.new()
        hero_lib.prism(bm, hero_lib.emblem_outline(0.046, 0.050, 32), 0.005, (0, -0.002, 0))
        bmesh.ops.bevel(bm, geom=[e for e in bm.edges if len(e.link_faces) == 2 and e.calc_face_angle(0) > 0.6], offset=0.0012, segments=2, affect="EDGES")
        cl.transform_bm(bm, T)
        em = new_object(self.name("CapBadge"), bm, self.M["emblema"])
        tag(em, "cap_badge", "gear")
        self.reg(em, "single", "head")
        bm = bmesh.new()
        hero_lib.prism(bm, hero_lib.star4(0.016, 0.0055), 0.003, (0, 0.003, 0.004))
        cl.transform_bm(bm, T)
        st = new_object(self.name("CapStar"), bm, self.M["ouro"])
        tag(st, "cap_star", "gear")
        self.reg(st, "single", "head")
        # cabelo escondido dentro da copa do bone sai da malha
        mi = m.inverted()
        bm = bmesh.new()
        bm.from_mesh(self.hair_ob.data)

        def inside(co):
            q = mi @ co
            return q.z > 0.012 * k and math.hypot(q.x, q.y) < R * 0.97
        hid = [f for f in bm.faces if all(inside(vv.co) for vv in f.verts)]
        bmesh.ops.delete(bm, geom=hid, context="FACES")
        bmesh.ops.delete(bm, geom=[vv for vv in bm.verts if not vv.link_faces], context="VERTS")
        bm.to_mesh(self.hair_ob.data)
        bm.free()

    # ------------------------------------------------------------ corpo inteirico (tronco + bracos + pernas num grafo so)
    def body_lv2(self):
        F, v = self.F, self.v
        hz, nz = F.hz, F.nz
        nodes, edges = [], []

        def add(co, r, link=None):
            nodes.append((tuple(co), r))
            if link is not None:
                edges.append((link, len(nodes) - 1))
            return len(nodes) - 1

        b = v["belly"]
        crotch = add((0, -0.004, hz - 0.050), b * 0.84)
        pelvis = add((0, -0.006, hz + 0.020), b * 1.00, crotch)
        waist = add((0, 0.000, hz + 0.105), b * 0.92, pelvis)
        chest = add((0, 0.006, nz - 0.090), b * 0.98, waist)
        upper = add((0, 0.000, nz - 0.040), b * 0.85, chest)
        add((0, 0.002, nz + 0.004), 0.054, upper)
        self.limb_segs = []
        for sx, s in ((1, "R"), (-1, "L")):
            sh = V(sx * F.sh.x, F.sh.y, F.sh.z)
            el = V(sx * F.elbow.x, F.elbow.y, F.elbow.z)
            W = V(sx * F.wrist.x, F.wrist.y, F.wrist.z)
            L = v["limb"]
            s0 = add(V(sx * F.sh.x * 0.62, 0.0, F.sh.z + 0.012), L * 1.30, upper)
            s1 = add(sh.lerp(el, 0.10), L * 1.20, s0)
            s2 = add(sh.lerp(el, 0.50), L * 1.02, s1)
            e0 = add(sh.lerp(el, 0.90), L * 0.90, s2)
            e1 = add(el.lerp(W, 0.12), L * 0.90, e0)
            f0 = add(el.lerp(W, 0.38), L * 0.94, e1)
            add(el.lerp(W, 0.92), L * 0.74, f0)
            hx, kx, fx = sx * F.hip_x, sx * F.knee_x, sx * F.foot_x
            kz = F.knee_z

            def lx(z):
                if z >= kz:
                    return hx + (kx - hx) * (hz - z) / (hz - kz)
                return kx + (fx - kx) * (kz - z) / (kz - F.ankle_z)
            h0 = add((hx, -0.004, hz - 0.060), 0.076, crotch)
            t1 = add((lx(hz - (hz - kz) * 0.45), 0.000, hz - (hz - kz) * 0.45), 0.068, h0)
            k0 = add((lx(kz + 0.024), 0.008, kz + 0.024), 0.054, t1)
            k1 = add((lx(kz - 0.018), 0.006, kz - 0.018), 0.050, k0)
            c0 = add((lx(kz - 0.062), -0.004, kz - 0.062), 0.052, k1)
            a0 = add((lx(F.ankle_z + 0.060), -0.004, F.ankle_z + 0.060), 0.042, c0)
            add((fx, -0.004, F.ankle_z + 0.012), 0.041, a0)
            self.limb_segs += [("upper_arm", s, sh, el), ("forearm", s, el, W),
                               ("thigh", s, V(hx, 0, hz - 0.03), V(kx, 0.006, kz)), ("shin", s, V(kx, 0.006, kz), V(fx, 0, F.ankle_z))]
        ob = cl.skin_obj(self.name("Body"), nodes, edges, self.M["uniforme"], levels=3, branch=1.0)
        self.shape_body(ob)
        decimate(ob, DECIMATE["body"])
        self.body_ob = ob
        return ob

    def shape_body(self, ob):
        """Articulacoes e formas: ombro, biceps, cotovelo de pele, joelho, panturrilha; tronco de crianca."""
        F, v = self.F, self.v
        hz, nz = F.hz, F.nz
        P = verts_np(ob)
        segs = [("torso", 0, np.array([0, 0, hz - 0.06]), np.array([0, 0, nz + 0.02]), v["belly"])]
        for kind, s, a, b in self.limb_segs:
            r = {"upper_arm": 0.048, "forearm": 0.040, "thigh": 0.070, "shin": 0.050}[kind]
            segs.append((kind, 1 if s == "R" else -1, np.array(a), np.array(b), r))
        D = []
        for kind, sx, a, b, r in segs:
            u, rr, rn, dn, L = seg_frame(P, a, b)
            uu = np.clip(u, 0, 1)
            dist = np.linalg.norm(P - (a + np.outer(uu, b - a)), axis=1)
            D.append(1.0 / ((dist / r) ** 8 + 1e-6))
        D = np.array(D)
        Wt = D / D.sum(axis=0)
        out = P.copy()
        w = Wt[0]
        z = P[:, 2]
        depth = 0.86 - 0.04 * smooth(z, hz + 0.05, nz - 0.05)
        out[:, 1] = P[:, 1] * (1 - w) + P[:, 1] * depth * w
        front = np.clip(P[:, 1] / 0.12, -1, 1)
        add_t = (0.006 * bump(z, nz - 0.095, 0.045) * np.clip(front, 0, 1) ** 1.5
                 + 0.008 * bump(z, hz + 0.065, 0.045) * np.clip(front, 0, 1) ** 2
                 + 0.012 * bump(z, hz - 0.030, 0.040) * np.clip(-front, 0, 1) ** 1.5)
        side = np.clip(np.abs(P[:, 0]) / 0.13, 0, 1)
        add_t += 0.008 * bump(z, hz - 0.01, 0.05) * side ** 2
        add_t -= 0.007 * bump(z, hz + 0.12, 0.04) * side ** 2
        rad = P.copy()
        rad[:, 2] = 0
        rn = rad / np.maximum(np.linalg.norm(rad, axis=1)[:, None], 1e-9)
        out += rn * (add_t * w)[:, None]
        for i, (kind, sx, a, b, r) in enumerate(segs[1:], start=1):
            w = Wt[i]
            u, rr, rnv, dn, L = seg_frame(P, a, b)
            fr, ou = ref_dirs(dn, sx)
            fdot = rnv @ fr
            odot = rnv @ ou
            d = np.zeros(len(P))
            if kind == "upper_arm":
                d += 0.008 * bump(u, 0.16, 0.16) * np.clip(0.35 + 0.65 * odot, 0, 1)
                d += 0.003 * bump(u, 0.55, 0.20) * np.clip(fdot, 0, 1)
            elif kind == "forearm":
                d += 0.006 * bump(u, 0.00, 0.06) * np.clip(-fdot, 0, 1) ** 2          # ponta do cotovelo (pele)
                d += 0.0035 * bump(u, 0.28, 0.20) * np.clip(0.5 + 0.5 * odot, 0, 1)
                d -= 0.004 * bump(u, 0.92, 0.10)                                        # pulso fino
            elif kind == "thigh":
                d += 0.005 * bump(u, 0.40, 0.28) * np.clip(fdot, 0, 1) ** 1.5
                d += 0.004 * bump(u, 0.10, 0.18) * np.clip(odot, 0, 1)
            elif kind == "shin":
                d += 0.010 * bump(u, 0.03, 0.09) * np.clip(fdot, 0, 1) ** 1.6           # joelho (pele, aparece)
                d += 0.008 * bump(u, 0.36, 0.18) * np.clip(-fdot, 0, 1) ** 1.2          # panturrilha
            out += rnv * (d * w)[:, None]
        set_verts(ob, out)
        bm = bmesh.new()
        bm.from_mesh(ob.data)
        pts = np.array([vv.co[:] for vv in bm.verts])
        jw = np.zeros(len(pts))
        for c in [np.array([sx * F.sh.x * 0.8, 0, F.sh.z - 0.03]) for sx in (1, -1)] + [np.array([0, 0, F.hz - 0.06])]:
            jw = np.maximum(jw, np.exp(-np.sum((pts - c) ** 2, axis=1) / 0.0016))
        sel = [vv for vv, ww in zip(bm.verts, jw) if ww > 0.3]
        for _ in range(4):
            bmesh.ops.smooth_vert(bm, verts=sel, factor=0.5, use_axis_x=True, use_axis_y=True, use_axis_z=True)
        bm.to_mesh(ob.data)
        bm.free()

    # ------------------------------------------------------------ regioes do corpo (camisa, bermuda, pele, meia)
    def regions(self):
        F = self.F
        self.z_waist = F.hz + 0.030
        self.z_hem = F.knee_z + 0.052                 # barra da bermuda (acima do joelho)
        self.z_sock = F.knee_z - 0.040                # meia de meio cano ate abaixo do joelho
        self.sleeve_u = 0.46                          # manga curta: ate o meio do braco

    def classify(self, P):
        """Regiao de cada ponto (repouso): 0 camisa, 1 bermuda, 2 pele, 3 meia."""
        F = self.F
        segs = [("torso", None, np.array([0, 0, F.hz - 0.06]), np.array([0, 0, F.nz + 0.04]), 0.13)]
        for kind, s, a, b in self.limb_segs:
            segs.append((kind, s, np.array(a), np.array(b), {"upper_arm": 0.048, "forearm": 0.040, "thigh": 0.070, "shin": 0.050}[kind]))
        sc, us = [], []
        for kind, s, a, b, r in segs:
            u, rr, rn, dn, L = seg_frame(P, a, b)
            uu = np.clip(u, 0, 1)
            dist = np.linalg.norm(P - (a + np.outer(uu, b - a)), axis=1)
            sc.append(dist / r)
            us.append(u)
        lab = np.argmin(np.array(sc), axis=0)
        kinds = [q[0] for q in segs]
        reg = np.zeros(len(P), int)
        z = P[:, 2]
        for i, kind in enumerate(kinds):
            sel = lab == i
            if kind == "torso":
                reg[sel] = np.where(z[sel] < self.z_waist, 1, 0)
            elif kind == "upper_arm":
                reg[sel] = np.where(us[i][sel] < self.sleeve_u, 0, 2)
            elif kind == "forearm":
                reg[sel] = 2
            else:
                reg[sel] = np.where(z[sel] >= self.z_hem, 1, np.where(z[sel] >= self.z_sock, 2, 3))
        return reg

    def split_body(self):
        """Corta o corpo inteirico (ja moldado e reduzido) em quatro objetos com as bordas coincidentes; folga de tecido na
        manga e na barra da bermuda (as bordas sao cobertas por vivos/barras modeladas)."""
        ob = self.body_ob
        bm = bmesh.new()
        bm.from_mesh(ob.data)
        planes = [((0, 0, self.z_waist), (0, 0, 1)), ((0, 0, self.z_hem), (0, 0, 1)), ((0, 0, self.z_sock), (0, 0, 1))]
        for kind, s, a, b in self.limb_segs:
            if kind == "upper_arm":
                planes.append((tuple(a.lerp(b, self.sleeve_u)), tuple((b - a).normalized())))
        for co, no in planes:
            g = bm.verts[:] + bm.edges[:] + bm.faces[:]
            bmesh.ops.bisect_plane(bm, geom=g, plane_co=co, plane_no=no, clear_inner=False, clear_outer=False)
        bm.to_mesh(ob.data)
        bm.free()
        me = ob.data
        cen = np.array([sum((me.vertices[i].co for i in p.vertices), Vector()) / len(p.vertices) for p in me.polygons])
        reg = self.classify(cen)
        names = [("Shirt", "shirt", "suit", "creme"), ("Shorts", "shorts", "suit", "calca"), ("LimbSkin", "skin_limb", "skin", "pele"),
                 ("Socks", "sock", "suit", "creme")]
        F = self.F
        outs = []
        for ri, (nm, part, grp, mk) in enumerate(names):
            bm = bmesh.new()
            bm.from_mesh(me)
            bm.faces.ensure_lookup_table()
            kill = [f for f in bm.faces if reg[f.index] != ri]
            bmesh.ops.delete(bm, geom=kill, context="FACES")
            if part == "sock":
                hid = [f for f in bm.faces if max(vv.co.z for vv in f.verts) < self.boot_top_z - 0.012]
                bmesh.ops.delete(bm, geom=hid, context="FACES")
            if part == "shirt":
                # camisa escondida sob as placas do colete: sai da malha (nao vaza pelo colete ao animar)
                hid = [f for f in bm.faces if all(self.vest_covers(vv.co) for vv in f.verts)]
                bmesh.ops.delete(bm, geom=hid, context="FACES")
            loose = [vv for vv in bm.verts if not vv.link_faces]
            bmesh.ops.delete(bm, geom=loose, context="VERTS")
            nob = new_object(self.name(nm), bm, self.M[mk], recalc=False)
            P = verts_np(nob)
            if part == "shirt":
                # manga solta: folga radial crescendo ate a barra; ombro justo
                for kind, s, a, b in self.limb_segs:
                    if kind != "upper_arm":
                        continue
                    u, rr, rn, dn, L = seg_frame(P, a, b)
                    w = smooth(u, 0.10, self.sleeve_u) * (u < self.sleeve_u + 0.08)
                    P += rn * (0.0055 * w)[:, None]
            elif part == "shorts":
                for kind, s, a, b in self.limb_segs:
                    if kind != "thigh":
                        continue
                    u, rr, rn, dn, L = seg_frame(P, a, b)
                    sx = 1 if s == "R" else -1
                    on = (P[:, 0] * sx > 0.01)
                    w = smooth(P[:, 2], self.z_hem + 0.12, self.z_hem) * on
                    P += rn * (0.010 * w)[:, None]
            elif part == "sock":
                # o pe da meia fica escondido dentro da botina: sai da malha (economia de triangulos)
                pass
            set_verts(nob, P)
            tag(nob, part, grp)
            self.reg(nob, "dist")
            outs.append(nob)
        bpy.data.objects.remove(ob)
        self.shirt_ob, self.shorts_ob, self.limbskin_ob, self.sock_ob = outs
        # barras: vivo azul na manga, barra dobrada da bermuda, punho canelado da meia
        bvh = BVHTree.FromObject(self.limbskin_ob, bpy.context.evaluated_depsgraph_get())
        bm_sl, bm_hm, bm_sk = bmesh.new(), bmesh.new(), bmesh.new()
        for kind, s, a, b in self.limb_segs:
            sx = 1 if s == "R" else -1
            if kind == "upper_arm":
                c = a.lerp(b, self.sleeve_u)
                ax = (b - a).normalized()
                r = self._radius_loop(self.limbskin_ob, c, ax)
                tb = bmesh.new()
                cl.torus_z(tb, r + 0.0045, 0.0055, 0.0, major=20, minor=5)
                cl.transform_bm(tb, Matrix.Translation(c) @ ax.to_track_quat("Z", "Y").to_matrix().to_4x4())
                hero_lib.join_bm(bm_sl, tb)
            if kind == "thigh":
                c = V(sx * self._leg_x(self.z_hem), 0.004, self.z_hem)
                ax = V(0, 0, 1)
                r = self._radius_loop(self.limbskin_ob, c, ax)
                tb = bmesh.new()
                cl.torus_z(tb, r + 0.0075, 0.0085, 0.0, major=20, minor=5)
                for vv in tb.verts:
                    vv.co.z *= 1.25
                cl.transform_bm(tb, Matrix.Translation(c))
                hero_lib.join_bm(bm_hm, tb)
            if kind == "shin":
                c = V(sx * self._leg_x(self.z_sock), 0.0, self.z_sock)
                r = self._radius_loop(self.sock_ob, c, V(0, 0, 1))
                tb = bmesh.new()
                cl.torus_z(tb, r + 0.0018, 0.0042, 0.0, major=20, minor=5)
                for vv in tb.verts:
                    vv.co.z *= 1.6
                cl.transform_bm(tb, Matrix.Translation(c))
                hero_lib.join_bm(bm_sk, tb)
        for bm_, nm, part, grp, mk in ((bm_sl, "SleeveBand", "sleeve_band", "suit", "uniforme"), (bm_hm, "ShortsHem", "shorts_hem", "suit", "calca"),
                                       (bm_sk, "SockTop", "sock_top", "suit", "creme")):
            o = new_object(self.name(nm), bm_, self.M[mk])
            tag(o, part, grp)
            self.reg(o, "dist")

    def _leg_x(self, z):
        F = self.F
        if z >= F.knee_z:
            return F.hip_x + (F.knee_x - F.hip_x) * (F.hz - z) / (F.hz - F.knee_z)
        return F.knee_x + (F.foot_x - F.knee_x) * (F.knee_z - z) / (F.knee_z - F.ankle_z)

    @staticmethod
    def _radius_loop(ob, c, ax, tol=0.0025, reach=0.09):
        """Raio medio do laco de corte de `ob` no plano (c, ax): vertices a menos de `tol` do plano e perto de c."""
        P = verts_np(ob)
        c_, a_ = np.array(c), np.array(ax.normalized())
        d = (P - c_) @ a_
        rv = P - c_ - np.outer(d, a_)
        r = np.linalg.norm(rv, axis=1)
        sel = (np.abs(d) < tol) & (r < reach)
        return float(r[sel].mean()) if sel.any() else 0.045

    @staticmethod
    def _radius_at(bvh, c, ax):
        ax = ax.normalized()
        ref = ax.cross(V(0, 1, 0) if abs(ax.y) < 0.9 else V(1, 0, 0)).normalized()
        rs = []
        for i in range(16):
            a = 2 * math.pi * i / 16
            d = (ref * math.cos(a) + ax.cross(ref) * math.sin(a)).normalized()
            h = bvh.ray_cast(c + d * 0.2, -d)[0]
            if h is not None:
                rs.append((h - c).length)
        return sum(rs) / len(rs) if rs else 0.045

    # ------------------------------------------------------------ colete salva-vidas
    def vest(self):
        """Placas de espuma sobre a camisa: duas placas na frente (abertura central), uma nas costas, laterais abertas com
        tiras (o braco passa livre). Superficie parametrica (theta, z) projetada no corpo por raycast; espessura com borda
        arredondada e canais de costura modelados; vivo branco em volta (borda). Gola-travesseiro em ferradura atras do pescoco."""
        F, k = self.F, self.F.k
        hz, nz = F.hz, F.nz
        dg = bpy.context.evaluated_depsgraph_get()
        bvh = BVHTree.FromObject(self.body_ob, dg)
        z_bot = hz + 0.060
        zV, zS, zA, zB = nz - 0.085, nz - 0.034, F.sh.z - 0.100, nz - 0.030
        self.vest_z = (z_bot, zV, zS, zA, zB)

        def surf(th, z):
            d = V(math.sin(th), math.cos(th), 0.0)
            h = bvh.ray_cast(V(0, 0.0, z), d)
            if h[0] is None:
                return V(0, 0, z) + d * 0.12, d
            n = h[1]
            return h[0], (n * 0.35 + d * 0.65).normalized()

        def top_front(a):            # a = |theta| em graus
            return zV + (zS - zV) * sm1(a, 3, 26) - (zS - zA) * sm1(a, 40, 64)

        def top_back(a):             # a = distancia angular a traseira (0 = centro das costas)
            return zA + (zB - zA) * sm1(62 - a, 0, 28)
        channels_f = (20.0, 40.0)
        channels_b = (22.0, -22.0)
        panels = [("R", 3.5, 64.0, top_front, channels_f), ("L", -64.0, -3.5, top_front, channels_f),
                  ("B", 118.0, 242.0, top_back, channels_b)]
        T_front, T_back = 0.021, 0.016
        self.vest_panels = [(a0, a1, topf, key) for key, a0, a1, topf, _ in panels]
        bm_o, bm_r = bmesh.new(), bmesh.new()
        self.vest_surf = {}
        for key, a0, a1, topf, chans in panels:
            nu = 17 if key != "B" else 28
            nv = 12
            grid = []
            for i in range(nu + 1):
                th_d = a0 + (a1 - a0) * i / nu
                th = math.radians(th_d)
                aa = abs(th_d) if key != "B" else abs(180.0 - th_d)
                zt = topf(aa)
                col = []
                for j in range(nv + 1):
                    s = j / nv
                    z = z_bot + (zt - z_bot) * s
                    p, n = surf(th, z)
                    r_loc = max(math.hypot(p.x, p.y), 0.05)
                    # distancia a borda (arco em theta, altura em z)
                    e = min((th_d - a0) * math.pi / 180 * r_loc, (a1 - th_d) * math.pi / 180 * r_loc, z - z_bot, zt - z)
                    if key == "B":
                        T = T_back
                        cc = 180.0 - th_d
                    else:
                        T = T_front * (1.0 - 0.25 * sm1(aa, 40, 64))
                        cc = aa
                    prof = math.sqrt(max(0.0, 1.0 - (1.0 - min(e / 0.011, 1.0)) ** 2))
                    t = 0.0035 + T * prof
                    for c0 in chans:
                        dc = (cc - c0) * math.pi / 180 * r_loc
                        t -= 0.0055 * math.exp(-(dc / 0.0035) ** 2) * min(e / 0.012, 1.0)
                    col.append((p + n * 0.0016, p + n * (0.0016 + t), n))
                grid.append(col)
            self.vest_surf[key] = (a0, a1, grid)
            O = [[bm_o.verts.new(c[1]) for c in col] for col in grid]
            for i in range(nu):
                for j in range(nv):
                    # theta crescente + z crescente: (u x v) aponta para dentro -> ordem invertida (normal para fora)
                    bm_o.faces.new((O[i][j], O[i][j + 1], O[i + 1][j + 1], O[i + 1][j]))
            # borda (vivo): faixa do contorno externo ate a superficie do corpo
            loop = [(i, 0) for i in range(nu + 1)] + [(nu, j) for j in range(1, nv + 1)] + \
                   [(i, nv) for i in range(nu - 1, -1, -1)] + [(0, j) for j in range(nv - 1, 0, -1)]
            outer = [bm_r.verts.new(grid[i][j][1]) for i, j in loop]
            inner = [bm_r.verts.new(grid[i][j][0]) for i, j in loop]
            L_ = len(loop)
            for q in range(L_):
                w_ = (q + 1) % L_
                bm_r.faces.new((outer[q], outer[w_], inner[w_], inner[q]))
        ob = new_object(self.name("Vest"), bm_o, self.M["uniforme"], recalc=False)
        tag(ob, "vest", "suit")
        self.reg(ob, "torso")
        self.vest_ob = ob
        rim = new_object(self.name("VestRim"), bm_r, self.M["creme"], recalc=False)
        tag(rim, "vest_rim", "suit")
        self.reg(rim, "torso")

    def vest_covers(self, p, margin_deg=5.0, margin_z=0.012):
        z_bot = self.vest_z[0]
        th = math.degrees(math.atan2(p.x, p.y))
        for a0, a1, topf, key in self.vest_panels:
            t = th if key != "B" else th % 360.0
            if a0 + margin_deg <= t <= a1 - margin_deg:
                aa = abs(t) if key != "B" else abs(180.0 - t)
                if z_bot + margin_z <= p.z <= topf(aa) - margin_z:
                    return True
        return False

    def vest_point(self, key, th_d, z, extra=0.0):
        """Ponto na superficie de fora do colete (interpolado na grade)."""
        a0, a1, grid = self.vest_surf[key]
        nu = len(grid) - 1
        fi = (th_d - a0) / (a1 - a0) * nu
        i = int(min(max(math.floor(fi), 0), nu - 1))
        t = min(max(fi - i, 0.0), 1.0)
        best = None
        for ii, w in ((i, 1 - t), (i + 1, t)):
            col = grid[ii]
            zs = [c[0].z for c in col]
            j = 0
            while j < len(col) - 2 and zs[j + 1] < z:
                j += 1
            s = min(max((z - zs[j]) / max(zs[j + 1] - zs[j], 1e-9), 0.0), 1.0)
            p = col[j][1].lerp(col[j + 1][1], s)
            n = col[j][2].lerp(col[j + 1][2], s).normalized()
            best = (p * w, n * w) if best is None else (best[0] + p * w, best[1] + n * w)
        return best[0] + best[1].normalized() * extra, best[1].normalized()

    def vest_details(self):
        F, k = self.F, self.F.k
        hz, nz = F.hz, F.nz
        z_bot, zV, zS, zA, zB = self.vest_z
        M = self.M
        # tiras da frente (azul-marinho) com fivela de engate branca no centro
        zs = hz + 0.112
        self.strap_z = zs
        self.reflect_z = (hz + 0.085, hz + 0.141)          # faixas refletivas (pintadas na textura)
        bm = bmesh.new()
        for side, a0, a1 in (("R", 4.0, 46.0), ("L", -46.0, -4.0)):
            pts = []
            for i in range(13):
                th = a0 + (a1 - a0) * i / 12
                p, n = self.vest_point(side, th, zs, 0.0012)
                pts.append((p, n))
            rows = []
            for p, n in pts:
                rows.append([bm.verts.new(p + n * o + V(0, 0, dz)) for dz, o in ((-0.0095, 0.0), (-0.0085, 0.0028), (0.0085, 0.0028), (0.0095, 0.0))])
            for i in range(len(rows) - 1):
                for q in range(3):
                    f = (rows[i][q], rows[i + 1][q], rows[i + 1][q + 1], rows[i][q + 1])
                    bm.faces.new(f if side == "L" else tuple(reversed(f)))
        st = new_object(self.name("VestStraps"), bm, M["couro"])
        tag(st, "vest_strap", "gear")
        self.reg(st, "torso")
        pR, nR = self.vest_point("R", 4.0, zs, 0.004)
        pL, nL = self.vest_point("L", -4.0, zs, 0.004)
        c = (pR + pL) * 0.5
        bm = bmesh.new()
        cl.rounded_box(bm, (0, 0, 0), (0.046, 0.010, 0.024), 0.004)
        tb = bmesh.new()
        cl.rounded_box(tb, (0, 0.006, 0), (0.016, 0.004, 0.012), 0.0015)
        hero_lib.join_bm(bm, tb)
        cl.transform_bm(bm, Matrix.Translation(c + V(0, 0.002, 0)))
        bk = new_object(self.name("VestBuckle"), bm, M["creme"])
        tag(bk, "vest_buckle", "gear")
        self.reg(bk, "torso")
        # tiras laterais (sob o braco) ligando frente e costas
        bm = bmesh.new()
        dg = bpy.context.evaluated_depsgraph_get()
        bvh = BVHTree.FromObject(self.body_ob, dg)
        for sx in (1, -1):
            for zz in (z_bot + 0.022, z_bot + 0.064):
                pts = []
                for i in range(11):
                    th = math.radians(sx * (60 + 62 * i / 10))
                    d = V(math.sin(th), math.cos(th), 0)
                    h = bvh.ray_cast(V(0, 0, zz), d)
                    p = h[0] if h[0] is not None else d * 0.12
                    pts.append(p + d * 0.0028 + V(0, 0, 0))
                rows = [[bm.verts.new(p + V(0, 0, dz)) for dz in (-0.008, 0.008)] for p in pts]
                for i in range(len(rows) - 1):
                    f = (rows[i][0], rows[i + 1][0], rows[i + 1][1], rows[i][1])
                    bm.faces.new(f if sx < 0 else tuple(reversed(f)))
        ss = new_object(self.name("VestSideStraps"), bm, M["couro"], recalc=False)
        sol = ss.modifiers.new("sol", "SOLIDIFY")
        sol.thickness = 0.0022
        sol.offset = 1.0
        hero_lib.bake(ss)
        tag(ss, "vest_strap", "gear")
        self.reg(ss, "torso")
        # gola-travesseiro (ferradura) atras do pescoco; as pontas descem sobre as placas da frente
        path = []
        for sx in (1, -1):
            pf, nf = self.vest_point("R" if sx > 0 else "L", sx * 13.0, zS - 0.045, 0.006)
            path.append((sx, pf))
        nodes, edges = [], []

        def add(co, r, link=None):
            nodes.append((tuple(co), r))
            if link is not None:
                edges.append((link, len(nodes) - 1))
            return len(nodes) - 1
        back = add((0, -0.086, nz + 0.012), 0.030)
        for sx, pf in path:
            b1 = add((sx * 0.050, -0.072, nz + 0.010), 0.030, back)
            b2 = add((sx * 0.080, -0.030, nz + 0.000), 0.028, b1)
            b3 = add((sx * 0.078, 0.030, nz - 0.022), 0.025, b2)
            add(pf + V(0, 0.004, 0.006), 0.021, b3)
        col = cl.skin_obj(self.name("CollarPillow"), nodes, edges, M["uniforme"], levels=2, branch=0.8)
        P = verts_np(col)
        # achata a gola contra o corpo (mais larga que funda)
        cy = np.array([0.0, 0.0])
        P[:, 2] = (nz + 0.006) + (P[:, 2] - (nz + 0.006)) * 0.92
        set_verts(col, P)
        tag(col, "collar_pillow", "suit")
        self.reg(col, "torso")
        # apito no cordao, pendurado na ponta direita da gola
        pw, nw = self.vest_point("R", 24.0, zS - 0.075, 0.010)
        bm = bmesh.new()
        p0 = path[0][1] + V(0.010, 0.012, -0.010)
        cl.tube(bm, [p0, p0.lerp(pw, 0.5) + nw * 0.006 + V(0, 0, -0.006), pw + V(0, 0, 0.012)], 0.0018, 5, True)
        cord = new_object(self.name("WhistleCord"), bm, M["creme"])
        tag(cord, "whistle_cord", "gear")
        self.reg(cord, "torso")
        bm = bmesh.new()
        cl.rounded_box(bm, (0, 0, 0), (0.016, 0.034, 0.014), 0.005)
        tb = bmesh.new()
        cl.ellipsoid(tb, (0, -0.010, -0.004), (0.011, 0.011, 0.011), 12, 6)
        hero_lib.join_bm(bm, tb)
        q = nw.to_track_quat("Z", "Y").to_matrix().to_4x4()
        cl.transform_bm(bm, Matrix.Translation(pw) @ Matrix.Rotation(math.radians(-15), 4, "Z") @ Matrix.Rotation(math.radians(80), 4, "X"))
        wh = new_object(self.name("Whistle"), bm, M["ouro"])
        tag(wh, "whistle", "gear")
        self.reg(wh, "torso")
        # EMBLEMA da equipe na placa esquerda do peito (lado esquerdo da personagem, -X)
        pe, ne = self.vest_point("L", -36.0, zS - 0.058, 0.0)
        ne_h = V(ne.x, ne.y, ne.z * 0.4).normalized()
        T = Matrix.Translation(pe) @ ne_h.to_track_quat("Y", "Z").to_matrix().to_4x4()
        w, h = 0.070, 0.076
        bm = bmesh.new()
        hero_lib.prism(bm, hero_lib.emblem_outline(w, h, 40), 0.006, (0, -0.002, 0))
        bmesh.ops.bevel(bm, geom=[e for e in bm.edges if len(e.link_faces) == 2 and e.calc_face_angle(0) > 0.6], offset=0.0018, segments=3, affect="EDGES")
        cl.transform_bm(bm, T)
        self.reg(tag(new_object(self.name("Emblem"), bm, M["emblema"]), "emblem", "gear"), "torso")
        bm = bmesh.new()
        hero_lib.prism(bm, hero_lib.star4(0.023, 0.0075), 0.004, (0, 0.004, 0.007))
        bmesh.ops.bevel(bm, geom=bm.edges[:], offset=0.0009, segments=1, affect="EDGES")
        cl.transform_bm(bm, T)
        self.reg(tag(new_object(self.name("EmblemStar"), bm, M["ouro"]), "emblem_star", "gear"), "torso")
        bm = bmesh.new()
        band = []
        for i in range(13):
            t = (i / 12) * 2 - 1
            band.append((t * w * 0.38, -0.020 + 0.007 * t * t))
        for i in range(12, -1, -1):
            t = (i / 12) * 2 - 1
            band.append((t * w * 0.38, -0.027 + 0.007 * t * t))
        hero_lib.prism(bm, band, 0.003, (0, 0.004, 0))
        cl.transform_bm(bm, T)
        self.reg(tag(new_object(self.name("EmblemBand"), bm, M["creme"]), "emblem_band", "gear"), "torso")

    # ------------------------------------------------------------ cinto de equipe + fivela-bussola
    def team(self):
        F = self.F
        hz = F.hz
        bvh = BVHTree.FromObject(self.body_ob, bpy.context.evaluated_depsgraph_get())
        bz = hz + 0.030
        rows = []
        bm = bmesh.new()
        prof = [(-0.017, 0.000), (-0.015, 0.008), (0.015, 0.008), (0.017, 0.000)]
        for i in range(48):
            a = 2 * math.pi * i / 48
            dr = V(math.sin(a), math.cos(a), 0)
            hit = bvh.ray_cast(V(0, 0, bz), dr)[0]
            p = (hit if hit else V(0, 0, bz) + dr * 0.12) + dr * 0.003
            rows.append([bm.verts.new(p + dr * o + V(0, 0, dz)) for dz, o in prof])
        for i in range(48):
            j = (i + 1) % 48
            for q in range(3):
                bm.faces.new((rows[i][q], rows[j][q], rows[j][q + 1], rows[i][q + 1]))
        belt = new_object(self.name("Belt"), bm, self.M["couro"], recalc=True)
        sub = belt.modifiers.new("sub", "SUBSURF")
        sub.levels = 1
        hero_lib.bake(belt)
        tag(belt, "belt", "gear")
        self.reg(belt, "torso")
        self.belt_z = bz
        by = (cl.snap_y(self.body_ob, 0.0, bz) or 0.11) + 0.010
        bm = bmesh.new()
        cl.lathe(bm, [(0.0, 0.011), (0.022, 0.011), (0.027, 0.007), (0.028, 0.0), (0.0, 0.0)], 32)
        cl.transform_bm(bm, Matrix.Translation((0, by - 0.003, bz)) @ Matrix.Rotation(math.radians(-90), 4, "X"))
        buckle = new_object(self.name("Buckle"), bm, self.M["ouro"])
        tag(buckle, "buckle", "gear")
        self.reg(buckle, "single", "hips")
        bm = bmesh.new()
        hero_lib.prism(bm, hero_lib.star4(0.019, 0.006), 0.004, (0, by + 0.007, bz))
        bmesh.ops.bevel(bm, geom=bm.edges[:], offset=0.0009, segments=1, affect="EDGES")
        stt = new_object(self.name("BuckleStar"), bm, self.M["emblema"])
        tag(stt, "buckle_star", "gear")
        self.reg(stt, "single", "hips")

    # ------------------------------------------------------------ gola da camisa (pontas dobradas sobre o decote do colete)
    def shirt_collar(self):
        F = self.F
        nz = F.nz
        bm = bmesh.new()
        rows = []
        nu, nv = 30, 3
        for i in range(nu + 1):
            a = math.radians(14 + (360 - 28) * i / nu)
            back = 0.5 - 0.5 * math.cos(a)
            frontness = 1 - back
            ring = []
            for j in range(nv + 1):
                t = j / nv
                # gola dobrada: sobe atras e cai para fora na frente (pontas)
                r = 0.057 + 0.003 * back + (0.010 + 0.022 * frontness ** 3) * t
                z = nz + 0.012 * back + (0.014 * back - 0.020 * frontness ** 2) * t
                ring.append(bm.verts.new((r * math.sin(a) * 1.05, r * math.cos(a) * 0.98 + 0.004, z)))
            rows.append(ring)
        for i in range(nu):
            for j in range(nv):
                bm.faces.new((rows[i][j], rows[i + 1][j], rows[i + 1][j + 1], rows[i][j + 1]))
        ob = new_object(self.name("ShirtCollar"), bm, self.M["creme"], recalc=False)
        sol = ob.modifiers.new("sol", "SOLIDIFY")
        sol.thickness = 0.004
        sol.offset = 1.0
        hero_lib.bake(ob)
        tag(ob, "shirt_collar", "suit")
        self.reg(ob, "torso")

    # ------------------------------------------------------------ maos de pele (4 dedos, relaxadas)
    def hands(self):
        F, v = self.F, self.v
        for sx, sd in ((1, "R"), (-1, "L")):
            W, d, f, n = F.hand_frame(sx)
            k = v["hand"]
            nn, ee = [], []

            def add(co, r, link=None):
                nn.append((tuple(co), r))
                if link is not None:
                    ee.append((link, len(nn) - 1))
                return len(nn) - 1
            w0 = add(W - d * 0.034 * k, 0.020 * k)
            w1 = add(W + d * 0.002 * k, 0.021 * k, w0)
            palm = add(W + d * 0.034 * k, 0.027 * k, w1)
            # polegar relaxado: ao lado da palma, para a frente e um pouco para baixo (sem fechar)
            t0 = add(W + d * 0.016 * k + f * 0.022 * k + n * 0.006 * k, 0.0125 * k, w1)
            t1 = add(W + d * 0.036 * k + f * 0.038 * k + n * 0.010 * k, 0.0112 * k, t0)
            add(W + d * 0.054 * k + f * 0.044 * k + n * 0.012 * k, 0.0100 * k, t1)
            # 3 dedos levemente abertos, quase retos (curva suave so na ponta: mao relaxada, nao garra)
            for off, ln, spread in ((0.0160, 0.040, 0.22), (-0.0005, 0.045, 0.0), (-0.0165, 0.038, -0.24)):
                base = add(W + d * 0.054 * k + f * off * k, 0.0122 * k, palm)
                fd = (d + f * spread * 0.30).normalized()
                mid = add(W + d * 0.054 * k + f * off * k + fd * ln * 0.52 * k + n * 0.002 * k, 0.0114 * k, base)
                add(W + d * 0.054 * k + f * off * k + fd * ln * k + n * 0.0055 * k, 0.0100 * k, mid)
            ob = cl.skin_obj(self.name("Hand" + sd), nn, ee, self.M["pele"], levels=2, branch=0.6)
            P = verts_np(ob)
            Wn = np.array(W)
            loc = P - Wn
            dd, ff, nnv = np.array(d), np.array(f), np.array(n)
            ad, af, an = loc @ dd, loc @ ff, loc @ nnv
            palm_w = np.exp(-((ad - 0.028 * k) / (0.032 * k)) ** 2)
            thumb = (af > 0.016 * k) & (an > 0.003 * k) & (ad < 0.05 * k)
            sq = 1 - 0.36 * palm_w * (~thumb)
            P2 = Wn + np.outer(ad, dd) + np.outer(af * (1 + 0.10 * palm_w * (~thumb)), ff) + np.outer(an * sq, nnv)
            set_verts(ob, P2)
            tag(ob, "hand", "skin")
            self.reg(ob, "single", "hand." + sd)

    # ------------------------------------------------------------ bussola de pulso (esquerda) e pulseira de corda (direita)
    def wrist_gear(self):
        F, v = self.F, self.v
        L = v["limb"]
        for sx, sd in ((-1, "L"), (1, "R")):
            el = V(sx * F.elbow.x, F.elbow.y, F.elbow.z)
            W = V(sx * F.wrist.x, F.wrist.y, F.wrist.z)
            ax = (W - el).normalized()
            q = ax.to_track_quat("Z", "Y").to_matrix().to_4x4()
            c = W - ax * 0.024
            bvh = BVHTree.FromObject(self.limbskin_ob, bpy.context.evaluated_depsgraph_get())
            r = self._radius_at(bvh, c, ax)
            bm = bmesh.new()
            if sd == "L":
                cl.torus_z(bm, r + 0.0030, 0.0055, 0.0, major=24, minor=5)
                for vv in bm.verts:
                    vv.co.z *= 1.9
                cl.transform_bm(bm, Matrix.Translation(c) @ q)
                strap = new_object(self.name("CompassStrap"), bm, self.M["couro"])
                tag(strap, "compass_strap", "gear")
                self.reg(strap, "single", "forearm.L")
                # caixa da bussola no dorso do pulso (lado de fora e para cima), aro dourado, mostrador branco, cupula de vidro
                outv = V(-0.85, 0.25, 0.45)
                outv = (outv - ax * outv.dot(ax)).normalized()
                P0 = c + outv * (r + 0.004)
                Tq = outv.to_track_quat("Z", "Y").to_matrix().to_4x4()
                self.compass_c = P0 + outv * 0.0108
                self.compass_n = outv.copy()
                bm = bmesh.new()
                cl.lathe(bm, [(0.0, 0.010), (0.021, 0.010), (0.025, 0.008), (0.026, 0.004), (0.024, 0.0), (0.0, 0.0)], 32)
                # coroa (botao de girar)
                tb = bmesh.new()
                cl.lathe(tb, [(0.0, 0.005), (0.004, 0.005), (0.0045, 0.0), (0.0, 0.0)], 10)
                cl.transform_bm(tb, Matrix.Translation((0, 0.026, 0.005)) @ Matrix.Rotation(math.radians(-90), 4, "X"))
                hero_lib.join_bm(bm, tb)
                cl.transform_bm(bm, Matrix.Translation(P0) @ Tq)
                hs = new_object(self.name("Compass"), bm, self.M["ouro"])
                tag(hs, "compass", "gear")
                self.reg(hs, "single", "forearm.L")
                bm = bmesh.new()
                cl.lathe(bm, [(0.0, 0.0108), (0.0195, 0.0108), (0.0195, 0.0090), (0.0, 0.0090)], 28)
                cl.transform_bm(bm, Matrix.Translation(P0) @ Tq)
                dial = new_object(self.name("CompassDial"), bm, self.M["creme"])
                tag(dial, "compass_dial", "gear")
                self.reg(dial, "single", "forearm.L")
                bm = bmesh.new()
                hero_lib.prism(bm, [(0, 0.016), (0.0042, 0.0), (0, -0.016), (-0.0042, 0.0)], 0.0016, (0, 0, 0))
                cl.transform_bm(bm, Matrix.Translation(P0) @ Tq @ Matrix.Translation((0, 0, 0.0127)) @ Matrix.Rotation(math.radians(-90), 4, "X")
                                @ Matrix.Rotation(math.radians(25), 4, "Y"))
                ndl = new_object(self.name("CompassNeedle"), bm, self.M["ouro"])
                tag(ndl, "compass_needle", "gear")
                self.reg(ndl, "single", "forearm.L")
                bm = bmesh.new()
                cl.ellipsoid(bm, (0, 0, 0.0112), (0.0200, 0.0200, 0.0055), 18, 6)
                cut = [vv for vv in bm.verts if vv.co.z < 0.0112]
                for vv in cut:
                    vv.co.z = 0.0112
                cl.transform_bm(bm, Matrix.Translation(P0) @ Tq)
                gl = new_object(self.name("CompassGlass"), bm, self.M["vidro"])
                tag(gl, "compass_glass", "glass")
                self.reg(gl, "single", "forearm.L")
            else:
                # pulseira de corda trancada (azul e branca): dois toros torcidos
                for ph_, mk, part in ((0.0, "uniforme", "bracelet_a"), (math.pi, "creme", "bracelet_b")):
                    bm = bmesh.new()
                    pts = []
                    for i in range(31):
                        a = 2 * math.pi * i / 30
                        tw = 6 * a + ph_
                        rr = r + 0.0035 + 0.0018 * math.cos(tw)
                        pts.append(V(rr * math.cos(a), rr * math.sin(a), 0.0026 * math.sin(tw)))
                    cl.tube(bm, pts, 0.0024, 4, False)
                    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-4)
                    cl.transform_bm(bm, Matrix.Translation(c) @ q)
                    br = new_object(self.name("Bracelet" + part[-1].upper()), bm, self.M[mk])
                    tag(br, part, "gear")
                    self.reg(br, "single", "forearm.R")

    # ------------------------------------------------------------ botinas nauticas (cano baixo, sola branca grossa, cadarco)
    def boots(self):
        F, v = self.F, self.v
        bk = v["boot"]
        self.boot_objs = {}
        for sx, sd in ((1, "R"), (-1, "L")):
            x = sx * F.foot_x
            nn = [((x, -0.010, F.ankle_z + 0.050 * bk), 0.047 * bk), ((x, -0.014, F.ankle_z + 0.000), 0.055 * bk),
                  ((x, F.ball_y * 0.62, 0.050 * bk), 0.056 * bk), ((x + sx * 0.002, F.toe_y - 0.050 * bk, 0.048 * bk), 0.053 * bk)]
            boot = cl.skin_obj(self.name("Boot" + sd), nn, [(0, 1), (1, 2), (2, 3)], self.M["botas"], levels=3, floor=0.024 * bk)
            P = verts_np(boot)
            yrel = (P[:, 1] - F.heel_y) / (F.toe_y - F.heel_y)
            # bico redondo e um pouco mais largo, achatado em cima; lateral de dentro mais reta (nada invade o vao)
            inner = (P[:, 0] - x) * sx < 0
            P[:, 0] = x + (P[:, 0] - x) * np.where(inner, 0.90, 1.0 + 0.06 * smooth(yrel, 0.45, 0.95))
            P[:, 2] = np.where(P[:, 2] > 0.05, 0.05 + (P[:, 2] - 0.05) * (1 - 0.12 * smooth(yrel, 0.55, 0.95)), P[:, 2])
            set_verts(boot, P)
            z_top = float(P[:, 2].max()) - 0.008
            bm = bmesh.new()
            bm.from_mesh(boot.data)
            hero_lib.bisect_keep(bm, (0, 0, z_top), (0, 0, 1), keep_above=False)
            rim = [vv.co.copy() for vv in bm.verts if abs(vv.co.z - z_top) < 1e-4]
            bm.to_mesh(boot.data)
            bm.free()
            assert len(rim) > 8, "corte da boca da bota nao achou o aro"
            rc = sum(rim, Vector()) / len(rim)
            rr = sum(((p - rc).xy.length for p in rim), 0.0) / len(rim)
            tag(boot, "boot", "gear")
            self.reg(boot, "dist")
            # sola branca, contorno medido da propria bota (+4 mm), 2,6 cm, com frisos
            BP = verts_np(boot)
            low = BP[BP[:, 2] < 0.065]
            cxy = np.array([x, low[:, 1].mean()])
            bm = bmesh.new()
            n_ = 36
            prof = []
            for i in range(n_):
                a = 2 * math.pi * i / n_
                dv = np.array([math.cos(a), math.sin(a)])
                proj = (low[:, :2] - cxy) @ dv
                prof.append(cxy + dv * (proj.max() + 0.004))
            rows = []
            for zz, grow in ((0.0, -0.004), (0.005, 0.0), (0.022, 0.0), (0.028, -0.003)):
                row = []
                for pxy in prof:
                    dv = pxy - cxy
                    dv = dv / max(np.linalg.norm(dv), 1e-9)
                    qq = pxy + dv * grow
                    row.append(bm.verts.new((qq[0], qq[1], zz)))
                rows.append(row)
            for zi in range(3):
                for i in range(n_):
                    j = (i + 1) % n_
                    bm.faces.new((rows[zi][i], rows[zi][j], rows[zi + 1][j], rows[zi + 1][i]))
            bm.faces.new(list(reversed(rows[0])))
            bm.faces.new(rows[3])
            sole = new_object(self.name("Sole" + sd), bm, self.M["creme"])
            tag(sole, "sole", "gear")
            self.reg(sole, "dist")
            # colarinho acolchoado na boca da botina
            bm = bmesh.new()
            cl.torus_z(bm, rr - 0.002, 0.0085, z_top + 0.0015, sy=0.97, major=24, minor=6)
            cl.transform_bm(bm, Matrix.Translation((rc.x, rc.y, 0)))
            top = new_object(self.name("BootCollar" + sd), bm, self.M["uniforme"])
            tag(top, "boot_collar", "gear")
            self.reg(top, "dist")
            # cadarco branco em X no peito do pe (3 cruzamentos) + ilhoses dourados
            bvh = BVHTree.FromObject(boot, bpy.context.evaluated_depsgraph_get())
            bm = bmesh.new()
            bme = bmesh.new()
            eys = []
            for i, yy in enumerate((0.040, 0.066, 0.092)):
                yy = yy * bk
                for side in (-1, 1):
                    xx = x + side * 0.019
                    h = bvh.ray_cast(V(xx, yy, 0.30), V(0, 0, -1))[0]
                    if h is None:
                        continue
                    eys.append((i, side, h))
                    tb = bmesh.new()
                    cl.torus_z(tb, 0.0040, 0.0013, 0.0, major=6, minor=3)
                    cl.transform_bm(tb, Matrix.Translation(h + V(0, 0, 0.0006)))
                    hero_lib.join_bm(bme, tb)
            for i in range(2):
                a = [e for e in eys if e[0] == i]
                b_ = [e for e in eys if e[0] == i + 1]
                for e1 in a:
                    for e2 in b_:
                        if e1[1] != e2[1]:
                            mid = (e1[2] + e2[2]) * 0.5 + V(0, 0, 0.004)
                            cl.tube(bm, [e1[2] + V(0, 0, 0.002), mid, e2[2] + V(0, 0, 0.002)], 0.0021, 5, True)
            # laco por cima
            a = [e for e in eys if e[0] == 2]
            if len(a) == 2:
                cpt = (a[0][2] + a[1][2]) * 0.5 + V(0, 0, 0.004)
                for side in (-1, 1):
                    pts = [cpt + V(side * 0.003, 0, 0), cpt + V(side * 0.013, -0.006, 0.006), cpt + V(side * 0.016, 0.004, 0.003),
                           cpt + V(side * 0.004, 0.002, 0.001)]
                    cl.tube(bm, pts, 0.0021, 5, True)
            lc = new_object(self.name("Laces" + sd), bm, self.M["creme"])
            tag(lc, "laces", "gear")
            self.reg(lc, "dist")
            ey = new_object(self.name("Eyelets" + sd), bme, self.M["ouro"])
            tag(ey, "eyelets", "gear")
            self.reg(ey, "dist")
            self.boot_objs[sd] = [boot, sole, top, lc, ey]
            self.boot_top_z = z_top

    # ------------------------------------------------------------ pescoco (pele)
    def neck(self):
        F = self.F
        nodes = [((0, 0.004, F.nz - 0.03), 0.038), ((0, 0.006, F.chin + 0.04), 0.036)]
        ob = cl.skin_obj(self.name("Neck"), nodes, [(0, 1)], self.M["pele"], levels=2)
        tag(ob, "skin_neck", "skin")
        self.reg(ob, "dist")

    def face_lv2(self):
        F, M = self.F, self.M
        import hero_face
        mats = dict(eye=M["olhos"], iris=M["iris"], dark=M["escuro"], skin=M["pele"], mouth=M["boca"])
        ob, info = hero_face.build_face(None, self.name("Face"), mats, self.head_ob, F.hc, k=F.k, eye_size=self.v["eye"])
        self.face_ob = ob
        self.eye_info = info
        tag(ob, "face", "face")

    # ------------------------------------------------------------ montagem
    def build_lv2(self, with_rig=True):
        self.regions()
        self.head_parts()
        self.neck()
        self.body_lv2()
        self.vest()
        self.vest_details()
        self.team()
        self.shirt_collar()
        self.boots()
        self.split_body()
        self.hands()
        self.wrist_gear()
        for ob, _, _ in self.parts:
            if ob.modifiers:
                hero_lib.bake(ob)
        for ob, _, _ in self.parts:
            r = DECIMATE.get(ob.get("rbpart"))
            if r and ob.get("rbpart") != "body":
                decimate(ob, r)
        hero_lib.bone_table = bone_table_lv2
        try:
            rig = hero_lib.make_rig(self.S, self.F, 1.0) if with_rig else None
        finally:
            hero_lib.bone_table = hero_lib._orig_bone_table
        self.face_lv2()
        byname = {ob.name[len(self.S) + 1:]: ob for ob, _, _ in self.parts}
        if rig is not None:
            for ob, mode, bone in self.parts:
                if mode == "single":
                    cl.bind_to_rig(ob, rig, single_bone=bone)
                elif mode == "dist":
                    hero_lib.geom_weights(ob, rig, self.F)
                    cl.smooth_weights(ob, 2, 0.5)
            for ob, mode, bone in self.parts:
                if mode == "torso":
                    hero_lib.geom_weights(ob, rig, self.F, only=("hips", "spine", "chest", "neck"))
                    cl.smooth_weights(ob, 1, 0.5)
            for ob, mode, bone in self.parts:
                if mode.startswith("xfer:"):
                    cl.transfer_weights(byname[mode[5:]], ob, rig)
            cl.bind_to_rig(self.face_ob, rig, single_bone="head")
        self.rig = rig
        self.objs = [o for o, _, _ in self.parts] + [self.face_ob]
        return rig, self.objs


def build(with_rig=True):
    b = LV2B()
    b.build_lv2(with_rig)
    return b
