"""Lumi v2 (RB-R1 G21): o operador do Farol 7, a base da equipe Rota Brava, no padrao do trio v2 e dos secundarios v2.
PROVISORIO.

Personagem original do projeto (decisao de Thiago, 2026-11-27): homem de uns 30 anos, calmo e animado, que fala no
radio ("Na escuta!"). Visual de docs/proposals/g21_farol7.md secao 1, revisto para homem:
  - silhueta-chave: cabelo crespo curto com o alto arredondado e as laterais baixas, fone de ARCO amarelo por cima do
    cabelo, conchas azuis, haste do microfone coral ate o canto da boca (sem cobrir a boca) e antena curta com bolinha
    coral na concha direita. De costas: "alto redondo + arco + antena", diferente do chapeu do Rastro, do capacete do
    Pico, do bone da Leme, do quepe do capitao e do lenco da Dona Amora.
  - rosto adulto masculino: mandibula mais larga e reta (JAW menor), queixo firme, cavanhaque curto e costeletas;
    sombra de barba pintada.
  - jaqueta de equipe azul 0B2440 com gola amarela FFD23A e emblema da Rota Brava no peito esquerdo; faixa coral E2453A
    que desce da gola pelo ombro ate o punho (so ele tem); barra e punhos canelados.
  - calca clara, tenis branco com sola amarela.
Base adulta em sv2_human.py; textura e material no pipeline do trio (sv2_lib -> rv2_tex). Mesmo esqueleto de 28 ossos.
Clipes: idle (loop, pose_idle_adult), talk (3,0 s, visemas), wave (1,6 s), point (1,2 s, aponta para a camera).

Uso (Linux):
  bash tools/blender.sh --background --factory-startup --python source_art/characters/secondary_v2/build_lumi_v2.py -- \
      --glb $PWD/game/assets/models/characters/lumi_v2.glb --blend $PWD/source_art/characters/secondary_v2/lumi_v2.blend
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
import hero_anim as ha
import hero_lib
import sv2_lib as S
from char_anim import blink_curve, lerp, smooth
from hero_lib import join_bm
from rbart import REPO, arg_value, new_object, reset_scene
from sv2_human import Adult, V, pose_idle_adult

CID = "lumi_v2"
PREFIX = "lumi_v2"
TEX_DIR = os.path.join(REPO, "captures", "g21", "build_textures", CID)
C = dict(pele="#9C6240", rubor="#B9604A", barba="#4E3829", cabelo="#2A1E18", cabelo_lt="#4A3428",
         navy="#0B2440", navy_lt="#16345A", amarelo="#FFD23A", coral="#E2453A", calca="#A9844E", calca_dk="#86663A",
         tenis="#F3F5F8", tenis_dk="#C9D2DE", concha="#2A5DA8", almofada="#22262E", emblema="#123A5E", ouro="#FFC83D",
         iris="#5A3820", boca="#7E3A36")
# proporcao adulta (metros): cabeca 0,36 m em ~1,73 m (21%), entre a Dona Amora (1,68) e o capitao (1,77); mais magro
# que o capitao, ombros um pouco mais largos que os da Dona Amora
# G21 r2 (coordenador): pernas mais curtas e grossas, tronco e ombros com mais volume (familia do capitao e da Dona Amora)
hero_lib.VARIANTS["LU2"] = dict(head=0.360, leg=0.750, torso=0.520, belly=0.168, sh_x=0.208, limb=0.062, hand=1.46, boot=1.18,
                                eye=0.84, layers=False, label="adulto v2 (Lumi)")
hero_lib.CAST[CID] = dict(display="Lumi", K=1.0, variant="LU2", hat="none", hair="short", team=True, gear=(), gloves=False,
                          pal=dict(pele=C["pele"], cabelo=C["cabelo"], iris=C["iris"], uniforme=C["navy"], creme=C["amarelo"],
                                   calca=C["calca"], botas=C["tenis"], chapeu=C["amarelo"], couro=C["concha"], emblema=C["emblema"],
                                   ouro=C["ouro"], olhos="#FFFFFF", escuro="#1E1512", boca=C["boca"], rubor=C["rubor"]))
parts = S.Parts()
HEM = None
GEO = {}


class Lumi(Adult):
    belly_bump = 0.004
    # rosto adulto masculino: mandibula menos afunilada (mais larga e reta), queixo firme, sem maca de bebe
    JAW, CHIN, CHEEK = 0.17, 0.11, 0.0
    # as conchas do fone ficam sobre as orelhas (a orelha modelada furaria a concha)
    EARS = False

    def __init__(self):
        super().__init__(CID, "LU2", parts)

    # ------------------------------------------------------------ cabelo, costeletas e cavanhaque
    def hair(self):
        F, k, M = self.F, self.F.k, self.M
        hc, hr = F.hc, F.hr
        E = [  # casca rente (laterais baixas) e o alto arredondado, um pouco para tras
             ("ELLIPSOID", (0, hc.y - 0.010 * k, hc.z + 0.004 * k), 1.0, (hr[0] * 1.035, hr[1] * 1.035, hr[2] * 0.985), False),
             ("ELLIPSOID", (0, hc.y - 0.006 * k, hc.z + hr[2] * 0.66), 1.0, (hr[0] * 0.96, hr[1] * 0.98, hr[2] * 0.64), False),
             # costeletas curtas ate o meio da concha do fone
             ("ELLIPSOID", (hr[0] * 0.92, hc.y + 0.030 * k, hc.z - 0.040 * k), 1.0, (0.020 * k, 0.026 * k, 0.050 * k), False),
             ("ELLIPSOID", (-hr[0] * 0.92, hc.y + 0.030 * k, hc.z - 0.040 * k), 1.0, (0.020 * k, 0.026 * k, 0.050 * k), False),
             # janela do rosto (linha do cabelo reta e alta de adulto)
             ("ELLIPSOID", (0, hc.y + hr[1] * 0.86, hc.z - 0.030 * k), 1.0, (hr[0] * 0.84, hr[1] * 0.56, 0.150 * k), True),
             # nuca curta: tira o que desceria abaixo da linha da orelha
             ("ELLIPSOID", (0, hc.y + hr[1] * 0.10, hc.z - 0.24 * k), 1.0, (hr[0] * 1.4, hr[1] * 1.3, 0.13 * k), True)]
        ob = hero_lib.metaball_obj(self.name("Hair"), E, M["cabelo"], res=0.009 * k, thresh=0.6)
        S.smooth_mesh(ob, 3, 0.5)
        S.decimate(ob, 0.22)
        self.hair_ob = ob
        self.reg(self.t(ob, "hair", "hair"), "single", "head")
        # cavanhaque curto: casca de fora do queixo (o que fica dentro do rosto sai), boca livre
        zc = hc.z - hr[2] * (1.0 + self.CHIN) + 0.030 * k
        E = [("ELLIPSOID", (0, hc.y + hr[1] * 0.66, zc - 0.002 * k), 1.0, (0.034 * k, 0.050 * k, 0.020 * k), False),
             ("ELLIPSOID", (0, hc.y + hr[1] * 0.98, hc.z - 0.112 * k), 1.0, (0.060 * k, 0.060 * k, 0.030 * k), True)]
        ob = hero_lib.metaball_obj(self.name("Beard"), E, M["cabelo"], res=0.006 * k, thresh=0.6)
        bm = bmesh.new()
        bm.from_mesh(ob.data)
        bvh = BVHTree.FromObject(self.head_ob, bpy.context.evaluated_depsgraph_get())
        inside = []
        for vv in bm.verts:
            loc, nrm, _, dist = bvh.find_nearest(vv.co)
            if loc is not None and (vv.co - loc).dot(nrm) < -0.002:
                inside.append(vv)
        bmesh.ops.delete(bm, geom=inside, context="VERTS")
        for vv in bm.verts:       # cola a barba no queixo: no maximo 9 mm para fora da pele
            loc, nrm, _, dist = bvh.find_nearest(vv.co)
            if loc is not None:
                off = (vv.co - loc).dot(nrm)
                if off > 0.0075 * k:
                    vv.co = loc + nrm * 0.0075 * k
        for _ in range(2):
            bmesh.ops.smooth_vert(bm, verts=bm.verts[:], factor=0.5, use_axis_x=True, use_axis_y=True, use_axis_z=True)
        bm.to_mesh(ob.data)
        bm.free()
        S.decimate(ob, 0.45)
        self.reg(self.t(ob, "beard", "hair"), "single", "head")
        return ob

    # ------------------------------------------------------------ fone de arco, microfone de haste e antena
    def hat(self):
        F, k = self.F, self.F.k
        hc, hr = F.hc, F.hr
        cx = hr[0] * 1.035 + 0.012 * k            # face interna da concha, encostada no cabelo
        cy = hc.y - 0.012 * k
        cz = hc.z - 0.030 * k
        cr = 0.044 * k                            # raio da concha
        dg = bpy.context.evaluated_depsgraph_get()
        bh = BVHTree.FromObject(self.hair_ob, dg)
        GEO.update(cup=(cx, cy, cz, cr))
        # arco: faixa achatada que sai do alto de cada concha e passa 7 mm acima do cabelo (raycast de fora para dentro)
        n = 25
        pts, nrms = [], []
        for i in range(n):
            a = math.radians(-82 + 164 * i / (n - 1))
            d = Vector((math.sin(a), 0.0, math.cos(a)))
            c0 = Vector((0, cy, cz + 0.020 * k))
            hit = bh.ray_cast(c0 + d * 0.6, -d)
            p = hit[0] if hit[0] is not None else c0 + d * (hr[0] * 1.1)
            pts.append(p + d * 0.007 * k)
            nrms.append(d)
        # pontas descem retas ate o topo das conchas
        for sx, idx in ((-1, 0), (1, -1)):
            p = pts[idx]
            pts_end = Vector((sx * (cx + 0.010 * k), cy, cz + cr * 0.75))
            if sx < 0:
                pts.insert(0, pts_end)
                nrms.insert(0, Vector((-1, 0, 0)))
            else:
                pts.append(pts_end)
                nrms.append(Vector((1, 0, 0)))
        bm = bmesh.new()
        W, Th = 0.013 * k, 0.0045 * k
        ring_prev = None
        rings = []
        for p, nv in zip(pts, nrms):
            b = Vector((0, 1, 0))
            prof = [(-W, -Th), (W, -Th), (W * 1.05, 0), (W, Th), (-W, Th), (-W * 1.05, 0)]
            ring = [bm.verts.new(p + b * u + nv * w) for u, w in prof]
            rings.append(ring)
        for ra, rb in zip(rings[:-1], rings[1:]):
            m_ = len(ra)
            for j in range(m_):
                bm.faces.new((ra[j], ra[(j + 1) % m_], rb[(j + 1) % m_], rb[j]))
        for ring in (rings[0], rings[-1]):
            bm.faces.new(ring)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
        band = new_object(self.name("HeadBand"), bm, self.M["chapeu"])
        md = band.modifiers.new("sub", "SUBSURF")
        md.levels = 1
        hero_lib.bake(band)
        self.reg(self.t(band, "band", "gear"), "single", "head")
        # conchas (torno ao longo de X), aro amarelo e almofada escura encostada no cabelo
        for sx, sd in ((1, "R"), (-1, "L")):
            Rm = Matrix.Translation((sx * cx, cy, cz)) @ Matrix.Rotation(math.radians(90 * sx), 4, "Y")
            bm = bmesh.new()
            cl.lathe(bm, [(0.0, 0.030 * k), (cr * 0.55, 0.030 * k), (cr * 0.88, 0.026 * k), (cr, 0.016 * k), (cr * 1.0, 0.006 * k),
                          (cr * 0.96, 0.0), (0.0, 0.0)], 28)
            cl.transform_bm(bm, Rm)
            self.reg(self.t(new_object(self.name("Cup" + sd), bm, self.M["couro"]), "cup", "gear"), "single", "head")
            bm = bmesh.new()
            cl.torus_z(bm, cr * 0.98, 0.0042 * k, 0.017 * k, major=28, minor=6)
            cl.transform_bm(bm, Rm)
            self.reg(self.t(new_object(self.name("CupRim" + sd), bm, self.M["chapeu"]), "cup_rim", "gear"), "single", "head")
            bm = bmesh.new()
            cl.torus_z(bm, cr * 0.72, 0.011 * k, -0.002 * k, major=24, minor=8)
            cl.transform_bm(bm, Rm)
            self.reg(self.t(new_object(self.name("Cushion" + sd), bm, self.M["escuro"]), "cushion", "gear"), "single", "head")
            # tampa do lado de fora com o disco central (botao) e o encaixe do arco
            bm = bmesh.new()
            cl.lathe(bm, [(0.0, 0.0365 * k), (cr * 0.40, 0.0360 * k), (cr * 0.46, 0.031 * k), (0.0, 0.031 * k)], 20)
            cl.transform_bm(bm, Rm)
            self.reg(self.t(new_object(self.name("CupCap" + sd), bm, self.M["chapeu"]), "cup_cap", "gear"), "single", "head")
        # haste do microfone: sai da concha esquerda, desce pela bochecha e para no canto da boca (6,5 cm do centro)
        mz = hc.z - 0.112 * k
        tip_x = -0.074 * k
        ty = (cl.snap_y(self.head_ob, tip_x, mz) or hc.y + hr[1]) + 0.030 * k
        p0 = Vector((-(cx + 0.026 * k), cy + 0.006 * k, cz - 0.010 * k))
        p1 = Vector((-(cx + 0.020 * k), cy + 0.050 * k, cz - 0.040 * k))
        p2 = Vector((-(hr[0] * 0.88), ty - 0.050 * k, mz - 0.006 * k))
        p3 = Vector((tip_x - 0.012 * k, ty - 0.008 * k, mz - 0.004 * k))
        pts = []
        for i in range(13):
            t = i / 12
            pts.append(p0 * (1 - t) ** 3 + p1 * 3 * t * (1 - t) ** 2 + p2 * 3 * t * t * (1 - t) + p3 * t ** 3)
        bm = bmesh.new()
        cl.tube(bm, pts, [0.0052 * k] * len(pts), 8, True)
        self.reg(self.t(new_object(self.name("MicBoom"), bm, self.M["chapeu"]), "boom", "gear"), "single", "head")
        bm = bmesh.new()
        dtip = (p3 - pts[-2]).normalized()
        cl.ellipsoid(bm, (0, 0, 0), (0.0115 * k, 0.0115 * k, 0.017 * k), 16, 10)
        cl.transform_bm(bm, Matrix.Translation(p3 + dtip * 0.010 * k) @ dtip.to_track_quat("Z", "Y").to_matrix().to_4x4())
        self.reg(self.t(new_object(self.name("MicTip"), bm, self.M["escuro"]), "mic", "gear"), "single", "head")
        # antena curta na concha direita (sobe e abre um pouco), com a bolinha coral
        a0 = Vector((cx + 0.024 * k, cy - 0.010 * k, cz + cr * 0.55))
        a1 = a0 + Vector((0.020 * k, -0.006 * k, 0.085 * k))
        bm = bmesh.new()
        cl.tube(bm, [a0, a0.lerp(a1, 0.5), a1], [0.0042 * k, 0.0036 * k, 0.0032 * k], 8, True)
        self.reg(self.t(new_object(self.name("Antenna"), bm, self.M["escuro"]), "antenna", "gear"), "single", "head")
        bm = bmesh.new()
        cl.ellipsoid(bm, a1 + Vector((0.002 * k, 0, 0.012 * k)), (0.017 * k,) * 3, 18, 12)
        self.reg(self.t(new_object(self.name("AntennaBall"), bm, self.M["couro"]), "antenna_ball", "gear"), "single", "head")
        GEO.update(antenna=tuple(a1), mic=tuple(p3))
        return []

    # ------------------------------------------------------------ jaqueta, calca e tenis
    def body(self):
        global HEM
        super().body()
        F = self.F
        HEM = F.hz - 0.05
        self.jacket = self.torso_shell("jacket", HEM, hem_flare=1.00, belly_k=0.98, chest_k=1.07, cuff_k=1.04)
        self.trousers()
        self.shoes(high=0.046)

    def uniform_details(self):
        F, k = self.F, self.F.k
        nz = F.nz
        jk = self.jacket
        # G21 r2: sem gola em pe (o anel abria e se via por dentro); a gola e baixa, canelada e pintada no topo da jaqueta,
        # com um filete amarelo (paint_cloth)
        bvh = BVHTree.FromObject(jk, bpy.context.evaluated_depsgraph_get())
        # emblema da Rota Brava no peito esquerdo (escudo azul, borda e estrela amarelas), colado na jaqueta
        ex, ez = -0.080, nz - 0.115
        hit = bvh.ray_cast(Vector((ex, 0.6, ez)), Vector((0, -1, 0)))
        loc = hit[0] if hit[0] is not None else Vector((ex, 0.13, ez))
        nrm = hit[1] if hit[1] is not None else Vector((0, 1, 0))
        nrm = Vector((nrm.x * 0.6, nrm.y, nrm.z * 0.6)).normalized()
        Tm = Matrix.Translation(loc + nrm * 0.0015) @ nrm.to_track_quat("Y", "Z").to_matrix().to_4x4()
        bm = bmesh.new()
        hero_lib.prism(bm, hero_lib.emblem_outline(0.064, 0.072), 0.004, (0, 0.000, 0))
        bmesh.ops.bevel(bm, geom=[e for e in bm.edges if len(e.link_faces) == 2 and e.calc_face_angle(0) > 0.6], offset=0.0012,
                        segments=2, affect="EDGES")
        cl.transform_bm(bm, Tm)
        self.reg(self.t(new_object(self.name("BadgeRim"), bm, self.M["creme"]), "badge_rim", "gear"), "torso")
        bm = bmesh.new()
        hero_lib.prism(bm, hero_lib.emblem_outline(0.052, 0.059), 0.003, (0, 0.0022, 0.0008))
        cl.transform_bm(bm, Tm)
        self.reg(self.t(new_object(self.name("Badge"), bm, self.M["emblema"]), "badge", "gear"), "torso")
        bm = bmesh.new()
        hero_lib.prism(bm, hero_lib.star4(0.019, 0.0065), 0.003, (0, 0.0045, 0.0015))
        cl.transform_bm(bm, Tm)
        self.reg(self.t(new_object(self.name("BadgeStar"), bm, self.M["creme"]), "badge_star", "gear"), "torso")
        # puxador do ziper logo abaixo da gola
        zy = (cl.snap_y(jk, 0.0, nz - 0.040) or 0.12) + 0.002
        bm = bmesh.new()
        cl.rounded_box(bm, (0.0, zy + 0.003, nz - 0.052), (0.012, 0.005, 0.026), 0.002)
        self.reg(self.t(new_object(self.name("ZipPull"), bm, self.M["creme"]), "zip_pull", "gear"), "torso")


# ------------------------------------------------------------------ pintura
CLOTH = {"jacket": dict(col=C["navy"], rough=0.60, kind="cloth", period=0.0019),
         "collar": dict(col=C["amarelo"], rough=0.55, kind="knit", period=0.0030),
         "trousers": dict(col=C["calca"], rough=0.70, kind="cloth", period=0.0020)}
GEAR = {"shoe": dict(col=C["tenis"], rough=0.55, kind="cloth", period=0.0016), "sole": dict(col=C["amarelo"], rough=0.45, kind="plastic"),
        "band": dict(col=C["amarelo"], rough=0.28, kind="plastic"), "cup": dict(col=C["concha"], rough=0.25, kind="plastic"),
        "cup_rim": dict(col=C["amarelo"], rough=0.28, kind="plastic"), "cup_cap": dict(col=C["amarelo"], rough=0.28, kind="plastic"),
        "cushion": dict(col=C["almofada"], rough=0.75, kind="leather"), "boom": dict(col=C["coral"], rough=0.30, kind="plastic"),
        "mic": dict(col=C["almofada"], rough=0.85, kind="felt"), "antenna": dict(col=C["almofada"], rough=0.35, kind="plastic"),
        "antenna_ball": dict(col=C["coral"], rough=0.22, kind="plastic"),
        "badge_rim": dict(col=C["amarelo"], rough=0.30, kind="plastic"), "badge": dict(col=C["emblema"], rough=0.32, kind="plastic"),
        "badge_star": dict(col=C["amarelo"], rough=0.30, kind="plastic"), "zip_pull": dict(col=C["ouro"], rough=0.25, metal=0.8, kind="metal")}


def coral_stripe(b, P):
    """Faixa coral: da gola, por cima do ombro e pela lateral de fora da manga ate o punho (os dois lados). 0..1."""
    F = b.F
    x, y, z = P[:, 0], P[:, 1], P[:, 2]
    out = np.zeros(len(P))
    w = 0.0115
    for kind, s, a, bb in b.limb_segs:
        sx = 1.0 if s == "R" else -1.0
        a, bb = np.array(a), np.array(bb)
        d = bb - a
        L = np.linalg.norm(d)
        dn = d / L
        u = (P - a) @ d / (L * L)
        proj = a + np.outer(np.clip(u, 0, 1), d)
        rv = P - proj
        r = np.linalg.norm(rv, axis=1)
        rn = rv / np.maximum(r[:, None], 1e-9)
        o = np.array([sx, 0.0, 0.0]) - dn * dn[0] * sx
        o /= np.linalg.norm(o)
        side = np.cross(dn, o)
        ang = np.arctan2(rn @ side, rn @ o)
        near = (r < b.v["limb"] * 1.7) & (u > -0.05) & (u < 1.02) & (sx * x > 0)
        out = np.maximum(out, S.line(ang * r, w) * near)
    # por cima do ombro: da gola ate a cabeca do braco, no meio (y ~ 0) da costura de cima
    top = (np.abs(x) > 0.060) & (np.abs(x) < F.sh.x + 0.03) & (z > F.nz - 0.09)
    out = np.maximum(out, S.line(y + 0.002, w) * top)
    return out


def poly_sdf(q, poly):
    """Distancia com sinal (negativa dentro) de pontos 2D `q` (n, 2) ao poligono `poly` (lista de (x, y))."""
    P = np.asarray(poly, dtype=float)
    A, B = P, np.roll(P, -1, axis=0)
    d = np.full(len(q), 1e9)
    inside = np.zeros(len(q), dtype=bool)
    for a, b in zip(A, B):
        e = b - a
        w = q - a
        t = np.clip((w @ e) / max(e @ e, 1e-12), 0, 1)
        d = np.minimum(d, np.linalg.norm(w - np.outer(t, e), axis=1))
        cond = ((a[1] > q[:, 1]) != (b[1] > q[:, 1]))
        xint = a[0] + (q[:, 1] - a[1]) * (b[0] - a[0]) / np.where(np.abs(b[1] - a[1]) < 1e-12, 1e-12, b[1] - a[1])
        inside ^= cond & (q[:, 0] < xint)
    return np.where(inside, -d, d)


def paint_cloth(b):
    F = b.F

    def fn(m):
        col, h, rough, metal = S.paint_table(m, parts, CLOTH)
        P, pid = m["P"], m["part"]
        x, y, z = P[:, 0], P[:, 1], P[:, 2]
        jk = pid == parts.pid("jacket")
        front = y > 0.02
        # faixa coral com pesponto nas duas bordas
        st = coral_stripe(b, P) * jk
        stp = S.sstep(st, 0.05, 0.25)
        col[:] = col * (1 - stp[:, None]) + S.lin(C["coral"]) * stp[:, None] * (0.92 + 0.10 * S.fbm(P, 0.003, 2))[:, None]
        h += 0.00018 * stp
        edge = S.line(stp - 0.5, 0.18) * jk
        col *= (1 - 0.18 * edge)[:, None]
        # barra e punhos canelados (malha azul mais escura, ribanas verticais)
        rib = np.zeros(len(P))
        rib = np.maximum(rib, S.sstep(z, HEM + 0.010, HEM + 0.016) * (1 - S.sstep(z, HEM + 0.052, HEM + 0.058)))
        for kind, s, a, bb in b.limb_segs:
            if kind != "forearm":
                continue
            a, bb = np.array(a), np.array(bb)
            d = bb - a
            L = np.linalg.norm(d)
            u = (P - a) @ d / (L * L)
            near = np.linalg.norm(P - (a + np.outer(np.clip(u, 0, 1), d)), axis=1) < b.v["limb"] * 1.7
            de = (0.93 - u) * L
            rib = np.maximum(rib, (S.sstep(de, -0.01, 0.0) * (1 - S.sstep(de, 0.045, 0.050))) * near)
        rib *= jk
        ang = np.arctan2(x, y + 0.0001)
        ribs = 0.5 + 0.5 * np.sin(ang * 140.0 + 0.0 * z)
        col[:] = col * (1 - rib[:, None]) + (S.lin(C["navy_lt"]) * (0.80 + 0.25 * ribs)[:, None]) * rib[:, None]
        h += 0.00035 * ribs * rib
        rough[:] = rough * (1 - rib) + 0.72 * rib
        # ziper no meio da frente (dentes e fita) da barra ate a gola
        zr = jk & front & (z > HEM + 0.010) & (z < F.nz - 0.006)
        tape = S.line(x, 0.0055) * zr
        col[:] = col * (1 - 0.55 * tape[:, None]) + S.lin("#07182C") * 0.55 * tape[:, None]
        teeth = S.line(x, 0.0024) * zr * (0.5 + 0.5 * np.sign(np.sin(2 * np.pi * z / 0.0042)))
        col[:] = col * (1 - 0.8 * teeth[:, None]) + S.lin(C["ouro"]) * 0.8 * teeth[:, None]
        metal[:] = np.maximum(metal, 0.6 * teeth)
        h += 0.0003 * teeth
        S.add_stitches(h, col, zr, np.abs(x) - 0.010, z, offset=0.0, w=0.0005)
        # bolsos em fenda com vivo amarelo fino
        for sx in (1, -1):
            pk = jk & front & (np.abs(x - sx * 0.088) < 0.040)
            dz = z - (HEM + 0.115) - 0.30 * sx * (x - sx * 0.088)
            L = S.add_line_detail(col, h, rough, pk, dz, 0.0026, depth=-0.0008, color="#061426", mix=0.8)
            S.add_line_detail(col, h, rough, pk, dz - 0.0040, 0.0011, depth=0.0002, color=C["amarelo"], mix=0.75)
        # costuras: ombro, cava, costas
        S.add_line_detail(col, h, rough, jk & (y < -0.02) & (z < F.nz - 0.05), x, 0.0016, depth=-0.0006, color="#07182C", mix=0.4)
        S.add_stitches(h, col, jk, z - (HEM + 0.060), np.arctan2(x, y) * 0.15, offset=0.003, w=0.0005)
        # emblema grande nas costas (escudo azul com borda e estrela amarelas): a equipe se le tambem de costas
        back = jk & (y < -0.03) & (z > F.nz - 0.32) & (z < F.nz - 0.03) & (np.abs(x) < 0.11)
        if back.any():
            ix = np.where(back)[0]
            ez = F.nz - 0.175
            q = np.column_stack([-x[ix], z[ix] - ez])
            dsh = poly_sdf(q, hero_lib.emblem_outline(0.170, 0.190, 40))
            dst = poly_sdf(q - np.array([0.0, 0.008]), hero_lib.star4(0.052, 0.018))
            rim, fill, stf = (np.zeros(len(P)) for _ in range(3))
            rim[ix] = S.sstep(-dsh, -0.0015, 0.0005)
            fill[ix] = S.sstep(-dsh, 0.0075, 0.0095)
            stf[ix] = S.sstep(-dst, -0.0008, 0.0008)
            col[:] = col * (1 - rim[:, None]) + S.lin(C["amarelo"]) * rim[:, None]
            col[:] = col * (1 - fill[:, None]) + S.lin("#173E6E") * fill[:, None]
            col[:] = col * (1 - stf[:, None]) + S.lin(C["amarelo"]) * stf[:, None]
            h += 0.00025 * np.maximum(rim - fill, 0) + 0.0002 * stf
            gl = np.clip(np.maximum(rim - fill, 0) + stf, 0, 1)
            rough[:] = rough * (1 - 0.4 * gl) + 0.40 * 0.4 * gl
        # calca: vinco e costura lateral, barra dobrada
        tr = pid == parts.pid("trousers")
        for sx in (1, -1):
            leg = tr & (sx * x > 0.0)
            S.add_line_detail(col, h, rough, leg & (z < F.hz - 0.08), x - sx * F.hip_x * 1.02, 0.0014, depth=0.0004, color=C["calca_dk"], mix=0.35)
        S.add_line_detail(col, h, rough, tr, z - (F.ankle_z + 0.090), 0.0018, depth=-0.0006, color=C["calca_dk"], mix=0.5)
        # gola baixa canelada (azul) no topo da jaqueta com filete amarelo na borda de cima e um filete fino embaixo
        neck = jk & (z > F.nz - 0.034)
        ang2 = np.arctan2(x, y + 0.0001)
        rb = 0.5 + 0.5 * np.sin(ang2 * 120.0)
        col[neck] = S.lin(C["navy_lt"]) * (0.82 + 0.22 * rb[neck])[:, None]
        h += 0.0003 * rb * neck
        rough[neck] = 0.72
        top = jk * S.sstep(z, F.nz + 0.004, F.nz + 0.008)
        fil = jk * S.line(z - (F.nz - 0.034), 0.0022)
        yl = np.clip(top + fil, 0, 1)
        col[:] = col * (1 - yl[:, None]) + S.lin(C["amarelo"]) * yl[:, None]
        h += 0.0002 * fil
        return col, h, rough, metal
    return fn


def paint_gear(b):
    F = b.F

    def fn(m):
        col, h, rough, metal = S.paint_table(m, parts, GEAR)
        P, pid = m["P"], m["part"]
        x, y, z = P[:, 0], P[:, 1], P[:, 2]
        sh = pid == parts.pid("shoe")
        if sh.any():
            # tenis: biqueira e calcanhar azuis-claros, faixa coral lateral, ilhoses e cadarco
            for sx in (1, -1):
                sel = sh & (sx * x > 0)
                toe = sel * S.sstep(y, F.ball_y * 0.95, F.ball_y * 1.25) * (1 - S.sstep(z, 0.055, 0.065))
                col[:] = col * (1 - toe[:, None]) + S.lin(C["tenis_dk"]) * toe[:, None]
                heel = sel * (1 - S.sstep(y, F.heel_y + 0.01, F.heel_y + 0.04))
                col[:] = col * (1 - heel[:, None]) + S.lin(C["navy"]) * heel[:, None]
                side = sel * S.line(z - 0.048 - 0.10 * (y - F.ball_y * 0.4), 0.006) * (np.abs(x - sx * F.hip_x) > 0.030)
                col[:] = col * (1 - side[:, None]) + S.lin(C["coral"]) * side[:, None]
                lace = sel * (np.abs(x - sx * F.hip_x) < 0.018) * S.sstep(y, 0.0, 0.02) * (1 - S.sstep(y, F.ball_y * 0.9, F.ball_y * 1.0))
                lines = 0.5 + 0.5 * np.sin(2 * np.pi * y / 0.014)
                h += 0.0005 * lace * lines
                col *= (1 - 0.12 * lace * lines)[:, None]
        so = pid == parts.pid("sole")
        if so.any():
            grooves = 0.5 + 0.5 * np.sin(2 * np.pi * y / 0.010)
            h += 0.0004 * grooves * so * (z < 0.012)
        bd = pid == parts.pid("band")
        if bd.any():      # arco: regulagem em degraus perto das conchas
            steps = (np.abs(x) > F.hr[0] * 0.80) * (0.5 + 0.5 * np.sign(np.sin(2 * np.pi * z / 0.006)))
            h += 0.0003 * steps * bd
        return col, h, rough, metal
    return fn


def paint_skin(b):
    F = b.F

    def fn(m):
        P = m["P"]
        n = len(P)
        col = np.tile(S.lin(C["pele"]), (n, 1))
        hc = np.array(F.hc)
        k = F.k
        head = np.isin(m["part"], [parts.pid("skin_head"), parts.pid("skin_nose")])
        for sx in (1, -1):        # rubor leve nas macas
            c = hc + np.array([sx * 0.085 * k, 0.14 * k, -0.070 * k])
            d = np.linalg.norm((P - c) / np.array([0.040, 0.08, 0.030]) / k, axis=1)
            w = np.exp(-d ** 2 * 1.6) * (P[:, 1] > hc[1])
            col = col * (1 - 0.22 * w[:, None]) + S.lin(C["rubor"]) * 0.22 * w[:, None]
        # sombra de barba rente: maxilar, queixo e buco (pontilhado fino), so na cabeca
        rel = (P - hc) / np.array(F.hr)
        jaw = S.sstep(-rel[:, 2], 0.42, 0.62) * S.sstep(rel[:, 1], -0.15, 0.20)
        lip = np.exp(-((rel[:, 2] + 0.53) / 0.07) ** 2) * np.exp(-(rel[:, 0] / 0.32) ** 2) * (rel[:, 1] > 0.6)
        mouth_free = 1 - np.exp(-((rel[:, 2] + 0.62) / 0.06) ** 2) * np.exp(-(rel[:, 0] / 0.22) ** 2)
        beard = np.clip(np.maximum(jaw, 0.7 * lip) * mouth_free, 0, 1) * head
        speck = S.sstep(S.fbm(P, 0.0011, 2), 0.45, 0.70)
        bw = beard * (0.12 + 0.16 * speck)
        col = col * (1 - bw[:, None]) + S.lin(C["barba"]) * bw[:, None]
        hand = m["part"] == parts.pid("skin_hand")
        col[hand] = col[hand] * 0.95 + S.lin(C["rubor"]) * 0.05
        mott = S.fbm(P, 0.03, 3)
        col *= (0.97 + 0.05 * mott)[:, None]
        col *= (0.84 + 0.16 * m["ao"] ** 0.7)[:, None]
        rough = 0.50 + 0.06 * (mott - 0.5) + 0.10 * beard
        h = 0.00003 * S.fbm(P, 0.0025, 2) + 0.00004 * speck * beard
        return col, h, rough, np.zeros(n)
    return fn


def paint_hair(b):
    F = b.F

    def fn(m):
        P, N = m["P"], m["N"]
        n = len(P)
        hc = np.array(F.hc)
        # crespo curto: cachos miudos (bolinhas de ruido de alta frequencia), sem mechas lisas
        coil = S.sstep(S.fbm(P, 0.0034, 2), 0.38, 0.72)
        coil2 = 1 - np.abs(2 * S.fbm(P + 1.7, 0.0012, 2) - 1)
        col = np.tile(S.lin(C["cabelo"]), (n, 1))
        lt = S.fbm(P, 0.018, 2)
        col = col * (1 - 0.30 * lt[:, None]) + S.lin(C["cabelo_lt"]) * 0.30 * lt[:, None]
        col *= (0.62 + 0.50 * coil + 0.10 * coil2)[:, None]
        col *= (0.72 + 0.28 * m["ao"] ** 0.8)[:, None]
        # laterais baixas: mais claras (pele aparece no degrade) perto da costeleta e da nuca
        beard = m["part"] == parts.pid("beard")
        col[beard] = S.lin(C["barba"]) * (0.85 + 0.35 * coil[beard])[:, None] * (0.80 + 0.20 * m["ao"][beard] ** 0.8)[:, None]
        rel = (P - hc) / np.array(F.hr)
        fade = S.sstep(-rel[:, 2], -0.10, 0.25) * (~beard)
        col = col * (1 - 0.22 * fade[:, None]) + S.lin(C["pele"]) * 0.22 * fade[:, None] * S.fbm(P, 0.0012, 1)[:, None]
        h = 0.0016 * coil + 0.0003 * coil2
        h *= (1 - 0.6 * fade)
        rough = 0.86 - 0.06 * coil          # G21 r2: fosco (na Godot o cabelo brilhava)
        return col, h, rough, np.zeros(n)
    return fn


# ------------------------------------------------------------------ clipes
def pose_idle_lumi(R, F, t, T):
    f = pose_idle_adult(R, F, t, T)
    f["atenta"] = 0.12
    return f


def pose_talk_lumi(R, F, t, T):
    """Fala no radio (3,0 s): bracos soltos junto ao corpo (sem o A do repouso), mao direita gesticula na frente do peito
    com a palma aberta, a esquerda descansa na lateral da coxa; acena com a cabeca; boca em silabas (visemas A/O/E)."""
    from char_anim import reach, stand_feet, torso
    ph = 2 * math.pi * t / T
    g = smooth(t, 0.15, 0.55) * (1 - smooth(t, T - 0.55, T - 0.10))
    R.hips_off = Vector((0.004 * math.sin(ph), 0.0, -0.008))
    torso(R, lean=2.0 + 1.0 * math.sin(2 * ph), yaw=5.0 * math.sin(ph) * g, roll=1.5 * math.sin(ph),
          head_pitch=4.0 * math.sin(3 * ph) * g, head_yaw=-7.0 * math.sin(ph) * g, head_roll=3.0 * math.sin(2 * ph + 0.5) * g)
    ha.arms_down(R, F, bend=20, out=-9)
    R.evaluate()
    rr, rl = R.tip("hand.R"), R.tip("hand.L")
    b = F.v["belly"]
    # mao direita aberta, palma para cima, ao lado do peito (gesto de "olha so"), indo e voltando em silabas
    # (na rodada 2a o alvo a 13 cm abaixo do ombro deixava a mao na altura da barriga: lia como braco caido)
    tgt_r = Vector((F.sh.x + 0.05 + 0.04 * math.sin(2 * ph), b + 0.20 + 0.03 * math.sin(3 * ph), F.sh.z - 0.02 + 0.05 * math.sin(2 * ph + 0.8)))
    reach(R, "R", rr.lerp(tgt_r, g), Vector((0.1, 0.2, -1.0)).lerp(Vector((0.55, 0.75, 0.35)), g), pole=(1.0, -0.5, -0.6),
          roll=-60.0 * g)
    # mao esquerda solta junto a coxa, com um balanco pequeno (sem a mao na cintura)
    tgt_l = rl + Vector((0.025, 0.03 + 0.015 * math.sin(2 * ph + 1.0), 0.02))
    reach(R, "L", rl.lerp(tgt_l, g), Vector((-0.1, 0.2, -1.0)), pole=(-1.0, -0.6, -0.2))
    stand_feet(R)
    f = ha.face(alegre=0.15, atenta=0.15, blink=blink_curve(t, 0.9) + blink_curve(t, 2.3))
    syl = abs(math.sin(2 * math.pi * 2.6 * t))
    pick = int(t * 5.2) % 3
    f["mouth_A"] = g * syl * (0.75 if pick == 0 else 0.25)
    f["mouth_O"] = g * syl * (0.65 if pick == 1 else 0.0)
    f["mouth_E"] = g * syl * (0.60 if pick == 2 else 0.0)
    return f


# ---- sentado na cadeira giratoria da base (G21 r2). O Lumi fica filho da cadeira (Farol7Base: Chair/Seat), que gira;
# o clipe nao gira o corpo inteiro: so a postura sentada e o gesto. Assento a 0,40 m do chao (com a canela de 0,29 m do
# Lumi, a 0,45 m a coxa descia ~20 graus e ele parecia escorregando da cadeira).
SEAT_TOP = 0.40


def seated_base(R, F, breath=0.0, lean=-4.0):
    from char_anim import put_foot, torso
    hip_z = SEAT_TOP + 0.075
    R.hips_off = Vector((0.0, -0.04, hip_z - F.hz + 0.003 * breath))
    torso(R, lean=lean + 1.0 * breath)
    for s, sx in (("R", 1), ("L", -1)):
        ankle = Vector((sx * (F.hip_x + 0.03), 0.30, F.ankle_z))
        put_foot(R, s, 0.0, 0.0, "heel", ankle=ankle, pole=(sx * 0.15, 1.0, 0.2))
    return hip_z


def lap_hands(R, F, u=1.0, hip_z=None):
    """Maos descansando sobre as coxas (u = 0: bracos soltos; 1: no colo)."""
    from char_anim import reach
    hz = hip_z if hip_z is not None else F.hz
    ha.arms_down(R, F, bend=30, out=-8)
    R.evaluate()
    for s, sx in (("R", 1), ("L", -1)):
        rest = R.tip("hand." + s)
        tgt = Vector((sx * (F.hip_x + 0.035), 0.20, hz + 0.075))
        reach(R, s, rest.lerp(tgt, u), Vector((0.1 * sx, 0.2, -1.0)).lerp(Vector((0.0, 1.0, -0.35)), u), pole=(sx * 1.0, -0.4, -0.2))


def pose_idle_seated(R, F, t, T):
    """Sentado na cadeira, de frente: respira, olha em volta, maos no colo (laco)."""
    ph = 2 * math.pi * t / T
    breath = math.sin(ph)
    hip_z = seated_base(R, F, breath)
    from char_anim import torso
    torso(R, lean=-4.0 + 1.0 * breath, roll=1.0 * math.sin(ph * 0.5), head_yaw=8.0 * math.sin(ph * 0.5 + 0.6),
          head_pitch=2.0 * math.sin(ph + 1.0), head_roll=1.5 * math.sin(ph + 2.0))
    lap_hands(R, F, 1.0, hip_z)
    return ha.face(atenta=0.15, alegre=0.12, blink=blink_curve(t, 1.0) + blink_curve(t, T - 0.7))


def pose_turn_chair(R, F, t, T):
    """Plano 9a (1,0 s): a cadeira gira de costas para a frente (quem gira e o no da cadeira). O corpo acompanha: comeca
    debrucado para a mesa com a mao direita no microfone, endireita, levanta a cabeca e chega na pose do idle_seated com
    um sorriso, de olhos abertos."""
    u = smooth(t, 0.05, 0.85)
    hip_z = seated_base(R, F, 0.0, lean=lerp(14.0, -4.0, u))
    from char_anim import reach, torso
    torso(R, lean=lerp(14.0, -4.0, u), yaw=lerp(-10.0, 0.0, u), head_pitch=lerp(-12.0, 0.0, u) + 6.0 * math.sin(math.pi * u),
          head_yaw=lerp(-8.0, 8.0 * math.sin(0.6), u))
    lap_hands(R, F, 1.0, hip_z)
    R.evaluate()
    a = 1.0 - smooth(t, 0.0, 0.55)
    if a > 0.0:
        rr = R.tip("hand.R")
        reach(R, "R", rr.lerp(Vector((0.10, 0.42, hip_z + 0.32)), a), Vector((0.0, 1.0, -0.35)).lerp(Vector((0.0, 0.8, 0.2)), a),
              pole=(1.0, -0.4, -0.2))
    # sorriso so pela boca: o "alegre" acima de ~0,3 ja fecha o olho em arco na Godot (G1)
    f = ha.face(atenta=0.15 * u, alegre=0.12)
    f["mouth_A"] = 0.30 * math.sin(math.pi * smooth(t, 0.4, 1.0))
    return f


def pose_wave_lumi(R, F, t, T):
    """Aceno de oi (1,6 s), sorriso aberto com os olhos abertos (regra G1)."""
    f = ha.pose_wave(R, F, t, T)
    a = f.get("alegre", 0.0)
    f["alegre"] = 0.15 * a                  # G21 r2: com 0,38 o olho ja virava arco fechado na Godot (regra G1)
    f["atenta"] = 0.20 * a
    f["mouth_A"] = 0.45 * a
    f["blink"] = blink_curve(t, 1.15)       # piscada longe do fim: o clipe sem laco para no ultimo quadro de olho aberto
    return f


def pose_point_lumi(R, F, t, T):
    """Aponta para a frente (a camera, plano 9c) na altura do ombro e volta."""
    f = ha.pose_point(R, F, t, T)
    f["alegre"] = 0.20 * smooth(t, 0.1, 0.4)
    f["blink"] = blink_curve(t, 0.70)       # (a piscada do hero_anim cai em 1,05-1,23 s e o clipe acabava de olho fechado)
    return f


CLIPS = {"idle": (3.6, True, pose_idle_lumi), "talk": (3.0, True, pose_talk_lumi), "wave": (1.6, False, pose_wave_lumi),
         "point": (1.2, False, pose_point_lumi), "idle_seated": (3.6, True, pose_idle_seated), "turn_chair": (1.0, False, pose_turn_chair)}
KEYS = tuple(ha.FACE_KEYS) + ("mouth_A", "mouth_O", "mouth_E")


def author(rig, face_ob, F):
    R = cl.Rigger(rig)
    sk = face_ob.data.shape_keys
    sk.animation_data_create()
    rig.animation_data_create()
    prev = {}
    for name, (dur, loop, fn) in CLIPS.items():
        act = bpy.data.actions.new(name)
        act.use_fake_user = True
        keyact = bpy.data.actions.new(name + "_key")
        keyact.use_fake_user = True
        rig.animation_data.action = act
        sk.animation_data.action = keyact
        n = int(round(dur * ha.FPS))
        prev.clear()
        for i in range(n + 1):
            t = dur * i / n
            R.reset()
            fc = fn(R, F, t, dur)
            R.evaluate()
            R.apply(i, prev)
            for kn in KEYS:
                kb = sk.key_blocks[kn]
                kb.value = max(0.0, min(1.0, fc.get(kn, 0.0)))
                kb.keyframe_insert("value", frame=i)
        act["loop"] = loop
        for ad, a_ in ((rig.animation_data, act), (sk.animation_data, keyact)):
            ad.action = None
            tr = ad.nla_tracks.new()
            tr.name = name
            st = tr.strips.new(name, 0, a_)
            st.name = name


# ------------------------------------------------------------------ montagem
def build(glb=None, blend=None):
    sc = reset_scene()
    sc.render.fps = ha.FPS
    b = Lumi()
    rig, objs = b.build(True)
    b.fix_skirt_weights(b.jacket, HEM)
    for ob in objs:
        if ob.name.endswith(("_HandR", "_HandL")):
            b.fix_wrist_weights(ob)
    rig["provisional"] = True
    rig["agent"] = "art3d"
    rig["variant"] = CID
    b.face_ob["rbgroup"] = "face"
    groups = S.join_groups(objs, "Lumi", parts, names={"cloth": "Lumi_Cloth", "skin": "Lumi_Skin", "hair": "Lumi_Hair",
                                                       "gear": "Lumi_Gear", "face": "Lumi_Face"})
    for g, res, paint, coat, cr in (("cloth", 2048, paint_cloth(b), 0.05, 0.5), ("skin", 1024, paint_skin(b), 0.30, 0.35),
                                    ("hair", 1024, paint_hair(b), 0.02, 0.9), ("gear", 1024, paint_gear(b), 0.55, 0.15)):
        S.apply_material(groups[g], S.texture_group(groups[g], "%s_%s" % (PREFIX, g), res, paint, TEX_DIR, coat=coat, coat_rough=cr))
    S.face_materials(groups["face"], PREFIX, C["iris"], C["pele"], mouth_hex=C["boca"], dark_hex="#1E1512")
    author(rig, groups["face"], b.F)
    # medidas na pose de repouso (a ultima trilha NLA e um clipe sentado e baixaria a altura medida)
    rig.data.pose_position = "REST"
    bpy.context.view_layer.update()
    info = S.base_info(list(groups.values()), rig, groups["face"], PREFIX)
    rig.data.pose_position = "POSE"
    bpy.context.view_layer.update()
    info.update({"head_h_m": round(b.F.head_h, 4), "head_ratio": round(b.F.head_h / info["height_m"], 4),
                 "loops": {k_: v[1] for k_, v in CLIPS.items()}, "walk_speed_mps": 0.0, "run_speed_mps": 0.0, "variant": CID,
                 "headset": {k_: [round(x, 4) for x in v] for k_, v in GEO.items()}})
    S.save(info, blend, glb)
    return info


if __name__ == "__main__":
    build(arg_value("--glb"), arg_value("--blend"))
