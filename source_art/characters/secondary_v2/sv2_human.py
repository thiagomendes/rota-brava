"""Adultos v2 (RB-R1 G4): base comum do capitao, da Dona Amora e dos moradores no padrao do trio v2. PROVISORIO.

Reusa do hero_lib (so leitura) o quadro de proporcoes (Frame), o esqueleto de 28 ossos, os pesos por distancia e o rosto
(hero_face); os clipes vem do hero_anim. Troca a cabeca de crianca por uma cabeca ADULTA (mandibula mais longa e
estreita, bochechas menos cheias, nariz maior, olhos menores) e o corpo por pecas v2: tronco+mangas numa malha SKIN com
SUBSURF 3 e forma modelada em numpy, calca SKIN, maos de 4 dedos lisas, sapatos SKIN com sola chanfrada. Tudo marcado por
parte e grupo para as atlas de textura (sv2_lib.texture_group).

Proporcao adulta: cabeca ~21% da altura (os herois tem ~35%); pescoco visivel; ombros mais largos que a cabeca.
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
import hero_lib
import sv2_lib as S
from hero_lib import join_bm
from rbart import new_object


def V(*a):
    return Vector(a)


def bump(u, c, w):
    return np.exp(-((u - c) / w) ** 2)


class Adult(hero_lib.Builder):
    """Construtor adulto v2. Subclasses definem o figurino (coat/dress, chapeu, cabelo) e a tabela de pintura."""

    GROUPS = ("cloth", "skin", "hair", "gear")

    def __init__(self, cid, variant, parts):
        super().__init__(cid, variant)
        self.parts_reg = parts
        self.F.hip_x = 0.082 * self.v["belly"] / 0.16

    # ------------------------------------------------------------ utilidades
    def t(self, ob, part, group):
        return S.tag(ob, part, group, self.parts_reg)

    def head_r_at(self, z):
        """Raios (x, y) da cabeca na altura z (elipsoide da cabeca)."""
        F = self.F
        u = (z - F.hc.z) / F.hr[2]
        s = math.sqrt(max(1e-4, 1 - u * u))
        return F.hr[0] * s, F.hr[1] * s

    # ------------------------------------------------------------ cabeca adulta
    def head(self):
        F = self.F
        k = F.k
        bm = bmesh.new()
        cl.ellipsoid(bm, (0, 0, 0), (1, 1, 1), 32, 20)
        for v in bm.verts:
            x, y, z = v.co
            if z < 0.1:                                    # mandibula adulta: afunila e alonga
                t = (0.1 - z) / 1.1
                x *= 1.0 - self.JAW * t ** 1.3
                y *= 1.0 - 0.06 * t
                z = z - self.CHIN * t ** 1.5
            if y > 0.2 and -0.75 < z < -0.25:              # queixo levemente para frente
                y *= 1.0 + 0.05 * math.exp(-((z + 0.62) ** 2) / 0.03)
            x *= 1.0 + self.CHEEK * math.exp(-((z + 0.20) ** 2) / 0.05) * max(y, 0.0)    # macas do rosto discretas
            if y > 0 and z > 0.15:                         # testa
                y *= 1.0 + 0.02 * z
            v.co = V(F.hc.x + x * F.hr[0], F.hc.y + y * F.hr[1], F.hc.z + z * F.hr[2])
        for sx in ((1, -1) if self.EARS else ()):   # orelhas (G4 r3b: quem tem cabelo cobrindo a orelha nao as modela)
            tb = bmesh.new()
            cl.ellipsoid(tb, (0, 0, 0), (0.014 * k, 0.026 * k, 0.040 * k), 14, 10)
            for vv in tb.verts:      # concha: frente achatada
                if vv.co.y > 0:
                    vv.co.y *= 0.6
            cl.transform_bm(tb, Matrix.Translation((sx * F.hr[0] * 0.95, F.hc.y - 0.010 * k, F.hc.z - 0.034 * k)) @ cl.rot_y(sx * 10))
            join_bm(bm, tb)
        ob = new_object(self.name("Head"), bm, self.M["pele"])
        bm = bmesh.new()
        nz_ = F.hc.z - 0.070 * k
        ny = cl.snap_y(ob, 0.0, nz_) or F.hc.y + F.hr[1]
        cl.ellipsoid(bm, (0, ny + 0.006 * k, nz_), (0.024 * k, 0.022 * k, 0.026 * k), 18, 12)
        for vv in bm.verts:                                # ponta do nariz um pouco mais larga embaixo
            if vv.co.z < nz_:
                vv.co.x = vv.co.x * 1.12
        nose = new_object(self.name("Nose"), bm, self.M["pele"])
        self.head_ob = ob
        self.reg(self.t(ob, "skin_head", "skin"), "single", "head")
        self.reg(self.t(nose, "skin_nose", "skin"), "single", "head")
        return ob

    def neck(self):
        F = self.F
        nodes = [((0, 0.000, F.nz - 0.05), 0.050 * F.k), ((0, 0.004, F.chin + 0.05), 0.044 * F.k)]
        ob = cl.skin_obj(self.name("Neck"), nodes, [(0, 1)], self.M["pele"], levels=2)
        self.reg(self.t(ob, "skin_neck", "skin"), "dist")

    # ------------------------------------------------------------ maos (4 dedos, lisas)
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
            # G4 r2: o pulso continua para dentro da manga (antes a mao comecava 3 cm antes do pulso, fina e solta da manga)
            el = V(sx * F.elbow.x, F.elbow.y, F.elbow.z)
            Wc = V(sx * F.wrist.x, F.wrist.y, F.wrist.z)
            L = v["limb"]
            f_in = add(el.lerp(Wc, 0.62), L * 0.66)
            f_mid = add(el.lerp(Wc, 0.84), L * 0.60, f_in)
            w0 = add(W - d * 0.004, L * 0.55, f_mid)
            palm = add(W + d * 0.032 * k, 0.031 * k, w0)
            t0 = add(W + d * 0.026 * k + f * 0.028 * k + n * 0.004, 0.0125 * k, palm)
            add(W + d * 0.052 * k + f * 0.044 * k + n * 0.010, 0.0105 * k, t0)
            for off, ln in ((0.017, 0.040), (0.0, 0.046), (-0.017, 0.038)):
                base = add(W + d * 0.060 * k + f * off * k, 0.0118 * k, palm)
                add(W + d * (0.060 + ln) * k + f * off * k + n * 0.012 * k, 0.0102 * k, base)
            ob = cl.skin_obj(self.name("Hand" + sd), nn, ee, self.M["pele"], levels=3)
            S.decimate(ob, 0.19)
            self.reg(self.t(ob, "skin_hand", "skin"), "dist")

    # ------------------------------------------------------------ tronco com mangas (casaco/blusa)
    def torso_shell(self, part, hem_z, hem_flare=1.15, belly_k=1.0, chest_k=1.0, cuff_k=1.10, group="cloth", decim=0.20):
        F, v = self.F, self.v
        hz, nz, b, L = F.hz, F.nz, v["belly"], v["limb"]
        nodes, edges = [], []

        def add(co, r, link=None):
            nodes.append((tuple(co), r))
            if link is not None:
                edges.append((link, len(nodes) - 1))
            return len(nodes) - 1
        hem = add((0, -0.004, hem_z), b * hem_flare)
        cur = hem
        if hem_z < hz - 0.06:
            cur = add((0, 0.000, (hem_z + hz) * 0.5), b * (hem_flare * 0.5 + 0.52), cur)
        hip = add((0, 0.002, hz + 0.01), b * 1.04, cur)
        waist = add((0, 0.010, hz + (nz - hz) * 0.30), b * 1.04 * belly_k, hip)
        chest = add((0, 0.006, nz - (nz - hz) * 0.26), b * 1.02 * chest_k, waist)
        upper = add((0, 0.000, nz - 0.055), b * 0.90, chest)
        add((0, 0.002, nz + 0.012), 0.058 * F.k, upper)
        self.limb_segs = []
        for sx, s in ((1, "R"), (-1, "L")):
            sh = V(sx * F.sh.x, F.sh.y, F.sh.z)
            el = V(sx * F.elbow.x, F.elbow.y, F.elbow.z)
            W = V(sx * F.wrist.x, F.wrist.y, F.wrist.z)
            s0 = add(V(sx * F.sh.x * 0.55, 0.0, F.sh.z + 0.010), L * 1.45, upper)
            s1 = add(sh.lerp(el, 0.10), L * 1.30, s0)
            s2 = add(sh.lerp(el, 0.50), L * 1.14, s1)
            e0 = add(sh.lerp(el, 0.92), L * 1.04, s2)
            f0 = add(el.lerp(W, 0.45), L * 1.02, e0)
            add(el.lerp(W, 0.93), L * cuff_k, f0)
            self.limb_segs += [("upper_arm", s, sh, el), ("forearm", s, el, W)]
        ob = cl.skin_obj(self.name(part.capitalize()), nodes, edges, self.M["uniforme"], levels=3, branch=1.0, scale=(1, 0.88, 1))
        self.shape_torso(ob, hem_z)
        # barra aberta (sem a calota do SKIN embaixo) com espessura de tecido para dentro
        # (reduz ANTES do corte: o Decimate numa borda aberta rasga a barra)
        S.decimate(ob, decim)
        bm = bmesh.new()
        bm.from_mesh(ob.data)
        hero_lib.bisect_keep(bm, (0, 0, hem_z + 0.012), (0, 0, 1), keep_above=True)
        bm.to_mesh(ob.data)
        bm.free()
        sol = ob.modifiers.new("sol", "SOLIDIFY")
        sol.thickness = 0.006
        sol.offset = -1.0
        sol.use_rim = True
        hero_lib.bake(ob)
        decim = 1.0
        S.decimate(ob, decim)
        self.shell = ob
        self.reg(self.t(ob, part, group), "dist")
        return ob

    def shape_torso(self, ob, hem_z):
        """Ombros arredondados, peito, barriga, costas e dobras de cotovelo; o resto do volume vem do grafo."""
        F = self.F
        hz, nz = F.hz, F.nz
        P = S.verts_np(ob)
        z = P[:, 2]
        out = P.copy()
        torso_w = np.exp(-(np.maximum(np.abs(P[:, 0]) - self.v["belly"] * 0.9, 0) / 0.03) ** 2)
        front = np.clip(P[:, 1] / 0.12, -1, 1)
        add = (0.010 * bump(z, nz - 0.11, 0.05) * np.clip(front, 0, 1) ** 1.5
               + self.belly_bump * bump(z, hz + 0.12, 0.10) * np.clip(front, 0, 1) ** 1.6
               + 0.008 * bump(z, nz - 0.12, 0.06) * np.clip(-front, 0, 1) ** 2)
        rad = P.copy()
        rad[:, 2] = 0
        rn = rad / np.maximum(np.linalg.norm(rad, axis=1)[:, None], 1e-9)
        out += rn * (add * torso_w)[:, None]
        for kind, s, a, b in self.limb_segs:
            a, b = np.array(a), np.array(b)
            d = b - a
            Ld = np.linalg.norm(d)
            u = (P - a) @ d / (Ld * Ld)
            proj = a + np.outer(np.clip(u, 0, 1), d)
            rv = P - proj
            r = np.linalg.norm(rv, axis=1)
            near = np.exp(-(r / (self.v["limb"] * 1.6)) ** 4) * (u > -0.1) * (u < 1.1)
            rnv = rv / np.maximum(r[:, None], 1e-9)
            fr = np.array([0, 1.0, 0])
            fdot = rnv @ fr
            if kind == "upper_arm":
                dd = 0.006 * bump(u, 0.12, 0.14) + 0.0024 * np.sin(2 * np.pi * u * Ld / 0.020) ** 2 * bump(u, 0.95, 0.07) * np.clip(fdot, 0, 1)
            else:
                dd = 0.0024 * np.sin(2 * np.pi * u * Ld / 0.020) ** 2 * bump(u, 0.06, 0.08) * np.clip(fdot, 0, 1)
            out += rnv * (dd * near)[:, None]
        S.set_verts(ob, out)

    belly_bump = 0.010
    # cabeca adulta: afunilamento da mandibula, alongamento do queixo, maca do rosto (G4 r2: por personagem)
    JAW, CHIN, CHEEK = 0.26, 0.10, 0.025
    EARS = True

    # ------------------------------------------------------------ calca e sapatos
    def trousers(self, part="trousers", top_r=None, hem_up=0.055, ankle_r=None):
        F, v = self.F, self.v
        hz = F.hz
        lk = (v["limb"] / 0.050)
        # G4 r3: as pernas formam UMA corrente em U (tornozelo E -> quadril E -> fundilho -> quadril D -> tornozelo D), sem no de
        # bifurcacao: o casco do SKIN nao incha (a lasca do r1 furava a roupa de cima no quadril) e o fundilho fecha o vao
        # escuro entre as coxas visto de baixo da barra do casaco (r2 tinha duas pernas soltas).
        chain = []
        for sx in (-1, 1):
            x = sx * F.hip_x
            # G23: com `ankle_r`, a perna (meia) continua por um tornozelo mais fino que desce para DENTRO do sapato (sem o
            # vao entre a barra e o sapato, que deixava o fundo aparecer)
            foot = [((x, -0.004, F.ankle_z - 0.012), ankle_r * lk)] if ankle_r else []
            leg = foot + [((x, -0.002, F.ankle_z + hem_up), 0.058 * lk), ((x, 0.006, F.knee_z - 0.02), 0.060 * lk),
                   ((x, 0.004, F.knee_z + 0.03), 0.063 * lk), ((x * 0.95, 0, hz - 0.11), 0.066 * lk)]
            chain += leg if sx < 0 else list(reversed(leg))
            if sx < 0:
                # fundilho baixo e cheio (o vao escuro entre as coxas sob a barra do casaco fica preenchido de tecido)
                chain.append(((0, -0.004, hz - 0.125), 0.062 * lk))
        nodes = chain
        edges = [(i, i + 1) for i in range(len(chain) - 1)]
        roots = [len(chain) // 2]
        ob = cl.skin_obj(self.name(part.capitalize()), nodes, edges, self.M["calca"], levels=3, scale=(1, 0.92, 1), roots=tuple(roots))
        self.pants = ob
        P = S.verts_np(ob)
        zz = P[:, 2]
        ang = np.arctan2(P[:, 0], P[:, 1])
        # barra com dobras sanfonadas acima do sapato e vinco no joelho de tras
        hem = S.sstep(zz, F.ankle_z + hem_up + 0.01, F.ankle_z + hem_up + 0.03) * (1 - S.sstep(zz, F.ankle_z + hem_up + 0.10, F.ankle_z + hem_up + 0.14))
        d = 0.004 * (0.5 + 0.5 * np.sin(2 * np.pi * (zz - F.ankle_z) / 0.030 + 1.3 * np.sin(3 * ang))) * hem
        rad = P.copy()
        for sx in (1, -1):
            sel = (P[:, 0] * sx) > 0.005
            rad[sel, 0] -= sx * F.hip_x
        rad[:, 2] = 0
        rn = rad / np.maximum(np.linalg.norm(rad, axis=1)[:, None], 1e-9)
        P += rn * d[:, None] * (zz < hz - 0.1)[:, None]
        S.set_verts(ob, P)
        S.decimate(ob, 0.24)
        self.reg(self.t(ob, part, "cloth"), "dist")
        return ob

    def shoes(self, part="shoe", sole_part="sole", high=0.050, shaft=None):
        """Sapato SKIN com sola chanfrada. G23: `shaft=(z_topo, raio)` sobe um cano (bota/tenis de cano) por DENTRO da barra
        da calca, ate `z_topo` acima do tornozelo, com raio menor que o da calca: a barra cobre o topo do cano em toda a volta
        e em todos os quadros, e nao sobra vao entre a calca e o sapato."""
        F, v = self.F, self.v
        bk = v["boot"]
        for sx, sd in ((1, "R"), (-1, "L")):
            x = sx * F.hip_x
            nn = [((x, -0.006, F.ankle_z + high), 0.050 * bk), ((x, -0.012, F.ankle_z - 0.010), 0.055 * bk),
                  ((x, F.ball_y * 0.70, 0.042 * bk), 0.054 * bk), ((x, F.toe_y - 0.036 * bk, 0.040 * bk), 0.046 * bk)]
            ee = [(0, 1), (1, 2), (2, 3)]
            if shaft:
                # o cano vira a ponta da corrente (raiz do SKIN): sem ramificacao no tornozelo, que dobrava a malha em quina;
                # o no do peito do pe afina para o cano sair sem degrau
                nn[0] = (nn[0][0], 0.5 * (nn[0][1] + shaft[1]))
                nn.insert(0, ((x, -0.004, F.ankle_z + shaft[0]), shaft[1]))
                ee = [(0, 1), (1, 2), (2, 3), (3, 4)]
            ob = cl.skin_obj(self.name("Shoe" + sd), nn, ee, self.M["botas"], levels=3, floor=0.020 * bk)
            S.decimate(ob, 0.20)
            self.reg(self.t(ob, part, "gear"), "dist")
            bm = bmesh.new()
            pts = []
            n_ = 22
            cy = (F.heel_y + F.toe_y) * 0.5 - 0.004
            ry = (F.toe_y - F.heel_y) * 0.5 + 0.012 * bk
            for i in range(n_):
                a = 2 * math.pi * i / n_
                rx = 0.054 * bk * (1.0 + 0.12 * math.sin(a))
                pts.append((math.cos(a) * rx, cy + math.sin(a) * ry))
            back = [bm.verts.new((x + px, py, 0.0)) for px, py in pts]
            front = [bm.verts.new((x + px * 1.02, py, 0.024 * bk)) for px, py in pts]
            bm.faces.new(list(reversed(back)))
            bm.faces.new(front)
            for i in range(n_):
                j = (i + 1) % n_
                bm.faces.new((back[i], back[j], front[j], front[i]))
            bmesh.ops.bevel(bm, geom=bm.edges[:], offset=0.005, segments=1, affect="EDGES")
            self.reg(self.t(new_object(self.name("Sole" + sd), bm, self.M["creme"]), sole_part, "gear"), "dist")

    # ------------------------------------------------------------ montagem
    def body(self):
        self.neck()
        self.hands()

    def uniform_details(self):
        pass

    def gear(self):
        pass

    def hat(self):
        return []

    def snap_z(self, ob, x, y, z0=3.0):
        """Altura da superficie de `ob` vista de cima em (x, y)."""
        from mathutils.bvhtree import BVHTree
        bvh = BVHTree.FromObject(ob, bpy.context.evaluated_depsgraph_get())
        hit = bvh.ray_cast(V(x, y, z0), V(0, 0, -1))
        return hit[0].z if hit[0] is not None else None

    def fix_wrist_weights(self, ob):
        """Mao: o trecho dentro da manga segue o antebraco; do pulso para a frente, a mao (transicao curta no pulso)."""
        F = self.F
        vg = {g.name: g for g in ob.vertex_groups}
        for sx, s in ((1, "R"), (-1, "L")):
            el = V(sx * F.elbow.x, F.elbow.y, F.elbow.z)
            W = V(sx * F.wrist.x, F.wrist.y, F.wrist.z)
            d = (W - el)
            L = d.length
            d = d / L
            for vx in ob.data.vertices:
                if (vx.co.x > 0) != (sx > 0):
                    continue
                u = (vx.co - W).dot(d)               # < 0: antebraco; > 0: depois do pulso
                wh = min(1.0, max(0.0, (u + 0.012) / 0.024))
                for g in list(vx.groups):
                    ob.vertex_groups[g.group].remove([vx.index])
                if wh < 0.999:
                    vg["forearm." + s].add([vx.index], 1.0 - wh, "REPLACE")
                if wh > 0.001:
                    vg["hand." + s].add([vx.index], wh, "REPLACE")

    def fix_skirt_weights(self, ob, hem_z):
        """Barra do casaco/saia abaixo do quadril: pesos repartidos entre quadril e coxas (nao estica com a perna)."""
        F = self.F
        vg = {g.name: g for g in ob.vertex_groups}
        for vx in ob.data.vertices:
            z = vx.co.z
            if z > F.hz - 0.02:
                continue
            t = min(1.0, (F.hz - 0.02 - z) / max(F.hz - 0.02 - hem_z, 0.05))
            side = "R" if vx.co.x > 0 else "L"
            ax = min(1.0, abs(vx.co.x) / (F.hip_x * 1.6))
            wt = 0.42 * t * ax
            for g in list(vx.groups):
                ob.vertex_groups[g.group].remove([vx.index])
            vg["hips"].add([vx.index], 1.0 - wt, "REPLACE")
            if wt > 0.01:
                vg["thigh." + side].add([vx.index], wt, "REPLACE")


# ------------------------------------------------------------------ idle adulto (G4 r2)
def pose_idle_adult(R, F, t, T):
    """Em pe e relaxado: bracos soltos junto ao corpo (cotovelo e pulso levemente dobrados, maos viradas para a coxa),
    respiracao no peito e nos ombros, peso que passa devagar de um pe para o outro, cabeca olhando em volta."""
    import hero_anim as ha
    from char_anim import blink_curve, stand_feet, torso
    from char_lib import eul
    ph = 2 * math.pi * t / T
    breath = math.sin(ph)
    sway = math.sin(ph * 0.5)
    R.hips_off = Vector((0.006 * sway, 0.0, -0.006 + 0.0025 * breath))
    torso(R, lean=1.0 + 0.9 * breath, roll=1.2 * sway, head_yaw=7.0 * math.sin(ph * 0.5 + 0.6), head_pitch=1.2 * math.sin(ph + 1.0),
          head_roll=1.5 * math.sin(ph + 2.0))
    for s, sx in (("R", 1), ("L", -1)):
        R.rel("shoulder." + s, eul(y=-1.2 * sx * (0.5 + 0.5 * breath)))
        R.rel("upper_arm." + s, eul(x=4.0 + 1.5 * breath, y=1.5 * sx - 0.6 * sx * breath))
        R.rel("forearm." + s, eul(x=13.0 + 2.5 * breath))
        R.rel("hand." + s, eul(x=8.0))
    stand_feet(R)
    return ha.face(blink=blink_curve(t, 1.0) + blink_curve(t, T - 0.6))
