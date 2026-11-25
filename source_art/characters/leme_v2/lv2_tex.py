"""Leme v2: UV, mapas assados e materiais PBR padrao do glTF. PROPOSTA PROVISORIA.

Mesmo fluxo do Rastro v2 (as utilidades genericas foram copiadas de source_art/characters/rastro_v2/rv2_tex.py, sem
importar de la, para que mudancas no Rastro nao quebrem a Leme), com pintura propria:
 1. junta as partes por grupo de material (traje = tecidos, equipamento = vinil/plastico/metal, pele, cabelo; vidro e rosto a parte);
 2. UV por Smart UV Project + empacotamento;
 3. assa no Cycles (CPU) mapas de GEOMETRIA por texel: posicao, normal, parte (atributo rbpart) e oclusao (AO);
 4. pinta em numpy, por texel e em coordenadas 3D: sarja tecnica (jaqueta e calca de pilota) com recortes, ziper, faixas
    refletivas e pespontos; luvas com protetor nos nos dos dedos; velcro; nailon ripstop (colete, acessorio) com canais
    costurados; gomos do bone; cachos em helice;
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
         gold="#FFC83D", silver="#B9C7D4", skin="#8C5634", blush="#B8624F", palm="#C08A68", hair="#1E1410", hair_lt="#5A3826",
         red="#E2473B", whistle="#2B5285", cyan="#7FE3FF", vest="#FFC83D")

PARTS = ["none", "jacket", "pants", "jacket_collar", "zip_pull", "elbow_pad", "elbow_pad_rim", "knee_pad", "knee_pad_rim",
         "vest", "vest_rim", "collar_pillow", "cap_crown", "skin_head", "skin_neck", "glove", "glove_cuff", "hair", "hair_tie",
         "cap_button", "cap_visor", "cap_badge", "cap_star", "headset_cup", "headset_disc", "headset_pad", "headset_band",
         "headset_toppad", "mic_boom", "mic", "vest_strap", "vest_buckle", "whistle", "whistle_cord", "whistle_slot", "whistle_ring",
         "emblem", "emblem_star", "emblem_band", "belt", "buckle", "buckle_star", "boot", "sole", "boot_collar", "boot_strap",
         "boot_tab", "compass_strap", "compass", "compass_dial", "compass_needle", "compass_glass", "face"]
PID = {n: i for i, n in enumerate(PARTS)}

# cor base, rugosidade, metalico por parte do grupo "gear" (vinil/plastico macio/metal) -- e das pecas de vinil do colete
GEAR = {
    "hair_tie": ("blue", 0.40, 0.0), "cap_button": ("navy", 0.40, 0.0), "cap_visor": ("navy_dk", 0.22, 0.0),
    "cap_badge": ("navy_emb", 0.32, 0.0), "cap_star": ("gold", 0.28, 0.55),
    "headset_cup": ("blue", 0.30, 0.0), "headset_disc": ("white", 0.28, 0.0), "headset_pad": ("navy", 0.55, 0.0),
    "headset_band": ("navy", 0.34, 0.0), "headset_toppad": ("white", 0.50, 0.0), "mic_boom": ("navy", 0.32, 0.0),
    "mic": ("navy_dk", 0.85, 0.0), "zip_pull": ("silver", 0.26, 0.75),
    "elbow_pad": ("navy", 0.42, 0.0), "elbow_pad_rim": ("navy_dk", 0.50, 0.0), "knee_pad": ("white", 0.36, 0.0),
    "knee_pad_rim": ("navy", 0.46, 0.0), "glove": ("white", 0.44, 0.0), "glove_cuff": ("blue", 0.40, 0.0),
    "vest_strap": ("navy", 0.50, 0.0),
    "vest_buckle": ("white", 0.40, 0.0), "whistle": ("whistle", 0.30, 0.0), "whistle_cord": ("navy", 0.55, 0.0), "whistle_slot": ("navy_dk", 0.6, 0.0), "whistle_ring": ("silver", 0.28, 0.6),
    "emblem": ("navy_emb", 0.34, 0.0), "emblem_star": ("gold", 0.28, 0.55), "emblem_band": ("white", 0.36, 0.0),
    "belt": ("navy", 0.44, 0.0), "buckle": ("gold", 0.30, 0.55), "buckle_star": ("navy_emb", 0.32, 0.0),
    "boot": ("blue", 0.36, 0.0), "sole": ("white", 0.58, 0.0), "boot_collar": ("white", 0.46, 0.0), "boot_strap": ("navy", 0.55, 0.0),
    "boot_tab": ("silver", 0.30, 0.0), "compass_strap": ("navy", 0.46, 0.0), "compass": ("gold", 0.26, 0.65),
    "compass_dial": ("white", 0.35, 0.0), "compass_needle": ("white", 0.35, 0.0),
}
# acessorios por missao (D16): grupo -> nome do no no GLB (objeto proprio, oculto por padrao na Godot pelo prefixo Acc_)
ACC = {"acc_lifevest": "Acc_LifeVest"}
ACC_SUIT_PARTS = ("vest", "vest_rim", "collar_pillow")
TEX_RES = {"suit": 2048, "gear": 2048, "skin": 1024, "hair": 1024, "acc_lifevest": 1024}


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
        ob.name = ACC[g] if g in ACC else ("%s_%s" % (prefix, g.capitalize()) if g != "face" else prefix + "_Face")
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


def _seg_uv(P, a, b):
    a, b = np.asarray(a, float), np.asarray(b, float)
    d = b - a
    L = np.linalg.norm(d)
    dn = d / L
    u = (P - a) @ dn / L
    proj = a + np.outer(np.clip(u, 0, 1), d)
    return u, np.linalg.norm(P - proj, axis=1)


def paint_suit(m, b):
    """Tecidos (D16): jaqueta de pilota em sarja tecnica azul (ombros brancos, laterais azul-marinho, ziper, faixas
    refletivas no peito e nos bracos, pespontos nos recortes), calca em sarja azul (vivo branco lateral, bolsos), gola alta
    branca com friso, copa do bone em gomos. As pecas do colete (acessorio) pintadas como antes."""
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
    wv = triplanar(P, N, weave2d, 0.0022)
    tw = triplanar(P, N, twill2d, 0.0018)
    # --- jaqueta: sarja tecnica azul
    jk = sel("jacket")
    col[jk] = blue
    h += np.where(jk, 0.00018 * tw, 0)
    segs = {(kind, s): (np.array(a), np.array(bb)) for kind, s, a, bb in b.limb_segs}
    on_arm = np.zeros(n, bool)
    for s in ("R", "L"):
        a, bb = segs[("upper_arm", s)]
        u, d = _seg_uv(P, a, bb)
        a2, b2 = segs[("forearm", s)]
        u2, d2 = _seg_uv(P, a2, b2)
        arm = jk & (((u > 0.12) & (d < 0.075)) | ((u2 > -0.1) & (d2 < 0.07))) & (np.abs(x) > F.sh.x * 0.88)   # so o braco, nao o peito
        on_arm |= arm
        # faixa refletiva no braco (acima da cotoveleira) com pesponto dos dois lados
        band = arm & (np.abs(u - 0.46) * np.linalg.norm(bb - a) < 0.0075) & (d < 0.075)
        col[band] = silver
        rough = np.where(band, 0.30, rough)
        dd = np.abs(u - 0.46) * np.linalg.norm(bb - a) - 0.0075
        h += np.where(arm & (u > 0.3) & (u < 0.62), 0.00045 * line(dd, 0.0011) + 0.0002 * stitches(dd - 0.0018, th * r_t, 0.0, 0.0042), 0)
    torso = jk & ~on_arm
    # ombros (canesu) brancos: recorte acima da linha do ombro, frente e costas, descendo um pouco pelo alto da manga
    zy = F.sh.z + 0.004 - 0.010 * sstep(np.abs(x), 0.10, 0.17)
    yoke = torso & (z > zy)
    col[yoke] = white
    dy_ = z - zy
    h -= np.where(torso, 0.00035 * line(dy_, 0.0012), 0)
    h += np.where(torso, 0.00022 * stitches(dy_ - 0.0028, x + y, 0.0, 0.0042), 0)
    # laterais azul-marinho (recortes sob os bracos)
    ang = np.degrees(np.abs(th))
    side = torso & (ang > 68) & (ang < 112) & (z < F.sh.z - 0.045)
    col[side] = navy
    for c0 in (68.0, 112.0):
        dc = np.radians(ang - c0) * np.maximum(r_t, 0.05)
        h -= np.where(torso & (z < F.sh.z - 0.045), 0.00035 * line(dc, 0.0012), 0)
        h += np.where(torso & (z < F.sh.z - 0.045), 0.00022 * stitches(np.abs(dc) - 0.0028, z, 0.0, 0.0042), 0)
    # faixa refletiva do peito (volta inteira no tronco), com vivos
    zc = F.hz + 0.120
    rb = torso & (np.abs(z - zc) < 0.0075)
    col[rb] = silver
    rough = np.where(rb, 0.30, rough)
    bead = value_noise(P, 0.0006)
    col[rb] *= (0.88 + 0.22 * bead[rb])[:, None]
    h += np.where(torso, 0.00045 * line(np.abs(z - zc) - 0.0075, 0.0011), 0)
    h += np.where(torso, 0.00020 * stitches(np.abs(z - zc) - 0.0092, th * r_t, 0.0, 0.0042), 0)
    # ziper central: fita azul-marinho e dentes prata
    zp = torso & (y > 0.02) & (np.abs(x) < 0.0070)
    col[zp] = navy
    teeth = zp & (np.abs(x) < 0.0032)
    tz = ((z / 0.0030) % 1.0)
    col[teeth & (tz < 0.6)] = silver
    rough = np.where(teeth, 0.30, rough)
    metal = np.where(teeth & (tz < 0.6), 0.6, metal)
    h += np.where(teeth, 0.0004 * (tz < 0.6), 0)
    h -= np.where(torso & (y > 0.02), 0.0003 * line(np.abs(x) - 0.0072, 0.0010), 0)
    # barra da jaqueta (canelado) logo acima do cinto
    hem = jk & (z < b.z_waist + 0.016) & ~on_arm
    h += np.where(hem, 0.0004 * (0.5 + 0.5 * np.sin(2 * np.pi * th * r_t / 0.0034)), 0)
    # --- gola alta branca com friso azul-marinho perto da borda
    gc = sel("jacket_collar")
    col[gc] = white
    h += np.where(gc, 0.00016 * wv, 0)
    gtop = gc & (z > F.nz + 0.010)
    h += np.where(gc, 0.0002 * stitches(z - (F.nz + 0.006), th * 0.06, 0.0, 0.0042), 0)
    col[gtop & (z < F.nz + 0.016)] = blue
    # --- calca: sarja azul, vivo branco lateral, bolsos com pesponto
    pt = sel("pants")
    col[pt] = deep
    h += np.where(pt, 0.00020 * tw, 0)
    for sx in (1, -1):
        legx = np.where(z > F.knee_z, F.hip_x + (F.knee_x - F.hip_x) * (F.hz - z) / (F.hz - F.knee_z), F.knee_x)
        out = pt & (x * sx > 0.02)
        ang_l = np.arctan2(y, (x - sx * legx) * sx)
        arc = np.hypot(x - sx * legx, y) * np.abs(ang_l)
        stripe = out & (arc < 0.0042) & (z < F.hz + 0.02)
        col[stripe] = white
        h += np.where(out & (z < F.hz + 0.02), 0.0005 * line(arc - 0.0042, 0.0012), 0)
        pk = (z - (F.hz + 0.02)) + 0.9 * ((x * sx) - (F.hip_x + 0.040))
        front = pt & (y > 0.02) & (x * sx > 0.03) & (z > F.hz - 0.08)
        h -= np.where(front, 0.0005 * line(pk, 0.0014), 0)
        h += np.where(front, 0.00025 * stitches(pk, z, 0.0035, 0.0042), 0)
        bx, bz0 = sx * 0.055, F.hz - 0.035
        back = pt & (y < -0.02) & (z > F.hz - 0.09)
        dr = np.maximum(np.abs(x - bx) - 0.030, np.abs(z - bz0) - 0.032)
        h -= np.where(back, 0.0004 * line(dr, 0.0012), 0)
        h += np.where(back, 0.00022 * stitches(dr, x + z, 0.0030, 0.0042), 0)
    h -= np.where(pt, 0.0003 * line(z - (F.hz + 0.045), 0.0015), 0)          # cos da cintura
    # --- colete (acessorio): nailon ripstop AMARELO da equipe (#FFC83D, o amarelo do emblema; nunca laranja, que e da
    # Rastro), canais costurados, faixas refletivas prata com vivos azul-marinho, vivo azul-marinho na borda, estrela nas costas
    vest = sel("vest") | sel("collar_pillow")
    col[vest] = lin(C["vest"])           # contraste forte com a jaqueta azul: o colete se le por cima dela
    rp = ripstop(P, N)
    h += np.where(vest, 0.00012 * rp, 0)
    rough = np.where(vest, 0.52 - 0.06 * rp, rough)
    if hasattr(b, "vest_z"):
        vz = b.vest_z
        isv = sel("vest")
        ang_d = np.degrees(th)
        rr_ = np.maximum(r_t, 0.05)
        for c0 in (20.0, 40.0, -20.0, -40.0, 158.0, -158.0):
            dc = np.radians(np.angle(np.exp(1j * np.radians(ang_d - c0)), deg=True)) * rr_
            h += np.where(isv, 0.00022 * (stitches(dc - 0.0040, z, 0.0, 0.0042) + stitches(dc + 0.0040, z, 0.0, 0.0042)), 0)
        for zb in b.reflect_z:
            piping = isv & (np.abs(z - zb) < 0.0080)
            col[piping] = navy                # vivo azul-marinho dos dois lados da faixa (a prata nao some no amarelo)
            band = isv & (np.abs(z - zb) < 0.0062)
            col[band] = silver
            rough = np.where(band, 0.30, rough)
            col[band] *= (0.88 + 0.22 * bead[band])[:, None]
            h += np.where(isv, 0.00045 * line(np.abs(z - zb) - 0.0062, 0.0011), 0)
            h += np.where(isv, 0.00020 * stitches(np.abs(z - zb) - 0.0075, th * rr_, 0.0, 0.0042), 0)
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
    cp = sel("collar_pillow")
    h += np.where(cp, 0.0002 * fbm(P, 0.01, 2), 0)
    col[sel("vest_rim")] = navy
    rough = np.where(sel("vest_rim"), 0.55, rough)
    # --- copa do bone: sarja branca em seis gomos (o da frente azul), costuras com pesponto e vivo azul-marinho na base
    cc = sel("cap_crown")
    col[cc] = white
    h += np.where(cc, 0.00016 * wv, 0)
    loc = (P - np.array(b.cap_m.translation)) @ np.array(b.cap_m.to_3x3())   # coordenadas do bone (aprox. sem escala)
    k = F.k
    az = np.degrees(np.arctan2(loc[:, 0], loc[:, 1]))
    rl = np.hypot(loc[:, 0], loc[:, 1])
    front_g = cc & (np.abs(az) < 30) & (loc[:, 2] > 0.008 * k)
    col[front_g] = blue
    for c0 in (30.0, 90.0, 150.0, -30.0, -90.0, -150.0):
        dc = np.radians(np.angle(np.exp(1j * np.radians(az - c0)), deg=True)) * np.maximum(rl, 0.02)
        h -= np.where(cc & (loc[:, 2] > 0.01 * k), 0.00035 * line(dc, 0.0011), 0)
        h += np.where(cc & (loc[:, 2] > 0.01 * k), 0.0002 * (stitches(dc - 0.0024, loc[:, 2], 0.0, 0.0042) + stitches(dc + 0.0024, loc[:, 2], 0.0, 0.0042)), 0)
    baseb = cc & (loc[:, 2] < 0.010 * k)
    col[baseb] = navy
    h += np.where(cc, 0.0004 * line(loc[:, 2] - 0.010 * k, 0.0012), 0)
    # tecido: variacao baixa e oclusao leve na cor
    mott = fbm(P, 0.05, 3)
    col *= (0.96 + 0.06 * mott)[:, None]
    fab = jk | pt | gc | cc
    col *= np.where(fab, 0.95 + 0.05 * tw, 1.0)[:, None]
    rough = np.where(fab & (rough > 0.5), 0.74 - 0.08 * tw + 0.04 * mott, rough)
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
    # bota de pilota: biqueira branca com pesponto, costura do calcanhar, faixa branca no alto do cano
    boot = part == PID["boot"]
    ax_ = np.abs(x)
    toe_line = F.ball_y - 0.004 + 0.010 * np.cos(np.clip((ax_ - F.foot_x) / 0.05, -1.5, 1.5))
    d_toe = y - toe_line
    col[boot & (d_toe > 0)] = lin(C["white"])
    h -= np.where(boot, 0.0005 * line(d_toe, 0.0018), 0)
    h += np.where(boot, 0.00025 * stitches(d_toe - 0.003, x, 0.0, 0.0045), 0)
    h -= np.where(boot & (y < F.heel_y + 0.02), 0.0004 * line(ax_ - F.foot_x, 0.0012), 0)
    zt = b.boot_top_z
    col[boot & (z > zt - 0.020)] = lin(C["white"])
    h -= np.where(boot, 0.0004 * line(z - (zt - 0.020), 0.0012), 0)
    # sola: frisos horizontais e um friso azul-marinho
    sole = part == PID["sole"]
    h -= np.where(sole, 0.0004 * line(((z / 0.0065) % 1.0) - 0.5, 0.12), 0)
    col[sole & (np.abs(z - 0.0135) < 0.0022)] = lin(C["navy"])
    # velcro das tiras (felpa) e trama das fitas
    vel = part == PID["boot_strap"]
    h += np.where(vel, 0.00030 * fbm(P, 0.0012, 2), 0)
    web = (part == PID["vest_strap"]) | (part == PID["belt"]) | (part == PID["compass_strap"])
    h += np.where(web, 0.00018 * triplanar(P, N, twill2d, 0.0012), 0)
    if hasattr(b, "belt_z"):
        dzb = z - b.belt_z
        h += np.where(part == PID["belt"], 0.0002 * (stitches(dzb - 0.012, np.arctan2(x, y) * 0.13, 0.0, 0.0040) +
                                                    stitches(dzb + 0.012, np.arctan2(x, y) * 0.13, 0.0, 0.0040)), 0)
    # aba do calcanhar: refletiva
    tab = part == PID["boot_tab"]
    col[tab] *= (0.88 + 0.22 * value_noise(P, 0.0006)[tab])[:, None]
    # luvas: dorso com protetor azul-marinho nos nos dos dedos (acolchoado), costuras entre os dedos, palma lisa
    glove = part == PID["glove"]
    if hasattr(b, "hand_skel") and glove.any():
        for sx, s in ((1, "R"), (-1, "L")):
            H = b.hand_skel[s]
            W, d, f, nn, k = (np.array(H["W"]), np.array(H["d"]), np.array(H["f"]), np.array(H["n"]), H["k"])
            near = glove & (np.sign(x) == sx) & (np.linalg.norm(P - W, axis=1) < 0.16)
            loc = P - W
            ad, af, an = loc @ d, loc @ f, loc @ nn
            dorsal = near & (an < -0.004 * k)
            knuck = dorsal & (np.abs(ad - 0.050 * k) < 0.012 * k) & (np.abs(af) < 0.028 * k)
            col[knuck] = lin(C["navy_lt"])
            rough = np.where(knuck, 0.50, rough)
            dk = np.maximum(np.abs(ad - 0.050 * k) - 0.012 * k, np.abs(af) - 0.028 * k)
            h += np.where(dorsal, 0.0006 * sstep(-dk, -0.0015, 0.0015), 0)
            h += np.where(knuck, 0.0003 * line(((af / (0.0093 * k)) % 1.0) - 0.5, 0.18), 0)
            # punho branco com vivo azul (transicao para o punho largo)
            h += np.where(near, 0.0002 * stitches(ad - 0.008 * k, af + an, 0.0, 0.0042), 0)
            palm = near & (an > 0.004 * k)
            rough = np.where(palm, 0.62, rough)
            h += np.where(palm, 0.00012 * fbm(P, 0.0016, 2), 0)
    # punho largo da luva: borda branca na abertura
    cuff = part == PID["glove_cuff"]
    if hasattr(b, "hand_skel") and cuff.any():
        for sx, s in ((1, "R"), (-1, "L")):
            H = b.hand_skel[s]
            W, d, k = np.array(H["W"]), np.array(H["d"]), H["k"]
            near = cuff & (np.sign(x) == sx)
            ad = (P - W) @ d
            col[near & (ad < -0.025 * k)] = lin(C["white"])
            h -= np.where(near, 0.0004 * line(ad + 0.025 * k, 0.0012), 0)
    # cotoveleiras e joelheiras: gomos acolchoados (vincos em grade)
    for nm in ("elbow_pad", "knee_pad"):
        pd = part == PID[nm]
        g1 = line(((x + z) / 0.016) % 1.0 - 0.5, 0.08) + line(((y - z) / 0.016) % 1.0 - 0.5, 0.08)
        h -= np.where(pd, 0.0006 * np.clip(g1, 0, 1), 0)
    kp = part == PID["knee_pad"]
    col[kp & (np.abs(z - (F.knee_z - 0.006)) < 0.0045)] = lin(C["silver"])          # filete refletivo na joelheira
    # fones: tampa com estrela de 4 pontas azul-marinho (equipe), casca com aro
    disc = part == PID["headset_disc"]
    if hasattr(b, "cup_c") and disc.any():
        for sx in (1, -1):
            c = np.array(b.cup_c[sx])
            near = disc & (np.sign(x) == sx)
            q2 = np.stack([y - c[1], z - c[2]], axis=1)
            rho = np.linalg.norm(q2, axis=1)
            th2 = np.arctan2(q2[:, 1], q2[:, 0])
            delta = np.abs(((th2 + np.pi / 4) % (np.pi / 2)) - np.pi / 4)
            r_star = 0.004 + 0.016 * (1 - delta / (np.pi / 4)) ** 2.2
            col[near & (rho < r_star)] = lin(C["navy"])
            h += np.where(near, 0.0003 * line(rho - r_star, 0.0010), 0)
    mic = part == PID["mic"]
    h += np.where(mic, 0.0004 * fbm(P, 0.0010, 2), 0)
    # bussola: mostrador com marcas e rosa dos ventos azul-marinho
    if hasattr(b, "compass_c"):
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
        ndl = part == PID["compass_needle"]
        col[ndl & ((vt @ e2) > 0)] = lin(C["red"])
    # vinil: micro variacao suave
    nz_ = fbm(P, 0.03, 2)
    h += 0.00004 * fbm(P, 0.004, 2)
    rough = rough + 0.05 * (nz_ - 0.5)
    col *= (0.97 + 0.05 * nz_)[:, None]
    col *= (0.85 + 0.15 * m["ao"] ** 0.8)[:, None]
    return col, h, rough, metal


def paint_acc(m, b):
    """Acessorio por missao (colete salva-vidas): tecido do colete pela pintura do traje, vinil/metal pela do equipamento."""
    cs, hs, rs, ms = paint_suit(m, b)
    cg, hg, rg, mg = paint_gear(m, b)
    suit = np.isin(m["part"], [PID[p] for p in ACC_SUIT_PARTS])
    return (np.where(suit[:, None], cs, cg), np.where(suit, hs, hg), np.where(suit, rs, rg), np.where(suit, ms, mg))


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
    mott = fbm(P, 0.03, 3)
    col *= (0.97 + 0.05 * mott)[:, None]
    col *= (0.86 + 0.14 * m["ao"] ** 0.7)[:, None]
    rough = 0.48 + 0.06 * (mott - 0.5)
    h = 0.00003 * fbm(P, 0.0025, 2)
    return col, h, rough, np.zeros(n)


def paint_hair(m, b):
    """Cachos legiveis: cada texel pega o cacho mais proximo (distancia normalizada pelo elipsoide do cacho) e recebe, no
    referencial DESSE cacho, uma mola de dois fios em helice (sulco escuro e fundo no normal, crista clara). O verniz:
    crista com rugosidade baixa e um brilho claro por cacho; sulcos e encontros entre cachos escurecem (AO + sulco).
    A massa de base (entre cachos, sob o bone) fica com fios finos em volta da coroa."""
    F = b.F
    P = m["P"]
    n = len(P)
    hc = np.array(F.hc)
    k = F.k
    crown = hc + np.array([0.0, -0.06 * k, 0.24 * k])
    v = P - crown
    az = np.arctan2(v[:, 0], v[:, 1] + 0.001)
    strands = np.sin(az * 46 + 2.0 * np.sin(az * 5)) * 0.5 + 0.5
    fine = np.sin(az * 140 + 6 * fbm(P, 0.02, 2)) * 0.5 + 0.5
    best = np.full(n, 9.0)
    ridge = np.zeros(n)
    finec = np.zeros(n)
    bright = np.ones(n)
    for c, r, rot, el, tw, br in b.curls:
        M = np.array([list(row) for row in rot])            # colunas = eixos do cacho no mundo
        q = (P - np.array(c[:])) @ M                          # coordenadas locais
        q = q / (np.array(el) * r)
        d = np.linalg.norm(q, axis=1)
        closer = d < best
        phi = np.arctan2(q[:, 1], q[:, 0])
        t = q[:, 2]
        hel = 2 * phi + 2 * np.pi * 1.35 * t * el[2] + tw     # mola de dois fios (~2 voltas visiveis)
        rg = (np.cos(hel) * 0.5 + 0.5) ** 0.8
        fn = np.sin(9 * phi + 2 * np.pi * 6.0 * t) * 0.5 + 0.5
        best = np.where(closer, d, best)
        ridge = np.where(closer, rg, ridge)
        finec = np.where(closer, fn, finec)
        bright = np.where(closer, br, bright)
    w = sstep(-best, -1.25, -1.02)                            # 1 na superficie do cacho, 0 na massa de base
    groove = 1.0 - ridge
    h = (1 - w) * (0.0013 * strands ** 1.4 + 0.00035 * fine) + w * (0.0030 * ridge + 0.00030 * finec)
    base_col = np.tile(lin(C["hair"]), (n, 1))
    col0 = base_col * (0.80 + 0.45 * strands[:, None]) + lin(C["hair_lt"]) * (0.10 * fine * strands)[:, None]
    col1 = base_col * (0.55 + 0.75 * ridge[:, None]) * bright[:, None] + lin(C["hair_lt"]) * (0.30 * ridge ** 3 * (0.6 + 0.4 * finec))[:, None]
    col1 *= (1.0 - 0.35 * groove ** 2)[:, None]
    col = col0 * (1 - w)[:, None] + col1 * w[:, None]
    col *= (0.62 + 0.38 * m["ao"] ** 0.9)[:, None]
    rough = (1 - w) * (0.46 - 0.10 * strands) + w * (0.52 - 0.30 * ridge)
    return col, h, rough, np.zeros(n)


def texture_group(ob, group, res, builder, tex_dir):
    """UV + mapas + pintura + normal; devolve o material PBR do grupo."""
    import time
    t0 = time.time()
    uv_unwrap(ob, margin=0.003 if res >= 2048 else 0.005)
    m = bake_geometry(ob, res)
    t1 = time.time()
    fn = {"suit": paint_suit, "gear": paint_gear, "skin": paint_skin, "hair": paint_hair, "acc_lifevest": paint_acc}[group]
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
    coat = {"suit": 0.0, "gear": 0.55, "skin": 0.30, "hair": 0.45, "acc_lifevest": 0.25}[group]
    coat_r = {"suit": 0.5, "gear": 0.28, "skin": 0.35, "hair": 0.30, "acc_lifevest": 0.35}[group]
    return pbr_material("mat_" + name, cimg, nimg, oimg, coat=coat, coat_rough=coat_r)
