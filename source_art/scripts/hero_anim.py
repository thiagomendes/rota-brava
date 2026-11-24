"""Animacoes do Rastro do RB-R1 (crianca-heroi): FK + IK de 2 ossos, 30 fps, sem root motion. PROVISORIO.

Clipes: idle (olha em volta, mexe na bolsa do caderno; loop), walk (loop 1,0 s), run (corrida saltitante; loop 0,6 s), stop,
crouch, inspect_touch, look_to_leme, react_surprise, point, wave, celebrate, team_pose.
Frente = +Y (Blender), direita = +X. Pes por IK com pivo de calcanhar/bola (mesma tecnica do RB-04, alturas do novo rig).
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
from mathutils import Vector

import char_lib as cl
from char_anim import blink_curve, foot_ankle, lerp, put_foot, reach, smooth, stand_feet, torso
from char_lib import eul

FPS = 30
WALK_T, WALK_SF, WALK_STEP = 1.0, 0.58, 0.26        # ciclo (s), fracao de apoio, curso do pe no apoio (m)
RUN_T, RUN_SF, RUN_STEP = 0.6, 0.42, 0.24
# Alvo da ponta da mao direita no inspect_touch (referencial do ator, Blender: +X direita, +Y frente, +Z cima):
# centro da PawMark do boat_v2 visto do ponto Ep01Layout.PAW_INSPECT_STAND_LOCAL (ver dock_stage.gd / test_characters.gd).
TOUCH_TARGET = Vector((0.08, 0.44, 0.112))
FACE_KEYS = ("atenta", "surpresa", "alegre", "triste", "blink")


def leg_k(F):
    return F.hz / 0.32


def walk_speed(F):
    return WALK_STEP * leg_k(F) / (WALK_T * WALK_SF)


def run_speed(F):
    return RUN_STEP * leg_k(F) / (RUN_T * RUN_SF)


def face(**kw):
    f = {k: 0.0 for k in FACE_KEYS}
    f.update(kw)
    return f


def arms_down(R, F, bend=12.0, out=0.0, swing=(0.0, 0.0), fwd=0.0):
    for s, sx in (("R", 1), ("L", -1)):
        sw = swing[0] if s == "R" else swing[1]
        R.rel("upper_arm." + s, eul(x=sw + fwd, y=-out * sx))
        R.rel("forearm." + s, eul(x=bend + max(sw, 0.0) * 0.6))


# ----------------------------------------------------------------- locomocao
def gait(R, F, p0, step, sf, lift, phi_land=12.0, phi_push=-26.0):
    for s, off in (("R", 0.0), ("L", 0.5)):
        p = (p0 + off) % 1.0
        h0 = R.rest_head["heel." + s].y
        front = h0 + step / 2
        if p < sf:
            u = p / sf
            hy = front - step * u
            if u < 0.14:
                phi, pivot = phi_land * (1 - smooth(u, 0, 0.14)), "heel"
            elif u < 0.62:
                phi, pivot = 0.0, "heel"
            else:
                phi, pivot = phi_push * smooth(u, 0.62, 1.0), "ball"
            put_foot(R, s, hy, phi, pivot)
        else:
            w = (p - sf) / (1 - sf)
            a_end = foot_ankle(R, s, front - step, phi_push, "ball")
            a_start = foot_ankle(R, s, front, phi_land, "heel")
            a = a_end.lerp(a_start, smooth(w))
            a.z += lift * math.sin(math.pi * w) ** 1.2
            put_foot(R, s, 0, lerp(phi_push, phi_land, smooth(w, 0.1, 0.95)), "heel", ankle=a)


def pose_walk(R, F, t, T):
    p0 = (t / T) % 1.0
    ph = 2 * math.pi * p0
    R.hips_off = Vector((0.0, 0.0, -0.016 + 0.008 * math.cos(4 * math.pi * (p0 - 0.30))))
    R.rel("hips", eul(z=6.0 * math.sin(ph), y=3.0 * math.cos(ph)))
    torso(R, lean=4.0, yaw=-7.0 * math.sin(ph), head_yaw=4.0 * math.sin(ph), head_pitch=-1.0, head_roll=2.0 * math.cos(ph))
    sw = 28.0 * math.cos(ph)
    arms_down(R, F, bend=20, out=6, swing=(-sw, sw))
    gait(R, F, p0, WALK_STEP * leg_k(F), WALK_SF, 0.060 * leg_k(F) ** 0.5)
    return face(blink=blink_curve(t, 0.55))


def pose_run(R, F, t, T):
    p0 = (t / T) % 1.0
    ph = 2 * math.pi * p0
    # saltitante: o quadril sobe no meio de cada apoio e desce na aterrissagem (dois quiques por ciclo)
    R.hips_off = Vector((0.0, 0.0, -0.030 + 0.016 * math.cos(4 * math.pi * (p0 - 0.21))))
    R.rel("hips", eul(z=8.0 * math.sin(ph), y=3.0 * math.cos(ph)))
    torso(R, lean=12.0, yaw=-10.0 * math.sin(ph), head_yaw=3.0 * math.sin(ph), head_pitch=4.0, head_roll=2.5 * math.cos(ph))
    sw = 48.0 * math.cos(ph)
    arms_down(R, F, bend=62, out=10, swing=(-sw, sw))
    gait(R, F, p0, RUN_STEP * leg_k(F), RUN_SF, 0.085 * leg_k(F) ** 0.5, phi_land=10.0, phi_push=-34.0)
    return face(alegre=0.45, blink=0.0)


def pose_stop(R, F, t, T):
    # chega correndo/andando e assenta: inclinacao para tras, pequeno quique e volta ao idle
    u = smooth(t, 0.0, 0.18)
    settle = math.sin(math.pi * smooth(t, 0.10, 0.45)) * (1 - smooth(t, 0.35, 0.5))
    R.hips_off = Vector((0.0, 0.0, -0.030 * settle - 0.012 * (1 - u)))
    torso(R, lean=lerp(10.0, -6.0, u) * (1 - smooth(t, 0.25, 0.5)) + 3.0 * smooth(t, 0.25, 0.5),
          head_pitch=-4.0 * settle, head_roll=0.0)
    arms_down(R, F, bend=lerp(50, 14, smooth(t, 0.0, 0.4)), out=lerp(12, 8, u), fwd=-14.0 * settle)
    stand_feet(R)
    return face(surpresa=0.25 * settle, blink=blink_curve(t, 0.3, 0.15))


def pose_idle(R, F, t, T):
    """4,0 s: respira, olha para a esquerda e a direita e confere a bolsa do caderno (mao direita na aba)."""
    ph = 2 * math.pi * t / T
    breath = math.sin(2 * ph)
    look = smooth(t, 0.5, 0.9) * (1 - smooth(t, 1.3, 1.7)) - smooth(t, 1.6, 2.0) * (1 - smooth(t, 2.3, 2.6))
    bag = smooth(t, 2.6, 3.0) * (1 - smooth(t, 3.55, 3.95))
    R.hips_off = Vector((0.004 * math.sin(ph), 0.0, -0.010 + 0.003 * breath))
    torso(R, lean=2.5 + 0.6 * breath + 5.0 * bag, yaw=-4.0 * bag, roll=-3.0 * bag,
          head_pitch=1.5 * math.sin(ph + 1.2) - 16.0 * bag, head_yaw=28.0 * look - 18.0 * bag, head_roll=3.0 * look + 6.0 * bag)
    arms_down(R, F, bend=16 + 2 * breath, out=6 + breath)
    if bag > 0.001:
        R.evaluate()
        rest = R.tip("hand.R")
        tgt = Vector((F.v["belly"] + 0.05, 0.06, F.hz + 0.03))
        reach(R, "R", rest.lerp(tgt, bag), Vector((0.1, 0.25, -1.0)).lerp(Vector((-0.4, 0.6, -0.7)), bag), pole=(1.0, -0.6, 0.0))
    stand_feet(R)
    return face(atenta=0.6 * bag, blink=blink_curve(t, 1.2) + blink_curve(t, 3.2))


def crouch_pose(R, F, u, lean_max=34.0, hips_fwd=0.0):
    hz = F.hz
    R.hips_off = Vector((0.0, lerp(0.0, hips_fwd, u), -(hz * 0.40) * u))
    torso(R, lean=lerp(3.0, lean_max, u), head_pitch=-10.0 * u)
    arms_down(R, F, bend=lerp(14, 40, u), out=lerp(6, 12, u), fwd=-20 * u)
    for s in ("R", "L"):
        put_foot(R, s, R.rest_head["heel." + s].y, 0.0, "heel", pole=(0.0, 1.0, 0.0), dx=(0.02 if s == "R" else -0.02) * u)


def pose_crouch(R, F, t, T):
    u = smooth(t, 0.0, 0.6)
    crouch_pose(R, F, u)
    return face(atenta=0.8 * u, blink=blink_curve(t, 0.75))


def pose_inspect(R, F, t, T):
    """Agacha, inclina e encosta a ponta dos dedos na marca (TOUCH_TARGET) entre ~1,1 e 1,8 s; volta a pose agachada."""
    r = smooth(t, 0.35, 1.1) * (1 - smooth(t, 1.9, 2.65))
    crouch_pose(R, F, 1.0, lean_max=lerp(34.0, 62.0, r), hips_fwd=lerp(0.0, 0.10, r))
    torso(R, lean=lerp(34.0, 62.0, r), yaw=-10.0 * r, roll=8.0 * r, head_pitch=-10.0 - 6.0 * r, head_yaw=-4.0 * r)
    R.evaluate()
    rest = R.tip("hand.R")
    tip = rest.lerp(TOUCH_TARGET, r)
    hd = Vector((0.0, 0.5, -1.0)).lerp(Vector((-0.05, 0.75, -0.66)), r)
    reach(R, "R", tip, hd, pole=(1.0, -0.2, -0.3), roll=-60.0 * r)
    R.rel("upper_arm.L", eul(x=-30, y=10))
    R.rel("forearm.L", eul(x=40))
    return face(atenta=0.9, blink=blink_curve(t, 2.3))


def pose_look(R, F, t, T):
    a = smooth(t, 0.15, 0.7) * (1 - smooth(t, 1.9, 2.4))
    wave = smooth(t, 0.65, 0.9) * (1 - smooth(t, 1.6, 1.9))
    ph = 2 * math.pi * (t - 0.9) * 2.4
    R.hips_off = Vector((0, 0, -0.010))
    R.rel("hips", eul(z=-10 * a))
    torso(R, lean=3.0, yaw=-30.0 * a, head_pitch=-3 * a, head_yaw=-36.0 * a, head_roll=-4 * a)
    arms_down(R, F, bend=16, out=6)
    if wave > 0.001:
        R.evaluate()
        rest = R.tip("hand.R")
        tgt = Vector((F.sh.x + 0.27 + 0.04 * math.sin(ph), 0.06, F.sh.z + 0.19))
        reach(R, "R", rest.lerp(tgt, wave), Vector((0.1, 0.2, -1.0)).lerp(Vector((0.35 + 0.35 * math.sin(ph), 0.1, 1.0)), wave), pole=(1.0, -0.6, -0.4))
    stand_feet(R)
    return face(atenta=0.5 * a, alegre=0.9 * wave, blink=blink_curve(t, 1.1))


def pose_surprise(R, F, t, T):
    a = smooth(t, 0.0, 0.12) * (1 - smooth(t, 0.55, 0.9))
    hop = math.sin(math.pi * min(max((t - 0.04) / 0.30, 0.0), 1.0))
    R.hips_off = Vector((0, -0.03 * a, -0.010 + 0.025 * hop))
    torso(R, lean=lerp(3.0, -12.0, a), head_pitch=10.0 * a)
    arms_down(R, F, bend=lerp(14, 70, a), out=lerp(6, 40, a), fwd=-35 * a)
    for s in ("R", "L"):
        put_foot(R, s, R.rest_head["heel." + s].y, -20.0 * hop if hop > 0.05 else 0.0, "ball" if hop > 0.05 else "heel",
                 lift=0.025 * hop)
    return face(surpresa=smooth(t, 0.0, 0.1) * (1 - smooth(t, 0.65, 0.9)))


def pose_point(R, F, t, T):
    a = smooth(t, 0.1, 0.4) * (1 - smooth(t, 0.95, 1.2))
    R.hips_off = Vector((0, 0, -0.010))
    torso(R, lean=lerp(3.0, -2.0, a), yaw=-8 * a, head_pitch=6 * a, head_yaw=-6 * a)
    arms_down(R, F, bend=14, out=6)
    R.evaluate()
    rest = R.tip("hand.R")
    reach(R, "R", rest.lerp(Vector((F.sh.x + 0.04, 0.36, F.sh.z + 0.10)), a), Vector((0.1, 0.2, -1.0)).lerp(Vector((0.05, 1.0, 0.25)), a),
          pole=(1.0, -0.5, -0.6))
    stand_feet(R)
    return face(atenta=0.7 * a, blink=blink_curve(t, 1.05))


def pose_wave(R, F, t, T):
    a = smooth(t, 0.1, 0.35) * (1 - smooth(t, 1.3, 1.6))
    ph = 2 * math.pi * t * 2.5
    R.hips_off = Vector((0, 0, -0.010))
    torso(R, lean=2.0, roll=3 * a, head_roll=8 * a * math.sin(ph * 0.5), head_pitch=4 * a)
    arms_down(R, F, bend=14, out=6)
    R.evaluate()
    rest = R.tip("hand.R")
    tgt = Vector((F.sh.x + 0.27 + 0.04 * math.sin(ph), 0.06, F.sh.z + 0.19))
    reach(R, "R", rest.lerp(tgt, a), Vector((0.1, 0.2, -1.0)).lerp(Vector((0.4 * math.sin(ph), 0.15, 1.0)), a), pole=(1.0, -0.6, -0.4))
    stand_feet(R)
    return face(alegre=a, blink=0.0)


def pose_celebrate(R, F, t, T):
    """Pulinho de alegria: agacha, salta (~8 cm) com os dois punhos para cima, aterrissa e assenta."""
    pre = smooth(t, 0.0, 0.18) * (1 - smooth(t, 0.18, 0.28))
    air = math.sin(math.pi * min(max((t - 0.26) / 0.40, 0.0), 1.0))
    land = math.sin(math.pi * min(max((t - 0.66) / 0.30, 0.0), 1.0))
    arms = smooth(t, 0.12, 0.32) * (1 - smooth(t, 0.95, 1.2))
    R.hips_off = Vector((0, 0, -0.06 * pre - 0.05 * land + 0.08 * air))
    torso(R, lean=8 * pre + 6 * land - 6 * air, head_pitch=10 * air)
    arms_down(R, F, bend=14, out=6)
    R.evaluate()
    for s, sx in (("R", 1), ("L", -1)):
        rest = R.tip("hand." + s)
        tgt = Vector((sx * (F.sh.x + 0.22), 0.06, F.sh.z + 0.23 + 0.04 * air))
        reach(R, s, rest.lerp(tgt, arms), Vector((0.1 * sx, 0.2, -1.0)).lerp(Vector((0.2 * sx, 0.1, 1.0)), arms), pole=(sx * 1.0, -0.5, -0.4))
    for s in ("R", "L"):
        put_foot(R, s, R.rest_head["heel." + s].y, -25.0 * air if air > 0.02 else 0.0, "ball" if air > 0.02 else "heel",
                 lift=0.08 * air, pole=(0.0, 1.0, 0.0))
    return face(alegre=smooth(t, 0.1, 0.3) * (1 - smooth(t, 1.05, 1.2)))


def pose_team(R, F, t, T):
    """Pose de equipe (1,5 s): punho direito erguido, mao esquerda na cintura, cabeca inclinada, sorriso."""
    a = smooth(t, 0.0, 0.45) * (1 - smooth(t, 1.25, 1.5))
    bounce = math.sin(math.pi * smooth(t, 0.35, 0.65)) * 0.5
    R.hips_off = Vector((0, 0, -0.010 - 0.012 * bounce))
    torso(R, lean=lerp(3.0, -3.0, a), roll=-3 * a, head_pitch=6 * a, head_roll=7 * a, head_yaw=-8 * a)
    arms_down(R, F, bend=14, out=6)
    R.evaluate()
    rr, rl = R.tip("hand.R"), R.tip("hand.L")
    reach(R, "R", rr.lerp(Vector((F.sh.x + 0.25, 0.08, F.sh.z + 0.21)), a), Vector((0.1, 0.2, -1.0)).lerp(Vector((0.3, 0.1, 1.0)), a),
          pole=(1.0, -0.4, -0.4))
    reach(R, "L", rl.lerp(Vector((-F.v["belly"] - 0.03, 0.03, F.hz + 0.03)), a), Vector((-0.1, 0.2, -1.0)).lerp(Vector((0.6, 0.2, -0.5)), a),
          pole=(-1.0, -0.6, 0.0))
    stand_feet(R, dxs=(0.02 * a, -0.02 * a))
    return face(alegre=a)


# ----------------------------------------------------------------- clipes por personagem (RB-R1, segunda leva)
def pose_idle_simple(R, F, t, T):
    ph = 2 * math.pi * t / T
    breath = math.sin(ph)
    R.hips_off = Vector((0.004 * math.sin(ph), 0.0, -0.010 + 0.003 * breath))
    torso(R, lean=2.0 + 0.6 * breath, head_yaw=10.0 * math.sin(ph * 0.5), head_pitch=1.5 * math.sin(ph + 1.0), head_roll=2.0 * math.sin(ph + 2.0))
    arms_down(R, F, bend=16 + 2 * breath, out=6 + breath)
    stand_feet(R)
    return face(blink=blink_curve(t, 1.0) + blink_curve(t, T - 0.6))


def pose_idle_hop(R, F, t, T):
    """Pico: quica na ponta dos pes (3 quiques), alonga os bracos para cima e volta."""
    ph = 2 * math.pi * t / T
    hop = max(0.0, math.sin(3 * ph)) * (1 - smooth(t, 1.6, 1.9)) * smooth(t, 0.0, 0.2) + max(0.0, math.sin(3 * ph)) * smooth(t, 2.6, 2.9) * (1 - smooth(t, T - 0.2, T))
    stretch = smooth(t, 1.7, 2.1) * (1 - smooth(t, 2.4, 2.8))
    R.hips_off = Vector((0.0, 0.0, -0.010 + 0.030 * hop + 0.012 * stretch))
    torso(R, lean=2.0 - 4.0 * stretch, head_pitch=6.0 * stretch + 3.0 * hop, head_roll=3.0 * math.sin(ph))
    arms_down(R, F, bend=30 - 10 * hop, out=8 + 6 * hop)
    if stretch > 0.001:
        R.evaluate()
        for s, sx in (("R", 1), ("L", -1)):
            rest = R.tip("hand." + s)
            reach(R, s, rest.lerp(Vector((sx * (F.sh.x + 0.06), 0.02, F.sh.z + 0.32)), stretch),
                  Vector((0.1 * sx, 0.2, -1.0)).lerp(Vector((0.1 * sx, 0.0, 1.0)), stretch), pole=(sx * 1.0, -0.4, -0.3))
    for s in ("R", "L"):
        put_foot(R, s, R.rest_head["heel." + s].y, -24.0 * hop, "ball")
    return face(alegre=0.35 + 0.3 * hop, blink=blink_curve(t, 2.2))


def pose_idle_compass(R, F, t, T):
    """Leme: confere a bussola de pulso (antebraco esquerdo a frente), depois sorri olhando o mar."""
    ph = 2 * math.pi * t / T
    look = smooth(t, 0.4, 0.9) * (1 - smooth(t, 2.0, 2.5))
    sea = smooth(t, 2.6, 3.0) * (1 - smooth(t, 3.6, T))
    R.hips_off = Vector((0.004 * math.sin(ph), 0.0, -0.010 + 0.003 * math.sin(2 * ph)))
    torso(R, lean=2.0 + 3.0 * look, head_pitch=-22.0 * look + 4.0 * sea, head_yaw=10.0 * look - 16.0 * sea, head_roll=4.0 * sea)
    arms_down(R, F, bend=16, out=6)
    if look > 0.001:
        R.evaluate()
        rest = R.tip("hand.L")
        tgt = Vector((-0.02, F.v["belly"] + 0.16, F.sh.z - 0.06))
        reach(R, "L", rest.lerp(tgt, look), Vector((-0.1, 0.2, -1.0)).lerp(Vector((1.0, 0.3, 0.0)), look), pole=(-1.0, -0.3, -0.6))
    stand_feet(R)
    return face(alegre=0.8 * sea, atenta=0.5 * look, blink=blink_curve(t, 2.3))


def pose_jump(R, F, t, T):
    """Pico: salto de apoio em apoio sem root motion. Impulso 0-0,25 s, voo ~0,45 s (0,25-0,70), amortecimento ate 1,0 s."""
    pre = smooth(t, 0.0, 0.18) * (1 - smooth(t, 0.18, 0.27))
    fly = min(max((t - 0.25) / 0.45, 0.0), 1.0)
    air = math.sin(math.pi * fly) if 0.0 < fly < 1.0 else 0.0
    land = math.sin(math.pi * min(max((t - 0.70) / 0.30, 0.0), 1.0))
    R.hips_off = Vector((0.0, 0.0, -0.07 * pre - 0.06 * land + 0.22 * air))
    torso(R, lean=14 * pre + 10 * land + 6 * air, head_pitch=-6 * air)
    sw = 40 * air - 30 * pre
    arms_down(R, F, bend=30 + 30 * air, out=10 + 20 * air, swing=(-sw, -sw))
    tuck = 0.10 * air
    for s in ("R", "L"):
        put_foot(R, s, R.rest_head["heel." + s].y, -30.0 * air if air > 0.02 else 0.0, "ball" if air > 0.02 else "heel",
                 lift=0.16 * air + tuck * 0.0, pole=(0.0, 1.0, 0.0))
    return face(atenta=0.6 * pre, alegre=0.7 * air, blink=0.0)


def pose_pull(R, F, t, T):
    """Pico: dois puxoes firmes numa corda a frente (forca maxima em ~0,42 s e ~1,02 s)."""
    e = smooth(t, 0.0, 0.18) * (1 - smooth(t, 1.38, 1.6))
    p = smooth(t, 0.12, 0.42) * (1 - smooth(t, 0.48, 0.72)) + smooth(t, 0.72, 1.02) * (1 - smooth(t, 1.14, 1.34))
    p = max(0.0, min(1.0, p))
    R.hips_off = Vector((0, -0.03 * p, -0.03 - 0.03 * p))
    torso(R, lean=-8.0 * p + 4.0, head_pitch=-3 * p)
    arms_down(R, F, bend=16, out=6)
    R.evaluate()
    for s, sx in (("R", 1), ("L", -1)):
        rest = R.tip("hand." + s)
        high = Vector((sx * 0.05, 0.26, F.sh.z + 0.20))
        low = Vector((sx * 0.06, 0.16, F.hz + 0.08))
        tip = rest.lerp(high.lerp(low, p), e)
        hd = Vector((0, 0.25, -1.0)).lerp(Vector((0, 1.0, 0.45)).lerp(Vector((0, 1.0, -0.35)), p), e)
        reach(R, s, tip, hd, pole=(sx * 0.8, -0.4, -1.0), roll=-30.0 * e)
    for s in ("R", "L"):
        put_foot(R, s, R.rest_head["heel." + s].y, 0.0, "heel", dx=(0.03 if s == "R" else -0.03), pole=(0.0, 1.0, 0.0))
    return face(atenta=0.6 * e, blink=blink_curve(t, 1.45))


def pose_look_up(R, F, t, T):
    a = smooth(t, 0.1, 0.7) * (1 - smooth(t, 1.5, 1.95))
    R.hips_off = Vector((0, 0, -0.010))
    torso(R, lean=-5.0 * a + 2.0, head_pitch=34.0 * a, head_yaw=8.0 * math.sin(2 * math.pi * t * 0.8) * a)
    arms_down(R, F, bend=16, out=6)
    e = smooth(t, 0.45, 0.85) * (1 - smooth(t, 1.3, 1.6))
    if e > 0.001:
        R.evaluate()
        rest = R.tip("hand.R")
        reach(R, "R", rest.lerp(Vector((F.sh.x + 0.02, 0.14, F.sh.z + 0.18)), e), Vector((0.1, 0.2, -1.0)).lerp(Vector((-0.6, 0.4, 0.1)), e),
              pole=(1.0, -0.5, -0.3))
    stand_feet(R)
    return face(atenta=0.8 * a, blink=blink_curve(t, 1.7))


# Leme no volante. Alvo no referencial do ator (Blender): centro do WheelPoint visto de BoatActor.CREW[&"pilot"] olhando para a proa.
WHEEL_C = Vector((0.0, 0.47, 0.72))
WHEEL_R = 0.19
WHEEL_TILT = math.radians(32)


def wheel_point(a_deg):
    a = math.radians(a_deg)
    return WHEEL_C + Vector((WHEEL_R * math.cos(a), WHEEL_R * math.sin(a) * math.sin(WHEEL_TILT), WHEEL_R * math.sin(a) * math.cos(WHEEL_TILT)))


def pose_idle_wheel(R, F, t, T, ang=0.0, steer=0.0):
    ph = 2 * math.pi * t / T
    R.hips_off = Vector((0.0, 0.15, -0.035 + 0.003 * math.sin(ph)))
    R.rel("hips", eul(z=steer * 6.0, y=-steer * 4.0))
    torso(R, lean=24.0 + 1.0 * math.sin(ph), roll=-steer * 8.0, yaw=steer * 8.0, head_yaw=steer * 14.0 + 3 * math.sin(ph + 1), head_pitch=6.0)
    for s, base in (("R", 0.0), ("L", 180.0)):
        sx = 1 if s == "R" else -1
        tip = wheel_point(base + ang + 2.0 * math.sin(ph))
        reach(R, s, tip + Vector((0, 0.01, 0)), Vector((-0.25 * sx, 1.0, -0.15)), pole=(sx * 0.8, -0.3, -1.0), roll=-40.0)
    for s in ("R", "L"):
        put_foot(R, s, R.rest_head["heel." + s].y, 0.0, "heel", pole=(0.0, 1.0, 0.0), dx=(0.02 if s == "R" else -0.02))
    return face(alegre=0.3, blink=blink_curve(t, 1.6))


def pose_steer(R, F, t, T, sign):
    e = smooth(t, 0.0, 0.35) * (1 - smooth(t, 0.65, 1.0))
    f = pose_idle_wheel(R, F, 0.0, 2.4, ang=sign * 38.0 * e, steer=sign * e)
    f["atenta"] = 0.6 * e
    return f


def pose_horn(R, F, t, T):
    e = smooth(t, 0.0, 0.2) * (1 - smooth(t, 0.55, 0.9))
    pull = math.sin(math.pi * smooth(t, 0.25, 0.6))
    f = pose_idle_wheel(R, F, 0.0, 2.4)
    R.evaluate()
    rest = R.tip("hand.R")
    tgt = Vector((F.sh.x + 0.04, 0.30, F.sh.z + 0.30 - 0.08 * pull))
    reach(R, "R", rest.lerp(tgt, e), Vector((-0.25, 1.0, -0.15)).lerp(Vector((0.0, 0.1, 1.0)), e), pole=(0.8, -0.5, -0.8))
    f["alegre"] = 0.9 * e
    f["blink"] = 0.0
    return f


def pose_thanks(R, F, t, T):
    """Piloto: maos juntas no peito e uma pequena reverencia de agradecimento."""
    a = smooth(t, 0.1, 0.5) * (1 - smooth(t, 1.5, 1.9))
    bow = math.sin(math.pi * smooth(t, 0.5, 1.4))
    R.hips_off = Vector((0, -0.02 * bow, -0.010))
    torso(R, lean=2.0 + 22.0 * bow, head_pitch=-10.0 * bow)
    arms_down(R, F, bend=16, out=6)
    R.evaluate()
    for s, sx in (("R", 1), ("L", -1)):
        rest = R.tip("hand." + s)
        reach(R, s, rest.lerp(Vector((sx * 0.015, F.v["belly"] + 0.10, F.sh.z - 0.10)), a),
              Vector((0.1 * sx, 0.2, -1.0)).lerp(Vector((-0.2 * sx, 0.3, 1.0)), a), pole=(sx * 1.0, -0.3, -0.6))
    stand_feet(R)
    return face(alegre=a, blink=blink_curve(t, 1.7))


def pose_chat(R, F, t, T):
    """Morador conversando: gesticula com a mao direita, acena com a cabeca e inclina o corpo."""
    ph = 2 * math.pi * t / T
    g = smooth(t, 0.2, 0.6) * (1 - smooth(t, T - 0.5, T - 0.1))
    R.hips_off = Vector((0, 0, -0.010))
    torso(R, lean=3.0, yaw=6.0 * math.sin(ph), head_pitch=5.0 * math.sin(3 * ph), head_yaw=-8.0 * math.sin(ph))
    arms_down(R, F, bend=18, out=6)
    R.evaluate()
    rest = R.tip("hand.R")
    tgt = Vector((F.sh.x + 0.05 + 0.04 * math.sin(2 * ph), F.v["belly"] + 0.15, F.sh.z - 0.10 + 0.05 * math.sin(3 * ph)))
    reach(R, "R", rest.lerp(tgt, g), Vector((0.1, 0.2, -1.0)).lerp(Vector((0.2, 1.0, 0.4)), g), pole=(1.0, -0.4, -0.6))
    stand_feet(R)
    return face(alegre=0.4 + 0.3 * math.sin(2 * ph) * g, blink=blink_curve(t, 0.9) + blink_curve(t, 2.4))
CLIPS = {
    "idle": (4.0, True, pose_idle),
    "walk": (WALK_T, True, pose_walk),
    "run": (RUN_T, True, pose_run),
    "stop": (0.5, False, pose_stop),
    "crouch": (1.0, False, pose_crouch),
    "inspect_touch": (3.0, False, pose_inspect),
    "look_to_leme": (2.4, False, pose_look),
    "react_surprise": (0.9, False, pose_surprise),
    "point": (1.2, False, pose_point),
    "wave": (1.6, False, pose_wave),
    "celebrate": (1.2, False, pose_celebrate),
    "team_pose": (1.5, False, pose_team),
    "jump": (1.0, False, pose_jump),
    "pull_rope": (1.6, False, pose_pull),
    "look_up": (2.0, False, pose_look_up),
    "idle_wheel": (2.4, True, pose_idle_wheel),
    "steer_left": (1.0, False, lambda R, F, t, T: pose_steer(R, F, t, T, +1)),
    "steer_right": (1.0, False, lambda R, F, t, T: pose_steer(R, F, t, T, -1)),
    "react_horn": (0.9, False, pose_horn),
    "thanks": (2.0, False, pose_thanks),
    "chat": (3.0, True, pose_chat),
}
IDLES = {"rastro": (4.0, pose_idle), "pico": (3.6, pose_idle_hop), "leme": (4.2, pose_idle_compass)}
CLIP_SETS = {
    "rastro": ["idle", "walk", "run", "stop", "crouch", "inspect_touch", "look_to_leme", "react_surprise", "point", "wave", "celebrate", "team_pose"],
    "pico": ["idle", "walk", "run", "stop", "jump", "pull_rope", "look_up", "react_surprise", "celebrate", "wave", "team_pose"],
    "leme": ["idle", "walk", "run", "stop", "idle_wheel", "steer_left", "steer_right", "react_horn", "celebrate", "wave", "point", "team_pose"],
    "captain": ["idle", "walk", "wave", "thanks"],
    "villager_a": ["idle", "walk", "wave", "chat"],
    "villager_b": ["idle", "walk", "wave", "chat"],
    "villager_c": ["idle", "walk", "wave", "chat"],
}
LOOPING = ("idle", "walk", "run", "idle_wheel", "chat")


def author(rig, face_ob, F, names=None, cid="rastro"):
    R = cl.Rigger(rig)
    sk = face_ob.data.shape_keys
    sk.animation_data_create()
    rig.animation_data_create()
    prev = {}
    report = {}
    for name in (names or CLIP_SETS.get(cid, CLIP_SETS["rastro"])):
        dur, loop, fn = CLIPS[name]
        if name == "idle":
            dur, fn = IDLES.get(cid, (3.0, pose_idle_simple))
        act = bpy.data.actions.new(name)
        act.use_fake_user = True
        keyact = bpy.data.actions.new(name + "_key")
        keyact.use_fake_user = True
        rig.animation_data.action = act
        sk.animation_data.action = keyact
        n = int(round(dur * FPS))
        prev.clear()
        best = 9.0
        for i in range(n + 1):
            t = dur * i / n
            R.reset()
            fc = fn(R, F, t, dur)
            R.evaluate()
            if name == "inspect_touch":
                best = min(best, (R.tip("hand.R") - TOUCH_TARGET).length)
            if name == "idle_wheel":
                best = min(best, ((R.tip("hand.R") + R.tip("hand.L")) * 0.5 - WHEEL_C).length)
            R.apply(i, prev)
            for kn in FACE_KEYS:
                kb = sk.key_blocks[kn]
                kb.value = max(0.0, min(1.0, fc.get(kn, 0.0)))
                kb.keyframe_insert("value", frame=i)
        if name == "inspect_touch":
            report["inspect_tip_err_m"] = round(best, 4)
        if name == "idle_wheel":
            report["wheel_mid_err_m"] = round(best, 4)
        act["loop"] = loop
        for ad, a_ in ((rig.animation_data, act), (sk.animation_data, keyact)):
            ad.action = None
            tr = ad.nla_tracks.new()
            tr.name = name
            st = tr.strips.new(name, 0, a_)
            st.name = name
    return report

