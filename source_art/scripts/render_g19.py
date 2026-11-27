"""RB-R1 G19: pranchas dos clipes de pegar, levar, pousar, examinar, escalar e corda (4 quadros por clipe), a partir do
.blend de um heroi v2. Objetos de prova (so no render, nao entram no GLB): caixa de 15 cm no ponto medio dos HoldPoints
enquanto esta na mao, degrau/parede/bancada/varal nas medidas do clipe, corda, alca do carrinho. PROVISORIO.

Uso: bash tools/blender.sh --background source_art/characters/pico_v2/pico_v2.blend \
        --python source_art/scripts/render_g19.py -- <saida> pico [clipe ...]
Gera <saida>/<clipe>/<heroi>_<i>.png e <saida>/<clipe>/<heroi>.png (4 quadros lado a lado).
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)
sys.path.insert(0, os.path.abspath(os.path.join(HERE, "..", "characters", "rastro_v2")))

import bpy
from mathutils import Matrix, Vector

import rv2_render as RR
from rbart import hex_to_linear

args = sys.argv[sys.argv.index("--") + 1:]
OUT = os.path.abspath(args[0])
HERO = args[1]
ONLY = args[2:]
sc = bpy.context.scene
rig = next(o for o in sc.objects if o.type == "ARMATURE")
meshes = [o for o in sc.objects if o.type == "MESH"]
face = next(o for o in meshes if o.name.endswith("_Face"))
gear = next(o for o in meshes if o.name.endswith("_Gear"))
for o in meshes:
    if o.name.startswith("Acc_"):
        o.hide_render = True
ADS = [rig.animation_data, face.data.shape_keys.animation_data]
GK = gear.data.shape_keys.animation_data if gear.data.shape_keys and gear.data.shape_keys.animation_data else None


def info():
    import json
    p = os.path.splitext(bpy.data.filepath)[0] + ".info.json"
    with open(p, encoding="utf-8") as f:
        return json.load(f)


INFO = info()
G = INFO.get("g19", {})


def set_clip(name, t):
    for ad in ADS + ([GK] if GK else []):
        for tr in ad.nla_tracks:
            tr.mute = True
    rig.animation_data.action = bpy.data.actions[name]
    face.data.shape_keys.animation_data.action = bpy.data.actions[name + "_key"]
    if GK:
        GK.action = bpy.data.actions.get(name + "_gear") or bpy.data.actions.get(name + "_hand")
    fr = t * 30.0
    sc.frame_set(int(math.floor(fr)), subframe=fr - math.floor(fr))
    bpy.context.view_layer.update()


def hold_mid():
    a = rig.matrix_world @ rig.pose.bones["HoldPoint"].head
    b = rig.matrix_world @ rig.pose.bones["HoldPoint_L"].head
    return (a + b) * 0.5, a, b


def mat(name, hexc, rough=0.6, alpha=1.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bs = m.node_tree.nodes["Principled BSDF"]
    bs.inputs["Base Color"].default_value = hex_to_linear(hexc) + (1,)
    bs.inputs["Roughness"].default_value = rough
    if alpha < 1.0:
        bs.inputs["Alpha"].default_value = alpha
    return m


PROPS = []


def clear_props():
    for o in PROPS:
        bpy.data.objects.remove(o, do_unlink=True)
    PROPS.clear()


def box(name, center, size, m):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=center)
    o = bpy.context.active_object
    o.name = name
    o.scale = size
    o.data.materials.append(m)
    PROPS.append(o)
    return o


def cyl(name, a, b, r, m):
    a, b = Vector(a), Vector(b)
    bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=(b - a).length, location=(a + b) * 0.5, vertices=16)
    o = bpy.context.active_object
    o.name = name
    o.rotation_euler = (b - a).to_track_quat("Z", "Y").to_euler()
    o.data.materials.append(m)
    PROPS.append(o)
    return o


M_BOX = mat("g19_caixa", "#E0412B", 0.5)
M_STONE = mat("g19_degrau", "#9AA3AD", 0.8)
M_LINE = mat("g19_varal", "#2B5FD8", 0.4)
M_ROPE = mat("g19_corda", "#C8A050", 0.7)
M_MARK = mat("g19_marca", "#FFFFFF", 0.3)
BOX = 0.15

RR.scene_lights(sc)
floor = sc.objects["Chao_prova"]
cam = RR.camera(sc, (0, 0, 0.56), 3.6, 8, 0, 70)
RR.cycles(sc, 300, 420, 14)
sc.render.film_transparent = False

hz = rig.data.bones["hips"].head_local.z


NF = int(os.environ.get("G19_NF", "4"))


def frames_for(name, dur):
    if NF != 4:
        return [round(dur * i / (NF - 1), 4) for i in range(NF)]
    if name == "carry_walk":
        sf = INFO["ciclos_v2"]["walk"]["apoio_frac"]
        return [round(dur * f, 4) for f in (0.02, sf * 0.33, sf * 0.66, sf * 0.97)]
    if name in ("climb_wall", "lower_rope", "carry_idle", "push_cart"):
        return [round(dur * f, 4) for f in (0.0, 0.25, 0.5, 0.75)]
    marks = {"pick_up": (0.0, 0.15, 0.27, 0.6), "place_high": (0.0, 0.25, 0.45, 0.9), "place_low": (0.0, 0.2, 0.38, 0.8),
             "throw_rope": (0.2, 0.5, 0.74, 1.2), "inspect": (0.0, 0.45, 0.75, 1.4)}
    if name in marks:
        return list(marks[name])
    return [round(dur * f, 4) for f in (0.0, 0.33, 0.66, 1.0)]


def scene_for(name, t, frames):
    """Objetos de prova e camera do quadro."""
    clear_props()
    floor.location = (0, 0, 0)
    rig.location = (0, 0, 0)
    g = G.get(name, {})
    tgt, dist, elev, az = (0, 0.05, 0.56), 3.6, 8.0, -28.0
    mid, a, b = hold_mid()
    if name in ("pick_up", "carry_idle", "carry_walk", "place_high", "place_low"):
        rel = None
        if name == "pick_up" and t < 0.27:
            set_clip(name, 0.27)
            rel = hold_mid()[0]
            set_clip(name, t)
        if name.startswith("place"):
            tr = g.get("instante_s", 0.4)
            if t > tr + 1e-3:
                set_clip(name, tr)
                rel = hold_mid()[0]
                set_clip(name, t)
        c = rel if rel is not None else hold_mid()[0]
        if name == "carry_walk":
            v = INFO["walk_speed_mps"]
            rig.location = (0, v * t, 0)
            bpy.context.view_layer.update()
            c = hold_mid()[0]
            set_clip(name, frames[0])
            rig.location = (0, v * frames[0], 0)
            bpy.context.view_layer.update()
            heel = rig.matrix_world @ rig.pose.bones["heel.R"].head
            rig.location = (0, v * t, 0)
            set_clip(name, t)
            box("marca", (heel.x, heel.y, 0.002), (0.05, 0.05, 0.004), M_MARK)
            tgt, dist, elev, az = (0, v * 0.2, 0.5), 3.4, 4.0, -90.0
        box("caixa", c, (BOX, BOX, BOX), M_BOX)
        if name == "place_high":
            cyl("varal_1_58", (-0.6, 0.2, 1.58), (0.6, 0.2, 1.58), 0.006, M_LINE)
            tgt, dist = (0, 0.05, 0.75), 4.2
        if name == "place_low":
            top = g.get("meio_palmas_m", [0, 0.26, 0.7])
            bz = top[2] - BOX / 2
            box("bancada", (0, top[1] + 0.20, bz / 2), (0.6, 0.30, bz), M_STONE)
            az = -60.0
    elif name.startswith("climb_up") or name == "climb_down":
        H = g["altura_do_degrau_m"]
        D = g["face_do_degrau_y_m"]
        if name == "climb_down":
            floor.location = (0, 0, -H)
            box("degrau", (0, D + 0.3, -H / 2), (0.9, 0.6, H), M_STONE)
            tgt = (0, -0.1, 0.1)
        else:
            box("degrau", (0, D + 0.3, H / 2), (0.9, 0.6, H), M_STONE)
            tgt = (0, 0.2, (H + 0.9) / 2)
        dist, elev, az = 4.6 + H, 8.0, -98.0
    elif name in ("climb_wall", "climb_top"):
        Dw = g["face_da_parede_y_m"]
        if name == "climb_top":
            ze = g["borda_acima_do_ator_m"]
            box("parede", (0, Dw + 0.3, ze / 2 - 0.5), (0.9, 0.6, ze + 1.0), M_STONE)
            tgt = (0, 0.2, ze * 0.9 + 0.2)
        else:
            box("parede", (0, Dw + 0.05, 0.6), (0.9, 0.1, 2.4), M_STONE)
            for i in range(9):          # degraus de escada a cada 0,15 m (so referencia de altura)
                z = 0.05 + 0.15 * i
                cyl("ref", (-0.35, Dw - 0.005, z), (-0.30, Dw - 0.005, z), 0.004, M_MARK)
            tgt = (0, 0.1, 0.55)
        floor.location = (0, 0, -0.5 if name == "climb_wall" else 0.0)
        dist, elev, az = 4.4, 8.0, (-150.0 if name == "climb_wall" else -100.0)
    elif name == "throw_rope":
        if t <= g.get("instante_s", 0.74) + 1e-3:
            bpy.ops.mesh.primitive_torus_add(major_radius=0.06, minor_radius=0.018, location=a)
            o = bpy.context.active_object
            o.data.materials.append(M_ROPE)
            PROPS.append(o)
        az = -60.0
    elif name == "lower_rope":
        cyl("corda", (mid.x, mid.y, 1.0), (mid.x, mid.y, -0.6), 0.008, M_ROPE)
    elif name == "push_cart":
        cyl("alca", (a.x + 0.06, a.y, a.z), (b.x - 0.06, b.y, b.z), 0.012, M_ROPE)
        az = -60.0
    RR.place(cam, tgt, dist, elev, az)


def run():
    names = ONLY or list(G.keys())
    for name in names:
        if name not in bpy.data.actions:
            continue
        a = bpy.data.actions[name]
        dur = (a.frame_range[1] - a.frame_range[0]) / 30.0
        fr = frames_for(name, dur)
        d = os.path.join(OUT, name)
        os.makedirs(d, exist_ok=True)
        paths = []
        for i, t in enumerate(fr):
            set_clip(name, t)
            scene_for(name, t, fr)
            paths.append(RR.render(sc, os.path.join(d, "%s_%d.png" % (HERO, i))))
        RR.compose([paths], os.path.join(d, HERO + ".png"))
        print("PRANCHA", name, HERO, fr)


run()
