"""Animacoes procedurais dos personagens (RB-04-chars): FK + IK de 2 ossos, 30 fps, sem root motion. PROVISORIO.

Clipes (todos nomeados e estaveis): idle, walk, crouch, inspect_touch, look_to_leme, react_surprise (Rastro);
idle, walk, idle_wheel, steer_left, steer_right, react_horn (Leme); idle, walk (figurantes).
Frente = +Y (Blender), direita do personagem = +X. Contatos dos pes: cinematica inversa com pivo de calcanhar/bola.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
from mathutils import Quaternion, Vector

import char_lib as cl
from char_lib import eul

FPS = 30
SF = 0.58        # fracao do ciclo com o pe no chao (walk)
TOUCH_TARGET = Vector((0.10, 0.45, 0.35))   # alvo da ponta da mao em inspect_touch (m, referencial do ator, Blender: +Y = frente)
WALK_STEP = 0.40  # curso do pe no referencial do corpo por apoio (m)


def smooth(t, a=0.0, b=1.0):
    u = max(0.0, min(1.0, (t - a) / (b - a)))
    return u * u * (3 - 2 * u)


def lerp(a, b, u):
    return a + (b - a) * u


# ----------------------------------------------------------------- blocos de pose
def foot_ankle(R, s, heel_y, phi, pivot, lift=0.0, dx=0.0):
    a0, h0, b0 = R.rest_head["foot." + s], R.rest_head["heel." + s], R.rest_head["toe." + s]
    p0 = h0 if pivot == "heel" else b0
    py = heel_y if pivot == "heel" else heel_y + (b0.y - h0.y)
    ra = a0 - p0
    c, sn = math.cos(math.radians(phi)), math.sin(math.radians(phi))
    return Vector((a0.x + dx, py + ra.y * c - ra.z * sn, ra.y * sn + ra.z * c + lift))


def put_foot(R, s, heel_y, phi=0.0, pivot="heel", lift=0.0, dx=0.0, pole=None, ankle=None):
    a = ankle if ankle is not None else foot_ankle(R, s, heel_y, phi, pivot, lift, dx)
    sx = 1 if s == "R" else -1
    R.solve2("thigh." + s, "shin." + s, None, a, pole or (sx * 0.05, 1.0, 0.0))
    R.absolute["foot." + s] = eul(x=phi)
    R.absolute["toe." + s] = eul(x=phi if phi > 0 else 0.0)
    return a


def stand_feet(R, lifts=(0.0, 0.0), dxs=(0.0, 0.0)):
    for s, lf, dx in (("R", lifts[0], dxs[0]), ("L", lifts[1], dxs[1])):
        put_foot(R, s, R.rest_head["heel." + s].y, 0.0, "heel", lift=lf, dx=dx)


def reach(R, s, tip, hand_dir, pole=None, roll=0.0):
    sx = 1 if s == "R" else -1
    hd = Vector(hand_dir).normalized()
    wrist = Vector(tip) - hd * R.length("hand." + s)
    R.solve2("upper_arm." + s, "forearm." + s, "hand." + s, wrist, pole or (sx * 0.6, -0.5, -1.0), end_dir=hd, end_roll=roll * sx)


def arms_relaxed(R, bend=14.0, adduct=14.0, swing=(0.0, 0.0)):
    for s, sx in (("R", 1), ("L", -1)):
        sw = swing[0] if s == "R" else swing[1]
        R.rel("upper_arm." + s, eul(x=sw, y=adduct * sx))
        R.rel("forearm." + s, eul(x=bend + abs(sw) * 0.5))


def torso(R, lean=0.0, yaw=0.0, roll=0.0, head_pitch=0.0, head_yaw=0.0, head_roll=0.0):
    R.rel("spine", eul(x=-lean * 0.45, y=roll * 0.5, z=yaw * 0.4))
    R.rel("chest", eul(x=-lean * 0.55, y=roll * 0.5, z=yaw * 0.6))
    R.rel("neck", eul(x=-head_pitch * 0.3, z=head_yaw * 0.35, y=head_roll * 0.3))
    R.rel("head", eul(x=-head_pitch * 0.7 + lean * 0.9, z=head_yaw * 0.65, y=head_roll * 0.7))


def blink_curve(t, at, dur=0.18):
    u = (t - at) / dur
    if u < 0 or u > 1:
        return 0.0
    return math.sin(u * math.pi) ** 0.7


def zero_face():
    return {"atenta": 0.0, "surpresa": 0.0, "alegre": 0.0, "blink": 0.0}


# ----------------------------------------------------------------- clipes
def pose_idle(R, t, T, cfg, K):
    """Respirar: 2,4 s em loop. Observadora (leve inclinacao a frente) quando cfg lean."""
    ph = 2 * math.pi * t / T
    breath = math.sin(ph)
    lean = (7.0 if cfg["lean"] else 2.0) + 0.8 * breath
    R.hips_off = Vector((0.004 * math.sin(ph), 0.0, -0.022 * K + 0.003 * breath))
    torso(R, lean=lean, yaw=2.0 * math.sin(ph), head_pitch=1.5 * math.sin(ph + 1.2) - (3 if cfg["lean"] else 0),
          head_yaw=3.5 * math.sin(ph + 0.6), head_roll=1.5 * math.sin(ph + 2.0))
    R.rel("shoulder.R", eul(y=-1.5 * breath))
    R.rel("shoulder.L", eul(y=1.5 * breath))
    arms_relaxed(R, bend=16 + 2 * breath, adduct=13 + 1.5 * breath)
    stand_feet(R)
    f = zero_face()
    f["blink"] = blink_curve(t, 1.5) + blink_curve(t, 0.25 if T > 2.0 else 9, 0.0001)
    return f


def pose_walk(R, t, T, cfg, K):
    p0 = (t / T) % 1.0
    L = WALK_STEP * K
    zb = 0.485 * K
    ph = 2 * math.pi * p0
    R.hips_off = Vector((0.0, 0.0, -(0.55 * K - zb) + 0.013 * math.cos(4 * math.pi * (p0 - 0.30))))
    R.rel("hips", eul(z=4.0 * math.sin(ph), y=2.0 * math.cos(ph)))
    torso(R, lean=(6.0 if cfg["lean"] else 3.0), yaw=-5.0 * math.sin(ph), head_yaw=3.0 * math.sin(ph), head_pitch=-2.0)
    sw = 24.0 * math.cos(ph)
    arms_relaxed(R, bend=18, adduct=10, swing=(-sw, sw))   # direita para tras quando a perna direita vai a frente
    for s, off in (("R", 0.0), ("L", 0.5)):
        p = (p0 + off) % 1.0
        h0 = R.rest_head["heel." + s].y
        hy_front = h0 + L / 2
        if p < SF:
            u = p / SF
            hy = hy_front - L * u
            if u < 0.12:
                phi, pivot = 15.0 * (1 - smooth(u, 0, 0.12)), "heel"
            elif u < 0.62:
                phi, pivot = 0.0, "heel"
            else:
                phi, pivot = -28.0 * smooth(u, 0.62, 1.0), "ball"
            put_foot(R, s, hy, phi, pivot)
        else:
            sw_u = (p - SF) / (1 - SF)
            a_end = foot_ankle(R, s, hy_front - L, -28.0, "ball")
            a_start = foot_ankle(R, s, hy_front, 15.0, "heel")
            e = smooth(sw_u)
            a = a_end.lerp(a_start, e)
            a.z += 0.075 * K * math.sin(math.pi * sw_u) ** 1.2
            phi = lerp(-28.0, 15.0, smooth(sw_u, 0.1, 0.95))
            put_foot(R, s, 0, phi, "heel", ankle=a)
    return zero_face()


def crouch_pose(R, u, K, cfg):
    """u: 0 em pe ... 1 agachada. Pes ficam plantados; quadril desce e recua; tronco inclina."""
    zb = 0.535 * K
    zc = 0.335 * K
    R.hips_off = Vector((0.0, -0.105 * K * u, lerp(zb, zc, u) - 0.55 * K))
    torso(R, lean=lerp(7.0 if cfg["lean"] else 2.0, 30.0, u), head_pitch=-8 * u - (3 if cfg["lean"] else 0) * (1 - u),
          head_yaw=0)
    arms_relaxed(R, bend=lerp(16, 38, u), adduct=lerp(13, 8, u), swing=(0.0, 0.0))
    for s in ("R", "L"):
        put_foot(R, s, R.rest_head["heel." + s].y, 0.0, "heel", pole=(0.0, 1.0, 0.0))


def pose_crouch(R, t, T, cfg, K):
    u = smooth(t, 0.0, 0.65)
    crouch_pose(R, u, K, cfg)
    f = zero_face()
    f["atenta"] = u * 0.8
    f["blink"] = blink_curve(t, 0.7)
    return f


def pose_inspect(R, t, T, cfg, K):
    crouch_pose(R, 1.0, K, cfg)
    reach_u = smooth(t, 0.45, 1.15) * (1 - smooth(t, 2.0, 2.65))
    press = 0.0
    # cabeca olha a marca
    torso(R, lean=30.0 + 6.0 * reach_u, head_pitch=-8 - 18 * reach_u, head_yaw=0)
    rest_tip = Vector((0.20 * K, 0.18 * K, 0.55 * K))
    tip = rest_tip.lerp(TOUCH_TARGET * Vector((1, 1, 1)) + Vector((0, 0, -press)), reach_u)
    tip = Vector((tip.x, tip.y, tip.z))
    hd = Vector((0, 0.15, -1)).lerp(Vector((0.05, 0.62, -0.78)), reach_u)
    reach(R, "R", tip, hd, pole=(0.9, -0.6, -0.6), roll=-80.0 * reach_u)
    # mao esquerda no joelho
    R.rel("upper_arm.L", eul(x=18, y=-8))
    R.rel("forearm.L", eul(x=30))
    f = zero_face()
    f["atenta"] = 0.85
    f["blink"] = blink_curve(t, 2.2)
    return f


def pose_look(R, t, T, cfg, K):
    a = smooth(t, 0.15, 0.75) * (1 - smooth(t, 1.9, 2.4))
    ph = 2 * math.pi * (t - 0.9) * 2.2
    wave = a * smooth(t, 0.7, 0.95) * (1 - smooth(t, 1.6, 1.9))
    base = (7.0 if cfg["lean"] else 2.0)
    R.hips_off = Vector((0, 0, -0.022 * K))
    R.rel("hips", eul(z=-10 * a))
    torso(R, lean=lerp(base, 3.0, a), yaw=-30.0 * a, head_pitch=-4 * a, head_yaw=-34.0 * a, head_roll=-3 * a)
    arms_relaxed(R, bend=16, adduct=13)
    # braco direito sinaliza: pulso acima do ombro, balanca
    shoulder = Vector((0.16, 0, 0.83)) * K
    tgt = Vector((0.40 * K + 0.05 * math.sin(ph) * wave, 0.10 * K, 1.02 * K))
    hd = Vector((0.45 + 0.35 * math.sin(ph) * wave, 0.1, 0.9))
    if wave > 0.001 or smooth(t, 0.6, 0.95) > 0:
        e = smooth(t, 0.6, 0.95) * (1 - smooth(t, 1.7, 2.05))
        rest_tip = Vector((0.30 * K, 0.12 * K, 0.32 * K))
        tip = rest_tip.lerp(tgt, e)
        hd2 = Vector((0.2, 0.2, -1.0)).lerp(hd, e)
        reach(R, "R", tip, hd2, pole=(0.7, -0.8, -0.3))
    stand_feet(R)
    f = zero_face()
    f["atenta"] = a * 0.6
    f["alegre"] = wave * 0.9
    f["blink"] = blink_curve(t, 1.1)
    return f


def pose_surprise(R, t, T, cfg, K):
    a = smooth(t, 0.0, 0.12) * (1 - smooth(t, 0.55, 0.9))
    hop = math.sin(math.pi * min(max((t - 0.04) / 0.34, 0.0), 1.0)) * 0.05 * K
    R.hips_off = Vector((0, -0.04 * K * a, -0.022 * K + hop * 0.0 + 0.02 * K * math.sin(math.pi * min(max((t - 0.04) / 0.34, 0.0), 1.0))))
    torso(R, lean=lerp(7.0 if cfg["lean"] else 2.0, -12.0, a), head_pitch=12.0 * a, head_yaw=0, head_roll=0)
    arms_relaxed(R, bend=lerp(16, 10, a), adduct=lerp(13, -35, a))
    for s, sx in (("R", 1), ("L", -1)):
        R.rel("shoulder." + s, eul(y=-6 * a * sx * -1))
        R.rel("forearm." + s, eul(x=lerp(16, 30, a), y=-25 * a * sx))
    lf = hop
    for s in ("R", "L"):
        put_foot(R, s, R.rest_head["heel." + s].y - 0.02 * K * a, 0.0 if hop < 0.004 else -18 * (hop / (0.05 * K)),
                 "heel" if hop < 0.004 else "ball", lift=lf)
    f = zero_face()
    f["surpresa"] = smooth(t, 0.0, 0.1) * (1 - smooth(t, 0.65, 0.9))
    return f


# ---- Leme (volante)
WHEEL_C = Vector((0.0, 0.34, 0.79))
WHEEL_R = 0.17


def wheel_hands(R, K, ang_deg, only=None):
    for s, base in (("R", 25.0), ("L", 155.0)):
        if only and s not in only:
            continue
        a = math.radians(base + ang_deg)
        c = WHEEL_C * K
        tip = Vector((c.x + math.cos(a) * WHEEL_R * K, c.y, c.z + math.sin(a) * WHEEL_R * K))
        reach(R, s, tip, (0.0 if s == "R" else 0.0, 1.0, -0.15 + (0.3 if tip.z < c.z else 0)), pole=((1 if s == "R" else -1) * 0.7, -0.4, -1.0))


def pose_idle_wheel(R, t, T, cfg, K, ang=0.0, steer=0.0):
    ph = 2 * math.pi * t / T
    R.hips_off = Vector((0.006 * math.sin(ph), 0.0, -0.02 * K))
    R.rel("hips", eul(z=1.5 * math.sin(ph), y=-steer * 2.0))
    torso(R, lean=3.0 + 1.0 * math.sin(ph), roll=-steer * 3.0, yaw=steer * 6.0, head_yaw=steer * 12.0 + 3 * math.sin(ph + 1),
          head_pitch=1.0 * math.sin(ph))
    wheel_hands(R, K, ang + 2.0 * math.sin(ph))
    stand_feet(R)
    f = zero_face()
    f["blink"] = blink_curve(t, 1.6)
    return f


def pose_steer(R, t, T, cfg, K, sign):
    e = smooth(t, 0.0, 0.35) * (1 - smooth(t, 0.65, 1.0))
    f = pose_idle_wheel(R, 0.0, 2.4, cfg, K, ang=sign * 38.0 * e, steer=sign * e)
    f["atenta"] = 0.5 * e
    return f


def pose_horn(R, t, T, cfg, K):
    e = smooth(t, 0.0, 0.2) * (1 - smooth(t, 0.55, 0.9))
    pull = math.sin(math.pi * smooth(t, 0.25, 0.6))
    f = pose_idle_wheel(R, 0.0, 2.4, cfg, K)
    rest_tip = Vector((WHEEL_R * K * 0.9 + 0.0, WHEEL_C.y * K, 0.86 * K))
    tgt = Vector((0.18 * K, 0.30 * K, (1.16 - 0.12 * pull) * K))
    reach(R, "R", rest_tip.lerp(tgt, e), Vector((0.0, 0.3, 1.0)).lerp(Vector((0, 0.1, 1.0)), 0), pole=(0.7, -0.5, -0.8))
    torso(R, lean=lerp(3.0, -4.0, e), head_pitch=8 * e, head_yaw=-8 * e, head_roll=4 * pull)
    stand_feet(R)
    f["surpresa"] = 0.0
    f["alegre"] = 0.7 * e
    f["blink"] = 0.0
    return f


CLIPS = {
    # nome: (duracao_s, loop, funcao)
    "idle": (2.4, True, pose_idle),
    "walk": (1.0, True, pose_walk),
    "crouch": (1.0, False, pose_crouch),
    "inspect_touch": (3.0, False, pose_inspect),
    "look_to_leme": (2.4, False, pose_look),
    "react_surprise": (0.9, False, pose_surprise),
    "idle_wheel": (2.4, True, pose_idle_wheel),
    "steer_left": (1.0, False, lambda R, t, T, cfg, K: pose_steer(R, t, T, cfg, K, +1)),
    "steer_right": (1.0, False, lambda R, t, T, cfg, K: pose_steer(R, t, T, cfg, K, -1)),
    "react_horn": (0.9, False, pose_horn),
}


def author(rig, face_ob, cfg, cid):
    R = cl.Rigger(rig)
    K = cfg["K"]
    sk = face_ob.data.shape_keys
    sk.animation_data_create()
    rig.animation_data_create()
    prev = {}
    for name in cfg["anims"]:
        dur, loop, fn = CLIPS[name]
        act = bpy.data.actions.new(name)
        act.use_fake_user = True
        keyact = bpy.data.actions.new(name + "_key")
        keyact.use_fake_user = True
        rig.animation_data.action = act
        sk.animation_data.action = keyact
        n = int(round(dur * FPS))
        prev.clear()
        for i in range(n + 1):
            t = dur * i / n
            R.reset()
            face = fn(R, t, dur, cfg, K)
            R.apply(i, prev)
            for kn in ("atenta", "surpresa", "alegre", "blink"):
                kb = sk.key_blocks[kn]
                kb.value = max(0.0, min(1.0, face.get(kn, 0.0)))
                kb.keyframe_insert("value", frame=i)
        act["loop"] = loop
        for ad, a_ in ((rig.animation_data, act), (sk.animation_data, keyact)):
            ad.action = None
            tr = ad.nla_tracks.new()
            tr.name = name
            st = tr.strips.new(name, 0, a_)
            st.name = name





