"""Pico v2.2: prova de LEITURA de frente na distancia da camera baixa da vitrine (heroi a ~4,1 m, camera ~20 graus acima,
campo vertical recortado do FOV 50 da Godot: o heroi fica com ~265 px de altura, como num quadro 1600x900 do jogo).
Prancha 1: 8 quadros do idle ao longo do ciclo (de frente) + 4 de tres-quartos. Prancha 2: team_pose, celebrate, wave e
jump de frente. Saida em captures/ (fora do Git). PROVISORIO.

Uso: bash tools/blender.sh --background source_art/characters/pico_v2/pico_v2.blend \
        --python source_art/characters/pico_v2/render_pico_leitura.py -- $PWD/captures/pico_idle
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

import pv2_render as RR

OUT = os.path.abspath(sys.argv[sys.argv.index("--") + 1])
os.makedirs(OUT, exist_ok=True)
sc = bpy.context.scene
rig = next(o for o in sc.objects if o.type == "ARMATURE")
meshes = [o for o in sc.objects if o.type == "MESH"]
face = next(o for o in meshes if o.name.endswith("_Face"))
gear = next(o for o in meshes if o.name.endswith("_Gear"))


def set_clip(name, frame):
    ads = [rig.animation_data, face.data.shape_keys.animation_data]
    gk = gear.data.shape_keys
    if gk is not None and gk.animation_data is not None:
        ads.append(gk.animation_data)
    for ad in ads:
        for tr in ad.nla_tracks:
            tr.mute = True
    rig.animation_data.action = bpy.data.actions[name]
    face.data.shape_keys.animation_data.action = bpy.data.actions[name + "_key"]
    if len(ads) == 3:
        ads[2].action = bpy.data.actions.get(name + "_gear")
    sc.frame_set(frame)


RR.scene_lights(sc)
cam = RR.camera(sc, (0, 0, 0.55), 4.1, 20.0, 0, 50)
cam.data.sensor_fit = "VERTICAL"
W, H = 300, 380
cam.data.angle_y = math.radians(50.0 * H / 900.0)
RR.cycles(sc, W, H, 40)


def shot(name, fr, az, tag):
    set_clip(name, fr)
    RR.place(cam, (0, 0, 0.55), 4.1, 20.0, az)
    return RR.render(sc, os.path.join(OUT, "q_%s_%s_%03d.png" % (tag, name, fr)))


idle = [shot("idle", f, 0, "frente") for f in range(0, 120, 15)]
idle34 = [shot("idle", f, -35, "tres_quartos") for f in (15, 55, 62, 100)]
RR.compose([idle[:4], idle[4:], idle34], os.path.join(OUT, "pico_idle_frente_camera_baixa.png"))
others = [("team_pose", 15), ("team_pose", 30), ("team_pose", 35), ("celebrate", 9), ("celebrate", 14),
          ("celebrate", 27), ("wave", 24), ("wave", 36), ("jump", 6), ("jump", 14)]
op = [shot(n, f, 0, "frente") for n, f in others]
RR.compose([op[:5], op[5:]], os.path.join(OUT, "pico_poses_frente_camera_baixa.png"))
print("LEITURA OK", OUT)
