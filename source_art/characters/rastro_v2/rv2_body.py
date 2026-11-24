"""Rastro v2 (RB-R1 D11/D13): geometria do heroi investigador. PROPOSTA PROVISORIA, lado a lado com o Rastro do jogo.

Toda geometria e gerada aqui do zero: grafo de pele (modificador SKIN) + SUBSURF para o traje inteirico, as luvas e as botas;
torno (lathe), tubos e bmesh para o equipamento; o rosto, a cabeca, o cabelo e o esqueleto de 28 ossos vem do Rastro atual
(source_art/scripts/hero_lib.py e hero_face.py), com ajuste de proporcao. Nada baixado, importado ou de terceiros.

Convencao: Blender Z-up, frente = +Y (vira -Z na Godot), direita do personagem (.R) = +X. Origem nos pes. Metros.
Cada parte registra um nome de PARTE (rbpart) usado pela pintura procedural das texturas (rv2_tex.py).
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
from rbart import mat, new_object

# ------------------------------------------------------------------ proporcao v2 (perto da A; pernas e tronco um pouco mais longos)
V2 = dict(head=0.390, leg=0.392, torso=0.272, belly=0.132, sh_x=0.130, limb=0.042, hand=1.34, boot=1.16, eye=1.10, layers=False,
          label="v2 heroi investigador")
hero_lib.VARIANTS["V2"] = V2
PAL = dict(pele="#C98B60", cabelo="#3A2419", iris="#8A5426", uniforme="#FF8A1F", creme="#FFF1D6", calca="#1F3A5F",
           botas="#1F3A5F", chapeu="#1F3A5F", couro="#1F3A5F", emblema="#123A5E", ouro="#FFC83D", olhos="#FFFFFF",
           escuro="#2A1A14", boca="#9C3341", rubor="#F08A7A", vidro="#9FE8FF")
hero_lib.CAST["rastro_v2"] = dict(display="Rastro", K=1.0, hat="none", hair="pigtails", gear=(), gloves=True, pal=PAL)

# Reducao de triangulos por parte (Decimate por colapso; preserva curvatura das dobras), antes do rig
DECIMATE = {"suit": 0.37, "glove": 0.50, "boot": 0.50, "hair": 0.30, "sole": 0.7, "belt": 0.5, "scanner_strap": 0.6,
            "pouch_strap": 0.7, "goggle_band": 0.7}


def decimate(ob, ratio):
    m = ob.modifiers.new("dec", "DECIMATE")
    m.decimate_type = "COLLAPSE"
    m.ratio = ratio
    m.use_collapse_triangulate = False
    hero_lib.bake(ob)


# Grupos de material final (cada grupo vira UM objeto, UMA atlas de textura)
GROUP_OF_PART = {}


def V(*a):
    return Vector(a)


def smooth(t, a, b):
    u = np.clip((t - a) / (b - a), 0.0, 1.0)
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


def normals_np(ob):
    ob.data.update()
    a = np.empty(len(ob.data.vertices) * 3)
    ob.data.vertices.foreach_get("normal", a)
    return a.reshape(-1, 3)


def tag(ob, part, group):
    """Marca a parte (atributo por vertice) e o grupo de material final."""
    GROUP_OF_PART[part] = group
    ob["rbpart"] = part
    ob["rbgroup"] = group
    return ob


def seg_frame(P, a, b):
    """Parametro u ao longo do segmento a->b, distancia radial e direcao radial unitaria para cada ponto."""
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
    """Vetores de referencia perpendiculares ao eixo: frente (+Y) e lado de fora (sx * X)."""
    fr = np.array([0.0, 1.0, 0.0]) - dn * dn[1]
    fr /= np.linalg.norm(fr)
    out = np.array([sx, 0.0, 0.0]) - dn * dn[0] * sx
    out = out - fr * (out @ fr)
    out /= max(np.linalg.norm(out), 1e-9)
    return fr, out


def rounded_lathe(bm, prof, seg=28, deform=None):
    cl.lathe(bm, prof, seg, deform)


class RV2(hero_lib.Builder):
    """Construtor do Rastro v2. Reusa cabeca, cabelo, rosto e rig do Builder do RB-R1; troca traje e equipamento."""

    def __init__(self):
        super().__init__("rastro_v2", "V2")
        self.S = "Rastro"
        GROUP_OF_PART.clear()

    # ------------------------------------------------------------ cabeca (reuso + marcacao)
    def hair_v2(self):
        """Cabelo do Rastro com as marias-chiquinhas soltas (caem e abrem para fora) em vez dos coques: silhueta mais viva."""
        F, k = self.F, self.F.k
        hc, hr = F.hc, F.hr
        E = [("ELLIPSOID", (hc.x, hc.y - 0.012 * k, hc.z + 0.020 * k), 1.0, (hr[0] * 1.04, hr[1] * 1.02, hr[2] * 1.0), False),
             ("ELLIPSOID", (hc.x, hc.y + hr[1] * 0.25, hc.z - 0.20 * k), 1.0, (hr[0] * 1.3, hr[1] * 0.75, 0.13 * k), True),
             ("ELLIPSOID", (0, hc.y - hr[1] * 0.55, hc.z - 0.07 * k), 1.0, (hr[0] * 0.86, 0.075 * k, 0.12 * k), False)]
        # franja curta em mechas arredondadas, varrida para o lado direito do personagem
        for bx, bz, bs in ((-0.085, 0.118, 0.050), (-0.030, 0.128, 0.052), (0.030, 0.124, 0.050), (0.082, 0.110, 0.044)):
            E.append(("ELLIPSOID", (bx * k, hc.y + hr[1] * 0.70, hc.z + bz * k), 1.0, (bs * k, 0.036 * k, 0.030 * k), False))
        self.tail_axes = []
        for sx in (1, -1):
            base = V(sx * (hr[0] * 0.86), hc.y - 0.070 * k, hc.z - 0.005 * k)
            pts = []
            for i in range(9):
                t = i / 8
                p = base + V(sx * (0.040 * k * t + 0.040 * k * t * t), -0.030 * k * t, -0.150 * k * t + 0.030 * k * t ** 3)
                r = (0.046 - 0.026 * t) * k
                E.append(("BALL", tuple(p), r, None, False))
                pts.append((p, r))
            self.tail_axes.append((sx, pts))
        # janela do rosto: elipsoide negativo que recorta a linha do cabelo de forma lisa (sem apagar vertices)
        E.append(("ELLIPSOID", (0, hc.y + hr[1] * 0.78, hc.z - 0.050 * k), 1.0, (hr[0] * 0.80, hr[1] * 0.55, 0.115 * k), True))
        ob = hero_lib.metaball_obj(self.name("Hair"), E, self.M["cabelo"], res=0.011 * k, thresh=0.6)
        bm = bmesh.new()
        bm.from_mesh(ob.data)
        for _ in range(3):
            bmesh.ops.smooth_vert(bm, verts=bm.verts[:], factor=0.5, use_axis_x=True, use_axis_y=True, use_axis_z=True)
        bm.to_mesh(ob.data)
        bm.free()
        self.hair_ob = ob
        self.reg(ob, "single", "head")
        return ob

    def head_parts(self):
        self.head()
        self.hair_v2()
        for ob, _, _ in self.parts:
            n = ob.name
            if n.endswith("_Head") or n.endswith("_Nose"):
                tag(ob, "skin_head", "skin")
            elif n.endswith("_Blush"):
                # o rubor passa a ser pintado na textura da pele (sem malha chapada por cima)
                pass
            elif n.endswith("_Hair"):
                tag(ob, "hair", "hair")
            elif n.endswith("_HairTies"):
                tag(ob, "hair_ties", "gear")
        keep = []
        for ob, mode, bone in self.parts:
            if ob.name.endswith("_Blush"):
                bpy.data.objects.remove(ob)
                continue
            keep.append((ob, mode, bone))
        self.parts = keep

    # ------------------------------------------------------------ traje inteirico (tronco + bracos + pernas num grafo so)
    def suit(self):
        F, v = self.F, self.v
        hz, nz = F.hz, F.nz
        nodes, edges = [], []

        def add(co, r, link=None):
            nodes.append((tuple(co), r))
            if link is not None:
                edges.append((link, len(nodes) - 1))
            return len(nodes) - 1

        b = v["belly"]
        crotch = add((0, -0.004, hz - 0.050), b * 0.80)
        pelvis = add((0, -0.004, hz + 0.020), b * 0.98, crotch)
        waist = add((0, 0.002, hz + 0.105), b * 0.93, pelvis)
        chest = add((0, 0.006, nz - 0.090), b * 1.00, waist)
        upper = add((0, 0.000, nz - 0.040), b * 0.86, chest)
        neck = add((0, 0.002, nz + 0.006), 0.056, upper)
        self.limb_segs = []
        for sx, s in ((1, "R"), (-1, "L")):
            sh = V(sx * F.sh.x, F.sh.y, F.sh.z)
            el = V(sx * F.elbow.x, F.elbow.y, F.elbow.z)
            W = V(sx * F.wrist.x, F.wrist.y, F.wrist.z)
            L = v["limb"]
            s0 = add(V(sx * F.sh.x * 0.62, 0.0, F.sh.z + 0.012), L * 1.30, upper)
            s1 = add(sh.lerp(el, 0.10), L * 1.22, s0)
            s2 = add(sh.lerp(el, 0.45), L * 1.08, s1)
            e0 = add(sh.lerp(el, 0.86), L * 0.98, s2)
            e1 = add(el.lerp(W, 0.12), L * 0.98, e0)
            f0 = add(el.lerp(W, 0.40), L * 1.02, e1)
            w0 = add(el.lerp(W, 0.86), L * 0.84, f0)
            hx = sx * F.hip_x
            kz = F.knee_z
            h0 = add((hx, -0.002, hz - 0.060), 0.074, crotch)
            t1 = add((hx, 0.002, hz - (hz - kz) * 0.45), 0.068, h0)
            k0 = add((hx, 0.006, kz + 0.022), 0.058, t1)
            k1 = add((hx, 0.004, kz - 0.020), 0.056, k0)
            c0 = add((hx, -0.004, kz - 0.070), 0.058, k1)
            a0 = add((hx, -0.002, F.ankle_z + 0.075), 0.051, c0)
            a1 = add((hx, -0.002, F.ankle_z + 0.030), 0.050, a0)
            self.limb_segs += [("upper_arm", s, sh, el), ("forearm", s, el, W), ("thigh", s, V(hx, 0, hz - 0.03), V(hx, 0.006, kz)),
                               ("shin", s, V(hx, 0.006, kz), V(hx, 0, F.ankle_z))]
        ob = cl.skin_obj(self.name("Suit"), nodes, edges, self.M["uniforme"], levels=3, branch=1.0)
        self.shape_suit(ob)
        tag(ob, "suit", "suit")
        self.suit_ob = ob
        self.reg(ob, "dist")
        return ob

    def shape_suit(self, ob):
        """Forma das articulacoes e dobras modeladas (ombro, cotovelo, quadril, joelho, barra), em metros, por vertice."""
        F, v = self.F, self.v
        hz, nz = F.hz, F.nz
        P = verts_np(ob)
        # pertinencia ao tronco x membros (pesos suaves pela distancia normalizada)
        torso_a, torso_b = np.array([0, 0, hz - 0.06]), np.array([0, 0, nz + 0.02])
        segs = [("torso", 0, torso_a, torso_b, v["belly"])]
        for kind, s, a, b in self.limb_segs:
            r = {"upper_arm": 0.050, "forearm": 0.042, "thigh": 0.070, "shin": 0.056}[kind]
            segs.append((kind, 1 if s == "R" else -1, np.array(a), np.array(b), r))
        D = []
        for kind, sx, a, b, r in segs:
            u, rr, rn, dn, L = seg_frame(P, a, b)
            uu = np.clip(u, 0, 1)
            dist = np.linalg.norm(P - (a + np.outer(uu, b - a)), axis=1)
            D.append(1.0 / ((dist / r) ** 8 + 1e-6))
        D = np.array(D)
        Wt = D / D.sum(axis=0)
        disp = np.zeros(len(P))
        dirs = np.zeros_like(P)
        out = P.copy()
        # tronco: profundidade menor, peito, barriga de crianca, costas retas, gluteo
        w = Wt[0]
        z = P[:, 2]
        depth = 0.86 - 0.04 * smooth(z, hz + 0.05, nz - 0.05)
        out[:, 1] = P[:, 1] * (1 - w) + P[:, 1] * depth * w
        front = np.clip(P[:, 1] / 0.12, -1, 1)
        add_t = (0.010 * bump(z, nz - 0.095, 0.045) * np.clip(front, 0, 1) ** 1.5         # peito
                 + 0.008 * bump(z, hz + 0.065, 0.045) * np.clip(front, 0, 1) ** 2          # barriga
                 + 0.012 * bump(z, hz - 0.030, 0.040) * np.clip(-front, 0, 1) ** 1.5)      # gluteo
        side = np.clip(np.abs(P[:, 0]) / 0.13, 0, 1)
        add_t += 0.006 * bump(z, hz + 0.0, 0.05) * side ** 2                                 # quadril
        add_t -= 0.006 * bump(z, hz + 0.12, 0.04) * side ** 2                                # cintura
        rad = P.copy()
        rad[:, 2] = 0
        rn = rad / np.maximum(np.linalg.norm(rad, axis=1)[:, None], 1e-9)
        out += rn * (add_t * w)[:, None]
        # membros
        for i, (kind, sx, a, b, r) in enumerate(segs[1:], start=1):
            w = Wt[i]
            u, rr, rnv, dn, L = seg_frame(P, a, b)
            fr, ou = ref_dirs(dn, sx)
            fdot = rnv @ fr
            odot = rnv @ ou
            s_along = u * L
            d = np.zeros(len(P))
            if kind == "upper_arm":
                d += 0.009 * bump(u, 0.16, 0.16) * np.clip(0.35 + 0.65 * odot, 0, 1)      # deltoide
                d += 0.004 * bump(u, 0.55, 0.20) * np.clip(fdot, 0, 1)                    # biceps
                # dobras no lado de dentro do cotovelo (frente)
                d += 0.0028 * np.sin(2 * np.pi * (L - s_along) / 0.016) ** 2 * bump(u, 0.94, 0.08) * np.clip(fdot, 0, 1) ** 2
            elif kind == "forearm":
                d += 0.005 * bump(u, 0.00, 0.07) * np.clip(-fdot, 0, 1) ** 2               # ponta do cotovelo
                d += 0.0040 * bump(u, 0.30, 0.22) * np.clip(0.5 + 0.5 * odot, 0, 1)
                d += 0.0028 * np.sin(2 * np.pi * s_along / 0.016) ** 2 * bump(u, 0.06, 0.08) * np.clip(fdot, 0, 1) ** 2
                # barra da manga franzida (some dentro da luva, aparece acima do punho)
                d += 0.0030 * (0.5 + 0.5 * np.sin(2 * np.pi * s_along / 0.013 + 1.4 * np.sin(3 * np.arctan2(odot, fdot)))) * bump(u, 0.80, 0.07)
            elif kind == "thigh":
                d += 0.006 * bump(u, 0.40, 0.28) * np.clip(fdot, 0, 1) ** 1.5                # quadriceps
                d += 0.005 * bump(u, 0.10, 0.18) * np.clip(odot, 0, 1)                       # quadril de fora
                d += 0.0030 * np.sin(2 * np.pi * (L - s_along) / 0.018) ** 2 * bump(u, 0.96, 0.07) * np.clip(-fdot, 0, 1) ** 2
            elif kind == "shin":
                d += 0.011 * bump(u, 0.02, 0.10) * np.clip(fdot, 0, 1) ** 1.6                # joelho
                d += 0.009 * bump(u, 0.36, 0.20) * np.clip(-fdot, 0, 1) ** 1.2               # panturrilha
                d += 0.0030 * np.sin(2 * np.pi * s_along / 0.018) ** 2 * bump(u, 0.03, 0.07) * np.clip(-fdot, 0, 1) ** 2
                # barra: dobras sanfonadas acima da bota
                zz = P[:, 2]
                ang = np.arctan2(odot, fdot)
                d += 0.0045 * (0.5 + 0.5 * np.sin(2 * np.pi * (zz - F.ankle_z) / 0.020 + 1.2 * np.sin(2 * ang + 0.7))) * \
                    smooth(zz, F.ankle_z + 0.075, F.ankle_z + 0.095) * (1 - smooth(zz, F.ankle_z + 0.15, F.ankle_z + 0.18))
            out += rnv * (d * w)[:, None]
        set_verts(ob, out)
        # suavizacao leve nas juncoes (axilas, virilha) para nao ficar vinco do SKIN
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

    # ------------------------------------------------------------ gola em pe (emoldura o rosto), mais alta atras, entalhe na frente
    def collar(self):
        F = self.F
        nz = F.nz
        bm = bmesh.new()
        rows = []
        nu, nv = 36, 3
        for i in range(nu + 1):
            a = math.radians(24 + (360 - 48) * i / nu)      # 0 = frente (+Y); abre +-24 graus na frente
            back = 0.5 - 0.5 * math.cos(a)
            ring = []
            for j in range(nv + 1):
                t = j / nv
                h = (0.030 + 0.020 * back) * t
                r = 0.058 + 0.004 * back + (0.008 + 0.010 * back) * t ** 1.4
                z = nz - 0.006 + h
                ring.append(bm.verts.new((r * math.sin(a) * 1.06, r * math.cos(a) * 0.98 + 0.004, z)))
            rows.append(ring)
        for i in range(nu):
            for j in range(nv):
                bm.faces.new((rows[i][j], rows[i + 1][j], rows[i + 1][j + 1], rows[i][j + 1]))
        ob = new_object(self.name("Collar"), bm, self.M["creme"], recalc=False)
        sol = ob.modifiers.new("sol", "SOLIDIFY")
        sol.thickness = 0.007
        sol.offset = 1.0
        hero_lib.bake(ob)
        tag(ob, "collar", "suit")
        self.reg(ob, "torso")

    # ------------------------------------------------------------ luvas (4 dedos: polegar + 3), palma achatada, punho largo
    def gloves(self):
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
            w0 = add(W - d * 0.030 * k, 0.026 * k)
            w1 = add(W + d * 0.004 * k, 0.027 * k, w0)
            palm = add(W + d * 0.036 * k, 0.031 * k, w1)
            # polegar: sai da lateral da palma, aponta para a frente e para dentro
            t0 = add(W + d * 0.020 * k + f * 0.024 * k + n * 0.010 * k, 0.0150 * k, w1)
            t1 = add(W + d * 0.040 * k + f * 0.044 * k + n * 0.018 * k, 0.0138 * k, t0)
            add(W + d * 0.058 * k + f * 0.052 * k + n * 0.024 * k, 0.0128 * k, t1)
            tips = []
            for off, ln, spread in ((0.0175, 0.046, 0.30), (-0.0005, 0.052, 0.0), (-0.0185, 0.044, -0.34)):
                base = add(W + d * 0.058 * k + f * off * k, 0.0148 * k, palm)
                fd = (d + f * spread * 0.35).normalized()
                mid = add(W + d * 0.058 * k + f * off * k + fd * ln * 0.55 * k + n * 0.006 * k, 0.0140 * k, base)
                tips.append(add(W + d * 0.058 * k + f * off * k + fd * ln * k + n * 0.016 * k, 0.0128 * k, mid))
            ob = cl.skin_obj(self.name("Glove" + sd), nn, ee, self.M["creme"], levels=2, branch=0.6)
            # achata a palma no eixo da normal da mao (mao, nao bola), alarga um pouco no eixo dos dedos
            P = verts_np(ob)
            Wn = np.array(W)
            loc = P - Wn
            dd, ff, nnv = np.array(d), np.array(f), np.array(n)
            ad, af, an = loc @ dd, loc @ ff, loc @ nnv
            palm_w = np.exp(-((ad - 0.030 * k) / (0.034 * k)) ** 2) * (1 - smooth(np.abs(af), 0.024 * k, 0.040 * k) * 0.0)
            thumb = (af > 0.018 * k) & (an > 0.004 * k) & (ad < 0.05 * k)
            sq = 1 - 0.30 * palm_w * (~thumb)
            an2 = an * sq
            af2 = af * (1 + 0.08 * palm_w * (~thumb))
            P2 = Wn + np.outer(ad, dd) + np.outer(af2, ff) + np.outer(an2, nnv)
            set_verts(ob, P2)
            tag(ob, "glove", "gear")
            # luva rigida no osso da mao: peso por distancia torcia o pulso e achatava a mao com o braco erguido
            self.reg(ob, "single", "hand." + sd)
            # punho largo (cano da luva) cobrindo o fim da manga
            el = V(sx * F.elbow.x, F.elbow.y, F.elbow.z)
            ax = (V(*W) - el).normalized()
            c = V(*W) - ax * 0.020
            bm = bmesh.new()
            prof = [(0.0, 0.034), (0.046, 0.034), (0.052, 0.030), (0.054, 0.024), (0.047, 0.004), (0.036, -0.012), (0.033, -0.016), (0.0, -0.016)]
            cl.lathe(bm, [(r * 1.0, z) for r, z in prof], 28)
            q = ax.to_track_quat("Z", "Y").to_matrix().to_4x4()
            cl.transform_bm(bm, Matrix.Translation(c) @ q @ Matrix.Diagonal((1.0, 0.92, 1.0, 1.0)))
            cuff = new_object(self.name("GloveCuff" + sd), bm, self.M["uniforme"])
            tag(cuff, "glove_cuff", "gear")
            self.reg(cuff, "single", "forearm." + sd)

    # ------------------------------------------------------------ botas grandes e redondas
    def boots(self):
        F, v = self.F, self.v
        bk = v["boot"]
        for sx, sd in ((1, "R"), (-1, "L")):
            x = sx * F.hip_x
            nn = [((x, -0.006, F.ankle_z + 0.090 * bk), 0.056 * bk), ((x, -0.010, F.ankle_z + 0.010), 0.064 * bk),
                  ((x, F.ball_y * 0.70, 0.052 * bk), 0.066 * bk), ((x + sx * 0.004, F.toe_y - 0.046 * bk, 0.052 * bk), 0.062 * bk)]
            boot = cl.skin_obj(self.name("Boot" + sd), nn, [(0, 1), (1, 2), (2, 3)], self.M["botas"], levels=3, floor=0.026 * bk)
            P = verts_np(boot)
            # bico mais largo e redondo, calcanhar arredondado
            yrel = (P[:, 1] - F.heel_y) / (F.toe_y - F.heel_y)
            P[:, 0] = x + (P[:, 0] - x) * (1.0 + 0.10 * smooth(yrel, 0.45, 0.95))
            P[:, 2] = np.where(P[:, 2] > 0.03, P[:, 2] + 0.006 * bump(yrel, 0.85, 0.15) * (P[:, 2] > 0.06), P[:, 2])
            set_verts(boot, P)
            # boca da bota aberta (o traje entra nela) e aro no corte
            z_top = float(P[:, 2].max()) - 0.010      # o SKIN termina a bota um pouco abaixo do no de cima: corta 1 cm abaixo do topo
            bm = bmesh.new()
            bm.from_mesh(boot.data)
            hero_lib.bisect_keep(bm, (0, 0, z_top), (0, 0, 1), keep_above=False)
            rim = [vv.co.copy() for vv in bm.verts if abs(vv.co.z - z_top) < 1e-4]
            bm.to_mesh(boot.data)
            bm.free()
            assert len(rim) > 8, "corte da boca da bota nao achou o aro"
            rc = sum(rim, Vector()) / max(len(rim), 1)
            rr = sum(((p - rc).xy.length for p in rim), 0.0) / max(len(rim), 1)
            self.boot_rim = (rc, rr, z_top)
            tag(boot, "boot", "gear")
            self.reg(boot, "dist")
            # sola clara ajustada a pegada da bota (contorno medido da propria bota, +5 mm), 2,4 cm de altura
            BP = verts_np(boot)
            low = BP[BP[:, 2] < 0.07]
            ang_c = np.arctan2(low[:, 1] - low[:, 1].mean(), low[:, 0] - x)
            cxy = np.array([x, low[:, 1].mean()])
            bm = bmesh.new()
            n_ = 32
            prof = []
            for i in range(n_):
                a = 2 * math.pi * i / n_
                d = np.array([math.cos(a), math.sin(a)])
                proj = (low[:, :2] - cxy) @ d
                prof.append(cxy + d * (proj.max() + 0.005))
            rows = []
            for zz, grow in ((0.0, -0.004), (0.005, 0.0), (0.020, 0.0), (0.026, -0.003)):
                row = []
                for pxy in prof:
                    dv = pxy - cxy
                    dv = dv / max(np.linalg.norm(dv), 1e-9)
                    q = pxy + dv * grow
                    row.append(bm.verts.new((q[0], q[1], zz)))
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
            # cano: aro creme na boca da bota
            bm = bmesh.new()
            rc, rr, z_top = self.boot_rim
            cl.torus_z(bm, rr - 0.002, 0.0090, z_top + 0.002, sy=0.97, major=22, minor=6)
            cl.transform_bm(bm, Matrix.Translation((rc.x, rc.y, 0)))
            top = new_object(self.name("BootTop" + sd), bm, self.M["creme"])
            tag(top, "boot_top", "gear")
            self.reg(top, "dist")

    # ------------------------------------------------------------ cinto de equipe + fivela-bussola + emblema
    def team(self):
        F, v = self.F, self.v
        hz, nz = F.hz, F.nz
        suit = self.suit_ob
        bvh = BVHTree.FromObject(suit, bpy.context.evaluated_depsgraph_get())

        def ring_at(z, off):
            pts = []
            for i in range(48):
                a = 2 * math.pi * i / 48
                dr = V(math.sin(a), math.cos(a), 0)
                hit = bvh.ray_cast(V(0, 0, z) + dr * 0.5, -dr)[0]
                pts.append((hit if hit else V(0, 0, z) + dr * 0.12) + dr * off)
            return pts
        bz = hz + 0.030
        bm = bmesh.new()
        # cinto: faixa de secao retangular arredondada seguindo a cintura
        prof = [(-0.020, 0.000), (-0.018, 0.009), (0.018, 0.009), (0.020, 0.000)]
        ring = ring_at(bz, 0.002)
        rows = []
        for p in ring:
            dr = V(p.x, p.y, 0).normalized()
            rows.append([bm.verts.new(p + dr * o + V(0, 0, dz)) for dz, o in prof])
        for i in range(48):
            j = (i + 1) % 48
            for k in range(3):
                bm.faces.new((rows[i][k], rows[j][k], rows[j][k + 1], rows[i][k + 1]))
        belt = new_object(self.name("Belt"), bm, self.M["couro"], recalc=True)
        sub = belt.modifiers.new("sub", "SUBSURF")
        sub.levels = 1
        hero_lib.bake(belt)
        tag(belt, "belt", "gear")
        self.reg(belt, "torso")
        self.belt_z = bz
        # fivela redonda (bussola de equipe)
        by = (cl.snap_y(suit, 0.0, bz) or 0.11) + 0.010
        bm = bmesh.new()
        cl.lathe(bm, [(0.0, 0.012), (0.026, 0.012), (0.032, 0.008), (0.033, 0.0), (0.0, 0.0)], 32)
        cl.transform_bm(bm, Matrix.Translation((0, by - 0.003, bz)) @ cl.Matrix.Rotation(math.radians(-90), 4, "X"))
        buckle = new_object(self.name("Buckle"), bm, self.M["ouro"])
        tag(buckle, "buckle", "gear")
        self.reg(buckle, "single", "hips")
        bm = bmesh.new()
        hero_lib.prism(bm, hero_lib.star4(0.022, 0.007), 0.004, (0, by + 0.008, bz))
        bmesh.ops.bevel(bm, geom=bm.edges[:], offset=0.0010, segments=1, affect="EDGES")
        st = new_object(self.name("BuckleStar"), bm, self.M["emblema"])
        tag(st, "buckle_star", "gear")
        self.reg(st, "single", "hips")
        # EMBLEMA grande no centro do peito: escudo-gota azul-marinho, rosa dos ventos amarela, faixa branca
        ez = nz - 0.095
        ey = (cl.snap_y(suit, 0.0, ez) or 0.11)
        T = Matrix.Translation((0, ey - 0.003, ez)) @ V(0, 1.0, 0.18).normalized().to_track_quat("Y", "Z").to_matrix().to_4x4()
        w, h = 0.105, 0.115
        bm = bmesh.new()
        hero_lib.prism(bm, hero_lib.emblem_outline(w, h, 40), 0.008, (0, 0, 0))
        bmesh.ops.bevel(bm, geom=[e for e in bm.edges if len(e.link_faces) == 2 and e.calc_face_angle(0) > 0.6], offset=0.0025, segments=3, affect="EDGES")
        cl.transform_bm(bm, T)
        self.emblem_ob = tag(new_object(self.name("Emblem"), bm, self.M["emblema"]), "emblem", "gear")
        self.reg(self.emblem_ob, "torso")
        bm = bmesh.new()
        hero_lib.prism(bm, hero_lib.star4(0.034, 0.011), 0.005, (0, 0.008, 0.010))
        bmesh.ops.bevel(bm, geom=bm.edges[:], offset=0.0012, segments=1, affect="EDGES")
        cl.transform_bm(bm, T)
        self.reg(tag(new_object(self.name("EmblemStar"), bm, self.M["ouro"]), "emblem_star", "gear"), "torso")
        bm = bmesh.new()
        band = []
        for i in range(13):
            t = (i / 12) * 2 - 1
            band.append((t * w * 0.38, -0.030 + 0.010 * t * t))
        for i in range(12, -1, -1):
            t = (i / 12) * 2 - 1
            band.append((t * w * 0.38, -0.040 + 0.010 * t * t))
        hero_lib.prism(bm, band, 0.004, (0, 0.008, 0))
        cl.transform_bm(bm, T)
        self.reg(tag(new_object(self.name("EmblemBand"), bm, self.M["creme"]), "emblem_band", "gear"), "torso")

    # ------------------------------------------------------------ equipamento de investigador
    def gear_v2(self):
        F, v = self.F, self.v
        hz, nz = F.hz, F.nz
        suit = self.suit_ob
        b = v["belly"]
        bz = self.belt_z
        # --- scanner de pulso no antebraco esquerdo (caixa arredondada + tela + lente)
        el = V(-F.elbow.x, F.elbow.y, F.elbow.z)
        W = V(-F.wrist.x, F.wrist.y, F.wrist.z)
        ax = (W - el).normalized()
        c = el.lerp(W, 0.50)
        q = ax.to_track_quat("Z", "Y").to_matrix().to_4x4()
        # lado de fora do antebraco esquerdo
        outv = V(-1.0, 0.25, 0.0)
        outv = (outv - ax * outv.dot(ax)).normalized()
        L = v["limb"]
        bm = bmesh.new()
        cl.torus_z(bm, L * 1.02, 0.009, 0.0, major=28, minor=6)
        cl.transform_bm(bm, Matrix.Translation(c - ax * 0.024) @ q)
        tb = bmesh.new()
        cl.torus_z(tb, L * 1.00, 0.009, 0.0, major=28, minor=6)
        cl.transform_bm(tb, Matrix.Translation(c + ax * 0.026) @ q)
        hero_lib.join_bm(bm, tb)
        strap = new_object(self.name("ScannerStrap"), bm, self.M["couro"])
        tag(strap, "scanner_strap", "gear")
        self.reg(strap, "single", "forearm.L")
        side = ax.cross(outv).normalized()
        frame = Matrix((side, ax, outv)).transposed().to_4x4()
        P0 = c + outv * (L * 1.02 + 0.010)
        bm = bmesh.new()
        cl.rounded_box(bm, (0, 0, 0), (0.060, 0.080, 0.026), 0.010)
        cl.transform_bm(bm, Matrix.Translation(P0) @ frame)
        tb = bmesh.new()
        cl.lathe(tb, [(0.0, 0.010), (0.010, 0.010), (0.012, 0.006), (0.012, 0.0), (0.0, 0.0)], 18)
        cl.transform_bm(tb, Matrix.Translation(P0 + ax * 0.044 + outv * 0.002) @ Matrix((side, -outv, ax)).transposed().to_4x4())
        hero_lib.join_bm(bm, tb)
        sc_body = new_object(self.name("Scanner"), bm, self.M["couro"])
        tag(sc_body, "scanner", "gear")
        self.reg(sc_body, "single", "forearm.L")
        bm = bmesh.new()
        cl.rounded_box(bm, (0, -0.008, 0.0118), (0.042, 0.048, 0.004), 0.0018)
        cl.transform_bm(bm, Matrix.Translation(P0) @ frame)
        scr = new_object(self.name("ScannerScreen"), bm, self.M["vidro"])
        tag(scr, "screen", "screen")
        self.reg(scr, "single", "forearm.L")
        # --- lupa no coldre do quadril direito (aro dourado grande, cabo azul)
        lx = b * 0.98 + 0.012
        cz = bz - 0.090
        bm = bmesh.new()
        cl.torus_z(bm, 0.036, 0.0070, 0.0, major=26, minor=6)
        cl.transform_bm(bm, Matrix.Translation((lx + 0.012, 0.030, cz)) @ cl.rot_y(90) @ cl.Matrix.Rotation(math.radians(12), 4, "X"))
        ring = new_object(self.name("Lupa"), bm, self.M["ouro"])
        tag(ring, "lupa_ring", "gear")
        self.reg(ring, "single", "hips")
        bm = bmesh.new()
        cl.tube(bm, [(lx + 0.012, 0.030 - 0.007, cz + 0.040), (lx + 0.010, 0.030 - 0.012, cz + 0.080)], [0.0095, 0.0085], 12, True)
        cl.ellipsoid(bm, (lx + 0.010, 0.030 - 0.012, cz + 0.084), (0.011, 0.011, 0.010), 12, 6)
        handle = new_object(self.name("LupaHandle"), bm, self.M["couro"])
        tag(handle, "lupa_handle", "gear")
        self.reg(handle, "single", "hips")
        bm = bmesh.new()
        cl.ellipsoid(bm, (0, 0, 0), (0.0045, 0.032, 0.032), 16, 8)
        cl.transform_bm(bm, Matrix.Translation((lx + 0.012, 0.030, cz)) @ cl.Matrix.Rotation(math.radians(12), 4, "X"))
        glass = new_object(self.name("LupaGlass"), bm, self.M["vidro"])
        tag(glass, "lupa_glass", "glass")
        self.reg(glass, "single", "hips")
        # coldre: alca do cinto que segura o cabo
        bm = bmesh.new()
        cl.rounded_box(bm, (lx + 0.003, 0.018, bz - 0.020), (0.020, 0.036, 0.046), 0.006)
        hol = new_object(self.name("Holster"), bm, self.M["couro"])
        tag(hol, "holster", "gear")
        self.reg(hol, "single", "hips")
        # --- caderno de pistas na bolsa da coxa esquerda
        tz = F.hz - 0.085
        tx = -F.hip_x - 0.060
        bvh = BVHTree.FromObject(suit, bpy.context.evaluated_depsgraph_get())
        hit = bvh.ray_cast(V(-0.5, 0.010, tz), V(1, 0, 0))[0]
        sx_ = hit.x if hit else tx
        bm = bmesh.new()
        cl.rounded_box(bm, (sx_ - 0.016, 0.010, tz), (0.034, 0.088, 0.096), 0.012)
        pouch = new_object(self.name("Pouch"), bm, self.M["couro"])
        tag(pouch, "pouch", "gear")
        self.reg(pouch, "xfer:Suit")
        bm = bmesh.new()
        cl.rounded_box(bm, (sx_ - 0.016, 0.010, tz + 0.058), (0.026, 0.072, 0.040), 0.005)
        nb = new_object(self.name("Notebook"), bm, self.M["uniforme"])
        tag(nb, "notebook", "gear")
        self.reg(nb, "xfer:Suit")
        bm = bmesh.new()
        prism_star = hero_lib.star4(0.012, 0.004)
        hero_lib.prism(bm, prism_star, 0.003, (0, 0, 0))
        cl.transform_bm(bm, Matrix.Translation((sx_ - 0.034, 0.010, tz + 0.004)) @ cl.Matrix.Rotation(math.radians(-90), 4, "Z"))
        nst = new_object(self.name("PouchStar"), bm, self.M["ouro"])
        tag(nst, "pouch_star", "gear")
        self.reg(nst, "xfer:Suit")
        # tiras da bolsa em volta da coxa
        bm = bmesh.new()
        for dz in (0.030, -0.034):
            pts = []
            for i in range(25):
                a = 2 * math.pi * i / 24
                pts.append((-F.hip_x + math.cos(a) * 0.075, 0.004 + math.sin(a) * 0.071, tz + dz))
            cl.tube(bm, pts, 0.0055, 5, False)
        straps = new_object(self.name("PouchStraps"), bm, self.M["couro"])
        tag(straps, "pouch_strap", "gear")
        self.reg(straps, "xfer:Suit")

    # ------------------------------------------------------------ oculos-visor erguido na testa (sem cobrir os olhos)
    def visor(self):
        F, k = self.F, self.F.k
        hc, hr = F.hc, F.hr
        tilt = math.radians(-24)
        cz = hc.z + 0.092 * k
        cy = hc.y - 0.006 * k
        m = Matrix.Translation((0, cy, cz)) @ cl.Matrix.Rotation(tilt, 4, "X")
        Rx, Ry = hr[0] * 1.02, hr[1] * 1.04
        # faixa (elastico) em volta da cabeca
        bm = bmesh.new()
        rows = []
        for i in range(48):
            a = 2 * math.pi * i / 48
            row = []
            for dz, dr in ((-0.013, 0.000), (-0.011, 0.006), (0.011, 0.006), (0.013, 0.000)):
                rr = 1.0 + dr / Rx
                row.append(bm.verts.new((math.sin(a) * Rx * rr, math.cos(a) * Ry * rr, dz)))
            rows.append(row)
        for i in range(48):
            j = (i + 1) % 48
            for q in range(3):
                bm.faces.new((rows[i][q], rows[j][q], rows[j][q + 1], rows[i][q + 1]))
        cl.transform_bm(bm, m)
        band = new_object(self.name("VisorBand"), bm, self.M["couro"])
        tag(band, "visor_band", "gear")
        self.reg(band, "single", "head")
        # aro do visor: arco frontal largo
        bm = bmesh.new()
        rows = []
        nu = 26
        for i in range(nu + 1):
            a = math.radians(-78 + 156 * i / nu)
            row = []
            for dz, dr in ((-0.026, 0.010), (-0.022, 0.020), (0.026, 0.020), (0.030, 0.010)):
                hh = 1.0 - 0.15 * (abs(math.degrees(a)) / 78) ** 2
                row.append(bm.verts.new((math.sin(a) * (Rx + dr), math.cos(a) * (Ry + dr), dz * hh)))
            rows.append(row)
        for i in range(nu):
            for q in range(3):
                bm.faces.new((rows[i][q], rows[i + 1][q], rows[i + 1][q + 1], rows[i][q + 1]))
        for end in (0, nu):
            bm.faces.new(rows[end] if end == 0 else list(reversed(rows[end])))
        cl.transform_bm(bm, m)
        fr = new_object(self.name("VisorFrame"), bm, self.M["couro"])
        sub = fr.modifiers.new("sub", "SUBSURF")
        sub.levels = 1
        hero_lib.bake(fr)
        tag(fr, "visor_frame", "gear")
        self.reg(fr, "single", "head")
        # lente: casca fina por dentro do aro
        bm = bmesh.new()
        rows = []
        for i in range(nu + 1):
            a = math.radians(-72 + 144 * i / nu)
            row = []
            for dz in (-0.019, 0.0, 0.021):
                hh = 1.0 - 0.15 * (abs(math.degrees(a)) / 78) ** 2
                row.append(bm.verts.new((math.sin(a) * (Rx + 0.022), math.cos(a) * (Ry + 0.024) + 0.002 * (1 - abs(dz) / 0.02), dz * hh)))
            rows.append(row)
        for i in range(nu):
            for q in range(2):
                bm.faces.new((rows[i][q], rows[i + 1][q], rows[i + 1][q + 1], rows[i][q + 1]))
        cl.transform_bm(bm, m)
        lens = new_object(self.name("VisorLens"), bm, self.M["vidro"], recalc=False)
        sol = lens.modifiers.new("sol", "SOLIDIFY")
        sol.thickness = 0.003
        hero_lib.bake(lens)
        tag(lens, "visor_lens", "glass")
        self.reg(lens, "single", "head")
        # pivos dourados nas laterais (onde o visor gira) com pequeno disco azul
        bm = bmesh.new()
        for sx in (1, -1):
            a = math.radians(sx * 82)
            pc = Vector((math.sin(a) * (Rx + 0.010), math.cos(a) * (Ry + 0.010), 0.0))
            tb = bmesh.new()
            cl.lathe(tb, [(0.0, 0.010), (0.019, 0.010), (0.023, 0.006), (0.023, 0.0), (0.0, 0.0)], 24)
            out = Vector((math.sin(a), math.cos(a), 0)).normalized()
            cl.transform_bm(tb, Matrix.Translation(pc) @ out.to_track_quat("Z", "Y").to_matrix().to_4x4())
            hero_lib.join_bm(bm, tb)
        cl.transform_bm(bm, m)
        piv = new_object(self.name("VisorPivots"), bm, self.M["ouro"])
        tag(piv, "visor_pivot", "gear")
        self.reg(piv, "single", "head")

    # ------------------------------------------------------------ oculos-lupa erguidos no alto da cabeca (assinatura do investigador)
    def goggles(self):
        """Faixa inclinada sobre o cabelo e dois oculos redondos de lente-lupa apoiados no alto da cabeca, acima da franja.
        Nao cobrem os olhos; dao silhueta de heroi de frente, de lado e de costas."""
        F, k = self.F, self.F.k
        hc, hr = F.hc, F.hr
        dg = bpy.context.evaluated_depsgraph_get()
        bvhs = [BVHTree.FromObject(o, dg) for o in (self.head_ob, self.hair_ob)]

        def surf(origin, dirv):
            best = None
            for bv in bvhs:
                h = bv.ray_cast(origin, dirv)
                if h[0] is not None and (best is None or h[3] < best[3]):
                    best = h
            return best
        # plano da faixa: passa pelo alto da testa (na frente) e pela nuca (atras)
        tilt = math.radians(48)
        ctr = V(0, hc.y - 0.020 * k, hc.z + 0.030 * k)
        Rm = cl.Matrix.Rotation(tilt, 4, "X")
        n_ = 56
        band_pts = []
        for i in range(n_):
            a = 2 * math.pi * i / n_
            dl = Rm @ V(math.sin(a), math.cos(a), 0.0)
            h = surf(ctr + dl * 0.6, -dl)
            p = h[0] if h else ctr + dl * hr[0]
            band_pts.append((p, (h[1] if h else dl).normalized()))
        bm = bmesh.new()
        rows = []
        up = (Rm @ V(0, 0, 1)).normalized()
        for p, nrm in band_pts:
            side = up
            rows.append([bm.verts.new(p + nrm * o + side * dz) for dz, o in ((-0.015, 0.000), (-0.012, 0.007), (0.012, 0.007), (0.015, 0.000))])
        for i in range(n_):
            j = (i + 1) % n_
            for q in range(3):
                bm.faces.new((rows[i][q], rows[j][q], rows[j][q + 1], rows[i][q + 1]))
        band = new_object(self.name("GoggleBand"), bm, self.M["couro"])
        tag(band, "goggle_band", "gear")
        self.reg(band, "single", "head")
        # dois oculos: copo azul-marinho, aro dourado, lente ciano; ponte entre eles
        bm_cup, bm_rim, bm_lens = bmesh.new(), bmesh.new(), bmesh.new()
        centers = []
        for sx in (1, -1):
            a = sx * math.radians(30)
            dl = Rm @ V(math.sin(a), math.cos(a), 0.0)
            h = surf(ctr + dl * 0.6, -dl)
            p, nrm = (h[0], h[1].normalized()) if h else (ctr + dl * hr[0], dl)
            # a lente olha para a frente e para cima (oculos erguidos)
            look = (nrm * 0.55 + V(0, 0.75, 0.55).normalized() * 0.45).normalized()
            q = look.to_track_quat("Z", "Y").to_matrix().to_4x4()
            T = Matrix.Translation(p + nrm * 0.004) @ q
            centers.append((T, look, p))
            tb = bmesh.new()
            cl.lathe(tb, [(0.0, 0.030), (0.040, 0.030), (0.044, 0.024), (0.046, 0.010), (0.044, 0.0), (0.034, -0.004), (0.0, -0.004)], 20)
            cl.transform_bm(tb, T)
            hero_lib.join_bm(bm_cup, tb)
            tb = bmesh.new()
            cl.torus_z(tb, 0.042, 0.0075, 0.033, major=22, minor=6)
            cl.transform_bm(tb, T)
            hero_lib.join_bm(bm_rim, tb)
            tb = bmesh.new()
            cl.ellipsoid(tb, (0, 0, 0.031), (0.037, 0.037, 0.010), 14, 6)
            cl.transform_bm(tb, T)
            hero_lib.join_bm(bm_lens, tb)
        # ponte entre as lentes
        (T0, l0, p0), (T1, l1, p1) = centers
        a0 = T0 @ V(-0.040, 0, 0.022)
        a1 = T1 @ V(0.040, 0, 0.022)
        mid = (a0 + a1) * 0.5 + (l0 + l1).normalized() * 0.006
        cl.tube(bm_cup, [a0, mid, a1], 0.0085, 10, True)
        cup = new_object(self.name("GoggleCups"), bm_cup, self.M["couro"])
        tag(cup, "goggle_cup", "gear")
        self.reg(cup, "single", "head")
        rim = new_object(self.name("GoggleRims"), bm_rim, self.M["ouro"])
        tag(rim, "goggle_rim", "gear")
        self.reg(rim, "single", "head")
        lens = new_object(self.name("GoggleLens"), bm_lens, self.M["vidro"])
        tag(lens, "goggle_lens", "glass")
        self.reg(lens, "single", "head")

    # ------------------------------------------------------------ pescoco (pele)
    def neck(self):
        F = self.F
        nodes = [((0, 0.004, F.nz - 0.03), 0.040), ((0, 0.006, F.chin + 0.04), 0.037)]
        ob = cl.skin_obj(self.name("Neck"), nodes, [(0, 1)], self.M["pele"], levels=2)
        tag(ob, "skin_neck", "skin")
        self.reg(ob, "dist")

    def face_v2(self):
        self.face(None)
        tag(self.face_ob, "face", "face")

    # ------------------------------------------------------------ montagem
    def build_v2(self, with_rig=True):
        self.head_parts()
        self.neck()
        self.suit()
        self.collar()
        self.gloves()
        self.boots()
        self.team()
        self.gear_v2()
        self.goggles()
        for ob, _, _ in self.parts:
            if ob.modifiers:
                hero_lib.bake(ob)
        for ob, _, _ in self.parts:
            r = DECIMATE.get(ob.get("rbpart"))
            if r:
                decimate(ob, r)
        rig = hero_lib.make_rig(self.S, self.F, 1.0) if with_rig else None
        self.face_v2()
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


def build():
    b = RV2()
    b.build_v2(True)
    return b
