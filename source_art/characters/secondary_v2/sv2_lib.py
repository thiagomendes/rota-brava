"""Secundarios v2 (RB-R1 G4): pipeline comum para refazer filhote, capitao, Dona Amora (e moradores) no padrao do trio v2.
PROVISORIO.

Reaproveita o pipeline do trio sem altera-lo: importa (so leitura) as funcoes de bake e material de
source_art/characters/rastro_v2/rv2_tex.py (UV Smart Project + pack, mapas de geometria assados no Cycles, normal map a
partir da altura, imagens de cor e ORM, Principled com verniz -> KHR_materials_clearcoat) e a montagem do rosto/rig do
source_art/scripts/hero_lib.py. O que e novo aqui: tabela de partes por personagem, pintura procedural generica por tipo de
material (tecido, malha, couro, pelo, cabelo, pele, plastico, metal) e exportacao.

Fluxo por personagem: geometria por partes marcadas com tag(ob, parte, grupo) -> join por grupo (um objeto e uma atlas
por grupo) -> texture_group() para cada grupo -> materiais de fator (olhos/boca) no rosto -> rig/clipes -> export_glb().
Convencao: Blender Z-up, frente = +Y (-Z na Godot). Metros. Nada baixado ou importado de terceiros.
"""
import json
import math
import os
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPTS = os.path.abspath(os.path.join(HERE, "..", "..", "scripts"))
RV2 = os.path.abspath(os.path.join(HERE, "..", "rastro_v2"))
for p in (HERE, SCRIPTS, RV2):
    if p not in sys.path:
        sys.path.insert(0, p)

import bmesh
import bpy
import numpy as np

import rv2_tex as T          # pipeline de textura do trio (so leitura)
from rbart import REPO, hex_to_linear, tri_count, world_bbox

lin = T.lin
fbm = T.fbm
sstep = T.sstep
line = T.line


# ------------------------------------------------------------------ partes
class Parts:
    """Registro de partes de um personagem: id inteiro por nome (gravado no atributo de vertice rbpart, como no trio)."""

    def __init__(self):
        self.names = ["none"]

    def pid(self, name):
        if name not in self.names:
            self.names.append(name)
        return self.names.index(name)


def tag(ob, part, group, parts):
    ob["rbpart"] = part
    ob["rbgroup"] = group
    parts.pid(part)
    return ob


def set_part_attr(ob, parts):
    me = ob.data
    a = me.attributes.get("rbpart") or me.attributes.new("rbpart", "FLOAT", "POINT")
    a.data.foreach_set("value", np.full(len(me.vertices), parts.pid(ob.get("rbpart", "none")) / 100.0, dtype=np.float32))


def join_groups(objs, prefix, parts, names=None):
    """Junta os objetos por grupo (um objeto por grupo). `names`: grupo -> nome final do objeto (padrao Prefix_Grupo).
    Grava antes o id da parte de cada objeto no atributo de vertice `rbpart` (lido no bake, como no trio)."""
    groups = {}
    for ob in objs:
        set_part_attr(ob, parts)
        groups.setdefault(ob.get("rbgroup", "gear"), []).append(ob)
    out = {}
    for g, obs in groups.items():
        if len(obs) > 1:
            for o in bpy.context.view_layer.objects:
                o.select_set(False)
            for o in obs:
                o.select_set(True)
            bpy.context.view_layer.objects.active = obs[0]
            bpy.ops.object.join()
            ob = bpy.context.view_layer.objects.active
        else:
            ob = obs[0]
        ob.name = (names or {}).get(g, "%s_%s" % (prefix, g.capitalize()))
        ob.data.name = ob.name
        ob["rbgroup"] = g
        out[g] = ob
    return out


def part_ids(m, parts):
    return m["part"]


def mask(m, parts, *names):
    ids = [parts.pid(n) for n in names]
    return np.isin(m["part"], ids)


# ------------------------------------------------------------------ padroes (numpy, coordenadas 3D por texel)
def weave(P, N, period=0.0022):
    return T.triplanar(P, N, T.weave2d, period)


def knit(P, N, period=0.0045):
    """Malha (tricô): colunas de laçadas em V. Altura 0..1."""
    def fn(u, v):
        fu = (u % 1.0) - 0.5
        fv = (v * 0.8 + np.abs(fu) * 0.9) % 1.0
        return (np.sin(np.pi * fv) ** 0.8) * (1 - (2 * np.abs(fu)) ** 3)
    return T.triplanar(P, N, fn, period)


def fur_streaks(P, flow, scale=0.010, n=1.0):
    """Mechas de pelo curtas ao longo de `flow` (vetores unitarios por texel). Altura 0..1."""
    side = np.cross(flow, np.array([0.0, 0.0, 1.0]))
    side /= np.maximum(np.linalg.norm(side, axis=1)[:, None], 1e-6)
    a = np.einsum("ij,ij->i", P, side) / (scale * 0.22)
    b = np.einsum("ij,ij->i", P, flow) / (scale * 1.6)
    jit = fbm(P, scale * 0.9, 2) * 3.0
    s = 0.5 + 0.5 * np.sin(2 * np.pi * (a + jit))
    tuft = 0.5 + 0.5 * np.sin(2 * np.pi * (b + 1.7 * fbm(P * 1.3, scale * 2.0, 2)))
    return np.clip(s ** 1.6 * (0.55 + 0.45 * tuft), 0, 1)


def fur_noise(P, flow, N, across=0.0010, along=0.0060):
    """Pelo/cabelo: ruido de valor anisotropico (fino de lado, comprido ao longo do fluxo), sem ondas regulares. 0..1."""
    side = np.cross(flow, N)
    side /= np.maximum(np.linalg.norm(side, axis=1)[:, None], 1e-6)
    Q = np.column_stack([np.einsum("ij,ij->i", P, side) / across, np.einsum("ij,ij->i", P, flow) / along,
                         np.einsum("ij,ij->i", P, N) / across])
    n1 = T.value_noise(Q, 1.0)
    n2 = T.value_noise(Q * 0.5 + 7.31, 1.0)
    n3 = T.value_noise(Q * 2.0 + 3.17, 1.0)
    return np.clip(0.5 * n1 + 0.3 * n2 + 0.2 * n3, 0, 1)


def grain(P, scale=0.0016):
    """Couro: poros e rugas finas. Altura 0..1."""
    return 0.6 * fbm(P, scale, 3) + 0.4 * (1 - np.abs(2 * fbm(P + 3.1, scale * 3.0, 2) - 1))


# ------------------------------------------------------------------ pintura generica por tabela de partes
# tabela: parte -> dict(col=hex, rough, metal=0, kind in {"cloth","knit","leather","plastic","metal","skin","fur","hair","felt"},
#         amp=altura (m), ao=forca da oclusao na cor (0..1))
KIND = {"cloth": (0.00016, 0.20), "knit": (0.00030, 0.25), "leather": (0.00008, 0.22), "plastic": (0.00002, 0.15),
        "metal": (0.00001, 0.10), "skin": (0.00003, 0.16), "fur": (0.00050, 0.30), "hair": (0.00060, 0.30),
        "felt": (0.00010, 0.20)}


def paint_table(m, parts, table, default="cloth"):
    P, N = m["P"], m["N"]
    n = len(P)
    col = np.zeros((n, 3))
    rough = np.full(n, 0.5)
    metal = np.zeros(n)
    h = np.zeros(n)
    ao = m["ao"]
    pid = m["part"]
    for name, d in table.items():
        sel = pid == parts.pid(name)
        if not sel.any():
            continue
        kind = d.get("kind", default)
        amp, ao_k = KIND[kind]
        amp = d.get("amp", amp)
        ao_k = d.get("ao", ao_k)
        Ps, Ns = P[sel], N[sel]
        c = np.tile(lin(d["col"]), (sel.sum(), 1))
        r = np.full(sel.sum(), d.get("rough", 0.5))
        if kind == "cloth":
            pat = weave(Ps, Ns, d.get("period", 0.0022))
            c *= (0.92 + 0.10 * pat)[:, None]
            hh = amp * pat
            r += 0.06 * (pat - 0.5)
        elif kind == "felt":
            pat = fbm(Ps, 0.0012, 2)
            c *= (0.95 + 0.08 * pat)[:, None]
            hh = amp * pat
        elif kind == "knit":
            pat = knit(Ps, Ns, d.get("period", 0.0045))
            c *= (0.86 + 0.18 * pat)[:, None]
            hh = amp * pat
        elif kind == "leather":
            pat = grain(Ps)
            c *= (0.90 + 0.14 * fbm(Ps, 0.02, 2))[:, None]
            hh = amp * pat
            r += 0.10 * (pat - 0.5)
        elif kind == "metal":
            pat = fbm(Ps, 0.004, 2)
            c *= (0.95 + 0.08 * pat)[:, None]
            hh = amp * pat
        elif kind == "skin":
            pat = fbm(Ps, 0.025, 3)
            c *= (0.97 + 0.05 * pat)[:, None]
            hh = 0.00003 * fbm(Ps, 0.0025, 2)
        elif kind in ("fur", "hair"):
            hh = np.zeros(sel.sum())          # pintado pelo chamador (precisa do fluxo)
            pat = np.zeros(sel.sum())
        else:   # plastic
            pat = fbm(Ps, 0.01, 2)
            c *= (0.97 + 0.05 * pat)[:, None]
            hh = amp * fbm(Ps, 0.0015, 2)
        c *= (1 - ao_k + ao_k * ao[sel] ** 0.8)[:, None]
        col[sel] = c
        rough[sel] = r
        metal[sel] = d.get("metal", 0.0)
        h[sel] = hh
    return col, h, rough, metal


def add_line_detail(col, h, rough, sel, dist, w, color=None, depth=-0.0004, rough_add=0.0, mix=1.0):
    """Costura/friso/vinco ao longo de uma linha implicita: `dist` = distancia (m) por texel. Aplica so em `sel`."""
    L = line(dist, w) * sel
    if color is not None:
        col[:] = col * (1 - mix * L[:, None]) + lin(color) * mix * L[:, None]
    h += depth * L
    rough += rough_add * L
    return L


def add_stitches(h, col, sel, dist, along, offset=0.0035, pitch=0.0045, w=0.0006, depth=-0.00025, darken=0.12):
    s = T.stitches(dist, along, offset, pitch, w) * sel
    h += depth * s
    col *= (1 - darken * s)[:, None]
    return s


# ------------------------------------------------------------------ material por grupo
def texture_group(ob, name, res, paint, tex_dir, coat=0.4, coat_rough=0.3, normal_strength=1.0):
    """UV + mapas + pintura (paint(m) -> col, altura, rugosidade, metalico) + normal; devolve o material PBR `mat_<name>`."""
    t0 = time.time()
    T.uv_unwrap(ob, margin=0.003 if res >= 2048 else 0.005)
    m = T.bake_geometry(ob, res)
    t1 = time.time()
    col, h, rough, metal = paint(m)
    t2 = time.time()
    nimg = T.bake_normal_from_height(ob, h, res, name + "_normal", strength=normal_strength)
    cimg, oimg = T.build_images(name, res, col, rough, metal, m["ao"], m["mask"])
    print("TEX %s res=%d uv+geo=%.1fs pintura=%.1fs normal+img=%.1fs" % (name, res, t1 - t0, t2 - t1, time.time() - t2))
    os.makedirs(tex_dir, exist_ok=True)
    for img, suf in ((cimg, "color"), (nimg, "normal"), (oimg, "orm")):
        p = os.path.join(tex_dir, "%s_%s.png" % (name, suf))
        img.filepath_raw = p
        img.file_format = "PNG"
        img.save()
        img.pack()
    return T.pbr_material("mat_" + name, cimg, nimg, oimg, coat=coat, coat_rough=coat_rough)


def apply_material(ob, mat_):
    ob.data.materials.clear()
    ob.data.materials.append(mat_)
    for p in ob.data.polygons:
        p.material_index = 0


def face_materials(face_ob, prefix, iris_hex, skin_hex, mouth_hex="#7A2E36", dark_hex="#140C09"):
    """Mesmos 5 materiais de fator do rosto do trio (ordem eye, iris, dark, skin, mouth do hero_face), com verniz."""
    fm = [T.factor_material("mat_%s_face_eye" % prefix, "#FFFFFF", 0.18, coat=0.8, coat_rough=0.06, emission=0.08),
          T.factor_material("mat_%s_face_iris" % prefix, iris_hex, 0.14, coat=1.0, coat_rough=0.04),
          T.factor_material("mat_%s_face_dark" % prefix, dark_hex, 0.25, coat=0.6, coat_rough=0.1),
          T.factor_material("mat_%s_face_skin" % prefix, skin_hex, 0.48, coat=0.3, coat_rough=0.35),
          T.factor_material("mat_%s_face_mouth" % prefix, mouth_hex, 0.35, coat=0.4, coat_rough=0.2)]
    for i, m in enumerate(fm):
        if i < len(face_ob.data.materials):
            face_ob.data.materials[i] = m
        else:
            face_ob.data.materials.append(m)


# ------------------------------------------------------------------ geometria
def decimate(ob, ratio):
    if ratio >= 0.999:
        return
    md = ob.modifiers.new("dec", "DECIMATE")
    md.decimate_type = "COLLAPSE"
    md.ratio = ratio
    md.use_collapse_triangulate = False
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
    old = ob.data
    ob.modifiers.remove(md)
    ob.data = me
    me.name = old.name
    for p in me.polygons:
        p.use_smooth = True
    bpy.data.meshes.remove(old)


def verts_np(ob):
    a = np.empty(len(ob.data.vertices) * 3)
    ob.data.vertices.foreach_get("co", a)
    return a.reshape(-1, 3)


def set_verts(ob, P):
    ob.data.vertices.foreach_set("co", P.ravel())
    ob.data.update()


def smooth_mesh(ob, reps=2, factor=0.5):
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    for _ in range(reps):
        bmesh.ops.smooth_vert(bm, verts=bm.verts[:], factor=factor, use_axis_x=True, use_axis_y=True, use_axis_z=True)
    bm.to_mesh(ob.data)
    bm.free()


# ------------------------------------------------------------------ exportacao e medidas
def export_glb(path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    kw = dict(filepath=path, export_format="GLB", use_selection=False, export_yup=True, export_apply=False, export_morph=True,
              export_materials="EXPORT", export_cameras=False, export_lights=False, export_extras=False, export_skins=True,
              export_animations=True, export_animation_mode="NLA_TRACKS", export_force_sampling=True, export_frame_range=False,
              export_optimize_animation_size=False, export_def_bones=False, export_image_format="JPEG", export_tangents=False)
    try:
        bpy.ops.export_scene.gltf(export_image_quality=88, **kw)
    except TypeError:
        bpy.ops.export_scene.gltf(**kw)
    print("GLB", path, os.path.getsize(path))


def base_info(objs, rig, face_ob, prefix):
    lo, hi = world_bbox(objs)
    acts = {a.name: [round(a.frame_range[0]), round(a.frame_range[1])] for a in bpy.data.actions if not a.name.endswith("_key")}
    return {"tris": tri_count(objs), "tris_por_objeto": {o.name: tri_count([o]) for o in objs},
            "materials": sorted({m.name for o in objs for m in o.data.materials if m}),
            "height_m": round(hi.z - lo.z, 4), "min_z": round(lo.z, 4), "objects": sorted(o.name for o in objs),
            "bones": [b.name for b in rig.data.bones], "bone_count": len(rig.data.bones), "animations": acts,
            "shape_keys": [k.name for k in face_ob.data.shape_keys.key_blocks],
            "texturas": {img.name: list(img.size) for img in bpy.data.images if img.name.startswith(prefix)}}


def save(info, blend, glb):
    print("CHAR_INFO", json.dumps({k: v for k, v in info.items() if k != "tris_por_objeto"}))
    if blend:
        os.makedirs(os.path.dirname(blend), exist_ok=True)
        bpy.ops.wm.save_as_mainfile(filepath=blend, compress=True)
        with open(os.path.splitext(blend)[0] + ".info.json", "w", encoding="utf-8") as f:
            json.dump(info, f, indent=2, ensure_ascii=False)
    if glb:
        export_glb(glb)
