"""Pico v2: UV, mapas assados e materiais PBR padrao do glTF. PROPOSTA PROVISORIA (copia adaptada de rastro_v2/rv2_tex.py).

Fluxo (tudo no Blender 4.5.16 por script, sem textura de terceiros):
 1. junta as partes por grupo de material (traje, pele, equipamento, cabelo, lente da lanterna; o rosto fica separado);
 2. UV por Smart UV Project + empacotamento;
 3. assa no Cycles (CPU) mapas de GEOMETRIA por texel: posicao, normal, parte (atributo rbpart) e oclusao (AO);
 4. pinta em numpy, por texel e em coordenadas 3D: nylon ripstop da jaqueta acolchoada (costuras dos gomos com pesponto),
    lona da calca (bolso de carga, joelho articulado), helice da corda, cadarcos, biqueira, listra do capacete, sardas;
 5. assa a normal map em espaco tangente a partir da altura (Bump) no Cycles;
 6. Principled BSDF com cor, normal e ORM (R=oclusao G=rugosidade B=metalico) + verniz (Coat -> KHR_materials_clearcoat).
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
C = dict(green="#3DBE5A", green_dk="#26904A", green_dd="#1D6B3A", yellow="#FFD23F", yellow_dk="#E8B523", slate="#5F7086",
         slate_dk="#46546A", charcoal="#3A4552", rubber="#D9DEE2", navy="#1F3A5F", navy_emb="#123A5E", gold="#FFC83D",
         creme="#FFF1D6", white="#F4F1EA", grip="#B98A3C", skin="#F3C9A2", blush="#F2907E", freckle="#CC7A4E",
         hair="#D8612A", hair_lt="#F08A4B", anod="#2FA84F")

PARTS = ["none", "suit", "collar", "skin_head", "skin_neck", "hair", "hair_lock", "helmet", "helmet_rim", "lamp_band", "lamp",
         "lamp_lens", "lamp_ring", "chin_strap", "chin_buckle", "hem", "zip_pull", "glove", "glove_cuff", "boot", "sole",
         "boot_top", "knee_pad", "belt", "buckle", "buckle_star", "emblem", "emblem_star", "emblem_band", "rope", "rope_wrap",
         "carabiner_a", "carabiner_b", "gear_loop", "chalk_bag", "chalk_rim", "chalk_cord", "face"]
PID = {n: i for i, n in enumerate(PARTS)}

# cor base, rugosidade, metalico por parte do grupo "gear" (vinil/plastico macio, metal anodizado)
GEAR = {
    "helmet": ("green", 0.30, 0.0), "helmet_rim": ("green_dd", 0.50, 0.0), "lamp_band": ("charcoal", 0.62, 0.0),
    "lamp": ("charcoal", 0.34, 0.0), "lamp_ring": ("gold", 0.28, 0.6), "chin_strap": ("yellow", 0.58, 0.0),
    "chin_buckle": ("charcoal", 0.36, 0.0), "hem": ("green_dk", 0.55, 0.0), "zip_pull": ("gold", 0.30, 0.6),
    "glove": ("yellow", 0.52, 0.0), "glove_cuff": ("green_dk", 0.50, 0.0), "boot": ("charcoal", 0.46, 0.0),
    "sole": ("rubber", 0.62, 0.0), "boot_top": ("green_dk", 0.55, 0.0), "knee_pad": ("green", 0.36, 0.0),
    "belt": ("navy", 0.40, 0.0), "buckle": ("gold", 0.30, 0.55), "buckle_star": ("navy_emb", 0.32, 0.0),
    "emblem": ("navy_emb", 0.34, 0.0), "emblem_star": ("gold", 0.28, 0.55), "emblem_band": ("creme", 0.36, 0.0),
    "rope": ("yellow", 0.62, 0.0), "rope_wrap": ("green_dk", 0.55, 0.0), "carabiner_a": ("gold", 0.24, 0.85),
    "carabiner_b": ("anod", 0.26, 0.80), "gear_loop": ("navy", 0.50, 0.0), "chalk_bag": ("yellow", 0.70, 0.0),
    "chalk_rim": ("white", 0.92, 0.0), "chalk_cord": ("green_dk", 0.60, 0.0),
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


def join_groups(objs, prefix="Pico"):
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
    tmp = bpy.data.materials.new("pv2_bake_tmp")
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
    img = new_image("pv2_pos", res)

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
    img_m = new_image("pv2_mask", res)

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



# ------------------------------------------------------------------ padroes extras
def ripstop2d(u, v):
    """Nylon ripstop: trama fina com quadriculado de reforco a cada 6 fios. Altura 0..1."""
    base = weave2d(u, v) * 0.6
    gu = line(((u / 6.0) % 1.0), 0.07) + line(((u / 6.0) % 1.0) - 1.0, 0.07)
    gv = line(((v / 6.0) % 1.0), 0.07) + line(((v / 6.0) % 1.0) - 1.0, 0.07)
    return np.clip(base + 0.5 * np.maximum(gu, gv), 0, 1)


def star_mask(qx, qz, r_in=0.008, r_out=0.026):
    rho = np.hypot(qx, qz)
    th = np.arctan2(qz, qx)
    delta = np.abs(((th + np.pi / 4) % (np.pi / 2)) - np.pi / 4)
    r_star = r_in + (r_out - r_in) * (1 - delta / (np.pi / 4)) ** 2.2
    return rho < r_star, rho - r_star


def nearest_axis(P, polys, closed=True):
    """Para cada ponto: distancia ao eixo mais proximo (lista de polilinhas), coordenada ao longo (m), angulo em volta
    (referencia: normal do plano local) e indice da polilinha."""
    n = len(P)
    best = np.full(n, 9.0)
    along = np.zeros(n)
    ang = np.zeros(n)
    which = np.zeros(n, int)
    for pi, pts in enumerate(polys):
        A = np.array([p[:] for p in pts])
        m = len(A)
        acc = 0.0
        segs = range(m) if closed else range(m - 1)
        for i in segs:
            a, b = A[i], A[(i + 1) % m]
            d = b - a
            L = np.linalg.norm(d)
            dn = d / L
            u = np.clip((P - a) @ dn / L, 0, 1)
            rv = P - (a + np.outer(u, d))
            dist = np.linalg.norm(rv, axis=1)
            ref = np.cross(dn, [0.0, 0.0, 1.0])
            if np.linalg.norm(ref) < 1e-3:
                ref = np.cross(dn, [1.0, 0.0, 0.0])
            ref /= np.linalg.norm(ref)
            ref2 = np.cross(dn, ref)
            aa = np.arctan2(rv @ ref2, rv @ ref)
            closer = dist < best
            best = np.where(closer, dist, best)
            along = np.where(closer, acc + u * L, along)
            ang = np.where(closer, aa, ang)
            which = np.where(closer, pi, which)
            acc += L
    return best, along, ang, which


# ------------------------------------------------------------------ pintura por grupo
def paint_suit(m, b):
    """Jaqueta acolchoada verde (nylon ripstop, gomos com pesponto, laterais e cotoveleiras verde-escuro, ziper amarelo,
    estrela amarela nas costas) + calca de escalada cinza-azulada (lona, costuras, joelho articulado, bolso de carga)."""
    from pv2_body import BAFFLE_A, BAFFLE_T
    F = b.F
    P, N, part = m["P"], m["N"], m["part"]
    n = len(P)
    x, y, z = P[:, 0], P[:, 1], P[:, 2]
    lab, res = seg_labels(P, F, b.limb_segs)
    is_suit = part == PID["suit"]
    torso = is_suit & (lab == 0)
    arm = np.zeros(n, bool)
    leg = np.zeros(n, bool)
    for i, q in enumerate(res[1:], start=1):
        if q["kind"] in ("upper_arm", "forearm"):
            arm |= is_suit & (lab == i)
        else:
            leg |= is_suit & (lab == i)
    hem = b.hem_z
    jacket = (torso & (z > hem - 0.002)) | arm
    pants = is_suit & ~jacket
    green, green_dk, yellow = lin(C["green"]), lin(C["green_dk"]), lin(C["yellow"])
    slate, slate_dk = lin(C["slate"]), lin(C["slate_dk"])
    col = np.tile(green, (n, 1))
    col[pants] = slate
    h = np.zeros(n)
    th = np.arctan2(x, y)
    r_t = np.hypot(x, y)
    # ---- tronco da jaqueta: painel lateral verde-escuro, gomos, ziper
    tj = torso & jacket
    side = np.abs(np.sin(th)) > 0.86
    col[tj & side] = green_dk
    for c0 in (math.pi / 2, -math.pi / 2):
        edge = r_t * (np.abs(np.angle(np.exp(1j * (th - c0)))) - (math.pi / 2 - math.asin(0.86)))
        h += np.where(tj, 0.00022 * stitches(edge, z, 0.0, 0.0042) - 0.00030 * line(edge + 0.002, 0.0012), 0)
    frac = ((z - hem) / BAFFLE_T) % 1.0
    dseam = np.minimum(frac, 1 - frac) * BAFFLE_T
    seam_t = tj & (z < F.nz - 0.035)
    h -= np.where(seam_t, 0.0007 * line(dseam, 0.0022), 0)
    h += np.where(seam_t, 0.00028 * stitches(dseam, th * r_t, 0.0030, 0.0042), 0)
    col *= np.where(seam_t, 1 - 0.16 * line(dseam, 0.0045), 1.0)[:, None]
    zipper = tj & (y > 0) & (np.abs(x) < 0.0058)
    col[zipper] = yellow
    teeth = 0.5 + 0.5 * np.sin(2 * np.pi * z / 0.0032)
    h += np.where(zipper, 0.0004 * teeth * line(x, 0.0035), 0)
    h += np.where(tj & (y > 0), 0.00024 * stitches(np.abs(x) - 0.0058, z, 0.0026, 0.0040), 0)
    # estrela amarela de 4 pontas no alto das costas (identidade da equipe de costas)
    st, sd = star_mask(x, z - (F.nz - 0.060), 0.010, 0.032)
    star_b = tj & (y < -0.02) & st
    col[star_b] = yellow
    h += np.where(tj & (y < -0.02), 0.00025 * line(sd, 0.0015), 0)
    # ---- mangas: aneis acolchoados, axila e cotoveleira verde-escuro, punho canelado
    for i, q in enumerate(res[1:], start=1):
        sel = is_suit & (lab == i)
        if not sel.any():
            continue
        kind = q["kind"]
        along = q["u"] * q["L"]
        ang = np.arctan2(q["o"], q["f"])
        if kind in ("upper_arm", "forearm"):
            off = 0.012 if kind == "upper_arm" else 0.0
            fr = ((along - off) / BAFFLE_A) % 1.0
            ds = np.minimum(fr, 1 - fr) * BAFFLE_A
            ok = sel & ((q["u"] > 0.10) if kind == "upper_arm" else (q["u"] < 0.82))
            h -= np.where(ok, 0.0007 * line(ds, 0.0022), 0)
            h += np.where(ok, 0.00028 * stitches(ds, ang * q["r"], 0.0030, 0.0042), 0)
            col *= np.where(ok, 1 - 0.16 * line(ds, 0.0045), 1.0)[:, None]
            under = sel & (q["o"] < -0.62)
            col[under] = green_dk
            if kind == "upper_arm":
                patch = sel & (q["u"] > 0.80) & (q["f"] < -0.30)
            else:
                patch = sel & (q["u"] < 0.22) & (q["f"] < -0.30)
                cuff = sel & (q["u"] > 0.83)
                col[cuff] = green_dk
                h += np.where(cuff, 0.00035 * (0.5 + 0.5 * np.sin(ang * 22)), 0)
            col[patch] = green_dk
            pe = q["f"] + 0.30
            h += np.where(sel & (np.abs(pe) < 0.06), 0.0002 * stitches(pe * q["r"], along, 0.0, 0.004), 0)
        else:
            # calca: costura interna, costura lateral, joelho articulado (pences), bolso de carga na coxa direita
            arc_in = q["r"] * np.arccos(np.clip(-q["o"], -1, 1))
            arc_out = q["r"] * np.arccos(np.clip(q["o"], -1, 1))
            h -= np.where(sel, 0.00035 * line(arc_in, 0.0012) + 0.00035 * line(arc_out, 0.0012), 0)
            h += np.where(sel, 0.00022 * stitches(arc_in, along, 0.0030, 0.0042) + 0.00022 * stitches(arc_out, along, 0.0030, 0.0042), 0)
            if kind == "shin":
                for zz in (0.020, 0.036):
                    dk = along - zz
                    h -= np.where(sel & (q["f"] > -0.1), 0.0004 * line(dk, 0.0014), 0)
                    h += np.where(sel & (q["f"] > -0.1), 0.0002 * stitches(dk, ang * q["r"], 0.0026, 0.0040), 0)
                # barra: faixa verde-escuro com elastico
                hemz = sel & (z < F.ankle_z + 0.075)
                col[hemz] = slate_dk
            if kind == "thigh" and q["sx"] == 1:
                a2 = np.arctan2(q["f"], q["o"])
                inside = sel & (q["u"] > 0.32) & (q["u"] < 0.70) & (np.abs(a2) < 0.58)
                col[inside] = slate_dk
                border = np.minimum.reduce([(q["u"] - 0.32) * q["L"], (0.70 - q["u"]) * q["L"], (0.58 - np.abs(a2)) * q["r"]])
                h += np.where(inside, 0.00026 * stitches(border - 0.004, along + ang * q["r"], 0.0, 0.0042), 0)
                flap = (q["u"] - 0.62) * q["L"]
                h -= np.where(inside, 0.0005 * line(flap, 0.0016), 0)
                col[inside & (np.abs(flap) < 0.0016)] = yellow
    # ---- calca no tronco (abaixo da bainha): pala das costas e costura de cos
    tp = torso & pants
    yoke = F.hz - 0.010 + 0.022 * (np.abs(x) / 0.12)
    h -= np.where(tp & (y < 0), 0.00035 * line(z - yoke, 0.0012), 0)
    h += np.where(tp & (y < 0), 0.0002 * stitches(z - yoke, x, 0.0028, 0.0042), 0)
    # ---- gola amarela
    is_col = part == PID["collar"]
    col[is_col] = yellow
    h += np.where(is_col, 0.0002 * stitches((z - (F.nz + 0.020)), th * 0.07, 0.0, 0.004), 0)
    # tecido: ripstop brilhante na jaqueta, lona na calca
    rip = triplanar(P, N, ripstop2d, 0.0024)
    can = triplanar(P, N, weave2d, 0.0030)
    jk = jacket | is_col
    h += np.where(jk, 0.00014 * rip, 0.00020 * can)
    mott = fbm(P, 0.05, 3)
    col *= (0.96 + 0.07 * mott)[:, None]
    col *= np.where(jk, 0.95 + 0.05 * rip, 0.92 + 0.08 * can)[:, None]
    rough = np.where(jk, 0.46 - 0.06 * rip + 0.04 * mott, 0.86 - 0.08 * can + 0.04 * mott)
    rough = np.where(zipper, 0.35, rough)
    col *= (0.80 + 0.20 * m["ao"] ** 0.8)[:, None]
    return col, h, rough, np.zeros(n)


def paint_gear(m, b):
    F = b.F
    P, N, part = m["P"], m["N"], m["part"]
    n = len(P)
    col = np.zeros((n, 3))
    rough = np.full(n, 0.5)
    metal = np.zeros(n)
    h = np.zeros(n)
    for name, (cname, r, mt) in GEAR.items():
        sel = part == PID[name]
        col[sel] = lin(C[cname])
        rough[sel] = r
        metal[sel] = mt
    x, y, z = P[:, 0], P[:, 1], P[:, 2]
    yellow, green, green_dk, charcoal = lin(C["yellow"]), lin(C["green"]), lin(C["green_dk"]), lin(C["charcoal"])
    # ---- capacete: listra amarela de frente a nuca, respiros, estrela amarela dos lados
    hel = part == PID["helmet"]
    hc = np.array(b.hel_c)
    rimz = b.rim_z(0.0)
    stripe = hel & (np.abs(x) < 0.017) & (N[:, 2] > -0.2)
    col[stripe] = yellow
    h += np.where(hel, 0.0004 * line(np.abs(x) - 0.017, 0.0012), 0)
    for sx in (1, -1):
        for yc in (-0.050, 0.020):
            vent = hel & (np.abs(x - sx * 0.068) < 0.0065) & (np.abs(y - (hc[1] + yc)) < 0.026) & (N[:, 2] > 0.45)
            col[vent] = lin(C["green_dd"])
            h -= np.where(vent, 0.0012, 0)
            ring_d = np.maximum(np.abs(x - sx * 0.068) - 0.0065, np.abs(y - (hc[1] + yc)) - 0.026)
            h += np.where(hel & (N[:, 2] > 0.45), 0.0004 * line(ring_d - 0.0012, 0.0012), 0)
        st, sd = star_mask(y - hc[1], z - (hc[2] + 0.080), 0.008, 0.026)
        sstar = hel & (N[:, 0] * sx > 0.55) & st
        col[sstar] = yellow
        h += np.where(hel & (N[:, 0] * sx > 0.55), 0.00025 * line(sd, 0.0012), 0)
    # aro de borracha e faixa elastica (fios amarelos nas bordas)
    band = part == PID["lamp_band"]
    h += np.where(band, 0.00015 * np.sin(np.arctan2(x, y - hc[1]) * 260), 0)
    col[band & (N[:, 2] > 0.35)] = yellow
    # ---- bota de aproximacao: biqueira e contorno de borracha clara, contraforte verde, cadarco amarelo
    boot = part == PID["boot"]
    bx = np.sign(x) * F.hip_x
    rand = boot & (((y > F.ball_y * 0.95) & (z < 0.060)) | (z < 0.030))
    col[rand] = lin(C["rubber"])
    rough[rand] = 0.60
    h -= np.where(boot, 0.0005 * line(np.minimum(np.abs(z - 0.030), np.abs(y - F.ball_y * 0.95) + 1.0 * (z > 0.06)), 0.0016), 0)
    heel = boot & (y < F.heel_y + 0.040) & (z > 0.030) & (z < F.ankle_z + 0.03)
    col[heel] = green_dk
    h += np.where(boot, 0.0002 * stitches(y - (F.heel_y + 0.040), z, 0.0028, 0.0042), 0)
    lace_zone = boot & (np.abs(x - bx) < 0.020) & (y > 0.000) & (y < F.ball_y * 0.92) & (N[:, 2] > 0.30)
    bars = line(((y / 0.0125) % 1.0) - 0.5, 0.20)
    cross = lace_zone & (bars > 0.2)
    col[lace_zone] = lin(C["slate_dk"])
    col[cross] = yellow
    h += np.where(lace_zone, 0.0009 * bars, 0)
    eye = lace_zone & (np.abs(np.abs(x - bx) - 0.017) < 0.0035) & (bars > 0.4)
    col[eye] = lin(C["gold"])
    sole = part == PID["sole"]
    h -= np.where(sole, 0.0004 * line(((z / 0.0065) % 1.0) - 0.5, 0.12), 0)
    col[sole & (z > 0.016)] = lin(C["green_dk"])
    # ---- luvas: dorso amarelo, palma e pontas cinza de aderencia, costura nos dedos
    glove = part == PID["glove"]
    for sx in (1, -1):
        W, d, f, nn = F.hand_frame(sx)
        nv = np.array(nn)
        side = glove & (np.sign(x) == sx)
        palm = side & ((N @ nv) > 0.20)
        col[palm] = lin(C["grip"])
        rough[palm] = 0.80
        loc = P - np.array(W)
        ad = loc @ np.array(d)
        h += np.where(palm, 0.0003 * (np.sin(ad / 0.003 * 2 * np.pi) > 0.3), 0)
        knuck = side & ~palm & (np.abs(ad - 0.052 * b.v["hand"]) < 0.004)
        h += np.where(knuck, 0.0004, 0)
        col[knuck] = lin(C["yellow_dk"])
    # ---- joelheiras: vivo amarelo na borda, gomos horizontais
    kp = part == PID["knee_pad"]
    for (kx, ky, kz) in b.knee_centers:
        sel = kp & (np.sign(x) == np.sign(kx))
        dd = np.sqrt(((x - kx) / 0.046) ** 2 + ((z - kz) / 0.054) ** 2)
        col[sel & (dd > 0.80)] = yellow
        h += np.where(sel, -0.0006 * line(((z - kz) / 0.024) % 1.0 - 0.5, 0.12) * (dd < 0.75), 0)
        h += np.where(sel, 0.00025 * stitches((dd - 0.80) * 0.05, np.arctan2(z - kz, x - kx) * 0.05, 0.0, 0.004), 0)
    # ---- corda: 3 pernas torcidas + fio traçador verde em helice (cores de corda de escalada)
    rope = part == PID["rope"]
    if rope.any():
        idx = np.where(rope)[0]
        dist, along, ang, which = nearest_axis(P[idx], b.rope_axes, closed=True)
        ph = (3 * ang / (2 * np.pi) + along / 0.016 + which * 0.31) % 1.0
        strand = np.sin(np.pi * ph) ** 0.6
        h[idx] += 0.0011 * strand
        tr = ((ang / (2 * np.pi) + along / 0.040 + which * 0.27) % 1.0)
        tracer = np.abs(tr - 0.5) < 0.07
        c = np.tile(lin(C["yellow"]), (len(idx), 1)) * (0.80 + 0.20 * strand)[:, None]
        c[tracer] = lin(C["green_dk"]) * (0.8 + 0.2 * strand[tracer])[:, None]
        c[(np.abs(tr - 0.15) < 0.03)] = lin(C["navy"])
        col[idx] = c
    wrap = part == PID["rope_wrap"]
    h += np.where(wrap, 0.0005 * (0.5 + 0.5 * np.sin(fbm(P, 0.01, 1) * 6 + (x + y + z) / 0.003)), 0)
    # ---- saco de magnesio: lona amarela, borda de pelucia, estrela verde atras
    bag = part == PID["chalk_bag"]
    h += np.where(bag, 0.00025 * triplanar(P, N, weave2d, 0.0030), 0)
    st, sd = star_mask(x, z - (b.belt_z - 0.020), 0.006, 0.020)
    col[bag & (N[:, 1] < -0.5) & st] = lin(C["green_dk"])
    rim = part == PID["chalk_rim"]
    h += np.where(rim, 0.0008 * fbm(P, 0.0025, 2), 0)
    # cinto: pespontos nas bordas
    belt = part == PID["belt"]
    dz = z - b.belt_z
    h += np.where(belt, 0.0002 * (stitches(dz - 0.0125, np.arctan2(x, y) * 0.13, 0.0, 0.0040) +
                                  stitches(dz + 0.0125, np.arctan2(x, y) * 0.13, 0.0, 0.0040)), 0)
    # mosquetoes: escovado leve
    car = (part == PID["carabiner_a"]) | (part == PID["carabiner_b"])
    h += np.where(car, 0.00005 * fbm(P * np.array([1, 1, 8]), 0.002, 2), 0)
    # vinil: micro variacao suave
    nz_ = fbm(P, 0.03, 2)
    h += 0.00004 * fbm(P, 0.004, 2)
    rough = rough + 0.05 * (nz_ - 0.5)
    col *= (0.97 + 0.05 * nz_)[:, None]
    col *= (0.84 + 0.16 * m["ao"] ** 0.8)[:, None]
    return col, h, rough, metal


def paint_skin(m, b):
    F = b.F
    P, N = m["P"], m["N"]
    n = len(P)
    col = np.tile(lin(C["skin"]), (n, 1))
    hc = np.array(F.hc)
    k = F.k
    for sx in (1, -1):
        c = hc + np.array([sx * 0.098 * k, 0.15 * k, -0.082 * k])
        d = np.linalg.norm((P - c) / np.array([0.050, 0.08, 0.034]) / k, axis=1)
        w = np.exp(-d ** 2 * 1.6) * (P[:, 1] > hc[1])
        col = col * (1 - 0.50 * w[:, None]) + lin(C["blush"]) * 0.50 * w[:, None]
    for c, s, a in (((0, 0.18 * k, -0.07 * k), 0.03 * k, 0.25), ((0.2 * k, -0.006, -0.03 * k), 0.035 * k, 0.25),
                    ((-0.2 * k, -0.006, -0.03 * k), 0.035 * k, 0.25)):
        d = np.linalg.norm(P - (hc + np.array(c)), axis=1) / s
        w = np.exp(-d ** 2) * a
        col = col * (1 - w[:, None]) + lin(C["blush"]) * w[:, None]
    # sardas: pontinhos macios nas bochechas e no nariz (marca do Pico ruivo)
    rng = np.random.default_rng(3)
    front = P[:, 1] > hc[1] + 0.08 * k
    for sx in (1, -1):
        for _ in range(11):
            cx = sx * (0.050 + rng.uniform(0.0, 0.055)) * k
            cz = hc[2] + (-0.070 + rng.uniform(-0.020, 0.018)) * k
            r = rng.uniform(0.0026, 0.0040) * k
            d = np.hypot(P[:, 0] - cx, P[:, 2] - cz) / r
            w = np.clip(1.2 - d, 0, 1) * front * 0.55
            col = col * (1 - w[:, None]) + lin(C["freckle"]) * w[:, None]
    for _ in range(5):
        cx = rng.uniform(-0.022, 0.022) * k
        cz = hc[2] + rng.uniform(-0.062, -0.045) * k
        d = np.hypot(P[:, 0] - cx, P[:, 2] - cz) / (0.0026 * k)
        w = np.clip(1.2 - d, 0, 1) * front * 0.45
        col = col * (1 - w[:, None]) + lin(C["freckle"]) * w[:, None]
    mott = fbm(P, 0.03, 3)
    col *= (0.97 + 0.05 * mott)[:, None]
    col *= (0.86 + 0.14 * m["ao"] ** 0.7)[:, None]
    rough = 0.50 + 0.06 * (mott - 0.5)
    h = 0.00003 * fbm(P, 0.0025, 2)
    return col, h, rough, np.zeros(n)


def paint_hair(m, b):
    F = b.F
    P, N = m["P"], m["N"]
    n = len(P)
    hc = np.array(F.hc)
    k = F.k
    crown = hc + np.array([0.0, -0.02 * k, 0.24 * k])
    v = P - crown
    az = np.arctan2(v[:, 0], v[:, 1] + 0.001)
    strands = np.sin(az * 46 + 2.0 * np.sin(az * 5)) * 0.5 + 0.5
    fine = np.sin(az * 140 + 6 * fbm(P, 0.02, 2)) * 0.5 + 0.5
    lockp = m["part"] == PID["hair_lock"]
    if lockp.any():
        idx = np.where(lockp)[0]
        polys = [[p for p, r in pts] for sx, pts in b.tail_axes]
        dist, along, ang, which = nearest_axis(P[idx], polys, closed=False)
        strands[idx] = np.sin(ang * 5 + which * 1.3) * 0.5 + 0.5
        fine[idx] = np.sin(ang * 15 + 3 * fbm(P[idx], 0.01, 1)) * 0.5 + 0.5
    h = 0.0011 * strands ** 1.5 + 0.00032 * fine
    col = np.tile(lin(C["hair"]), (n, 1))
    tipw = np.zeros(n)
    if lockp.any():
        tipw[idx] = np.clip((along - 0.03) / 0.06, 0, 1) * 0.35
    col = col * (0.84 + 0.30 * strands[:, None])
    col = col * (1 - tipw[:, None]) + lin(C["hair_lt"]) * tipw[:, None]
    col *= (0.74 + 0.26 * m["ao"] ** 0.8)[:, None]
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
    fn = {"suit": paint_suit, "gear": paint_gear, "skin": paint_skin, "hair": paint_hair}[group]
    col, h, rough, metal = fn(m, builder)
    t2 = time.time()
    name = "pico_v2_" + group
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
    coat = {"suit": 0.15, "gear": 0.55, "skin": 0.30, "hair": 0.45}[group]
    coat_r = {"suit": 0.45, "gear": 0.28, "skin": 0.35, "hair": 0.30}[group]
    return pbr_material("mat_" + name, cimg, nimg, oimg, coat=coat, coat_rough=coat_r)
