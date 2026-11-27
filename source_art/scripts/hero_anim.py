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



# ======================================================================= RB-R1 G19: pegar, levar, pousar, examinar, escalar, corda
# Clipes compartilhados pelos herois v2 (Rastro, Pico, Leme). Cada modulo de heroi (rv2/pv2/lv2_anim.py) chama
# g19_clips(WALK, ...) com o proprio WALK (hero_gait_v2) e junta o resultado ao seu CLIPS; author() chama
# add_hold_points(rig) antes de montar o Rigger. FK + IK, 30 fps, sem root motion: nos clipes de escalada o corpo
# inteiro (quadril, maos e pes) se desloca dentro do clipe e o codigo move o ator no fim pelo deslocamento medido
# (info.json -> "g19" -> <clipe> -> "deslocamento_final_m", referencial Blender do ator: +Y frente, +Z cima). PROVISORIO.
#
# Pontos de encaixe: HoldPoint (filho de hand.R) e HoldPoint_L (filho de hand.L), ossos sem deformacao no centro da palma
# (PALM_AT do osso hand, do pulso para a ponta dos dedos), com os eixos do osso da mao.
# Objeto de uma mao: BoneAttachment3D no HoldPoint (ou HoldPoint_L). Objeto de duas maos (caixa, roupa dobrada): ponto
# medio dos dois HoldPoints (os clipes de carregar mantem as palmas simetricas).
#
# Reuso por outro heroi: g19_clips(WALK, climber=True) devolve tambem climb_up*, climb_wall, climb_top, climb_down,
# throw_rope e lower_rope; as medidas vem do rig de cada heroi (ombro, braco, perna, barriga), nada e fixo do Pico.
HOLD_BONES = (("HoldPoint", "R"), ("HoldPoint_L", "L"))
PALM_AT = 0.45


def add_hold_points(rig):
    """Cria HoldPoint/HoldPoint_L (sem deformacao, filhos de hand.R/hand.L, eixos do proprio osso da mao)."""
    vl = bpy.context.view_layer
    if bpy.context.object is not None and bpy.context.object.mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")
    vl.objects.active = rig
    rig.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    eb = rig.data.edit_bones
    for name, s in HOLD_BONES:
        if name in eb:
            continue
        h = eb["hand." + s]
        d = h.tail - h.head
        b = eb.new(name)
        b.head = h.head + d * PALM_AT
        b.tail = b.head + d.normalized() * 0.03
        b.align_roll(h.z_axis)
        b.parent = h
        b.use_connect = False
        b.use_deform = False
    bpy.ops.object.mode_set(mode="OBJECT")


def palm(R, s):
    p = R.pos["hand." + s]
    return p + (R.tip("hand." + s) - p) * PALM_AT


def _rest_arms(R, F, bend=16.0, out=6.0):
    """Bracos soltos do idle; devolve (pontas, direcoes) de repouso das duas maos."""
    arms_down(R, F, bend=bend, out=out)
    R.evaluate()
    tips = {s: R.tip("hand." + s) for s in "RL"}
    dirs = {s: (R.tip("hand." + s) - R.pos["hand." + s]).normalized() for s in "RL"}
    return tips, dirs


def _blend_arm(R, s, rest_tip, rest_dir, palm_at, hand_dir, w, pole, roll=0.0):
    """Mistura repouso -> alvo da palma (peso w) e resolve o IK pela ponta da mao."""
    if w <= 1e-4:
        return
    hd_t = Vector(hand_dir).normalized()
    hd = rest_dir.lerp(hd_t, w).normalized()
    tip_t = Vector(palm_at) + hd_t * (1.0 - PALM_AT) * R.length("hand." + s)
    reach(R, s, rest_tip.lerp(tip_t, w), hd, pole, roll * w)


# ----------------------------------------------------------------- geometria do carregar (por heroi, a partir do rig)
CARRY_XH = 0.10        # meia distancia entre os centros das palmas (m)
CARRY_FWD = 0.10       # palma a frente da barriga (m)
CARRY_DROP = 0.08      # palma abaixo do ombro (m): a frente do peito
CARRY_DIR = (-0.30, 0.88, -0.36)      # dedos para a frente e para dentro (x espelha por lado)
CARRY_FIST = 0.35      # dedos meio fechados segurando
CARRY_POLE = {"R": (1.0, -0.6, -0.5), "L": (-1.0, -0.6, -0.5)}


def carry_palms(F, dz=0.0, dy=0.0):
    y = F.v["belly"] + CARRY_FWD + dy
    z = F.sh.z - CARRY_DROP + dz
    return {"R": Vector((CARRY_XH, y, z)), "L": Vector((-CARRY_XH, y, z))}


def carry_dir(s, d=CARRY_DIR):
    sx = 1 if s == "R" else -1
    return Vector((d[0] * sx, d[1], d[2]))


def carry_arms(R, F, dz=0.0, dy=0.0, w=1.0):
    tips, dirs = _rest_arms(R, F)
    P = carry_palms(F, dz, dy)
    for s in "RL":
        _blend_arm(R, s, tips[s], dirs[s], P[s], carry_dir(s), w, CARRY_POLE[s])


def _fist(f, v):
    f["fist_R"] = f["fist_L"] = v
    return f


def pose_carry_idle(R, F, t, T):
    """carry_idle (laco 2,4 s): segura o objeto a frente do peito com as duas maos; respira (o objeto sobe e desce junto),
    olha de leve para os lados; uma piscada."""
    ph = 2 * math.pi * t / T
    breath = math.sin(ph)
    R.hips_off = Vector((0.003 * math.sin(ph), 0.0, -0.010 + 0.003 * breath))
    torso(R, lean=-1.0 + 0.5 * breath, head_pitch=-4.0 + 1.5 * math.sin(ph + 1.0), head_yaw=8.0 * math.sin(ph),
          head_roll=1.5 * math.sin(ph + 2.0))
    carry_arms(R, F, dz=0.003 * breath)
    stand_feet(R)
    return _fist(face(atenta=0.2, blink=blink_curve(t, 1.3)), CARRY_FIST)


def carry_walk_cfg(walk):
    """Mesmo passo do walk (pes, curso, ciclo e quadril iguais): so o tronco fica mais firme e os bracos seguram."""
    g = dict(walk)
    g["torso_yaw"] = walk["torso_yaw"] * 0.35
    g["head_yaw"] = walk["head_yaw"] * 0.4
    g["lean"] = walk["lean"] - 3.0
    g["head_pitch"] = walk["head_pitch"] - 3.0
    g["face"] = {"atenta": 0.2}
    return g


def carry_walk_fn(walk):
    import hero_gait_v2 as hg
    g = carry_walk_cfg(walk)

    def fn(R, F, t, T):
        f = hg.pose(R, F, t, g)
        carry_arms(R, F, dz=R.hips_off.z - g["base"])        # o objeto acompanha o sobe-e-desce do corpo
        f["blink"] = blink_curve(t, 0.55)
        return _fist(f, CARRY_FIST)
    return fn, g


# ----------------------------------------------------------------- pick_up (0,6 s)
PICK_T = 0.6
PICK_GRAB_T = 0.27     # as palmas chegam ao objeto (o codigo prende o objeto aqui)
PICK_PALM_Y = 0.05     # alem da ponta do pe (m)
PICK_PALM_Z = 0.09     # centro da pega no chao (caixa de ~0,16-0,18 m de altura, pega no meio)
PICK_XH = 0.11


def pose_pick_up(R, F, t, T):
    """Abaixa (agacha e inclina), pega com as duas maos um objeto no chao a frente dos pes e sobe com ele ate a frente do
    peito. Termina igual ao quadro 0 do carry_idle."""
    down = smooth(t, 0.0, PICK_GRAB_T) * (1 - smooth(t, 0.31, 0.58))
    r = smooth(t, 0.03, PICK_GRAB_T)
    c = smooth(t, 0.31, 0.58)
    R.hips_off = Vector((0.0, -0.06 * down, -0.010 - F.hz * 0.56 * down))
    torso(R, lean=lerp(2.0, 74.0, down) - 3.0 * c * (1 - down), head_pitch=-12.0 * down - 4.0 * c, head_yaw=0.0)
    tips, dirs = _rest_arms(R, F, bend=lerp(16, 30, down))
    toe_y = R.rest_head["toe_tip.R"].y
    P = carry_palms(F)
    for s, sx in (("R", 1), ("L", -1)):
        floor = Vector((sx * PICK_XH, toe_y + PICK_PALM_Y, PICK_PALM_Z))
        fd = Vector((-0.25 * sx, 0.45, -0.86))
        _blend_arm(R, s, tips[s], dirs[s], floor.lerp(P[s], c), fd.lerp(carry_dir(s), c), max(r, c), CARRY_POLE[s])
    for s in ("R", "L"):
        put_foot(R, s, R.rest_head["heel." + s].y, 0.0, "heel", pole=(0.0, 1.0, 0.0))
    f = face(atenta=0.6 * down + 0.2 * c, blink=blink_curve(t, 0.40, 0.15))
    return _fist(f, CARRY_FIST * smooth(t, 0.20, PICK_GRAB_T + 0.02))


# ----------------------------------------------------------------- place_high (0,9 s) e place_low (0,8 s)
PLACE_HIGH_T, PLACE_HIGH_REL = 0.9, 0.45
PLACE_LOW_T, PLACE_LOW_REL = 0.8, 0.38


def _tiptoe(R, deg):
    for s in ("R", "L"):
        put_foot(R, s, R.rest_head["heel." + s].y, -deg, "ball" if deg > 0.3 else "heel",
                 pole=((0.05 if s == "R" else -0.05), 1.0, 0.0))


def pose_place_high(R, F, t, T):
    """Ergue o objeto o mais alto que os bracos alcancam (na ponta dos pes, um pouco a frente da testa), segura, solta
    (dedos abrem em PLACE_HIGH_REL) e volta ao repouso de maos vazias."""
    up = smooth(t, 0.0, 0.36) * (1 - smooth(t, 0.52, 0.86))
    rise = smooth(t, 0.0, 0.36)
    carry = 1 - smooth(t, 0.50, 0.86)
    R.hips_off = Vector((0.0, -0.01 * up, -0.010 + 0.012 * up))
    torso(R, lean=lerp(-1.0, -7.0, up), head_pitch=lerp(-4.0, 24.0, up))
    tips, dirs = _rest_arms(R, F)
    P = carry_palms(F)
    top_z = F.sh.z + 0.92 * (R.length("upper_arm.R") + R.length("forearm.R") + PALM_AT * R.length("hand.R")) + 0.05
    for s, sx in (("R", 1), ("L", -1)):
        hi = Vector((sx * 0.085, F.v["belly"] + 0.07, top_z))
        d = carry_dir(s).lerp(Vector((-0.20 * sx, 0.40, 0.90)), rise)
        _blend_arm(R, s, tips[s], dirs[s], P[s].lerp(hi, rise), d, carry, (sx * 1.0, -0.4, -0.3))
    _tiptoe(R, 20.0 * up)
    f = face(atenta=0.6 * up, alegre=0.9 * smooth(t, 0.40, 0.50) * (1 - smooth(t, 0.60, 0.72)), blink=blink_curve(t, 0.78, 0.12))
    return _fist(f, CARRY_FIST * (1 - smooth(t, PLACE_HIGH_REL - 0.03, PLACE_HIGH_REL + 0.07)))


def pose_place_low(R, F, t, T):
    """Estende o objeto para a frente e para cima ate o alto de uma bancada (ponta dos pes, tronco inclinado), solta em
    PLACE_LOW_REL e volta ao repouso."""
    a = smooth(t, 0.0, 0.32) * (1 - smooth(t, 0.46, 0.76))
    u = smooth(t, 0.0, 0.32)
    carry = 1 - smooth(t, 0.44, 0.76)
    R.hips_off = Vector((0.0, 0.015 * a, -0.010 + 0.008 * a))
    torso(R, lean=lerp(-1.0, 10.0, a), head_pitch=lerp(-4.0, -6.0, a))
    tips, dirs = _rest_arms(R, F)
    P = carry_palms(F)
    for s, sx in (("R", 1), ("L", -1)):
        out = Vector((sx * CARRY_XH, F.v["belly"] + 0.15, F.sh.z + 0.13))
        d = carry_dir(s).lerp(Vector((-0.25 * sx, 0.95, 0.10)), u)
        _blend_arm(R, s, tips[s], dirs[s], P[s].lerp(out, u), d, carry, CARRY_POLE[s])
    _tiptoe(R, 14.0 * a)
    f = face(atenta=0.5 * a, blink=blink_curve(t, 0.60, 0.12))
    return _fist(f, CARRY_FIST * (1 - smooth(t, PLACE_LOW_REL - 0.03, PLACE_LOW_REL + 0.07)))


# ----------------------------------------------------------------- inspect (1,4 s): nome unico para os tres herois
INSPECT_T = 1.4


def pose_inspect_generic(R, F, t, T):
    """Agacha, inclina, encosta a ponta dos dedos da mao direita no chao a frente e olha de perto; levanta."""
    u = smooth(t, 0.0, 0.40) * (1 - smooth(t, 1.0, 1.36))
    r = smooth(t, 0.26, 0.58) * (1 - smooth(t, 0.86, 1.10))
    R.hips_off = Vector((0.0, -0.05 * u, -0.010 - F.hz * 0.52 * u))
    torso(R, lean=lerp(2.0, 62.0, u) + 10.0 * r, yaw=-6.0 * r, head_pitch=-6.0 * u - 6.0 * r, head_yaw=-4.0 * r)
    arms_down(R, F, bend=lerp(16, 40, u), out=lerp(6, 14, u), fwd=-30 * u)
    for s in ("R", "L"):
        put_foot(R, s, R.rest_head["heel." + s].y, 0.0, "heel", pole=(0.0, 1.0, 0.0))
    R.evaluate()
    rest = R.tip("hand.R")
    toe_y = R.rest_head["toe_tip.R"].y
    tgt = Vector((0.07, toe_y + 0.05, 0.012))
    if r > 1e-4:
        drest = (R.tip("hand.R") - R.pos["hand.R"]).normalized()
        reach(R, "R", rest.lerp(tgt, r), drest.lerp(Vector((-0.05, 0.55, -0.83)).normalized(), r),
              pole=(1.0, -0.2, -0.3), roll=-50.0 * r)
    return face(atenta=0.85 * u, blink=blink_curve(t, 0.95, 0.14))


# ----------------------------------------------------------------- push_cart (laco, passo do walk)
CART_XH = 0.14


def push_cart_arms(R, F, bob):
    tips, dirs = _rest_arms(R, F)
    for s, sx in (("R", 1), ("L", -1)):
        at = Vector((sx * CART_XH, F.v["belly"] + 0.15, F.hz + 0.17 + bob))
        _blend_arm(R, s, tips[s], dirs[s], at, Vector((-0.05 * sx, 1.0, -0.15)), 1.0, (sx * 1.0, -0.7, -0.4))


def push_cart_fn(walk):
    import hero_gait_v2 as hg
    g = carry_walk_cfg(walk)
    g["lean"] = walk["lean"] + 7.0

    def fn(R, F, t, T):
        f = hg.pose(R, F, t, g)
        push_cart_arms(R, F, R.hips_off.z - g["base"])
        f["blink"] = blink_curve(t, 0.55)
        return _fist(f, 0.6)
    return fn, g


# ----------------------------------------------------------------- interpolacao por chaves (escalada)
def _pchip(ts, ys, t):
    """Cubica monotona (Fritsch-Carlson): sem ultrapassar as chaves (o pe nao atravessa o degrau entre duas chaves)."""
    n = len(ts)
    if t <= ts[0]:
        return ys[0]
    if t >= ts[-1]:
        return ys[-1]
    i = max(k for k in range(n - 1) if ts[k] <= t)
    h = [ts[k + 1] - ts[k] for k in range(n - 1)]
    d = [(ys[k + 1] - ys[k]) / h[k] for k in range(n - 1)]
    m = [0.0] * n
    for k in range(1, n - 1):
        if d[k - 1] * d[k] > 0:
            w1, w2 = 2 * h[k] + h[k - 1], h[k] + 2 * h[k - 1]
            m[k] = (w1 + w2) / (w1 / d[k - 1] + w2 / d[k])
    u = (t - ts[i]) / h[i]
    h00, h10, h01, h11 = 2 * u ** 3 - 3 * u ** 2 + 1, u ** 3 - 2 * u ** 2 + u, -2 * u ** 3 + 3 * u ** 2, u ** 3 - u ** 2
    return h00 * ys[i] + h10 * h[i] * m[i] + h01 * ys[i + 1] + h11 * h[i] * m[i + 1]


class Keys:
    """Instantaneos de pose: cada chave herda a anterior e muda so o que for dado. Canais: P (quadril, absoluto), lean,
    yaw, roll, hp/hy (cabeca), hR/hL (centro da palma), dR/dL (direcao da mao), wR/wL (peso do IK), fR/fL (tornozelo),
    pR/pL (angulo do pe), knee (joelho para fora), fist, effort (careta curta de olho aberto), atenta."""

    def __init__(self, base):
        self.snaps = [dict(base)]

    def at(self, t, **ch):
        s = dict(self.snaps[-1])
        s.update(ch)
        s["t"] = t
        self.snaps.append(s)
        return self

    def value(self, k, t):
        ts = [s["t"] for s in self.snaps]
        vs = [s[k] for s in self.snaps]
        if isinstance(vs[0], Vector):
            return Vector([_pchip(ts, [v[i] for v in vs], t) for i in range(3)])
        return _pchip(ts, vs, t)


def keyed_pose(R, F, K, t, off=None):
    """Aplica os canais de K no tempo t; `off` desloca tudo (quadril, maos e pes) no referencial do ator."""
    off = off if off is not None else Vector((0, 0, 0))
    v = lambda k: K.value(k, t)
    R.hips_off = v("P") + off - R.rest_head["hips"]
    torso(R, lean=v("lean"), yaw=v("yaw"), roll=v("roll"), head_pitch=v("hp"), head_yaw=v("hy"))
    tips, dirs = _rest_arms(R, F)
    for s, sx in (("R", 1), ("L", -1)):
        _blend_arm(R, s, tips[s], dirs[s], v("h" + s) + off, v("d" + s), max(0.0, min(1.0, v("w" + s))),
                   (sx * 0.9, -0.5, -0.6))
    for s, sx in (("R", 1), ("L", -1)):
        put_foot(R, s, 0.0, v("p" + s), "heel", ankle=v("f" + s) + off, pole=(sx * v("knee"), 1.0, 0.0))
    eff = max(0.0, min(1.0, v("effort")))
    f = face(atenta=max(0.0, min(1.0, v("atenta"))))
    f["brava_leve"] = 0.55 * eff
    f["mouth_E"] = 0.6 * eff
    f["blink"] = sum(blink_curve(t, b, 0.14) for b in K.snaps[0].get("blinks", ()))
    return _fist(f, max(0.0, min(1.0, v("fist"))))


def _ankle_for_toe(R, s, toe, phi):
    """Tornozelo que poe a PONTA DO PE (toe_tip) em `toe` com o pe girado `phi` graus (como put_foot gira)."""
    a0, b0, c0 = R.rest_head["foot." + s], R.rest_head["toe." + s], R.rest_head["toe_tip." + s]
    rx = lambda v, a: Vector((v.x, v.y * math.cos(a) - v.z * math.sin(a), v.y * math.sin(a) + v.z * math.cos(a)))
    ball = rx(b0 - a0, math.radians(phi))
    tipv = rx(c0 - b0, math.radians(max(phi, 0.0)))
    return Vector(toe) - ball - tipv


def _stand_ankle(R, s, off=(0.0, 0.0, 0.0)):
    return foot_ankle(R, s, R.rest_head["heel." + s].y, 0.0, "heel") + Vector(off)


# ----------------------------------------------------------------- escalada (Pico; reutilizavel pelos outros herois)
CLIMB_FIST = 0.55


def _mantle(K, R, F, k, D, H, Yend, t0, pull_dt):
    """Fim comum de climb_up e climb_top: puxa (peito ate a borda), apoia os bracos estendidos com o quadril acima da
    borda, poe o pe direito em cima (ja no lugar final), passa o esquerdo por cima e fica de pe."""
    hz = R.rest_head["hips"].z
    belly = F.v["belly"]
    press_d = lambda sx: Vector((-0.10 * sx, 0.93, -0.36))
    top = {s: _stand_ankle(R, s, (0.0, Yend, H)) for s in "RL"}
    yg = min(0.0, D - belly - 0.03)
    t = t0
    t += pull_dt
    K.at(t * k, P=Vector((0, yg, max(H - 0.22, K.snaps[-1]["P"].z + 0.02))), lean=24.0, hp=6.0,
         fR=_ankle_for_toe(R, "R", Vector((0.098, D - 0.015, max(0.03, H - 0.42))), -12.0), pR=-12.0,
         fL=_ankle_for_toe(R, "L", Vector((-0.098, D - 0.02, max(0.02, H - 0.55))), -38.0), pL=-38.0,
         knee=0.6, effort=1.0, atenta=0.4)
    t += 0.16
    K.at(t * k, P=Vector((0, D - 0.03, H + 0.09)), lean=46.0, hp=-6.0, dR=press_d(1), dL=press_d(-1),
         fR=_ankle_for_toe(R, "R", Vector((0.098, D - 0.006, H - 0.06)), -20.0), pR=-20.0,
         fL=_ankle_for_toe(R, "L", Vector((-0.098, D - 0.02, H - 0.30)), -40.0), pL=-40.0, effort=1.0)
    # pe direito sobe rente a face ate passar da quina e so depois avanca para cima do degrau
    t += 0.05
    K.at(t * k, P=Vector((0, D - 0.01, H + 0.11)), fR=_ankle_for_toe(R, "R", Vector((0.098, D - 0.02, H + 0.035)), -10.0),
         pR=-10.0)
    t += 0.06
    K.at(t * k, P=Vector((0, D + 0.0, H + 0.12)), fR=_ankle_for_toe(R, "R", Vector((0.098, D + 0.14, H + 0.04)), -5.0), pR=-5.0)
    t += 0.08
    K.at(t * k, P=Vector((0, D + 0.02, H + 0.13)), lean=36.0, hp=-2.0, fR=top["R"], pR=0.0,
         fL=_ankle_for_toe(R, "L", Vector((-0.098, D - 0.012, H - 0.16)), -30.0), pL=-30.0, effort=0.6)
    # pe esquerdo: o mesmo caminho (sobe rente, passa a quina, pisa)
    t += 0.05
    K.at(t * k, P=Vector((0, D + 0.06, H + hz - 0.12)), lean=26.0, wR=0.8, wL=0.8,
         fL=_ankle_for_toe(R, "L", Vector((-0.098, D - 0.02, H + 0.035)), -10.0), pL=-10.0, effort=0.3)
    t += 0.06
    K.at(t * k, P=Vector((0, (D + Yend) / 2 + 0.02, H + hz - 0.08)), lean=18.0, wR=0.5, wL=0.5,
         fL=_ankle_for_toe(R, "L", Vector((-0.098, D + 0.14, H + 0.04)), -5.0), pL=-5.0, effort=0.1, fist=0.3)
    t += 0.09
    K.at(t * k, P=Vector((0, Yend, H + hz - 0.04)), lean=8.0, hp=2.0, wR=0.0, wL=0.0, fL=top["L"], pL=0.0, knee=0.15,
         effort=0.0, fist=0.0, atenta=0.2)
    t += 0.08
    K.at(t * k, P=Vector((0, Yend, H + hz - 0.010)), lean=2.0, hp=0.0, atenta=0.0)
    return t


def climb_up_keys(R, F, H, T=1.2):
    """Chaves do climb_up numa borda de altura H (m) cuja face fica 3 cm alem da ponta do pe. Fim: de pe em cima em
    (0, Yend, H) no referencial do ator (Blender; na Godot = (0, H, -Yend))."""
    hz = R.rest_head["hips"].z
    shz = F.sh.z - hz
    D = R.rest_head["toe_tip.R"].y + 0.03
    Yend = D + 0.10
    arm = R.length("upper_arm.R") + R.length("forearm.R") + PALM_AT * R.length("hand.R")
    edge = lambda sx: Vector((sx * 0.105, D + 0.035, H + 0.026))      # palma em cima, logo depois da quina
    grip_d = lambda sx: Vector((-0.10 * sx, 0.96, -0.22))               # dedos deitados sobre o topo
    pre = lambda sx: Vector((sx * 0.105, D - 0.08, H - 0.04))           # sobe por fora da face antes de passar a quina
    yg = min(0.0, D - F.v["belly"] - 0.025)       # barriga a 2,5 cm da face quando agarra
    dy = (D + 0.035) - (yg + 0.02)                # palma na borda, a frente do ombro
    zg = max(H + 0.026 - math.sqrt(max((0.93 * arm) ** 2 - dy * dy, 0.0)) - shz, hz - 0.08)
    lift = max(0.0, zg - (hz - 0.010))
    stand = {s: _stand_ankle(R, s) for s in "RL"}
    k = T / 1.2
    K = Keys(dict(t=0.0, P=Vector((0, 0, hz - 0.010)), lean=2.0, yaw=0.0, roll=0.0, hp=0.0, hy=0.0,
                  hR=edge(1), hL=edge(-1), dR=grip_d(1), dL=grip_d(-1), wR=0.0, wL=0.0,
                  fR=stand["R"], fL=stand["L"], pR=0.0, pL=0.0, knee=0.15, fist=0.0, effort=0.0, atenta=0.3,
                  blinks=(0.10 * k, 0.95 * k)))
    if lift > 0.0:     # impulso: agacha, salta e agarra; pes soltos com a ponta encostando na face
        K.at(0.16 * k, P=Vector((0, -0.02, hz - 0.075)), lean=14.0, hp=18.0, wR=1.0, wL=1.0, hR=pre(1), hL=pre(-1),
             dR=Vector((-0.1, 0.3, 1.0)), dL=Vector((0.1, 0.3, 1.0)), atenta=0.7)
        # no ar: as maos sobem por fora da face (pre) e so passam a quina quando o corpo ja subiu
        K.at(0.28 * k, P=Vector((0, -0.02, hz - 0.075)).lerp(Vector((0, yg, zg)), 0.8), lean=8.0, hp=22.0)
        over = lambda sx: Vector((sx * 0.105, D - 0.03, H + 0.05))         # acima do topo, ainda do lado de fora
        K.at(0.31 * k, P=Vector((0, -0.02, hz - 0.075)).lerp(Vector((0, yg, zg)), 0.95), hR=over(1), hL=over(-1),
             dR=Vector((-0.1, 0.7, 0.3)), dL=Vector((0.1, 0.7, 0.3)))
        K.at(0.34 * k, P=Vector((0, yg, zg)), lean=6.0, hp=22.0, wR=1.0, wL=1.0, hR=edge(1), hL=edge(-1), dR=grip_d(1), dL=grip_d(-1),
             fR=_ankle_for_toe(R, "R", Vector((0.098, D - 0.02, max(0.02, lift * 0.6))), -25.0), pR=-25.0,
             fL=_ankle_for_toe(R, "L", Vector((-0.098, D - 0.03, max(0.02, lift * 0.35))), -40.0), pL=-40.0,
             fist=CLIMB_FIST, effort=0.4)
    else:              # degrau baixo: estica (ou abaixa) e agarra com os pes no chao
        K.at(0.14 * k, P=Vector((0, -0.01, hz - 0.03)), lean=10.0, hp=14.0, wR=1.0, wL=1.0, hR=pre(1), hL=pre(-1),
             dR=Vector((-0.1, 0.6, 0.6)), dL=Vector((0.1, 0.6, 0.6)), atenta=0.7)
        K.at(0.34 * k, P=Vector((0, yg, zg)), lean=12.0 + 30.0 * max(0.0, (hz - 0.010 - zg) / 0.10), hp=10.0, wR=1.0, wL=1.0,
             hR=edge(1), hL=edge(-1), dR=grip_d(1), dL=grip_d(-1),
             fist=CLIMB_FIST, effort=0.3)
    _mantle(K, R, F, k, D, H, Yend, 0.34, 0.22)
    return K, Vector((0.0, Yend, H)), D


CLIMB_UP_H = {"climb_up_low": 0.6, "climb_up": 0.9, "climb_up_high": 1.2}
CLIMB_UP_T = {"climb_up_low": 1.0, "climb_up": 1.2, "climb_up_high": 1.35}
CLIMB_DOWN_T, CLIMB_DOWN_H = 1.0, 0.9


def climb_up_fn(name):
    H, T = CLIMB_UP_H[name], CLIMB_UP_T[name]
    cache = {}

    def fn(R, F, t, T_):
        if "K" not in cache:
            cache["K"] = climb_up_keys(R, F, H, T)[0]
        return keyed_pose(R, F, cache["K"], t)
    return fn


def climb_down_fn(H=CLIMB_DOWN_H, T=CLIMB_DOWN_T):
    """climb_down: o climb_up (H) ao contrario e mais rapido. Comeca de pe na borda, de costas para ela (a borda fica
    atras), desce agarrado e termina no chao em (0, -Yend, -H) do ponto de partida."""
    cache = {}

    def fn(R, F, t, T_):
        if "K" not in cache:
            K, off, D = climb_up_keys(R, F, H, 1.2)
            cache["K"], cache["off"] = K, off
        return keyed_pose(R, F, cache["K"], 1.2 * (1.0 - t / T), off=-cache["off"])
    return fn


# climb_wall (laco): parede vertical a frente; maos e pes alternam (mao direita com pe esquerdo). O ator sobe
# CLIMB_WALL_ADV metros por ciclo (a mao e o pe de apoio descem nessa velocidade no clipe). Tocado ao contrario
# (velocidade -1) serve para descer uma escada.
CLIMB_WALL_T, CLIMB_WALL_S, CLIMB_WALL_SF = 1.2, 0.18, 0.6
CLIMB_WALL_ADV = CLIMB_WALL_S / CLIMB_WALL_SF


def wall_geom(R, F):
    hz = R.rest_head["hips"].z
    Dw = F.v["belly"] + 0.075
    P = Vector((0.0, 0.0, hz + 0.05))
    arm = R.length("upper_arm.R") + R.length("forearm.R") + PALM_AT * R.length("hand.R")
    leg = R.length("thigh.R") + R.length("shin.R")
    shz = F.sh.z - hz
    h_top = P.z + shz + math.sqrt(max((0.86 * arm) ** 2 - (Dw - 0.035) ** 2, 0.01))
    f_bot = P.z - (hz - R.rest_head["thigh.R"].z) - 0.93 * leg + 0.04
    return dict(Dw=Dw, P=P, h_top=h_top, f_bot=f_bot, hz=hz)


def _limb_phase(p, s, sf):
    """(deslocamento para baixo 0..s, afastamento da parede 0..1) de um membro na fase p."""
    if p < sf:
        return s * p / sf, 0.0
    w = (p - sf) / (1 - sf)
    return s * (1 - smooth(w)), math.sin(math.pi * w)


def wall_limbs(R, F, p0, G=None):
    G = G or wall_geom(R, F)
    s, sf = CLIMB_WALL_S, CLIMB_WALL_SF
    out = {}
    for limb, side, off in (("h", "R", 0.0), ("f", "L", 0.0), ("h", "L", 0.5), ("f", "R", 0.5)):
        dz, away = _limb_phase((p0 + off) % 1.0, s, sf)
        sx = 1 if side == "R" else -1
        if limb == "h":
            out["h" + side] = Vector((sx * 0.11, G["Dw"] - 0.035 - 0.05 * away, G["h_top"] - dz))
            out["d" + side] = Vector((-0.05 * sx, 0.35 - 0.25 * away, 1.0))
        else:
            toe = Vector((sx * 0.10, G["Dw"] - 0.006 - 0.05 * away, G["f_bot"] + s - dz - 0.06))
            out["f" + side] = _ankle_for_toe(R, side, toe, -10.0)
            out["p" + side] = -10.0
    return out, G


def pose_climb_wall(R, F, t, T):
    p0 = (t / T) % 1.0
    L, G = wall_limbs(R, F, p0)
    sway = math.sin(2 * math.pi * p0)
    R.hips_off = G["P"] + Vector((0.012 * sway, 0.0, 0.006 * math.cos(4 * math.pi * p0))) - R.rest_head["hips"]
    R.rel("hips", eul(y=2.5 * sway))
    torso(R, lean=-2.0, roll=-2.0 * sway, head_pitch=14.0, head_yaw=5.0 * sway)
    tips, dirs = _rest_arms(R, F)
    for s, sx in (("R", 1), ("L", -1)):
        _blend_arm(R, s, tips[s], dirs[s], L["h" + s], L["d" + s], 1.0, (sx * 1.0, -0.8, -0.2))
        put_foot(R, s, 0.0, L["p" + s], "heel", ankle=L["f" + s], pole=(sx * 1.0, 0.6, 0.0))
    eff = 0.5 + 0.3 * math.sin(4 * math.pi * p0)
    f = face(atenta=0.4)
    f["brava_leve"] = 0.45 * eff
    f["mouth_E"] = 0.35 * eff
    f["blink"] = blink_curve(t, 0.75, 0.14)
    return _fist(f, CLIMB_FIST)


CLIMB_TOP_T = 0.8


def climb_top_keys(R, F, T=CLIMB_TOP_T):
    """Da parede (pose do climb_wall na fase 0) por cima da borda: borda em Ze = alto das maos no climb_wall - 1 cm; termina de pe em
    cima em (0, Yend, Ze) do ator."""
    L, G = wall_limbs(R, F, 0.0)
    Dw = G["Dw"]
    Ze = G["h_top"] - 0.01            # topo da borda (as palmas apoiam 2,6 cm acima)
    Yend = Dw + 0.10
    edge = lambda sx: Vector((sx * 0.105, Dw + 0.035, Ze + 0.026))
    k = T / 0.8
    K = Keys(dict(t=0.0, P=G["P"].copy(), lean=-2.0, yaw=0.0, roll=0.0, hp=14.0, hy=0.0, hR=L["hR"], hL=L["hL"],
                  dR=L["dR"], dL=L["dL"], wR=1.0, wL=1.0, fR=L["fR"], fL=L["fL"], pR=L["pR"], pL=L["pL"], knee=1.0,
                  fist=CLIMB_FIST, effort=0.5, atenta=0.4, blinks=(0.55 * k,)))
    K.at(0.05 * k, hR=Vector((0.105, Dw - 0.05, Ze + 0.03)), hL=Vector((-0.105, Dw - 0.05, Ze + 0.03)))
    K.at(0.10 * k, hR=edge(1), hL=edge(-1), dR=Vector((-0.1, 0.96, -0.22)), dL=Vector((0.1, 0.96, -0.22)),
         P=G["P"] + Vector((0, 0.0, 0.035)), effort=0.8)   # estica para alcancar a borda
    # o mesmo final do climb_up, comprimido: 0,8 s ao todo
    _mantle(K, R, F, k * 0.84, Dw, Ze, Yend, 0.10 / 0.84, 0.18)   # 0,10 + 0,81 x 0,84: termina em ~0,78 s
    return K, Vector((0.0, Yend, Ze)), Dw


def climb_top_fn():
    cache = {}

    def fn(R, F, t, T):
        if "K" not in cache:
            cache["K"] = climb_top_keys(R, F)[0]
        return keyed_pose(R, F, cache["K"], t)
    return fn


# ----------------------------------------------------------------- corda: throw_rope (1,2 s) e lower_rope (laco)
THROW_T, THROW_REL = 1.2, 0.74


def pose_throw_rope(R, F, t, T):
    """Rolo de corda na mao direita (HoldPoint): traz ao peito, gira o braco para tras, lanca para a frente e para cima
    (solta em THROW_REL) e acompanha; a esquerda equilibra."""
    hold = smooth(t, 0.0, 0.22)
    wind = smooth(t, 0.22, 0.56) * (1 - smooth(t, 0.60, 0.76))
    thr = smooth(t, 0.60, 0.76) * (1 - smooth(t, 0.86, 1.18))
    back = 1 - smooth(t, 0.90, 1.18)
    R.hips_off = Vector((0.0, -0.01 * wind + 0.01 * thr, -0.016 - 0.012 * wind))
    R.rel("hips", eul(z=14.0 * wind - 8.0 * thr))
    torso(R, lean=2.0 - 6.0 * wind + 10.0 * thr, yaw=22.0 * wind - 16.0 * thr, roll=4.0 * wind,
          head_pitch=4.0 + 8.0 * thr, head_yaw=-14.0 * wind + 12.0 * thr)
    tips, dirs = _rest_arms(R, F)
    chest = Vector((0.05, F.v["belly"] + 0.10, F.sh.z - 0.10))
    behind = Vector((F.sh.x + 0.14, -0.14, F.sh.z + 0.06))
    front = Vector((F.sh.x - 0.02, 0.30, F.sh.z + 0.20))
    tgt = chest.lerp(behind, wind).lerp(front, thr)
    d = Vector((-0.4, 0.8, -0.3)).lerp(Vector((0.2, -0.9, 0.3)), wind).lerp(Vector((0.0, 0.8, 0.6)), thr)
    _blend_arm(R, "R", tips["R"], dirs["R"], tgt, d, hold * back, (1.0, -0.6, -0.4))
    bal = Vector((-F.sh.x - 0.10, 0.18, F.sh.z - 0.12))
    _blend_arm(R, "L", tips["L"], dirs["L"], bal, Vector((-0.3, 0.8, -0.4)), 0.7 * smooth(t, 0.15, 0.4) * back,
               (-1.0, -0.6, -0.4))
    for s in ("R", "L"):
        put_foot(R, s, R.rest_head["heel." + s].y + (0.03 if s == "L" else -0.02), 0.0, "heel",
                 dx=(0.02 if s == "R" else -0.02), pole=((0.05 if s == "R" else -0.05), 1.0, 0.0))
    f = face(atenta=0.5 * wind + 0.3, alegre=0.9 * smooth(t, 0.80, 0.88) * (1 - smooth(t, 1.0, 1.1)),
             blink=blink_curve(t, 0.30, 0.14))
    f["brava_leve"] = 0.4 * wind
    f["fist_R"] = 0.6 * (1 - smooth(t, THROW_REL - 0.02, THROW_REL + 0.06))
    f["fist_L"] = 0.0
    return f


LOWER_T, LOWER_S, LOWER_SF = 1.0, 0.20, 0.6
LOWER_ADV = LOWER_S / LOWER_SF          # corda que desce por ciclo (m)


def pose_lower_rope(R, F, t, T):
    """Baixa algo pela corda, mao sobre mao (laco): corda vertical a frente do peito; a mao de apoio desce com a corda,
    a outra volta para cima e agarra mais alto. Pes firmes, corpo levemente para tras (contrapeso)."""
    p0 = (t / T) % 1.0
    ph = 2 * math.pi * p0
    R.hips_off = Vector((0.0, -0.02, -0.040 + 0.004 * math.cos(2 * ph)))
    torso(R, lean=2.0, head_pitch=-22.0, roll=1.5 * math.sin(ph))
    tips, dirs = _rest_arms(R, F)
    ytop = F.v["belly"] + 0.13
    z_top = F.sh.z + 0.02
    for s, off, sx in (("R", 0.0, 1), ("L", 0.5, -1)):
        dz, away = _limb_phase((p0 + off) % 1.0, LOWER_S, LOWER_SF)
        at = Vector((sx * (0.025 + 0.012 * away), ytop + 0.045 * away, z_top - dz))
        _blend_arm(R, s, tips[s], dirs[s], at, Vector((-0.85 * sx, 0.45, -0.15)), 1.0, (sx * 1.0, -0.7, -0.5))
    for s in ("R", "L"):
        put_foot(R, s, R.rest_head["heel." + s].y + (0.03 if s == "R" else -0.03), 0.0, "heel",
                 dx=(0.02 if s == "R" else -0.02), pole=((0.05 if s == "R" else -0.05), 1.0, 0.0))
    f = face(atenta=0.6, blink=blink_curve(t, 0.62, 0.14))
    f["brava_leve"] = 0.3
    return _fist(f, 0.6)


# ----------------------------------------------------------------- montagem por heroi e medidas
G19_LOOPS = ("carry_idle", "carry_walk", "climb_wall", "lower_rope", "push_cart")
G19_FACE_EXTRA = ("brava_leve", "mouth_E")      # chaveados (0 fora destes clipes) em todos os clipes dos herois v2


def g19_clips(walk, climber=False, pilot=False):
    """Clipes G19 de um heroi. `walk`: o WALK (hero_gait_v2) do heroi; carry_walk e push_cart usam o mesmo passo."""
    cw, _ = carry_walk_fn(walk)
    out = {
        "pick_up": (PICK_T, False, pose_pick_up),
        "carry_idle": (2.4, True, pose_carry_idle),
        "carry_walk": (walk["T"], True, cw),
        "place_high": (PLACE_HIGH_T, False, pose_place_high),
        "place_low": (PLACE_LOW_T, False, pose_place_low),
        "inspect": (INSPECT_T, False, pose_inspect_generic),
    }
    if climber:
        for n in CLIMB_UP_H:
            out[n] = (CLIMB_UP_T[n], False, climb_up_fn(n))
        out["climb_wall"] = (CLIMB_WALL_T, True, pose_climb_wall)
        out["climb_top"] = (CLIMB_TOP_T, False, climb_top_fn())
        out["climb_down"] = (CLIMB_DOWN_T, False, climb_down_fn())
        out["throw_rope"] = (THROW_T, False, pose_throw_rope)
        out["lower_rope"] = (LOWER_T, True, pose_lower_rope)
    if pilot:
        pc, _ = push_cart_fn(walk)
        out["push_cart"] = (walk["T"], True, pc)
    return out


def g19_names(climber=False, pilot=False):
    n = ["pick_up", "carry_idle", "carry_walk", "place_high", "place_low", "inspect"]
    if climber:
        n += list(CLIMB_UP_H) + ["climb_wall", "climb_top", "climb_down", "throw_rope", "lower_rope"]
    if pilot:
        n += ["push_cart"]
    return n


def g19_measure(R, F, name, fn, dur):
    """Medidas do clipe no Blender (vao para o info.json): ponto medio das palmas (o encaixe de duas maos) nos
    instantes de pega/solta, distancia entre as palmas e, na escalada, o deslocamento final e o menor afastamento de
    ossos ao volume do degrau/parede (negativo = dentro)."""
    rep = {}
    n = int(round(dur * FPS))

    def at(t):
        R.reset()
        fn(R, F, t, dur)
        R.evaluate()

    if name in ("pick_up", "carry_idle", "carry_walk", "place_high", "place_low", "push_cart"):
        gap = []
        for i in range(n + 1):
            at(dur * i / n)
            if name.startswith("carry") or (name == "pick_up" and i * dur / n >= PICK_GRAB_T) or \
                    (name.startswith("place") and i * dur / n <= (PLACE_HIGH_REL if name == "place_high" else PLACE_LOW_REL)) \
                    or name == "push_cart":
                gap.append((palm(R, "R") - palm(R, "L")).length)
        rep["palmas_dist_m"] = [round(min(gap), 4), round(max(gap), 4)]
    marks = {"pick_up": PICK_GRAB_T, "place_high": PLACE_HIGH_REL, "place_low": PLACE_LOW_REL, "throw_rope": THROW_REL,
             "carry_idle": 0.0}
    if name in marks:
        at(marks[name])
        rep["instante_s"] = marks[name]
        rep["meio_palmas_m"] = [round(v, 4) for v in (palm(R, "R") + palm(R, "L")) * 0.5]
        rep["palma_R_m"] = [round(v, 4) for v in palm(R, "R")]
    if name.startswith("climb"):
        pts = ("HoldPoint", "HoldPoint_L", "hand_tip.R", "hand_tip.L", "hand.R", "hand.L", "forearm.R", "forearm.L", "toe_tip.R", "toe_tip.L", "toe.R",
               "toe.L", "heel.R", "heel.L", "foot.R", "foot.L", "shin.R", "shin.L", "hips", "chest", "neck")
        if name in ("climb_wall", "climb_top"):
            G = wall_geom(R, F)
            ze = G["h_top"] - 0.01 if name == "climb_top" else 99.0
            vol = lambda p, Dw=G["Dw"], ze=ze: max(Dw - p.y, p.z - ze)
            if name == "climb_top":
                rep["deslocamento_final_m"] = [round(v, 4) for v in climb_top_keys(R, F)[1]]
                rep["borda_acima_do_ator_m"] = round(ze, 4)
            else:
                rep["subida_por_ciclo_m"] = round(CLIMB_WALL_ADV, 4)
                rep["subida_mps"] = round(CLIMB_WALL_ADV / dur, 4)
            rep["face_da_parede_y_m"] = round(G["Dw"], 4)
        else:
            H = CLIMB_UP_H.get(name, CLIMB_DOWN_H)
            K, off, D = climb_up_keys(R, F, H, 1.2)
            sh = -off if name == "climb_down" else Vector((0, 0, 0))
            vol = lambda p, D=D + sh.y, top=H + sh.z: max(D - p.y, p.z - top)
            rep["deslocamento_final_m"] = [round(v, 4) for v in (-off if name == "climb_down" else off)]
            rep["altura_do_degrau_m"] = H
            rep["face_do_degrau_y_m"] = round(D + sh.y, 4)
        worst, wb, wt = 9.0, None, None
        for i in range(n + 1):
            t = dur * i / n
            at(t)
            for b in pts:
                # hand_tip/toe_tip: so a cabeca (o osso e uma extensao de 2 cm alem da ponta da malha)
                for p in ((R.pos[b],) if b.endswith("_tip.R") or b.endswith("_tip.L") else (R.pos[b], R.tip(b))):
                    c = vol(p)
                    if c < worst:
                        worst, wb, wt = c, b, round(t, 3)
        rep["folga_min_m"] = round(worst, 4)
        rep["folga_min_osso"] = wb
        rep["folga_min_t"] = wt
    if name == "inspect":
        tgt = Vector((0.07, R.rest_head["toe_tip.R"].y + 0.05, 0.012))
        best = 9.0
        for i in range(n + 1):
            at(dur * i / n)
            best = min(best, (R.tip("hand.R") - tgt).length)
        rep["toque_no_chao_erro_m"] = round(best, 4)
    if name == "lower_rope":
        rep["corda_por_ciclo_m"] = round(LOWER_ADV, 4)
        rep["corda_mps"] = round(LOWER_ADV / dur, 4)
    R.reset()
    return rep
