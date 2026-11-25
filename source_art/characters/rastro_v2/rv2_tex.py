"""Rastro v2: UV, mapas assados e materiais PBR padrao do glTF. PROPOSTA PROVISORIA.

Fluxo (tudo no Blender 4.5.16 por script, sem textura de terceiros):
 1. junta as partes por grupo de material (traje, pele, equipamento, cabelo, vidro, tela; o rosto fica separado);
 2. UV por Smart UV Project + empacotamento;
 3. assa no Cycles (CPU) mapas de GEOMETRIA por texel: posicao, normal, parte (atributo rbpart) e oclusao (AO);
 4. pinta em numpy, por texel e em coordenadas 3D (continuo atraves das ilhas de UV): cor, altura (trama do tecido,
    costuras, pespontos, vincos, frisos), rugosidade e metalico;
 5. assa a normal map em espaco tangente (MikkTSpace) a partir da altura (Bump) no Cycles;
 6. monta Principled BSDF com as texturas (base color, normal, ORM: R=oclusao G=rugosidade B=metalico) e camada de verniz
    (Coat -> KHR_materials_clearcoat). Texturas com mipmap na Godot (ver game/lookdev/gltf_pbr_import.gd).
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
import numpy as np

from rbart import hex_to_linear

# ------------------------------------------------------------------ paleta (sRGB hex) e ids das partes
C = dict(orange="#FF8A1F", orange_dk="#E8701A", creme="#FFF1D6", navy="#1F3A5F", navy_lt="#2B5285", navy_emb="#123A5E",
         gold="#FFC83D", skin="#C98B60", blush="#E9806E", lip="#B5585A", hair="#3A2419", hair_lt="#6A4430", cyan="#7FE3FF")

PARTS = ["none", "suit", "collar", "tail", "skin_head", "skin_neck", "hair", "hair_ties", "glove", "glove_cuff", "boot", "sole",
         "boot_top", "belt", "buckle", "buckle_star", "emblem", "emblem_star", "emblem_band", "scanner_strap", "scanner", "screen",
         "lupa_ring", "lupa_handle", "lupa_glass", "holster", "pouch", "notebook", "pouch_star", "pouch_strap", "goggle_band",
         "goggle_cup", "goggle_rim", "goggle_lens", "visor_band", "visor_frame", "visor_lens", "visor_pivot", "face"]
PID = {n: i for i, n in enumerate(PARTS)}

# cor base, rugosidade, metalico por parte do grupo "gear" (vinil/plastico macio)
GEAR = {
    "glove": ("navy", 0.46, 0.0), "glove_cuff": ("creme", 0.44, 0.0), "boot": ("navy", 0.42, 0.0), "sole": ("creme", 0.55, 0.0),
    "boot_top": ("orange", 0.44, 0.0), "belt": ("navy", 0.40, 0.0), "buckle": ("gold", 0.30, 0.55), "buckle_star": ("navy_emb", 0.32, 0.0),
    "emblem": ("navy_emb", 0.34, 0.0), "emblem_star": ("gold", 0.28, 0.55), "emblem_band": ("creme", 0.36, 0.0),
    "scanner_strap": ("navy", 0.44, 0.0), "scanner": ("navy_lt", 0.36, 0.0), "lupa_ring": ("gold", 0.28, 0.6),
    "lupa_handle": ("navy", 0.38, 0.0), "holster": ("navy", 0.46, 0.0), "pouch": ("navy", 0.48, 0.0), "notebook": ("orange", 0.50, 0.0),
    "pouch_star": ("gold", 0.30, 0.55), "pouch_strap": ("navy", 0.46, 0.0), "goggle_band": ("navy", 0.46, 0.0),
    "goggle_cup": ("navy_lt", 0.36, 0.0), "goggle_rim": ("gold", 0.28, 0.6), "hair_ties": ("orange", 0.40, 0.0),
    "visor_band": ("navy", 0.46, 0.0), "visor_frame": ("navy", 0.36, 0.0), "visor_pivot": ("gold", 0.3, 0.55),
}
TEX_RES = {"suit": 2048, "gear": 2048, "skin": 1024, "hair": 1024}


def lin(hexcol):
    return np.array(hex_to_linear(hexcol))


# ------------------------------------------------------------------ juntar por grupo
def set_part_attr(ob):
    me = ob.data
    pid = PID.get(ob.get("rbpart", "none"), 0)
    a = me.attributes.get("rbpart") or me.attributes.new("rbpart", "FLOAT", "POINT")
    a.data.foreach_set("value", np.full(len(me.vertices), pid / 100.0, dtype=np.float32))


def join_groups(objs, prefix="Rastro"):
    groups = {}
    for ob in objs:
        set_part_attr(ob)
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
        ob = bpy.context.view_layer.objects.active if len(obs) > 1 else obs[0]
        ob.name = "%s_%s" % (prefix, g.capitalize()) if g != "face" else prefix + "_Face"
        ob.data.name = ob.name
        ob["rbgroup"] = g
        out[g] = ob
    return out


def uv_unwrap(ob, margin=0.004):
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    me = ob.data
    while len(me.uv_layers) > 1:
        me.uv_layers.remove(me.uv_layers[-1])
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=margin, area_weight=0.0, correct_aspect=True,
                             scale_to_bounds=False)
    bpy.ops.uv.pack_islands(rotate=True, margin=margin)
    bpy.ops.object.mode_set(mode="OBJECT")


# ------------------------------------------------------------------ bake (Cycles)
def _cycles_bake_setup(samples=1):
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = samples
    sc.cycles.use_denoising = False
    sc.render.bake.margin = 6
    sc.render.bake.margin_type = "EXTEND"
    sc.render.bake.use_clear = True
    sc.render.bake.target = "IMAGE_TEXTURES"


def new_image(name, res, float_buf=True, color_space="Non-Color"):
    old = bpy.data.images.get(name)
    if old:
        bpy.data.images.remove(old)
    img = bpy.data.images.new(name, res, res, alpha=False, float_buffer=float_buf)
    img.colorspace_settings.name = color_space
    return img


def img_np(img):
    w, h = img.size
    a = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(a)
    return a.reshape(h * w, 4)


def np_img(img, arr):
    w, h = img.size
    a = np.ones((h * w, 4), dtype=np.float32)
    a[:, :arr.shape[1]] = arr
    img.pixels.foreach_set(a.ravel())
    img.update()


def _select_only(ob):
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob


def bake_with(ob, img, builder, bake_type="EMIT", samples=1, extra=None):
    """Troca o material do objeto por um temporario (builder(nt) -> socket ligado a Emission/Normal), assa em `img` e restaura."""
    _cycles_bake_setup(samples)
    saved = list(ob.data.materials)
    tmp = bpy.data.materials.new("rv2_bake_tmp")
    tmp.use_nodes = True
    nt = tmp.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    builder(nt, out)
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = img
    nt.nodes.active = tex
    tex.select = True
    ob.data.materials.clear()
    ob.data.materials.append(tmp)
    for p in ob.data.polygons:
        p.material_index = 0
    _select_only(ob)
    kw = dict(type=bake_type, margin=6, use_clear=True)
    if extra:
        kw.update(extra)
    bpy.ops.object.bake(**kw)
    ob.data.materials.clear()
    for m in saved:
        ob.data.materials.append(m)
    bpy.data.materials.remove(tmp)


def _emit_builder(make_color):
    def b(nt, out):
        em = nt.nodes.new("ShaderNodeEmission")
        em.inputs["Strength"].default_value = 1.0
        nt.links.new(make_color(nt), em.inputs["Color"])
        nt.links.new(em.outputs[0], out.inputs["Surface"])
    return b


def _encoded(nt, sock, scale, offset):
    vm = nt.nodes.new("ShaderNodeVectorMath")
    vm.operation = "MULTIPLY_ADD"
    vm.inputs[1].default_value = (scale, scale, scale)
    vm.inputs[2].default_value = (offset, offset, offset)
    nt.links.new(sock, vm.inputs[0])
    return vm.outputs[0]


def bake_geometry(ob, res):
    """Devolve dict com P (posicao), N (normal suave), part (id inteiro), ao (0..1) por texel e a mascara de cobertura."""
    maps = {}
    img = new_image("rv2_pos", res)

    def pos(nt):
        g = nt.nodes.new("ShaderNodeNewGeometry")
        return _encoded(nt, g.outputs["Position"], 0.25, 0.5)
    bake_with(ob, img, _emit_builder(pos))
    maps["P"] = (img_np(img)[:, :3] - 0.5) / 0.25
    cov = img_np(img)[:, 3]

    def nrm(nt):
        g = nt.nodes.new("ShaderNodeNewGeometry")
        return _encoded(nt, g.outputs["Normal"], 0.5, 0.5)
    bake_with(ob, img, _emit_builder(nrm))
    N = img_np(img)[:, :3] * 2 - 1
    maps["N"] = N / np.maximum(np.linalg.norm(N, axis=1)[:, None], 1e-6)

    def part(nt):
        a = nt.nodes.new("ShaderNodeAttribute")
        a.attribute_name = "rbpart"
        a.attribute_type = "GEOMETRY"
        return a.outputs["Fac"]
    bake_with(ob, img, _emit_builder(part))
    maps["part"] = np.rint(img_np(img)[:, 0] * 100).astype(int)

    # cobertura: texels de fora das ilhas (antes da margem) -> assa um branco sem margem
    img_m = new_image("rv2_mask", res)

    def white(nt):
        rgb = nt.nodes.new("ShaderNodeRGB")
        rgb.outputs[0].default_value = (1, 1, 1, 1)
        return rgb.outputs[0]
    sc = bpy.context.scene
    bake_with(ob, img_m, _emit_builder(white), extra=dict(margin=0))
    maps["mask"] = img_np(img_m)[:, 0] > 0.5
    bpy.data.images.remove(img_m)

    def ao_builder(nt, out):
        bs = nt.nodes.new("ShaderNodeBsdfDiffuse")
        nt.links.new(bs.outputs[0], out.inputs["Surface"])
    # olhos, boca e vidros ficam fora da oclusao (as cascas do olho escureciam a pele em volta)
    hidden = [o for o in bpy.context.scene.objects if o.get("rbgroup") in ("face", "glass", "screen") and not o.hide_render]
    for o in hidden:
        o.hide_render = True
    bake_with(ob, img, ao_builder, bake_type="AO", samples=48)
    for o in hidden:
        o.hide_render = False
    maps["ao"] = img_np(img)[:, 0]
    bpy.data.images.remove(img)
    return maps


def bake_normal_from_height(ob, height, res, name, strength=1.0):
    """Normal map tangente (OpenGL, +Y) a partir do mapa de altura (metros) via Bump no Cycles."""
    himg = new_image(name + "_h", res)
    np_img(himg, np.repeat(height[:, None], 3, axis=1))
    nimg = new_image(name, res, float_buf=False, color_space="Non-Color")

    def b(nt, out):
        t = nt.nodes.new("ShaderNodeTexImage")
        t.image = himg
        t.interpolation = "Cubic"
        bump = nt.nodes.new("ShaderNodeBump")
        bump.inputs["Strength"].default_value = strength
        bump.inputs["Distance"].default_value = 1.0
        nt.links.new(t.outputs["Color"], bump.inputs["Height"])
        bs = nt.nodes.new("ShaderNodeBsdfPrincipled")
        nt.links.new(bump.outputs["Normal"], bs.inputs["Normal"])
        nt.links.new(bs.outputs[0], out.inputs["Surface"])
    bake_with(ob, nimg, b, bake_type="NORMAL", samples=4, extra=dict(normal_space="TANGENT"))
    bpy.data.images.remove(himg)
    return nimg


# ------------------------------------------------------------------ ruidos e padroes (numpy, 3D)
def _hash3(ix, iy, iz):
    h = (ix * 73856093) ^ (iy * 19349663) ^ (iz * 83492791)
    h = (h ^ (h >> 13)) * 1274126177
    return ((h ^ (h >> 16)) & 0xFFFF) / 65535.0


def value_noise(P, scale):
    Q = P / scale
    i = np.floor(Q).astype(np.int64)
    f = Q - i
    f = f * f * (3 - 2 * f)
    out = 0.0
    for dx in (0, 1):
        for dy in (0, 1):
            for dz in (0, 1):
                w = (f[:, 0] if dx else 1 - f[:, 0]) * (f[:, 1] if dy else 1 - f[:, 1]) * (f[:, 2] if dz else 1 - f[:, 2])
                out = out + w * _hash3(i[:, 0] + dx, i[:, 1] + dy, i[:, 2] + dz)
    return out


def fbm(P, scale, octaves=3):
    s, a, tot, out = scale, 1.0, 0.0, 0.0
    for _ in range(octaves):
        out = out + a * value_noise(P, s)
        tot += a
        s *= 0.5
        a *= 0.5
    return out / tot


def weave2d(u, v):
    """Tafeta (sarja simples): fios de urdume e trama alternando por cima e por baixo. Altura 0..1."""
    iu, iv = np.floor(u), np.floor(v)
    fu, fv = u - iu, v - iv
    over = ((iu + iv) % 2 == 0)
    warp = np.sin(np.pi * fv) ** 0.6 * np.where(over, 0.75 + 0.25 * np.sin(np.pi * fu), 0.55 - 0.15 * np.sin(np.pi * fu))
    weft = np.sin(np.pi * fu) ** 0.6 * np.where(~over, 0.75 + 0.25 * np.sin(np.pi * fv), 0.55 - 0.15 * np.sin(np.pi * fv))
    return np.maximum(warp, weft)


def triplanar(P, N, fn, period):
    w = np.abs(N) ** 6
    w /= w.sum(axis=1)[:, None]
    h = w[:, 0] * fn(P[:, 1] / period, P[:, 2] / period) + w[:, 1] * fn(P[:, 0] / period, P[:, 2] / period) + \
        w[:, 2] * fn(P[:, 0] / period, P[:, 1] / period)
    return h


def sstep(x, a, b):
    u = np.clip((x - a) / (b - a), 0, 1)
    return u * u * (3 - 2 * u)


def line(d, w):
    """Perfil de friso/vinco de meia-largura w em funcao da distancia d (1 no centro, 0 fora)."""
    return np.clip(1 - (np.abs(d) / w) ** 2, 0, 1)


def stitches(d, s, offset=0.0032, pitch=0.0042, w=0.00055):
    """Pespontos: duas fileiras de tracos a +-offset de uma costura (d = distancia a costura, s = coordenada ao longo)."""
    dash = sstep(0.62 - np.abs(((s / pitch) % 1.0) - 0.5) * 2.0, 0.0, 0.25)
    return (line(d - offset, w) + line(d + offset, w)) * dash


# ------------------------------------------------------------------ geometria de referencia do corpo
def seg_labels(P, F, limb_segs):
    """Rotulo do segmento mais proximo (0 tronco, 1.. membros), u ao longo, cosseno p/ frente e p/ fora, raio local."""
    segs = [("torso", 0, np.array([0, 0, F.hz - 0.06]), np.array([0, 0, F.nz + 0.02]), 0.132)]
    for kind, s, a, b in limb_segs:
        r = {"upper_arm": 0.050, "forearm": 0.042, "thigh": 0.070, "shin": 0.056}[kind]
        segs.append((kind, 1 if s == "R" else -1, np.array(a), np.array(b), r))
    best = None
    res = []
    for i, (kind, sx, a, b, r) in enumerate(segs):
        d = b - a
        L = np.linalg.norm(d)
        dn = d / L
        u = (P - a) @ dn / L
        proj = a + np.outer(np.clip(u, 0, 1), d)
        rv = P - proj
        rr = np.linalg.norm(rv, axis=1)
        rn = rv / np.maximum(rr[:, None], 1e-9)
        fr = np.array([0.0, 1.0, 0.0]) - dn * dn[1]
        fr /= np.linalg.norm(fr)
        ou = np.array([sx, 0.0, 0.0]) - dn * dn[0] * sx
        ou = ou - fr * (ou @ fr)
        ou /= max(np.linalg.norm(ou), 1e-9)
        score = rr / r
        res.append(dict(kind=kind, sx=sx, u=u, r=rr, f=rn @ fr, o=rn @ ou, L=L, score=score))
        best = score if best is None else np.minimum(best, score)
    lab = np.argmin(np.array([q["score"] for q in res]), axis=0)
    return lab, res


# ------------------------------------------------------------------ pintura por grupo
def paint_suit(m, F, limb_segs):
    P, N, part = m["P"], m["N"], m["part"]
    n = len(P)
    col = np.tile(lin(C["orange"]), (n, 1))
    h = np.zeros(n)
    rough = np.full(n, 0.80)
    lab, res = seg_labels(P, F, limb_segs)
    x, y, z = P[:, 0], P[:, 1], P[:, 2]
    creme, navy = lin(C["creme"]), lin(C["navy"])
    is_suit = part == PID["suit"]
    torso = is_suit & (lab == 0)
    # --- peitoral/cangalha creme: borda em V no peito (ponta no emblema), reta nas costas
    front = sstep(y, -0.02, 0.03)
    vdip = 0.080 * np.clip(1 - np.abs(x) / 0.120, 0, 1) ** 1.25
    yoke_front = F.nz - 0.052 - vdip
    yoke_back = F.nz - 0.070 - 0.012 * np.clip(1 - np.abs(x) / 0.12, 0, 1)
    yz = yoke_front * front + yoke_back * (1 - front)
    arm_cap = np.zeros(n, bool)
    for i, q in enumerate(res[1:], start=1):
        if q["kind"] == "upper_arm":
            arm_cap |= is_suit & (lab == i) & (q["u"] < 0.10)
    d_yoke = z - yz
    yoke = (torso | arm_cap) & (d_yoke > 0)
    col[yoke] = creme
    # piping azul-marinho na borda da cangalha (friso em relevo)
    pip = (torso | arm_cap) & (np.abs(d_yoke) < 0.0042)
    col[pip] = navy
    h += np.where(torso | arm_cap, 0.00075 * line(d_yoke, 0.0042), 0)
    h -= np.where(torso | arm_cap, 0.00035 * line(np.abs(d_yoke) - 0.0050, 0.0010), 0)
    h += np.where((torso | arm_cap) & (d_yoke > 0), 0.00028 * stitches(d_yoke - 0.0085, x * 0.7 + y * 0.7, 0.0, 0.0042), 0)
    # --- faixas laterais (rastro) em bracos e pernas: creme com friso azul-marinho dos dois lados
    for i, q in enumerate(res[1:], start=1):
        sel = is_suit & (lab == i)
        if not sel.any():
            continue
        kind = q["kind"]
        arc = q["r"] * np.arccos(np.clip(q["o"], -1, 1))
        half = 0.011 if kind in ("thigh", "shin") else 0.0085
        if kind == "upper_arm":
            sel_s = sel & (q["u"] > 0.06)
        else:
            sel_s = sel
        stripe = sel_s & (arc < half)
        col[stripe] = creme
        edge = sel_s & (np.abs(arc - half) < 0.0028)
        col[edge] = navy
        h += np.where(sel_s, 0.0006 * line(arc - half - 0.0002, 0.0030), 0)
        along = q["u"] * q["L"]
        h += np.where(sel_s, 0.00025 * stitches(arc - half - 0.0052, along, 0.0, 0.0042), 0)
        # costura interna (entreperna / parte de dentro do braco)
        arc_in = q["r"] * np.arccos(np.clip(-q["o"], -1, 1))
        h -= np.where(sel, 0.00035 * line(arc_in, 0.0012), 0)
        h += np.where(sel, 0.00022 * stitches(arc_in, along, 0.0030, 0.0042), 0)
        # vincos finos nas articulacoes (normal map) - complementam as dobras modeladas
        ang = np.arctan2(q["o"], q["f"])
        if kind == "upper_arm":
            cre = np.sin(2 * np.pi * (q["L"] - along) / 0.0075 + 1.5 * np.sin(ang * 2)) * sstep(q["u"], 0.72, 0.9) * np.clip(q["f"], 0, 1) ** 2
            h += np.where(sel, 0.00030 * cre, 0)
        if kind == "shin":
            cre = np.sin(2 * np.pi * along / 0.008 + 1.3 * np.sin(ang * 2)) * (1 - sstep(q["u"], 0.05, 0.16)) * np.clip(-q["f"], 0, 1) ** 2
            h += np.where(sel, 0.00032 * cre, 0)
        if kind == "thigh":
            # costura do quadril (onde a perna nasce)
            d_hip = (q["u"] - 0.06) * q["L"]
            h -= np.where(sel, 0.0003 * line(d_hip, 0.0012), 0)
    # --- costuras do tronco: laterais e centro das costas
    th = np.arctan2(x, y)
    r_t = np.hypot(x, y)
    for c0 in (math.pi / 2, -math.pi / 2, math.pi):
        dd = r_t * np.angle(np.exp(1j * (th - c0)))
        sel = torso & ~yoke
        h -= np.where(sel, 0.0003 * line(dd, 0.0012), 0)
        h += np.where(sel, 0.0002 * stitches(dd, z, 0.0030, 0.0042), 0)
    # rugas leves de franzido logo acima do cinto
    belt_z = F.hz + 0.030
    wr = np.sin(th * 22 + 4 * np.sin(th * 3)) * line(z - belt_z - 0.028, 0.012)
    h += np.where(torso, 0.00025 * wr, 0)
    # --- estrela azul-marinho de 4 pontas pintada no centro da cangalha das costas (identidade de equipe de costas)
    back_c = np.array([0.0, F.nz - 0.035])
    q2 = np.stack([x - back_c[0], z - back_c[1]], axis=1)
    rho = np.linalg.norm(q2, axis=1)
    th2 = np.arctan2(q2[:, 1], q2[:, 0])
    delta = np.abs(((th2 + np.pi / 4) % (np.pi / 2)) - np.pi / 4)     # distancia angular a ponta mais proxima
    r_star = 0.010 + 0.026 * (1 - delta / (np.pi / 4)) ** 2.2           # rosa dos ventos de 4 pontas finas
    star_b = torso & (y < -0.02) & (rho < r_star)
    col[star_b] = lin(C["navy"])
    h += np.where(torso & (y < -0.02), 0.0002 * line(rho - r_star, 0.0012), 0)
    # --- gola em pe: creme, com piping na borda de cima
    is_col = part == PID["collar"]
    col[is_col] = creme
    # --- abas de casaco: fora laranja, forro creme (lado virado para o corpo)
    is_tail = part == PID["tail"]
    inward = (N[:, 1] > 0.15)
    col[is_tail & inward] = creme
    # trama do tecido (fina) e variacao baixa de cor
    weave = triplanar(P, N, weave2d, 0.0026)
    h += 0.00018 * weave
    mott = fbm(P, 0.05, 3)
    col *= (0.96 + 0.07 * mott)[:, None]
    col *= (0.94 + 0.06 * weave)[:, None]
    rough = 0.82 - 0.08 * weave + 0.04 * mott
    rough = np.where(pip, 0.62, rough)
    # oclusao dos cantos escurece de leve a cor (o mapa vai inteiro no canal de oclusao)
    col *= (0.82 + 0.18 * m["ao"] ** 0.8)[:, None]
    metal = np.zeros(n)
    return col, h, rough, metal


def paint_gear(m, F):
    P, N, part = m["P"], m["N"], m["part"]
    n = len(P)
    col = np.zeros((n, 3))
    rough = np.zeros(n)
    metal = np.zeros(n)
    h = np.zeros(n)
    for name, (cname, r, mt) in GEAR.items():
        sel = part == PID[name]
        col[sel] = lin(C[cname])
        rough[sel] = r
        metal[sel] = mt
    x, y, z = P[:, 0], P[:, 1], P[:, 2]
    # bota: biqueira azul mais clara com pesponto e vinco
    boot = part == PID["boot"]
    toe_line = F.ball_y - 0.018 + 0.012 * np.cos(np.clip((np.abs(x) - F.hip_x) / 0.06, -1.5, 1.5))
    d_toe = y - toe_line
    col[boot & (d_toe > 0)] = lin(C["navy_lt"])
    h -= np.where(boot, 0.0005 * line(d_toe, 0.0018), 0)
    h += np.where(boot, 0.00025 * stitches(d_toe, x, 0.0035, 0.0045), 0)
    # sola: frisos horizontais na lateral (cravo da sola)
    sole = part == PID["sole"]
    h -= np.where(sole, 0.0004 * line(((z / 0.0065) % 1.0) - 0.5, 0.12), 0)
    # cinto e tiras: pespontos nas bordas
    for nm, half in (("belt", 0.0105), ("pouch_strap", 0.0)):
        sel = part == PID[nm]
        if nm == "belt":
            dz = z - (F.hz + 0.030)
            h += np.where(sel, 0.0002 * (stitches(dz - 0.006, np.arctan2(x, y) * 0.13, 0.0, 0.0040)), 0)
    # bolsa: aba com vinco e pesponto
    pouch = part == PID["pouch"]
    flap = F.hz - 0.085 + 0.018
    h -= np.where(pouch, 0.0005 * line(z - flap, 0.0016), 0)
    h += np.where(pouch, 0.0002 * stitches(z - flap, y, 0.0035, 0.0042), 0)
    # caderno: paginas creme na lateral (fora da capa)
    nb = part == PID["notebook"]
    pages = nb & (np.abs(N[:, 0]) < 0.6) & (N[:, 2] < 0.6)
    col[pages] = lin(C["creme"])
    h -= np.where(pages, 0.00015 * (np.sin(z / 0.0012 * 2 * np.pi) > 0.6), 0)
    # luva: costuras no dorso dos dedos e no punho
    glove = part == PID["glove"]
    # vinil: micro variacao suave (sem casca de laranja forte)
    nz_ = fbm(P, 0.03, 2)
    h += 0.00004 * fbm(P, 0.004, 2)
    rough = rough + 0.05 * (nz_ - 0.5)
    col *= (0.97 + 0.05 * nz_)[:, None]
    col *= (0.85 + 0.15 * m["ao"] ** 0.8)[:, None]
    return col, h, rough, metal


def paint_skin(m, F):
    P, N = m["P"], m["N"]
    n = len(P)
    col = np.tile(lin(C["skin"]), (n, 1))
    hc = np.array(F.hc)
    k = F.k
    # rubor nas bochechas (degrade macio pintado, sem malha por cima)
    for sx in (1, -1):
        c = hc + np.array([sx * 0.098 * k, 0.15 * k, -0.082 * k])
        d = np.linalg.norm((P - c) / np.array([0.050, 0.08, 0.034]) / k, axis=1)
        w = np.exp(-d ** 2 * 1.6) * (P[:, 1] > hc[1])
        col = col * (1 - 0.55 * w[:, None]) + lin(C["blush"]) * 0.55 * w[:, None]
    # nariz, orelhas e queixo levemente mais quentes
    for c, s, a in (((0, 0.18 * k, -0.07 * k), 0.03 * k, 0.25), ((0.2 * k, -0.006, -0.03 * k), 0.035 * k, 0.25),
                    ((-0.2 * k, -0.006, -0.03 * k), 0.035 * k, 0.25)):
        d = np.linalg.norm(P - (hc + np.array(c)), axis=1) / s
        w = np.exp(-d ** 2) * a
        col = col * (1 - w[:, None]) + lin(C["blush"]) * w[:, None]
    mott = fbm(P, 0.03, 3)
    col *= (0.97 + 0.05 * mott)[:, None]
    col *= (0.86 + 0.14 * m["ao"] ** 0.7)[:, None]
    rough = 0.50 + 0.06 * (mott - 0.5)
    h = 0.00003 * fbm(P, 0.0025, 2)
    return col, h, rough, np.zeros(n)


def paint_hair(m, F, tail_axes):
    P, N = m["P"], m["N"]
    n = len(P)
    hc = np.array(F.hc)
    k = F.k
    # direcao dos fios: azimute em torno do eixo que sai do redemoinho (alto, um pouco para tras)
    crown = hc + np.array([0.0, -0.06 * k, 0.24 * k])
    v = P - crown
    az = np.arctan2(v[:, 0], v[:, 1] + 0.001)
    strands = np.sin(az * 46 + 2.0 * np.sin(az * 5)) * 0.5 + 0.5
    fine = np.sin(az * 140 + 6 * fbm(P, 0.02, 2)) * 0.5 + 0.5
    # marias-chiquinhas: fios ao longo do eixo de cada uma
    for sx, pts in tail_axes:
        A = np.array([p[:] for p, r in pts])
        best = np.full(n, 9.0)
        ang = np.zeros(n)
        for i in range(len(A) - 1):
            a, b = A[i], A[i + 1]
            d = b - a
            L = np.linalg.norm(d)
            dn = d / L
            u = np.clip((P - a) @ dn / L, 0, 1)
            rv = P - (a + np.outer(u, d))
            dist = np.linalg.norm(rv, axis=1)
            ref = np.cross(dn, [1.0, 0, 0])
            ref /= np.linalg.norm(ref)
            ref2 = np.cross(dn, ref)
            aa = np.arctan2(rv @ ref2, rv @ ref)
            closer = dist < best
            best = np.where(closer, dist, best)
            ang = np.where(closer, aa, ang)
        inside = best < 0.055 * k
        w = sstep(-best, -0.055 * k, -0.035 * k)
        strands = strands * (1 - w) + (np.sin(ang * 9) * 0.5 + 0.5) * w
        fine = fine * (1 - w) + (np.sin(ang * 26) * 0.5 + 0.5) * w
    h = 0.0012 * strands ** 1.5 + 0.00035 * fine
    col = np.tile(lin(C["hair"]), (n, 1))
    col = col * (0.85 + 0.30 * strands[:, None])
    col *= (0.75 + 0.25 * m["ao"] ** 0.8)[:, None]
    rough = 0.42 - 0.08 * strands
    return col, h, rough, np.zeros(n)


# ------------------------------------------------------------------ materiais finais
def save_img(img, path, fmt="PNG", quality=92):
    img.filepath_raw = path
    img.file_format = fmt
    sc = bpy.context.scene
    sc.render.image_settings.quality = quality
    if fmt == "JPEG":
        img.save_render(path, scene=sc) if False else None
    img.save()
    return path


def to_srgb(c):
    c = np.clip(c, 0, 1)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * np.power(c, 1 / 2.4) - 0.055)


def build_images(name, res, col, rough, metal, ao, mask):
    """Imagens de 8 bits: cor (sRGB) e ORM (R oclusao, G rugosidade, B metalico)."""
    cimg = new_image(name + "_color", res, float_buf=False, color_space="sRGB")
    # o buffer de 8 bits do Blender recebe valores lineares e converte para sRGB na gravacao? Nao: pixels sao armazenados
    # como estao; por isso a cor vai convertida para sRGB aqui.
    np_img(cimg, to_srgb(col))
    oimg = new_image(name + "_orm", res, float_buf=False, color_space="Non-Color")
    orm = np.stack([np.clip(0.35 + 0.65 * ao, 0, 1), np.clip(rough, 0.05, 1), np.clip(metal, 0, 1)], axis=1)
    np_img(oimg, orm)
    return cimg, oimg


def gltf_output_group():
    """Grupo 'glTF Material Output' reconhecido pelo exportador do Blender (entrada Occlusion)."""
    ng = bpy.data.node_groups.get("glTF Material Output")
    if ng:
        return ng
    ng = bpy.data.node_groups.new("glTF Material Output", "ShaderNodeTree")
    ng.interface.new_socket("Occlusion", in_out="INPUT", socket_type="NodeSocketFloat")
    ng.interface.new_socket("Thickness", in_out="INPUT", socket_type="NodeSocketFloat")
    return ng


def pbr_material(name, cimg, nimg, oimg, coat=0.0, coat_rough=0.3, normal_strength=1.0, emission=None, alpha=None):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    m.use_backface_culling = True
    nt = m.node_tree
    b = nt.nodes["Principled BSDF"]
    if cimg is not None:
        t = nt.nodes.new("ShaderNodeTexImage")
        t.image = cimg
        nt.links.new(t.outputs["Color"], b.inputs["Base Color"])
    if oimg is not None:
        t = nt.nodes.new("ShaderNodeTexImage")
        t.image = oimg
        sep = nt.nodes.new("ShaderNodeSeparateColor")
        nt.links.new(t.outputs["Color"], sep.inputs[0])
        nt.links.new(sep.outputs["Green"], b.inputs["Roughness"])
        nt.links.new(sep.outputs["Blue"], b.inputs["Metallic"])
        g = nt.nodes.new("ShaderNodeGroup")
        g.node_tree = gltf_output_group()
        nt.links.new(sep.outputs["Red"], g.inputs["Occlusion"])
    if nimg is not None:
        t = nt.nodes.new("ShaderNodeTexImage")
        t.image = nimg
        nm = nt.nodes.new("ShaderNodeNormalMap")
        nm.inputs["Strength"].default_value = normal_strength
        nt.links.new(t.outputs["Color"], nm.inputs["Color"])
        nt.links.new(nm.outputs["Normal"], b.inputs["Normal"])
    b.inputs["Coat Weight"].default_value = coat
    b.inputs["Coat Roughness"].default_value = coat_rough
    if emission is not None:
        b.inputs["Emission Color"].default_value = emission + (1,)
        b.inputs["Emission Strength"].default_value = 1.0
    if alpha is not None:
        b.inputs["Alpha"].default_value = alpha
        m.blend_method = "BLEND" if hasattr(m, "blend_method") else None
        try:
            m.surface_render_method = "BLENDED"
        except AttributeError:
            pass
    return m


def factor_material(name, hexcol, rough, metal=0.0, coat=0.0, coat_rough=0.3, emission=0.0, alpha=None):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    m.use_backface_culling = True
    b = m.node_tree.nodes["Principled BSDF"]
    c = hex_to_linear(hexcol) + (1.0,)
    b.inputs["Base Color"].default_value = c
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    b.inputs["Coat Weight"].default_value = coat
    b.inputs["Coat Roughness"].default_value = coat_rough
    if emission > 0:
        b.inputs["Emission Color"].default_value = c
        b.inputs["Emission Strength"].default_value = emission
    if alpha is not None:
        b.inputs["Alpha"].default_value = alpha
        try:
            m.surface_render_method = "BLENDED"
        except AttributeError:
            pass
    m.diffuse_color = c
    return m


def texture_group(ob, group, res, builder, tex_dir):
    """UV + mapas + pintura + normal; devolve o material PBR do grupo."""
    import time
    t0 = time.time()
    uv_unwrap(ob, margin=0.003 if res >= 2048 else 0.005)
    m = bake_geometry(ob, res)
    t1 = time.time()
    if group == "suit":
        col, h, rough, metal = paint_suit(m, builder.F, builder.limb_segs)
    elif group == "gear":
        col, h, rough, metal = paint_gear(m, builder.F)
    elif group == "skin":
        col, h, rough, metal = paint_skin(m, builder.F)
    else:
        col, h, rough, metal = paint_hair(m, builder.F, builder.tail_axes)
    t2 = time.time()
    name = "rastro_v2_" + group
    nimg = bake_normal_from_height(ob, h, res, name + "_normal")
    cimg, oimg = build_images(name, res, col, rough, metal, m["ao"], m["mask"])
    t3 = time.time()
    print("TEX %s res=%d uv+geo=%.1fs pintura=%.1fs normal+img=%.1fs" % (group, res, t1 - t0, t2 - t1, t3 - t2))
    os.makedirs(tex_dir, exist_ok=True)
    for img, suf in ((cimg, "color"), (nimg, "normal"), (oimg, "orm")):
        p = os.path.join(tex_dir, "%s_%s.png" % (name, suf))
        img.filepath_raw = p
        img.file_format = "PNG"
        img.save()
    coat = {"suit": 0.0, "gear": 0.55, "skin": 0.30, "hair": 0.45}[group]
    coat_r = {"suit": 0.5, "gear": 0.28, "skin": 0.35, "hair": 0.30}[group]
    return pbr_material("mat_" + name, cimg, nimg, oimg, coat=coat, coat_rough=coat_r)
