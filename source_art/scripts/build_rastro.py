"""Gera o corpo-base PROVISORIO do Rastro (rastreadora) em escala final (metros), sem rig.

Origem nos pes; frente em +Y no Blender = -Z na Godot (glTF +Y up). Parametros: source_art/params/rastro.json.
Uso: tools/blender.ps1 --background --factory-startup --python source_art/scripts/build_rastro.py -- --blend X.blend --glb Y.glb
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
from rbart import REPO, arg_value, reset_scene, tri_count, world_bbox
import rbchars


def main():
    params = json.load(open(os.path.join(REPO, "source_art", "params", "rastro.json"), encoding="utf-8"))
    sc = reset_scene()
    ch = rbchars.build("tracker", params["candidate"], prefix="Rastro", display="Rastro",
                       hat_height=params["hat_height"], scale=params["scale"])
    rbchars.add_face(ch, "Face")
    ch.root["provisional"] = True
    ch.root["agent"] = "art3d"
    bpy.context.view_layer.update()
    lo, hi = world_bbox(ch.objs)
    mats = sorted({m.name for o in ch.objs for m in o.data.materials})
    info = {"tris": tri_count(ch.objs), "materials": mats, "height_m": round(hi.z - lo.z, 4),
            "min_z": round(lo.z, 4), "objects": sorted(o.name for o in ch.objs)}
    print("RASTRO_INFO", json.dumps(info))
    blend = arg_value("--blend", os.path.join(REPO, "source_art", "characters", "rastro", "rastro.blend"))
    os.makedirs(os.path.dirname(blend), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=blend)
    glb = arg_value("--glb")
    if glb:
        os.makedirs(os.path.dirname(glb), exist_ok=True)
        bpy.ops.export_scene.gltf(filepath=glb, export_format="GLB", use_selection=False, export_yup=True,
                                  export_apply=False, export_morph=True, export_materials="EXPORT",
                                  export_cameras=False, export_lights=False, export_extras=True)
    with open(os.path.splitext(blend)[0] + ".info.json", "w", encoding="utf-8") as f:
        json.dump(info, f, indent=2)


main()
