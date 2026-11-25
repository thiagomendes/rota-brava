"""Rastro v2.1: folga entre as duas botas (bota + sola + aro) em TODOS os quadros de TODOS os clipes.
Distancia ponto-superficie com BVH nas malhas AVALIADAS (armature + shape keys), nos dois sentidos, e teste de
interseccao (overlap) entre as duas. Imprime o minimo por clipe e o minimo global (clipe/quadro).

Uso: bash tools/blender.sh --background source_art/characters/rastro_v2/rastro_v2.blend \
        --python source_art/characters/rastro_v2/measure_feet.py -- [saida.json]
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import bpy
import numpy as np
from mathutils.bvhtree import BVHTree

import rv2_tex

sc = bpy.context.scene
rig = next(o for o in sc.objects if o.type == "ARMATURE")
gear = next(o for o in sc.objects if o.name.endswith("_Gear"))
face = next(o for o in sc.objects if o.name.endswith("_Face"))
me = gear.data
part = np.empty(len(me.vertices), dtype=np.float32)
me.attributes["rbpart"].data.foreach_get("value", part)
pid = np.rint(part * 100).astype(int)
rest = np.empty(len(me.vertices) * 3)
me.vertices.foreach_get("co", rest)
rest = rest.reshape(-1, 3)
feet = np.isin(pid, [rv2_tex.PID[n] for n in ("boot", "sole", "boot_top")])
side = {s: np.where(feet & (np.sign(rest[:, 0]) == sx))[0] for s, sx in (("R", 1), ("L", -1))}
polys = {}
for s, idx in side.items():
    sset = set(idx.tolist())
    polys[s] = [list(p.vertices) for p in me.polygons if all(v in sset for v in p.vertices)]


def clips():
    return sorted(tr.name for tr in rig.animation_data.nla_tracks)


def set_clip(name, frame):
    for ob_ad in (rig.animation_data, face.data.shape_keys.animation_data,
                  gear.data.shape_keys.animation_data if gear.data.shape_keys else None):
        if ob_ad is None:
            continue
        for tr in ob_ad.nla_tracks:
            tr.mute = True
    rig.animation_data.action = bpy.data.actions[name]
    if gear.data.shape_keys and bpy.data.actions.get(name + "_gear"):
        gear.data.shape_keys.animation_data.action = bpy.data.actions[name + "_gear"]
    sc.frame_set(frame)


def gap_now():
    dg = bpy.context.evaluated_depsgraph_get()
    ev = gear.evaluated_get(dg)
    m = ev.to_mesh()
    co = np.empty(len(m.vertices) * 3)
    m.vertices.foreach_get("co", co)
    ev.to_mesh_clear()
    co = co.reshape(-1, 3)
    mw = np.array(gear.matrix_world)
    co = co @ mw[:3, :3].T + mw[:3, 3]
    verts = [tuple(v) for v in co]
    tR = BVHTree.FromPolygons(verts, polys["R"])
    tL = BVHTree.FromPolygons(verts, polys["L"])
    if tR.overlap(tL):
        return 0.0, True
    best = 9.0
    for a, tree in (("R", tL), ("L", tR)):
        for i in side[a][::1]:
            hit = tree.find_nearest(verts[i])
            if hit[0] is not None:
                best = min(best, hit[3])
    return best, False


out = {"por_clipe": {}}
glob = (9.0, None, None)
for name in clips():
    act = bpy.data.actions[name]
    f0, f1 = int(act.frame_range[0]), int(act.frame_range[1])
    cmin = (9.0, None)
    inter = 0
    for fr in range(f0, f1 + 1):
        set_clip(name, fr)
        g, hit = gap_now()
        inter += int(hit)
        if g < cmin[0]:
            cmin = (g, fr)
    out["por_clipe"][name] = {"min_m": round(cmin[0], 4), "quadro": cmin[1], "quadros": f1 - f0 + 1, "interseccoes": inter}
    print("FOLGA %-15s min=%.4f m quadro=%s (de %d) interseccoes=%d" % (name, cmin[0], cmin[1], f1 - f0 + 1, inter))
    if cmin[0] < glob[0]:
        glob = (cmin[0], name, cmin[1])
out["min_global_m"] = round(glob[0], 4)
out["clipe"] = glob[1]
out["quadro"] = glob[2]
print("FOLGA_MIN_GLOBAL %.4f m em %s quadro %s" % glob)
args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
if args:
    with open(args[0], "w", encoding="utf-8") as f:
        json.dump(out, f, indent=2)
