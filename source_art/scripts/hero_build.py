"""Rastro final do RB-R1 (variacao recomendada A "brinquedo brilhante"): malha, rig (28 ossos + ponteiras do RB-04),
pesos, rosto com expressoes/visemas/olhar, 12 animacoes, .blend e GLB (metros, +Y up). PROVISORIO ate o Portao 1.

Uso: tools/blender.ps1 --background --factory-startup --python source_art/scripts/hero_build.py -- --id rastro
        [--variant A] [--blend X.blend] [--glb Y.glb]
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
from mathutils import Vector

import hero_anim
import hero_lib
from rbart import REPO, arg_value, reset_scene, tri_count, world_bbox

FINAL_VARIANT = "A"


def build(cid, variant, blend_path=None, glb_path=None):
    sc = reset_scene()
    sc.render.fps = hero_anim.FPS
    b = hero_lib.build_hero(cid, variant, with_rig=True)
    rig = b.rig
    rig["provisional"] = True
    rig["agent"] = "art3d"
    rig["variant"] = variant
    rep = hero_anim.author(rig, b.face_ob, b.F)
    bpy.context.view_layer.update()
    objs = b.objs
    lo, hi = world_bbox(objs)
    head = b.head_ob
    hz = [(head.matrix_world @ Vector(c)).z for c in head.bound_box]
    acts = {a.name: [round(a.frame_range[0]), round(a.frame_range[1])] for a in bpy.data.actions if not a.name.endswith("_key")}
    info = {"tris": tri_count(objs), "materials": sorted({m.name for o in objs for m in o.data.materials if m}),
            "height_m": round(hi.z - lo.z, 4), "min_z": round(lo.z, 4), "head_h_m": round(max(hz) - min(hz), 4),
            "head_ratio": round((max(hz) - min(hz)) / (hi.z - lo.z), 4),
            "eye_h_ratio": round(b.eye_info["R"]["ez"] * 2 / (max(hz) - min(hz)), 4),
            "objects": sorted(o.name for o in objs), "tris_por_objeto": {o.name: tri_count([o]) for o in objs},
            "bones": [bb.name for bb in rig.data.bones], "bone_count": len(rig.data.bones), "animations": acts,
            "shape_keys": [k.name for k in b.face_ob.data.shape_keys.key_blocks],
            "walk_speed_mps": round(hero_anim.walk_speed(), 4), "run_speed_mps": round(hero_anim.run_speed(), 4),
            "variant": variant}
    info.update(rep)
    print("CHAR_INFO", json.dumps(info))
    if blend_path:
        os.makedirs(os.path.dirname(blend_path), exist_ok=True)
        bpy.ops.wm.save_as_mainfile(filepath=blend_path)
        with open(os.path.splitext(blend_path)[0] + ".info.json", "w", encoding="utf-8") as f:
            json.dump(info, f, indent=2)
    if glb_path:
        os.makedirs(os.path.dirname(glb_path), exist_ok=True)
        bpy.ops.export_scene.gltf(filepath=glb_path, export_format="GLB", use_selection=False, export_yup=True,
                                  export_apply=False, export_morph=True, export_materials="EXPORT", export_cameras=False,
                                  export_lights=False, export_extras=True, export_skins=True, export_animations=True,
                                  export_animation_mode="NLA_TRACKS", export_force_sampling=True, export_frame_range=False,
                                  export_optimize_animation_size=False, export_def_bones=False)
    return b


if __name__ == "__main__":
    cid = arg_value("--id", "rastro")
    var = arg_value("--variant", FINAL_VARIANT)
    blend = arg_value("--blend", os.path.join(REPO, "source_art", "characters", "heroes", cid, cid + ".blend"))
    build(cid, var, blend, arg_value("--glb"))
