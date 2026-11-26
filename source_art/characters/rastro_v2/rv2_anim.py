"""Rastro v2: animacoes. Reusa o esqueleto de 28 ossos e os 12 clipes do Rastro atual (source_art/scripts/hero_anim.py),
com os MESMOS nomes que o jogo usa; troca o `idle` (confere o scanner de pulso) e o `team_pose` (pose de heroi com atitude).
FK + IK de 2 ossos, 30 fps, sem root motion. PROVISORIO.
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
from mathutils import Vector

import char_lib as cl
import hero_anim as ha
from char_anim import blink_curve, lerp, put_foot, reach, smooth, stand_feet, torso
from char_lib import eul

FPS = ha.FPS


def pose_idle_v2(R, F, t, T):
    """4,4 s: respira, olha em volta, ergue o antebraco esquerdo e confere o scanner de pulso (toca a tela com a direita)."""
    ph = 2 * math.pi * t / T
    breath = math.sin(2 * ph)
    look = smooth(t, 0.4, 0.8) * (1 - smooth(t, 1.2, 1.6)) - smooth(t, 1.5, 1.9) * (1 - smooth(t, 2.1, 2.4))
    scan = smooth(t, 2.3, 2.75) * (1 - smooth(t, 3.75, 4.25))
    tap = math.sin(math.pi * smooth(t, 3.0, 3.45)) * scan
    R.hips_off = Vector((0.004 * math.sin(ph), 0.0, -0.010 + 0.003 * breath))
    R.rel("hips", eul(z=4.0 * scan))
    torso(R, lean=2.0 + 0.6 * breath + 4.0 * scan, yaw=6.0 * scan, roll=-2.0 * scan,
          head_pitch=1.5 * math.sin(ph + 1.2) - 20.0 * scan, head_yaw=26.0 * look + 16.0 * scan, head_roll=3.0 * look - 5.0 * scan)
    ha.arms_down(R, F, bend=16 + 2 * breath, out=7 + breath)
    if scan > 0.001:
        R.evaluate()
        rest = R.tip("hand.L")
        tgt = Vector((0.02, F.v["belly"] + 0.17, F.sh.z - 0.07))
        reach(R, "L", rest.lerp(tgt, scan), Vector((-0.1, 0.2, -1.0)).lerp(Vector((1.0, 0.35, 0.05)), scan), pole=(-1.0, -0.3, -0.6))
        R.evaluate()
        restr = R.tip("hand.R")
        tr = Vector((0.03, F.v["belly"] + 0.20, F.sh.z - 0.02 - 0.03 * tap))
        reach(R, "R", restr.lerp(tr, scan * 0.85), Vector((0.1, 0.2, -1.0)).lerp(Vector((-0.6, 0.5, -0.5)), scan), pole=(1.0, -0.4, -0.6))
    stand_feet(R)
    # sem "alegre" parcial: no hero_face a palpebra parcial afunda o branco do olho (parecia mancha escura sob o olho)
    return ha.face(atenta=0.7 * scan, blink=blink_curve(t, 1.0) + blink_curve(t, 3.6))



def pose_team_v2(R, F, t, T):
    """Pose de equipe (1,5 s), v2.1: impulso curto, pulinho para a pose e contrapposto: peso na perna esquerda (o quadril
    desloca e cai do lado direito), perna direita solta com o calcanhar erguido, ombro direito sobe com o punho FECHADO ao
    alto (shape key fist_R), mao esquerda na cintura, cabeca inclinada para o punho, queixo erguido e sorriso; segura e assenta."""
    pre = smooth(t, 0.0, 0.12) * (1 - smooth(t, 0.12, 0.24))
    air = math.sin(math.pi * min(max((t - 0.18) / 0.22, 0.0), 1.0))
    a = smooth(t, 0.14, 0.46) * (1 - smooth(t, 1.24, 1.5))
    land = math.sin(math.pi * min(max((t - 0.38) / 0.24, 0.0), 1.0))
    sway = math.sin(2 * math.pi * (t - 0.5) / 1.4) * smooth(t, 0.5, 0.7) * (1 - smooth(t, 1.1, 1.3))
    R.hips_off = Vector((-0.024 * a, 0.0, -0.040 * pre + 0.050 * air - 0.028 * land - 0.016 * a + 0.004 * sway))
    R.rel("hips", eul(z=-10.0 * a, y=6.0 * a))
    torso(R, lean=lerp(3.0, -8.0, a) + 10 * pre, yaw=12.0 * a, roll=-11.0 * a, head_pitch=9.0 * a + 2.0 * sway,
          head_roll=12.0 * a, head_yaw=-10.0 * a)
    R.rel("shoulder.R", eul(y=-10.0 * a))
    R.rel("shoulder.L", eul(y=-4.0 * a))
    ha.arms_down(R, F, bend=14, out=6)
    R.evaluate()
    rr, rl = R.tip("hand.R"), R.tip("hand.L")
    up = Vector((F.sh.x + 0.17, 0.10, F.sh.z + 0.36))
    reach(R, "R", rr.lerp(up, a), Vector((0.1, 0.2, -1.0)).lerp(Vector((0.18, 0.12, 1.0)), a), pole=(1.0, -0.2, -0.7), roll=-20.0 * a)
    hip = Vector((-F.v["belly"] - 0.040, 0.005, F.hz + 0.065))
    reach(R, "L", rl.lerp(hip, a), Vector((-0.1, 0.2, -1.0)).lerp(Vector((0.45, 0.05, -0.9)), a), pole=(-1.0, -0.9, 0.3))
    # perna de apoio (esquerda) firme; perna direita solta: um pouco a frente e para fora, calcanhar erguido
    put_foot(R, "L", R.rest_head["heel.L"].y - 0.012 * a, 0.0, "heel", lift=0.03 * air, dx=-0.020 * a, pole=(-0.25, 1.0, 0.0))
    phi = -16.0 * a if air < 0.05 else 0.0
    put_foot(R, "R", R.rest_head["heel.R"].y + 0.045 * a, phi, "ball" if phi < -0.5 else "heel", lift=0.03 * air, dx=0.040 * a,
             pole=(0.35, 1.0, 0.0))
    f = ha.face(alegre=smooth(t, 0.1, 0.35) * (1 - smooth(t, 1.3, 1.5)), atenta=0.4 * pre)
    f["fist_R"] = smooth(t, 0.20, 0.42) * (1 - smooth(t, 1.22, 1.45))
    return f


def pose_celebrate_v2(R, F, t, T):
    """celebrate do Rastro atual, agora com os dois punhos fechados no alto do salto."""
    f = ha.pose_celebrate(R, F, t, T)
    fist = smooth(t, 0.12, 0.32) * (1 - smooth(t, 0.95, 1.2))
    f["fist_R"] = f["fist_L"] = fist
    return f


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
CLIPS["team_pose"] = (1.5, False, pose_team_v2)
CLIPS["celebrate"] = (1.2, False, pose_celebrate_v2)
IDLE = (4.4, pose_idle_v2)
# ciclos v2 (pedido de Thiago, 2026-11-25: "pes muito acelerados"): passada longa para escala ~1 no jogo (1,4 e 3,2 m/s).
# Rastro: atenta e leve -- joelho levemente dobrado, quique curto, cabeca firme olhando a frente, maos soltas na corrida.
import hero_gait_v2 as hg
WALK = hg.gait_cfg(1.0, 0.46, 1.4 / 1.18, center=-0.035, lift=0.062, lift_at=0.44, phi_land=12.0, phi_push=-28.0,
                   hip_yaw=11.0, hip_roll=3.0, base=-0.030, bob=0.006, lean=5.0, torso_yaw=7.0, head_pitch=-2.0,
                   head_yaw=-3.0, head_roll=1.5, arm_swing=27.0, arm_bend=18.0, arm_out=7.0, blink_at=0.55,
                   face={"atenta": 0.25})
RUN = hg.gait_cfg(0.6, 0.46, 3.2 * 0.6 / 1.12, center=-0.03, lift=0.115, lift_at=0.42, lift_p=2.0, phi_land=6.0,
                  phi_push=-36.0, phi_mid=-24.0, land_u=0.10, push_u=0.45, low_w=0.12, skim=0.012, hip_yaw=9.0,
                  hip_roll=2.5, bob_mode="run", base=-0.030, bob=0.010, lean=12.0, torso_yaw=9.0, head_pitch=6.0,
                  head_yaw=-2.0, head_roll=2.0, arm_swing=50.0, arm_bend=72.0, arm_out=10.0, arm_pump=0.35, blink_at=None,
                  face={"atenta": 0.3, "alegre": 0.25, "fist_R": 0.45, "fist_L": 0.45})
CLIPS["walk"] = hg.clip(WALK)
CLIPS["run"] = hg.clip(RUN)
# G1: sorriso de olhos fechados curto nos gestos (antes 0,92-1,22 s seguidos; janela no pico do gesto)
for _n, (_a, _b) in {"wave": (0.68, 1.01), "celebrate": (0.50, 0.83), "team_pose": (0.68, 1.01),
                     "look_to_leme": (1.10, 1.43)}.items():
    CLIPS[_n] = (CLIPS[_n][0], CLIPS[_n][1], short_squint(CLIPS[_n][2], _a, _b))
CLIPS["point"] = (CLIPS["point"][0], CLIPS["point"][1], blink_once(CLIPS["point"][2], 0.80))
CLIP_SET = ["idle", "walk", "run", "stop", "crouch", "inspect_touch", "look_to_leme", "react_surprise", "point", "wave", "celebrate", "team_pose"]
GEAR_KEYS = ("fist_R", "fist_L")


def author(rig, face_ob, F, names=CLIP_SET, gear_ob=None):
    """Grava cada clipe como Action + faixa NLA (corpo), Action de shape keys do rosto e, se houver, das luvas (punho)."""
    R = cl.Rigger(rig)
    sk = face_ob.data.shape_keys
    sk.animation_data_create()
    gk = gear_ob.data.shape_keys if gear_ob is not None and gear_ob.data.shape_keys else None
    if gk is not None:
        gk.animation_data_create()
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
        gearact = None
        if gk is not None:
            gearact = bpy.data.actions.new(name + "_gear")
            gearact.use_fake_user = True
            gk.animation_data.action = gearact
        n = int(round(dur * FPS))
        prev.clear()
        best = 9.0
        for i in range(n + 1):
            t = dur * i / n
            R.reset()
            fc = fn(R, F, t, dur)
            R.evaluate()
            if name == "inspect_touch":
                best = min(best, (R.tip("hand.R") - ha.TOUCH_TARGET).length)
            R.apply(i, prev)
            for kn in ha.FACE_KEYS:
                kb = sk.key_blocks[kn]
                kb.value = max(0.0, min(1.0, fc.get(kn, 0.0)))
                kb.keyframe_insert("value", frame=i)
            if gk is not None:
                for kn in GEAR_KEYS:
                    kb = gk.key_blocks[kn]
                    kb.value = max(0.0, min(1.0, fc.get(kn, 0.0)))
                    kb.keyframe_insert("value", frame=i)
        if name == "inspect_touch":
            report["inspect_tip_err_m"] = round(best, 4)
        act["loop"] = loop
        pairs = [(rig.animation_data, act), (sk.animation_data, keyact)]
        if gk is not None:
            pairs.append((gk.animation_data, gearact))
        for ad, a_ in pairs:
            ad.action = None
            tr = ad.nla_tracks.new()
            tr.name = name
            st = tr.strips.new(name, 0, a_)
            st.name = name
    return report
