"""Pico v2 (RB-R1 D11/D13): constroi o heroi escalador do zero, texturas assadas, PBR padrao do glTF, rig de 28 ossos,
rosto com expressoes/visemas/olhar, 11 clipes (mesmos nomes do pico.glb), .blend e GLB (metros, +Y up).
PROPOSTA PROVISORIA, lado a lado: NAO substitui o Pico do jogo (game/assets/models/characters/pico.glb).

Uso (Linux):
  bash tools/blender.sh --background --factory-startup --python source_art/characters/pico_v2/build_pico_v2.py -- \
      [--glb $PWD/game/assets/models/characters/pico_v2.glb] [--blend $PWD/source_art/characters/pico_v2/pico_v2.blend] [--no-tex]
"""
import json
import os
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPTS = os.path.abspath(os.path.join(HERE, "..", "..", "scripts"))
for p in (HERE, SCRIPTS):
    if p not in sys.path:
        sys.path.insert(0, p)

import bpy

import pv2_anim
import pv2_body
import pv2_tex
from rbart import REPO, arg_value, reset_scene, tri_count, world_bbox

TEX_DIR = os.path.join(REPO, "captures", "pico_v2", "build_textures")   # intermediario (fora do Git); o .blend empacota


def finish_materials(groups, b):
    T = pv2_tex
    for g in ("suit", "gear", "skin", "hair"):
        ob = groups[g]
        m = T.texture_group(ob, g, T.TEX_RES[g], b, TEX_DIR)
        ob.data.materials.clear()
        ob.data.materials.append(m)
    lens = T.factor_material("mat_pico_v2_lamp", "#FFF3B8", 0.12, coat=1.0, coat_rough=0.05, emission=2.4)
    groups["screen"].data.materials.clear()
    groups["screen"].data.materials.append(lens)
    face = groups["face"]
    fm = [T.factor_material("mat_pico_v2_face_eye", "#FFFFFF", 0.18, coat=0.8, coat_rough=0.06, emission=0.08),
          T.factor_material("mat_pico_v2_face_iris", "#2F7FC9", 0.14, coat=1.0, coat_rough=0.04),
          T.factor_material("mat_pico_v2_face_dark", "#2A160E", 0.25, coat=0.6, coat_rough=0.1),
          T.factor_material("mat_pico_v2_face_skin", T.C["skin"], 0.5, coat=0.3, coat_rough=0.35),
          T.factor_material("mat_pico_v2_face_mouth", "#A63A3F", 0.35, coat=0.4, coat_rough=0.2)]
    for i, m in enumerate(fm):          # por indice: materials.clear() zera o indice de material das faces
        face.data.materials[i] = m
    for img in list(bpy.data.images):
        if img.name.startswith("pico_v2_"):
            img.pack()


def measure(b, groups, rig):
    objs = list(groups.values())
    lo, hi = world_bbox(objs)
    head = groups["skin"]
    # altura da cabeca: do queixo ao topo do cranio (elipsoide da cabeca; a parte de cima esta dentro do capacete)
    hz = [v.co.z for v in head.data.vertices if v.co.z > b.F.chin - 0.01]
    head_top = b.F.hc.z + b.F.hr[2]
    head_h = head_top - min(hz)
    acts = {a.name: [round(a.frame_range[0]), round(a.frame_range[1])] for a in bpy.data.actions if not a.name.endswith("_key")}
    return {"tris": tri_count(objs), "tris_por_objeto": {o.name: tri_count([o]) for o in objs},
            "materials": sorted({m.name for o in objs for m in o.data.materials if m}),
            "height_m": round(hi.z - lo.z, 4), "min_z": round(lo.z, 4), "head_h_m": round(head_h, 4),
            "head_ratio": round(head_h / (hi.z - lo.z), 4),
            "head_with_helmet_ratio": round((hi.z - min(hz)) / (hi.z - lo.z), 4),
            "eye_h_ratio": round(b.eye_info["R"]["ez"] * 2 / head_h, 4),
            "hip_x_m": b.F.hip_x,
            "objects": sorted(o.name for o in objs), "bones": [bb.name for bb in rig.data.bones], "bone_count": len(rig.data.bones),
            "animations": acts, "shape_keys": [k.name for k in groups["face"].data.shape_keys.key_blocks],
            "walk_speed_mps": round(pv2_anim.ha.walk_speed(b.F), 4), "run_speed_mps": round(pv2_anim.ha.run_speed(b.F), 4),
            "texturas": {img.name: list(img.size) for img in bpy.data.images if img.name.startswith("pico_v2_")}}


def export_glb(path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    kw = dict(filepath=path, export_format="GLB", use_selection=False, export_yup=True, export_apply=False, export_morph=True,
              export_materials="EXPORT", export_cameras=False, export_lights=False, export_extras=False, export_skins=True,
              export_animations=True, export_animation_mode="NLA_TRACKS", export_force_sampling=True, export_frame_range=False,
              export_optimize_animation_size=False, export_def_bones=False, export_image_format="JPEG", export_tangents=False)
    try:
        bpy.ops.export_scene.gltf(export_image_quality=90, **kw)
    except TypeError:
        bpy.ops.export_scene.gltf(**kw)


def build(glb=None, blend=None, textures=True):
    t0 = time.time()
    sc = reset_scene()
    sc.render.fps = pv2_anim.FPS
    b = pv2_body.build()
    rig = b.rig
    rig["provisional"] = True
    rig["agent"] = "art3d"
    rig["variant"] = "pico_v2"
    for o in b.objs:
        print("PARTE", o.name, tri_count([o]))
    groups = pv2_tex.join_groups(b.objs, prefix="Pico")
    print("JOIN", {g: o.name for g, o in groups.items()}, round(time.time() - t0, 1))
    if textures:
        finish_materials(groups, b)
    print("MATERIAIS ok", round(time.time() - t0, 1))
    pv2_anim.author(rig, groups["face"], b.F)
    bpy.context.view_layer.update()
    info = measure(b, groups, rig)
    print("CHAR_INFO", json.dumps(info))
    if blend:
        os.makedirs(os.path.dirname(blend), exist_ok=True)
        bpy.ops.wm.save_as_mainfile(filepath=blend, compress=True)
        with open(os.path.splitext(blend)[0] + ".info.json", "w", encoding="utf-8") as f:
            json.dump(info, f, indent=2)
    if glb:
        export_glb(glb)
        print("GLB", glb, os.path.getsize(glb))
    print("TOTAL s", round(time.time() - t0, 1))
    return b, groups, info


if __name__ == "__main__":
    build(arg_value("--glb"), arg_value("--blend"), "--no-tex" not in sys.argv)
