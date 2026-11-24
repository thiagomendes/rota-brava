"""Pico v2 (RB-R1 D11/D13): geometria do heroi escalador. PROPOSTA PROVISORIA, lado a lado com o Pico do jogo.

Mesmo acabamento do Rastro v2 (source_art/characters/rastro_v2), traje e silhueta proprios:
  - jaqueta curta ACOLCHOADA (gomos horizontais no tronco e aneis nas mangas, modelados) + calca de escalada com joelheiras;
  - capacete de escalada arredondado com lanterna de testa e jugular amarela; tufos de cabelo ruivo saindo por baixo;
  - rolo de corda a tiracolo (ombro direito -> quadril esquerdo, 4 voltas amarradas), mosquetoes grandes no cinto,
    saco de magnesio nas costas, luvas de escalada amarelas, botas de aproximacao (cano baixo, biqueira de borracha);
  - comum da equipe: emblema da Rota Brava no peito (esquerdo, livre da corda) e cinto azul-marinho com fivela-bussola.

Toda geometria e gerada aqui do zero: grafo de pele (SKIN) + SUBSURF para o corpo inteirico (tronco, bracos e pernas numa
malha so), luvas e botas; deslocamento por vertice em numpy (gomos, articulacoes, dobras); torno, tubos, toros e bmesh para o
equipamento; metaballs para o cabelo. Cabeca, rosto e esqueleto de 28 ossos vem de source_art/scripts/hero_lib.py e
hero_face.py (os mesmos do Pico atual). Nada baixado, importado ou de terceiros.

Convencao: Blender Z-up, frente = +Y (vira -Z na Godot), direita do personagem (.R) = +X. Origem nos pes. Metros.
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

# ------------------------------------------------------------------ proporcao: o menor do trio (cabeca proporcionalmente maior)
P2 = dict(head=0.392, leg=0.370, torso=0.262, belly=0.128, sh_x=0.126, limb=0.040, hand=1.28, boot=1.08, eye=1.12, layers=False,
          label="v2 heroi escalador")
hero_lib.VARIANTS["P2"] = P2
PAL = dict(pele="#F3C9A2", cabelo="#D8612A", iris="#2F7FC9", uniforme="#3DBE5A", creme="#FFD23F", calca="#3A4A5C",
           botas="#34404C", chapeu="#3DBE5A", couro="#1F3A5F", emblema="#123A5E", ouro="#FFC83D", olhos="#FFFFFF",
           escuro="#3A1E12", boca="#A63A3F", rubor="#F49A8A", vidro="#FFF6B0", metal="#D6DEE6", corda="#FFD23F", luz="#FFF6B0")
hero_lib.CAST["pico_v2"] = dict(display="Pico", K=1.0, hat="none", hair="tufts", gear=(), gloves=True, pal=PAL)

# Afastamento lateral das pernas (eixo do quadril/joelho/tornozelo): pes separados, chao visivel entre as botas parado
HIP_X = 0.088
# Bainha da jaqueta curta (acima do cinto) e passo dos gomos
HEM_DZ = 0.054
BAFFLE_T = 0.046      # passo dos gomos do tronco (m)
BAFFLE_A = 0.042      # passo dos aneis das mangas (m)

DECIMATE = {"suit": 0.26, "glove": 0.36, "boot": 0.38, "hair": 0.16, "sole": 0.7, "belt": 0.6, "rope": 0.70,
            "lamp_band": 0.7, "chin_strap": 0.8, "knee_pad": 0.6, "carabiner_a": 0.7, "carabiner_b": 0.7}


def decimate(ob, ratio):
    m = ob.modifiers.new("dec", "DECIMATE")
    m.decimate_type = "COLLAPSE"
    m.ratio = ratio
    m.use_collapse_triangulate = False
    hero_lib.bake(ob)


GROUP_OF_PART = {}


def V(*a):
    return Vector(a)


def smooth(t, a, b):
    u = np.clip((t - a) / (b - a), 0.0, 1.0)
    return u * u * (3 - 2 * u)


def bump(u, c, w):
    return np.exp(-((u - c) / w) ** 2)


def puff(frac, sharp=0.45):
    """Perfil de gomo acolchoado: 1 no meio, 0 na costura (vinco agudo)."""
    return np.sin(np.pi * np.clip(frac, 0, 1)) ** sharp


def verts_np(ob):
    a = np.empty(len(ob.data.vertices) * 3)
    ob.data.vertices.foreach_get("co", a)
    return a.reshape(-1, 3)


def set_verts(ob, P):
    ob.data.vertices.foreach_set("co", P.astype(np.float64).ravel())
    ob.data.update()


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


def loop_tube(bm, pts, r, sides, ref):
    """Tubo fechado ao longo de um laco quase plano (ref = normal do plano do laco: referencial estavel)."""
    pts = [Vector(p) for p in pts]
    n = len(pts)
    ref = Vector(ref).normalized()
    rings = []
    for i, p in enumerate(pts):
        d = (pts[(i + 1) % n] - pts[(i - 1) % n]).normalized()
        a = (ref - d * ref.dot(d)).normalized()
        b = d.cross(a)
        rings.append([bm.verts.new(p + (a * math.cos(2 * math.pi * k / sides) + b * math.sin(2 * math.pi * k / sides)) * r)
                      for k in range(sides)])
    for i in range(n):
        j = (i + 1) % n
        for k in range(sides):
            bm.faces.new((rings[i][k], rings[i][(k + 1) % sides], rings[j][(k + 1) % sides], rings[j][k]))


def ring_tube(bm, c, axis, R, r, major=20, minor=6):
    """Toro centrado em c com eixo `axis`."""
    tb = bmesh.new()
    cl.torus_z(tb, R, r, 0.0, major=major, minor=minor)
    q = Vector(axis).normalized().to_track_quat("Z", "Y").to_matrix().to_4x4()
    cl.transform_bm(tb, Matrix.Translation(c) @ q)
    return tb


class PV2(hero_lib.Builder):
    """Construtor do Pico v2. Reusa cabeca, rosto e rig do Builder do RB-R1; corpo, traje, cabelo e equipamento proprios."""

    def __init__(self):
        super().__init__("pico_v2", "P2")
        self.S = "Pico"
        self.F.hip_x = HIP_X
        self.hem_z = self.F.hz + HEM_DZ
        GROUP_OF_PART.clear()

    # ------------------------------------------------------------ cabeca
    def head_parts(self):
        self.head()
        keep = []
        for ob, mode, bone in self.parts:
            if ob.name.endswith("_Blush"):
                bpy.data.objects.remove(ob)        # o rubor e as sardas vao pintados na textura da pele
                continue
            if ob.name.endswith("_Head") or ob.name.endswith("_Nose"):
                tag(ob, "skin_head", "skin")
            keep.append((ob, mode, bone))
        self.parts = keep

    # ------------------------------------------------------------ capacete de escalada (casca + aro + faixa + lanterna + jugular)
    def helmet_geo(self):
        F, k = self.F, self.F.k
        hc, hr = F.hc, F.hr
        self.hel_c = V(0.0, hc.y - 0.008 * k, hc.z + 0.014 * k)
        Ri = (hr[0] * 1.035, hr[1] * 1.035, hr[2] * 1.02)
        self.hel_Ro = (Ri[0] + 0.013, Ri[1] + 0.013, Ri[2] + 0.013)

        def rim_z(a):                    # altura da borda: alta na testa, acima da orelha dos lados, baixa na nuca
            return hc.z - 0.006 * k + 0.092 * k * ((1 + math.cos(a)) / 2) ** 1.6
        self.rim_z = rim_z

        def surf(a, phi, Ro, off=0.0):
            return self.hel_c + V((Ro[0] + off) * math.sin(phi) * math.sin(a), (Ro[1] + off) * math.sin(phi) * math.cos(a),
                                  (Ro[2] + off) * math.cos(phi))
        self.hel_surf = surf

        def phi_rim(a):
            return math.acos(max(-0.99, min(0.99, (rim_z(a) - self.hel_c.z) / self.hel_Ro[2])))
        self.phi_rim = phi_rim
        na, nr = 40, 12
        bm = bmesh.new()
        rows = []
        top = bm.verts.new(self.hel_c + V(0, 0, self.hel_Ro[2]))
        for i in range(na):
            a = 2 * math.pi * i / na
            pr = phi_rim(a)
            col = []
            for j in range(1, nr + 1):
                phi = pr * (j / nr) ** 0.9
                col.append(bm.verts.new(surf(a, phi, self.hel_Ro)))
            rows.append(col)
        for i in range(na):
            ii = (i + 1) % na
            bm.faces.new((top, rows[i][0], rows[ii][0]))
            for j in range(nr - 1):
                bm.faces.new((rows[i][j], rows[i][j + 1], rows[ii][j + 1], rows[ii][j]))
        ob = new_object(self.name("Helmet"), bm, self.M["chapeu"], recalc=True)
        sol = ob.modifiers.new("sol", "SOLIDIFY")
        sol.thickness = 0.011
        sol.offset = -1.0
        hero_lib.bake(ob)
        tag(ob, "helmet", "gear")
        self.reg(ob, "single", "head")
        self.helmet_ob = ob
        # aro de borracha na borda (esconde a espessura e da acabamento de brinquedo)
        bm = bmesh.new()
        pts = []
        for i in range(48):
            a = 2 * math.pi * i / 48
            pts.append(surf(a, phi_rim(a), self.hel_Ro, -0.005))
        loop_tube(bm, pts, 0.0074, 6, (0, 0, 1))
        rim = new_object(self.name("HelmetRim"), bm, self.M["couro"])
        tag(rim, "helmet_rim", "gear")
        self.reg(rim, "single", "head")
        # faixa elastica da lanterna, paralela a borda (~4 cm acima), e a lanterna na testa
        bm = bmesh.new()
        rows = []
        n_ = 64
        for i in range(n_):
            a = 2 * math.pi * i / n_
            pb = phi_rim(a) - 0.30
            nrm = (surf(a, pb, self.hel_Ro, 0.01) - surf(a, pb, self.hel_Ro)).normalized()
            up = (surf(a, pb - 0.05, self.hel_Ro) - surf(a, pb + 0.05, self.hel_Ro)).normalized()
            p = surf(a, pb, self.hel_Ro)
            rows.append([bm.verts.new(p + nrm * o + up * dz) for dz, o in ((-0.012, 0.0), (-0.010, 0.0045), (0.010, 0.0045), (0.012, 0.0))])
        for i in range(n_):
            j = (i + 1) % n_
            for q in range(3):
                bm.faces.new((rows[i][q], rows[j][q], rows[j][q + 1], rows[i][q + 1]))
        band = new_object(self.name("LampBand"), bm, self.M["couro"])
        tag(band, "lamp_band", "gear")
        self.reg(band, "single", "head")
        pb = phi_rim(0.0) - 0.30
        p = surf(0.0, pb, self.hel_Ro, 0.004)
        nrm = (surf(0.0, pb, self.hel_Ro, 0.01) - surf(0.0, pb, self.hel_Ro)).normalized()
        look = (nrm * 0.6 + V(0, 1, 0) * 0.4).normalized()
        T = Matrix.Translation(p) @ look.to_track_quat("Z", "Y").to_matrix().to_4x4()
        bm = bmesh.new()
        cl.lathe(bm, [(0.0, -0.004), (0.030, -0.004), (0.036, 0.004), (0.037, 0.020), (0.034, 0.030), (0.027, 0.033), (0.0, 0.033)], 28)
        cl.rounded_box(bm, (0.0, 0.0, 0.004), (0.090, 0.040, 0.016), 0.006)      # base que prende na faixa
        cl.transform_bm(bm, T)
        lamp = new_object(self.name("Lamp"), bm, self.M["botas"])
        tag(lamp, "lamp", "gear")
        self.reg(lamp, "single", "head")
        bm = bmesh.new()
        cl.ellipsoid(bm, (0, 0, 0.031), (0.026, 0.026, 0.006), 18, 6)
        cl.transform_bm(bm, T)
        lens = new_object(self.name("LampLens"), bm, self.M["luz"])
        tag(lens, "lamp_lens", "screen")
        self.reg(lens, "single", "head")
        bm = bmesh.new()
        tb = ring_tube(bm, V(0, 0, 0.032), V(0, 0, 1), 0.029, 0.0045, 20, 5)
        cl.transform_bm(tb, T)
        hero_lib.join_bm(bm, tb)
        lr = new_object(self.name("LampRing"), bm, self.M["creme"])
        tag(lr, "lamp_ring", "gear")
        self.reg(lr, "single", "head")
        self.lamp_T = T
        # jugular amarela: da borda (na frente da orelha) desce pela mandibula ate a fivela sob o queixo
        dg = bpy.context.evaluated_depsgraph_get()
        hb = BVHTree.FromObject(self.head_ob, dg)
        bm = bmesh.new()
        chin_pts = []
        for sx in (1, -1):
            guide = []
            a0 = math.radians(86)
            z0 = rim_z(a0) + 0.006
            for i in range(16):
                t = i / 15
                # primeiro desce reto na frente da orelha ate a linha da mandibula, depois corre por baixo do queixo
                u1 = min(t / 0.45, 1.0)
                u2 = max((t - 0.45) / 0.55, 0.0)
                a = sx * (a0 - math.radians(6) * u1 - math.radians(80) * (u2 ** 0.8))
                z = z0 + (hc.z - 0.150 * k - z0) * (u1 ** 1.2) + (-0.045 * k) * math.sin(math.pi * 0.5 * u2)
                rr = 0.92 - 0.30 * u2
                g = V(hc.x + math.sin(a) * hr[0] * rr, hc.y + math.cos(a) * hr[1] * rr, z)
                hit = hb.find_nearest(g)
                guide.append(hit[0] + hit[1].normalized() * 0.0052)
            chin_pts.append(guide[-1])
            cl.tube(bm, guide, 0.0042, 6, True)
        strap = new_object(self.name("ChinStrap"), bm, self.M["creme"])
        tag(strap, "chin_strap", "gear")
        self.reg(strap, "single", "head")
        c = (chin_pts[0] + chin_pts[1]) * 0.5
        hit = hb.find_nearest(c)
        nn = hit[1].normalized()
        bm = bmesh.new()
        cl.rounded_box(bm, (0, 0, 0), (0.026, 0.010, 0.016), 0.004)
        cl.transform_bm(bm, Matrix.Translation(hit[0] + nn * 0.008) @ nn.to_track_quat("Y", "Z").to_matrix().to_4x4())
        bk = new_object(self.name("ChinBuckle"), bm, self.M["botas"])
        tag(bk, "chin_buckle", "gear")
        self.reg(bk, "single", "head")

    def cull_head(self):
        """Apaga a parte da cabeca escondida dentro do capacete (economia de triangulos; nada visivel muda)."""
        c = self.hel_c
        bm = bmesh.new()
        bm.from_mesh(self.head_ob.data)
        kill = [v for v in bm.verts if v.co.z > self.rim_z(math.atan2(v.co.x, v.co.y - c.y)) + 0.030]
        bmesh.ops.delete(bm, geom=kill, context="VERTS")
        bm.to_mesh(self.head_ob.data)
        bm.free()

    # ------------------------------------------------------------ cabelo ruivo em tufos que escapam do capacete
    def hair_tufts(self):
        """Massa ruiva sob o capacete (metaballs) + mechas pontudas de vinil (tubos achatados afinando ate a ponta) que escapam
        da borda: leque atras e dos lados com a ponta virada para fora/cima, costeletas e franja varrida para o lado."""
        F, k = self.F, self.F.k
        hc, hr = F.hc, F.hr
        E = [("ELLIPSOID", (hc.x, hc.y - 0.012 * k, hc.z + 0.012 * k), 1.0, (hr[0] * 1.015, hr[1] * 1.0, hr[2] * 0.97), False),
             ("ELLIPSOID", (hc.x, hc.y + hr[1] * 0.25, hc.z - 0.20 * k), 1.0, (hr[0] * 1.3, hr[1] * 0.75, 0.13 * k), True),
             ("ELLIPSOID", (0, hc.y + hr[1] * 0.80, hc.z - 0.046 * k), 1.0, (hr[0] * 0.80, hr[1] * 0.55, 0.112 * k), True),
             # nuca cheia e volume dos lados logo abaixo da borda (atras das orelhas)
             ("ELLIPSOID", (0, hc.y - hr[1] * 0.55, hc.z - 0.030 * k), 1.0, (hr[0] * 0.70, 0.058 * k, 0.080 * k), False)]
        ob = hero_lib.metaball_obj(self.name("Hair"), E, self.M["cabelo"], res=0.012 * k, thresh=0.6)
        bm = bmesh.new()
        bm.from_mesh(ob.data)
        for _ in range(3):
            bmesh.ops.smooth_vert(bm, verts=bm.verts[:], factor=0.5, use_axis_x=True, use_axis_y=True, use_axis_z=True)
        c = self.hel_c
        Ri = (self.hel_Ro[0] - 0.016, self.hel_Ro[1] - 0.016, self.hel_Ro[2] - 0.016)
        kill = []
        for v in bm.verts:
            d = v.co - c
            inside = (d.x / Ri[0]) ** 2 + (d.y / Ri[1]) ** 2 + (d.z / Ri[2]) ** 2 < 1.0
            if inside and v.co.z > self.rim_z(math.atan2(v.co.x, v.co.y - c.y)) + 0.018:
                kill.append(v)
        bmesh.ops.delete(bm, geom=kill, context="VERTS")
        bm.to_mesh(ob.data)
        bm.free()
        tag(ob, "hair", "hair")
        self.hair_ob = ob
        self.reg(ob, "single", "head")
        # ---- mechas
        self.tail_axes = []
        rng = np.random.default_rng(11)
        lb = bmesh.new()

        def lock(a_deg, length, w0, out, down, flick, curl, dz0, root_in=0.020, seg=7, sides=6, flat=0.55):
            a = math.radians(a_deg)
            rad = V(math.sin(a), math.cos(a), 0.0)
            tang = V(math.cos(a), -math.sin(a), 0.0)
            z0 = self.rim_z(a) + dz0
            base = V(hc.x, hc.y - 0.008 * k, 0) + rad * (hr[0] * 1.02 - root_in) + V(0, 0, z0)
            pts = []
            for i in range(seg + 1):
                t = i / seg
                p = base + rad * (out * length * t) + V(0, 0, -down * length * t + flick * length * t ** 2.2) + tang * (curl * length * t ** 2)
                pts.append(p)
            rings = []
            for i, p in enumerate(pts):
                t = i / seg
                d = (pts[min(i + 1, seg)] - pts[max(i - 1, 0)]).normalized()
                nrm = (p - V(hc.x, hc.y, hc.z)).normalized()
                nrm = (nrm - d * nrm.dot(d)).normalized()
                bvec = d.cross(nrm)
                w = w0 * (1.0 - t ** 1.5) * (0.85 + 0.15 * math.sin(math.pi * t))
                if i == seg:
                    rings.append([lb.verts.new(p)])
                    continue
                rings.append([lb.verts.new(p + bvec * math.cos(2 * math.pi * q / sides) * w + nrm * math.sin(2 * math.pi * q / sides) * w * flat)
                              for q in range(sides)])
            for i in range(seg - 1):
                for q in range(sides):
                    lb.faces.new((rings[i][q], rings[i][(q + 1) % sides], rings[i + 1][(q + 1) % sides], rings[i + 1][q]))
            tip = rings[seg][0]
            for q in range(sides):
                lb.faces.new((rings[seg - 1][q], rings[seg - 1][(q + 1) % sides], tip))
            cap = lb.verts.new(pts[0] - (pts[1] - pts[0]) * 0.3)
            for q in range(sides):
                lb.faces.new((rings[0][(q + 1) % sides], rings[0][q], cap))
            self.tail_axes.append((1, [(p, w0 * (1.0 - (i / seg) ** 1.5)) for i, p in enumerate(pts)]))
        # leque de tras e dos lados: descem e viram a ponta para fora/cima
        # cortina de mechas atras e dos lados (depois das orelhas): caem rente a cabeca e a ponta vira para fora
        for i, a in enumerate((102, 122, 142, 161, 180, 199, 218, 238, 258)):
            L = (0.112 if i % 2 == 0 else 0.096) * k
            lock(a + rng.uniform(-3, 3), L, 0.042 * k, 0.30, 1.0, 0.30, 0.16 * (1 if a < 180 else -1), -0.004 * k, root_in=-0.012,
                 flat=0.62)
        # costeletas na frente das orelhas
        for sx in (1, -1):
            lock(sx * 66, 0.046 * k, 0.022 * k, 0.30, 1.0, 0.25, -0.15 * sx, -0.006 * k, root_in=0.004, flat=0.5)
        # franja varrida para a direita do personagem, saindo de baixo da aba
        for a, L, w in ((-42, 0.050, 0.027), (-27, 0.060, 0.029), (-12, 0.062, 0.029), (3, 0.056, 0.027), (18, 0.044, 0.024)):
            lock(a, L * k, w * k, 0.20, 0.55, 0.10, 0.80, -0.004 * k, root_in=0.012, flat=0.70)
        locks = new_object(self.name("HairLocks"), lb, self.M["cabelo"])
        tag(locks, "hair_lock", "hair")
        self.reg(locks, "single", "head")

    # ------------------------------------------------------------ corpo inteirico (tronco + bracos + pernas num grafo so)
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
        pelvis = add((0, -0.004, hz + 0.020), b * 0.97, crotch)
        prev = pelvis
        # tronco com nos densos (gomos do acolchoado precisam de resolucao vertical)
        for t in (0.0, 0.22, 0.44, 0.66, 0.86):
            z = hz + 0.075 + (nz - 0.085 - hz - 0.075) * t
            prev = add((0, 0.002 + 0.004 * t, z), b * (0.94 + 0.05 * t), prev)
        upper = add((0, 0.000, nz - 0.040), b * 0.86, prev)
        add((0, 0.002, nz + 0.006), 0.054, upper)
        self.limb_segs = []
        for sx, s in ((1, "R"), (-1, "L")):
            sh = V(sx * F.sh.x, F.sh.y, F.sh.z)
            el = V(sx * F.elbow.x, F.elbow.y, F.elbow.z)
            W = V(sx * F.wrist.x, F.wrist.y, F.wrist.z)
            L = v["limb"]
            s0 = add(V(sx * F.sh.x * 0.62, 0.0, F.sh.z + 0.012), L * 1.30, upper)
            p = add(sh.lerp(el, 0.10), L * 1.22, s0)
            for t, rr in ((0.32, 1.12), (0.55, 1.06), (0.78, 1.00)):
                p = add(sh.lerp(el, t), L * rr, p)
            p = add(sh.lerp(el, 0.95), L * 0.98, p)
            for t, rr in ((0.14, 0.98), (0.36, 1.00), (0.58, 0.96)):
                p = add(el.lerp(W, t), L * rr, p)
            add(el.lerp(W, 0.86), L * 0.84, p)
            hx = sx * F.hip_x
            kz = F.knee_z
            h0 = add((hx, -0.002, hz - 0.060), 0.070, crotch)
            t1 = add((hx, 0.002, hz - (hz - kz) * 0.45), 0.065, h0)
            k0 = add((hx, 0.006, kz + 0.022), 0.057, t1)
            k1 = add((hx, 0.004, kz - 0.020), 0.055, k0)
            c0 = add((hx, -0.004, kz - 0.070), 0.055, k1)
            a0 = add((hx, -0.002, F.ankle_z + 0.068), 0.051, c0)
            add((hx, -0.002, F.ankle_z + 0.026), 0.049, a0)
            self.limb_segs += [("upper_arm", s, sh, el), ("forearm", s, el, W), ("thigh", s, V(hx, 0, hz - 0.03), V(hx, 0.006, kz)),
                               ("shin", s, V(hx, 0.006, kz), V(hx, 0, F.ankle_z))]
        ob = cl.skin_obj(self.name("Suit"), nodes, edges, self.M["uniforme"], levels=3, branch=1.0)
        self.shape_suit(ob)
        tag(ob, "suit", "suit")
        self.suit_ob = ob
        self.reg(ob, "dist")
        return ob

    def shape_suit(self, ob):
        """Jaqueta acolchoada (gomos e aneis), articulacoes, calca de escalada (joelho articulado, bolso de carga)."""
        F, v = self.F, self.v
        hz, nz = F.hz, F.nz
        hem = self.hem_z
        P = verts_np(ob)
        segs = [("torso", 0, np.array([0, 0, hz - 0.06]), np.array([0, 0, nz + 0.02]), v["belly"])]
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
        out = P.copy()
        z = P[:, 2]
        # ---- tronco
        w = Wt[0]
        depth = 0.86 - 0.04 * smooth(z, hz + 0.05, nz - 0.05)
        out[:, 1] = P[:, 1] * (1 - w) + P[:, 1] * depth * w
        front = np.clip(P[:, 1] / 0.12, -1, 1)
        add_t = (0.008 * bump(z, hz + 0.065, 0.045) * np.clip(front, 0, 1) ** 2
                 + 0.012 * bump(z, hz - 0.030, 0.040) * np.clip(-front, 0, 1) ** 1.5)
        side = np.clip(np.abs(P[:, 0]) / 0.13, 0, 1)
        add_t += 0.006 * bump(z, hz + 0.0, 0.05) * side ** 2
        # jaqueta: espessura do acolchoado + gomos horizontais (vinco fundo na costura), abertos no ziper central
        jk = smooth(z, hem - 0.003, hem + 0.004)
        top_fade = 1 - smooth(z, nz - 0.040, nz - 0.010)
        frac = ((z - hem) / BAFFLE_T) % 1.0
        zip_gap = 1 - 0.85 * bump(P[:, 0], 0.0, 0.007) * (P[:, 1] > 0)
        add_t += jk * (0.009 + 0.0065 * puff(frac) * top_fade * zip_gap)
        add_t -= 0.0025 * jk * bump(P[:, 0], 0.0, 0.004) * (P[:, 1] > 0)          # canaleta do ziper
        rad = P.copy()
        rad[:, 2] = 0
        rn = rad / np.maximum(np.linalg.norm(rad, axis=1)[:, None], 1e-9)
        out += rn * (add_t * w)[:, None]
        # ---- membros
        for i, (kind, sx, a, b, r) in enumerate(segs[1:], start=1):
            w = Wt[i]
            u, rr, rnv, dn, L = seg_frame(P, a, b)
            fr, ou = ref_dirs(dn, sx)
            fdot = rnv @ fr
            odot = rnv @ ou
            s_along = u * L
            d = np.zeros(len(P))
            if kind == "upper_arm":
                d += 0.008 * bump(u, 0.16, 0.16) * np.clip(0.35 + 0.65 * odot, 0, 1)
                d += 0.008 + 0.0060 * puff(((s_along - 0.012) / BAFFLE_A) % 1.0) * smooth(u, 0.08, 0.2)
                d += 0.0028 * np.sin(2 * np.pi * (L - s_along) / 0.016) ** 2 * bump(u, 0.95, 0.07) * np.clip(fdot, 0, 1) ** 2
            elif kind == "forearm":
                d += 0.005 * bump(u, 0.00, 0.07) * np.clip(-fdot, 0, 1) ** 2
                cuff = smooth(u, 0.80, 0.86)
                d += (0.007 + 0.0055 * puff((s_along / BAFFLE_A) % 1.0)) * (1 - cuff)
                d += 0.0028 * np.sin(2 * np.pi * s_along / 0.016) ** 2 * bump(u, 0.06, 0.08) * np.clip(fdot, 0, 1) ** 2
                # punho elastico canelado
                ang = np.arctan2(odot, fdot)
                d += cuff * (0.0015 + 0.0012 * np.sin(ang * 18))
            elif kind == "thigh":
                d += 0.005 * bump(u, 0.40, 0.28) * np.clip(fdot, 0, 1) ** 1.5
                d += 0.004 * bump(u, 0.10, 0.18) * np.clip(odot, 0, 1)
                d += 0.0030 * np.sin(2 * np.pi * (L - s_along) / 0.018) ** 2 * bump(u, 0.96, 0.07) * np.clip(-fdot, 0, 1) ** 2
                # bolso de carga na coxa direita (lado de fora): volume quadrado e macio
                if sx == 1:
                    ang = np.arctan2(fdot, odot)
                    d += 0.0075 * smooth(u, 0.30, 0.36) * (1 - smooth(u, 0.66, 0.72)) * smooth(-np.abs(ang), -0.62, -0.48)
            elif kind == "shin":
                d += 0.010 * bump(u, 0.02, 0.10) * np.clip(fdot, 0, 1) ** 1.6
                d += 0.008 * bump(u, 0.36, 0.20) * np.clip(-fdot, 0, 1) ** 1.2
                d += 0.0030 * np.sin(2 * np.pi * s_along / 0.018) ** 2 * bump(u, 0.03, 0.07) * np.clip(-fdot, 0, 1) ** 2
                # barra franzida da calca sobre a bota
                zz = P[:, 2]
                ang = np.arctan2(odot, fdot)
                d += 0.0035 * (0.5 + 0.5 * np.sin(2 * np.pi * (zz - F.ankle_z) / 0.020 + 1.2 * np.sin(2 * ang + 0.7))) * \
                    smooth(zz, F.ankle_z + 0.060, F.ankle_z + 0.075) * (1 - smooth(zz, F.ankle_z + 0.12, F.ankle_z + 0.15))
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

    def _suit_bvh(self):
        return BVHTree.FromObject(self.suit_ob, bpy.context.evaluated_depsgraph_get())

    def ring_at(self, bvh, z, off, n=48):
        """Anel na superficie do tronco na altura z (raio lancado de DENTRO para fora: nao pega os bracos ao lado)."""
        pts = []
        for i in range(n):
            a = 2 * math.pi * i / n
            dr = V(math.sin(a), math.cos(a), 0)
            hit = bvh.ray_cast(V(0, 0, z), dr, 0.4)[0]
            pts.append((hit if hit else V(0, 0, z) + dr * 0.12) + dr * off)
        return pts

    # ------------------------------------------------------------ gola acolchoada em pe, ziper e bainha amarela
    def jacket_trims(self):
        F = self.F
        nz = F.nz
        bm = bmesh.new()
        rows = []
        nu, nv = 28, 3
        for i in range(nu + 1):
            a = math.radians(20 + (360 - 40) * i / nu)
            back = 0.5 - 0.5 * math.cos(a)
            ring = []
            for j in range(nv + 1):
                t = j / nv
                h = (0.034 + 0.012 * back) * t
                r = 0.062 + 0.004 * back + (0.010 + 0.006 * back) * t ** 1.3
                ring.append(bm.verts.new((r * math.sin(a) * 1.06, r * math.cos(a) * 0.98 + 0.004, nz - 0.010 + h)))
            rows.append(ring)
        for i in range(nu):
            for j in range(nv):
                bm.faces.new((rows[i][j], rows[i + 1][j], rows[i + 1][j + 1], rows[i][j + 1]))
        ob = new_object(self.name("Collar"), bm, self.M["creme"], recalc=False)
        sol = ob.modifiers.new("sol", "SOLIDIFY")
        sol.thickness = 0.011
        sol.offset = 1.0
        hero_lib.bake(ob)
        tag(ob, "collar", "suit")
        self.reg(ob, "torso")
        bvh = self._suit_bvh()
        # bainha: vivo amarelo grosso seguindo a borda da jaqueta
        bm = bmesh.new()
        ring = self.ring_at(bvh, self.hem_z + 0.004, 0.003, 32)
        loop_tube(bm, ring, 0.0080, 6, (0, 0, 1))
        hem = new_object(self.name("Hem"), bm, self.M["uniforme"])
        tag(hem, "hem", "gear")
        self.reg(hem, "torso")
        # puxador do ziper no alto do peito
        zy = (cl.snap_y(self.suit_ob, 0.0, nz - 0.030) or 0.11)
        bm = bmesh.new()
        cl.rounded_box(bm, (0.0, zy + 0.006, nz - 0.040), (0.016, 0.006, 0.026), 0.003)
        cl.rounded_box(bm, (0.0, zy + 0.003, nz - 0.025), (0.012, 0.008, 0.010), 0.002)
        zp = new_object(self.name("ZipPull"), bm, self.M["ouro"])
        tag(zp, "zip_pull", "gear")
        self.reg(zp, "torso")

    # ------------------------------------------------------------ luvas de escalada (4 dedos, relaxados, juntos e levemente curvos)
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
            w0 = add(W - d * 0.028 * k, 0.026 * k)
            w1 = add(W + d * 0.004 * k, 0.027 * k, w0)
            palm = add(W + d * 0.036 * k, 0.031 * k, w1)
            # polegar junto da palma, apontando para a frente (sem abrir em garra)
            t0 = add(W + d * 0.022 * k + f * 0.022 * k + n * 0.012 * k, 0.0148 * k, w1)
            t1 = add(W + d * 0.040 * k + f * 0.034 * k + n * 0.020 * k, 0.0136 * k, t0)
            add(W + d * 0.054 * k + f * 0.036 * k + n * 0.027 * k, 0.0126 * k, t1)
            # tres dedos juntos, quase paralelos, com curva suave para dentro da palma (mao relaxada)
            for off, ln, spread in ((0.0165, 0.042, 0.08), (-0.0005, 0.047, 0.0), (-0.0175, 0.040, -0.09)):
                base = add(W + d * 0.058 * k + f * off * k, 0.0150 * k, palm)
                fd = (d + f * spread * 0.35).normalized()
                mid = add(W + d * 0.058 * k + f * off * k + fd * ln * 0.55 * k + n * 0.009 * k, 0.0142 * k, base)
                add(W + d * 0.058 * k + f * off * k + fd * ln * 0.92 * k + n * 0.024 * k, 0.0130 * k, mid)
            ob = cl.skin_obj(self.name("Glove" + sd), nn, ee, self.M["creme"], levels=2, branch=0.6)
            P = verts_np(ob)
            Wn = np.array(W)
            loc = P - Wn
            dd, ff, nnv = np.array(d), np.array(f), np.array(n)
            ad, af, an = loc @ dd, loc @ ff, loc @ nnv
            palm_w = np.exp(-((ad - 0.030 * k) / (0.034 * k)) ** 2)
            thumb = (af > 0.018 * k) & (an > 0.006 * k) & (ad < 0.05 * k)
            sq = 1 - 0.30 * palm_w * (~thumb)
            P2_ = Wn + np.outer(ad, dd) + np.outer(af * (1 + 0.08 * palm_w * (~thumb)), ff) + np.outer(an * sq, nnv)
            set_verts(ob, P2_)
            tag(ob, "glove", "gear")
            self.reg(ob, "single", "hand." + sd)
            # cano curto da luva com tira de velcro
            el = V(sx * F.elbow.x, F.elbow.y, F.elbow.z)
            ax = (V(*W) - el).normalized()
            c = V(*W) - ax * 0.016
            bm = bmesh.new()
            prof = [(0.0, 0.026), (0.040, 0.026), (0.046, 0.022), (0.047, 0.016), (0.042, 0.002), (0.034, -0.010), (0.031, -0.014), (0.0, -0.014)]
            cl.lathe(bm, prof, 22)
            q = ax.to_track_quat("Z", "Y").to_matrix().to_4x4()
            cl.transform_bm(bm, Matrix.Translation(c) @ q @ Matrix.Diagonal((1.0, 0.92, 1.0, 1.0)))
            tb = bmesh.new()
            cl.rounded_box(tb, (0.0, 0.0, 0.0), (0.030, 0.012, 0.022), 0.004)
            outv = V(sx * 1.0, 0.0, 0.0)
            outv = (outv - ax * outv.dot(ax)).normalized()
            cl.transform_bm(tb, Matrix.Translation(c + ax * 0.012 + outv * 0.044) @ Matrix((ax.cross(outv).normalized(), outv, ax)).transposed().to_4x4())
            hero_lib.join_bm(bm, tb)
            cuff = new_object(self.name("GloveCuff" + sd), bm, self.M["uniforme"])
            tag(cuff, "glove_cuff", "gear")
            self.reg(cuff, "single", "forearm." + sd)

    # ------------------------------------------------------------ botas de aproximacao: cano baixo, biqueira, sola clara
    def boots(self):
        F = self.F
        self.boot_info = {}
        for sx, sd in ((1, "R"), (-1, "L")):
            x = sx * F.hip_x
            nn = [((x, -0.008, F.ankle_z + 0.050), 0.047), ((x, -0.012, F.ankle_z + 0.004), 0.053),
                  ((x, F.ball_y * 0.70, 0.047), 0.055), ((x, F.toe_y - 0.044, 0.046), 0.051)]
            boot = cl.skin_obj(self.name("Boot" + sd), nn, [(0, 1), (1, 2), (2, 3)], self.M["botas"], levels=3, floor=0.022)
            P = verts_np(boot)
            yrel = (P[:, 1] - F.heel_y) / (F.toe_y - F.heel_y)
            P[:, 0] = x + (P[:, 0] - x) * (1.0 + 0.06 * smooth(yrel, 0.45, 0.95))
            P[:, 2] = np.where(P[:, 2] > 0.03, P[:, 2] + 0.005 * bump(yrel, 0.85, 0.15) * (P[:, 2] > 0.06), P[:, 2])
            set_verts(boot, P)
            z_top = float(P[:, 2].max()) - 0.010
            bm = bmesh.new()
            bm.from_mesh(boot.data)
            hero_lib.bisect_keep(bm, (0, 0, z_top), (0, 0, 1), keep_above=False)
            rim = [vv.co.copy() for vv in bm.verts if abs(vv.co.z - z_top) < 1e-4]
            bm.to_mesh(boot.data)
            bm.free()
            assert len(rim) > 8, "corte da boca da bota nao achou o aro"
            rc = sum(rim, Vector()) / max(len(rim), 1)
            rr = sum(((p - rc).xy.length for p in rim), 0.0) / max(len(rim), 1)
            tag(boot, "boot", "gear")
            self.reg(boot, "dist")
            BP = verts_np(boot)
            low = BP[BP[:, 2] < 0.06]
            cxy = np.array([x, low[:, 1].mean()])
            bm = bmesh.new()
            n_ = 32
            prof = []
            for i in range(n_):
                a = 2 * math.pi * i / n_
                dv = np.array([math.cos(a), math.sin(a)])
                prof.append(cxy + dv * (((low[:, :2] - cxy) @ dv).max() + 0.004))
            rows = []
            for zz, grow in ((0.0, -0.004), (0.005, 0.0), (0.019, 0.0), (0.024, -0.003)):
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
            # colarinho acolchoado na boca da bota
            bm = bmesh.new()
            cl.torus_z(bm, rr - 0.001, 0.0095, z_top + 0.002, sy=0.97, major=22, minor=6)
            cl.transform_bm(bm, Matrix.Translation((rc.x, rc.y, 0)))
            top = new_object(self.name("BootTop" + sd), bm, self.M["uniforme"])
            tag(top, "boot_top", "gear")
            self.reg(top, "dist")
            self.boot_info[sd] = dict(x=x, z_top=z_top)

    # ------------------------------------------------------------ joelheiras (acolchoadas, verdes com vivo amarelo)
    def knee_pads(self):
        F = self.F
        bvh = self._suit_bvh()
        bm = bmesh.new()
        self.knee_centers = []
        for sx in (1, -1):
            x = sx * F.hip_x
            z = F.knee_z + 0.002
            hit = bvh.ray_cast(V(x, 0.5, z), V(0, -1, 0))[0]
            y = hit.y if hit else 0.06
            tb = bmesh.new()
            cl.ellipsoid(tb, (0, 0, 0), (0.046, 0.022, 0.054), 16, 10)
            for vv in tb.verts:                     # costas da joelheira acompanham a perna (concava)
                vv.co.y -= 0.010 * (vv.co.x / 0.046) ** 2
            cl.transform_bm(tb, Matrix.Translation((x, y - 0.006, z)) @ cl.Matrix.Rotation(math.radians(-6), 4, "X"))
            hero_lib.join_bm(bm, tb)
            self.knee_centers.append((x, y + 0.016, z))
        pads = new_object(self.name("KneePads"), bm, self.M["uniforme"])
        tag(pads, "knee_pad", "gear")
        self.reg(pads, "xfer:Suit")

    # ------------------------------------------------------------ cinto de equipe + fivela-bussola + EMBLEMA (peito esquerdo)
    def team(self):
        F = self.F
        hz, nz = F.hz, F.nz
        suit = self.suit_ob
        bvh = self._suit_bvh()
        bz = hz + 0.016
        self.belt_z = bz
        prof = [(-0.019, 0.000), (-0.017, 0.009), (0.017, 0.009), (0.019, 0.000)]
        ring = self.ring_at(bvh, bz, 0.002)
        self.belt_ring = ring
        bm = bmesh.new()
        rows = []
        for p in ring:
            dr = V(p.x, p.y, 0).normalized()
            rows.append([bm.verts.new(p + dr * o + V(0, 0, dz)) for dz, o in prof])
        for i in range(48):
            j = (i + 1) % 48
            for k in range(3):
                bm.faces.new((rows[i][k], rows[j][k], rows[j][k + 1], rows[i][k + 1]))
        belt = new_object(self.name("Belt"), bm, self.M["couro"], recalc=True)
        tag(belt, "belt", "gear")
        self.reg(belt, "torso")
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
        # EMBLEMA no peito esquerdo (-X): pousado acima dos gomos (maior y da superficie sob ele)
        ex, ez = -0.058, nz - 0.098
        w, h = 0.080, 0.090
        ys = [cl.snap_y(suit, ex + dx, ez + dz) for dx in (-0.03, 0.0, 0.03) for dz in (-0.035, 0.0, 0.035)]
        ey = max(y for y in ys if y is not None)
        T = Matrix.Translation((ex, ey - 0.004, ez)) @ V(-0.30, 1.0, 0.12).normalized().to_track_quat("Y", "Z").to_matrix().to_4x4()
        bm = bmesh.new()
        hero_lib.prism(bm, hero_lib.emblem_outline(w, h, 40), 0.008, (0, 0, 0))
        bmesh.ops.bevel(bm, geom=[e for e in bm.edges if len(e.link_faces) == 2 and e.calc_face_angle(0) > 0.6], offset=0.0022, segments=3, affect="EDGES")
        cl.transform_bm(bm, T)
        self.reg(tag(new_object(self.name("Emblem"), bm, self.M["emblema"]), "emblem", "gear"), "torso")
        bm = bmesh.new()
        hero_lib.prism(bm, hero_lib.star4(0.027, 0.009), 0.005, (0, 0.008, 0.009))
        bmesh.ops.bevel(bm, geom=bm.edges[:], offset=0.0010, segments=1, affect="EDGES")
        cl.transform_bm(bm, T)
        self.reg(tag(new_object(self.name("EmblemStar"), bm, self.M["ouro"]), "emblem_star", "gear"), "torso")
        bm = bmesh.new()
        band = []
        for i in range(13):
            t = (i / 12) * 2 - 1
            band.append((t * w * 0.38, -0.024 + 0.008 * t * t))
        for i in range(12, -1, -1):
            t = (i / 12) * 2 - 1
            band.append((t * w * 0.38, -0.032 + 0.008 * t * t))
        hero_lib.prism(bm, band, 0.004, (0, 0.008, 0))
        cl.transform_bm(bm, T)
        self.reg(tag(new_object(self.name("EmblemBand"), bm, self.M["creme"]), "emblem_band", "gear"), "torso")

    # ------------------------------------------------------------ rolo de corda a tiracolo (ombro direito -> quadril esquerdo)
    def rope(self):
        F = self.F
        hz, nz = F.hz, F.nz
        dg = bpy.context.evaluated_depsgraph_get()
        bvhs = [BVHTree.FromObject(o, dg) for o, _, _ in self.parts if o.get("rbpart") in ("suit", "collar", "hem", "belt", "emblem")]
        A = V(0.098, 0.0, nz + 0.004)
        B = V(-0.124, 0.0, hz - 0.004)
        e1 = (A - B).normalized()
        Y = V(0, 1, 0)
        nP = e1.cross(Y).normalized()
        C = (A + B) * 0.5
        n_ = 40
        rho = []
        dirs = []
        for i in range(n_):
            th = 2 * math.pi * i / n_
            dv = e1 * math.cos(th) + Y * math.sin(th)
            best = None
            for bv in bvhs:
                h = bv.ray_cast(C + dv * 0.7, -dv)
                if h[0] is not None and (best is None or h[3] < best):
                    best = h[3]
            rho.append(0.7 - best if best is not None else 0.15)
            dirs.append(dv)
        rho = np.array(rho)
        # fechamento morfologico (nao afunda nas concavidades) + media circular
        dil = np.max(np.stack([np.roll(rho, s) for s in (-2, -1, 0, 1, 2)]), axis=0)
        sm = np.mean(np.stack([np.roll(dil, s) for s in (-2, -1, 0, 1, 2)]), axis=0)
        self.rope_axes = []
        bm = bmesh.new()
        rr = 0.0108
        # feixe de 5 voltas em volta de um eixo a 2,8 cm da roupa (rolo grosso, le a distancia e de costas)
        strands = tuple((0.028 + 0.0165 * math.cos(2 * math.pi * q / 5 + 0.3), 0.0165 * math.sin(2 * math.pi * q / 5 + 0.3)) for q in range(5))
        for si, (radial, lat) in enumerate(strands):
            pts = []
            for i in range(n_):
                th = 2 * math.pi * i / n_
                l = lat + 0.0025 * math.sin(2 * th + si * 1.7)
                pts.append(C + dirs[i] * (sm[i] + radial) + nP * l)
            loop_tube(bm, pts, rr, 6, nP)
            self.rope_axes.append(pts)
        ob = new_object(self.name("Rope"), bm, self.M["corda"])
        tag(ob, "rope", "gear")
        self.reg(ob, "torso")
        # amarracoes (voltas que prendem o feixe) perto do quadril esquerdo, e um mosquetao preso nelas
        bm = bmesh.new()
        self.wrap_pts = []
        for th_ in (math.pi - 0.20, math.pi, math.pi + 0.20):
            i = int(round(th_ / (2 * math.pi) * n_)) % n_
            j = (i + 1) % n_
            c = C + dirs[i] * (sm[i] + 0.028)
            tang = (dirs[j] * sm[j] - dirs[i] * sm[i]).normalized()
            tb = ring_tube(bm, c, tang, 0.0300, 0.0058, 16, 5)
            hero_lib.join_bm(bm, tb)
            self.wrap_pts.append((c, tang))
        wr = new_object(self.name("RopeWraps"), bm, self.M["uniforme"])
        tag(wr, "rope_wrap", "gear")
        self.reg(wr, "torso")
        self.rope_plane = (C, e1, nP)

    # ------------------------------------------------------------ mosquetoes grandes no cinto + saco de magnesio
    def carabiner(self, c, up, side, H=0.084, Wd=0.050, r=0.0070):
        """Mosquetao em D: tubo fechado com a trava (lado reto) um pouco destacada."""
        up, side = up.normalized(), side.normalized()
        nrm = side.cross(up).normalized()
        pts = []
        n_ = 24
        for i in range(n_):
            t = 2 * math.pi * i / n_
            x = math.cos(t)
            y = math.sin(t)
            # D: lado esquerdo reto (trava), direito arredondado e mais largo embaixo
            xx = (x if x > 0 else x * 0.55) * Wd * 0.5 * (1 + 0.12 * (-y))
            yy = y * H * 0.5
            pts.append(c + side * xx + up * yy)
        bm = bmesh.new()
        loop_tube(bm, pts, r, 6, nrm)
        # trava (gate) com a rosca: cilindro curto e grosso no lado reto
        tb = bmesh.new()
        cl.tube(tb, [c - side * Wd * 0.29 - up * H * 0.30, c - side * Wd * 0.29 - up * H * 0.06], 0.0088, 10, True)
        hero_lib.join_bm(bm, tb)
        return bm

    def rack(self):
        F = self.F
        bz = self.belt_z
        g = bmesh.new()
        b2 = bmesh.new()
        loops = bmesh.new()
        ring = self.belt_ring
        for idx, (ang, dst) in enumerate(((38, g), (72, b2))):
            i = int(round(ang / 360 * 48)) % 48
            p = ring[i]
            dr = V(p.x, p.y, 0).normalized()
            tang = V(dr.y, -dr.x, 0)
            top = p + dr * 0.016 + V(0, 0, -0.022)
            c = top + V(0, 0, -0.040) + dr * 0.004
            up = V(0, 0, 1) + dr * 0.15
            tb = self.carabiner(c, up, tang if idx == 0 else -tang)
            hero_lib.join_bm(dst, tb)
            # passador do cinto que segura o mosquetao
            tl = ring_tube(loops, p + dr * 0.012 + V(0, 0, -0.016), tang, 0.009, 0.0042, 14, 5)
            hero_lib.join_bm(loops, tl)
        # mosquetao preso nas amarracoes da corda (quadril esquerdo)
        c, tang = self.wrap_pts[1]
        C, e1, nP = self.rope_plane
        outw = (c - V(0, 0, c.z)).normalized()
        tb = self.carabiner(c + outw * 0.046 + V(0, 0, -0.040), V(0, 0, 1), V(-outw.y, outw.x, 0), H=0.062, Wd=0.038, r=0.0055)
        hero_lib.join_bm(g, tb)
        ca = new_object(self.name("CarabinerA"), g, self.M["ouro"])
        tag(ca, "carabiner_a", "gear")
        self.reg(ca, "single", "hips")
        cb = new_object(self.name("CarabinerB"), b2, self.M["uniforme"])
        tag(cb, "carabiner_b", "gear")
        self.reg(cb, "single", "hips")
        gl = new_object(self.name("GearLoops"), loops, self.M["couro"])
        tag(gl, "gear_loop", "gear")
        self.reg(gl, "single", "hips")
        # saco de magnesio nas costas, no cinto (amarelo, borda de pelucia branca, cordao verde)
        i = 24
        p = ring[i]
        cy = p.y - 0.040
        cz = bz - 0.018
        bm = bmesh.new()
        cl.lathe(bm, [(0.0, -0.034), (0.026, -0.033), (0.036, -0.026), (0.040, -0.008), (0.040, 0.020), (0.037, 0.030), (0.0, 0.030)], 24)
        cl.transform_bm(bm, Matrix.Translation((0.0, cy, cz)) @ cl.Matrix.Rotation(math.radians(8), 4, "X"))
        bag = new_object(self.name("ChalkBag"), bm, self.M["creme"])
        tag(bag, "chalk_bag", "gear")
        self.reg(bag, "single", "hips")
        bm = bmesh.new()
        cl.torus_z(bm, 0.037, 0.0085, 0.0, major=24, minor=6)
        cl.transform_bm(bm, Matrix.Translation((0.0, cy + 0.004, cz + 0.031)) @ cl.Matrix.Rotation(math.radians(8), 4, "X"))
        rim = new_object(self.name("ChalkRim"), bm, self.M["olhos"])
        tag(rim, "chalk_rim", "gear")
        self.reg(rim, "single", "hips")
        bm = bmesh.new()
        cl.tube(bm, [(0.022, cy - 0.020, cz + 0.040), (0.030, cy - 0.034, cz + 0.020), (0.026, cy - 0.040, cz + 0.002)], 0.0035, 6, True)
        cl.ellipsoid(bm, (0.026, cy - 0.041, cz - 0.002), (0.007, 0.007, 0.009), 10, 6)
        cord = new_object(self.name("ChalkCord"), bm, self.M["uniforme"])
        tag(cord, "chalk_cord", "gear")
        self.reg(cord, "single", "hips")

    # ------------------------------------------------------------ pescoco (pele)
    def neck(self):
        F = self.F
        nodes = [((0, 0.004, F.nz - 0.03), 0.039), ((0, 0.006, F.chin + 0.04), 0.036)]
        ob = cl.skin_obj(self.name("Neck"), nodes, [(0, 1)], self.M["pele"], levels=1)
        tag(ob, "skin_neck", "skin")
        self.reg(ob, "dist")

    def face_v2(self):
        self.face(None)
        tag(self.face_ob, "face", "face")

    # ------------------------------------------------------------ montagem
    def build_v2(self, with_rig=True):
        self.head_parts()
        self.helmet_geo()
        self.hair_tufts()
        self.neck()
        self.suit()
        self.jacket_trims()
        self.gloves()
        self.boots()
        self.knee_pads()
        self.team()
        self.rope()
        self.rack()
        for ob, _, _ in self.parts:
            if ob.modifiers:
                hero_lib.bake(ob)
        for ob, _, _ in self.parts:
            r = DECIMATE.get(ob.get("rbpart"))
            if r:
                decimate(ob, r)
        rig = hero_lib.make_rig(self.S, self.F, 1.0) if with_rig else None
        self.face_v2()
        self.cull_head()
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
    b = PV2()
    b.build_v2(True)
    return b
