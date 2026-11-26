"""Dona Amora (RB-R1, arte das cenas): feirante da vila, senhora calorosa. PROVISORIO.

Construida do zero pelo mesmo construtor procedural dos adultos da vila (source_art/scripts/hero_lib.py, proporcao "EL"),
com partes proprias deste script: coque no alto da cabeca, lenco roxo amarrado na nuca com tres amoras e folha, saia
rodada, avental branco com peitilho, alcas e lacos, bolinhas de amora no avental. Acabamento vinil dos herois v2:
Principled com verniz (coat) por cor, sem textura assada (ver PROVENANCE.md). Coerente com o retrato SVG
game/ui/brand/icons/vendor.svg (vestido #7A3E9D, avental #F7FBFF, amoras #4A2370, cabelo #5A2E3A, pele #D9976A).

Clipes: idle (loop), wave, thanks, point, talk (3,0 s, comeca e termina na mesma pose; o jogo decide se repete).
Sem walk: fica parada na barraca. Frente = +Y (Blender) = -Z (Godot). Origem nos pes.

Uso (Linux):
  bash tools/blender.sh --background --factory-startup --python source_art/characters/amora/build_amora.py -- \
      --blend $PWD/source_art/characters/amora/amora.blend --glb $PWD/game/assets/models/characters/amora.glb
"""
import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPTS = os.path.abspath(os.path.join(HERE, "..", "..", "scripts"))
if SCRIPTS not in sys.path:
    sys.path.insert(0, SCRIPTS)

import bmesh
import bpy
from mathutils import Matrix, Vector

import char_lib as cl
import hero_anim as ha
import hero_lib
from char_anim import blink_curve, lerp, reach, smooth, stand_feet, torso
from hero_lib import join_bm
from rbart import arg_value, hex_to_linear, mat, new_object, reset_scene, tri_count, world_bbox

CID = "amora"
hero_lib.CAST[CID] = dict(
    display="Amora", K=0.93, variant="EL", hat="none", hair="short", team=False, gear=(), gloves=False,
    pal=dict(pele="#D9976A", cabelo="#5A2E3A", iris="#4A3A6A", uniforme="#7A3E9D", creme="#F7FBFF", calca="#4A2370",
             botas="#6B3A2A", chapeu="#7A3E9D", couro="#5A2E7A", emblema="#123A5E", ouro="#FFC83D", olhos="#FFFFFF",
             escuro="#2A1A24", boca="#A0404A", rubor="#FF7A8A", amora="#4A2370", folha="#3DBE5A", sola="#F2E4D0"))

# acabamento vinil (v2): rugosidade e verniz por papel; brilho proprio so nos olhos
VINYL = {"pele": (0.50, 0.30, 0.35), "cabelo": (0.34, 0.80, 0.10), "uniforme": (0.52, 0.55, 0.14), "creme": (0.50, 0.50, 0.15),
         "calca": (0.55, 0.40, 0.20), "botas": (0.40, 0.70, 0.12), "chapeu": (0.48, 0.60, 0.12), "couro": (0.45, 0.60, 0.14),
         "amora": (0.18, 1.00, 0.05), "folha": (0.30, 0.90, 0.08), "olhos": (0.18, 0.80, 0.06), "iris": (0.14, 1.00, 0.04),
         "escuro": (0.25, 0.60, 0.10), "boca": (0.35, 0.40, 0.20), "rubor": (0.60, 0.20, 0.30), "sola": (0.60, 0.20, 0.30),
         "ouro": (0.30, 0.80, 0.10), "emblema": (0.40, 0.60, 0.10)}
EMIS = {"olhos": 0.08}


class AmoraBuilder(hero_lib.Builder):
    def __init__(self):
        super().__init__(CID, "EL")
        for role in ("amora", "folha", "sola"):
            if role not in self.M:
                self.M[role] = mat("mat_%s_%s" % (CID, role), self.cfg["pal"][role], 0.5)

    # saia: raio por altura (mesma funcao para a saia e o avental que a cobre)
    def skirt_geom(self):
        F = self.F
        rx, ry = self.jacket_radius(F.hz - 0.05)
        top = F.hz + 0.02
        bot = F.knee_z * 0.55
        r0 = max(rx, ry / 0.9) + 0.006
        r1 = r0 + 0.110
        return top, bot, r0, r1

    def skirt_r(self, z):
        top, bot, r0, r1 = self.skirt_geom()
        u = max(0.0, min(1.0, (top - z) / (top - bot)))
        return r0 + (r1 - r0) * (u ** 0.85)

    def uniform_details(self):
        """No lugar da gola/ziper/cinto de equipe: saia, avental com peitilho e alcas, laco, gola redonda e botoes."""
        F, v, M, k = self.F, self.v, self.M, self.F.k
        hz, nz = F.hz, F.nz
        top, bot, r0, r1 = self.skirt_geom()
        SY = 0.90
        # saia rodada com pregas leves na barra (roxo do vestido)
        prof = []
        n = 9
        for i in range(n + 1):
            z = top - (top - bot) * i / n
            prof.append((self.skirt_r(z), z))
        prof = [(0.0, top)] + prof + [(r1 * 0.97, bot + 0.012), (0.0, bot + 0.012)]
        bm = bmesh.new()
        cl.lathe(bm, prof, 40, deform=lambda r, z, a: (r * (1.0 + 0.035 * math.sin(10 * a) * ((top - z) / (top - bot)) ** 2), z))
        cl.transform_bm(bm, Matrix.Diagonal((1.0, SY, 1.0, 1.0)))
        self.reg(new_object(self.name("Skirt"), bm, M["uniforme"]), "single", "hips")
        # avental (parte de baixo): lamina sobre a frente da saia, com espessura
        bm = bmesh.new()
        A0, A1 = -0.95, 0.95
        zt, zb = hz + 0.005, bot + 0.035
        rows, cols = 10, 16
        grid = []
        for i in range(rows + 1):
            z = zt - (zt - zb) * i / rows
            rr = self.skirt_r(z) * (1.0 + 0.035) + 0.014
            row = []
            for j in range(cols + 1):
                a = A0 + (A1 - A0) * j / cols
                row.append(bm.verts.new((rr * math.sin(a), rr * math.cos(a) * SY, z)))
            grid.append(row)
        for i in range(rows):
            for j in range(cols):
                bm.faces.new((grid[i][j], grid[i + 1][j], grid[i + 1][j + 1], grid[i][j + 1]))
        bmesh.ops.solidify(bm, geom=bm.faces[:], thickness=0.005)
        apron = new_object(self.name("Apron"), bm, M["creme"])
        self.reg(apron, "single", "hips")
        # bolinhas de amora no avental (cachos de 4, como no retrato)
        bm = bmesh.new()
        for (ca, cz) in ((-0.45, 0.35), (0.42, 0.30), (0.0, 0.62), (-0.30, 0.82), (0.38, 0.80)):
            for (da, dz) in ((-0.07, 0.0), (0.0, 0.035), (0.07, 0.0), (0.0, -0.035)):
                z = zt - (zt - zb) * (cz + dz)
                a = ca + da
                rr = self.skirt_r(z) * 1.035 + 0.014 + 0.0055
                p = Vector((rr * math.sin(a), rr * math.cos(a) * SY, z))
                nrm = Vector((math.sin(a), math.cos(a) / SY, 0.0)).normalized()
                tb = bmesh.new()
                cl.ellipsoid(tb, (0, 0, 0), (0.0105, 0.0035, 0.0105), 8, 4)
                q = nrm.to_track_quat("Y", "Z").to_matrix().to_4x4()
                cl.transform_bm(tb, Matrix.Translation(p) @ q)
                join_bm(bm, tb)
        self.reg(new_object(self.name("ApronDots"), bm, M["amora"]), "single", "hips")
        # peitilho do avental: grade colada na frente da blusa
        jk = self.jacket
        bm = bmesh.new()
        z0, z1 = hz + 0.015, nz - 0.085
        rows, cols = 8, 8
        grid = []
        for i in range(rows + 1):
            z = z0 + (z1 - z0) * i / rows
            w = lerp(0.105, 0.080, i / rows)
            row = []
            for j in range(cols + 1):
                x = -w + 2 * w * j / cols
                y = (cl.snap_y(jk, x, z) or 0.10) + 0.006
                row.append(bm.verts.new((x, y, z)))
            grid.append(row)
        for i in range(rows):
            for j in range(cols):
                bm.faces.new((grid[i][j], grid[i][j + 1], grid[i + 1][j + 1], grid[i + 1][j]))
        bmesh.ops.solidify(bm, geom=bm.faces[:], thickness=0.004)
        # bolso do peitilho com uma amora
        tb = bmesh.new()
        py = (cl.snap_y(jk, 0.0, z0 + 0.10) or 0.10) + 0.010
        cl.rounded_box(tb, (0.0, py, z0 + 0.085), (0.090, 0.008, 0.060), 0.004)
        join_bm(bm, tb)
        bib = new_object(self.name("ApronBib"), bm, M["creme"])
        self.reg(bib, "torso")
        bm = bmesh.new()
        for (dx, dz) in ((-0.011, 0.0), (0.011, 0.0), (0.0, 0.015), (0.0, -0.013)):
            cl.ellipsoid(bm, (dx, py + 0.006, z0 + 0.090 + dz), (0.010, 0.004, 0.010), 10, 6)
        self.reg(new_object(self.name("BibBerry"), bm, M["amora"]), "torso")
        # alcas do peitilho ate a nuca e cinta com laco nas costas
        bm = bmesh.new()
        for sx in (1, -1):
            x0 = sx * 0.080
            y0 = (cl.snap_y(jk, x0, z1) or 0.10) + 0.006
            pts = [(x0, y0, z1), (sx * 0.072, y0 - 0.010, nz - 0.040), (sx * 0.064, 0.030, nz - 0.004),
                   (sx * 0.045, -0.025, nz + 0.004), (sx * 0.012, -0.055, nz - 0.010)]
            cl.tube(bm, pts, 0.0085, 6, True)
        wz = hz + 0.012
        rx, ry = self.jacket_radius(wz)
        cl.torus_z(bm, rx + 0.006, 0.010, wz, sy=(ry + 0.006) / (rx + 0.006), major=30, minor=5)
        by = -(ry + 0.016)
        for sx in (1, -1):
            tb = bmesh.new()
            cl.ellipsoid(tb, (0, 0, 0), (0.040, 0.012, 0.024), 12, 6)
            cl.transform_bm(tb, Matrix.Translation((sx * 0.034, by, wz + 0.004)) @ cl.rot_y(sx * 20))
            join_bm(bm, tb)
            tb = bmesh.new()
            cl.tube(tb, [(sx * 0.010, by, wz - 0.005), (sx * 0.024, by - 0.004, wz - 0.060), (sx * 0.030, by - 0.002, wz - 0.110)],
                    [0.010, 0.009, 0.007], 6, True)
            join_bm(bm, tb)
        cl.ellipsoid(bm, (0, by - 0.002, wz + 0.002), (0.014, 0.012, 0.016), 10, 6)
        self.reg(new_object(self.name("ApronTies"), bm, M["creme"]), "torso")
        # gola redonda branca e tres botoes de amora na blusa (acima do peitilho)
        bm = bmesh.new()
        cl.torus_z(bm, 0.060, 0.015, 0.0, sy=0.92, major=22, minor=6)
        cl.transform_bm(bm, Matrix.Translation((0, 0.004, nz - 0.012)) @ cl.Matrix.Rotation(math.radians(12), 4, "X"))
        self.reg(new_object(self.name("Collar"), bm, M["creme"]), "torso")
        # punhos brancos
        for sx, sd in ((1, "R"), (-1, "L")):
            el = Vector((sx * F.elbow.x, F.elbow.y, F.elbow.z))
            W = Vector((sx * F.wrist.x, F.wrist.y, F.wrist.z))
            c = W.lerp(el, 0.12)
            bm = bmesh.new()
            cl.torus_z(bm, v["limb"] * 0.98, 0.011, 0.0, major=18, minor=5)
            q = (W - el).normalized().to_track_quat("Z", "Y").to_matrix().to_4x4()
            cl.transform_bm(bm, Matrix.Translation(c) @ q)
            self.reg(new_object(self.name("Cuff" + sd), bm, M["creme"]), "single", "forearm." + sd)

    def hair(self):
        ob = super().hair()
        F, k = self.F, self.F.k
        hc, hr = F.hc, F.hr
        # coque no alto da cabeca (como no retrato) e um anel de base
        bm = bmesh.new()
        cz = hc.z + hr[2] * 1.02 + 0.040 * k
        cl.ellipsoid(bm, (0, hc.y - hr[1] * 0.10, cz), (0.078 * k, 0.074 * k, 0.066 * k), 20, 12)
        tb = bmesh.new()
        cl.torus_z(tb, 0.050 * k, 0.020 * k, 0.0, major=20, minor=6)
        cl.transform_bm(tb, Matrix.Translation((0, hc.y - hr[1] * 0.10, cz - 0.046 * k)))
        join_bm(bm, tb)
        # mecha que enrola o coque (espiral leve)
        pts = []
        for i in range(14):
            a = i / 13 * math.pi * 1.6
            pts.append((math.cos(a) * 0.060 * k, hc.y - hr[1] * 0.10 + math.sin(a) * 0.058 * k, cz - 0.010 * k + 0.030 * k * i / 13))
        cl.tube(bm, pts, [0.016 * k] * 14, 6, True)
        self.reg(new_object(self.name("Bun"), bm, self.M["cabelo"]), "single", "head")
        self.scarf()
        return ob

    def scarf(self):
        """Lenco roxo: faixa por cima da cabeca, na frente do coque, amarrada na nuca (laco e duas pontas); amoras e folha."""
        F, k, M = self.F, self.F.k, self.M
        hc, hr = F.hc, F.hr
        S = (hr[0] * 1.08, hr[1] * 1.08, hr[2] * 1.07)

        def on_head(d, grow=1.0):
            d = Vector(d).normalized()
            s = 1.0 / math.sqrt((d.x / S[0]) ** 2 + (d.y / S[1]) ** 2 + (d.z / S[2]) ** 2)
            return hc + d * s * grow

        pts = []
        N = 40
        for i in range(N + 1):
            a = 2 * math.pi * i / N
            u = (1 - math.cos(a)) / 2         # 0 no alto, 1 na nuca
            d = (math.sin(a) * 1.0, lerp(0.30, -0.95, u), lerp(1.0, -0.35, u))
            pts.append(on_head(d))
        bm = bmesh.new()
        rings = cl.tube(bm, pts[:-1] + [pts[0]], [0.022 * k] * N + [0.022 * k], 10, False)
        bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-5)
        # achata a faixa (fita larga): aproxima cada vertice do centro da cabeca na direcao radial
        for vtx in bm.verts:
            rad = (vtx.co - hc)
            base = on_head(rad)
            vtx.co = base + (vtx.co - base) * 0.55 + (base - hc).normalized() * 0.006 * k
        nape = on_head((0, -0.95, -0.35), 1.02)
        for sx in (1, -1):
            tb = bmesh.new()
            cl.ellipsoid(tb, (0, 0, 0), (0.034 * k, 0.014 * k, 0.022 * k), 12, 6)
            cl.transform_bm(tb, Matrix.Translation(nape + Vector((sx * 0.030 * k, -0.006, 0.004))) @ cl.rot_y(sx * 25))
            join_bm(bm, tb)
            tb = bmesh.new()
            cl.tube(tb, [nape + Vector((sx * 0.008, -0.004, -0.004)), nape + Vector((sx * 0.026 * k, -0.018, -0.050 * k)),
                         nape + Vector((sx * 0.038 * k, -0.020, -0.095 * k))], [0.014 * k, 0.012 * k, 0.006 * k], 6, True)
            join_bm(bm, tb)
        cl.ellipsoid(bm, nape + Vector((0, -0.008, 0)), (0.016 * k, 0.014 * k, 0.018 * k), 10, 6)
        self.reg(new_object(self.name("Scarf"), bm, M["chapeu"]), "single", "head")
        # tres amoras (cachos de bolinhas) e uma folha no lado esquerdo do lenco (-X), como no retrato
        a = -0.62
        u = (1 - math.cos(a)) / 2
        base = on_head((math.sin(a), lerp(0.30, -0.95, u), lerp(1.0, -0.35, u)), 1.06)
        nrm = (base - hc).normalized()
        bm = bmesh.new()
        for (ox, oz) in ((0.0, 0.0), (-0.040, -0.030), (0.012, -0.044)):
            c = base + Vector((ox * k, 0.012 * k, oz * k))
            c = hc + (c - hc).normalized() * ((c - hc).length)
            for (dx, dy, dz) in ((0, 0, 0), (0.010, 0.006, 0.008), (-0.010, 0.006, 0.008), (0.010, 0.006, -0.008),
                                 (-0.010, 0.006, -0.008), (0, 0.012, 0)):
                cl.ellipsoid(bm, c + nrm * 0.004 + Vector((dx, dy, dz)) * k, (0.012 * k, 0.012 * k, 0.012 * k), 8, 5)
        self.reg(new_object(self.name("Berries"), bm, M["amora"]), "single", "head")
        bm = bmesh.new()
        tb = bmesh.new()
        cl.ellipsoid(tb, (0, 0, 0), (0.030 * k, 0.006 * k, 0.014 * k), 12, 6)
        q = nrm.to_track_quat("Y", "Z").to_matrix().to_4x4()
        cl.transform_bm(tb, Matrix.Translation(base + Vector((0.030 * k, 0.010 * k, 0.034 * k))) @ q @ cl.Matrix.Rotation(math.radians(40), 4, "Y"))
        join_bm(bm, tb)
        self.reg(new_object(self.name("Leaf"), bm, M["folha"]), "single", "head")


def vinyl(builder):
    for role, m in list(builder.M.items()):
        b = m.node_tree.nodes["Principled BSDF"]
        rough, coat, coat_r = VINYL.get(role, (0.45, 0.5, 0.15))
        b.inputs["Roughness"].default_value = rough
        b.inputs["Coat Weight"].default_value = coat
        b.inputs["Coat Roughness"].default_value = coat_r
        b.inputs["Emission Strength"].default_value = EMIS.get(role, 0.0)
        m["vinyl"] = True


# ------------------------------------------------------------------ clipes
def pose_point_amora(R, F, t, T):
    """Aponta a barraca/os caixotes: braco direito estendido para frente-direita na altura do peito, mao aberta, sorriso."""
    a = smooth(t, 0.10, 0.38) * (1 - smooth(t, 0.92, 1.18))
    R.hips_off = Vector((0, 0, -0.010))
    torso(R, lean=lerp(3.0, 0.0, a), yaw=-9.0 * a, head_pitch=3.0 * a, head_yaw=-12.0 * a)
    ha.arms_down(R, F, bend=16, out=8)
    R.evaluate()
    rest = R.tip("hand.R")
    L = R.length("upper_arm.R") + R.length("forearm.R") + R.length("hand.R")
    d = Vector((0.40, 0.90, -0.05)).normalized()
    tgt = Vector((F.sh.x, 0.02, F.sh.z)) + d * (L * 0.92)
    reach(R, "R", rest.lerp(tgt, a), Vector((0.1, 0.2, -1.0)).lerp(d, a), pole=(1.0, -0.4, -0.8))
    stand_feet(R)
    return ha.face(atenta=0.5 * a, alegre=0.12 * a, blink=blink_curve(t, 0.85))


def pose_thanks_amora(R, F, t, T):
    """Agradece: maos juntas no peito, inclina a cabeca e o corpo com um sorriso grande."""
    f = ha.pose_thanks(R, F, t, T)
    f["alegre"] = min(1.0, f.get("alegre", 0.0) * 1.0 + 0.2)
    return f


def pose_talk_amora(R, F, t, T):
    """Conversa (3,0 s): gesticula com a mao direita, acena com a cabeca; a boca abre em silabas (visemas A/O/E)."""
    f = ha.pose_chat(R, F, t, T)
    f["alegre"] = 0.12      # olhos abertos enquanto fala (o sorriso de olhos fechados fica para o thanks)
    g = smooth(t, 0.15, 0.40) * (1 - smooth(t, T - 0.40, T - 0.12))
    syl = abs(math.sin(2 * math.pi * 2.6 * t))
    pick = int(t * 5.2) % 3
    f["mouth_A"] = g * syl * (0.75 if pick == 0 else 0.25)
    f["mouth_O"] = g * syl * (0.65 if pick == 1 else 0.0)
    f["mouth_E"] = g * syl * (0.60 if pick == 2 else 0.0)
    return f


def pose_idle_amora(R, F, t, T):
    f = ha.pose_idle_simple(R, F, t, T)
    # olhos abertos (o "alegre" fecha os olhos em sorriso; na barraca ela fica de olhos abertos, so com piscadas)
    f["alegre"] = 0.0
    f["atenta"] = 0.15
    return f


CLIPS = {"idle": (3.6, True, pose_idle_amora), "wave": (1.6, False, ha.pose_wave), "thanks": (2.0, False, pose_thanks_amora),
         "point": (1.2, False, pose_point_amora), "talk": (3.0, True, pose_talk_amora)}
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


def main():
    sc = reset_scene()
    sc.render.fps = ha.FPS
    b = AmoraBuilder()
    b.build(True)
    vinyl(b)
    rig = b.rig
    rig["provisional"] = True
    rig["agent"] = "art3d"
    rig["variant"] = "amora"
    author(rig, b.face_ob, b.F)
    bpy.context.view_layer.update()
    objs = b.objs
    lo, hi = world_bbox(objs)
    head = b.head_ob
    hz = [(head.matrix_world @ Vector(c)).z for c in head.bound_box]
    acts = {a.name: [round(a.frame_range[0]), round(a.frame_range[1])] for a in bpy.data.actions if not a.name.endswith("_key")}
    info = {"tris": tri_count(objs), "materials": sorted({m.name for o in objs for m in o.data.materials if m}),
            "height_m": round(hi.z - lo.z, 4), "min_z": round(lo.z, 4), "head_h_m": round(max(hz) - min(hz), 4),
            "head_ratio": round((max(hz) - min(hz)) / (hi.z - lo.z), 4),
            "objects": sorted(o.name for o in objs), "tris_por_objeto": {o.name: tri_count([o]) for o in objs},
            "bones": [bb.name for bb in rig.data.bones], "bone_count": len(rig.data.bones), "animations": acts,
            "loops": {k: v[1] for k, v in CLIPS.items()},
            "shape_keys": [kb.name for kb in b.face_ob.data.shape_keys.key_blocks], "walk_speed_mps": 0.0, "run_speed_mps": 0.0,
            "variant": "amora", "acabamento": "vinil (Principled + coat por cor, sem textura assada)"}
    print("CHAR_INFO", json.dumps(info))
    blend = arg_value("--blend")
    if blend:
        os.makedirs(os.path.dirname(blend), exist_ok=True)
        bpy.ops.wm.save_as_mainfile(filepath=blend, compress=True)
        with open(os.path.splitext(blend)[0] + ".info.json", "w", encoding="utf-8") as f:
            json.dump(info, f, indent=2)
    glb = arg_value("--glb")
    if glb:
        os.makedirs(os.path.dirname(glb), exist_ok=True)
        bpy.ops.export_scene.gltf(filepath=glb, export_format="GLB", use_selection=False, export_yup=True, export_apply=False,
                                  export_morph=True, export_materials="EXPORT", export_cameras=False, export_lights=False,
                                  export_extras=True, export_skins=True, export_animations=True,
                                  export_animation_mode="NLA_TRACKS", export_force_sampling=True, export_frame_range=False,
                                  export_optimize_animation_size=False, export_def_bones=False)


if __name__ == "__main__":
    main()
