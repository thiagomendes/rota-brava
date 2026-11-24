# Rota Brava - estudos de heróis v2 (D7). Geometria 100% procedural, feita do zero.
# ESTUDO / PROVISÓRIO: não é asset de jogo. Uso:
#   bash tools/blender.sh --background --factory-startup --python source_art/studies/heroes_v2/heroes_v2.py -- A|B|C OUT_DIR
import bpy, bmesh, math, sys, os
from mathutils import Vector

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else ["A", "/tmp"]
DIR, OUT = ARGS[0], ARGS[1]
os.makedirs(OUT, exist_ok=True)
HERE = os.path.dirname(os.path.abspath(__file__))

def hexc(h):
    h = h.lstrip("#"); c = [int(h[i:i+2], 16) / 255 for i in (0, 2, 4)]
    return tuple(((x + 0.055) / 1.055) ** 2.4 if x > 0.04045 else x / 12.92 for x in c) + (1.0,)

# ---------------------------------------------------------------- materiais toon (2 tons + sombra com cor)
MATS = {}
def shade_of(h):
    # sombra: mais escura, puxada para violeta-azulado (nunca preta)
    r, g, b, _ = hexc(h)
    return (r * 0.45 + 0.03, g * 0.42 + 0.02, b * 0.55 + 0.09, 1)

def toon(h, shadow=None, emit=0.0):
    key = (h, shadow, emit)
    if key in MATS: return MATS[key]
    m = bpy.data.materials.new("toon_" + h.strip("#")); m.use_nodes = True
    nt = m.node_tree; nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    if emit > 0:
        e = nt.nodes.new("ShaderNodeEmission"); e.inputs[0].default_value = hexc(h); e.inputs[1].default_value = emit
        nt.links.new(e.outputs[0], out.inputs[0])
    else:
        d = nt.nodes.new("ShaderNodeBsdfDiffuse"); d.inputs[0].default_value = (1, 1, 1, 1)
        s2r = nt.nodes.new("ShaderNodeShaderToRGB")
        bw = nt.nodes.new("ShaderNodeRGBToBW")
        ramp = nt.nodes.new("ShaderNodeValToRGB"); ramp.color_ramp.interpolation = "CONSTANT"
        ramp.color_ramp.elements[0].color = hexc(shadow) if shadow else shade_of(h)
        ramp.color_ramp.elements[1].position = 0.45; ramp.color_ramp.elements[1].color = hexc(h)
        em = nt.nodes.new("ShaderNodeEmission")
        nt.links.new(d.outputs[0], s2r.inputs[0]); nt.links.new(s2r.outputs[0], bw.inputs[0])
        nt.links.new(bw.outputs[0], ramp.inputs[0]); nt.links.new(ramp.outputs[0], em.inputs[0])
        nt.links.new(em.outputs[0], out.inputs[0])
    MATS[key] = m; return m

def lens_mat(h, alpha):
    m = bpy.data.materials.new("lens"); m.use_nodes = True; nt = m.node_tree; nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial"); e = nt.nodes.new("ShaderNodeEmission")
    e.inputs[0].default_value = hexc(h); t = nt.nodes.new("ShaderNodeBsdfTransparent")
    mix = nt.nodes.new("ShaderNodeMixShader"); mix.inputs[0].default_value = alpha
    nt.links.new(t.outputs[0], mix.inputs[1]); nt.links.new(e.outputs[0], mix.inputs[2]); nt.links.new(mix.outputs[0], out.inputs[0])
    m.surface_render_method = "BLENDED"; return m

OUTLINE = None
def outline_mat():
    global OUTLINE
    if OUTLINE: return OUTLINE
    m = bpy.data.materials.new("outline"); m.use_nodes = True; nt = m.node_tree; nt.nodes.clear()
    o = nt.nodes.new("ShaderNodeOutputMaterial"); e = nt.nodes.new("ShaderNodeEmission")
    e.inputs[0].default_value = hexc("#1C1838"); nt.links.new(e.outputs[0], o.inputs[0])
    m.use_backface_culling = True; OUTLINE = m; return m

# ---------------------------------------------------------------- primitivas
def finish(o, mat, parent, line=0.011, smooth=True):
    o.data.materials.append(mat)
    if line > 0:
        o.data.materials.append(outline_mat())
        s = o.modifiers.new("contorno", "SOLIDIFY"); s.thickness = line; s.offset = 1
        s.use_flip_normals = True; s.material_offset = 1; s.use_rim = False
    if smooth:
        for p in o.data.polygons: p.use_smooth = True
    if parent: o.parent = parent
    return o

def sph(loc, sc, mat, parent, line=0.011, seg=32):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=seg // 2, radius=1, location=loc)
    o = bpy.context.object; o.scale = sc; return finish(o, mat, parent, line)

def cyl(loc, r, d, mat, parent, rot=(0, 0, 0), line=0.011, verts=32):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=d, location=loc, rotation=rot)
    o = bpy.context.object; bev(o, min(r, d) * 0.3); return finish(o, mat, parent, line)

def box(loc, size, mat, parent, rot=(0, 0, 0), bevel=0.03, line=0.011):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot)
    o = bpy.context.object; o.scale = size; bpy.ops.object.transform_apply(scale=True)
    bev(o, bevel); return finish(o, mat, parent, line)

def tor(loc, R, r, mat, parent, rot=(0, 0, 0), line=0.008, sc=(1, 1, 1)):
    bpy.ops.mesh.primitive_torus_add(major_radius=R, minor_radius=r, location=loc, rotation=rot, major_segments=40, minor_segments=12)
    o = bpy.context.object; o.scale = sc; return finish(o, mat, parent, line)

def cone(loc, r1, r2, d, mat, parent, rot=(0, 0, 0), verts=24, line=0.008, sc=(1, 1, 1)):
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r1, radius2=r2, depth=d, location=loc, rotation=rot)
    o = bpy.context.object; o.scale = sc; return finish(o, mat, parent, line, smooth=verts > 8)

def bev(o, w):
    if w <= 0: return
    b = o.modifiers.new("chanfro", "BEVEL"); b.width = w; b.segments = 3; b.limit_method = "ANGLE"

def shell(loc, R, mat, parent, keep, sc=(1, 1, 1), line=0.012):
    """Esfera aberta: mantém só faces cujo centro (normalizado) passa em keep(x,y,z)."""
    bpy.ops.mesh.primitive_uv_sphere_add(segments=96, ring_count=48, radius=R, location=loc)
    o = bpy.context.object; bm = bmesh.new(); bm.from_mesh(o.data)
    dead = [f for f in bm.faces if not keep(*(f.calc_center_median() / R))]
    bmesh.ops.delete(bm, geom=dead, context="FACES"); bm.to_mesh(o.data); bm.free()
    so = o.modifiers.new("casca", "SOLIDIFY"); so.thickness = R * 0.08; so.offset = 1
    o.scale = sc; return finish(o, mat, parent, line)

def empty(name, loc, parent=None):
    e = bpy.data.objects.new(name, None); e.location = loc; bpy.context.collection.objects.link(e)
    if parent: e.parent = parent
    return e

def star4(loc, R, mat, parent, rot_x=math.pi / 2, line=0.004):
    """Rosa dos ventos de 4 pontas (2 losangos achatados)."""
    for a in (0, math.pi / 4):
        k = 1.0 if a == 0 else 0.6
        cone(loc, R * k, 0, 0.002, mat, parent, rot=(rot_x, 0, 0), verts=4, line=line, sc=(1, 1, 1)).rotation_euler = (rot_x, a, 0)

# ---------------------------------------------------------------- elenco
HEROES = {
    "rastro": dict(main="#FF8A1F", sec="#FFF1D6", skin="#F2C29B", hair="#6A3B1F", iris="#3C7A3A", H=1.10),
    "pico":   dict(main="#3DBE5A", sec="#FFD23F", skin="#8A5636", hair="#1E1612", iris="#5A3A1E", H=1.04),
    "leme":   dict(main="#2F8CFF", sec="#F7FBFF", skin="#D49A6A", hair="#E0A43A", iris="#2A5FA8", H=1.07),
}
NAVY, YEL, WHITE = "#123A5E", "#FFC83D", "#FFFFFF"

# Três direções: variam proporção, traje e forma da cabeça (não só a cor).
STYLE = {
    # A: resgate náutico. Capacete arredondado + viseira erguida, macacão + colete flutuador branco.
    "A": dict(head=0.44, torso_w=0.80, torso_k="egg", leg=0.24, glove="#F7FBFF", boot="#123A5E"),
    # B: expedição high-tech. Cabeça grande sem capacete, visor de lente que cobre os olhos, traje justo com faixas que brilham.
    "B": dict(head=0.50, torso_w=0.70, torso_k="egg", leg=0.20, glove="#1F2A44", boot="#1F2A44"),
    # C: armadura em camadas com capacete-máscara (abertura no rosto) e crista própria; corpo robusto.
    "C": dict(head=0.41, torso_w=0.95, torso_k="box", leg=0.22, glove="#FFC83D", boot="#FFFFFF"),
}[DIR]

def limb(parent, name, loc, length, r, mat, pose, side, hand_mat, hand_r, foot=False):
    e = empty(name, loc, parent)
    sph((0, 0, -length / 2), (r, r, length / 2 + r * 0.4), mat, e)
    if not foot:
        sph((0, 0, -length - hand_r * 0.6), (hand_r, hand_r * 0.85, hand_r), hand_mat, e)
        sph((-side * 0 + side * hand_r * 0.15, -hand_r * 0.75, -length - hand_r * 0.35), (hand_r * 0.38,) * 3, hand_mat, e, line=0.007)
        fwd, abd = pose
        e.rotation_euler = (-math.radians(fwd), -side * math.radians(abd), 0)
    return e

def face(head, R, h):
    skin = toon(h["skin"]); white = toon(WHITE, "#C9D4E8")
    ex = R * 0.36
    eyes_h = R * 0.30  # altura do olho ~ 0,30 R*2*... => >=20% da altura da cabeça
    for s in (-1, 1):
        base = Vector((s * ex, -R * 0.86, -R * 0.02))
        sph(base, (R * 0.19, R * 0.09, eyes_h), white, head, line=0.006)
        sph(base + Vector((s * -0.005, -R * 0.07, -R * 0.03)), (R * 0.135, R * 0.06, R * 0.2), toon(h["iris"]), head, line=0)
        sph(base + Vector((s * -0.005, -R * 0.1, -R * 0.04)), (R * 0.075, R * 0.05, R * 0.11), toon("#141224", "#141224"), head, line=0)
        sph(base + Vector((s * R * 0.04, -R * 0.15, R * 0.07)), (R * 0.045,) * 3, toon(WHITE, WHITE), head, line=0)
        sph(base + Vector((-s * R * 0.04, -R * 0.15, -R * 0.1)), (R * 0.022,) * 3, toon(WHITE, WHITE), head, line=0)
        # sobrancelha confiante (inclinada para dentro)
        b = sph((s * ex, -R * 0.9, R * 0.36), (R * 0.15, R * 0.05, R * 0.04), toon(h["hair"]), head, line=0)
        b.rotation_euler = (0, s * math.radians(14), 0)
        sph((s * R * 0.62, -R * 0.72, -R * 0.33), (R * 0.12, R * 0.04, R * 0.07), toon("#FF8FA0"), head, line=0)
    sph((0, -R * 0.99, -R * 0.2), (R * 0.07, R * 0.06, R * 0.055), skin, head, line=0.004)  # nariz botão
    # sorriso aberto
    m = sph((0, -R * 0.9, -R * 0.42), (R * 0.2, R * 0.08, R * 0.1), toon("#7A1E2E", "#5A1020"), head, line=0.005)
    sph((0, -R * 0.96, -R * 0.37), (R * 0.15, R * 0.04, R * 0.04), toon(WHITE), head, line=0)

def emblem(parent, loc, R, tilt=0.0):
    e = empty("emblema", loc, parent); e.rotation_euler = (tilt, 0, 0)
    cyl((0, 0, 0), R, 0.02, toon(NAVY), e, rot=(math.pi / 2, 0, 0), line=0.008)
    tor((0, -0.011, 0), R * 0.86, R * 0.07, toon(WHITE), e, rot=(math.pi / 2, 0, 0), line=0)
    star4((0, -0.013, 0), R * 0.7, toon(YEL, "#D89A1A"), e)
    return e

def build(hero_key, pose):
    h = HEROES[hero_key]; H = h["H"]; st = STYLE
    root = empty(hero_key, (0, 0, 0))
    main, sec = toon(h["main"]), toon(h["sec"])
    skin, hair = toon(h["skin"]), toon(h["hair"])
    glove, boot = toon(st["glove"]), toon(st["boot"])
    hd = st["head"] * H; R = hd / 2
    foot_h = 0.06; leg = st["leg"] * H
    hip = foot_h + leg; neck = H - hd * 0.98
    tl = neck - hip; tw = st["torso_w"] * R
    # pernas + botas
    for s in (-1, 1):
        lg = empty("perna", (s * tw * 0.42, 0, hip), root)
        sph((0, 0, -leg / 2), (R * 0.27, R * 0.27, leg / 2 + 0.03), main, lg)
        sph((0, -0.03, -leg - 0.005), (R * 0.27, R * 0.38, 0.065), boot, lg)
        sph((0, -0.04, -leg - 0.045), (R * 0.28, R * 0.4, 0.025), toon("#F7FBFF"), lg, line=0.006)
        lg.rotation_euler = (0, -s * math.radians(pose.get("stance", 4)), 0)
    # tronco
    torso = empty("tronco", (0, 0, hip), root)
    torso.rotation_euler = (math.radians(pose.get("lean", 0)), 0, 0)
    if st["torso_k"] == "egg":
        sph((0, 0, tl * 0.5), (tw, tw * 0.8, tl * 0.62), main, torso)
    else:
        box((0, 0, tl * 0.5), (tw * 2, tw * 1.5, tl * 1.05), main, torso, bevel=0.045)
    sph((0, 0, 0.0), (tw * 0.95, tw * 0.75, tl * 0.25), main, torso)  # quadril
    chest_y = -tw * 0.8
    # ---------------- traje por direção
    if DIR == "A":
        # colete flutuador branco em gomos + gola alta
        sph((0, 0, tl * 0.58), (tw * 1.08, tw * 0.9, tl * 0.48), main, torso)
        for s in (-1, 1):  # alças refletivas do colete
            box((s * tw * 0.5, chest_y * 1.08, tl * 0.6), (0.06, 0.03, tl * 0.8), toon(WHITE, "#AFC0DA"), torso, bevel=0.01, line=0.006)
        tor((0, 0, tl * 0.98), tw * 0.62, 0.035, sec, torso, sc=(1, 0.9, 1))
        box((0, chest_y * 0.2, tl * 0.02), (tw * 2.0, tw * 1.6, 0.07), toon(NAVY), torso, bevel=0.02)  # cinto
        emblem(torso, (0, chest_y * 1.16, tl * 0.6), R * 0.4)
    elif DIR == "B":
        # traje justo com faixas luminosas + mochila compacta com anel
        for s in (-1, 1):
            box((s * tw * 0.55, chest_y * 0.98, tl * 0.5), (0.025, 0.02, tl * 0.85), toon("#9FFFF4", emit=2.5), torso, line=0, bevel=0.006)
        box((0, tw * 0.75, tl * 0.55), (tw * 1.3, tw * 0.6, tl * 0.75), toon("#1F2A44"), torso, bevel=0.05)
        tor((0, tw * 1.07, tl * 0.6), tw * 0.32, 0.02, toon(h["main"], emit=0.0), torso, rot=(math.pi / 2, 0, 0))
        cyl((0, tw * 1.07, tl * 0.6), tw * 0.22, 0.02, toon("#9FFFF4", emit=2.5), torso, rot=(math.pi / 2, 0, 0), line=0)
        box((0, 0, tl * 0.02), (tw * 1.95, tw * 1.55, 0.05), toon("#1F2A44"), torso, bevel=0.02)
        emblem(torso, (0, chest_y * 1.05, tl * 0.62), R * 0.4)
    else:
        # camadas: jaqueta-armadura curta na cor secundária por cima + ombreiras + cinto largo
        box((0, 0, tl * 0.66), (tw * 2.15, tw * 1.62, tl * 0.62), main, torso, bevel=0.06)
        box((0, chest_y * 1.02, tl * 0.62), (tw * 0.9, 0.03, tl * 0.55), sec, torso, bevel=0.012, line=0.006)
        for s in (-1, 1):
            sph((s * tw * 1.05, 0, tl * 0.92), (R * 0.3, R * 0.3, R * 0.2), toon(NAVY), torso)
        box((0, 0, tl * 0.08), (tw * 2.1, tw * 1.66, 0.1), toon(NAVY), torso, bevel=0.03)
        emblem(torso, (0, chest_y * 1.08, tl * 0.64), R * 0.44)
    # braços
    arm_len = tl * 0.85; ar = R * 0.15; hr = R * 0.24
    arms = {}
    for s, k in ((-1, "R"), (1, "L")):
        arms[k] = limb(torso, "braco" + k, (s * (tw + ar * 0.6), 0, tl * 0.88), arm_len, ar, main,
                       pose.get(k, (0, 10)), s, glove, hr)
    # cabeça
    head = empty("cabeca", (0, 0, neck - hip + R * 0.78), torso)
    head.rotation_euler = (math.radians(pose.get("nod", 0)), 0, math.radians(pose.get("turn", 0)))
    sph((0, 0, -R * 0.95), (R * 0.28, R * 0.28, R * 0.2), skin, head, line=0)  # pescoço
    sph((0, 0, 0), (R, R * 0.95, R * 0.93), skin, head)
    for s in (-1, 1):
        sph((s * R * 0.98, 0.0, -R * 0.08), (R * 0.12, R * 0.08, R * 0.16), skin, head, line=0.006)  # orelha humana
    face(head, R, h)
    if DIR != "C": hairstyle(head, R, h, hero_key)
    headgear(head, R, h, hero_key)
    gear(hero_key, h, arms, torso, tl, tw, R, arm_len, hr)
    return root

def hairstyle(head, R, h, k):
    hair = toon(h["hair"])
    if k == "rastro":   # topete espetado
        sph((0, R * 0.05, R * 0.35), (R * 1.02, R * 0.98, R * 0.7), hair, head)
        for i, x in enumerate((-0.5, -0.17, 0.17, 0.5)):
            cone((x * R, -R * 0.55, R * 0.85), R * 0.25, 0, R * 0.6, hair, head, rot=(math.radians(60), 0, math.radians(x * 30)))
    elif k == "pico":   # cachos volumosos
        for a in range(-3, 4):
            ang = math.radians(a * 26)
            sph((math.sin(ang) * R * 0.9, -math.cos(ang) * R * 0.45 + R * 0.1, R * 0.5), (R * 0.28,) * 3, hair, head)
        sph((0, R * 0.1, R * 0.45), (R * 1.02, R * 0.98, R * 0.65), hair, head)
    else:               # rabo de cavalo + franja de lado
        sph((0, R * 0.05, R * 0.3), (R * 1.03, R * 0.99, R * 0.72), hair, head)
        sph((-R * 0.25, -R * 0.75, R * 0.55), (R * 0.5, R * 0.22, R * 0.18), hair, head).rotation_euler = (0, math.radians(-20), 0)
        sph((0, R * 1.05, R * 0.05), (R * 0.22, R * 0.22, R * 0.42), hair, head).rotation_euler = (math.radians(-25), 0, 0)

def headgear(head, R, h, k):
    main, sec = toon(h["main"]), toon(h["sec"])
    if DIR == "A":
        shell((0, 0, R * 0.08), R * 1.13, main, head, lambda x, y, z: z > 0.12 or (y > 0.15 and z > -0.55))
        tor((0, 0, R * 0.2), R * 1.12, R * 0.07, toon(WHITE), head, sc=(1, 0.98, 1), line=0.008)  # aba
        # viseira erguida sobre a testa
        v = shell((0, -R * 0.05, R * 0.3), R * 1.2, lens_mat("#7FE6FF", 0.7), head,
                  lambda x, y, z: y < -0.45 and 0.3 < z < 0.62 and abs(x) < 0.8, line=0.008)
        for s in (-1, 1):  # rádio nas laterais
            cyl((s * R * 1.13, 0, R * 0.0), R * 0.24, R * 0.12, toon(NAVY), head, rot=(0, math.pi / 2, 0))
            star4((s * R * 1.2, 0, 0), R * 0.13, toon(YEL), head, rot_x=0)
        mark = {"rastro": "#FFFFFF", "pico": "#FFD23F", "leme": "#FFFFFF"}[k]
        box((0, 0, R * 1.19), (R * 0.28, R * 1.6, R * 0.12), toon(mark), head, bevel=0.02, line=0.006)  # faixa central
    elif DIR == "B":
        # visor de lente larga sobre os olhos (moldura em ponte, retangular arredondada)
        frame = toon("#1F2A44")
        box((0, -R * 0.9, R * 0.0), (R * 1.7, R * 0.12, R * 0.62), frame, head, bevel=R * 0.2, line=0.009).modifiers["contorno"].thickness = 0.01
        box((0, -R * 0.97, R * 0.0), (R * 1.5, R * 0.05, R * 0.5), lens_mat(h["main"], 0.14), head, bevel=R * 0.18, line=0)
        box((0, -R * 0.99, R * 0.24), (R * 1.2, R * 0.02, R * 0.04), toon(WHITE, emit=1.5), head, line=0, bevel=0.005)
        # faixa da cabeça ligando o visor + fone com antena
        tor((0, 0, R * 0.05), R * 1.0, R * 0.08, frame, head, sc=(1.02, 0.98, 1))
        for s in (-1, 1):
            cyl((s * R * 1.02, 0, 0), R * 0.25, R * 0.16, toon(h["main"]), head, rot=(0, math.pi / 2, 0))
        cyl((R * 1.1, 0, R * 0.45), R * 0.035, R * 0.7, frame, head, rot=(0, math.radians(-15), 0), line=0.006)
        sph((R * 1.2, 0, R * 0.82), (R * 0.09,) * 3, toon("#9FFFF4", emit=2.5), head, line=0.006)
    else:
        # capacete-máscara: cobre a cabeça, janela larga para o rosto, crista que diz a habilidade
        shell((0, 0, 0), R * 1.12, main, head, lambda x, y, z: z > -0.72 and not (y < -0.25 and -0.62 < z < 0.4 and abs(x) < 0.78))
        tor((0, -R * 0.05, -R * 0.1), R * 0.95, R * 0.07, toon(NAVY), head, rot=(math.radians(90), 0, 0), sc=(0.9, 1.05, 1), line=0.007)
        if k == "rastro":   # crista em lente redonda (olhar)
            cyl((0, R * 0.1, R * 1.25), R * 0.3, R * 0.12, toon(NAVY), head, rot=(math.pi / 2, 0, 0))
            cyl((0, R * 0.03, R * 1.25), R * 0.22, R * 0.04, lens_mat("#FFE9A8", 0.85), head, rot=(math.pi / 2, 0, 0), line=0)
        elif k == "pico":   # crista em pico de montanha
            cone((0, 0, R * 1.2), R * 0.5, 0, R * 0.7, toon(h["sec"]), head, rot=(math.pi / 2, 0, 0), verts=3, sc=(1, 1, 0.35)).rotation_euler = (math.pi / 2, 0, math.pi / 2)
        else:               # crista em barbatana/onda
            sph((0, R * 0.2, R * 1.12), (R * 0.12, R * 0.6, R * 0.32), toon(WHITE), head).rotation_euler = (math.radians(-25), 0, 0)
        for s in (-1, 1):
            star4((s * R * 1.13, 0, 0), R * 0.2, toon(YEL), head, rot_x=0)

def gear(k, h, arms, torso, tl, tw, R, L, hr):
    navy, yel, white = toon(NAVY), toon(YEL, "#D89A1A"), toon(WHITE)
    tip = -L - hr * 0.6
    if k == "rastro":
        # lupa na mão direita + scanner de pulso na esquerda + caderno no quadril
        a = arms["R"]
        cyl((0, -hr * 0.3, tip - hr * 1.0), hr * 0.25, hr * 1.6, navy, a)
        tor((0, -hr * 0.3, tip - hr * 2.6), hr * 1.0, hr * 0.18, yel, a, rot=(math.pi / 2, 0, 0), line=0.01)
        cyl((0, -hr * 0.3, tip - hr * 2.6), hr * 0.92, 0.01, lens_mat("#CFF6FF", 0.45), a, rot=(math.pi / 2, 0, 0), line=0)
        box((0, -0.02, -L * 0.7), (hr * 1.4, hr * 1.5, hr * 0.9), navy, arms["L"], bevel=0.015)
        box((0, -0.04 - hr * 0.6, -L * 0.7), (hr * 0.9, 0.01, hr * 0.55), toon("#9FFFF4", emit=2.0), arms["L"], line=0, bevel=0.003)
        box((tw * 1.0, -tw * 0.2, tl * 0.1), (0.05, tw * 0.9, tl * 0.38), toon("#FFF1D6"), torso, bevel=0.012)
        # mochila-scanner nas costas: caixa + antena parabólica (leitura de costas)
        box((0, tw * 0.95, tl * 0.6), (tw * 1.3, tw * 0.55, tl * 0.7), navy, torso, bevel=0.04)
        tor((0, tw * 1.25, tl * 0.62), tw * 0.32, 0.018, yel, torso, rot=(math.pi / 2, 0, 0), line=0.006)
        cyl((tw * 0.45, tw * 1.0, tl * 1.15), 0.012, tl * 0.5, navy, torso, line=0.005, verts=10)
        sph((tw * 0.45, tw * 1.0, tl * 1.42), (0.035,) * 3, toon("#9FFFF4", emit=2.0), torso, line=0.005)
    elif k == "pico":
        # rolo de corda a tiracolo + mosquetões grandes no cinto + garra na mão
        rope = toon("#FFD23F", "#C08A1C")
        tor((0, 0, tl * 0.55), tw * 1.12, R * 0.1, rope, torso, rot=(0, math.radians(38), 0), sc=(1, 0.95, 1.12))
        tor((-tw * 0.8, tw * 0.5, tl * 0.35), tw * 0.38, R * 0.08, rope, torso, rot=(0, math.radians(90), 0))
        for x in (-0.6, 0.0, 0.6):
            tor((x * tw, -tw * 1.35, tl * 0.04), R * 0.14, R * 0.035, toon("#C9D4E8", "#6B7894"), torso, rot=(math.pi / 2, 0, math.pi / 2), sc=(1, 1, 1.4), line=0.005)
        a = arms["L"]
        cyl((0, 0, tip - hr * 0.9), hr * 0.22, hr * 1.4, navy, a)
        for i in range(3):
            g = empty("garra", (0, 0, tip - hr * 1.6), a); g.rotation_euler = (0, 0, i * 2 * math.pi / 3)
            cone((hr * 0.5, 0, -hr * 0.4), hr * 0.18, 0.0, hr * 1.1, toon("#C9D4E8", "#6B7894"), g, rot=(0, math.radians(150), 0), verts=12)
    else:
        # leme de pulso + bússola no cinto + gola-boia
        a = arms["L"]
        w = empty("leme_pulso", (0, -hr * 0.9, -L * 0.62), a); w.rotation_euler = (math.pi / 2, 0, 0)
        tor((0, 0, 0), hr * 1.3, hr * 0.17, yel, w, line=0.008)
        cyl((0, 0, 0), hr * 0.35, hr * 0.4, navy, w)
        for i in range(6):
            sp = empty("raio", (0, 0, 0), w); sp.rotation_euler = (0, 0, i * math.pi / 3)
            cyl((hr * 0.95, 0, 0), hr * 0.08, hr * 1.9, yel, sp, rot=(0, math.pi / 2, 0), line=0.004, verts=10)
        cyl((-tw * 0.9, -tw * 1.25, tl * 0.08), R * 0.2, 0.04, toon(WHITE), torso, rot=(math.pi / 2, 0, 0))
        cone((-tw * 0.9, -tw * 1.32, tl * 0.08), R * 0.12, 0, 0.002, toon("#E8473A"), torso, rot=(math.pi / 2, 0, 0), verts=3, line=0)
        tor((0, 0, tl * 0.98), tw * 0.65, R * 0.14, toon("#FF6A3D" if DIR != "A" else "#FFC83D"), torso, sc=(1, 0.9, 1))
        # boia nas costas, com faixas (leitura de costas)
        tor((0, tw * 1.0, tl * 0.58), tw * 0.72, tw * 0.24, white, torso, rot=(math.pi / 2, 0, 0))
        for i in range(4):
            g = empty("faixa", (0, tw * 1.0, tl * 0.58), torso); g.rotation_euler = (0, i * math.pi / 2 + math.pi / 4, 0)
            tor((tw * 0.72, 0, 0), tw * 0.26, tw * 0.07, toon("#FF6A3D"), g, rot=(0, 0, math.pi / 2), sc=(1, 1, 1), line=0.004)

# ---------------------------------------------------------------- cena
def reset():
    global OUTLINE
    bpy.ops.wm.read_factory_settings(use_empty=True)
    MATS.clear(); OUTLINE = None
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_EEVEE_NEXT"
    sc.eevee.taa_render_samples = 64
    sc.view_settings.view_transform = "Standard"
    sc.render.film_transparent = False
    w = bpy.data.worlds.new("mundo"); sc.world = w; w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = hexc("#B9C3CF"); w.node_tree.nodes["Background"].inputs[1].default_value = 1.0
    # chão neutro (recebe sombra no ramp toon)
    bpy.ops.mesh.primitive_circle_add(vertices=64, radius=9, fill_type="NGON")
    finish(bpy.context.object, toon("#C7CED8", "#8E97B5"), None, line=0)
    def light(kind, name, loc, rot, energy, color, size=None):
        d = bpy.data.lights.new(name, kind); d.energy = energy; d.color = color
        if size: d.shadow_soft_size = size
        o = bpy.data.objects.new(name, d); o.location = loc; o.rotation_euler = [math.radians(a) for a in rot]
        sc.collection.objects.link(o); return o
    light("SUN", "sol_quente", (0, 0, 5), (50, 0, -55), 4.0, (1.0, 0.86, 0.68)).data.angle = math.radians(0.5)
    light("AREA", "preench_frio", (4, -3, 2.5), (60, 0, 55), 40, (0.62, 0.74, 1.0), 3)
    light("AREA", "contraluz", (-1.5, 4, 3.2), (-55, 0, 200), 250, (1.0, 0.92, 0.8), 2)
    return sc

def camera(sc, loc, target, lens=50, ortho=None):
    c = bpy.data.cameras.new("cam"); o = bpy.data.objects.new("cam", c); sc.collection.objects.link(o)
    o.location = loc; d = Vector(target) - Vector(loc); o.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    c.lens = lens
    if ortho: c.type = "ORTHO"; c.ortho_scale = ortho
    sc.camera = o; return o

def render(sc, path, w, hgt):
    sc.render.resolution_x, sc.render.resolution_y = w, hgt; sc.render.resolution_percentage = 100
    sc.render.filepath = path; bpy.ops.render.render(write_still=True); print("RENDER", path)

POSES = {
    "rastro": dict(R=(80, 35), L=(10, 30), lean=-4, turn=8, stance=7),
    "pico":   dict(R=(15, 25), L=(20, 155), lean=-6, turn=-6, stance=10, nod=-4),
    "leme":   dict(R=(70, 40), L=(30, 55), lean=-3, turn=-10, stance=6),
}
NEUTRAL = dict(R=(5, 18), L=(5, 18), stance=4)

# 1) trio em pose de equipe
sc = reset()
for k, x, y, rz in (("pico", -0.95, 0.18, 22), ("rastro", 0.0, -0.12, 0), ("leme", 0.95, 0.18, -22)):
    r = build(k, POSES[k]); r.location = (x, y, 0); r.rotation_euler = (0, 0, math.radians(rz))
camera(sc, (0.35, -4.3, 0.75), (0, 0, 0.62), lens=55)
render(sc, f"{OUT}/{DIR}_trio.png", 1600, 1000)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, f"heroes_v2_{DIR}.blend"))

# 2) turnaround de um herói (frente, 3/4, costas)
turn_hero = {"A": "rastro", "B": "pico", "C": "leme"}[DIR]
sc = reset()
for x, rz in ((-0.9, 0), (0.0, 35), (0.9, 180)):
    r = build(turn_hero, NEUTRAL); r.location = (x, 0, 0); r.rotation_euler = (0, 0, math.radians(rz))
camera(sc, (0, -6, 0.6), (0, 0, 0.6), ortho=2.9)
render(sc, f"{OUT}/{DIR}_turnaround_{turn_hero}.png", 1500, 800)

# 3) miniatura: herói com 48 px de altura; frente e costas
sc = reset()
for i, (k, rz) in enumerate((("rastro", 0), ("pico", 0), ("leme", 0), ("rastro", 180), ("pico", 180), ("leme", 180))):
    r = build(k, NEUTRAL); r.location = (-2.0 + i * 0.8, 0, 0); r.rotation_euler = (0, 0, math.radians(rz))
Hmax = 1.10; px_h = 96  # 48 px de herói em quadro de 96 px
camera(sc, (0, -8, Hmax * 0.75), (0, 0, Hmax * 0.75), ortho=(2 * Hmax) * 480 / px_h)
sc.render.filter_size = 1.0
p = f"{OUT}/{DIR}_mini48.png"; render(sc, p, 480, px_h)
img = bpy.data.images.load(p); import numpy as np
a = np.array(img.pixels[:]).reshape(px_h, 480, 4); a = a.repeat(4, 0).repeat(4, 1)
big = bpy.data.images.new("x4", 480 * 4, px_h * 4, alpha=True); big.pixels = a.ravel().tolist()
big.filepath_raw = f"{OUT}/{DIR}_mini48_x4.png"; big.file_format = "PNG"; big.save()
print("DONE", DIR)
