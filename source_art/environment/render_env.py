"""Renders de conferencia (Workbench) de um .blend do ambiente: sombreado e malha (wireframe).
Uso: blender --background FILE.blend --python render_env.py -- --out captures/rb-04/env/nome [--view az,el] [--only Raiz1,Raiz2]
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
from mathutils import Vector
from envlib import arg_value
from rbart import setup_workbench


def main():
    out = arg_value("--out")
    az, el = [float(v) for v in arg_value("--view", "35,28").split(",")]
    only = arg_value("--only")
    w, h = [int(v) for v in arg_value("--size", "1600,800").split("x" if "x" in arg_value("--size", "1600,800") else ",")]
    sc = bpy.context.scene
    meshes = [o for o in sc.objects if o.type == "MESH"]
    if only:
        names = only.split(",")
        for o in meshes:
            r = o
            while r.parent:
                r = r.parent
            o.hide_render = r.name not in names
        meshes = [o for o in meshes if not o.hide_render]
        cur = 0.0
        for nm in names:
            root = bpy.data.objects.get(nm)
            kids = [o for o in meshes if o.parent == root]
            if root is None or not kids:
                continue
            bpy.context.view_layer.update()
            xs = [(o.matrix_world @ Vector(c)).x for o in kids for c in o.bound_box]
            root.location.x += cur - min(xs)
            bpy.context.view_layer.update()
            cur += max(xs) - min(xs) + 0.6
    deps = bpy.context.evaluated_depsgraph_get()
    lo = Vector((1e9,) * 3)
    hi = Vector((-1e9,) * 3)
    for o in meshes:
        for c in o.evaluated_get(deps).bound_box:
            p = o.matrix_world @ Vector(c)
            lo = Vector(map(min, lo, p))
            hi = Vector(map(max, hi, p))
    ctr = (lo + hi) / 2
    size = max((hi - lo).length, 1.0)
    setup_workbench(sc, w, h, color_type="MATERIAL", light="STUDIO", bg=(0.82, 0.88, 0.9))
    sc.display.shading.show_cavity = True
    sc.display.shading.cavity_type = "BOTH"
    cam = bpy.data.cameras.new("c")
    cam.lens = 55
    co = bpy.data.objects.new("c", cam)
    sc.collection.objects.link(co)
    # camera olhando de -Y(Blender)=+Z(Godot, sul) para o conjunto
    a, e = math.radians(az), math.radians(el)
    d = Vector((math.sin(a) * math.cos(e), -math.cos(a) * math.cos(e), math.sin(e)))
    dist = size * 1.45
    co.location = ctr + d * dist
    co.rotation_euler = (ctr - co.location).to_track_quat("-Z", "Y").to_euler()
    sc.camera = co
    os.makedirs(os.path.dirname(out), exist_ok=True)
    sc.render.filepath = out + "_shaded.png"
    bpy.ops.render.render(write_still=True)
    # malha: copia com Wireframe sobre fundo claro
    wm = bpy.data.materials.new("wire")
    wm.diffuse_color = (0.02, 0.03, 0.04, 1)
    for o in meshes:
        ev = o.evaluated_get(deps)
        me = bpy.data.meshes.new_from_object(ev)
        cp = bpy.data.objects.new(o.name + "_w", me)
        sc.collection.objects.link(cp)
        cp.matrix_world = o.matrix_world
        me.materials.clear()
        me.materials.append(wm)
        md = cp.modifiers.new("w", "WIREFRAME")
        md.thickness = 0.0035 * size / 4
        md.use_even_offset = True
        o.hide_render = True
        o.hide_viewport = True
    sc.display.shading.color_type = "MATERIAL"
    sc.display.shading.show_cavity = False
    sc.display.shading.light = "FLAT"
    sc.render.filepath = out + "_mesh.png"
    bpy.ops.render.render(write_still=True)
    print("RENDER_OK", out)


main()
