"""Dona Amora v2 (RB-R1 G4): a feirante da vila refeita no padrao do trio v2, com proporcao de ADULTA. PROVISORIO.

Mesma personagem do amora.glb e do retrato game/ui/brand/icons/vendor.svg (vestido roxo #7A3E9D, avental branco com
bolinhas de amora, lenco roxo com tres amoras e folha, coque, cabelo #5A2E3A, pele #D9976A), agora com proporcao de
senhora (cabeca ~22% da altura; antes 27%, lia como crianca), cabeca adulta (sv2_human.Adult), vestido inteirico
(blusa+saia rodada numa malha SKIN com SUBSURF 3), meia-calca, sapatos, avental com peitilho e alcas por cima, textura
assada e pintada no pipeline do trio (tecido, bolinhas e pespontos pintados). Mesmos clipes (idle, wave, thanks, point,
talk) do source_art/characters/amora/build_amora.py, importado so para leitura.

Uso (Linux):
  bash tools/blender.sh --background --factory-startup --python source_art/characters/secondary_v2/build_amora_v2.py -- \
      --glb $PWD/game/assets/models/characters/amora_v2.glb --blend $PWD/source_art/characters/secondary_v2/amora_v2.blend
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPTS = os.path.abspath(os.path.join(HERE, "..", "..", "scripts"))
AMORA = os.path.abspath(os.path.join(HERE, "..", "amora"))
for p in (HERE, SCRIPTS, AMORA):
    if p not in sys.path:
        sys.path.insert(0, p)

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

import build_amora as A1          # clipes da Dona Amora atual (so leitura)
import char_lib as cl
import hero_anim as ha
import hero_lib
import sv2_lib as S
from char_anim import lerp
from hero_lib import join_bm
from rbart import REPO, arg_value, new_object, reset_scene
from sv2_human import Adult, V, pose_idle_adult

CID = "amora_v2"
PREFIX = "amora_v2"
TEX_DIR = os.path.join(REPO, "captures", "g4", "build_textures", CID)
C = dict(pele="#D9976A", rubor="#E5806E", cabelo="#5A2E3A", cabelo_lt="#7A4352", vestido="#7A3E9D", vestido_dk="#62307F",
         creme="#F7FBFF", amora="#4A2370", meia="#4A2370", sapato="#6B3A2A", sola="#F2E4D0", folha="#3DBE5A", lenco="#8A49B0",
         iris="#4A3A6A", boca="#A0404A")
hero_lib.VARIANTS["AM2"] = dict(head=0.355, leg=0.760, torso=0.470, belly=0.172, sh_x=0.180, limb=0.055, hand=1.38, boot=1.05,
                                eye=0.74, layers=False, label="senhora v2")
hero_lib.CAST[CID] = dict(display="Amora", K=1.0, variant="AM2", hat="none", hair="short", team=False, gear=(), gloves=False,
                          pal=dict(pele=C["pele"], cabelo=C["cabelo"], iris=C["iris"], uniforme=C["vestido"], creme=C["creme"],
                                   calca=C["meia"], botas=C["sapato"], chapeu=C["lenco"], couro=C["sapato"], emblema="#123A5E",
                                   ouro="#FFC83D", olhos="#FFFFFF", escuro="#2A1A24", boca=C["boca"], rubor=C["rubor"]))
parts = S.Parts()
HEM = None
APRON = {}


class Amora(Adult):
    belly_bump = 0.016
    # G4 r2: rosto de senhora: mandibula mais afunilada e queixo mais longo, sem maca de bebe
    JAW, CHIN, CHEEK = 0.32, 0.14, -0.015

    def __init__(self):
        super().__init__(CID, "AM2", parts)

    # ------------------------------------------------------------ cabelo, coque, lenco
    def hair(self):
        F, k, M = self.F, self.F.k, self.M
        hc, hr = F.hc, F.hr
        E = [("ELLIPSOID", (0, hc.y - 0.016 * k, hc.z + 0.016 * k), 1.0, (hr[0] * 1.04, hr[1] * 1.03, hr[2] * 0.99), False),
             ("ELLIPSOID", (0, hc.y - hr[1] * 0.45, hc.z - 0.07 * k), 1.0, (hr[0] * 0.86, 0.080 * k, 0.11 * k), False),
             # janela do rosto com linha do cabelo repartida (testa livre)
             ("ELLIPSOID", (0, hc.y + hr[1] * 0.80, hc.z - 0.050 * k), 1.0, (hr[0] * 0.84, hr[1] * 0.56, 0.135 * k), True),
             ("ELLIPSOID", (0, hc.y + hr[1] * 0.25, hc.z - 0.22 * k), 1.0, (hr[0] * 1.3, hr[1] * 0.75, 0.12 * k), True)]
        ob = hero_lib.metaball_obj(self.name("Hair"), E, M["cabelo"], res=0.010 * k, thresh=0.6)
        S.smooth_mesh(ob, 3, 0.5)
        S.decimate(ob, 0.20)
        self.reg(self.t(ob, "hair", "hair"), "single", "head")
        # coque no alto (com anel de base e mecha em espiral)
        bm = bmesh.new()
        cz = hc.z + hr[2] * 1.00 + 0.036 * k
        by = hc.y - hr[1] * 0.12
        cl.ellipsoid(bm, (0, by, cz), (0.074 * k, 0.070 * k, 0.062 * k), 24, 14)
        tb = bmesh.new()
        cl.torus_z(tb, 0.048 * k, 0.019 * k, 0.0, major=22, minor=8)
        cl.transform_bm(tb, Matrix.Translation((0, by, cz - 0.044 * k)))
        join_bm(bm, tb)
        pts = [(math.cos(i / 13 * math.pi * 1.6) * 0.058 * k, by + math.sin(i / 13 * math.pi * 1.6) * 0.056 * k,
                cz - 0.010 * k + 0.030 * k * i / 13) for i in range(14)]
        cl.tube(bm, pts, [0.015 * k] * 14, 8, True)
        ob = new_object(self.name("Bun"), bm, M["cabelo"])
        S.decimate(ob, 0.6)
        self.reg(self.t(ob, "bun", "hair"), "single", "head")
        self.scarf()
        return ob

    def scarf(self):
        """Lenco roxo: faixa larga por cima da cabeca, na frente do coque, amarrada na nuca (laco e pontas); amoras e folha."""
        F, k, M = self.F, self.F.k, self.M
        hc, hr = F.hc, F.hr
        Sx = (hr[0] * 1.09, hr[1] * 1.09, hr[2] * 1.08)

        def on_head(d, grow=1.0):
            d = Vector(d).normalized()
            s = 1.0 / math.sqrt((d.x / Sx[0]) ** 2 + (d.y / Sx[1]) ** 2 + (d.z / Sx[2]) ** 2)
            return hc + d * s * grow

        pts = []
        N = 48
        for i in range(N):
            a = 2 * math.pi * i / N
            u = (1 - math.cos(a)) / 2
            pts.append(on_head((math.sin(a), lerp(0.30, -0.95, u), lerp(1.0, -0.35, u))))
        # G4 r3: tubo CICLICO (o anel N liga no anel 0). Antes o tubo aberto fechava emendando o fim no comeco bem no topo
        # da frente, com o referencial do fim girado em relacao ao do comeco: a costura aparecia em close.
        # Referencial de cada anel pelo raio da cabeca (sem deriva de transporte paralelo).
        bm = bmesh.new()
        sides = 12
        rings = []
        for i, p in enumerate(pts):
            t = (pts[(i + 1) % N] - pts[i - 1]).normalized()
            up = (p - hc).normalized()
            nn = (up - t * up.dot(t)).normalized()
            bb = t.cross(nn)
            r = 0.026 * k
            rings.append([bm.verts.new(p + (nn * math.cos(2 * math.pi * j / sides) + bb * math.sin(2 * math.pi * j / sides)) * r)
                          for j in range(sides)])
        for i in range(N):
            ra, rb = rings[i], rings[(i + 1) % N]
            for j in range(sides):
                bm.faces.new((ra[j], ra[(j + 1) % sides], rb[(j + 1) % sides], rb[j]))
        for vtx in bm.verts:
            base = on_head(vtx.co - hc)
            vtx.co = base + (vtx.co - base) * 0.45 + (base - hc).normalized() * 0.005 * k
        nape = on_head((0, -0.95, -0.35), 1.02)
        for sx in (1, -1):
            tb = bmesh.new()
            cl.ellipsoid(tb, (0, 0, 0), (0.036 * k, 0.014 * k, 0.024 * k), 16, 8)
            cl.transform_bm(tb, Matrix.Translation(nape + Vector((sx * 0.032 * k, -0.006, 0.004))) @ cl.rot_y(sx * 25))
            join_bm(bm, tb)
            tb = bmesh.new()
            cl.tube(tb, [nape + Vector((sx * 0.008, -0.004, -0.004)), nape + Vector((sx * 0.026 * k, -0.018, -0.050 * k)),
                         nape + Vector((sx * 0.040 * k, -0.020, -0.100 * k))], [0.016 * k, 0.013 * k, 0.006 * k], 8, True)
            join_bm(bm, tb)
        cl.ellipsoid(bm, nape + Vector((0, -0.008, 0)), (0.017 * k, 0.015 * k, 0.019 * k), 12, 8)
        self.reg(self.t(new_object(self.name("Scarf"), bm, M["chapeu"]), "scarf", "cloth"), "single", "head")
        a = -0.62
        u = (1 - math.cos(a)) / 2
        base = on_head((math.sin(a), lerp(0.30, -0.95, u), lerp(1.0, -0.35, u)), 1.06)
        nrm = (base - hc).normalized()
        bm = bmesh.new()
        for (ox, oz) in ((0.0, 0.0), (-0.040, -0.030), (0.012, -0.044)):
            c = base + Vector((ox * k, 0.012 * k, oz * k))
            for (dx, dy, dz) in ((0, 0, 0), (0.010, 0.006, 0.008), (-0.010, 0.006, 0.008), (0.010, 0.006, -0.008),
                                 (-0.010, 0.006, -0.008), (0, 0.012, 0)):
                cl.ellipsoid(bm, c + nrm * 0.004 + Vector((dx, dy, dz)) * k, (0.012 * k,) * 3, 8, 5)
        self.reg(self.t(new_object(self.name("Berries"), bm, M["chapeu"]), "berry", "gear"), "single", "head")
        bm = bmesh.new()
        cl.ellipsoid(bm, (0, 0, 0), (0.032 * k, 0.006 * k, 0.015 * k), 16, 8)
        for vv in bm.verts:   # folha com ponta
            vv.co.z *= 1.0 - 0.5 * max(0.0, vv.co.x / (0.032 * k)) ** 2
        q = nrm.to_track_quat("Y", "Z").to_matrix().to_4x4()
        cl.transform_bm(bm, Matrix.Translation(base + Vector((0.030 * k, 0.010 * k, 0.034 * k))) @ q @ Matrix.Rotation(math.radians(40), 4, "Y"))
        self.reg(self.t(new_object(self.name("Leaf"), bm, M["chapeu"]), "leaf", "gear"), "single", "head")

    # ------------------------------------------------------------ vestido, meia e sapatos
    def body(self):
        global HEM
        super().body()
        F = self.F
        HEM = F.knee_z * 0.62
        self.dress = self.torso_shell("dress", HEM, hem_flare=1.62, belly_k=1.08, chest_k=1.10, cuff_k=1.05, decim=0.15)
        self.trousers(part="tights", top_r=self.v["belly"] * 0.80, hem_up=0.035)
        self.shoes(high=0.030)

    def uniform_details(self):
        F, k, M = self.F, self.F.k, self.M
        hz, nz = F.hz, F.nz
        dress = self.dress
        bvh = BVHTree.FromObject(dress, bpy.context.evaluated_depsgraph_get())

        def out_at(z, a, off):
            d = Vector((math.sin(a), math.cos(a), 0.0))
            o = Vector((0, 0, z)) + d * 1.0
            hit = bvh.ray_cast(o, -d)
            p = hit[0] if hit[0] is not None else Vector((0, 0, z)) + d * 0.2
            return p + d * off
        # avental (parte de baixo): lamina por cima da frente da saia, ate perto da barra
        zt, zb = hz - 0.010, HEM + 0.050
        rows, cols = 10, 14
        A0, A1_ = -0.95, 0.95
        bm = bmesh.new()
        grid = []
        for i in range(rows + 1):
            z = zt - (zt - zb) * i / rows
            grid.append([bm.verts.new(out_at(z, A0 + (A1_ - A0) * j / cols, 0.007)) for j in range(cols + 1)])
        for i in range(rows):
            for j in range(cols):
                bm.faces.new((grid[i][j], grid[i + 1][j], grid[i + 1][j + 1], grid[i][j + 1]))
        bmesh.ops.solidify(bm, geom=bm.faces[:], thickness=0.004)
        APRON.update(zt=zt, zb=zb)
        self.reg(self.t(new_object(self.name("Apron"), bm, M["creme"]), "apron", "cloth"), "xfer:Dress")
        # peitilho colado na frente da blusa, com bolso
        z0, z1 = hz + 0.020, nz - 0.090
        bm = bmesh.new()
        grid = []
        rows, cols = 8, 8
        for i in range(rows + 1):
            z = z0 + (z1 - z0) * i / rows
            w = lerp(0.115, 0.088, i / rows)
            row = []
            for j in range(cols + 1):
                x = -w + 2 * w * j / cols
                y = (cl.snap_y(dress, x, z) or 0.12) + 0.006
                row.append(bm.verts.new((x, y, z)))
            grid.append(row)
        for i in range(rows):
            for j in range(cols):
                bm.faces.new((grid[i][j], grid[i][j + 1], grid[i + 1][j + 1], grid[i + 1][j]))
        bmesh.ops.solidify(bm, geom=bm.faces[:], thickness=0.004)
        APRON.update(bib=(z0, z1))
        self.reg(self.t(new_object(self.name("ApronBib"), bm, M["creme"]), "bib", "cloth"), "torso")
        # alcas ate a nuca, cinta e laco nas costas
        bm = bmesh.new()
        for sx in (1, -1):
            x0 = sx * 0.086
            y0 = (cl.snap_y(dress, x0, z1) or 0.12) + 0.006
            pts = [(x0, y0, z1), (sx * 0.078, y0 - 0.012, nz - 0.040), (sx * 0.068, 0.032, nz - 0.004),
                   (sx * 0.048, -0.028, nz + 0.004), (sx * 0.012, -0.058, nz - 0.012)]
            cl.tube(bm, pts, 0.0090, 8, True)
        wz = hz + 0.016
        hit = [out_at(wz, a, 0.006) for a in (0.0, math.pi / 2)]
        ry, rx = hit[0].y, hit[1].x
        cl.torus_z(bm, rx, 0.011, wz, sy=ry / rx, major=36, minor=6)
        by = -(ry + 0.010)
        for sx in (1, -1):
            tb = bmesh.new()
            cl.ellipsoid(tb, (0, 0, 0), (0.044, 0.013, 0.026), 16, 8)
            cl.transform_bm(tb, Matrix.Translation((sx * 0.036, by, wz + 0.004)) @ cl.rot_y(sx * 20))
            join_bm(bm, tb)
            tb = bmesh.new()
            cl.tube(tb, [(sx * 0.010, by, wz - 0.005), (sx * 0.026, by - 0.004, wz - 0.065), (sx * 0.032, by - 0.002, wz - 0.120)],
                    [0.011, 0.010, 0.007], 8, True)
            join_bm(bm, tb)
        cl.ellipsoid(bm, (0, by - 0.002, wz + 0.002), (0.015, 0.013, 0.017), 12, 8)
        self.reg(self.t(new_object(self.name("ApronTies"), bm, M["creme"]), "ties", "cloth"), "torso")
        # gola redonda branca
        bm = bmesh.new()
        cl.torus_z(bm, 0.060 * k + 0.004, 0.016, 0.0, sy=0.92, major=28, minor=8)
        cl.transform_bm(bm, Matrix.Translation((0, 0.004, nz - 0.010)) @ Matrix.Rotation(math.radians(12), 4, "X"))
        self.reg(self.t(new_object(self.name("Collar"), bm, M["creme"]), "collar", "cloth"), "torso")
        # amora de pano no bolso do peitilho
        py = (cl.snap_y(dress, 0.0, z0 + 0.10) or 0.12) + 0.012
        bm = bmesh.new()
        for (dx, dz) in ((-0.011, 0.0), (0.011, 0.0), (0.0, 0.015), (0.0, -0.013)):
            cl.ellipsoid(bm, (dx, py + 0.004, z0 + 0.090 + dz), (0.010, 0.005, 0.010), 10, 6)
        self.reg(self.t(new_object(self.name("BibBerry"), bm, M["chapeu"]), "berry", "gear"), "torso")


# ------------------------------------------------------------------ pintura
CLOTH = {"dress": dict(col=C["vestido"], rough=0.62, kind="cloth", period=0.0020), "apron": dict(col=C["creme"], rough=0.58, kind="cloth", period=0.0016),
         "bib": dict(col=C["creme"], rough=0.58, kind="cloth", period=0.0016), "ties": dict(col=C["creme"], rough=0.58, kind="cloth"),
         "collar": dict(col=C["creme"], rough=0.55, kind="cloth"), "scarf": dict(col=C["lenco"], rough=0.55, kind="cloth", period=0.0018),
         "tights": dict(col=C["meia"], rough=0.55, kind="knit", period=0.0035)}
GEAR = {"shoe": dict(col=C["sapato"], rough=0.32, kind="leather"), "sole": dict(col=C["sola"], rough=0.6, kind="leather"),
        "berry": dict(col=C["amora"], rough=0.18, kind="plastic"), "leaf": dict(col=C["folha"], rough=0.35, kind="plastic")}


def dots(P, centers, r=0.0105):
    """Cachos de 4 bolinhas (amoras) pintados: devolve a mascara 0..1."""
    w = np.zeros(len(P))
    for c in centers:
        for d in ((-0.012, 0.0), (0.012, 0.0), (0.0, 0.012), (0.0, -0.012)):
            q = np.array([c[0] + d[0], c[1] + d[1]])
            dist = np.sqrt((P[:, 0] - q[0]) ** 2 + (P[:, 2] - q[1]) ** 2)
            w = np.maximum(w, 1 - S.sstep(dist, r * 0.75, r))
    return w


def paint_cloth(b):
    F = b.F

    def fn(m):
        col, h, rough, metal = S.paint_table(m, parts, CLOTH)
        P, pid = m["P"], m["part"]
        x, y, z = P[:, 0], P[:, 1], P[:, 2]
        dr = pid == parts.pid("dress")
        # punhos brancos pintados na barra das mangas
        for kind, s, a, bb in b.limb_segs:
            if kind != "forearm":
                continue
            a, bb = np.array(a), np.array(bb)
            d = bb - a
            L = np.linalg.norm(d)
            u = (P - a) @ d / (L * L)
            near = np.linalg.norm(P - (a + np.outer(np.clip(u, 0, 1), d)), axis=1) < b.v["limb"] * 1.6
            cuff = (1 - S.sstep((0.90 - u) * L, 0.022, 0.026)) * dr * near
            col[:] = col * (1 - cuff[:, None]) + S.lin(C["creme"]) * cuff[:, None] * (0.85 + 0.15 * m["ao"][:, None])
            S.add_stitches(h, col, dr & near, (0.90 - u) * L - 0.024, np.arctan2(P[:, 0] - a[0], P[:, 1]) * 0.03, offset=0.0, w=0.0005)
        # pregas da saia: sombras verticais suaves e barra com pesponto
        ang = np.arctan2(x, y)
        skirt = dr & (z < F.hz)
        pleat = 0.5 + 0.5 * np.cos(ang * 10)
        col[skirt] *= (0.92 + 0.08 * pleat[skirt])[:, None]
        h[skirt] += 0.0008 * pleat[skirt]
        S.add_stitches(h, col, dr, z - (HEM + 0.030), ang * 0.15, offset=0.004, w=0.0005)
        # avental: bolinhas de amora, barra e pespontos; peitilho: bolso
        ap = np.isin(pid, [parts.pid("apron"), parts.pid("bib")]) & (y > 0)
        cen = [(-0.10, F.hz - 0.12), (0.09, F.hz - 0.16), (0.0, F.hz - 0.26), (-0.07, F.hz - 0.36), (0.08, F.hz - 0.40),
               (-0.13, F.hz - 0.24), (0.14, F.hz - 0.30)]
        dm = dots(P, cen) * ap * (pid == parts.pid("apron"))
        col[:] = col * (1 - dm[:, None]) + S.lin(C["amora"]) * dm[:, None]
        h += 0.0003 * dm
        apr = pid == parts.pid("apron")
        S.add_stitches(h, col, apr, z - (APRON["zb"] + 0.014), x, offset=0.0, w=0.0005, darken=0.2)
        z0, z1 = APRON["bib"]
        bib = pid == parts.pid("bib")
        pk = bib & (np.abs(x) < 0.050) & (z < z0 + 0.13) & (z > z0 + 0.04)
        edge = np.minimum(np.abs(np.abs(x) - 0.046), np.abs(z - (z0 + 0.128)))
        S.add_stitches(h, col, bib & (np.abs(x) < 0.050) & (z < z0 + 0.132) & (z > z0 + 0.035), edge, x + z, offset=0.0, w=0.0005, darken=0.2)
        # lenco: listras finas de bolinhas claras
        sc = pid == parts.pid("scarf")
        sp = (np.sin(P[:, 0] / 0.006) * np.sin(P[:, 2] / 0.006) > 0.85) * sc
        col[:] = col * (1 - 0.35 * sp[:, None]) + S.lin("#C9A6E0") * 0.35 * sp[:, None]
        return col, h, rough, metal
    return fn


def paint_gear(b):
    def fn(m):
        col, h, rough, metal = S.paint_table(m, parts, GEAR)
        P = m["P"]
        br = m["part"] == parts.pid("berry")
        # brilho e graos da amora
        g = S.fbm(P, 0.003, 2)
        col[br] *= (0.8 + 0.4 * g[br])[:, None]
        h[br] += 0.0004 * g[br]
        lf = m["part"] == parts.pid("leaf")
        if lf.any():
            col[lf] *= (0.9 + 0.2 * S.fbm(P[lf], 0.004, 2))[:, None]
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
        for sx in (1, -1):
            c = hc + np.array([sx * 0.088 * k, 0.14 * k, -0.075 * k])
            d = np.linalg.norm((P - c) / np.array([0.045, 0.08, 0.032]) / k, axis=1)
            w = np.exp(-d ** 2 * 1.6) * (P[:, 1] > hc[1])
            col = col * (1 - 0.45 * w[:, None]) + S.lin(C["rubor"]) * 0.45 * w[:, None]
        for c, s, a in (((0, 0.19 * k, -0.07 * k), 0.032 * k, 0.25),):
            d = np.linalg.norm(P - (hc + np.array(c)), axis=1) / s
            w = np.exp(-d ** 2) * a
            col = col * (1 - w[:, None]) + S.lin(C["rubor"]) * w[:, None]
        # linhas de sorriso (senhora): dois arcos suaves do nariz ao canto da boca, e um leve vinco embaixo dos olhos
        h = 0.00003 * S.fbm(P, 0.0025, 2)
        front = P[:, 1] > hc[1] + 0.05 * k
        for sx in (1, -1):
            c = hc + np.array([sx * 0.016 * k, 0.15 * k, -0.075 * k])
            r = np.sqrt(((P[:, 0] - c[0]) / 1.0) ** 2 + ((P[:, 2] - c[2]) / 1.25) ** 2)
            arc = S.line(r - 0.050 * k, 0.0040 * k) * front * (sx * P[:, 0] > 0.030 * k) * (P[:, 2] < hc[2] - 0.065 * k) * (P[:, 2] > hc[2] - 0.135 * k)
            col *= (1 - 0.16 * arc)[:, None]
            h -= 0.00050 * arc
            # pes de galinha: tres riscos curtos saindo do canto de fora do olho
            co_ = hc + np.array([sx * 0.100 * k, 0.12 * k, -0.040 * k])
            for ang in (-0.45, 0.0, 0.45):
                dvec = np.array([sx * math.cos(ang), 0.0, math.sin(ang)])
                rel = P - co_
                along = rel @ dvec
                perp = np.linalg.norm(rel - np.outer(along, dvec), axis=1)
                crow = S.line(perp, 0.0018 * k) * (along > 0.002 * k) * (along < 0.020 * k) * front
                col *= (1 - 0.08 * crow)[:, None]
                h -= 0.00020 * crow
            ce = hc + np.array([sx * 0.060 * k, 0.15 * k, -0.062 * k])
            und = S.line(np.sqrt((P[:, 0] - ce[0]) ** 2 + ((P[:, 2] - ce[2]) * 2.2) ** 2) - 0.030 * k, 0.0025 * k) * front * (P[:, 2] < ce[2])
            col *= (1 - 0.06 * und)[:, None]
        mott = S.fbm(P, 0.03, 3)
        col *= (0.97 + 0.05 * mott)[:, None]
        col *= (0.84 + 0.16 * m["ao"] ** 0.7)[:, None]
        rough = 0.50 + 0.06 * (mott - 0.5)
        return col, h, rough, np.zeros(n)
    return fn


def paint_hair(b):
    F = b.F

    def fn(m):
        P, N = m["P"], m["N"]
        n = len(P)
        hc = np.array(F.hc)
        top = hc + np.array([0, -0.02, F.hr[2] * 1.1])
        f = top - P                                   # puxado para o coque
        bun = m["part"] == parts.pid("bun")
        f[bun] = np.cross(P[bun] - top, np.array([0, 0, 1.0]))
        f = f - N * np.einsum("ij,ij->i", f, N)[:, None]
        f /= np.maximum(np.linalg.norm(f, axis=1)[:, None], 1e-6)
        st = S.fur_noise(P, f, N, across=0.0014, along=0.020)
        fine = S.fur_noise(P + 0.4, f, N, across=0.0006, along=0.008)
        col = np.tile(S.lin(C["cabelo"]), (n, 1))
        col = col * (0.80 + 0.35 * st[:, None]) + S.lin(C["cabelo_lt"]) * 0.10 * fine[:, None]
        # G4 r3: grisalho em MECHAS (antes uma faixa larga e lisa de 55-85% da largura da cabeca lia como casca/halo):
        # so na tempora e acima da orelha, so nos fios (liga e desliga pelo ruido dos fios), cinza-acastanhado de
        # contraste moderado contra o castanho, mais alguns fios soltos no resto do cabelo
        temple = S.sstep(np.abs(P[:, 0]), F.hr[0] * 0.55, F.hr[0] * 0.65)
        temple *= S.sstep(P[:, 1], hc[1] - 0.05, hc[1] + 0.0) * S.sstep(-(P[:, 2] - (hc[2] + 0.10)), 0.0, 0.04)
        # mechas: o cabelo e puxado para o coque, entao os fios correm da linha do cabelo ate o alto; as mechas sao faixas
        # finas no azimute em torno do eixo vertical da cabeca (largura de alguns mm), com a fase variando pouco ao longo
        az = np.arctan2(P[:, 0] - hc[0], P[:, 1] - hc[1])
        ph = az * 120.0 + 6.0 * S.fbm(P, 0.03, 2)
        lane = 0.5 + 0.5 * np.sin(ph)
        sel_lane = S.sstep(np.sin(az * 9.0 + 1.3 * S.fbm(P + 5.0, 0.05, 2)), -0.35, 0.15)    # so algumas faixas viram grisalho
        strand_on = S.sstep(lane, 0.70, 0.90) * sel_lane * (0.55 + 0.45 * S.sstep(S.fbm(P + 9.0, 0.012, 2), 0.35, 0.6))
        grey = np.clip(temple * strand_on, 0, 1)
        col = col * (1 - 0.70 * grey[:, None]) + S.lin("#A39599") * 0.70 * grey[:, None]
        col *= (0.75 + 0.25 * m["ao"] ** 0.8)[:, None]
        return col, 0.0006 * st + 0.0002 * fine, 0.40 - 0.10 * st, np.zeros(n)
    return fn


# ------------------------------------------------------------------ montagem
def mature_face(face_ob, eye_info, k):
    """G4 r2 (senhora): sobrancelhas mais finas (o tubo afina em volta da linha do meio) e olhos levemente caidos (cada olho
    gira ~7 graus em torno do proprio centro, canto de fora para baixo). Aplicado igual em todas as shape keys, sobre o
    rosto do hero_face (que nao e alterado)."""
    me = face_ob.data
    dark = set()
    for poly in me.polygons:
        if poly.material_index == 2:
            dark.update(poly.vertices)
    basis = [v.co.copy() for v in me.vertices]
    brow = sorted(i for i in dark if any(basis[i].z > I["c"].z + I["ez"] + 0.010 * k and abs(basis[i].x - I["c"].x) < 0.06 * k
                                           for I in eye_info.values()))
    runs, cur = [], []
    for i in brow:
        if cur and i != cur[-1] + 1:
            runs.append(cur)
            cur = []
        cur.append(i)
    if cur:
        runs.append(cur)
    eye_sets = {}
    for s_, I in eye_info.items():
        c, ex, ez = I["c"], I["ex"], I["ez"]
        eye_sets[s_] = [i for i, b in enumerate(basis) if abs(b.x - c.x) < ex * 1.45 and abs(b.z - c.z) < ez * 1.40
                        and i not in brow and b.y > c.y - ex * 0.8]
    for kb in me.shape_keys.key_blocks:
        co = kb.data
        for run in runs:
            nring = (len(run) - 2) // 6
            centers = []
            for r in range(nring):
                idx = run[r * 6:(r + 1) * 6]
                cc = sum((co[i].co for i in idx), Vector()) / 6.0
                centers.append(cc)
                for i in idx:
                    co[i].co = cc + (co[i].co - cc) * 0.55
            for i in run[nring * 6:]:
                cc = min(centers, key=lambda q: (q - co[i].co).length)
                co[i].co = cc + (co[i].co - cc) * 0.55
        for s_, I in eye_info.items():
            c = I["c"]
            th = math.radians(7.0) * I["sx"]
            cs, sn = math.cos(th), math.sin(th)
            for i in eye_sets[s_]:
                p_ = co[i].co
                dx, dz = p_.x - c.x, p_.z - c.z
                co[i].co = Vector((c.x + dx * cs + dz * sn, p_.y, c.z - dx * sn + dz * cs))
    kb0 = me.shape_keys.key_blocks[0].data
    for i, v in enumerate(me.vertices):
        v.co = kb0[i].co
    return {"sobrancelha_vertices": len(brow), "olho_vertices": {s_: len(v) for s_, v in eye_sets.items()}}


def pose_idle_amora_v2(R, F, t, T):
    f = pose_idle_adult(R, F, t, T)
    f["atenta"] = 0.10
    return f


def kind_lids(fn):
    """Palpebra de cima um pouco baixa (olhar de senhora simpatica) por baixo das piscadas do clipe."""
    def w(R, F, t, T):
        f = fn(R, F, t, T)
        f["blink"] = max(f.get("blink", 0.0), 0.12)
        return f
    return w


def build(glb=None, blend=None):
    sc = reset_scene()
    sc.render.fps = ha.FPS
    b = Amora()
    rig, objs = b.build(True)
    b.fix_skirt_weights(b.dress, HEM)
    for ob in objs:
        if ob.name.endswith(("_HandR", "_HandL")):
            b.fix_wrist_weights(ob)
    face_rep = mature_face(b.face_ob, b.eye_info, b.F.k)
    print("ROSTO", face_rep)
    for ob in objs:
        if ob.name.endswith("_Apron"):
            b.fix_skirt_weights(ob, HEM)
    rig["provisional"] = True
    rig["agent"] = "art3d"
    rig["variant"] = CID
    b.face_ob["rbgroup"] = "face"
    groups = S.join_groups(objs, "Amora", parts, names={"cloth": "Amora_Cloth", "skin": "Amora_Skin", "hair": "Amora_Hair",
                                                        "gear": "Amora_Gear", "face": "Amora_Face"})
    for g, res, paint, coat, cr in (("cloth", 2048, paint_cloth(b), 0.05, 0.5), ("skin", 1024, paint_skin(b), 0.30, 0.35),
                                    ("hair", 1024, paint_hair(b), 0.35, 0.30), ("gear", 512, paint_gear(b), 0.7, 0.10)):
        S.apply_material(groups[g], S.texture_group(groups[g], "%s_%s" % (PREFIX, g), res, paint, TEX_DIR, coat=coat, coat_rough=cr))
    S.face_materials(groups["face"], PREFIX, C["iris"], C["pele"], mouth_hex=C["boca"], dark_hex="#2A1A24")
    # G4 r2: idle relaxado (bracos soltos, respiracao) no lugar do idle em A; palpebra levemente baixa no idle
    # (so no idle: somada ao sorriso do talk/point a palpebra fechava o olho e os brilhos ficavam soltos)
    A1.CLIPS["idle"] = (3.6, True, kind_lids(pose_idle_amora_v2))
    A1.author(rig, groups["face"], b.F)
    bpy.context.view_layer.update()
    info = S.base_info(list(groups.values()), rig, groups["face"], PREFIX)
    info.update({"head_h_m": round(b.F.head_h, 4), "head_ratio": round(b.F.head_h / info["height_m"], 4),
                 "loops": {k_: v[1] for k_, v in A1.CLIPS.items()}, "walk_speed_mps": 0.0, "run_speed_mps": 0.0, "variant": CID})
    S.save(info, blend, glb)
    return info


if __name__ == "__main__":
    build(arg_value("--glb"), arg_value("--blend"))
