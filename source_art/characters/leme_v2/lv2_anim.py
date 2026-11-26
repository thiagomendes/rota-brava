"""Leme v2: animacoes. Mesmo esqueleto de 28 ossos e os MESMOS 12 nomes de clipe da Leme do jogo (leme.glb):
idle, walk, run, stop, idle_wheel, steer_left, steer_right, react_horn, celebrate, wave, point, team_pose.
Novos nesta proposta: `idle` (gira a bussola de pulso e depois olha o horizonte sorrindo, mao na cintura), `team_pose`
(v2.2 pilota, D16: mao direita no fone, joinha da esquerda, base aberta) e `wave` (aceno aberto, braco alto, palma
para a frente). Os demais vem de source_art/scripts/hero_anim.py. FK + IK de 2 ossos, 30 fps, sem root motion. PROVISORIO.

Sem ossos de dedo (28 ossos): as luvas tem shape keys fist_R/fist_L (punho) e thumb_up_R/thumb_up_L (joinha),
animadas por clipe numa Action propria (<clipe>_hand): punhos no celebrate, joinha da mao esquerda no team_pose (junto da
continencia) e pegada leve no volante (idle_wheel/steer). Contato dos pes: a sola nunca afunda no chao ao rolar o pe
(put_foot corrigido abaixo com os pontos reais da sola).
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPTS = os.path.abspath(os.path.join(HERE, "..", "..", "scripts"))
for p in (HERE, SCRIPTS):
    if p not in sys.path:
        sys.path.insert(0, p)

import bpy
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

import char_anim
import char_lib as cl
import hero_anim as ha
from char_anim import blink_curve, foot_ankle, lerp, put_foot, reach, smooth, stand_feet, torso
from char_lib import eul

FPS = ha.FPS


# ------------------------------------------------------------------ pes: a sola nunca afunda ao rolar o pe
_PUT_FOOT = char_anim.put_foot
SOLE = {}


def put_foot_sole(R, s, heel_y, phi=0.0, pivot="heel", lift=0.0, dx=0.0, pole=None, ankle=None):
    """put_foot do char_anim, mas se algum ponto real da sola (pontos de repouso em SOLE[s]) ficar abaixo do chao com o pe
    rolado (pivo no osso do calcanhar ou da bola, acima da borda da sola), o tornozelo sobe o que falta."""
    a = ankle if ankle is not None else foot_ankle(R, s, heel_y, phi, pivot, lift, dx)
    pts = SOLE.get(s)
    if pts is not None and len(pts):
        a0, b0 = np.array(R.rest_head["foot." + s]), np.array(R.rest_head["toe." + s])
        c, sn = math.cos(math.radians(phi)), math.sin(math.radians(phi))
        rel = pts - a0
        zf = a.z + rel[:, 1] * sn + rel[:, 2] * c                    # Rx(phi): z' = y sin + z cos
        if phi < 0.0:
            # dedos: o osso toe fica plano, mas a pele da ponta da sola tem peso dividido com o osso do pe (que gira para
            # baixo) -- vale o pior dos dois (a ponta afundava ate 4 mm no impulso do walk/run)
            tz = a.z + (b0 - a0)[1] * sn + (b0 - a0)[2] * c
            toe = pts[:, 1] > b0[1]
            zf = np.where(toe, np.minimum(zf, tz + (pts[:, 2] - b0[2])), zf)
        low = float(zf.min()) - (0.0010 if abs(phi) > 0.2 else 0.0)   # folga para o peso dividido com a canela
        if low < 0.0:
            a = Vector((a.x, a.y, a.z - low))
    return _PUT_FOOT(R, s, heel_y, phi, pivot, lift, dx, pole, ankle=a)


def fix_soles(sole):
    """Liga a correcao da sola em todos os clipes (hero_anim, char_anim e este modulo usam put_foot por nome)."""
    global put_foot
    SOLE.clear()
    SOLE.update({k: np.asarray(v, dtype=float) for k, v in sole.items()})
    char_anim.put_foot = put_foot_sole
    ha.put_foot = put_foot_sole
    put_foot = put_foot_sole


def head_point(R, p_rest):
    """Posicao atual de um ponto preso a cabeca (dado em repouso)."""
    return R.pos["head"] + R.acc["head"] @ (Vector(p_rest) - R.rest_head["head"])


def pose_idle_lv2(R, F, t, T):
    """5,2 s em loop: respira com o peso alternando entre as pernas; ergue o pulso esquerdo e gira o aro da bussola com a mao
    direita (olha para ela, atenta); baixa; vira o rosto para o mar (direita), queixo erguido e sorriso, mao direita na
    cintura (pose de capita); volta."""
    ph = 2 * math.pi * t / T
    breath = math.sin(2 * ph)
    comp = smooth(t, 0.5, 1.0) * (1 - smooth(t, 2.6, 3.0))
    turn = smooth(t, 1.0, 1.25) * (1 - smooth(t, 2.35, 2.6))
    sea = smooth(t, 3.0, 3.5) * (1 - smooth(t, 4.6, 5.1))
    brim = smooth(t, 3.0, 3.45) * (1 - smooth(t, 4.5, 5.0))
    shift = 0.5 + 0.5 * math.cos(ph)                       # peso alterna devagar (contrapposto leve)
    R.hips_off = Vector((0.010 * (shift - 0.5) * 2, 0.0, -0.011 + 0.003 * breath - 0.004 * shift))
    R.rel("hips", eul(y=2.5 * (shift - 0.5) * 2, z=5.0 * sea))
    torso(R, lean=1.5 + 0.6 * breath + 5.0 * comp - 3.0 * sea, yaw=-4.0 * comp + 12.0 * sea, roll=-1.5 * (shift - 0.5) * 2,
          head_pitch=1.2 * math.sin(ph + 1.2) - 24.0 * comp + 12.0 * sea, head_yaw=8.0 * comp + 26.0 * sea,
          head_roll=-4.0 * comp + 5.0 * sea)
    ha.arms_down(R, F, bend=14 + 2 * breath, out=7 + breath)
    if comp > 0.001:
        R.evaluate()
        rest = R.tip("hand.L")
        tgt = Vector((0.03, F.v["belly"] + 0.15, F.sh.z - 0.10))
        reach(R, "L", rest.lerp(tgt, comp), Vector((-0.1, 0.2, -1.0)).lerp(Vector((1.0, 0.30, 0.10)), comp), pole=(-1.0, -0.3, -0.6),
              roll=-40.0 * comp)
        R.evaluate()
        # centro da bussola: dorso do pulso esquerdo, um pouco para cima
        w = R.pos["hand.L"]
        fa = (R.pos["hand.L"] - R.pos["forearm.L"]).normalized()
        c = w - fa * F.compass_back + Vector((0, 0.0, 0.034))   # a bussola subiu pelo antebraco (acima do punho da luva)
        a = 2 * math.pi * 1.4 * smooth(t, 1.1, 2.4)
        circ = Vector((0.012 * math.cos(a), 0.012 * math.sin(a), 0.0)) * turn
        restr = R.tip("hand.R")
        reach(R, "R", restr.lerp(c + circ + Vector((0.0, -0.004, 0.012)), comp * 0.92),
              Vector((0.1, 0.2, -1.0)).lerp(Vector((-0.75, 0.25, -0.55)), comp), pole=(1.0, -0.5, -0.4))
    if brim > 0.001:
        R.evaluate()
        restr = R.tip("hand.R")
        hip = Vector((F.v["belly"] + 0.045, 0.012, F.hz + 0.065))
        reach(R, "R", restr.lerp(hip, brim), Vector((0.1, 0.2, -1.0)).lerp(Vector((-0.45, 0.05, -0.9)), brim), pole=(1.0, -0.9, 0.3))
    stand_feet(R)
    # G1 (RB-R1): "alegre" e o sorriso de OLHOS FECHADOS. Antes ele seguia o "sea" inteiro (~1,8 s de olhos fechados a cada
    # 5,2 s; 39% do idle), e a Leme parecia dormir no menu e nas cenas. Agora so um "sorriso de olhos" curto (~0,5 s) quando
    # o rosto chega ao mar; depois os olhos ficam abertos com a boca neutra (que ja sorri de leve) ate voltar.
    squint = smooth(t, 3.25, 3.45) * (1 - smooth(t, 3.75, 3.95))
    return ha.face(atenta=0.75 * comp, alegre=0.95 * squint + 0.2 * (1 - comp) * (1 - sea),
                   blink=blink_curve(t, 0.25) + blink_curve(t, 2.8) + blink_curve(t, 4.85))


TEAM_ROLL = -20.0          # giro da mao direita no fone (ajustado olhando o palmo: dedos para cima, palma na concha)
TEAM_DIR = (-0.30, -0.10, 1.0)


def pose_team_lv2(R, F, t, T):
    """Pose de equipe de PILOTA (1,5 s, D16): pequeno impulso, pousa na base aberta, MAO DIREITA NO FONE (como quem fala no
    radio: "na escuta!"), JOINHA da esquerda a frente do peito, peito aberto, queixo erguido e sorriso; segura e assenta."""
    pre = smooth(t, 0.0, 0.14) * (1 - smooth(t, 0.14, 0.26))
    air = math.sin(math.pi * min(max((t - 0.20) / 0.22, 0.0), 1.0))
    a = smooth(t, 0.14, 0.44) * (1 - smooth(t, 1.22, 1.5))
    land = math.sin(math.pi * min(max((t - 0.40) / 0.22, 0.0), 1.0))
    R.hips_off = Vector((0.0, 0.0, -0.036 * pre + 0.040 * air - 0.026 * land - 0.010 * a))
    R.rel("hips", eul(z=6.0 * a))
    torso(R, lean=lerp(2.0, -6.0, a) + 9 * pre, yaw=-6.0 * a, roll=2.0 * a, head_pitch=7.0 * a, head_roll=-7.0 * a, head_yaw=4.0 * a)
    ha.arms_down(R, F, bend=14, out=6)
    R.evaluate()
    rr, rl = R.tip("hand.R"), R.tip("hand.L")
    cup = head_point(R, F.cup_out_R) + Vector((0.028, -0.014, 0.030))
    reach(R, "R", rr.lerp(cup, a), Vector((0.1, 0.2, -1.0)).lerp(Vector(TEAM_DIR), a), pole=(1.0, -0.35, -0.35), roll=TEAM_ROLL * a)
    # mao esquerda: JOINHA a frente do peito (punho deitado, polegar para cima), cotovelo baixo
    thumb = Vector((-0.085, F.v["belly"] + 0.17, F.sh.z - 0.11))
    reach(R, "L", rl.lerp(thumb, a), Vector((-0.1, 0.2, -1.0)).lerp(Vector((0.25, 1.0, 0.10)), a), pole=(-0.8, -0.4, -1.0))
    for s, sx, dx, dy in (("R", 1, 0.030, 0.020), ("L", -1, -0.030, -0.020)):
        put_foot(R, s, R.rest_head["heel." + s].y + dy * a, 0.0, "heel", lift=0.025 * air, dx=dx * a, pole=(sx * 0.25, 1.0, 0.0))
    f = ha.face(alegre=smooth(t, 0.1, 0.35) * (1 - smooth(t, 1.3, 1.5)), atenta=0.4 * pre)
    f["thumb_up_L"] = smooth(t, 0.22, 0.44) * (1 - smooth(t, 1.20, 1.42))
    return f


def pose_celebrate_lv2(R, F, t, T):
    """celebrate da Leme do jogo, agora com os dois punhos FECHADOS no alto do salto (shape keys fist_R/fist_L)."""
    f = ha.pose_celebrate(R, F, t, T)
    f["fist_R"] = f["fist_L"] = smooth(t, 0.12, 0.32) * (1 - smooth(t, 0.95, 1.2))
    return f


def pose_idle_wheel_lv2(R, F, t, T):
    f = ha.pose_idle_wheel(R, F, t, T)
    f["fist_R"] = f["fist_L"] = 0.45             # pegada leve no aro do volante
    return f


def pose_steer_lv2(sign):
    def fn(R, F, t, T):
        f = ha.pose_steer(R, F, t, T, sign)
        f["fist_R"] = f["fist_L"] = 0.45
        return f
    return fn


def pose_wave_lv2(R, F, t, T):
    """Aceno aberto (1,6 s): braco direito bem alto e aberto para o lado, palma para a frente, balanca do pulso e do
    antebraco; ombro e cabeca acompanham; sorriso."""
    a = smooth(t, 0.08, 0.32) * (1 - smooth(t, 1.28, 1.58))
    ph = 2 * math.pi * t * 2.4
    R.hips_off = Vector((-0.006 * a, 0, -0.010))
    torso(R, lean=1.0, roll=5 * a, head_roll=-6 * a + 3 * a * math.sin(ph * 0.5), head_pitch=5 * a, head_yaw=-4 * a)
    ha.arms_down(R, F, bend=14, out=6)
    R.evaluate()
    rest = R.tip("hand.R")
    tgt = Vector((F.sh.x + 0.20 + 0.05 * math.sin(ph), 0.08, F.sh.z + 0.30 - 0.012 * abs(math.sin(ph))))
    hd = Vector((0.15 + 0.55 * math.sin(ph), 0.10, 1.0))
    reach(R, "R", rest.lerp(tgt, a), Vector((0.1, 0.2, -1.0)).lerp(hd, a), pole=(1.0, -0.2, -0.6), roll=-75.0 * a)
    stand_feet(R)
    return ha.face(alegre=a, blink=0.0)


def short_squint(fn, t0, t1):
    """G1 (RB-R1): "alegre" e o sorriso de OLHOS FECHADOS; nos gestos ele durava ~1,2 s e, no close da abertura e no menu,
    a heroina parecia de olhos fechados. Mantem o sorriso so num aperto curto (~0,45 s com peso >= 0,5) entre t0 e t1;
    fora dele a boca volta a neutra (que ja sorri de leve) e os olhos ficam abertos. Corpo e demais chaves iguais."""
    def g(R, F, t, T):
        f = fn(R, F, t, T)
        f["alegre"] = f.get("alegre", 0.0) * smooth(t, t0 - 0.12, t0) * (1 - smooth(t, t1, t1 + 0.12))
        return f
    return g


def blink_once(fn, at):
    """G1 (RB-R1): troca a piscada do clipe por uma so em `at`. O `point` (1,2 s, sem laco) piscava em 1,05 s e terminava
    com o olho 62% fechado; parado no ultimo quadro (close da abertura), a heroina ficava de olho quase fechado."""
    def g(R, F, t, T):
        f = fn(R, F, t, T)
        f["blink"] = blink_curve(t, at)
        return f
    return g


CLIPS = dict(ha.CLIPS)
CLIPS["team_pose"] = (1.5, False, pose_team_lv2)
CLIPS["wave"] = (1.6, False, pose_wave_lv2)
CLIPS["celebrate"] = (CLIPS["celebrate"][0], False, pose_celebrate_lv2)
CLIPS["idle_wheel"] = (CLIPS["idle_wheel"][0], True, pose_idle_wheel_lv2)
CLIPS["steer_left"] = (CLIPS["steer_left"][0], False, pose_steer_lv2(+1))
CLIPS["steer_right"] = (CLIPS["steer_right"][0], False, pose_steer_lv2(-1))
IDLE = (5.2, pose_idle_lv2)
# ciclos v2 (pedido de Thiago, 2026-11-25: "pes muito acelerados"): passada longa para escala ~1 no jogo (1,4 e 3,2 m/s).
# Leme: firme, pilota -- peito aberto e tronco ereto, quique pequeno, joelhos um pouco para fora, punhos firmes na corrida.
import hero_gait_v2 as hg
WALK = hg.gait_cfg(1.0, 0.47, 1.4 / 1.15, center=-0.035, lift=0.055, lift_at=0.46, phi_land=12.0, phi_push=-27.0,
                   hip_yaw=10.0, hip_roll=2.0, base=-0.032, bob=0.004, lean=1.5, torso_yaw=6.0, head_pitch=-3.0,
                   head_yaw=-2.0, head_roll=1.0, arm_swing=24.0, arm_bend=16.0, arm_out=8.0, blink_at=0.55,
                   knee_out=0.10, face={"fist_R": 0.3, "fist_L": 0.3})
RUN = hg.gait_cfg(19 / 30, 0.47, 3.2 * (19 / 30) / 1.15, center=-0.03, lift=0.105, lift_at=0.43, lift_p=2.0,
                  phi_land=6.0, phi_push=-35.0, phi_mid=-22.0, land_u=0.10, push_u=0.45, low_w=0.12, skim=0.012,
                  hip_yaw=8.0, hip_roll=2.0, bob_mode="run", base=-0.032, bob=0.007, lean=10.0, torso_yaw=8.0,
                  head_pitch=4.0, head_yaw=-1.5, head_roll=1.0, arm_swing=52.0, arm_bend=76.0, arm_out=10.0, arm_pump=0.3,
                  blink_at=None, knee_out=0.10, face={"atenta": 0.4, "fist_R": 0.9, "fist_L": 0.9})
CLIPS["walk"] = hg.clip(WALK)
CLIPS["run"] = hg.clip(RUN)
# G1: sorriso de olhos fechados curto nos gestos (antes 0,92-1,22 s seguidos; janela no pico do gesto)
for _n, (_a, _b) in {"wave": (0.68, 1.01), "celebrate": (0.50, 0.83), "team_pose": (0.68, 1.01)}.items():
    CLIPS[_n] = (CLIPS[_n][0], CLIPS[_n][1], short_squint(CLIPS[_n][2], _a, _b))
CLIPS["point"] = (CLIPS["point"][0], CLIPS["point"][1], blink_once(CLIPS["point"][2], 0.80))
CLIP_SET = ["idle", "walk", "run", "stop", "idle_wheel", "steer_left", "steer_right", "react_horn", "celebrate", "wave", "point", "team_pose"]
HAND_KEYS = ("fist_R", "fist_L", "thumb_up_R", "thumb_up_L")


def author(rig, face_ob, F, names=CLIP_SET, hand_ob=None, sole=None):
    """Grava cada clipe como Action + faixa NLA (corpo), Action de shape keys (rosto) e, se houver, Action das shape keys das
    maos (<clipe>_hand), como no Rastro v2.1. `sole`: pontos de repouso da sola por lado (ver fix_soles)."""
    if sole is not None:
        fix_soles(sole)
    R = cl.Rigger(rig)
    sk = face_ob.data.shape_keys
    sk.animation_data_create()
    hk = hand_ob.data.shape_keys if hand_ob is not None and hand_ob.data.shape_keys else None
    if hk is not None:
        hk.animation_data_create()
    rig.animation_data_create()
    prev = {}
    report = {}
    for name in names:
        dur, loop, fn = CLIPS[name]
        if name == "idle":
            dur, fn = IDLE
        act = bpy.data.actions.new(name)
        act.use_fake_user = True
        keyact = bpy.data.actions.new(name + "_key")
        keyact.use_fake_user = True
        rig.animation_data.action = act
        sk.animation_data.action = keyact
        handact = None
        if hk is not None:
            handact = bpy.data.actions.new(name + "_hand")
            handact.use_fake_user = True
            hk.animation_data.action = handact
        n = int(round(dur * FPS))
        prev.clear()
        best = 9.0
        for i in range(n + 1):
            t = dur * i / n
            R.reset()
            fc = fn(R, F, t, dur)
            R.evaluate()
            if name == "idle_wheel":
                best = min(best, ((R.tip("hand.R") + R.tip("hand.L")) * 0.5 - ha.WHEEL_C).length)
            R.apply(i, prev)
            for kn in ha.FACE_KEYS:
                kb = sk.key_blocks[kn]
                kb.value = max(0.0, min(1.0, fc.get(kn, 0.0)))
                kb.keyframe_insert("value", frame=i)
            if hk is not None:
                for kn in HAND_KEYS:
                    kb = hk.key_blocks[kn]
                    kb.value = max(0.0, min(1.0, fc.get(kn, 0.0)))
                    kb.keyframe_insert("value", frame=i)
        if name == "idle_wheel":
            report["wheel_mid_err_m"] = round(best, 4)
        act["loop"] = loop
        pairs = [(rig.animation_data, act), (sk.animation_data, keyact)]
        if hk is not None:
            pairs.append((hk.animation_data, handact))
        for ad, a_ in pairs:
            ad.action = None
            tr = ad.nla_tracks.new()
            tr.name = name
            st = tr.strips.new(name, 0, a_)
            st.name = name
    return report


# ------------------------------------------------------------------ medidas (botas nunca se tocam; pes sem patinar)
BOOT_PARTS = ("boot", "sole", "boot_collar", "boot_strap", "boot_tab")


def _use_clip(rig, face_ob, name):
    for ad in (rig.animation_data, face_ob.data.shape_keys.animation_data):
        for tr in ad.nla_tracks:
            tr.mute = True
    rig.animation_data.action = bpy.data.actions[name]
    face_ob.data.shape_keys.animation_data.action = bpy.data.actions[name + "_key"]


def _restore(rig, face_ob):
    for ad in (rig.animation_data, face_ob.data.shape_keys.animation_data):
        ad.action = None
        for tr in ad.nla_tracks:
            tr.mute = False


def measure_feet(rig, gear_ob, face_ob, F, part_ids, names=CLIP_SET):
    """Para cada clipe e quadro: menor distancia entre as malhas das duas botas (vertice -> superficie da outra, nos dois
    sentidos) e, no walk/run, a velocidade do pe de apoio contra a velocidade nominal (deslize)."""
    sc = bpy.context.scene
    me = gear_ob.data
    n = len(me.vertices)
    pid = np.empty(n, dtype=np.float32)
    me.attributes["rbpart"].data.foreach_get("value", pid)
    pid = np.rint(pid * 100).astype(int)
    co = np.empty(n * 3)
    me.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    boot = np.isin(pid, [part_ids[p] for p in BOOT_PARTS])
    sideR = boot & (co[:, 0] > 0)
    sideL = boot & (co[:, 0] < 0)
    polys = [list(p.vertices) for p in me.polygons]
    idxR, idxL = np.where(sideR)[0], np.where(sideL)[0]
    polR = [p for p in polys if all(sideR[i] for i in p)]
    polL = [p for p in polys if all(sideL[i] for i in p)]
    soleR = np.where(sideR & (pid == part_ids["sole"]))[0]
    soleL = np.where(sideL & (pid == part_ids["sole"]))[0]
    dg = bpy.context.evaluated_depsgraph_get()
    out = {"min_m": 9.0, "min_clip": None, "min_frame": None, "por_clipe": {}, "deslize": {}}
    for name in names:
        act = bpy.data.actions[name]
        f0, f1 = int(act.frame_range[0]), int(act.frame_range[1])
        _use_clip(rig, face_ob, name)
        cmin, cfr = 9.0, None
        soles = []
        for fr in range(f0, f1 + 1):
            sc.frame_set(fr)
            dg = bpy.context.evaluated_depsgraph_get()
            ev = gear_ob.evaluated_get(dg)
            em = ev.to_mesh()
            P = np.empty(len(em.vertices) * 3)
            em.vertices.foreach_get("co", P)
            ev.to_mesh_clear()
            P = P.reshape(-1, 3)
            mw = np.array(gear_ob.matrix_world)
            P = P @ mw[:3, :3].T + mw[:3, 3]
            best = 9.0
            for A, B, polB in ((idxL, idxR, polR), (idxR, idxL, polL)):
                bvh = BVHTree.FromPolygons([tuple(v) for v in P], polB, all_triangles=False)
                for i in A:
                    h = bvh.find_nearest(Vector(P[i]))
                    if h[0] is not None and h[3] < best:
                        best = h[3]
            if best < cmin:
                cmin, cfr = best, fr
            soles.append((P[soleR], P[soleL]))
        out["por_clipe"][name] = {"min_m": round(cmin, 4), "quadro": cfr}
        if cmin < out["min_m"]:
            out["min_m"], out["min_clip"], out["min_frame"] = round(cmin, 4), name, cfr
        if name in ("walk", "run"):
            nominal = hg.nominal_speed(WALK if name == "walk" else RUN)   # ciclos v2
            errs = []
            for side in (0, 1):
                for i in range(len(soles) - 1):
                    a, b = soles[i][side], soles[i + 1][side]
                    c = (a[:, 2] < 0.002) & (b[:, 2] < 0.002)        # vertices da sola em contato nos dois quadros
                    if c.sum() < 3:
                        continue
                    v = (b[c] - a[c]) * FPS
                    e = np.hypot(v[:, 0], v[:, 1] + nominal)          # o pe de apoio deve recuar exatamente a velocidade nominal
                    errs.append(float(np.median(e)))
            out["deslize"][name] = {"nominal_mps": round(nominal, 4), "pares_de_quadros_em_apoio": len(errs),
                                    "erro_medio_mps": round(float(np.mean(errs)), 4) if errs else None,
                                    "erro_max_mps": round(float(np.max(errs)), 4) if errs else None,
                                    "min_z_m": round(float(min(min(s[0][:, 2].min(), s[1][:, 2].min()) for s in soles)), 4)}
    _restore(rig, face_ob)
    sc.frame_set(0)
    return out
