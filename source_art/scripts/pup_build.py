"""Filhote (pup) do RB-R1: cachorrinho ORIGINAL do projeto (caramelo com focinho e peito creme, mancha creme em volta de um olho,
orelhas caidas castanhas, coleira turquesa com pingente-emblema da Rota Brava). PROVISORIO.
Geometria 100% procedural (SKIN + SUBSURF, bmesh); rig proprio de 22 ossos; rosto com o mesmo sistema dos herois (hero_face).
Clipes: idle, wag, jump_happy, bark, step_on_horn, walk, run (RB-R1 arte das cenas). Frente = +Y (Blender) = -Z (Godot). Origem nas patas.

Uso: tools/blender.ps1 --background --factory-startup --python source_art/scripts/pup_build.py -- [--blend X] [--glb Y]
"""
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bmesh
import bpy
from mathutils import Matrix, Vector

import char_lib as cl
import hero_face
import hero_lib
from char_lib import eul
from rbart import REPO, arg_value, mat, new_object, reset_scene, tri_count, world_bbox

PAL = dict(pelo="#E3A15A", creme="#FFF1D6", orelha="#9A5B2E", nariz="#2A1A14", coleira="#2FB5A5", ouro="#FFC83D",
           emblema="#123A5E", olhos="#FFFFFF", iris="#6B3F1F", escuro="#22140E", boca="#B04050", lingua="#F07A8A", pele="#E3A15A")
HC = Vector((0.0, 0.17, 0.40))          # centro da cabeca
HR = (0.115, 0.105, 0.105)
LEGS = {"fl.L": (-0.055, 0.10), "fl.R": (0.055, 0.10), "bl.L": (-0.06, -0.10), "bl.R": (0.06, -0.10)}
BODY_Z = 0.22


def V(*a):
    return Vector(a)


def bones():
    B = [("root", (0, 0, 0), (0, 0, 0.06), None, False),
         ("hips", (0, -0.10, BODY_Z), (0, -0.02, BODY_Z + 0.01), "root", True),
         ("spine", (0, -0.02, BODY_Z + 0.01), (0, 0.06, BODY_Z + 0.02), "hips", True),
         ("chest", (0, 0.06, BODY_Z + 0.02), (0, 0.11, BODY_Z + 0.06), "spine", True),
         ("neck", (0, 0.11, BODY_Z + 0.06), (0, 0.15, 0.32), "chest", True),
         ("head", (0, 0.15, 0.32), (0, 0.17, 0.52), "neck", True)]
    for s, sx in (("L", -1), ("R", 1)):
        B.append(("ear." + s, (sx * 0.09, 0.15, 0.46), (sx * 0.13, 0.14, 0.36), "head", True))
    B += [("tail1", (0, -0.15, BODY_Z + 0.03), (0, -0.20, BODY_Z + 0.08), "hips", True),
          ("tail2", (0, -0.20, BODY_Z + 0.08), (0, -0.22, BODY_Z + 0.14), "tail1", True),
          ("tail3", (0, -0.22, BODY_Z + 0.14), (0, -0.21, BODY_Z + 0.19), "tail2", True)]
    for name, (x, y) in LEGS.items():
        s = name[-1]
        pre = name[:2]
        parent = "chest" if pre == "fl" else "hips"
        B += [(pre + "_upper." + s, (x, y, BODY_Z - 0.01), (x, y + 0.005, 0.11), parent, True),
              (pre + "_lower." + s, (x, y + 0.005, 0.11), (x, y, 0.03), pre + "_upper." + s, True),
              (pre + "_paw." + s, (x, y, 0.03), (x, y + 0.04, 0.0), pre + "_lower." + s, True)]
    return B


RAD = {"hips": 0.09, "spine": 0.09, "chest": 0.09, "neck": 0.05, "head": 0.12, "ear": 0.03, "tail1": 0.025, "tail2": 0.022,
       "tail3": 0.02, "fl_upper": 0.04, "fl_lower": 0.032, "fl_paw": 0.035, "bl_upper": 0.045, "bl_lower": 0.032, "bl_paw": 0.035}


class _F:   # quadro minimo para hero_lib.geom_weights
    pass


def build_pup(with_rig=True):
    M = {}
    for role, col in PAL.items():
        m = mat("mat_pup_" + role, col, 0.7 if role not in ("olhos", "iris") else 0.2)
        b = m.node_tree.nodes["Principled BSDF"]
        b.inputs["Emission Color"].default_value = m.diffuse_color
        b.inputs["Emission Strength"].default_value = hero_lib.EMISSION.get(role, 0.20)
        M[role] = m
    objs = []

    def reg(ob, mode, bone=None):
        objs.append((ob, mode, bone))
        return ob

    # corpo (tronco + pernas) em uma malha SKIN
    nodes = [((0, -0.11, BODY_Z), 0.085), ((0, 0.0, BODY_Z + 0.01), 0.088), ((0, 0.09, BODY_Z + 0.03), 0.090),
             ((0, 0.13, 0.30), 0.055)]
    edges = [(0, 1), (1, 2), (2, 3)]
    for name, (x, y) in LEGS.items():
        i0 = len(nodes)
        root = 2 if name.startswith("fl") else 0
        nodes += [((x, y, BODY_Z - 0.03), 0.042), ((x, y + 0.005, 0.11), 0.034), ((x, y, 0.045), 0.033)]
        edges += [(root, i0), (i0, i0 + 1), (i0 + 1, i0 + 2)]
    body = cl.skin_obj("Pup_Body", nodes, edges, M["pelo"], levels=2, scale=(1.0, 1.0, 1.0))
    reg(body, "dist")
    # barriga/peito creme
    bm = bmesh.new()
    cl.ellipsoid(bm, (0, 0.10, BODY_Z + 0.01), (0.060, 0.050, 0.070), 18, 10)
    reg(new_object("Pup_Chest", bm, M["creme"]), "single", "chest")
    # patas creme
    bm = bmesh.new()
    for name, (x, y) in LEGS.items():
        cl.ellipsoid(bm, (x, y + 0.015, 0.022), (0.038, 0.050, 0.024), 14, 8)
    paws = new_object("Pup_Paws", bm, M["creme"])
    reg(paws, "dist")
    # cabeca grande + focinho (mesmo objeto, para o rosto ancorar a boca no focinho)
    bm = bmesh.new()
    cl.ellipsoid(bm, HC, HR, 28, 18)
    n_fur = len(bm.faces)
    cl.ellipsoid(bm, (0, HC.y + 0.088, HC.z - 0.048), (0.060, 0.052, 0.044), 18, 10)          # focinho creme
    cl.ellipsoid(bm, (0.050, HC.y + 0.062, HC.z + 0.016), (0.044, 0.050, 0.048), 16, 8)     # mancha creme no olho direito
    bm.faces.ensure_lookup_table()
    for i, f in enumerate(bm.faces):
        f.material_index = 0 if i < n_fur else 1
    head = new_object("Pup_Head", bm, M["pelo"])
    head.data.materials.append(M["creme"])
    reg(head, "single", "head")
    bm = bmesh.new()
    cl.ellipsoid(bm, (0, HC.y + 0.142, HC.z - 0.030), (0.022, 0.016, 0.016), 14, 8)
    reg(new_object("Pup_Nose", bm, M["nariz"]), "single", "head")
    # orelhas caidas
    for s, sx in (("L", -1), ("R", 1)):
        bm = bmesh.new()
        cl.ellipsoid(bm, (0, 0, 0), (0.030, 0.016, 0.062), 14, 8)
        cl.transform_bm(bm, Matrix.Translation((sx * 0.112, HC.y - 0.005, HC.z + 0.005)) @ cl.Matrix.Rotation(math.radians(-sx * 18), 4, "Y"))
        reg(new_object("Pup_Ear" + s, bm, M["orelha"]), "single", "ear." + s)
    # rabo
    bm = bmesh.new()
    # RB-R1 (arte das cenas): o rabo comeca DENTRO da garupa (antes ficava 7 cm solto do corpo, visivel de lado)
    cl.tube(bm, [(0, -0.09, BODY_Z + 0.0), (0, -0.13, BODY_Z + 0.02), (0, -0.15, BODY_Z + 0.03), (0, -0.20, BODY_Z + 0.08),
                 (0, -0.22, BODY_Z + 0.14), (0, -0.21, BODY_Z + 0.19)],
            [0.034, 0.028, 0.024, 0.022, 0.019, 0.012], 10, True)
    cl.ellipsoid(bm, (0, -0.21, BODY_Z + 0.195), (0.018, 0.018, 0.022), 10, 6)
    tail = new_object("Pup_Tail", bm, M["pelo"])
    reg(tail, "tail")
    # coleira com pingente-emblema
    bm = bmesh.new()
    cl.torus_z(bm, 0.052, 0.012, 0.0, sy=1.0, major=24, minor=6)
    cl.transform_bm(bm, Matrix.Translation((0, 0.13, 0.29)) @ cl.Matrix.Rotation(math.radians(-35), 4, "X"))
    reg(new_object("Pup_Collar", bm, M["coleira"]), "single", "neck")
    bm = bmesh.new()
    hero_lib.prism(bm, hero_lib.emblem_outline(0.040, 0.046), 0.006, (0, 0, 0))
    cl.transform_bm(bm, Matrix.Translation((0, 0.188, 0.245)) @ cl.Matrix.Rotation(math.radians(-15), 4, "X"))
    reg(new_object("Pup_Tag", bm, M["emblema"]), "single", "neck")
    bm = bmesh.new()
    hero_lib.prism(bm, hero_lib.star4(0.014, 0.005), 0.004, (0, 0.006, 0.002))
    cl.transform_bm(bm, Matrix.Translation((0, 0.188, 0.245)) @ cl.Matrix.Rotation(math.radians(-15), 4, "X"))
    reg(new_object("Pup_TagStar", bm, M["ouro"]), "single", "neck")
    # rosto (olhos enormes, dois brilhos, boca no focinho)
    face, info = hero_face.build_face(None, "Pup_Face", dict(eye=M["olhos"], iris=M["iris"], dark=M["escuro"], skin=M["pelo"], mouth=M["boca"]),
                                      head, HC, k=0.62, eye_x=0.078, eye_z=HC.z + 0.020, eye_size=1.25, mouth_z=HC.z - 0.085, brow_w=0.8)
    rig = None
    if with_rig:
        arm = bpy.data.armatures.new("Pup_Armature")
        rig = bpy.data.objects.new("Pup", arm)
        bpy.context.scene.collection.objects.link(rig)
        bpy.context.view_layer.objects.active = rig
        bpy.ops.object.mode_set(mode="EDIT")
        for (n, h, t, p, d) in bones():
            b = arm.edit_bones.new(n)
            b.head, b.tail, b.use_deform = Vector(h), Vector(t), d
            if p:
                b.parent = arm.edit_bones[p]
        bpy.ops.object.mode_set(mode="OBJECT")
        rig["provisional"] = True
        for ob, mode, bone in objs:
            if mode == "single":
                cl.bind_to_rig(ob, rig, single_bone=bone)
            else:
                # rabo so nos ossos do rabo e no quadril (antes pegava peso das coxas e descolava no andar/correr)
                pup_weights(ob, rig, only=("hips", "tail1", "tail2", "tail3") if mode == "tail" else None)
                cl.smooth_weights(ob, 2, 0.5)
        cl.bind_to_rig(face, rig, single_bone="head")
    return type("Pup", (), dict(objs=[o for o, _, _ in objs] + [face], face_ob=face, rig=rig, head_ob=head, eye_info=info))


def pup_weights(ob, rig, power=6.0, only=None):
    for g in list(ob.vertex_groups):
        ob.vertex_groups.remove(g)
    bs = [b for b in rig.data.bones if b.use_deform and not b.name.startswith("ear") and (only is None or b.name in only)]
    groups = {b.name: ob.vertex_groups.new(name=b.name) for b in rig.data.bones if b.use_deform}
    segs = [(b.name, Vector(b.head_local), Vector(b.tail_local), RAD.get(b.name.split(".")[0], 0.04)) for b in bs]
    for v in ob.data.vertices:
        p = v.co
        ws = []
        for n, h, t, r in segs:
            d = t - h
            u = max(0.0, min(1.0, (p - h).dot(d) / max(d.length_squared, 1e-9)))
            ws.append((n, 1.0 / (((p - (h + d * u)).length / r) ** power + 1e-4)))
        ws.sort(key=lambda a: -a[1])
        ws = ws[:3]
        tot = sum(w for _, w in ws)
        for n, w in ws:
            if w / tot > 0.02:
                groups[n].add([v.index], w / tot, "REPLACE")
    m = ob.modifiers.new("Armature", "ARMATURE")
    m.object = rig
    ob.parent = rig


# ------------------------------------------------------------------ animacoes (FK)
def smooth(t, a, b):
    u = max(0.0, min(1.0, (t - a) / (b - a)))
    return u * u * (3 - 2 * u)


def legs_down(R, lift=0.0, bend=0.0):
    for name in LEGS:
        pre, s = name[:2], name[-1]
        R.rel(pre + "_upper." + s, eul(x=-bend if pre == "fl" else bend))
        R.rel(pre + "_lower." + s, eul(x=bend * 1.6 if pre == "fl" else -bend * 1.6))
        R.rel(pre + "_paw." + s, eul())


def tail(R, t, speed, amp, up=0.0):
    w = math.sin(2 * math.pi * speed * t) * amp
    R.rel("tail1", eul(x=up, z=w * 0.6))
    R.rel("tail2", eul(z=w))
    R.rel("tail3", eul(z=w * 1.2))


def blink(t, at):
    u = (t - at) / 0.16
    return math.sin(u * math.pi) ** 0.7 if 0 <= u <= 1 else 0.0


def clip_idle(R, t, T):
    br = math.sin(2 * math.pi * t / T)
    R.hips_off = Vector((0, 0, 0.003 * br))
    R.rel("chest", eul(x=2 * br))
    R.rel("head", eul(y=12 * smooth(t, 0.8, 1.3) * (1 - smooth(t, 2.0, 2.5)), x=-3 * br))
    R.rel("ear.L", eul(y=6 * br))
    R.rel("ear.R", eul(y=-6 * br))
    legs_down(R)
    tail(R, t, 0.8, 18)
    return {"blink": blink(t, 1.6), "alegre": 0.0}


def clip_wag(R, t, T):
    e = smooth(t, 0.0, 0.2) * (1 - smooth(t, T - 0.2, T))
    w = math.sin(2 * math.pi * 3.0 * t)
    R.rel("hips", eul(z=8 * w * e))
    R.rel("chest", eul(z=-5 * w * e))
    R.rel("head", eul(y=6 * w * e, x=-6 * e))
    legs_down(R)
    tail(R, t, 3.0, 40 * e, up=-15 * e)
    return {"alegre": e, "blink": 0.0}


def clip_jump(R, t, T):
    pre = smooth(t, 0.0, 0.15) * (1 - smooth(t, 0.15, 0.25))
    air = math.sin(math.pi * min(max((t - 0.22) / 0.40, 0.0), 1.0))
    land = math.sin(math.pi * min(max((t - 0.62) / 0.25, 0.0), 1.0))
    R.hips_off = Vector((0, 0, -0.03 * pre - 0.02 * land + 0.16 * air))
    R.rel("chest", eul(x=-8 * pre + 10 * air))
    R.rel("head", eul(x=15 * air))
    legs_down(R, bend=25 * pre + 30 * air + 15 * land)
    tail(R, t, 3.0, 30, up=-20 * air)
    return {"alegre": smooth(t, 0.1, 0.3), "blink": 0.0}


def clip_bark(R, t, T):
    b1 = math.sin(math.pi * min(max((t - 0.10) / 0.20, 0.0), 1.0))
    b2 = math.sin(math.pi * min(max((t - 0.45) / 0.20, 0.0), 1.0))
    b = max(b1, b2)
    R.rel("chest", eul(x=4 * b))
    R.rel("neck", eul(x=-10 * b))
    R.rel("head", eul(x=18 * b))
    R.hips_off = Vector((0, -0.01 * b, 0))
    legs_down(R)
    tail(R, t, 2.0, 25)
    return {"mouth_A": b, "surpresa": 0.0, "alegre": 0.3, "blink": 0.0}


def clip_horn(R, t, T):
    """Pisa na buzina: a pata dianteira direita sobe e pressiona para baixo e para a frente (~0,55 s), com susto feliz."""
    up = smooth(t, 0.1, 0.35) * (1 - smooth(t, 0.45, 0.6))
    press = smooth(t, 0.45, 0.6) * (1 - smooth(t, 0.9, 1.2))
    legs_down(R)
    R.rel("fl_upper.R", eul(x=-75 * up - 20 * press))
    R.rel("fl_lower.R", eul(x=85 * up))
    R.rel("chest", eul(x=6 * up - 4 * press))
    R.rel("head", eul(x=10 * press, y=-8 * press))
    tail(R, t, 2.5, 30 * press + 10)
    return {"surpresa": press, "alegre": smooth(t, 1.0, 1.3), "blink": 0.0}


# ------------------------------------------------------------------ andar e correr (RB-R1 arte das cenas, PROVISORIO)
# IK de 2 ossos por pata (upper + lower; o osso da pata fica na pose de repouso, sola rente ao chao). No apoio a pata recua
# em linha reta na velocidade do corpo (sem deslizar no chao); no balanco volta para a frente num arco. Sem root motion:
# a velocidade nominal (m/s) e a do apoio, curso / (fator de carga * ciclo), e vai para o .tscn (walk_speed_mps/run_speed_mps).
ANKLE_Z = 0.03      # altura do tornozelo (cabeca do osso da pata) com a sola no chao
GAITS = {
    # walk: passo lateral, 3 ciclos em 1,0 s (o clipe walk de todo o elenco tem 1,0 s; testes) (PT, PD, PT oposta, PD oposta), sempre 2-3 patas no chao
    "walk": dict(T=1.0 / 3.0, duty=0.58, stride=0.11, lift=0.035, drop=0.016, bob=0.006, pitch=2.0,
                 phase={"bl.L": 0.0, "fl.L": 0.25, "bl.R": 0.5, "fl.R": 0.75}, center={"fl": 0.012, "bl": -0.004}),
    # run: meio-galope (traseiras juntas, dianteiras juntas, fase aerea curta), corpo ondula
    "run": dict(T=0.30, duty=0.34, stride=0.13, lift=0.050, drop=0.026, bob=0.016, pitch=7.0,
                phase={"bl.L": 0.0, "bl.R": 0.07, "fl.L": 0.48, "fl.R": 0.56}, center={"fl": 0.020, "bl": -0.010}),
}


def gait_speed(name):
    g = GAITS[name]
    return g["stride"] / (g["duty"] * g["T"])


def paw_target(g, leg, t):
    """(dy, dz) do tornozelo em relacao a posicao de repouso, no tempo t do ciclo."""
    u = ((t / g["T"]) - g["phase"][leg]) % 1.0
    S, duty = g["stride"], g["duty"]
    c = g["center"][leg[:2]]
    if u < duty:                                  # apoio: recua de +S/2 a -S/2 em velocidade constante
        return c + S * (0.5 - u / duty), 0.0, 0.0
    w = (u - duty) / (1.0 - duty)                 # balanco: volta num arco, sobe cedo e pousa suave
    e = w * w * (3 - 2 * w)
    arc = math.sin(math.pi * w) ** 0.8
    return c + S * (-0.5 + e), g["lift"] * arc, arc


def gait_pose(R, t, name):
    g = GAITS[name]
    T = g["T"]
    ph = 2 * math.pi * t / T
    run = name == "run"
    # corpo: abaixa um pouco (pernas dobradas), quica 2x por ciclo no andar e 1x no galope, ondula a coluna no galope
    bob = math.cos(2 * ph) if not run else math.cos(ph - 0.6)
    R.hips_off = Vector((0.0, 0.0, -g["drop"] + g["bob"] * bob))
    flex = math.sin(ph - 0.3) * g["pitch"]
    R.rel("hips", eul(x=-flex * 0.6 if run else 0.0, z=(0.0 if run else 3.0 * math.sin(ph))))
    R.rel("spine", eul(x=flex * 0.5 if run else 0.0))
    R.rel("chest", eul(x=(flex * 0.6 if run else g["pitch"] * 0.5 * math.sin(2 * ph)), z=(0.0 if run else -2.5 * math.sin(ph))))
    R.rel("neck", eul(x=(-6.0 if run else -2.0) - flex * 0.5))
    R.rel("head", eul(x=(8.0 if run else 2.0) + 3.0 * math.sin(2 * ph + 0.8), y=(0.0 if run else 3.0 * math.sin(ph))))
    ear = (18.0 + 14.0 * math.sin(ph + 1.2)) if run else 6.0 * math.sin(2 * ph + 1.0)
    R.rel("ear.L", eul(x=-ear * 0.6 if run else 0.0, y=ear))
    R.rel("ear.R", eul(x=-ear * 0.6 if run else 0.0, y=-ear))
    if run:
        R.rel("tail1", eul(x=12.0 + 8.0 * math.sin(ph), z=0.0))
        R.rel("tail2", eul(x=-14.0, z=8.0 * math.sin(ph)))
        R.rel("tail3", eul(z=10.0 * math.sin(ph)))
    else:
        tail(R, t, 2.5, 16, up=10.0)
    # patas
    for leg in LEGS:
        pre, s = leg[:2], leg[-1]
        rest = R.rest_tail[pre + "_lower." + s]
        dy, dz, arc = paw_target(g, leg, t)
        target = Vector((rest.x, rest.y + dy, ANKLE_Z + dz))
        R.solve2(pre + "_upper." + s, pre + "_lower." + s, None, target, (0.0, -1.0, 0.0) if pre == "fl" else (0.0, 1.0, 0.0))
        # no balanco a pata dobra (dianteira para tras, traseira estica); no apoio fica na pose de repouso (sola no chao)
        R.absolute[pre + "_paw." + s] = eul(x=(-35.0 if pre == "fl" else 25.0) * arc)
    R.evaluate()


def clip_walk(R, t, T):
    gait_pose(R, t, "walk")
    return {"alegre": 0.35, "blink": blink(t, 0.62)}


def clip_run(R, t, T):
    gait_pose(R, t, "run")
    return {"alegre": 0.7, "mouth_A": 0.35 + 0.15 * math.sin(2 * math.pi * t / T), "blink": 0.0}


CLIPS = {"idle": (2.8, True, clip_idle), "wag": (1.2, True, clip_wag), "jump_happy": (1.0, False, clip_jump),
         "bark": (0.8, False, clip_bark), "step_on_horn": (1.4, False, clip_horn),
         "walk": (GAITS["walk"]["T"] * 3, True, clip_walk), "run": (GAITS["run"]["T"] * 2, True, clip_run)}
KEYS = ("blink", "alegre", "surpresa", "mouth_A")


def author(rig, face):
    R = cl.Rigger(rig)
    sk = face.data.shape_keys
    sk.animation_data_create()
    rig.animation_data_create()
    for name, (dur, loop, fn) in CLIPS.items():
        act = bpy.data.actions.new(name)
        act.use_fake_user = True
        ka = bpy.data.actions.new(name + "_key")
        ka.use_fake_user = True
        rig.animation_data.action = act
        sk.animation_data.action = ka
        n = int(round(dur * 30))
        prev = {}
        for i in range(n + 1):
            t = dur * i / n
            R.reset()
            fc = fn(R, t, dur)
            R.apply(i, prev)
            for k in KEYS:
                kb = sk.key_blocks[k]
                kb.value = max(0.0, min(1.0, fc.get(k, 0.0)))
                kb.keyframe_insert("value", frame=i)
        act["loop"] = loop
        for ad, a_ in ((rig.animation_data, act), (sk.animation_data, ka)):
            ad.action = None
            tr = ad.nla_tracks.new()
            tr.name = name
            st = tr.strips.new(name, 0, a_)
            st.name = name


def main():
    sc = reset_scene()
    sc.render.fps = 30
    p = build_pup(True)
    author(p.rig, p.face_ob)
    bpy.context.view_layer.update()
    lo, hi = world_bbox(p.objs)
    acts = {a.name: [round(a.frame_range[0]), round(a.frame_range[1])] for a in bpy.data.actions if not a.name.endswith("_key")}
    info = {"tris": tri_count(p.objs), "materials": sorted({m.name for o in p.objs for m in o.data.materials if m}),
            "height_m": round(hi.z - lo.z, 4), "min_z": round(lo.z, 4), "objects": sorted(o.name for o in p.objs),
            "bones": [b.name for b in p.rig.data.bones], "bone_count": len(p.rig.data.bones), "animations": acts,
            "shape_keys": [k.name for k in p.face_ob.data.shape_keys.key_blocks], "head_ratio": 0.0, "walk_speed_mps": round(gait_speed("walk"), 4),
            "run_speed_mps": round(gait_speed("run"), 4), "variant": "pup"}
    print("CHAR_INFO", json.dumps(info))
    blend = arg_value("--blend")
    if blend:
        os.makedirs(os.path.dirname(blend), exist_ok=True)
        bpy.ops.wm.save_as_mainfile(filepath=blend)
        with open(os.path.splitext(blend)[0] + ".info.json", "w", encoding="utf-8") as f:
            json.dump(info, f, indent=2)
    glb = arg_value("--glb")
    if glb:
        bpy.ops.export_scene.gltf(filepath=glb, export_format="GLB", use_selection=False, export_yup=True, export_apply=False,
                                  export_morph=True, export_materials="EXPORT", export_cameras=False, export_lights=False,
                                  export_extras=True, export_skins=True, export_animations=True, export_animation_mode="NLA_TRACKS",
                                  export_force_sampling=True, export_frame_range=False, export_optimize_animation_size=False,
                                  export_def_bones=False)


if __name__ == "__main__":
    main()
