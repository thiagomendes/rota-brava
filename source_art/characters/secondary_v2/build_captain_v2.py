"""Capitao v2 (RB-R1 G4): o capitao do barco refeito no padrao do trio v2, com proporcao ADULTA. PROVISORIO.

Personagem original do projeto: senhor de barba branca aparada, quepe branco de capitao (faixa marinho, cordao e emblema
da Rota Brava dourados, pala preta envernizada), casaco marinho de lã trespassado ate o meio da coxa (gola em pe,
lapelas, 6 botoes dourados, platinas, dois galoes dourados no punho), calca marinho com vinco, sapatos de couro.
Base adulta em sv2_human.py; textura e material no pipeline do trio (sv2_lib -> rv2_tex). Mesmo esqueleto de 28 ossos e
mesmos clipes do capitao atual (idle, walk, wave, thanks; hero_anim), velocidades recalculadas pela proporcao nova.

Uso (Linux):
  bash tools/blender.sh --background --factory-startup --python source_art/characters/secondary_v2/build_captain_v2.py -- \
      --glb $PWD/game/assets/models/characters/captain_v2.glb --blend $PWD/source_art/characters/secondary_v2/captain_v2.blend
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

import char_lib as cl
import hero_anim as ha
import hero_lib
import sv2_lib as S
from hero_lib import join_bm
from rbart import REPO, arg_value, new_object, reset_scene
from sv2_human import Adult, V, pose_idle_adult

CID = "captain_v2"
PREFIX = "captain_v2"
TEX_DIR = os.path.join(REPO, "captures", "g4", "build_textures", CID)
C = dict(pele="#E7B08A", rubor="#E58C7A", cabelo="#D9DCE2", cabelo_dk="#A9AFB8", navy="#22406E", navy_dk="#1A3155",
         calca="#1E3354", branco="#F7FBFF", ouro="#FFC83D", couro="#3A2418", sola="#2A1E18", preto="#16181D",
         emblema="#123A5E", iris="#3A6E8A", boca="#8E3A44")
# proporcao adulta (metros, ja na escala final): cabeca 0,37 m em ~1,75 m de altura (21%)
hero_lib.VARIANTS["CAP2"] = dict(head=0.370, leg=0.810, torso=0.520, belly=0.170, sh_x=0.200, limb=0.058, hand=1.45, boot=1.20,
                                 eye=0.88, layers=False, label="adulto v2")
hero_lib.CAST[CID] = dict(display="Captain", K=1.0, variant="CAP2", hat="captain", hair="short", beard=True, team=False, gear=(),
                          gloves=False, pal=dict(pele=C["pele"], cabelo=C["cabelo"], iris=C["iris"], uniforme=C["navy"],
                                                 creme=C["branco"], calca=C["calca"], botas=C["couro"], chapeu=C["branco"],
                                                 couro=C["couro"], emblema=C["emblema"], ouro=C["ouro"], olhos="#FFFFFF",
                                                 escuro="#2A2228", boca=C["boca"], rubor=C["rubor"]))
parts = S.Parts()
HEM = None


class Captain(Adult):
    belly_bump = 0.020

    def __init__(self):
        super().__init__(CID, "CAP2", parts)

    # ------------------------------------------------------------ cabelo e barba
    def hair(self):
        F, k = self.F, self.F.k
        hc, hr = F.hc, F.hr
        ear = (hr[0] * 0.97, hc.y - 0.010 * k, hc.z - 0.034 * k)
        E = [("ELLIPSOID", (0, hc.y - 0.034 * k, hc.z - 0.020 * k), 1.0, (hr[0] * 0.94, hr[1] * 0.95, hr[2] * 0.66), False),
             # orelhas livres
             ("ELLIPSOID", ear, 1.0, (0.030 * k, 0.040 * k, 0.050 * k), True),
             ("ELLIPSOID", (-ear[0], ear[1], ear[2]), 1.0, (0.030 * k, 0.040 * k, 0.050 * k), True),
             # janela do rosto e da testa (o quepe cobre o alto)
             ("ELLIPSOID", (0, hc.y + hr[1] * 0.80, hc.z + 0.010 * k), 1.0, (hr[0] * 0.86, hr[1] * 0.60, hr[2] * 0.70), True),
             # costeletas que descem ate a barba
             ("ELLIPSOID", (hr[0] * 0.86, hc.y + 0.030 * k, hc.z - 0.090 * k), 1.0, (0.024 * k, 0.030 * k, 0.060 * k), False),
             ("ELLIPSOID", (-hr[0] * 0.86, hc.y + 0.030 * k, hc.z - 0.090 * k), 1.0, (0.024 * k, 0.030 * k, 0.060 * k), False)]
        ob = hero_lib.metaball_obj(self.name("Hair"), E, self.M["cabelo"], res=0.010 * k, thresh=0.6)
        bm = bmesh.new()
        bm.from_mesh(ob.data)
        # tira o que ficaria dentro do rosto abaixo das orelhas na frente
        capz = hc.z + hr[2] * 0.58
        kill = [vv for vv in bm.verts if (vv.co.y > hc.y + hr[1] * 0.30 and vv.co.z < hc.z - 0.02 * k and abs(vv.co.x) < hr[0] * 0.72)
                or vv.co.z > capz]
        bmesh.ops.delete(bm, geom=kill, context="VERTS")
        for _ in range(2):
            bmesh.ops.smooth_vert(bm, verts=bm.verts[:], factor=0.5, use_axis_x=True, use_axis_y=True, use_axis_z=True)
        bm.to_mesh(ob.data)
        bm.free()
        S.decimate(ob, 0.35)
        self.reg(self.t(ob, "hair", "hair"), "single", "head")
        # barba cheia aparada (contorna a mandibula, deixa a boca livre) e bigode
        E = [("ELLIPSOID", (0, hc.y + hr[1] * 0.42, hc.z - 0.150 * k), 1.0, (0.120 * k, 0.112 * k, 0.090 * k), False),
             ("ELLIPSOID", (0, hc.y + hr[1] * 0.60, hc.z - 0.205 * k), 1.0, (0.070 * k, 0.070 * k, 0.040 * k), False),
             ("BALL", (0.098 * k, hc.y + 0.020 * k, hc.z - 0.105 * k), 0.050 * k, None, False),
             ("BALL", (-0.098 * k, hc.y + 0.020 * k, hc.z - 0.105 * k), 0.050 * k, None, False),
             # boca e labio de baixo livres
             ("ELLIPSOID", (0, hc.y + hr[1] * 0.98, hc.z - 0.112 * k), 1.0, (0.052 * k, 0.060 * k, 0.020 * k), True),
             # bochechas livres acima da linha da barba
             ("ELLIPSOID", (0, hc.y + hr[1] * 0.62, hc.z - 0.030 * k), 1.0, (hr[0] * 0.95, hr[1] * 0.55, 0.060 * k), True)]
        ob = hero_lib.metaball_obj(self.name("Beard"), E, self.M["cabelo"], res=0.008 * k, thresh=0.6)
        bm = bmesh.new()
        bm.from_mesh(ob.data)
        # so a casca de fora da cabeca (o que fica dentro do rosto sai)
        bvh = __import__("mathutils").bvhtree.BVHTree.FromObject(self.head_ob, bpy.context.evaluated_depsgraph_get())
        inside = []
        for vv in bm.verts:
            loc, nrm, _, dist = bvh.find_nearest(vv.co)
            if loc is not None and (vv.co - loc).dot(nrm) < -0.002:
                inside.append(vv)
        bmesh.ops.delete(bm, geom=inside, context="VERTS")
        for _ in range(2):
            bmesh.ops.smooth_vert(bm, verts=bm.verts[:], factor=0.5, use_axis_x=True, use_axis_y=True, use_axis_z=True)
        bm.to_mesh(ob.data)
        bm.free()
        S.decimate(ob, 0.30)
        self.reg(self.t(ob, "beard", "hair"), "single", "head")
        bm = bmesh.new()
        for sx in (1, -1):
            tb = bmesh.new()
            cl.ellipsoid(tb, (0, 0, 0), (0.040 * k, 0.020 * k, 0.015 * k), 16, 8)
            for vv in tb.verts:                  # bigode: cai para fora e afina na ponta
                u = abs(vv.co.x) / (0.040 * k)
                vv.co.z -= 0.010 * k * u * u
                vv.co.y -= 0.010 * k * u * u
            yy = (cl.snap_y(self.head_ob, sx * 0.030 * k, hc.z - 0.094 * k) or hc.y + hr[1]) + 0.004 * k
            cl.transform_bm(tb, Matrix.Translation((sx * 0.034 * k, yy, hc.z - 0.094 * k)) @ cl.rot_y(-sx * 8))
            join_bm(bm, tb)
        self.reg(self.t(new_object(self.name("Mustache"), bm, self.M["cabelo"]), "mustache", "hair"), "single", "head")

    # ------------------------------------------------------------ quepe
    def hat(self):
        F, k = self.F, self.F.k
        hc, hr = F.hc, F.hr
        z0 = hc.z + hr[2] * 0.47
        z1 = hc.z + hr[2] * 0.86
        # giro em torno do centro da cabeca (pivo no cranio, nao na origem)
        tilt = Matrix.Translation((0, hc.y - 0.010 * k, hc.z + 0.004 * k)) @ Matrix.Rotation(math.radians(4), 4, "X") \
            @ Matrix.Translation((0, 0, -hc.z))
        rx0, ry0 = self.head_r_at(z0)
        sy = ry0 / rx0
        R0 = rx0 + 0.010 * k
        # faixa (marinho) e copa (branca) por torno
        bm = bmesh.new()
        prof = [(R0 * 0.93, z0 - 0.002), (R0, z0), (R0 + 0.002, (z0 + z1) * 0.5), (R0 + 0.004, z1), (R0 * 0.93, z1 - 0.002)]
        cl.lathe(bm, prof, 48)
        cl.transform_bm(bm, Matrix.Translation((0, 0, 0)) @ Matrix.Diagonal((1, sy, 1, 1)))
        cl.transform_bm(bm, tilt)
        band = self.t(new_object(self.name("CapBand"), bm, self.M["uniforme"]), "cap_band", "cloth")
        self.reg(band, "single", "head")
        Rt = R0 * 1.30
        zt = z1 + 0.060 * k
        prof = [(R0 + 0.003, z1 - 0.004), (R0 + 0.010, z1 + 0.010 * k), (Rt * 0.98, zt - 0.020 * k), (Rt, zt - 0.006 * k),
                (Rt * 0.96, zt + 0.004 * k), (Rt * 0.70, zt + 0.012 * k), (Rt * 0.30, zt + 0.016 * k), (0.0, zt + 0.017 * k)]
        bm = bmesh.new()
        cl.lathe(bm, prof, 40, deform=lambda r, z, a: (r, z + (0.012 * k * (r / Rt) ** 2) * max(0.0, math.cos(a))))
        cl.transform_bm(bm, Matrix.Diagonal((1, sy * 1.02, 1, 1)))
        cl.transform_bm(bm, Matrix.Translation((0, 0.010 * k, 0)))
        cl.transform_bm(bm, tilt)
        crown = self.t(new_object(self.name("CapCrown"), bm, self.M["chapeu"]), "cap_crown", "cloth")
        self.reg(crown, "single", "head")
        # pala: meia-lua curva, inclinada para baixo, com espessura
        bm = bmesh.new()
        rows = []
        nu, nv = 24, 5
        for i in range(nu + 1):
            a = math.radians(-70 + 140 * i / nu)
            row = []
            for j in range(nv + 1):
                t = j / nv
                ext = 0.078 * k * math.cos(a * 0.9) ** 0.7
                r = R0 + ext * t
                zz = z0 + 0.002 - 0.012 * k * t - 0.030 * k * t * t
                row.append(bm.verts.new((r * math.sin(a), r * math.cos(a) * sy, zz)))
            rows.append(row)
        for i in range(nu):
            for j in range(nv):
                bm.faces.new((rows[i][j], rows[i + 1][j], rows[i + 1][j + 1], rows[i][j + 1]))
        bmesh.ops.solidify(bm, geom=bm.faces[:], thickness=0.004)
        cl.transform_bm(bm, tilt)
        visor = self.t(new_object(self.name("CapVisor"), bm, self.M["escuro"], recalc=True), "visor", "gear")
        self.reg(visor, "single", "head")
        # cordao dourado na frente da faixa e dois botoezinhos
        pts = []
        for i in range(13):
            a = math.radians(-62 + 124 * i / 12)
            zz = z0 + 0.010 * k
            pts.append((math.sin(a) * (R0 + 0.004), math.cos(a) * (R0 + 0.004) * sy, zz))
        bm = bmesh.new()
        cl.tube(bm, pts, 0.0042 * k, 8, True)
        for sx in (1, -1):
            a = math.radians(sx * 62)
            cl.ellipsoid(bm, (math.sin(a) * (R0 + 0.006), math.cos(a) * (R0 + 0.006) * sy, z0 + 0.010 * k), (0.007 * k,) * 3, 10, 6)
        cl.transform_bm(bm, tilt)
        self.reg(self.t(new_object(self.name("CapCord"), bm, self.M["ouro"]), "cord", "gear"), "single", "head")
        # emblema da Rota Brava na frente da faixa (escudo marinho, borda e estrela douradas)
        zc = (z0 + z1) * 0.5 + 0.004
        yc = R0 * sy + 0.002
        Tm = tilt @ Matrix.Translation((0, yc, zc))
        bm = bmesh.new()
        hero_lib.prism(bm, hero_lib.emblem_outline(0.050 * k, 0.056 * k), 0.005, (0, -0.002, 0))
        bmesh.ops.bevel(bm, geom=[e for e in bm.edges if len(e.link_faces) == 2 and e.calc_face_angle(0) > 0.6], offset=0.0015,
                        segments=2, affect="EDGES")
        cl.transform_bm(bm, Tm)
        self.reg(self.t(new_object(self.name("CapBadgeRim"), bm, self.M["ouro"]), "badge_rim", "gear"), "single", "head")
        bm = bmesh.new()
        hero_lib.prism(bm, hero_lib.emblem_outline(0.040 * k, 0.045 * k), 0.004, (0, 0.000, 0.001))
        prism_star = bmesh.new()
        hero_lib.prism(prism_star, hero_lib.star4(0.015 * k, 0.005 * k), 0.003, (0, 0.004, 0.002))
        cl.transform_bm(bm, Tm)
        self.reg(self.t(new_object(self.name("CapBadge"), bm, self.M["emblema"]), "badge", "gear"), "single", "head")
        cl.transform_bm(prism_star, Tm)
        self.reg(self.t(new_object(self.name("CapStar"), prism_star, self.M["ouro"]), "badge_star", "gear"), "single", "head")
        return []

    # ------------------------------------------------------------ casaco
    def body(self):
        global HEM
        super().body()
        F = self.F
        HEM = F.hz - 0.22
        self.coat = self.torso_shell("coat", HEM, hem_flare=1.12, belly_k=1.06, chest_k=1.04)
        self.trousers()
        self.shoes(shaft=(0.125, 0.045))   # G23: bota de cano por dentro da barra

    def uniform_details(self):
        F, k = self.F, self.F.k
        nz, hz = F.nz, F.hz
        coat = self.coat
        # gola em pe (mais alta atras, aberta na frente) e colarinho branco com as pontas em V
        bm = bmesh.new()
        rows = []
        nu, nv = 36, 3
        for i in range(nu + 1):
            a = math.radians(30 + 300 * i / nu)
            back = 0.5 - 0.5 * math.cos(a)
            ring = []
            for j in range(nv + 1):
                t = j / nv
                h = (0.030 + 0.016 * back) * t
                r = 0.060 * k + 0.004 + (0.006 + 0.006 * back) * t ** 1.4
                ring.append(bm.verts.new((r * math.sin(a) * 1.08, r * math.cos(a) + 0.004, nz - 0.010 + h)))
            rows.append(ring)
        for i in range(nu):
            for j in range(nv):
                bm.faces.new((rows[i][j], rows[i + 1][j], rows[i + 1][j + 1], rows[i][j + 1]))
        ob = new_object(self.name("Collar"), bm, self.M["uniforme"], recalc=False)
        sol = ob.modifiers.new("sol", "SOLIDIFY")
        sol.thickness = 0.008
        sol.offset = 1.0
        hero_lib.bake(ob)
        self.reg(self.t(ob, "coat_collar", "cloth"), "torso")
        bm = bmesh.new()
        for sx in (1, -1):
            y = (cl.snap_y(coat, sx * 0.018, nz - 0.030) or 0.11) + 0.004
            hero_lib.prism(bm, [(0, 0.020), (sx * 0.034, 0.010), (sx * 0.022, -0.034), (0, -0.016)], 0.005, (0, y - 0.006, nz - 0.020))
        self.reg(self.t(new_object(self.name("ShirtCollar"), bm, self.M["creme"]), "shirt", "cloth"), "torso")
        # lapelas: abas triangulares sobre o peito, coladas ao casaco
        bm = bmesh.new()
        for sx in (1, -1):
            pts2 = [(sx * 0.028, nz - 0.020), (sx * 0.092, nz - 0.055), (sx * 0.080, nz - 0.090), (sx * 0.050, nz - 0.150)]
            vs = []
            for (x, z) in pts2:
                y = (cl.snap_y(coat, x, z) or 0.11) + 0.003
                vs.append((x, y, z))
            front = [bm.verts.new(p) for p in vs]
            back = [bm.verts.new((p[0], p[1] - 0.006, p[2])) for p in vs]
            f = bm.faces.new(front if sx < 0 else list(reversed(front)))
            bm.faces.new(list(reversed(back)) if sx < 0 else back)
            for i in range(4):
                j = (i + 1) % 4
                try:
                    bm.faces.new((front[i], front[j], back[j], back[i]) if sx > 0 else (front[j], front[i], back[i], back[j]))
                except ValueError:
                    pass
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
        lap = new_object(self.name("Lapels"), bm, self.M["uniforme"])
        md = lap.modifiers.new("sub", "SUBSURF")
        md.levels = 2
        hero_lib.bake(lap)
        self.reg(self.t(lap, "lapel", "cloth"), "torso")
        # botoes dourados (trespassado: 2 colunas de 3) e um em cada punho
        bm = bmesh.new()
        for x in (0.052, -0.040):
            for z in (nz - 0.175, nz - 0.270, nz - 0.365):
                y = (cl.snap_y(coat, x, z) or 0.12) + 0.001
                tb = bmesh.new()
                cl.lathe(tb, [(0.0, 0.0065), (0.009, 0.0055), (0.0115, 0.0025), (0.0115, 0.0), (0.0, 0.0)], 20)
                cl.transform_bm(tb, Matrix.Translation((x, y, z)) @ Matrix.Rotation(math.radians(-90), 4, "X"))
                join_bm(bm, tb)
        self.reg(self.t(new_object(self.name("Buttons"), bm, self.M["ouro"]), "button", "gear"), "torso")
        # platinas nos ombros (marinho com borda dourada pintada)
        for sx, sd in ((1, "R"), (-1, "L")):
            ex = sx * F.sh.x * 0.80
            ez = (self.snap_z(coat, ex, -0.002) or F.sh.z + 0.06) + 0.002
            ez2 = (self.snap_z(coat, ex + sx * 0.035, -0.002) or ez) + 0.002
            ang = math.degrees(math.atan2(ez - ez2, 0.035))
            c = V(ex, -0.002, ez + 0.003)
            bm = bmesh.new()
            cl.rounded_box(bm, (0, 0, 0), (0.076, 0.046, 0.008), 0.004)
            cl.transform_bm(bm, Matrix.Translation(c) @ cl.rot_y(sx * ang))
            self.reg(self.t(new_object(self.name("Epaulet" + sd), bm, self.M["uniforme"]), "epaulet", "cloth"), "single", "shoulder." + sd)


# ------------------------------------------------------------------ pintura
CLOTH = {"coat": dict(col=C["navy"], rough=0.66, kind="cloth", period=0.0020), "coat_collar": dict(col=C["navy"], rough=0.64, kind="cloth"),
         "lapel": dict(col=C["navy_dk"], rough=0.60, kind="cloth"), "trousers": dict(col=C["calca"], rough=0.68, kind="cloth"),
         "shirt": dict(col=C["branco"], rough=0.55, kind="cloth", period=0.0016), "cap_band": dict(col=C["navy_dk"], rough=0.70, kind="felt"),
         "cap_crown": dict(col=C["branco"], rough=0.55, kind="cloth", period=0.0018), "epaulet": dict(col=C["navy_dk"], rough=0.6, kind="felt")}
GEAR = {"shoe": dict(col=C["couro"], rough=0.30, kind="leather"), "sole": dict(col=C["sola"], rough=0.6, kind="leather"),
        "button": dict(col=C["ouro"], rough=0.25, metal=0.8, kind="metal"), "visor": dict(col=C["preto"], rough=0.12, kind="plastic"),
        "cord": dict(col=C["ouro"], rough=0.35, metal=0.6, kind="metal"), "badge_rim": dict(col=C["ouro"], rough=0.25, metal=0.8, kind="metal"),
        "badge": dict(col=C["emblema"], rough=0.3, kind="plastic"), "badge_star": dict(col=C["ouro"], rough=0.25, metal=0.8, kind="metal")}


def paint_cloth(b):
    F = b.F

    def fn(m):
        col, h, rough, metal = S.paint_table(m, parts, CLOTH)
        P, pid = m["P"], m["part"]
        x, y, z = P[:, 0], P[:, 1], P[:, 2]
        coat = (pid == parts.pid("coat"))
        front = y > 0.02
        # galoes dourados nos punhos: duas faixas ao redor do antebraco perto da barra da manga
        for kind, s, a, bb in b.limb_segs:
            if kind != "forearm":
                continue
            a, bb = np.array(a), np.array(bb)
            d = bb - a
            L = np.linalg.norm(d)
            u = (P - a) @ d / (L * L)
            dist_end = (0.90 - u) * L
            near = np.linalg.norm(P - (a + np.outer(np.clip(u, 0, 1), d)), axis=1) < b.v["limb"] * 1.6
            for c0, w in ((0.020, 0.0055), (0.040, 0.0035)):
                band = S.line(dist_end - c0, w) * coat * near
                col[:] = col * (1 - band[:, None]) + S.lin(C["ouro"]) * band[:, None]
                rough[:] = rough * (1 - band) + 0.32 * band
                metal[:] = np.maximum(metal, 0.55 * band)
                h += 0.00025 * band
        # abertura do trespassado (borda da frente a direita), barra, bolsos, costura das costas e dos ombros
        tor = coat & (np.abs(x) < b.v["belly"] * 1.3)
        open_x = 0.088
        S.add_line_detail(col, h, rough, tor & front & (z < F.nz - 0.13), x - open_x, 0.0022, depth=-0.0007, color=C["navy_dk"], mix=0.6)
        S.add_stitches(h, col, tor & front & (z < F.nz - 0.13), x - open_x + 0.006, z, offset=0.0, w=0.0005)
        for sx in (1, -1):
            pk = tor & front & (np.abs(x - sx * 0.10) < 0.055) & (sx * x > 0.04)
            S.add_line_detail(col, h, rough, pk, z - (F.hz - 0.050), 0.0020, depth=-0.0008, color=C["navy_dk"], mix=0.7)
            S.add_stitches(h, col, pk, z - (F.hz - 0.050) + 0.008, x, offset=0.0, w=0.0005)
        S.add_line_detail(col, h, rough, coat & (y < -0.02) & (z < F.hz + 0.05), x, 0.0018, depth=-0.0008, color=C["navy_dk"], mix=0.5)
        S.add_line_detail(col, h, rough, coat & (z > F.nz - 0.08), np.abs(x) - F.sh.x * 0.62, 0.0018, depth=-0.0005)
        # barra: pesponto duplo perto da borda de baixo
        S.add_stitches(h, col, coat, z - (HEM + 0.030), np.arctan2(x, y) * 0.15, offset=0.004, w=0.0005)
        # calca: vinco na frente e atras de cada perna
        tr = pid == parts.pid("trousers")
        for sx in (1, -1):
            leg = tr & (sx * x > 0.0)
            S.add_line_detail(col, h, rough, leg & (z < F.hz - 0.08), x - sx * F.hip_x * 1.02, 0.0016, depth=0.0005, color="#2E4A72", mix=0.35)
        # quepe: costura da copa (anel) e da faixa
        cr = pid == parts.pid("cap_crown")
        rr = np.sqrt(x ** 2 + ((y - F.hc.y) / 1.0) ** 2)
        S.add_line_detail(col, h, rough, cr, rr - F.hr[0] * 1.25, 0.0018, depth=-0.0005, color="#DDE3EA", mix=0.5)
        # platinas: borda dourada (franja curta pintada)
        ep = pid == parts.pid("epaulet")
        if ep.any():
            for sx in (1, -1):
                sel = ep & (sx * x > 0)
                cx = sx * F.sh.x * 0.82
                dd = np.maximum(np.abs(x - cx) - 0.036, np.abs(y + 0.002) - 0.017)
                edge = S.sstep(dd, -0.006, -0.002) * sel
                col[:] = col * (1 - edge[:, None]) + S.lin(C["ouro"]) * edge[:, None]
                metal[:] = np.maximum(metal, 0.5 * edge)
        return col, h, rough, metal
    return fn


def paint_gear(b):
    def fn(m):
        col, h, rough, metal = S.paint_table(m, parts, GEAR)
        P, pid = m["P"], m["part"]
        sh = pid == parts.pid("shoe")
        if sh.any():
            # costura da gaspea (anel ao redor do peito do pe) e brilho de graxa na ponta
            for sx in (1, -1):
                sel = sh & (sx * P[:, 0] > 0)
                d = np.linalg.norm((P - np.array([sx * b.F.hip_x, b.F.ball_y * 0.55, 0.05])) / np.array([1.0, 1.25, 1.0]), axis=1) - 0.060
                S.add_stitches(h, col, sel, d, np.arctan2(P[:, 0] - sx * b.F.hip_x, P[:, 1]) * 0.05, offset=0.0, w=0.0006, darken=0.3)
            toe = sh * S.sstep(P[:, 1], b.F.ball_y, b.F.toe_y)
            rough[:] = rough - 0.12 * toe
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
        for sx in (1, -1):        # rubor e nariz/orelhas mais quentes
            c = hc + np.array([sx * 0.090 * k, 0.14 * k, -0.075 * k])
            d = np.linalg.norm((P - c) / np.array([0.045, 0.08, 0.032]) / k, axis=1)
            w = np.exp(-d ** 2 * 1.6) * (P[:, 1] > hc[1])
            col = col * (1 - 0.40 * w[:, None]) + S.lin(C["rubor"]) * 0.40 * w[:, None]
        for c, s, a in (((0, 0.19 * k, -0.07 * k), 0.035 * k, 0.30), ((0.17 * k, -0.01, -0.034 * k), 0.035 * k, 0.25),
                        ((-0.17 * k, -0.01, -0.034 * k), 0.035 * k, 0.25)):
            d = np.linalg.norm(P - (hc + np.array(c)), axis=1) / s
            w = np.exp(-d ** 2) * a
            col = col * (1 - w[:, None]) + S.lin(C["rubor"]) * w[:, None]
        # nos dos dedos e palma levemente mais rosados
        hand = m["part"] == parts.pid("skin_hand")
        col[hand] = col[hand] * 0.94 + S.lin(C["rubor"]) * 0.06
        mott = S.fbm(P, 0.03, 3)
        col *= (0.97 + 0.05 * mott)[:, None]
        col *= (0.84 + 0.16 * m["ao"] ** 0.7)[:, None]
        rough = 0.50 + 0.06 * (mott - 0.5)
        h = 0.00003 * S.fbm(P, 0.0025, 2)
        return col, h, rough, np.zeros(n)
    return fn


def paint_hair(b):
    F = b.F

    def fn(m):
        P, N = m["P"], m["N"]
        n = len(P)
        hc = np.array(F.hc)
        # fluxo: cabelo penteado para tras e para baixo; barba e bigode para baixo/fora
        f = np.tile([0.0, -0.5, -1.0], (n, 1))
        beard = np.isin(m["part"], [parts.pid("beard"), parts.pid("mustache")])
        f[beard] = np.column_stack([P[beard, 0] - hc[0], np.zeros(beard.sum()), -np.ones(beard.sum()) * 0.08])
        f = f - N * np.einsum("ij,ij->i", f, N)[:, None]
        f /= np.maximum(np.linalg.norm(f, axis=1)[:, None], 1e-6)
        st = S.fur_streaks(P, f, scale=0.008)
        fine = S.fur_streaks(P + 0.21, f, scale=0.0035)
        col = np.tile(S.lin(C["cabelo"]), (n, 1))
        dk = S.fbm(P, 0.02, 2)
        col = col * (1 - 0.35 * dk[:, None]) + S.lin(C["cabelo_dk"]) * 0.35 * dk[:, None]
        col *= (0.82 + 0.22 * st + 0.05 * fine)[:, None]
        col *= (0.76 + 0.24 * m["ao"] ** 0.8)[:, None]
        h = 0.0007 * st + 0.0002 * fine
        rough = 0.50 - 0.10 * st
        return col, h, rough, np.zeros(n)
    return fn


# ------------------------------------------------------------------ montagem
def build(glb=None, blend=None):
    sc = reset_scene()
    sc.render.fps = ha.FPS
    b = Captain()
    rig, objs = b.build(True)
    b.fix_skirt_weights(b.coat, HEM)
    for ob in objs:
        if ob.name.endswith(("_HandR", "_HandL")):
            b.fix_wrist_weights(ob)
    rig["provisional"] = True
    rig["agent"] = "art3d"
    rig["variant"] = CID
    b.face_ob["rbgroup"] = "face"
    groups = S.join_groups(objs, "Captain", parts, names={"cloth": "Captain_Cloth", "skin": "Captain_Skin", "hair": "Captain_Hair",
                                                          "gear": "Captain_Gear", "face": "Captain_Face"})
    for g, res, paint, coat, cr in (("cloth", 2048, paint_cloth(b), 0.05, 0.5), ("skin", 1024, paint_skin(b), 0.30, 0.35),
                                    ("hair", 1024, paint_hair(b), 0.30, 0.35), ("gear", 1024, paint_gear(b), 0.55, 0.18)):
        S.apply_material(groups[g], S.texture_group(groups[g], "%s_%s" % (PREFIX, g), res, paint, TEX_DIR, coat=coat, coat_rough=cr))
    S.face_materials(groups["face"], PREFIX, C["iris"], C["pele"], mouth_hex=C["boca"], dark_hex="#3A3036")
    # G4 r2: idle relaxado (bracos soltos ao lado do corpo, respiracao) no lugar do idle em A; mesmo nome de clipe
    ha.IDLES["captain"] = (3.6, pose_idle_adult)
    rep = ha.author(rig, groups["face"], b.F, cid="captain")
    bpy.context.view_layer.update()
    info = S.base_info(list(groups.values()), rig, groups["face"], PREFIX)
    head = groups["skin"]
    hz = [(v.co.z) for v in head.data.vertices if v.co.z > b.F.chin - 0.03]
    info.update({"head_h_m": round(b.F.head_h, 4), "head_ratio": round(b.F.head_h / info["height_m"], 4),
                 "walk_speed_mps": round(ha.walk_speed(b.F), 4), "run_speed_mps": round(ha.run_speed(b.F), 4), "variant": CID})
    info.update(rep)
    S.save(info, blend, glb)
    return info


if __name__ == "__main__":
    build(arg_value("--glb"), arg_value("--blend"))
