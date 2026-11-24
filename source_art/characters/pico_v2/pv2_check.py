"""Pico v2: medicoes de animacao a partir do .blend (criterio de Thiago: as botas NUNCA se tocam).

Para cada clipe e cada quadro: avalia a malha deformada do grupo de equipamento, separa as botas (partes boot, sole, boot_top)
pelo lado no repouso e mede a MENOR distancia entre as duas malhas (vertices de uma contra os triangulos da outra, nos dois
sentidos, BVH). Tambem mede: deslize da bola do pe plantada entre quadros nos clipes parados, deslize do pe de apoio no walk
e no run (velocidade do pe no chao comparada a velocidade nominal do clipe) e o vao entre as botas em repouso.

Uso: bash tools/blender.sh --background source_art/characters/pico_v2/pico_v2.blend \
        --python source_art/characters/pico_v2/pv2_check.py -- source_art/characters/pico_v2/pico_v2.check.json
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPTS = os.path.abspath(os.path.join(HERE, "..", "..", "scripts"))
for p in (HERE, SCRIPTS):
    if p not in sys.path:
        sys.path.insert(0, p)

import bpy
import numpy as np
from mathutils.bvhtree import BVHTree

import pv2_tex

out_path = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else None
sc = bpy.context.scene
rig = next(o for o in sc.objects if o.type == "ARMATURE")
gear = next(o for o in sc.objects if o.type == "MESH" and o.name.endswith("_Gear"))
face = next(o for o in sc.objects if o.type == "MESH" and o.name.endswith("_Face"))
me = gear.data
nv = len(me.vertices)
pid = np.empty(nv, dtype=np.float32)
me.attributes["rbpart"].data.foreach_get("value", pid)
pid = np.rint(pid * 100).astype(int)
rest = np.empty(nv * 3)
me.vertices.foreach_get("co", rest)
rest = rest.reshape(-1, 3)
boot_ids = {pv2_tex.PID[n] for n in ("boot", "sole", "boot_top")}
is_boot = np.isin(pid, list(boot_ids))
is_helmet = pid == pv2_tex.PID["helmet"]
gloveR = (pid == pv2_tex.PID["glove"]) & (rest[:, 0] > 0)
gloveL = (pid == pv2_tex.PID["glove"]) & (rest[:, 0] < 0)
sideR = is_boot & (rest[:, 0] > 0)
sideL = is_boot & (rest[:, 0] < 0)
polys = [tuple(p.vertices) for p in me.polygons]
setR, setL = set(np.where(sideR)[0]), set(np.where(sideL)[0])
facesR = [f for f in polys if all(v in setR for v in f)]
facesL = [f for f in polys if all(v in setL for v in f)]
iR, iL = np.where(sideR)[0], np.where(sideL)[0]
# reindexa faces para listas compactas
mapR = {v: i for i, v in enumerate(iR)}
mapL = {v: i for i, v in enumerate(iL)}
fR = [tuple(mapR[v] for v in f) for f in facesR]
fL = [tuple(mapL[v] for v in f) for f in facesL]
FPS = sc.render.fps


def mute_all():
    for ad in (rig.animation_data, face.data.shape_keys.animation_data):
        for tr in ad.nla_tracks:
            tr.mute = True
    gk = gear.data.shape_keys
    if gk is not None and gk.animation_data is not None:
        for tr in gk.animation_data.nla_tracks:
            tr.mute = True
        gk.animation_data.action = None


def set_clip(name):
    mute_all()
    rig.animation_data.action = bpy.data.actions[name]
    gk = gear.data.shape_keys
    if gk is not None and gk.animation_data is not None:
        for tr in gk.animation_data.nla_tracks:
            tr.mute = True
        gk.animation_data.action = bpy.data.actions.get(name + "_gear")


def deformed():
    dg = bpy.context.evaluated_depsgraph_get()
    ev = gear.evaluated_get(dg)
    m = ev.to_mesh()
    a = np.empty(len(m.vertices) * 3)
    m.vertices.foreach_get("co", a)
    ev.to_mesh_clear()
    return (np.array(gear.matrix_world) [:3, :3] @ a.reshape(-1, 3).T).T + np.array(gear.matrix_world)[:3, 3]


def min_gap(P):
    PR, PL = P[iR], P[iL]
    bR = BVHTree.FromPolygons([tuple(p) for p in PR], fR)
    bL = BVHTree.FromPolygons([tuple(p) for p in PL], fL)
    best = 9.0
    for p in PL:
        h = bR.find_nearest(p)
        if h[0] is not None:
            best = min(best, h[3])
    for p in PR:
        h = bL.find_nearest(p)
        if h[0] is not None:
            best = min(best, h[3])
    if bR.overlap(bL):
        best = 0.0
    return best


def bone_head(name):
    pb = rig.pose.bones[name]
    return np.array(rig.matrix_world @ pb.head)


report = {"criterio": "menor distancia entre as malhas das duas botas (bota+sola+colarinho) >= 0,02 m em todos os quadros",
          "clipes": {}}
glob = (9.0, None, None)
mute_all()
rig.animation_data.action = None
for pb in rig.pose.bones:
    pb.rotation_quaternion = (1, 0, 0, 0)
    pb.location = (0, 0, 0)
sc.frame_set(0)
report["vao_repouso_m"] = round(min_gap(deformed()), 4)
names = sorted(a.name for a in bpy.data.actions if not a.name.endswith("_key") and not a.name.endswith("_gear"))
speeds = {}
info_p = os.path.join(HERE, "pico_v2.info.json")
if os.path.exists(info_p):
    inf = json.load(open(info_p))
    speeds = {"walk": inf.get("walk_speed_mps"), "run": inf.get("run_speed_mps")}
for name in names:
    act = bpy.data.actions[name]
    set_clip(name)
    f0, f1 = int(act.frame_range[0]), int(act.frame_range[1])
    gaps = []
    balls = {"R": [], "L": []}
    hand_over = {}
    toes = {"R": [], "L": []}
    for fr in range(f0, f1 + 1):
        sc.frame_set(fr)
        P = deformed()
        g = min_gap(P)
        gaps.append(g)
        if name in ("idle", "team_pose", "celebrate"):
            top = float(P[is_helmet, 2].max())
            for sd, msk in (("R", gloveR), ("L", gloveL)):
                hand_over[sd] = max(hand_over.get(sd, -9.0), float(P[msk, 2].max()) - top)
        for s in ("R", "L"):
            balls[s].append(bone_head("toe." + s))
            toes[s].append(bone_head("toe_tip." + s))
    gaps = np.array(gaps)
    i = int(np.argmin(gaps))
    rec = {"min_gap_m": round(float(gaps[i]), 4), "quadro": f0 + i, "quadros": f1 - f0 + 1, "media_m": round(float(gaps.mean()), 4)}
    if hand_over:
        rec["mao_acima_do_capacete_max_m"] = {k: round(v, 4) for k, v in hand_over.items()}
    if name in ("idle", "team_pose", "pull_rope", "look_up", "wave", "stop"):
        # pe plantado: maior deslocamento horizontal da bola do pe entre dois quadros seguidos com ela no chao (z < 5 mm);
        # trocar de lugar NO AR (pulinho da team_pose) nao conta como patinar
        slide = 0.0
        for s in ("R", "L"):
            B = np.array(balls[s])
            for k in range(len(B) - 1):
                if B[k, 2] < 0.005 and B[k + 1, 2] < 0.005:
                    slide = max(slide, float(np.linalg.norm(B[k + 1, :2] - B[k, :2])))
        rec["deslize_pe_plantado_m_por_quadro"] = round(slide, 4)
    if name in ("walk", "run") and speeds.get(name):
        # no referencial do corpo o pe de apoio deve recuar a velocidade nominal; erro = |v_pe + v_nominal|
        errs = []
        for s in ("R", "L"):
            B = np.array(balls[s])
            Tt = np.array(toes[s])
            for k in range(len(B) - 1):
                if B[k, 2] < 0.004 and B[k + 1, 2] < 0.004:
                    vy = (B[k + 1, 1] - B[k, 1]) * FPS
                    errs.append(abs(vy + speeds[name]))
        rec["deslize_apoio_mps_max"] = round(max(errs), 4) if errs else None
        rec["quadros_apoio_medidos"] = len(errs)
    report["clipes"][name] = rec
    if gaps[i] < glob[0]:
        glob = (float(gaps[i]), name, f0 + i)
    print("CHECK", name, rec)
report["minimo_global_m"] = round(glob[0], 4)
report["minimo_global_clipe"] = glob[1]
report["minimo_global_quadro"] = glob[2]
report["aprovado"] = glob[0] >= 0.02
print("CHECK_GLOBAL", json.dumps({k: v for k, v in report.items() if k != "clipes"}))
if out_path:
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(report, f, indent=2, ensure_ascii=False)
