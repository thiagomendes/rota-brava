"""Leme v2: UV, mapas assados e materiais PBR padrao do glTF. PROPOSTA PROVISORIA.

Mesmo fluxo do Rastro v2 (as utilidades genericas foram copiadas de source_art/characters/rastro_v2/rv2_tex.py, sem
importar de la, para que mudancas no Rastro nao quebrem a Leme), com pintura propria:
 1. junta as partes por grupo de material (traje = tecidos, equipamento = vinil/plastico/metal, pele, cabelo; vidro e rosto a parte);
 2. UV por Smart UV Project + empacotamento;
 3. assa no Cycles (CPU) mapas de GEOMETRIA por texel: posicao, normal, parte (atributo rbpart) e oclusao (AO);
 4. pinta em numpy, por texel e em coordenadas 3D: algodao (camisa), sarja (bermuda), canelado (meia), nailon ripstop
    (colete) com canais costurados e faixas refletivas, pespontos, bolsos, botoes, palma mais clara, cachos em helice;
 5. assa a normal map em espaco tangente (MikkTSpace) a partir da altura no Cycles;
 6. Principled BSDF com base color, normal, ORM (R oclusao, G rugosidade, B metalico) e verniz (Coat -> KHR_materials_clearcoat).
Nenhuma imagem de terceiros.
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
C = dict(white="#F7FBFF", blue="#2F8CFF", deep="#1F5FBF", navy="#1F3A5F", navy_lt="#2B5285", navy_emb="#123A5E", navy_dk="#142B4A",
         gold="#FFC83D", silver="#D2DDE6", skin="#8C5634", blush="#B8624F", palm="#C08A68", hair="#1E1410", hair_lt="#5A3826",
         red="#E2473B", whistle="#FFB020", cyan="#7FE3FF")

PARTS = ["none", "shirt", "shorts", "skin_limb", "sock", "sleeve_band", "shorts_hem", "sock_top", "vest", "vest_rim", "collar_pillow",
         "cap_crown", "shirt_collar", "skin_head", "skin_neck", "hand", "hair", "hair_tie", "cap_band", "cap_visor", "cap_cord",
         "cap_badge", "cap_star", "vest_strap", "vest_buckle", "whistle", "whistle_cord", "emblem", "emblem_star", "emblem_band",
         "belt", "buckle", "buckle_star", "boot", "sole", "boot_collar", "laces", "eyelets", "compass_strap", "compass",
         "compass_dial", "compass_needle", "compass_glass", "bracelet_a", "bracelet_b", "face"]
PID = {n: i for i, n in enumerate(PARTS)}

# cor base, rugosidade, metalico por parte do grupo "gear" (vinil/plastico macio/metal dourado)
GEAR = {
    "hair_tie": ("blue", 0.40, 0.0), "cap_band": ("navy", 0.42, 0.0), "cap_visor": ("navy_dk", 0.20, 0.0), "cap_cord": ("gold", 0.30, 0.6),
    "cap_badge": ("navy_emb", 0.32, 0.0), "cap_star": ("gold", 0.28, 0.55), "vest_strap": ("navy", 0.50, 0.0),
    "vest_buckle": ("white", 0.40, 0.0), "whistle": ("whistle", 0.30, 0.0), "whistle_cord": ("white", 0.55, 0.0),
    "emblem": ("navy_emb", 0.34, 0.0), "emblem_star": ("gold", 0.28, 0.55), "emblem_band": ("white", 0.36, 0.0),
    "belt": ("navy", 0.44, 0.0), "buckle": ("gold", 0.30, 0.55), "buckle_star": ("navy_emb", 0.32, 0.0),
    "boot": ("navy", 0.40, 0.0), "sole": ("white", 0.58, 0.0), "boot_collar": ("blue", 0.46, 0.0), "laces": ("white", 0.60, 0.0),
    "eyelets": ("gold", 0.30, 0.6), "compass_strap": ("navy", 0.46, 0.0), "compass": ("gold", 0.26, 0.65),
    "compass_dial": ("white", 0.35, 0.0), "compass_needle": ("white", 0.35, 0.0), "bracelet_a": ("blue", 0.55, 0.0),
    "bracelet_b": ("white", 0.55, 0.0),
}
TEX_RES = {"suit": 2048, "gear": 2048, "skin": 2048, "hair": 1024}


def lin(hexcol):
    return np.array(hex_to_linear(hexcol))


# ------------------------------------------------------------------ juntar por grupo
def set_part_attr(ob):
    me = ob.data
    pid = PID.get(ob.get("rbpart", "none"), 0)
    a = me.attributes.get("rbpart") or me.attributes.new("rbpart", "FLOAT", "POINT")
    a.data.foreach_set("value", np.full(len(me.vertices), pid / 100.0, dtype=np.float32))


def join_groups(objs, prefix="Leme"):
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
    tmp = bpy.data.materials.new("lv2_bake_tmp")
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
    img = new_image("lv2_pos", res)

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
    img_m = new_image("lv2_mask", res)

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



# ------------------------------------------------------------------ pintura por grupo (Leme v2)
def _cyl(P):
    x, y = P[:, 0], P[:, 1]
    return np.arctan2(x, y), np.hypot(x, y)


def twill2d(u, v):
    """Sarja (diagonal) para a bermuda."""
    d = (u + v) % 4.0
    return 0.5 + 0.5 * np.sin(np.pi * d / 2.0) ** 2 * np.sin(np.pi * (u % 1.0))


def ripstop(P, N, cell=0.0045, w=0.00035):
    """Grade do nailon ripstop (colete): linhas finas mais altas a cada `cell` metros (triplanar)."""
    def g(u, v):
        du = np.abs(((u + 0.5) % 1.0) - 0.5)
        dv = np.abs(((v + 0.5) % 1.0) - 0.5)
        return np.maximum(line(du, w / cell), line(dv, w / cell))
    return triplanar(P, N, g, cell)


def rib(P, period=0.0030):
    """Canelado da meia (colunas verticais)."""
    th, r = _cyl(P)
    return 0.5 + 0.5 * np.sin(2 * np.pi * (th * r) / period)


def paint_suit(m, b):
    F = b.F
    P, N, part = m["P"], m["N"], m["part"]
    n = len(P)
    x, y, z = P[:, 0], P[:, 1], P[:, 2]
    col = np.zeros((n, 3))
    h = np.zeros(n)
    rough = np.full(n, 0.80)
    metal = np.zeros(n)
    white, blue, deep, navy, silver = lin(C["white"]), lin(C["blue"]), lin(C["deep"]), lin(C["navy"]), lin(C["silver"])
    th, r_t = _cyl(P)
    sel = lambda nm: part == PID[nm]
    # --- camisa (algodao branco, trama fina), costuras laterais, carcela com botoes no decote em V, costura do ombro
    shirt = sel("shirt") | sel("shirt_collar")
    col[shirt] = white
    wv = triplanar(P, N, weave2d, 0.0022)
    h += np.where(shirt, 0.00016 * wv, 0)
    torso = sel("shirt") & (np.abs(x) < 0.12)
    for c0 in (math.pi / 2, -math.pi / 2):
        dd = r_t * np.angle(np.exp(1j * (th - c0)))
        h -= np.where(torso, 0.0003 * line(dd, 0.0012), 0)
        h += np.where(torso, 0.0002 * stitches(dd, z, 0.0030, 0.0042), 0)
    plk = sel("shirt") & (y > 0) & (np.abs(x) < 0.03)
    h -= np.where(plk, 0.00035 * (line(x - 0.009, 0.0010) + line(x + 0.009, 0.0010)), 0)
    for bz in (F.nz - 0.040, F.nz - 0.075):
        d_b = np.hypot(x, z - bz)
        btn = plk & (d_b < 0.0042)
        col[btn] = lin(C["deep"])
        h += np.where(plk, 0.0006 * line(d_b, 0.0042), 0)
    yoke = sel("shirt") & (y < 0) & (z > F.nz - 0.06)
    h -= np.where(sel("shirt"), 0.0003 * line(z - (F.nz - 0.035), 0.0012) * (y < 0), 0)
    # --- vivo azul da manga e barra/punho das meias
    col[sel("sleeve_band")] = blue
    # --- bermuda (sarja azul), faixa lateral branca fina, bolsos com pesponto, barra dobrada
    sh_ = sel("shorts") | sel("shorts_hem")
    col[sh_] = deep
    tw = triplanar(P, N, twill2d, 0.0018)
    h += np.where(sh_, 0.00020 * tw, 0)
    for sx in (1, -1):
        hx = sx * F.hip_x
        side = sel("shorts") & (x * sx > 0.02)
        ang = np.arctan2(y - 0.0, (x - hx) * sx)          # 0 = lado de fora
        arc = np.hypot(x - hx, y) * np.abs(ang)
        stripe = side & (arc < 0.0045) & (z < F.hz + 0.02)
        col[stripe] = white
        h += np.where(side & (z < F.hz + 0.02), 0.0005 * line(arc - 0.0045, 0.0012), 0)
        # bolso da frente (corte inclinado)
        pk = (z - (F.hz + 0.02)) + 0.9 * ((x * sx) - (F.hip_x + 0.040))
        front = sel("shorts") & (y > 0.02) & (x * sx > 0.03) & (z > F.hz - 0.08)
        h -= np.where(front, 0.0005 * line(pk, 0.0014), 0)
        h += np.where(front, 0.00025 * stitches(pk, z, 0.0035, 0.0042), 0)
        # bolso de tras (retangulo com pesponto)
        bx, bz0 = sx * 0.055, F.hz - 0.035
        back = sel("shorts") & (y < -0.02)
        dr = np.maximum(np.abs(x - bx) - 0.030, np.abs(z - bz0) - 0.032)
        h -= np.where(back, 0.0004 * line(dr, 0.0012), 0)
        h += np.where(back, 0.00022 * stitches(dr, x + z, 0.0030, 0.0042), 0)
    h -= np.where(sel("shorts"), 0.0003 * line(z - (F.hz + 0.045), 0.0015), 0)          # cos da cintura
    # --- meias brancas, canelado, duas listras azuis perto do punho
    so = sel("sock") | sel("sock_top")
    col[so] = white
    rb = rib(P)
    h += np.where(so, 0.00045 * rb, 0)
    zs = b.z_sock
    for zc in (zs - 0.016, zs - 0.032):
        stp = sel("sock") & (np.abs(z - zc) < 0.0045)
        col[stp] = blue
    # --- colete: nailon ripstop azul, canais costurados, faixas refletivas, vivo branco, estrela nas costas
    vest = sel("vest") | sel("collar_pillow")
    col[vest] = blue
    rp = ripstop(P, N)
    h += np.where(vest, 0.00012 * rp, 0)
    rough = np.where(vest, 0.52 - 0.06 * rp, rough)
    vz = b.vest_z
    isv = sel("vest")
    ang_d = np.degrees(th)
    rr_ = np.maximum(r_t, 0.05)
    for c0 in (20.0, 40.0, -20.0, -40.0, 158.0, -158.0):
        dc = np.radians(np.angle(np.exp(1j * np.radians(ang_d - c0)), deg=True)) * rr_
        h += np.where(isv, 0.00022 * (stitches(dc - 0.0040, z, 0.0, 0.0042) + stitches(dc + 0.0040, z, 0.0, 0.0042)), 0)
    for zb in b.reflect_z:
        band = isv & (np.abs(z - zb) < 0.0062)
        col[band] = silver
        rough = np.where(band, 0.30, rough)
        bead = value_noise(P, 0.0006)
        col[band] *= (0.88 + 0.22 * bead[band])[:, None]
        h += np.where(isv, 0.00045 * line(np.abs(z - zb) - 0.0062, 0.0011), 0)
        h += np.where(isv, 0.00020 * stitches(np.abs(z - zb) - 0.0075, th * rr_, 0.0, 0.0042), 0)
    # estrela de 4 pontas branca com borda azul-marinho no centro das costas (identidade de equipe de costas)
    back_c = np.array([0.0, (vz[0] + vz[4]) * 0.5 + 0.030])
    q2 = np.stack([x - back_c[0], z - back_c[1]], axis=1)
    rho = np.linalg.norm(q2, axis=1)
    th2 = np.arctan2(q2[:, 1], q2[:, 0])
    delta = np.abs(((th2 + np.pi / 4) % (np.pi / 2)) - np.pi / 4)
    r_star = 0.010 + 0.032 * (1 - delta / (np.pi / 4)) ** 2.0
    onb = isv & (y < -0.03)
    col[onb & (rho < r_star + 0.0035)] = navy
    col[onb & (rho < r_star)] = white
    h += np.where(onb, 0.0003 * line(rho - r_star - 0.0035, 0.0012), 0)
    # gola-travesseiro: costura ao longo do alto
    cp = sel("collar_pillow")
    h += np.where(cp, 0.0002 * fbm(P, 0.01, 2), 0)
    # vivo branco
    col[sel("vest_rim")] = white
    rough = np.where(sel("vest_rim"), 0.55, rough)
    # --- copa do bone (sarja branca) com vivo na borda mais larga
    cc = sel("cap_crown")
    col[cc] = white
    h += np.where(cc, 0.00016 * wv, 0)
    loc = (P - np.array(b.cap_m.translation)) @ np.array(b.cap_m.to_3x3())   # coordenadas do bone (aprox. sem escala)
    zc_ = loc[:, 2]
    k = F.k
    h += np.where(cc, 0.0005 * line(zc_ - 0.072 * k, 0.0020), 0)
    h += np.where(cc, 0.00022 * stitches(zc_ - 0.064 * k, np.arctan2(loc[:, 0], loc[:, 1]) * 0.2, 0.0, 0.0042), 0)
    # tecido: variacao baixa e oclusao leve na cor
    mott = fbm(P, 0.05, 3)
    col *= (0.96 + 0.06 * mott)[:, None]
    fab = shirt | sh_ | so | cc
    col *= np.where(fab, 0.95 + 0.05 * wv, 1.0)[:, None]
    rough = np.where(fab, 0.84 - 0.08 * wv + 0.04 * mott, rough)
    col *= (0.82 + 0.18 * m["ao"] ** 0.8)[:, None]
    return col, h, rough, metal


def paint_gear(m, b):
    F = b.F
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
    # botina: biqueira mais clara com pesponto, costura do calcanhar
    boot = part == PID["boot"]
    ax_ = np.abs(x)
    toe_line = F.ball_y - 0.010 + 0.010 * np.cos(np.clip((ax_ - F.foot_x) / 0.05, -1.5, 1.5))
    d_toe = y - toe_line
    col[boot & (d_toe > 0)] = lin(C["navy_lt"])
    h -= np.where(boot, 0.0005 * line(d_toe, 0.0018), 0)
    h += np.where(boot, 0.00025 * stitches(d_toe - 0.003, x, 0.0, 0.0045), 0)
    h -= np.where(boot & (y < F.heel_y + 0.02), 0.0004 * line(ax_ - F.foot_x, 0.0012), 0)
    # sola: frisos horizontais e um friso azul (botina nautica)
    sole = part == PID["sole"]
    h -= np.where(sole, 0.0004 * line(((z / 0.0065) % 1.0) - 0.5, 0.12), 0)
    col[sole & (np.abs(z - 0.0135) < 0.0022)] = lin(C["blue"])
    # tiras (webbing): trama em sarja
    web = (part == PID["vest_strap"]) | (part == PID["belt"]) | (part == PID["compass_strap"])
    h += np.where(web, 0.00018 * triplanar(P, N, twill2d, 0.0012), 0)
    dzb = z - b.belt_z
    h += np.where(part == PID["belt"], 0.0002 * (stitches(dzb - 0.012, np.arctan2(x, y) * 0.13, 0.0, 0.0040) +
                                                stitches(dzb + 0.012, np.arctan2(x, y) * 0.13, 0.0, 0.0040)), 0)
    # bussola: mostrador com marcas e rosa dos ventos azul-marinho
    c0, nrm = np.array(b.compass_c), np.array(b.compass_n)
    dial = part == PID["compass_dial"]
    v = P - c0
    vt = v - np.outer(v @ nrm, nrm)
    rr = np.linalg.norm(vt, axis=1)
    e1 = np.cross(nrm, [0.0, 0.0, 1.0])
    e1 /= max(np.linalg.norm(e1), 1e-9)
    e2 = np.cross(nrm, e1)
    an = np.arctan2(vt @ e2, vt @ e1)
    ticks = (np.abs(((an / (2 * np.pi / 16)) + 0.5) % 1.0 - 0.5) < 0.10) & (rr > 0.0150) & (rr < 0.0185)
    col[dial & ticks] = lin(C["navy"])
    delta = np.abs(((an + np.pi / 4) % (np.pi / 2)) - np.pi / 4)
    rs = 0.003 + 0.010 * (1 - delta / (np.pi / 4)) ** 2.4
    col[dial & (rr < rs)] = lin(C["navy_lt"])
    # agulha: metade vermelha
    ndl = part == PID["compass_needle"]
    col[ndl & ((vt @ e2) > 0)] = lin(C["red"])
    # vinil: micro variacao suave
    nz_ = fbm(P, 0.03, 2)
    h += 0.00004 * fbm(P, 0.004, 2)
    rough = rough + 0.05 * (nz_ - 0.5)
    col *= (0.97 + 0.05 * nz_)[:, None]
    col *= (0.85 + 0.15 * m["ao"] ** 0.8)[:, None]
    return col, h, rough, metal


def paint_skin(m, b):
    F = b.F
    P, N, part = m["P"], m["N"], m["part"]
    n = len(P)
    col = np.tile(lin(C["skin"]), (n, 1))
    hc = np.array(F.hc)
    k = F.k
    for sx in (1, -1):
        c = hc + np.array([sx * 0.098 * k, 0.15 * k, -0.082 * k])
        d = np.linalg.norm((P - c) / np.array([0.050, 0.08, 0.034]) / k, axis=1)
        w = np.exp(-d ** 2 * 1.6) * (P[:, 1] > hc[1])
        col = col * (1 - 0.45 * w[:, None]) + lin(C["blush"]) * 0.45 * w[:, None]
    for c, s, a in (((0, 0.18 * k, -0.07 * k), 0.03 * k, 0.22), ((0.2 * k, -0.006, -0.03 * k), 0.035 * k, 0.22),
                    ((-0.2 * k, -0.006, -0.03 * k), 0.035 * k, 0.22)):
        d = np.linalg.norm(P - (hc + np.array(c)), axis=1) / s
        w = np.exp(-d ** 2) * a
        col = col * (1 - w[:, None]) + lin(C["blush"]) * w[:, None]
    # palmas e planta dos dedos mais claras (pele negra); joelhos e cotovelos levemente mais quentes
    hand = part == PID["hand"]
    for sx in (1, -1):
        W, d, f, nn = F.hand_frame(sx)
        near = hand & (np.linalg.norm(P - np.array(W), axis=1) < 0.16) & (P[:, 0] * sx > 0)
        palm = np.clip((N @ np.array(nn)) * 1.4, 0, 1) ** 1.3
        col[near] = col[near] * (1 - 0.55 * palm[near, None]) + lin(C["palm"]) * 0.55 * palm[near, None]
    for kind, s, a, b_ in b.limb_segs:
        if kind in ("forearm", "shin"):
            c = np.array(a)
            w = np.exp(-np.sum((P - c) ** 2, axis=1) / 0.0009) * (part == PID["skin_limb"])
            col = col * (1 - 0.25 * w[:, None]) + lin(C["blush"]) * 0.25 * w[:, None]
    mott = fbm(P, 0.03, 3)
    col *= (0.97 + 0.05 * mott)[:, None]
    col *= (0.86 + 0.14 * m["ao"] ** 0.7)[:, None]
    rough = 0.48 + 0.06 * (mott - 0.5)
    h = 0.00003 * fbm(P, 0.0025, 2)
    return col, h, rough, np.zeros(n)


def paint_hair(m, b):
    """Cachos: cada texel pega o cacho mais proximo e recebe fios em helice em volta de um eixo proprio do cacho."""
    F = b.F
    P, N = m["P"], m["N"]
    n = len(P)
    hc = np.array(F.hc)
    k = F.k
    crown = hc + np.array([0.0, -0.06 * k, 0.24 * k])
    v = P - crown
    az = np.arctan2(v[:, 0], v[:, 1] + 0.001)
    strands = np.sin(az * 46 + 2.0 * np.sin(az * 5)) * 0.5 + 0.5
    fine = np.sin(az * 140 + 6 * fbm(P, 0.02, 2)) * 0.5 + 0.5
    rng = np.random.RandomState(11)
    best = np.full(n, 9.0)
    pat = np.zeros(n)
    pat2 = np.zeros(n)
    centers = [(np.array(c[:]), r) for c, r in b.curls] + [(np.array(b.puff[0][:]), b.puff[1])]
    for c, r in centers:
        axv = rng.normal(size=3)
        axv /= np.linalg.norm(axv)
        e1 = np.cross(axv, [0.3, 0.5, 0.8])
        e1 /= np.linalg.norm(e1)
        e2 = np.cross(axv, e1)
        q = P - c
        d = np.linalg.norm(q, axis=1) / r
        closer = d < best
        a = np.arctan2(q @ e2, q @ e1)
        hgt = (q @ axv) / r
        coil = np.sin(a * 3 + hgt * 9.0 + rng.uniform(0, 6)) * 0.5 + 0.5
        fn = np.sin(a * 18 + hgt * 30.0) * 0.5 + 0.5
        best = np.where(closer, d, best)
        pat = np.where(closer, coil, pat)
        pat2 = np.where(closer, fn, pat2)
    w = sstep(-best, -1.5, -1.05)
    strands = strands * (1 - w) + pat * w
    fine = fine * (1 - w) + pat2 * w
    h = 0.0013 * strands ** 1.4 + 0.00035 * fine
    col = np.tile(lin(C["hair"]), (n, 1))
    col = col * (0.80 + 0.45 * strands[:, None]) + lin(C["hair_lt"]) * (0.10 * fine * strands)[:, None]
    col *= (0.70 + 0.30 * m["ao"] ** 0.8)[:, None]
    rough = 0.46 - 0.10 * strands
    return col, h, rough, np.zeros(n)


def texture_group(ob, group, res, builder, tex_dir):
    """UV + mapas + pintura + normal; devolve o material PBR do grupo."""
    import time
    t0 = time.time()
    uv_unwrap(ob, margin=0.003 if res >= 2048 else 0.005)
    m = bake_geometry(ob, res)
    t1 = time.time()
    fn = {"suit": paint_suit, "gear": paint_gear, "skin": paint_skin, "hair": paint_hair}[group]
    col, h, rough, metal = fn(m, builder)
    t2 = time.time()
    name = "leme_v2_" + group
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
