"""Filhote v2 (RB-R1 G4): o cachorrinho caramelo refeito no padrao do trio v2. PROVISORIO.

Mesmo personagem do pup.glb (caramelo, focinho e peito creme, mancha creme em volta do olho direito, orelhas caidas
castanhas, coleira turquesa com pingente-emblema), mesmo esqueleto (23 ossos, mesmas posicoes) e MESMOS CLIPES
(idle, wag, jump_happy, bark, step_on_horn, walk, run) do source_art/scripts/pup_build.py, que e importado so para leitura
(bones, pesos, clipes, velocidades). O que muda e o acabamento:
 - corpo e pernas numa malha so (SKIN + SUBSURF 3), com patas largas e sola achatada saindo da propria perna (antes: tubos
   e patas-ovo soltas); peito, barriga e garupa modelados por deslocamento em numpy;
 - cabeca por metaballs (cranio + focinho + bochechas + testa numa superficie lisa; antes: elipsoides grudados);
 - creme do focinho, peito, patas, mancha do olho e ponta do rabo PINTADOS na textura com degrade (antes: malhas por cima);
 - textura assada e pintada como a do trio (rv2_tex): pelo curto com fluxo (normal map), oclusao, rugosidade; nariz e
   pingente com verniz; coleira de couro com pesponto;
 - rosto pelo mesmo hero_face do trio (olhos com dois brilhos, palpebras, sobrancelhas, visemas), materiais de rosto do trio.

Uso (Linux):
  bash tools/blender.sh --background --factory-startup --python source_art/characters/secondary_v2/build_pup_v2.py -- \
      --glb $PWD/game/assets/models/characters/pup_v2.glb --blend $PWD/source_art/characters/secondary_v2/pup_v2.blend
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPTS = os.path.abspath(os.path.join(HERE, "..", "..", "scripts"))
for p in (HERE, SCRIPTS):
    if p not in sys.path:
        sys.path.insert(0, p)

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

import char_lib as cl
import hero_face
import hero_lib
import pup_build as PB           # esqueleto, pesos e clipes do filhote atual (so leitura)
import sv2_lib as S
from rbart import REPO, arg_value, mat, new_object, reset_scene

TEX_DIR = os.path.join(REPO, "captures", "g4", "build_textures", "pup_v2")
PREFIX = "pup_v2"
HC, HR, BZ = PB.HC, PB.HR, PB.BODY_Z
C = dict(pelo="#E09A52", sela="#C07A3A", creme="#F6E4C4", orelha="#94552B", orelha_dk="#6E3C1E", nariz="#24150F",
         coleira="#2FB5A5", coleira_dk="#1E8C80", ouro="#FFC83D", emblema="#123A5E", iris="#6B3F1F", boca="#8E3A44")
parts = S.Parts()


def V(*a):
    return Vector(a)


def placeholder(role):
    return mat("tmp_pup_" + role, C.get(role, "#888888"), 0.5)


# ------------------------------------------------------------------ geometria
def body():
    """Tronco + pescoco + 4 pernas numa malha SKIN; a pata e um no a frente do tornozelo com a sola achatada no chao."""
    nodes, edges = [], []

    def add(co, r, link=None):
        nodes.append((tuple(co), r))
        if link is not None:
            edges.append((link, len(nodes) - 1))
        return len(nodes) - 1
    rump = add((0, -0.115, BZ + 0.005), 0.078)
    mid = add((0, -0.020, BZ + 0.004), 0.080, rump)
    chest = add((0, 0.080, BZ + 0.022), 0.086, mid)
    neck0 = add((0, 0.122, 0.292), 0.062, chest)
    add((0, 0.150, 0.345), 0.052, neck0)
    for name, (x, y) in PB.LEGS.items():
        front = name.startswith("fl")
        root = chest if front else rump
        top = add((x * 0.95, y - (0.0 if front else 0.010), BZ - 0.028), 0.050 if front else 0.060, root)
        knee = add((x, y + (0.006 if front else -0.012), 0.112), 0.036 if front else 0.040, top)
        ank = add((x, y, 0.046), 0.033, knee)
        add((x, y + 0.026, 0.024), 0.043, ank)
    ob = cl.skin_obj("Pup_BodyMesh", nodes, edges, placeholder("pelo"), levels=3, branch=0.9)
    P = S.verts_np(ob)
    # assenta as patas no chao (o SUBSURF encolhe a ponta): desce o que esta abaixo de 6 cm e achata a sola
    m0 = P[:, 2].min()
    low = np.clip(1 - P[:, 2] / 0.06, 0, 1)
    P[:, 2] -= m0 * low
    P[:, 2] = np.maximum(P[:, 2], 0.0)
    # barriga recolhida atras do peito, peito mais fundo na frente, garupa arredondada; pescoco mais grosso na base
    y, z = P[:, 1], P[:, 2]
    under = np.clip((BZ - z) / 0.08, 0, 1) * (np.abs(P[:, 0]) < 0.07)
    tuck = np.exp(-((y + 0.02) / 0.06) ** 2) * under * (z > 0.12)
    P[:, 2] += 0.018 * tuck
    chest_f = np.exp(-((y - 0.10) / 0.05) ** 2) * np.exp(-((z - (BZ - 0.01)) / 0.05) ** 2)
    P[:, 1] += 0.012 * chest_f
    S.set_verts(ob, P)
    S.decimate(ob, 0.55)
    return S.tag(ob, "fur_body", "body", parts)


def tail():
    bm = bmesh.new()
    pts = [(0, -0.10, BZ + 0.01), (0, -0.14, BZ + 0.025), (0, -0.165, BZ + 0.045), (0, -0.195, BZ + 0.085),
           (0, -0.212, BZ + 0.135), (0, -0.208, BZ + 0.180), (0, -0.200, BZ + 0.200)]
    cl.tube(bm, pts, [0.036, 0.030, 0.026, 0.023, 0.020, 0.015, 0.006], 12, True)
    ob = new_object("Pup_TailMesh", bm, placeholder("pelo"))
    md = ob.modifiers.new("sub", "SUBSURF")
    md.levels = 1
    hero_lib.bake(ob)
    return S.tag(ob, "fur_tail", "body", parts)


def head():
    """Cranio, testa, focinho e bochechas numa superficie lisa (metaballs), alisada e reduzida."""
    E = [("ELLIPSOID", tuple(HC), 1.0, (HR[0] * 0.98, HR[1] * 0.96, HR[2] * 0.97), False),
         ("ELLIPSOID", (0, HC.y + 0.082, HC.z - 0.050), 1.0, (0.058, 0.060, 0.042), False),          # focinho
         ("ELLIPSOID", (0, HC.y + 0.070, HC.z - 0.078), 1.0, (0.040, 0.040, 0.020), False),          # queixo
         ("BALL", (0.058, HC.y + 0.050, HC.z - 0.040), 0.044, None, False),                         # bochechas
         ("BALL", (-0.058, HC.y + 0.050, HC.z - 0.040), 0.044, None, False),
         ("ELLIPSOID", (0, HC.y - 0.030, HC.z + 0.050), 1.0, (0.085, 0.080, 0.060), False)]          # nuca/topo
    ob = hero_lib.metaball_obj("Pup_HeadMesh", E, placeholder("pelo"), res=0.0065, thresh=0.6)
    S.smooth_mesh(ob, 3, 0.5)
    S.decimate(ob, 0.45)
    return S.tag(ob, "fur_head", "head", parts)


def ears():
    out = []
    for s, sx in (("L", -1), ("R", 1)):
        bm = bmesh.new()
        cl.ellipsoid(bm, (0, 0, 0), (0.034, 0.011, 0.066), 20, 12)
        for v in bm.verts:                       # orelha em concha: curva para dentro, ponta arredondada e mais larga
            x, y, z = v.co
            u = (0.066 - z) / 0.132
            v.co.x = x * (0.85 + 0.35 * u)
            v.co.y = y - 0.010 * (x / 0.034) ** 2 + 0.004 * u
        cl.transform_bm(bm, Matrix.Translation((sx * 0.113, HC.y - 0.004, HC.z + 0.002))
                        @ Matrix.Rotation(math.radians(-sx * 16), 4, "Y") @ Matrix.Rotation(math.radians(8), 4, "X"))
        ob = new_object("Pup_Ear" + s, bm, placeholder("orelha"))
        S.tag(ob, "ear", "head", parts)
        out.append((ob, "ear." + s))
    return out


def nose():
    bm = bmesh.new()
    cl.ellipsoid(bm, (0, 0, 0), (0.024, 0.017, 0.016), 20, 12)
    for v in bm.verts:                            # nariz em coracao arredondado (mais largo em cima)
        v.co.x *= 1.0 + 0.18 * max(v.co.z, 0) / 0.016
    cl.transform_bm(bm, Matrix.Translation((0, HC.y + 0.141, HC.z - 0.036)))
    return S.tag(new_object("Pup_NoseMesh", bm, placeholder("nariz")), "nose", "gear", parts)


def collar():
    bm = bmesh.new()
    # faixa de couro (perfil achatado) inclinada como no pescoco
    prof_r, prof_h = 0.058, 0.026
    n, m = 32, 8
    rows = []
    for i in range(n):
        a = 2 * math.pi * i / n
        ring = []
        for j in range(m):
            b = 2 * math.pi * j / m
            r = prof_r + 0.005 * math.cos(b)
            z = prof_h * 0.5 * math.sin(b)
            ring.append(bm.verts.new((r * math.sin(a), r * math.cos(a) * 1.04, z)))
        rows.append(ring)
    for i in range(n):
        for j in range(m):
            bm.faces.new((rows[i][j], rows[(i + 1) % n][j], rows[(i + 1) % n][(j + 1) % m], rows[i][(j + 1) % m]))
    cl.transform_bm(bm, Matrix.Translation((0, 0.132, 0.292)) @ Matrix.Rotation(math.radians(-38), 4, "X"))
    col = S.tag(new_object("Pup_CollarMesh", bm, placeholder("coleira")), "collar", "gear", parts)
    # argola e pingente-escudo com borda dourada e estrela
    T_ = Matrix.Translation((0, 0.190, 0.240)) @ Matrix.Rotation(math.radians(-14), 4, "X")
    bm = bmesh.new()
    cl.torus_z(bm, 0.008, 0.0022, 0.0, major=14, minor=5)
    cl.transform_bm(bm, Matrix.Translation((0, 0.186, 0.268)) @ Matrix.Rotation(math.radians(90), 4, "Y"))
    ring = S.tag(new_object("Pup_TagRing", bm, placeholder("ouro")), "tag_ring", "gear", parts)
    bm = bmesh.new()
    hero_lib.prism(bm, hero_lib.emblem_outline(0.046, 0.052), 0.006, (0, -0.003, 0))
    bmesh.ops.bevel(bm, geom=[e for e in bm.edges if len(e.link_faces) == 2 and e.calc_face_angle(0) > 0.6], offset=0.0016,
                    segments=2, affect="EDGES")
    cl.transform_bm(bm, T_)
    rim = S.tag(new_object("Pup_TagRim", bm, placeholder("ouro")), "tag_rim", "gear", parts)
    bm = bmesh.new()
    hero_lib.prism(bm, hero_lib.emblem_outline(0.036, 0.042), 0.004, (0, 0.001, 0.001))
    cl.transform_bm(bm, T_)
    tag = S.tag(new_object("Pup_TagFace", bm, placeholder("emblema")), "tag", "gear", parts)
    bm = bmesh.new()
    hero_lib.prism(bm, hero_lib.star4(0.014, 0.005), 0.003, (0, 0.005, 0.002))
    cl.transform_bm(bm, T_)
    star = S.tag(new_object("Pup_TagStar", bm, placeholder("ouro")), "tag_star", "gear", parts)
    return [col, ring, rim, tag, star]


# ------------------------------------------------------------------ pintura
def flow_field(P, N, kind):
    if kind == "head":
        f = P - np.array([0.0, HC.y + 0.16, HC.z - 0.03])         # sai do focinho para tras
        f[:, 2] *= 0.6
    elif kind == "tail":
        f = np.tile([0.0, -0.4, 1.0], (len(P), 1))
    else:
        f = np.tile([0.0, -1.0, -0.25], (len(P), 1))
        legs = P[:, 2] < BZ - 0.04
        f[legs] = [0.0, 0.0, -1.0]
    f = f - N * np.einsum("ij,ij->i", f, N)[:, None]
    return f / np.maximum(np.linalg.norm(f, axis=1)[:, None], 1e-6)


def blob(P, c, r):
    d = np.linalg.norm((P - np.array(c)) / np.array(r), axis=1)
    return d


def cream_mask(P, kind):
    """1 onde o pelo e creme: focinho, queixo, mancha do olho direito, peito e barriga, patas, ponta do rabo (degrade)."""
    x, y, z = P[:, 0], P[:, 1], P[:, 2]
    w = np.zeros(len(P))
    if kind == "head":
        w = np.maximum(w, sstep_inv(blob(P, (0, HC.y + 0.10, HC.z - 0.058), (0.070, 0.090, 0.050)), 0.85, 1.15))
        w = np.maximum(w, sstep_inv(blob(P, (0.050, HC.y + 0.075, HC.z + 0.018), (0.048, 0.080, 0.052)), 0.80, 1.10))
        # risca creme no meio da testa (descendo para o focinho)
        stripe = sstep_inv(np.abs(x) / 0.016 + np.clip((HC.z + 0.05 - z) / 0.12, 0, 9) * 0, 0.7, 1.2) * (y > HC.y + 0.05) * \
            (z < HC.z + 0.09) * (z > HC.z - 0.02)
        w = np.maximum(w, stripe)
    elif kind == "body":
        chest = sstep_inv(blob(P, (0, 0.140, BZ + 0.030), (0.052, 0.050, 0.070)), 0.8, 1.15) * (P[:, 2] > BZ - 0.06)
        # barriga: so a parte de baixo do tronco (nada nas pernas)
        belly = S.sstep(z, BZ - 0.105, BZ - 0.085) * sstep_inv((z - (BZ - 0.075)) / 0.035, 0.6, 1.3) * (np.abs(x) < 0.060) * \
            (y > -0.10) * (y < 0.14)
        paws = sstep_inv((z - 0.060) / 0.03, 0.4, 1.2)
        w = np.maximum.reduce([chest, belly, paws])
    elif kind == "tail":
        w = S.sstep(z, BZ + 0.150, BZ + 0.175)
    return np.clip(w, 0, 1)


def sstep_inv(d, a, b):
    return 1.0 - S.sstep(d, a, b)


def paint_fur(kind):
    def fn(m):
        P, N = m["P"], m["N"]
        n = len(P)
        pid = m["part"]
        flow = flow_field(P, N, kind)
        # G4 r2: pelo curto (tufos + fios + fio fino), no lugar do vinil liso
        clump = S.fur_noise(P + 1.91, flow, N, across=0.0030, along=0.0100)
        strands = S.fur_noise(P, flow, N, across=0.0013, along=0.0070)
        fine = S.fur_noise(P + 0.37, flow, N, across=0.0005, along=0.0025)
        base = np.tile(S.lin(C["pelo"]), (n, 1))
        # sela mais escura no dorso e no alto da cabeca, clareando para a barriga
        up = np.clip(N[:, 2], 0, 1)
        dorsal = S.sstep(P[:, 2], BZ + 0.03, BZ + 0.09) * (kind == "body") + S.sstep(P[:, 2], HC.z + 0.04, HC.z + 0.11) * (kind == "head")
        base = base * (1 - 0.45 * dorsal[:, None]) + S.lin(C["sela"]) * 0.45 * dorsal[:, None]
        k = kind if kind != "body" else "body"
        cm = cream_mask(P, k)
        if kind == "body":
            tl = pid == parts.pid("fur_tail")
            cm[tl] = cream_mask(P[tl], "tail")
        col = base * (1 - cm[:, None]) + S.lin(C["creme"]) * cm[:, None]
        # orelhas: castanho, mais escuro na ponta
        ear = pid == parts.pid("ear")
        if ear.any():
            tip = S.sstep(-(P[ear, 2] - HC.z), 0.02, 0.07)
            col[ear] = S.lin(C["orelha"]) * (1 - 0.5 * tip[:, None]) + S.lin(C["orelha_dk"]) * 0.5 * tip[:, None]
        col *= (0.70 + 0.26 * clump + 0.22 * strands + 0.08 * fine)[:, None]
        col *= (0.78 + 0.22 * m["ao"] ** 0.8)[:, None]
        h = 0.00120 * clump + 0.00080 * strands + 0.00030 * fine
        rough = 0.80 - 0.08 * strands
        return col, h, rough, np.zeros(n)
    return fn


GEAR = {"nose": dict(col=C["nariz"], rough=0.22, kind="plastic"), "collar": dict(col=C["coleira"], rough=0.45, kind="leather"),
        "tag_ring": dict(col=C["ouro"], rough=0.28, metal=0.7, kind="metal"), "tag_rim": dict(col=C["ouro"], rough=0.28, metal=0.7, kind="metal"),
        "tag": dict(col=C["emblema"], rough=0.32, kind="plastic"), "tag_star": dict(col=C["ouro"], rough=0.26, metal=0.7, kind="metal")}


def paint_gear(m):
    col, h, rough, metal = S.paint_table(m, parts, GEAR)
    P = m["P"]
    c = m["part"] == parts.pid("collar")
    if c.any():
        # bordas mais escuras e pesponto dos dois lados da faixa (distancia ao plano medio da coleira)
        o = np.array([0, 0.132, 0.292])
        nrm = np.array([0, math.sin(math.radians(-38)) * -1, math.cos(math.radians(-38))])
        nrm = nrm / np.linalg.norm(nrm)
        d = (P - o) @ nrm
        along = np.arctan2(P[:, 0], (P[:, 1] - o[1])) * 0.06
        S.add_stitches(h, col, c, np.abs(d) - 0.0065, along, offset=0.0, pitch=0.0040, w=0.0007, depth=-0.0002, darken=0.25)
        edge = S.sstep(np.abs(d), 0.008, 0.0105) * c
        col *= (1 - 0.35 * edge)[:, None]
    nz = m["part"] == parts.pid("nose")
    if nz.any():
        # narinas e risca do meio (vincos), leve brilho
        Pn = P[nz] - np.array([0, HC.y + 0.141, HC.z - 0.036])
        nost = sum(np.exp(-(((Pn[:, 0] - sx * 0.010) / 0.0055) ** 2 + ((Pn[:, 2] + 0.002) / 0.004) ** 2)) for sx in (1, -1)) * (Pn[:, 1] > 0.005)
        mid = np.exp(-(Pn[:, 0] / 0.0012) ** 2) * (Pn[:, 2] < -0.004)
        h[nz] += -0.0006 * nost - 0.0003 * mid
        col[nz] *= (1 - 0.6 * nost)[:, None]
    return col, h, rough, metal


# ------------------------------------------------------------------ montagem
def build(glb=None, blend=None):
    sc = reset_scene()
    sc.render.fps = 30
    objs = []      # (ob, modo, osso)
    objs.append((body(), "dist", None))
    objs.append((tail(), "tail", None))
    hd = head()
    objs.append((hd, "single", "head"))
    for ob, bone in ears():
        objs.append((ob, "single", bone))
    objs.append((nose(), "single", "head"))
    for i, ob in enumerate(collar()):
        objs.append((ob, "single", "neck"))
    # rosto: mesmo construtor do trio, ancorado na superficie da cabeca nova (olhos grandes, boca no focinho)
    fm = dict(eye=placeholder("olhos"), iris=placeholder("iris"), dark=placeholder("escuro"), skin=placeholder("pelo"),
              mouth=placeholder("boca"))
    face, info = hero_face.build_face(None, "Pup_Face", fm, hd, HC, k=0.62, eye_x=0.074, eye_z=HC.z + 0.022, eye_size=1.18,
                                      mouth_z=HC.z - 0.083, brow_w=0.8)
    face["rbgroup"] = "face"
    # rig e pesos (mesmos ossos e regras do filhote atual)
    arm = bpy.data.armatures.new("Pup_Armature")
    rig = bpy.data.objects.new("Pup", arm)
    bpy.context.scene.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")
    for (nm, h, t, p, d) in PB.bones():
        b = arm.edit_bones.new(nm)
        b.head, b.tail, b.use_deform = Vector(h), Vector(t), d
        if p:
            b.parent = arm.edit_bones[p]
    bpy.ops.object.mode_set(mode="OBJECT")
    rig["provisional"] = True
    rig["agent"] = "art3d"
    rig["variant"] = PREFIX
    for ob, mode, bone in objs:
        if mode == "single":
            cl.bind_to_rig(ob, rig, single_bone=bone)
        else:
            PB.pup_weights(ob, rig, only=("hips", "tail1", "tail2", "tail3") if mode == "tail" else None)
            cl.smooth_weights(ob, 2, 0.5)
    cl.bind_to_rig(face, rig, single_bone="head")
    groups = S.join_groups([o for o, _, _ in objs] + [face], "Pup", parts,
                           names={"body": "Pup_Body", "head": "Pup_Head", "gear": "Pup_Gear", "face": "Pup_Face"})
    # texturas (atlas por grupo) e materiais
    # G4 r2: pelo sem verniz e com normal mais forte (fosco, nao vinil)
    for g, res, coat, cr in (("body", 1024, 0.0, 0.5), ("head", 1024, 0.0, 0.5)):
        S.apply_material(groups[g], S.texture_group(groups[g], "%s_%s" % (PREFIX, "fur_" + g), res, paint_fur(g), TEX_DIR,
                                                    coat=coat, coat_rough=cr, normal_strength=1.6))
    S.apply_material(groups["gear"], S.texture_group(groups["gear"], PREFIX + "_gear", 512, paint_gear, TEX_DIR, coat=0.6, coat_rough=0.12))
    S.face_materials(groups["face"], PREFIX, C["iris"], C["pelo"], mouth_hex=C["boca"], dark_hex="#1E120C")
    PB.author(rig, groups["face"])
    bpy.context.view_layer.update()
    objs_f = list(groups.values())
    out = S.base_info(objs_f, rig, groups["face"], PREFIX)
    out.update({"walk_speed_mps": round(PB.gait_speed("walk"), 4), "run_speed_mps": round(PB.gait_speed("run"), 4),
                "variant": PREFIX})
    S.save(out, blend, glb)
    return out


if __name__ == "__main__":
    build(arg_value("--glb"), arg_value("--blend"))
