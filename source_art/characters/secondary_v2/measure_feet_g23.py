"""Medida do vao perna-sapato (RB-R1 G23) nos adultos v2, quadro a quadro em todos os clipes. PROVISORIO.

Para cada perna e cada quadro: eixo da canela posada (joelho -> tornozelo). A perna (calca/meia: triangulos da malha de
tecido com peso dominante na canela ou no pe) e o sapato (triangulos da malha de equipamento com peso dominante no pe ou na
canela, abaixo de 30 cm), na faixa da juncao, viram pontos (vertices, meio das arestas e centro de cada triangulo, para a
malha reduzida nao abrir buracos falsos entre vertices). Em 24 setores em volta do eixo, so contam pontos a RMIN ou mais do eixo (a borda que aparece
na silhueta). vao(setor) = ponto mais baixo da perna - ponto mais alto do sapato, ao longo do eixo; vao do quadro = pior
setor. <= 0: a barra desce alem do topo do sapato em toda a volta. A mesma conta roda no Godot sobre o GLB
(game/tests/test_feet_gap.gd).

Uso: bash tools/blender.sh --background <id>_v2.blend --python measure_feet_g23.py [-- --json saida.json]
"""
import json
import math
import sys

import bpy
import numpy as np

SECTORS = 24
RMIN = 0.030
LEG_BONES = ("shin", "foot", "toe", "heel")
SHOE_BONES = ("shin", "foot", "toe", "toe_tip", "heel")
SHOE_MAX_Z = 0.30
LEG_BAND = 0.20        # perna: so triangulos ate 20 cm acima do tornozelo (na pose de repouso)
SHOE_BAND = -0.03      # sapato: so triangulos acima de 3 cm abaixo do tornozelo (o cano e o peito do pe)
# vertices, pontos medios das arestas e centro de cada triangulo (7 pontos)
BARY = np.array([(1, 0, 0), (0, 1, 0), (0, 0, 1), (0.5, 0.5, 0), (0, 0.5, 0.5), (0.5, 0, 0.5), (1 / 3.0, 1 / 3.0, 1 / 3.0)])


def dominant(ob):
    names = {g.index: g.name for g in ob.vertex_groups}
    out = []
    for v in ob.data.vertices:
        best, bw = None, 0.0
        for g in v.groups:
            if g.weight > bw:
                best, bw = names[g.group], g.weight
        out.append(best or "")
    return out


def tris_of(ob, vmask):
    ob.data.calc_loop_triangles()
    T = np.empty(len(ob.data.loop_triangles) * 3, dtype=np.int64)
    ob.data.loop_triangles.foreach_get("vertices", T)
    T = T.reshape(-1, 3)
    return T[vmask[T].all(axis=1)]


def world_verts(ob):
    dg = bpy.context.evaluated_depsgraph_get()
    ev = ob.evaluated_get(dg)
    me = ev.to_mesh()
    P = np.empty(len(me.vertices) * 3)
    me.vertices.foreach_get("co", P)
    ev.to_mesh_clear()
    P = P.reshape(-1, 3)
    M = np.array(ob.matrix_world)
    return P @ M[:3, :3].T + M[:3, 3]


def samples(V, T):
    return np.einsum("kj,tjc->tkc", BARY, V[T]).reshape(-1, 3)


def leg_gap(leg, shoe, knee, ankle):
    a = knee - ankle
    a /= np.linalg.norm(a)
    e1 = np.array([1.0, 0, 0]) - a * a[0]
    e1 /= np.linalg.norm(e1)
    e2 = np.cross(a, e1)

    def polar(P):
        d = P - ankle
        u = d @ a
        rv = d - np.outer(u, a)
        r = np.linalg.norm(rv, axis=1)
        th = np.arctan2(rv @ e2, rv @ e1)
        sec = ((th + math.pi) / (2 * math.pi) * SECTORS).astype(int) % SECTORS
        return u, r, sec
    lu, lr, ls = polar(leg)
    su, sr, ss = polar(shoe)
    worst = -1e9
    for k in range(SECTORS):
        lm = (ls == k) & (lr >= RMIN)
        sm = (ss == k) & (sr >= RMIN)
        if not lm.any() or not sm.any():
            continue                       # setor sem borda de um dos lados: nao decide
        worst = max(worst, lu[lm].min() - su[sm].max())
    return worst


def main():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    rig = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    meshes = [o for o in bpy.data.objects if o.type == "MESH" and o.parent == rig]
    cloth = next(o for o in meshes if o.name.endswith("_Cloth"))
    gear = next(o for o in meshes if o.name.endswith("_Gear"))
    dc, dg_ = dominant(cloth), dominant(gear)
    gz = np.array([v.co.z for v in gear.data.vertices])
    cz = np.array([v.co.z for v in cloth.data.vertices])
    ankle_z = rig.data.bones["foot.R"].head_local.z
    sel = {}
    for s in ("R", "L"):
        lm = np.array([d in tuple(b + "." + s for b in LEG_BONES) for d in dc]) & (cz < ankle_z + LEG_BAND)
        sm = np.array([d in tuple(b + "." + s for b in SHOE_BONES) for d in dg_]) & (gz < SHOE_MAX_Z) & (gz > ankle_z + SHOE_BAND)
        sel[s] = (tris_of(cloth, lm), tris_of(gear, sm))
    acts = [a for a in bpy.data.actions if not a.name.endswith(("_key", "_gear"))]
    for o in meshes:                     # NLA fora: so a acao ativa conta
        ad = o.data.shape_keys.animation_data if o.data.shape_keys else None
        if ad:
            for tr in ad.nla_tracks:
                tr.mute = True
    if rig.animation_data:
        for tr in rig.animation_data.nla_tracks:
            tr.mute = True
    sc = bpy.context.scene
    res = {}
    for act in acts:
        rig.animation_data.action = act
        f0, f1 = int(act.frame_range[0]), int(act.frame_range[1])
        worst, wf = -1e9, None
        for f in range(f0, f1 + 1):
            sc.frame_set(f)
            C, G = world_verts(cloth), world_verts(gear)
            Mw = np.array(rig.matrix_world)
            for s in ("R", "L"):
                pb = rig.pose.bones["shin." + s]
                knee = Mw[:3, :3] @ np.array(pb.head) + Mw[:3, 3]
                ankle = Mw[:3, :3] @ np.array(pb.tail) + Mw[:3, 3]
                lt, st = sel[s]
                g = leg_gap(samples(C, lt), samples(G, st), knee, ankle)
                if g > worst:
                    worst, wf = g, (f, s)
        res[act.name] = {"max_gap_mm": round(worst * 1000, 1), "frame": wf[0], "side": wf[1], "frames": f1 - f0 + 1}
        print("G23GAP %s %s" % (act.name, json.dumps(res[act.name])))
    if "--json" in args:
        with open(args[args.index("--json") + 1], "w") as fh:
            json.dump(res, fh, indent=1)


main()
