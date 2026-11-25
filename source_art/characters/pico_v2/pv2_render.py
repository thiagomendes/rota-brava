"""Pico v2: render de prova (copia de rastro_v2/rv2_render.py) no Blender (Cycles CPU): turnaround com luz de cena, malha (wireframe) e prancha de poses.
PROVISORIO. Luz da biblia de estilo/D11: sol quente direcional, preenchimento frio do ceu, contraluz, chao com sombra de contato.
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
from mathutils import Vector

from rbart import hex_to_linear, load_pixels, save_pixels


def cycles(sc, w, h, samples=96):
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = samples
    sc.cycles.use_denoising = True
    try:
        sc.cycles.denoiser = "OPENIMAGEDENOISE"
    except TypeError:
        pass
    sc.cycles.max_bounces = 6
    sc.cycles.diffuse_bounces = 3
    sc.cycles.glossy_bounces = 3
    sc.cycles.transparent_max_bounces = 8
    sc.render.resolution_x, sc.render.resolution_y = w, h
    sc.render.resolution_percentage = 100
    sc.render.film_transparent = False
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGB"
    sc.view_settings.view_transform = "AgX"
    sc.view_settings.look = "AgX - Punchy"
    sc.render.threads_mode = "AUTO"


def world_sky(sc, strength=0.9):
    world = bpy.data.worlds.new("pv2_sky")
    sc.world = world
    world.use_nodes = True
    nt = world.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position = 0.0
    ramp.color_ramp.elements[0].color = hex_to_linear("#E9D9C0") + (1,)
    ramp.color_ramp.elements[1].position = 0.7
    ramp.color_ramp.elements[1].color = hex_to_linear("#7FB4E6") + (1,)
    bg = nt.nodes.new("ShaderNodeBackground")
    bg.inputs["Strength"].default_value = strength
    out = nt.nodes.new("ShaderNodeOutputWorld")
    nt.links.new(tc.outputs["Generated"], sep.inputs[0])
    nt.links.new(sep.outputs["Z"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], bg.inputs["Color"])
    nt.links.new(bg.outputs[0], out.inputs["Surface"])
    return world


def sun(sc, name, color, energy, elev, azim, angle=3.0, shadow=True):
    ld = bpy.data.lights.new(name, "SUN")
    ld.color = hex_to_linear(color)
    ld.energy = energy
    ld.angle = math.radians(angle)
    ld.use_shadow = shadow
    ob = bpy.data.objects.new(name, ld)
    sc.collection.objects.link(ob)
    d = Vector((math.sin(math.radians(azim)) * math.cos(math.radians(elev)), math.cos(math.radians(azim)) * math.cos(math.radians(elev)),
                math.sin(math.radians(elev))))
    ob.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
    return ob


def area(sc, name, color, energy, loc, target, size=1.0):
    ld = bpy.data.lights.new(name, "AREA")
    ld.color = hex_to_linear(color)
    ld.energy = energy
    ld.size = size
    ob = bpy.data.objects.new(name, ld)
    sc.collection.objects.link(ob)
    ob.location = loc
    ob.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    return ob


def scene_lights(sc):
    """Sol quente a ~40 graus pela frente-direita, contraluz quente-clara, preenchimento frio fraco, rebatido quente do chao."""
    world_sky(sc, 0.75)
    sun(sc, "Sol", "#FFE1B4", 3.6, 40, -35, 2.5)
    sun(sc, "Contraluz", "#FFF0D8", 1.6, 30, 160, 6.0, shadow=False)
    sun(sc, "Preenchimento", "#B9D3FF", 0.35, 15, 110, 20.0, shadow=False)
    area(sc, "Rebatido", "#FFC58C", 18.0, (0.3, 1.2, 0.1), (0, 0, 0.5), 1.2)
    # chao: tabuas do cais simplificadas em madeira clara (so no render de prova)
    bpy.ops.mesh.primitive_plane_add(size=12, location=(0, 0, 0))
    g = bpy.context.active_object
    g.name = "Chao_prova"
    m = bpy.data.materials.new("prova_chao")
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = hex_to_linear("#C9A57A") + (1,)
    b.inputs["Roughness"].default_value = 0.8
    g.data.materials.append(m)
    return g


def camera(sc, target, dist, elev=6.0, azim=0.0, lens=85.0, name="Cam"):
    cam = bpy.data.cameras.new(name)
    cam.lens = lens
    co = bpy.data.objects.new(name, cam)
    sc.collection.objects.link(co)
    place(co, target, dist, elev, azim)
    sc.camera = co
    return co


def place(co, target, dist, elev, azim):
    t = Vector(target)
    d = Vector((math.sin(math.radians(azim)) * math.cos(math.radians(elev)), math.cos(math.radians(azim)) * math.cos(math.radians(elev)),
                math.sin(math.radians(elev))))
    co.location = t + d * dist
    co.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()


def render(sc, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)
    return path


def compose(rows, path, pad=10, bg=(0.97, 0.96, 0.94)):
    imgs = [[load_pixels(p) for p in r] for r in rows]
    W = max(sum(i.shape[1] for i in r) + pad * (len(r) + 1) for r in imgs)
    H = sum(max(i.shape[0] for i in r) for r in imgs) + pad * (len(imgs) + 1)
    out = np.ones((H, W, 4), dtype=np.float32)
    out[..., 0], out[..., 1], out[..., 2] = bg
    y = H - pad
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


def turnaround(sc, out_dir, prefix, target=(0, 0, 0.56), dist=3.6, w=720, h=1040, samples=96, views=(("frente", 0), ("tres_quartos", -38), ("costas", 180))):
    cycles(sc, w, h, samples)
    cam = sc.camera or camera(sc, target, dist, 8.0, 0.0, 85.0)
    paths = []
    for label, az in views:
        place(cam, target, dist, 8.0, az)
        paths.append(render(sc, os.path.join(out_dir, "%s_%s.png" % (prefix, label))))
    compose([paths], os.path.join(out_dir, prefix + "_turnaround.png"))
    return paths


def wire_material():
    m = bpy.data.materials.new("prova_wire")
    m.use_nodes = True
    nt = m.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    wf = nt.nodes.new("ShaderNodeWireframe")
    wf.use_pixel_size = True
    wf.inputs["Size"].default_value = 0.9
    dif = nt.nodes.new("ShaderNodeBsdfPrincipled")
    dif.inputs["Base Color"].default_value = (0.78, 0.78, 0.80, 1)
    dif.inputs["Roughness"].default_value = 0.6
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = (0.02, 0.05, 0.12, 1)
    mix = nt.nodes.new("ShaderNodeMixShader")
    nt.links.new(wf.outputs[0], mix.inputs[0])
    nt.links.new(dif.outputs[0], mix.inputs[1])
    nt.links.new(em.outputs[0], mix.inputs[2])
    nt.links.new(mix.outputs[0], out.inputs["Surface"])
    return m
