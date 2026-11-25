"""Pico v2: animacoes. Mesmo esqueleto de 28 ossos e os MESMOS 11 nomes de clipe do pico.glb atual (source_art/scripts/
hero_anim.py, conjunto "pico"); troca o `idle` (quica na ponta dos pes e alonga) e o `team_pose` (pulinho para a base aberta,
dois puxoes na corda a tiracolo, punho ao alto). FK + IK de 2 ossos, 30 fps, sem root motion. PROVISORIO.

Regra dos pes (pedido de Thiago): nenhum clipe aproxima os pes do eixo; o afastamento vem do rig (HIP_X em pv2_body) e os
deslocamentos laterais (dx) so abrem a base. Medido em pv2_check.py.
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
from char_anim import blink_curve, lerp, put_foot, reach, smooth, torso
from char_lib import eul

FPS = ha.FPS


def on_toes(R, lift_deg, dxs=(0.0, 0.0), lift=(0.0, 0.0)):
    """Pes plantados pela bola do pe (nao patinam); o calcanhar sobe `lift_deg` graus."""
    for s, dx, lf in (("R", dxs[0], lift[0]), ("L", dxs[1], lift[1])):
        put_foot(R, s, R.rest_head["heel." + s].y, -lift_deg, "ball", lift=lf, dx=dx, pole=((0.05 if s == "R" else -0.05), 1.0, 0.0))


def pose_idle_pico(R, F, t, T):
    """4,0 s em loop: tres quiques na ponta dos pes, alongamento com os bracos para o alto e inclinacao para o lado,
    sacode os bracos e mais dois quiques. Animado, nunca parado (o menor e mais energetico do trio)."""
    ph = 2 * math.pi * t / T
    breath = math.sin(2 * ph)
    hw1 = smooth(t, 0.05, 0.25) * (1 - smooth(t, 1.20, 1.45))
    hw2 = smooth(t, 3.05, 3.20) * (1 - smooth(t, 3.75, 3.95))
    b1 = 0.5 - 0.5 * math.cos(2 * math.pi * (t - 0.10) / 0.42)
    b2 = 0.5 - 0.5 * math.cos(2 * math.pi * (t - 3.10) / 0.40)
    hop = b1 * hw1 + b2 * hw2
    hw = hw1 + hw2
    st = smooth(t, 1.45, 1.85) * (1 - smooth(t, 2.70, 3.05))
    R.rel("shoulder.R", eul(y=-36.0 * st))
    R.rel("shoulder.L", eul(y=36.0 * st))
    side = math.sin(math.pi * smooth(t, 1.95, 2.70))
    shake = smooth(t, 2.85, 3.0) * (1 - smooth(t, 3.25, 3.45))
    R.hips_off = Vector((0.004 * math.sin(ph) - 0.010 * side * st, 0.0,
                         -0.012 + 0.003 * breath + 0.020 * hop - 0.010 * hw * (1 - hop) + 0.014 * st))
    R.rel("hips", eul(y=3.0 * side * st))
    torso(R, lean=2.0 + 0.6 * breath - 6.0 * st + 3.0 * hop, roll=-6.0 * side * st,
          head_pitch=3.0 * hop + 12.0 * st - 4.0 * hw * (1 - hop), head_roll=3.0 * math.sin(ph) - 8.0 * side * st,
          head_yaw=6.0 * math.sin(ph + 0.8) * (1 - st))
    sw = 10.0 * math.sin(2 * math.pi * t * 4.0) * shake
    ha.arms_down(R, F, bend=24 - 8 * hop + 6 * shake, out=8 + 5 * hop + 6 * shake, swing=(sw, -sw))
    if st > 0.001:
        R.evaluate()
        for s, sx in (("R", 1), ("L", -1)):
            rest = R.tip("hand." + s)
            tgt = Vector((sx * (F.sh.x - 0.01) - 0.04 * side, 0.04, F.sh.z + 0.62))
            reach(R, s, rest.lerp(tgt, st), Vector((0.1 * sx, 0.2, -1.0)).lerp(Vector((0.05 * sx, 0.05, 1.0)), st), pole=(sx * 1.0, -0.4, -0.3))
    on_toes(R, 22.0 * hop + 24.0 * st)
    # sorriso de olhos fechados so nos quiques e no alongamento (sem "alegre" parcial parado: a palpebra parcial afunda o
    # branco do olho e vira mancha escura na Godot, como visto no Rastro v2)
    return ha.face(alegre=max(hw, st), blink=blink_curve(t, 1.6) * (1 - max(hw, st)))


def pose_team_pico(R, F, t, T):
    """Pose de equipe do Pico (1,5 s): agacha, pulinho para a base aberta, mao esquerda agarra a corda a tiracolo e da dois
    puxoes, punho direito sobe bem alto; sorriso largo; assenta e volta ao neutro."""
    pre = smooth(t, 0.0, 0.12) * (1 - smooth(t, 0.12, 0.22))
    air = math.sin(math.pi * min(max((t - 0.18) / 0.26, 0.0), 1.0))
    land = math.sin(math.pi * min(max((t - 0.42) / 0.20, 0.0), 1.0))
    a = smooth(t, 0.14, 0.42) * (1 - smooth(t, 1.25, 1.5))
    grab = smooth(t, 0.30, 0.50) * (1 - smooth(t, 1.20, 1.45))
    tug = math.sin(math.pi * min(max((t - 0.52) / 0.16, 0.0), 1.0)) + math.sin(math.pi * min(max((t - 0.72) / 0.16, 0.0), 1.0))
    fist = smooth(t, 0.70, 0.95) * (1 - smooth(t, 1.22, 1.48))
    # o pe so muda de lugar no ar (pulinho de ida e pulinho de volta): nunca desliza no chao
    air2 = math.sin(math.pi * min(max((t - 1.20) / 0.24, 0.0), 1.0))
    wide = smooth(t, 0.22, 0.38) - smooth(t, 1.24, 1.40)
    R.hips_off = Vector((0.0, 0.0, -0.040 * pre + 0.060 * air + 0.030 * air2 - 0.034 * land - 0.016 * a - 0.008 * tug))
    R.rel("hips", eul(z=6.0 * a))
    torso(R, lean=lerp(2.0, -7.0, a) + 12 * pre + 4 * tug + 4.0 * fist, yaw=-8.0 * a, roll=4.0 * a - 18.0 * fist,
          head_pitch=8.0 * a + 4.0 * fist, head_roll=-8.0 * a - 4.0 * fist, head_yaw=10.0 * a)
    ha.arms_down(R, F, bend=20, out=8)
    R.evaluate()
    rr, rl = R.tip("hand.R"), R.tip("hand.L")
    up = Vector((F.sh.x - 0.01, 0.08, F.sh.z + 0.62))
    R.rel("shoulder.R", eul(y=-34.0 * fist))
    mid = Vector((F.sh.x + 0.16, 0.16, F.sh.z + 0.02))
    tr = rr.lerp(mid, smooth(t, 0.20, 0.55) * (1 - fist)).lerp(up, fist)
    reach(R, "R", tr, Vector((0.1, 0.2, -1.0)).lerp(Vector((0.1, 0.15, 1.0)), max(fist, 0.5 * a)), pole=(1.0, -0.5, -0.4))
    rope = Vector((0.045, F.v["belly"] + 0.060 - 0.010 * tug, F.sh.z - 0.050 - 0.040 * tug))
    reach(R, "L", rl.lerp(rope, grab), Vector((-0.1, 0.2, -1.0)).lerp(Vector((0.85, 0.35, 0.40)), grab), pole=(-1.0, -0.8, -0.2))
    lift = 0.040 * air + 0.030 * air2
    # no punho ao alto sobe na ponta dos pes (a bola do pe fica plantada)
    on_toes(R, 22.0 * air + 14.0 * air2 + 28.0 * fist, dxs=(0.040 * wide, -0.040 * wide), lift=(lift, lift))
    f = ha.face(alegre=smooth(t, 0.1, 0.35) * (1 - smooth(t, 1.3, 1.5)), atenta=0.5 * pre)
    f["fist_R"] = smooth(t, 0.62, 0.85) * (1 - smooth(t, 1.25, 1.45))
    f["fist_L"] = grab * 0.85          # mao esquerda fechada na corda
    return f


def pose_celebrate_pico(R, F, t, T):
    """celebrate do Pico atual, agora com os dois punhos fechados no alto do salto."""
    f = ha.pose_celebrate(R, F, t, T)
    fist = smooth(t, 0.12, 0.32) * (1 - smooth(t, 0.95, 1.2))
    f["fist_R"] = f["fist_L"] = fist
    return f


CLIPS = dict(ha.CLIPS)
CLIPS["team_pose"] = (1.5, False, pose_team_pico)
CLIPS["celebrate"] = (1.2, False, pose_celebrate_pico)
GEAR_KEYS = ("fist_R", "fist_L")
IDLE = (4.0, pose_idle_pico)
CLIP_SET = list(ha.CLIP_SETS["pico"])     # idle, walk, run, stop, jump, pull_rope, look_up, react_surprise, celebrate, wave, team_pose


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
        for i in range(n + 1):
            t = dur * i / n
            R.reset()
            fc = fn(R, F, t, dur)
            R.evaluate()
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
        act["loop"] = name in ha.LOOPING
        pairs = [(rig.animation_data, act), (sk.animation_data, keyact)]
        if gk is not None:
            pairs.append((gk.animation_data, gearact))
        for ad, a_ in pairs:
            ad.action = None
            tr = ad.nla_tracks.new()
            tr.name = name
            st = tr.strips.new(name, 0, a_)
            st.name = name
    return {}
