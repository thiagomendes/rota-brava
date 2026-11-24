"""Biblioteca de personagens organicos do Rota Brava (RB-04-chars). PROVISORIO ate aprovacao de Thiago.

Geometria 100% procedural (bmesh + modificadores SKIN/SUBSURF do Blender), rig, pesos por distancia ao osso,
shape keys do rosto e animacoes por cinematica (FK + IK de 2 ossos). Nada de terceiros.
Convencao: Blender Z-up, frente do personagem = +Y (vira -Z na Godot), lado direito (.R) = +X.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bmesh
import bpy
from mathutils import Matrix, Quaternion, Vector
from rbart import mat, new_object

# ----------------------------------------------------------------------------- malhas
def skin_obj(name, nodes, edges, material, levels=2, branch=0.8, scale=None, floor=None, collection=None, roots=(0,)):
    """Malha organica: grafo de vertices (co, raio) -> modificador SKIN -> SUBSURF, aplicado em malha comum."""
    bm = bmesh.new()
    sk = bm.verts.layers.skin.verify()
    vs = []
    for co, r in nodes:
        v = bm.verts.new(co)
        v[sk].radius = (r, r)
        vs.append(v)
    for ri in roots:
        vs[ri][sk].use_root = True
    for a, b in edges:
        bm.edges.new((vs[a], vs[b]))
    me = bpy.data.meshes.new(name + "_g")
    bm.to_mesh(me)
    bm.free()
    tmp = bpy.data.objects.new(name + "_g", me)
    bpy.context.scene.collection.objects.link(tmp)
    m = tmp.modifiers.new("skin", "SKIN")
    m.branch_smoothing = branch
    m.use_smooth_shade = True
    s = tmp.modifiers.new("sub", "SUBSURF")
    s.levels = levels
    s.render_levels = levels
    dg = bpy.context.evaluated_depsgraph_get()
    me2 = bpy.data.meshes.new_from_object(tmp.evaluated_get(dg))
    bpy.data.objects.remove(tmp)
    bpy.data.meshes.remove(me)
    bm2 = bmesh.new()
    bm2.from_mesh(me2)
    bpy.data.meshes.remove(me2)
    if scale is not None:
        for v in bm2.verts:
            v.co.x *= scale[0]
            v.co.y *= scale[1]
            v.co.z *= scale[2]
    if floor is not None:
        for v in bm2.verts:
            if v.co.z < floor:
                v.co.z = floor
    return new_object(name, bm2, material, collection=collection)


def ellipsoid(bm, c, r, u=24, v=14):
    bmesh.ops.create_uvsphere(bm, u_segments=u, v_segments=v, radius=1.0,
                              matrix=Matrix.Translation(Vector(c)) @ Matrix.Diagonal((r[0], r[1], r[2], 1.0)))


def tube(bm, pts, radii, sides=8, cap=True):
    """Tubo de secao circular ao longo de uma polilinha (frames por transporte paralelo)."""
    pts = [Vector(p) for p in pts]
    rings = []
    prev_n = None
    for i, p in enumerate(pts):
        d = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
        n = prev_n if prev_n is not None else (Vector((0, 0, 1)) if abs(d.z) < 0.9 else Vector((1, 0, 0)))
        n = (n - d * n.dot(d)).normalized()
        b = d.cross(n)
        prev_n = n
        r = radii[i] if isinstance(radii, (list, tuple)) else radii
        rings.append([bm.verts.new(p + (n * math.cos(2 * math.pi * k / sides) + b * math.sin(2 * math.pi * k / sides)) * r)
                      for k in range(sides)])
    for i in range(len(rings) - 1):
        for k in range(sides):
            bm.faces.new((rings[i][k], rings[i][(k + 1) % sides], rings[i + 1][(k + 1) % sides], rings[i + 1][k]))
    if cap:
        for ring in (rings[0], rings[-1]):
            c = bm.verts.new(sum((v.co for v in ring), Vector()) / len(ring))
            for k in range(sides):
                bm.faces.new((ring[k], ring[(k + 1) % sides], c) if ring is rings[-1] else (ring[(k + 1) % sides], ring[k], c))
    return rings


def lathe(bm, profile, seg=32, deform=None):
    """Revolve um perfil fechado (r, z) em torno de Z; `deform(r, z, ang)` -> (r, z) opcional."""
    n = len(profile)
    rings = []
    for i in range(seg):
        a = 2 * math.pi * i / seg
        ring = []
        for (r, z) in profile:
            rr, zz = deform(r, z, a) if deform else (r, z)
            ring.append(bm.verts.new((rr * math.cos(a), rr * math.sin(a), zz)))
        rings.append(ring)
    for i in range(seg):
        for j in range(n):
            try:
                bm.faces.new((rings[i][j], rings[(i + 1) % seg][j], rings[(i + 1) % seg][(j + 1) % n], rings[i][(j + 1) % n]))
            except ValueError:
                pass
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-5)


def subdivide(bm, levels=1):
    for _ in range(levels):
        bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=1, use_grid_fill=True, use_smooth_function=False)


def transform_bm(bm, matrix):
    bmesh.ops.transform(bm, matrix=matrix, verts=bm.verts[:])


def smooth_bm(bm, factor=0.5, reps=2):
    bmesh.ops.smooth_vert(bm, verts=bm.verts[:], factor=factor, use_axis_x=True, use_axis_y=True, use_axis_z=True)


def rounded_box(bm, c, size, bevel=0.006, rot=None):
    m = Matrix.Translation(Vector(c))
    if rot is not None:
        m = m @ rot
    n0 = len(bm.verts)
    bmesh.ops.create_cube(bm, size=1.0, matrix=m @ Matrix.Diagonal((size[0], size[1], size[2], 1.0)))
    new_edges = [e for e in bm.edges if all(v.index >= n0 for v in e.verts)]
    bmesh.ops.bevel(bm, geom=new_edges, offset=bevel, segments=2, affect="EDGES")


# ----------------------------------------------------------------------------- rig
# nome, head, tail, pai, deforma. R = +X (direita do personagem), frente = +Y. Valores a escala 1,0.
def bone_table(hk=1.0):
    B = []
    B.append(("root", (0, 0, 0), (0, 0, 0.12), None, False))
    B.append(("hips", (0, 0, 0.55), (0, 0, 0.62), "root", True))
    B.append(("spine", (0, 0, 0.62), (0, 0, 0.76), "hips", True))
    B.append(("chest", (0, 0, 0.76), (0, 0, 0.88), "spine", True))
    B.append(("neck", (0, 0, 0.88), (0, 0, 0.94), "chest", True))
    B.append(("head", (0, 0, 0.94), (0, 0, 1.24), "neck", True))
    for sx, s in ((1, "R"), (-1, "L")):
        B.append(("shoulder." + s, (sx * 0.05, 0, 0.84), (sx * 0.15, 0, 0.84), "chest", True))
        B.append(("upper_arm." + s, (sx * 0.16, 0, 0.83), (sx * 0.27, 0.0, 0.62), "shoulder." + s, True))
        B.append(("forearm." + s, (sx * 0.27, 0.0, 0.62), (sx * 0.34, 0.03, 0.43), "upper_arm." + s, True))
        Wr = Vector((sx * 0.34, 0.03, 0.43))
        hd = (Vector((sx * 0.37, 0.05, 0.34)) - Wr).normalized()
        Ht = Wr + hd * 0.097 * 1.3 * hk
        B.append(("hand." + s, tuple(Wr), tuple(Ht), "forearm." + s, True))
        B.append(("hand_tip." + s, tuple(Ht), tuple(Ht + hd * 0.02), "hand." + s, False))
        B.append(("thigh." + s, (sx * 0.085, 0, 0.55), (sx * 0.085, 0.005, 0.30), "hips", True))
        B.append(("shin." + s, (sx * 0.085, 0.005, 0.30), (sx * 0.085, 0, 0.075), "thigh." + s, True))
        B.append(("foot." + s, (sx * 0.085, 0, 0.075), (sx * 0.085, 0.10, 0.0), "shin." + s, True))
        B.append(("toe." + s, (sx * 0.085, 0.10, 0.0), (sx * 0.085, 0.17, 0.0), "foot." + s, True))
        B.append(("toe_tip." + s, (sx * 0.085, 0.17, 0.0), (sx * 0.085, 0.19, 0.0), "toe." + s, False))
        B.append(("heel." + s, (sx * 0.085, -0.065, 0.0), (sx * 0.085, -0.065, 0.03), "foot." + s, False))
    return B


# raio de influencia por osso (m) para o calculo de pesos (osso grosso influencia mais longe)
BONE_RADIUS = {"hips": 0.13, "spine": 0.13, "chest": 0.14, "neck": 0.06, "head": 0.18, "shoulder": 0.06,
               "upper_arm": 0.06, "forearm": 0.05, "hand": 0.05, "thigh": 0.085, "shin": 0.065, "foot": 0.06, "toe": 0.05}


def make_rig(name, K=1.0, hk=1.0):
    arm = bpy.data.armatures.new(name + "_Armature")
    ob = bpy.data.objects.new(name, arm)
    bpy.context.scene.collection.objects.link(ob)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.mode_set(mode="EDIT")
    for (n, h, t, p, d) in bone_table(hk):
        b = arm.edit_bones.new(n)
        b.head = Vector(h) * K
        b.tail = Vector(t) * K
        b.use_deform = d
        if p:
            b.parent = arm.edit_bones[p]
            b.use_connect = False
    bpy.ops.object.mode_set(mode="OBJECT")
    arm.display_type = "STICK"
    return ob


def bind_to_rig(mesh_ob, rig, mode="distance", single_bone=None, max_inf=4, power=3.0):
    """Pesos: osso unico (rigido) ou distancia ao segmento do osso (normalizado, ate max_inf)."""
    me = mesh_ob.data
    for g in list(mesh_ob.vertex_groups):
        mesh_ob.vertex_groups.remove(g)
    bones = [b for b in rig.data.bones if b.use_deform]
    groups = {b.name: mesh_ob.vertex_groups.new(name=b.name) for b in bones}
    if single_bone:
        groups[single_bone].add(list(range(len(me.vertices))), 1.0, "REPLACE")
    else:
        segs = []
        for b in bones:
            base = b.name.split(".")[0]
            segs.append((b.name, Vector(b.head_local), Vector(b.tail_local), BONE_RADIUS.get(base, 0.06)))
        mw = mesh_ob.matrix_world
        for v in me.vertices:
            p = mw @ v.co
            ws = []
            for (n, h, t, r) in segs:
                d = t - h
                u = max(0.0, min(1.0, (p - h).dot(d) / max(d.length_squared, 1e-9)))
                dist = (p - (h + d * u)).length
                ws.append((n, 1.0 / ((dist / r) ** power + 0.02)))
            ws.sort(key=lambda a: -a[1])
            ws = ws[:max_inf]
            tot = sum(w for _, w in ws)
            for n, w in ws:
                if w / tot > 0.02:
                    groups[n].add([v.index], w / tot, "REPLACE")
    mod = mesh_ob.modifiers.new("Armature", "ARMATURE")
    mod.object = rig
    mesh_ob.parent = rig


def transfer_weights(src, dst, rig):
    """Copia os pesos do vertice mais proximo de `src` (camadas de roupa deformam juntas, sem vazar)."""
    from mathutils.kdtree import KDTree
    sme = src.data
    kd = KDTree(len(sme.vertices))
    for v in sme.vertices:
        kd.insert(src.matrix_world @ v.co, v.index)
    kd.balance()
    for g in list(dst.vertex_groups):
        dst.vertex_groups.remove(g)
    groups = {b.name: dst.vertex_groups.new(name=b.name) for b in rig.data.bones if b.use_deform}
    for v in dst.data.vertices:
        _, idx, _ = kd.find(dst.matrix_world @ v.co)
        for g in sme.vertices[idx].groups:
            groups[src.vertex_groups[g.group].name].add([v.index], g.weight, "REPLACE")
    mod = dst.modifiers.new("Armature", "ARMATURE")
    mod.object = rig
    dst.parent = rig


def smooth_weights(mesh_ob, iterations=2, factor=0.5):
    """Suaviza pesos pela vizinhanca de arestas (Python puro), limita a 4 influencias e normaliza."""
    me = mesh_ob.data
    names = [g.name for g in mesh_ob.vertex_groups]
    n = len(me.vertices)
    W = [dict() for _ in range(n)]
    for v in me.vertices:
        for g in v.groups:
            W[v.index][g.group] = g.weight
    nb = [set() for _ in range(n)]
    for e in me.edges:
        a, b = e.vertices
        nb[a].add(b)
        nb[b].add(a)
    for _ in range(iterations):
        NW = []
        for i in range(n):
            acc = {}
            for k, w in W[i].items():
                acc[k] = w * (1 - factor)
            if nb[i]:
                f = factor / len(nb[i])
                for j in nb[i]:
                    for k, w in W[j].items():
                        acc[k] = acc.get(k, 0.0) + w * f
            NW.append(acc)
        W = NW
    for g in mesh_ob.vertex_groups:
        g.remove(list(range(n)))
    for i in range(n):
        ws = sorted(W[i].items(), key=lambda a: -a[1])[:4]
        tot = sum(w for _, w in ws) or 1.0
        for k, w in ws:
            if w / tot > 0.02:
                mesh_ob.vertex_groups[k].add([i], w / tot, "REPLACE")

def snap_y(ob, x, z, y0=1.0):
    """Y da superficie frontal (+Y) de `ob` em (x, z) por raycast em BVH; None se nao acertar."""
    from mathutils.bvhtree import BVHTree
    bvh = BVHTree.FromObject(ob, bpy.context.evaluated_depsgraph_get())
    hit = bvh.ray_cast(Vector((x, y0, z)), Vector((0, -1, 0)))
    return hit[0].y if hit[0] is not None else None


def torus_z(bm, R, r, z, sy=1.0, major=32, minor=8):
    """Anel (torus) horizontal em torno de Z, achatado em Y por `sy`."""
    vs = []
    for i in range(major):
        a = 2 * math.pi * i / major
        for j in range(minor):
            b = 2 * math.pi * j / minor
            rr = R + r * math.cos(b)
            vs.append(bm.verts.new((rr * math.cos(a), rr * math.sin(a) * sy, z + r * math.sin(b))))
    for i in range(major):
        for j in range(minor):
            bm.faces.new((vs[i * minor + j], vs[((i + 1) % major) * minor + j], vs[((i + 1) % major) * minor + (j + 1) % minor],
                          vs[i * minor + (j + 1) % minor]))


def rot_y(deg):
    return Matrix.Rotation(math.radians(deg), 4, "Y")



# ----------------------------------------------------------------------------- pose / cinematica
def _q_identity():
    return Quaternion((1, 0, 0, 0))


def eul(x=0.0, y=0.0, z=0.0):
    """Rotacao em graus nos eixos X (inclinar p/ frente = negativo), Y (rolar), Z (guinar p/ esquerda = positivo)."""
    return Quaternion((0, 0, 1), math.radians(z)) @ Quaternion((0, 1, 0), math.radians(y)) @ Quaternion((1, 0, 0), math.radians(x))


class Rigger:
    """Calcula poses por FK relativa (R no referencial de repouso do pai) e IK de dois ossos; aplica ao Armature."""

    def __init__(self, rig):
        self.rig = rig
        self.order = [b.name for b in rig.data.bones]
        self.rest_head = {b.name: Vector(b.head_local) for b in rig.data.bones}
        self.rest_tail = {b.name: Vector(b.tail_local) for b in rig.data.bones}
        self.parent = {b.name: (b.parent.name if b.parent else None) for b in rig.data.bones}
        self.M = {b.name: b.matrix_local.to_quaternion() for b in rig.data.bones}
        self.reset()

    def reset(self):
        self.R = {}
        self.absolute = {}
        self.hips_off = Vector((0, 0, 0))
        self.acc = {n: _q_identity() for n in self.order}
        self.pos = dict(self.rest_head)

    def rest_dir(self, n):
        return (self.rest_tail[n] - self.rest_head[n]).normalized()

    def length(self, n):
        return (self.rest_tail[n] - self.rest_head[n]).length

    def rel(self, bone, q):
        self.R[bone] = q

    def evaluate(self):
        for n in self.order:
            p = self.parent[n]
            if n in self.absolute:
                self.acc[n] = self.absolute[n].copy()
            else:
                base = self.acc[p] if p else _q_identity()
                self.acc[n] = base @ self.R.get(n, _q_identity())
            if p is None:
                self.pos[n] = self.rest_head[n].copy()
            else:
                self.pos[n] = self.pos[p] + self.acc[p] @ (self.rest_head[n] - self.rest_head[p])
            if n == "hips":
                self.pos[n] = self.rest_head[n] + self.hips_off
        # hips deslocado: recalcular descendentes (a ordem garante pai antes de filho)
        return self

    def tip(self, n):
        return self.pos[n] + self.acc[n] @ (self.rest_tail[n] - self.rest_head[n])

    def solve2(self, root_bone, mid_bone, end_bone, target, pole, end_dir=None, end_roll=0.0):
        """IK de 2 ossos (ex.: upper_arm, forearm, hand): ponta do `mid` (pulso) em `target`."""
        self.evaluate()
        S = self.pos[root_bone]
        l1, l2 = self.length(root_bone), self.length(mid_bone)
        T = Vector(target)
        d = (T - S)
        dist = max(min(d.length, l1 + l2 - 1e-4), abs(l1 - l2) + 1e-3)
        u = d.normalized()
        a = (l1 * l1 - l2 * l2 + dist * dist) / (2 * dist)
        h = math.sqrt(max(l1 * l1 - a * a, 0.0))
        pv = Vector(pole)
        perp = pv - u * pv.dot(u)
        if perp.length < 1e-6:
            perp = Vector((0, 0, 1)).cross(u)
        perp.normalize()
        E = S + u * a + perp * h
        W = S + u * dist
        self.absolute[root_bone] = Quaternion(self.rest_dir(root_bone).rotation_difference((E - S).normalized()))
        self.evaluate()
        self.absolute[mid_bone] = Quaternion(self.rest_dir(mid_bone).rotation_difference((W - E).normalized()))
        self.evaluate()
        if end_bone is not None and end_dir is not None:
            aim = Quaternion(self.rest_dir(end_bone).rotation_difference(Vector(end_dir).normalized()))
            self.absolute[end_bone] = Quaternion(Vector(end_dir).normalized(), math.radians(end_roll)) @ aim
        self.evaluate()
        return W

    def apply(self, frame, prev=None):
        """Grava rotation_quaternion/location nos pose bones e insere keyframes."""
        self.evaluate()
        for n in self.order:
            pb = self.rig.pose.bones[n]
            p = self.parent[n]
            base = self.acc[p] if p else _q_identity()
            relq = base.inverted() @ self.acc[n]
            q = self.M[n].inverted() @ relq @ self.M[n]
            if prev is not None:
                if n in prev and prev[n].dot(q) < 0:
                    q = Quaternion((-q.w, -q.x, -q.y, -q.z))
                prev[n] = q.copy()
            pb.rotation_mode = "QUATERNION"
            pb.rotation_quaternion = q
            pb.keyframe_insert("rotation_quaternion", frame=frame)
            if n == "hips":
                pb.location = self.M[n].inverted() @ self.hips_off
                pb.keyframe_insert("location", frame=frame)







