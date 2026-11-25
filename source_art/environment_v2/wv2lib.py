"""Rota Brava · Mundo v2 (RB-R1 W1) · biblioteca de malha. PROVISORIO ate aprovacao de Thiago.

Toda geometria e gerada aqui do zero (bmesh do Blender e formulas proprias). Nada baixado ou importado.
CONVENCAO: tudo e modelado em coordenadas da GODOT (x leste, y CIMA, z sul; metros) e convertido no fim
para o Blender (x, -z, y); o exportador glTF (+Y up) devolve as mesmas medidas na Godot.

`MB` acumula primitivas (cada uma com material, cor de vertice e UV) e vira UM objeto do Blender; as superficies
saem agrupadas por material (uma chamada de desenho por material na Godot). UV em metros (o shader aplica a escala
da textura): `box` = projecao pelo eixo dominante no espaco local da peca (o veio segue `grain`), `world` = idem
no espaco do mundo (paredes continuas entre pecas), `cyl` = cilindrica em torno de Y local, `none`.
"""
import math
import random

import bmesh
import bpy
from mathutils import Matrix, Vector

CONV = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
AX = {"x": 0, "y": 1, "z": 2}


def lin(c):
    """sRGB (0..1) -> linear (a cor de vertice do glTF e linear)."""
    return tuple((x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4) for x in c)


def hexc(h, mul=1.0):
    h = h.lstrip("#")
    return tuple(min(1.0, int(h[i:i + 2], 16) / 255.0 * mul) for i in (0, 2, 4))


def T(x=0.0, y=0.0, z=0.0):
    return Matrix.Translation((x, y, z))


def R(rx=0.0, ry=0.0, rz=0.0):
    """Rotacao em graus (ordem: z, x, y aplicada como Ry @ Rx @ Rz)."""
    return (Matrix.Rotation(math.radians(ry), 4, "Y") @ Matrix.Rotation(math.radians(rx), 4, "X")
            @ Matrix.Rotation(math.radians(rz), 4, "Z"))


def S(x, y=None, z=None):
    return Matrix.Diagonal((x, x if y is None else y, x if z is None else z, 1.0))


# ------------------------------------------------------------------ primitivas locais (bmesh)
def _bm_box(sx, sy, sz, bevel=0.0, segs=2):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0, matrix=S(sx, sy, sz))
    if bevel > 0:
        b = min(bevel, sx * 0.45, sy * 0.45, sz * 0.45)
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=b, segments=segs, profile=0.5, affect="EDGES")
    return bm


def _bm_cyl(r0, r1, h, seg=12, caps=True, bevel=0.0):
    """Cilindro/cone ao longo de Y local, base em y=0."""
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=caps, cap_tris=False, segments=seg, radius1=r0, radius2=r1, depth=h,
                          matrix=T(0, h / 2, 0) @ Matrix.Rotation(math.radians(-90), 4, "X"))
    if bevel > 0 and caps:
        rim = [e for e in bm.edges if len(e.link_faces) == 2 and
               abs(e.link_faces[0].normal.angle(e.link_faces[1].normal)) > math.radians(60)]
        bmesh.ops.bevel(bm, geom=rim, offset=min(bevel, h * 0.3, r0 * 0.4), segments=2, profile=0.5, affect="EDGES")
    return bm


def _bm_sphere(r, subd=2):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=subd, radius=r)
    return bm


def _bm_lathe(profile, seg=16):
    """profile: lista de (raio, y) de baixo para cima. Fecha base e topo se o raio for > 0."""
    bm = bmesh.new()
    rings = []
    for r, y in profile:
        ring = []
        for i in range(seg):
            a = 2 * math.pi * i / seg
            ring.append(bm.verts.new((math.sin(a) * r, y, math.cos(a) * r)))
        rings.append(ring)
    for k in range(len(rings) - 1):
        a, b = rings[k], rings[k + 1]
        for i in range(seg):
            j = (i + 1) % seg
            bm.faces.new((a[i], a[j], b[j], b[i]))
    if profile[0][0] > 1e-4:
        bm.faces.new(list(reversed(rings[0])))
    if profile[-1][0] > 1e-4:
        bm.faces.new(rings[-1])
    bm.normal_update()
    return bm


def _bm_prism(poly2d, depth):
    """Poligono no plano XY (local), extrudado em Z de -depth/2 a +depth/2."""
    bm = bmesh.new()
    vs0 = [bm.verts.new((x, y, -depth / 2)) for x, y in poly2d]
    vs1 = [bm.verts.new((x, y, depth / 2)) for x, y in poly2d]
    n = len(poly2d)
    bm.faces.new(list(reversed(vs0)))
    bm.faces.new(vs1)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((vs0[i], vs0[j], vs1[j], vs1[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def _bm_tube(pts, r, seg=8, caps=True):
    bm = bmesh.new()
    pts = [Vector(p) for p in pts]
    rings = []
    prev_n = None
    for i, p in enumerate(pts):
        if i == 0:
            t = (pts[1] - pts[0]).normalized()
        elif i == len(pts) - 1:
            t = (pts[-1] - pts[-2]).normalized()
        else:
            t = (pts[i + 1] - pts[i - 1]).normalized()
        if prev_n is None:
            up = Vector((0, 1, 0)) if abs(t.y) < 0.9 else Vector((1, 0, 0))
            n = t.cross(up).normalized()
        else:
            n = (prev_n - t * prev_n.dot(t)).normalized()
        prev_n = n
        b = t.cross(n)
        rr = r(i / max(1, len(pts) - 1)) if callable(r) else r
        rings.append([bm.verts.new(p + (n * math.cos(2 * math.pi * k / seg) + b * math.sin(2 * math.pi * k / seg)) * rr)
                      for k in range(seg)])
    for k in range(len(rings) - 1):
        a, c = rings[k], rings[k + 1]
        for i in range(seg):
            j = (i + 1) % seg
            bm.faces.new((a[i], a[j], c[j], c[i]))
    if caps:
        bm.faces.new(list(reversed(rings[0])))
        bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def blob(bm, seed, amp=0.18, freq=2.2, flat_bottom=None):
    """Deforma uma esfera em massa organica (copa, arbusto, rocha). Ruido por somas de senos (estavel)."""
    rnd = random.Random(seed)
    waves = [(Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-1, 1))).normalized() * freq * rnd.uniform(0.7, 1.6),
              rnd.uniform(0, 6.28)) for _ in range(6)]
    for v in bm.verts:
        p = v.co.copy()
        n = p.normalized()
        d = sum(math.sin(p.dot(k) * 1.0 + ph) for k, ph in waves) / 6.0
        v.co = p + n * d * amp * p.length
        if flat_bottom is not None and v.co.y < flat_bottom:
            v.co.y = flat_bottom + (v.co.y - flat_bottom) * 0.25
    return bm


# ------------------------------------------------------------------ acumulador
class MB:
    def __init__(self, name):
        self.name = name
        self.verts = []
        self.faces = []
        self.fmat = []
        self.cuv = []    # uv por canto (lista por face)
        self.ccol = []   # cor por canto (linear rgba)
        self.mats = []

    def mat_index(self, m):
        if m not in self.mats:
            self.mats.append(m)
        return self.mats.index(m)

    def add_bm(self, bm, xf, mat, color=(1, 1, 1), uv="box", grain="x", uvoff=None, uvrot=0.0, shade=None, rng=None):
        """Acrescenta a malha local `bm` transformada por `xf` (Godot). `shade(p_local, p_world)` -> fator de cor."""
        bm.verts.index_update()
        bm.verts.ensure_lookup_table()
        base = len(self.verts)
        mi = self.mat_index(mat)
        loc = [v.co.copy() for v in bm.verts]
        wpos = [xf @ c for c in loc]
        self.verts.extend(wpos)
        if uvoff is None:
            r = rng or random
            uvoff = (r.uniform(0, 4), r.uniform(0, 4))
        col_lin = lin(color)
        nmat = xf.to_3x3()
        gi = AX[grain]
        circ_r = None
        if uv == "cyl":
            rs = [math.hypot(c.x, c.z) for c in loc]
            circ_r = max(1e-3, sum(rs) / len(rs))
        for f in bm.faces:
            idx = [v.index for v in f.verts]
            self.faces.append([base + i for i in idx])
            self.fmat.append(mi)
            if uv == "world":
                n = (nmat @ f.normal).normalized()
                pts = [wpos[i] for i in idx]
            else:
                n = f.normal
                pts = [loc[i] for i in idx]
            uvs = []
            if uv in ("box", "world"):
                na = [abs(n.x), abs(n.y), abs(n.z)]
                dom = na.index(max(na))
                if dom != gi:
                    ua = gi
                    va = [a for a in (0, 1, 2) if a not in (dom, ua)][0]
                else:
                    ua, va = [a for a in (0, 1, 2) if a != dom]
                # paredes: v sempre ao longo de Y (para cima), salvo quando o veio e vertical (postes)
                if gi != 1 and dom != 1 and ua == 1:
                    ua, va = va, ua
                sgn = 1.0
                if dom == 2 and n.z < 0 and ua == 0:
                    sgn = -1.0
                if dom == 0 and n.x > 0 and ua == 2:
                    sgn = -1.0
                for p in pts:
                    uvs.append((p[ua] * sgn, p[va]))
            elif uv == "cyl":
                if abs(n.y) > 0.75:
                    uvs = [(p.x, p.z) for p in pts]
                else:
                    us = [math.atan2(p.x, p.z) * circ_r for p in pts]
                    span = 2 * math.pi * circ_r
                    if max(us) - min(us) > span / 2:
                        us = [u + span if u < 0 else u for u in us]
                    uvs = [(us[k], pts[k].y) for k in range(len(pts))]
            elif uv == "slope":
                # telhado: u ao longo do beiral (x local), v subindo a agua (projecao no plano da face)
                t = Vector((1, 0, 0))
                b = n.cross(t).normalized()
                if b.y < 0:
                    b = -b
                uvs = [(p.dot(t), p.dot(b)) for p in pts]
            else:
                uvs = [(0.0, 0.0)] * len(pts)
            if uvrot:
                c, s = math.cos(uvrot), math.sin(uvrot)
                uvs = [(u * c - v * s, u * s + v * c) for u, v in uvs]
            self.cuv.append([(u + uvoff[0], v + uvoff[1]) for u, v in uvs])
            if shade is None:
                self.ccol.append([col_lin + (1.0,)] * len(idx))
            else:
                cc = []
                for i in idx:
                    k = shade(loc[i], wpos[i])
                    cc.append(tuple(min(1.0, x * k) for x in col_lin) + (1.0,))
                self.ccol.append(cc)
        bm.free()

    # atalhos -----------------------------------------------------------
    def box(self, c, size, mat, color=(1, 1, 1), bevel=0.02, segs=2, rot=None, uv="box", grain="x", **kw):
        bm = _bm_box(size[0], size[1], size[2], bevel, segs)
        xf = T(*c) @ (rot if rot is not None else Matrix.Identity(4))
        self.add_bm(bm, xf, mat, color, uv, grain, **kw)

    def cyl(self, base, r0, h, mat, color=(1, 1, 1), r1=None, seg=12, rot=None, bevel=0.0, caps=True, uv="cyl", **kw):
        bm = _bm_cyl(r0, r0 if r1 is None else r1, h, seg, caps, bevel)
        xf = T(*base) @ (rot if rot is not None else Matrix.Identity(4))
        self.add_bm(bm, xf, mat, color, uv, "y", **kw)

    def sphere(self, c, r, mat, color=(1, 1, 1), subd=2, scale=(1, 1, 1), rot=None, uv="none", seed=None, amp=0.0,
               freq=2.2, flat_bottom=None, **kw):
        bm = _bm_sphere(1.0, subd)
        if seed is not None and amp > 0:
            blob(bm, seed, amp, freq, None)
        for v in bm.verts:
            v.co = Vector((v.co.x * scale[0] * r, v.co.y * scale[1] * r, v.co.z * scale[2] * r))
            if flat_bottom is not None and v.co.y < flat_bottom:
                v.co.y = flat_bottom
        xf = T(*c) @ (rot if rot is not None else Matrix.Identity(4))
        self.add_bm(bm, xf, mat, color, uv, "x", **kw)

    def lathe(self, base, profile, mat, color=(1, 1, 1), seg=16, rot=None, uv="cyl", **kw):
        bm = _bm_lathe(profile, seg)
        xf = T(*base) @ (rot if rot is not None else Matrix.Identity(4))
        self.add_bm(bm, xf, mat, color, uv, "y", **kw)

    def prism(self, c, poly2d, depth, mat, color=(1, 1, 1), rot=None, uv="box", grain="x", **kw):
        bm = _bm_prism(poly2d, depth)
        xf = T(*c) @ (rot if rot is not None else Matrix.Identity(4))
        self.add_bm(bm, xf, mat, color, uv, grain, **kw)

    def tube(self, pts, r, mat, color=(1, 1, 1), seg=8, caps=True, uv="box", **kw):
        bm = _bm_tube(pts, r, seg, caps)
        # UV ao longo do comprimento: usa projecao no mundo (as cordas sao finas, a textura e quase isotropica)
        self.add_bm(bm, Matrix.Identity(4), mat, color, uv, "x", **kw)

    def merge(self, other, xf=Matrix.Identity(4)):
        """Copia outro MB (ja montado) transformado por xf (instancia achatada)."""
        base = len(self.verts)
        self.verts.extend([xf @ v for v in other.verts])
        for f, m, u, c in zip(other.faces, other.fmat, other.cuv, other.ccol):
            self.faces.append([base + i for i in f])
            self.fmat.append(self.mat_index(other.mats[m]))
            self.cuv.append(u)
            self.ccol.append(c)

    def tris(self):
        return sum(len(f) - 2 for f in self.faces)

    # saida -------------------------------------------------------------
    def to_object(self, materials, collection=None, smooth_angle=50.0):
        me = bpy.data.meshes.new(self.name)
        verts = [(v.x, -v.z, v.y) for v in self.verts]
        me.from_pydata(verts, [], self.faces)
        for m in self.mats:
            me.materials.append(materials[m])
        me.polygons.foreach_set("material_index", self.fmat)
        uvl = me.uv_layers.new(name="UVMap")
        flat_uv = [c for face in self.cuv for uv in face for c in uv]
        uvl.data.foreach_set("uv", flat_uv)
        ca = me.color_attributes.new("Color", "FLOAT_COLOR", "CORNER")
        flat_c = [c for face in self.ccol for col in face for c in col]
        ca.data.foreach_set("color", flat_c)
        me.color_attributes.active_color = ca
        me.validate()
        me.update()
        me.shade_smooth()
        me.set_sharp_from_angle(angle=math.radians(smooth_angle))
        ob = bpy.data.objects.new(self.name, me)
        (collection or bpy.context.scene.collection).objects.link(ob)
        mod = ob.modifiers.new("WeightedNormal", "WEIGHTED_NORMAL")
        mod.keep_sharp = True
        mod.weight = 50
        mod.mode = "FACE_AREA"
        return ob
