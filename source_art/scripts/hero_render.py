"""Render de estudo dos herois do RB-R1 (Eevee): luz e materiais da biblia de estilo. PROVISORIO.

Luz: sol quente #FFE6BE a ~45 graus, preenchimento frio, contraluz (rim), fundo de ceu em gradiente (#4FA6E8 -> #FDE9C9).
Materiais: toon suave (Diffuse -> Shader to RGB -> rampa com sombra azulada), rim quente por Layer Weight, contorno fino por
Solidify invertido com material escuro (so no render; o GLB exporta os materiais simples mat_<id>_*).
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
from mathutils import Vector

from rbart import hex_to_linear, load_pixels, save_pixels


def eevee_scene(w, h, ground=True):
    sc = bpy.context.scene
    for eng in ("BLENDER_EEVEE_NEXT", "BLENDER_EEVEE"):
        try:
            sc.render.engine = eng
            break
        except TypeError:
            continue
    sc.render.resolution_x, sc.render.resolution_y = w, h
    sc.render.resolution_percentage = 100
    sc.render.film_transparent = False
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGB"
    sc.view_settings.view_transform = "Standard"
    sc.view_settings.look = "None"
    try:
        sc.eevee.taa_render_samples = 32
        sc.eevee.use_shadows = True
    except AttributeError:
        pass
    world = bpy.data.worlds.new("sky")
    sc.world = world
    world.use_nodes = True
    nt = world.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position = 0.25
    ramp.color_ramp.elements[0].color = hex_to_linear("#FDE9C9") + (1,)
    ramp.color_ramp.elements[1].position = 0.95
    ramp.color_ramp.elements[1].color = hex_to_linear("#4FA6E8") + (1,)
    lp = nt.nodes.new("ShaderNodeLightPath")
    bg_cam = nt.nodes.new("ShaderNodeBackground")
    bg_amb = nt.nodes.new("ShaderNodeBackground")
    bg_amb.inputs["Color"].default_value = hex_to_linear("#BFD6F0") + (1,)
    bg_amb.inputs["Strength"].default_value = 0.35
    mix = nt.nodes.new("ShaderNodeMixShader")
    out = nt.nodes.new("ShaderNodeOutputWorld")
    nt.links.new(tc.outputs["Window"], sep.inputs[0])
    nt.links.new(sep.outputs["Y"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], bg_cam.inputs["Color"])
    nt.links.new(lp.outputs["Is Camera Ray"], mix.inputs["Fac"])
    nt.links.new(bg_amb.outputs[0], mix.inputs[1])
    nt.links.new(bg_cam.outputs[0], mix.inputs[2])
    nt.links.new(mix.outputs[0], out.inputs["Surface"])

    def sun(name, color, energy, elev, azim, angle=4.0, shadow=True):
        ld = bpy.data.lights.new(name, "SUN")
        ld.color = hex_to_linear(color)
        ld.energy = energy
        ld.angle = math.radians(angle)
        ld.use_shadow = shadow
        ob = bpy.data.objects.new(name, ld)
        sc.collection.objects.link(ob)
        # direcao: de onde vem a luz (elevacao, azimute em graus; 0 = de frente +Y)
        d = Vector((math.sin(math.radians(azim)) * math.cos(math.radians(elev)), math.cos(math.radians(azim)) * math.cos(math.radians(elev)),
                    math.sin(math.radians(elev))))
        ob.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
        return ob
    sun("Sol", "#FFE6BE", 3.4, 45, -35, 6.0)
    sun("Preenchimento", "#A9C4FF", 0.9, 20, 120, 20.0, False)
    sun("Contraluz", "#FFE2B0", 2.6, 25, 175, 10.0, False)
    if ground:
        bpy.ops.mesh.primitive_circle_add(vertices=64, radius=6.0, fill_type="NGON", location=(0, 0, 0))
        g = bpy.context.active_object
        g.name = "Chao"
        g.data.materials.append(toon_material("toon_chao", hex_to_linear("#E9DDBF") + (1,), rim=0.0))
    return sc


def S(node, name, out=False):
    for s in (node.outputs if out else node.inputs):
        if s.name == name and s.type == "RGBA":
            return s
    raise KeyError(name)


def toon_material(name, base, rim=0.35, emission=False):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    em = nt.nodes.new("ShaderNodeEmission")
    nt.links.new(em.outputs[0], out.inputs["Surface"])
    if emission:
        em.inputs["Color"].default_value = base
        return m
    dif = nt.nodes.new("ShaderNodeBsdfDiffuse")
    dif.inputs["Color"].default_value = (1, 1, 1, 1)
    s2r = nt.nodes.new("ShaderNodeShaderToRGB")
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    cr = ramp.color_ramp
    cr.interpolation = "EASE"
    cr.elements[0].position = 0.08
    cr.elements[0].color = (0.56, 0.62, 0.86, 1)
    cr.elements[1].position = 0.42
    cr.elements[1].color = (1.0, 0.99, 0.96, 1)
    e = cr.elements.new(0.24)
    e.color = (0.74, 0.77, 0.92, 1)
    mul = nt.nodes.new("ShaderNodeMix")
    mul.data_type = "RGBA"
    mul.blend_type = "MULTIPLY"
    mul.inputs["Factor"].default_value = 1.0
    S(mul,"A").default_value = base
    lw = nt.nodes.new("ShaderNodeLayerWeight")
    lw.inputs["Blend"].default_value = 0.35
    rr = nt.nodes.new("ShaderNodeValToRGB")
    rr.color_ramp.elements[0].position = 0.55
    rr.color_ramp.elements[1].position = 0.75
    rmul = nt.nodes.new("ShaderNodeMix")
    rmul.data_type = "RGBA"
    rmul.blend_type = "MULTIPLY"
    rmul.inputs["Factor"].default_value = 1.0
    S(rmul,"B").default_value = (1.0 * rim, 0.80 * rim, 0.55 * rim, 1)
    add = nt.nodes.new("ShaderNodeMix")
    add.data_type = "RGBA"
    add.blend_type = "ADD"
    add.inputs["Factor"].default_value = 1.0
    nt.links.new(dif.outputs[0], s2r.inputs[0])
    nt.links.new(s2r.outputs["Color"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], S(mul,"B"))
    nt.links.new(lw.outputs["Facing"], rr.inputs["Fac"])
    nt.links.new(rr.outputs["Color"], S(rmul,"A"))
    nt.links.new(S(mul,"Result",True), S(add,"A"))
    nt.links.new(S(rmul,"Result",True), S(add,"B"))
    nt.links.new(S(add,"Result",True), em.inputs["Color"])
    return m


def toonify(objs, outline=0.0045, outline_hex="#2A1C22"):
    """Troca materiais por versoes toon (copias) e adiciona contorno por Solidify invertido."""
    cache = {}
    oline = bpy.data.materials.new("toon_contorno")
    oline.use_nodes = True
    nt = oline.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = hex_to_linear(outline_hex) + (1,)
    o = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(em.outputs[0], o.inputs["Surface"])
    oline.use_backface_culling = True
    if hasattr(oline, "use_backface_culling_shadow"):
        oline.use_backface_culling_shadow = True
    for ob in objs:
        if ob.type != "MESH":
            continue
        for i, m in enumerate(ob.data.materials):
            if m is None:
                continue
            if m.name not in cache:
                base = tuple(m.diffuse_color)
                emis = any(t in m.name for t in ("_olhos", "_luz", "_vidro"))
                cache[m.name] = toon_material("toon_" + m.name, base, rim=0.0 if emis else 0.35, emission=emis)
            ob.data.materials[i] = cache[m.name]
        small = any(t in ob.name for t in ("_Face", "_Head", "Star", "Blush", "Nose", "Glass", "Light", "Band", "Clasp", "Buckle"))
        if outline > 0 and not small:
            ob.data.materials.append(oline)
            sol = ob.modifiers.new("contorno", "SOLIDIFY")
            sol.thickness = outline
            sol.offset = 1.0
            sol.use_flip_normals = True
            sol.use_rim = False
            sol.material_offset = len(ob.data.materials) - 1
    return cache


def camera(sc, target, dist, elev=6.0, azim=0.0, lens=85.0, name="Cam"):
    cam = bpy.data.cameras.new(name)
    cam.lens = lens
    co = bpy.data.objects.new(name, cam)
    sc.collection.objects.link(co)
    t = Vector(target)
    d = Vector((math.sin(math.radians(azim)) * math.cos(math.radians(elev)), math.cos(math.radians(azim)) * math.cos(math.radians(elev)),
                math.sin(math.radians(elev))))
    co.location = t + d * dist
    co.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
    sc.camera = co
    return co


def render(sc, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)
    return path


def place_view(cam, target, dist, elev, azim):
    t = Vector(target)
    d = Vector((math.sin(math.radians(azim)) * math.cos(math.radians(elev)), math.cos(math.radians(azim)) * math.cos(math.radians(elev)),
                math.sin(math.radians(elev))))
    cam.location = t + d * dist
    cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()


def compose(rows, path, pad=8, bg=(1.0, 1.0, 1.0)):
    """rows: lista de listas de caminhos PNG (mesma altura por linha). Prancha simples via numpy."""
    import numpy as np
    imgs = [[load_pixels(p) for p in r] for r in rows]
    W = max(sum(i.shape[1] for i in r) + pad * (len(r) + 1) for r in imgs)
    H = sum(max(i.shape[0] for i in r) for r in imgs) + pad * (len(imgs) + 1)
    out = np.ones((H, W, 4), dtype=np.float32)
    out[..., 0], out[..., 1], out[..., 2] = bg
    y = H - pad      # load_pixels devolve linhas de baixo para cima
    for r in imgs:
        rh = max(i.shape[0] for i in r)
        y -= rh
        x = pad
        for im in r:
            h, w, _ = im.shape
            out[y + (rh - h):y + rh, x:x + w] = im
            x += w + pad
        y -= pad
    save_pixels(out, path)


def upscale_nearest(path_in, path_out, f):
    import numpy as np
    a = load_pixels(path_in)
    save_pixels(np.repeat(np.repeat(a, f, axis=0), f, axis=1), path_out)




