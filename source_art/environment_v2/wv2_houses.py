"""Rota Brava · Mundo v2 (RB-R1 W1) · gerador de casas da vila Farol 7. PROVISORIO ate aprovacao de Thiago.

Casa em espaco LOCAL: fachada no plano z = 0 virada para +Z, largura em x de 0 a W, fundo ate z = -D, chao em y = 0.
A fachada e montada como parede com VAOS de verdade (paredes em blocos em volta das aberturas, com espessura), de modo
que janelas e portas ficam recuadas e mostram o requadro. Por cima: molduras, peitoris, venezianas abertas, floreiras,
sacada com guarda-corpo, toldo listrado com babado, placa da loja, cunhais de pedra, cornijas, telhado com fiadas de
telha modeladas (degrau real entre fiadas), cumeeira, oitoes e chamines.
"""
import math
import random

from mathutils import Matrix, Vector

from wv2lib import MB, R, T, hexc

PLASTER = "wv2_plaster"
STONE = "wv2_stone"
PAINT = "wv2_paint"
SLATS = "wv2_slats"
ROOF = "wv2_roof"
WOOD = "wv2_wood"
METAL = "wv2_metal"
GLASS = "wv2_glass"
GLASS_LIT = "wv2_glass_lit"
CANVAS = "wv2_canvas"
LEAF = "wv2_leaf"
GLOSSY = "wv2_glossy"
LAMP = "wv2_lamp"

TRIM = hexc("#FFF6E6")
IRON = hexc("#2F4A4C")
TERRA = hexc("#D27A4E")


class House:
    def __init__(self, mb, xf, p, rng, lights):
        self.m = mb
        self.xf = xf
        self.p = p
        self.rng = rng
        self.lights = lights

    # -- utilitarios em espaco local --------------------------------------
    def box(self, c, s, mat, col, bevel=0.0, segs=1, rot=None, uv="box", grain="x", **kw):
        r = rot if rot is not None else Matrix.Identity(4)
        self.m.box((0, 0, 0), s, mat, col, bevel, segs, rot=self.xf @ T(*c) @ r, uv=uv, grain=grain, rng=self.rng, **kw)

    def wbox(self, x0, x1, y0, y1, z0, z1, mat, col):
        """Bloco de parede alinhado (UV no mundo, continuo entre blocos)."""
        self.m.box((0, 0, 0), (x1 - x0, y1 - y0, z1 - z0), mat, col, 0.0, 1,
                   rot=self.xf @ T((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), uv="world", uvoff=(0, 0))

    def cyl(self, base, r0, h, mat, col, rot=None, **kw):
        r = rot if rot is not None else Matrix.Identity(4)
        self.m.cyl((0, 0, 0), r0, h, mat, col, rot=self.xf @ T(*base) @ r, rng=self.rng, **kw)

    def sphere(self, c, r, mat, col, **kw):
        self.m.sphere((0, 0, 0), r, mat, col, rot=self.xf @ T(*c), rng=self.rng, **kw)

    def prism(self, c, poly, depth, mat, col, rot=None, **kw):
        r = rot if rot is not None else Matrix.Identity(4)
        self.m.prism((0, 0, 0), poly, depth, mat, col, rot=self.xf @ T(*c) @ r, rng=self.rng, **kw)

    def world(self, p):
        return self.xf @ Vector(p)

    # -- montagem ----------------------------------------------------------
    def build(self):
        p = self.p
        W, D = p["W"], p["D"]
        gh, fh, n = p.get("gh", 3.2), p.get("fh", 2.8), p["floors"]
        H = gh + (n - 1) * fh
        self.H = H
        t = 0.3
        wall = p["wall"]
        detail = p.get("detail", 2)
        nc = p.get("cols", max(2, int(round(W / 1.75))))
        colx = [W * (i + 0.5) / nc for i in range(nc)]
        ww = min(0.95, W / nc - 0.7)
        holes = []
        items = []
        # terreo
        ground = p.get("ground", "door")
        door_col = p.get("door_col", 0)
        if ground == "shop":
            sw = min(W - 1.4, 3.0)
            holes.append((W / 2 - sw / 2, W / 2 + sw / 2, 0.0, 2.55))
            items.append(("shop", W / 2 - sw / 2, W / 2 + sw / 2, 0.0, 2.55))
        else:
            for i, cx in enumerate(colx):
                if i == door_col:
                    holes.append((cx - 0.55, cx + 0.55, 0.0, 2.3))
                    items.append(("door", cx - 0.55, cx + 0.55, 0.0, 2.3))
                elif ground != "blank":
                    y0 = 0.95
                    holes.append((cx - ww / 2, cx + ww / 2, y0, y0 + 1.35))
                    items.append(("win", cx - ww / 2, cx + ww / 2, y0, y0 + 1.35))
        # andares
        bal_floor = p.get("balcony", 0)
        for f in range(1, n):
            fy = gh + (f - 1) * fh
            for i, cx in enumerate(colx):
                if f == bal_floor and i == p.get("balcony_col", nc // 2):
                    holes.append((cx - 0.5, cx + 0.5, fy + 0.08, fy + 2.25))
                    items.append(("frenchdoor", cx - 0.5, cx + 0.5, fy + 0.08, fy + 2.25))
                else:
                    y0 = fy + 0.85
                    holes.append((cx - ww / 2, cx + ww / 2, y0, y0 + 1.35))
                    items.append(("win", cx - ww / 2, cx + ww / 2, y0, y0 + 1.35))
        self.facade(W, H, t, holes, wall)
        # laterais, fundos, plinto
        self.wbox(0, t, 0, H, -D, -t, PLASTER, wall)
        self.wbox(W - t, W, 0, H, -D, -t, PLASTER, wall)
        self.wbox(t, W - t, 0, H, -D, -D + t, PLASTER, wall)
        self.wbox(-0.02, W + 0.02, 0, 0.5, -D - 0.02, 0.05, STONE, (1, 1, 1))
        # interior escuro atras das aberturas (fecha a caixa, sem ver o ceu)
        self.wbox(t, W - t, 0.0, H, -1.4, -1.3, PLASTER, hexc("#6B5A50"))
        # cornijas e faixas
        for f in range(1, n):
            fy = gh + (f - 1) * fh
            self.box((W / 2, fy - 0.02, 0.04), (W + 0.04, 0.14, 0.1), PLASTER, TRIM, 0.02, 1)
        roof = p.get("roof", "eave")
        if roof == "eave" or detail < 2:
            self.box((W / 2, H - 0.08, 0.07), (W + 0.12, 0.16, 0.16), PLASTER, TRIM, 0.025, 1)
            self.box((W / 2, H + 0.04, 0.12), (W + 0.22, 0.1, 0.26), PLASTER, TRIM, 0.025, 1)
        else:
            self.box((W / 2, H - 0.08, 0.06), (W + 0.06, 0.16, 0.14), PLASTER, TRIM, 0.025, 1)
        if p.get("quoins", detail >= 2):
            self.quoins(W, H)
        for it in items:
            kind = it[0]
            if kind == "win":
                self.window(*it[1:], detail)
            elif kind == "door":
                self.door(*it[1:])
            elif kind == "shop":
                self.shop(*it[1:])
            elif kind == "frenchdoor":
                self.window(*it[1:], detail, french=True)
                self.balcony((it[1] + it[2]) / 2, it[3] - 0.08)
        if roof == "eave":
            self.roof_eave(W, D, H)
        else:
            self.roof_gable(W, D, H)
        return H

    def facade(self, W, H, t, holes, col):
        xs = sorted({0.0, W} | {h[0] for h in holes} | {h[1] for h in holes})
        for a, b in zip(xs[:-1], xs[1:]):
            if b - a < 1e-4:
                continue
            mid = (a + b) / 2
            hs = sorted([(h[2], h[3]) for h in holes if h[0] < mid < h[1]])
            y = 0.0
            for y0, y1 in hs:
                if y0 > y + 1e-4:
                    self.wbox(a, b, y, y0, -t, 0, PLASTER, col)
                y = max(y, y1)
            if H > y + 1e-4:
                self.wbox(a, b, y, H, -t, 0, PLASTER, col)

    def quoins(self, W, H):
        y = 0.5
        k = 0
        while y < H - 0.2:
            h = 0.3
            for x, s in ((0.0, 1), (W, -1)):
                w = 0.42 if k % 2 == 0 else 0.26
                self.box((x + s * (w / 2 - 0.02), y + h / 2, 0.015), (w, h - 0.025, 0.07), STONE, (1, 1, 1), 0.018, 1,
                         uvoff=(self.rng.uniform(0, 2), self.rng.uniform(0, 2)))
            y += h
            k += 1

    def window(self, x0, x1, y0, y1, detail, french=False):
        p = self.p
        w, h = x1 - x0, y1 - y0
        cx = (x0 + x1) / 2
        lit = (not french) and self.rng.random() < p.get("lit", 0.18)
        # vidro recuado + caixilho
        self.box((cx, y0 + h / 2, -0.19), (w, h, 0.02), GLASS_LIT if lit else "wv2_glass", (1, 1, 1))
        if lit:
            self.lights.append(("window", tuple(self.world((cx, y0 + h * 0.5, 0.25)))))
        fc = TRIM
        fw = 0.06
        self.box((cx, y1 - fw / 2, -0.16), (w, fw, 0.07), PAINT, fc)
        self.box((cx, y0 + fw / 2, -0.16), (w, fw, 0.07), PAINT, fc)
        self.box((x0 + fw / 2, y0 + h / 2, -0.16), (fw, h, 0.07), PAINT, fc, grain="y")
        self.box((x1 - fw / 2, y0 + h / 2, -0.16), (fw, h, 0.07), PAINT, fc, grain="y")
        self.box((cx, y0 + h / 2, -0.165), (0.045, h, 0.05), PAINT, fc, grain="y")
        self.box((cx, y0 + h * 0.62, -0.165), (w, 0.04, 0.05), PAINT, fc)
        # moldura na fachada, verga e peitoril
        mw = 0.11
        self.box((x0 - mw / 2, y0 + h / 2, 0.02), (mw, h + 0.02, 0.05), PLASTER, TRIM, 0.012, 1)
        self.box((x1 + mw / 2, y0 + h / 2, 0.02), (mw, h + 0.02, 0.05), PLASTER, TRIM, 0.012, 1)
        self.box((cx, y1 + 0.08, 0.035), (w + 2 * mw + 0.08, 0.16, 0.08), PLASTER, TRIM, 0.02, 1)
        if detail >= 2:
            self.box((cx, y1 + 0.08, 0.075), (0.16, 0.2, 0.05), STONE, (1, 1, 1), 0.015, 1)   # fecho
        if not french:
            self.box((cx, y0 - 0.04, 0.06), (w + 0.34, 0.08, 0.16), STONE, (1, 1, 1), 0.02, 1)
        if detail < 1:
            return
        # venezianas abertas
        if detail >= 2 and p.get("shutters", True) and not french:
            sc = p.get("shutter", hexc("#3A7BD5"))
            for s in (-1, 1):
                xx = (x0 - mw - w / 4 - 0.02) if s < 0 else (x1 + mw + w / 4 + 0.02)
                self.box((xx, y0 + h / 2, 0.065), (w / 2 - 0.02, h, 0.035), SLATS, sc, 0.008, 1)
        # floreira
        if detail >= 2 and not french and self.rng.random() < p.get("flowers", 0.55):
            fy = y0 - 0.17
            fc2 = p.get("box_col", hexc("#8B5E3C"))
            self.box((cx, fy, 0.2), (w + 0.12, 0.2, 0.2), PAINT, fc2, 0.015, 1)
            cols = p.get("flower_cols", ["#FF5C8A", "#FFFFFF", "#FFD23F", "#E8442E"])
            for k in range(4):
                fx = x0 + (k + 0.5) * w / 4 + self.rng.uniform(-0.04, 0.04)
                self.sphere((fx, fy + 0.15, 0.2), 0.13, LEAF, hexc("#58A83F"), subd=1, scale=(1, 0.8, 0.9), seed=int(fx * 100) + k,
                            amp=0.25, freq=3.0, uv="none")
            for k in range(7):
                fx = x0 + self.rng.uniform(0.05, w - 0.05)
                self.sphere((fx, fy + 0.24 + self.rng.uniform(0, 0.06), 0.2 + self.rng.uniform(-0.06, 0.1)), 0.045, GLOSSY,
                            hexc(cols[k % len(cols)]), subd=1, scale=(1, 0.7, 1))
            # trepadeira caindo
            if self.rng.random() < 0.35:
                for k in range(3):
                    fx = x0 + (k + 0.5) * w / 3
                    self.sphere((fx, fy - 0.2, 0.28), 0.1, LEAF, hexc("#4F9F3A"), subd=1, scale=(0.8, 1.6, 0.6),
                                seed=int(fx * 77), amp=0.2, freq=3.0)

    def door(self, x0, x1, y0, y1):
        p = self.p
        w, h = x1 - x0, y1 - y0
        cx = (x0 + x1) / 2
        dc = p.get("door_color", hexc("#2F9C95"))
        self.box((cx, h / 2, -0.27), (w, h, 0.06), PAINT, dc, grain="y")
        for r in range(2):
            for s in (-1, 1):
                self.box((cx + s * w * 0.22, 0.45 + r * 1.0 + 0.4, -0.235), (w * 0.32, 0.8 if r else 0.75, 0.03), PAINT, dc, 0.008, 1,
                         grain="y")
        self.sphere((cx + w * 0.36, 1.05, -0.22), 0.035, METAL, hexc("#D9A94A"), subd=1)
        # requadro de pedra, soleira e degrau
        self.box((x0 - 0.1, h / 2 + 0.05, 0.02), (0.2, h + 0.1, 0.07), STONE, (1, 1, 1), 0.02, 1, grain="y")
        self.box((x1 + 0.1, h / 2 + 0.05, 0.02), (0.2, h + 0.1, 0.07), STONE, (1, 1, 1), 0.02, 1, grain="y")
        self.box((cx, h + 0.17, 0.03), (w + 0.5, 0.26, 0.09), STONE, (1, 1, 1), 0.02, 1)
        self.box((cx, 0.08, 0.18), (w + 0.5, 0.16, 0.42), STONE, (1, 1, 1), 0.025, 2)
        # arandela
        lx = x1 + 0.45
        self.box((lx, 2.05, 0.06), (0.05, 0.22, 0.08), METAL, IRON)
        self.box((lx, 2.15, 0.16), (0.04, 0.04, 0.22), METAL, IRON)
        self.box((lx, 1.98, 0.24), (0.17, 0.24, 0.17), LAMP, hexc("#FFE0A0"), 0.01, 1)
        self.box((lx, 2.13, 0.24), (0.23, 0.05, 0.23), METAL, IRON, 0.01, 1)
        self.lights.append(("wall_lamp", tuple(self.world((lx, 1.98, 0.42)))))

    def shop(self, x0, x1, y0, y1):
        p = self.p
        w = x1 - x0
        cx = (x0 + x1) / 2
        sc = p.get("door_color", hexc("#2F7FD8"))
        dw = 0.95
        # porta da loja (esquerda) e vitrine
        self.box((x0 + dw / 2, 1.15, -0.24), (dw, 2.3, 0.06), PAINT, sc, grain="y")
        self.box((x0 + dw / 2, 1.45, -0.21), (dw * 0.6, 1.1, 0.02), GLASS_LIT, (1, 1, 1))
        self.box((x0 + dw + 0.03, 1.27, -0.2), (0.06, 2.55, 0.12), PAINT, sc, grain="y")
        vx0 = x0 + dw + 0.06
        vw = x1 - vx0
        self.box((vx0 + vw / 2, 0.35, -0.12), (vw, 0.7, 0.2), PAINT, sc)
        self.box((vx0 + vw / 2, 1.6, -0.22), (vw, 1.8, 0.02), GLASS_LIT, (1, 1, 1))
        for k in range(1, 3):
            self.box((vx0 + vw * k / 3, 1.6, -0.19), (0.05, 1.8, 0.05), PAINT, sc, grain="y")
        self.box((cx, 2.52, -0.18), (w, 0.07, 0.1), PAINT, sc)
        # mercadoria na vitrine (caixotes e cores)
        for k in range(5):
            gx = vx0 + 0.25 + k * (vw - 0.5) / 4
            self.sphere((gx, 0.78, -0.35), 0.12, GLOSSY, hexc(["#F59A23", "#E8442E", "#F4D03F", "#7DBA3A", "#FF8FB1"][k % 5]),
                        subd=1, scale=(1, 0.7, 1))
        self.lights.append(("shop", tuple(self.world((cx, 1.6, 0.4)))))
        # pilastras de pedra
        self.box((x0 - 0.12, 1.3, 0.03), (0.24, 2.6, 0.1), STONE, (1, 1, 1), 0.02, 1, grain="y")
        self.box((x1 + 0.12, 1.3, 0.03), (0.24, 2.6, 0.1), STONE, (1, 1, 1), 0.02, 1, grain="y")
        # placa da loja + icone em relevo
        bc = p.get("sign_col", hexc("#2F4F6F"))
        self.box((cx, 2.95, 0.05), (min(w, 2.4), 0.42, 0.06), PAINT, bc, 0.015, 2)
        self.box((cx, 2.95, 0.085), (min(w, 2.4) - 0.12, 0.3, 0.02), PAINT, hexc("#FFF0D0"), 0.006, 1)
        self.icon(cx, 2.95, 0.1, p.get("icon", "fish"))
        # toldo listrado inclinado com babado
        ac = p.get("awning", hexc("#E8442E"))
        depth, top, bot = 1.35, 2.72, 2.22
        ang = math.degrees(math.atan2(top - bot, depth))
        L = math.hypot(top - bot, depth)
        aw = w + 0.5
        self.box((cx, (top + bot) / 2, depth / 2), (aw, 0.025, L), CANVAS, ac, rot=R(rx=ang), uvrot=math.pi / 2)
        n = max(5, int(aw / 0.32))
        for k in range(n):
            x0k = cx - aw / 2 + (k + 0.5) * aw / n
            poly = [(-0.5, 0), (0.5, 0)] + [(math.cos(a) * 0.5, -0.45 * math.sin(a)) for a in [math.pi * q / 6 for q in range(1, 6)]]
            poly = [(x0k + px * aw / n, bot + py * 0.42) for px, py in poly]
            self.prism((0, 0, depth), poly, 0.02, CANVAS, ac, uvoff=(k * 0.125, 0))
        for s in (-1, 1):
            self.m.tube([self.world((cx + s * aw / 2, top - 0.05, 0.02)), self.world((cx + s * aw / 2, bot, depth))], 0.015,
                        METAL, IRON, seg=6)
        self.lights.append(("awning", tuple(self.world((cx, 2.0, 0.8)))))

    def icon(self, x, y, z, kind):
        c = hexc("#FF8A3D")
        if kind == "fish":
            self.sphere((x - 0.05, y, z), 0.16, GLOSSY, hexc("#3D7DC4"), subd=2, scale=(1, 0.45, 0.2))
            self.prism((x + 0.14, y, z), [(0, 0), (0.12, 0.09), (0.12, -0.09)], 0.03, GLOSSY, hexc("#3D7DC4"))
        elif kind == "bread":
            for k in range(3):
                self.sphere((x - 0.18 + k * 0.18, y, z), 0.09, GLOSSY, hexc("#D9953E"), subd=2, scale=(1, 0.6, 0.35))
        elif kind == "flower":
            for k in range(5):
                a = k / 5 * 6.283
                self.sphere((x + math.cos(a) * 0.07, y + math.sin(a) * 0.07, z), 0.055, GLOSSY, hexc("#FF5C8A"), subd=1,
                            scale=(1, 1, 0.4))
            self.sphere((x, y, z + 0.01), 0.045, GLOSSY, hexc("#FFD23F"), subd=1, scale=(1, 1, 0.5))
        else:  # xicara
            self.cyl((x, y - 0.09, z), 0.09, 0.15, GLOSSY, c, rot=R(rx=0), seg=12)
            self.m.tube([self.world((x + 0.09, y - 0.04, z)), self.world((x + 0.15, y - 0.01, z)),
                         self.world((x + 0.09, y + 0.04, z))], 0.018, GLOSSY, c, seg=5)

    def balcony(self, cx, fy):
        bw, bd = 1.9, 0.75
        self.box((cx, fy - 0.07, bd / 2), (bw, 0.14, bd), STONE, (1, 1, 1), 0.03, 2)
        for s in (-1, 1):
            self.prism((cx + s * (bw / 2 - 0.15), fy - 0.14, 0.0), [(0, 0), (0, -0.42), (0.55, 0)], 0.1, STONE, (1, 1, 1),
                       rot=R(ry=-90))
        rh = 0.95
        # corrimao e balaustres de ferro
        self.box((cx, fy + rh, bd - 0.04), (bw - 0.04, 0.05, 0.06), METAL, IRON, 0.012, 1)
        for s in (-1, 1):
            self.box((cx + s * (bw / 2 - 0.04), fy + rh, bd / 2), (0.06, 0.05, bd - 0.04), METAL, IRON, 0.012, 1, grain="z")
        self.box((cx, fy + 0.12, bd - 0.04), (bw - 0.04, 0.03, 0.03), METAL, IRON)
        nb = int((bw - 0.1) / 0.13)
        for k in range(nb + 1):
            x = cx - (bw - 0.1) / 2 + k * (bw - 0.1) / nb
            self.cyl((x, fy, bd - 0.04), 0.012, rh, METAL, IRON, seg=6)
        for s in (-1, 1):
            for k in range(1, 5):
                z = k * (bd - 0.04) / 5
                self.cyl((cx + s * (bw / 2 - 0.04), fy, z), 0.012, rh, METAL, IRON, seg=6)
        # vasos na sacada
        for s in (-1, 1):
            px = cx + s * 0.6
            self.m.lathe((0, 0, 0), [(0.0, 0.0), (0.1, 0.0), (0.14, 0.26), (0.0, 0.26)], GLOSSY, TERRA, seg=12,
                         rot=self.xf @ T(px, fy, 0.35))
            self.sphere((px, fy + 0.38, 0.35), 0.2, LEAF, hexc("#5DAE40"), subd=2, scale=(1, 0.9, 1), seed=int(px * 50), amp=0.25,
                        freq=3.0)
            for k in range(6):
                a = k / 6 * 6.283
                self.sphere((px + math.cos(a) * 0.14, fy + 0.45 + self.rng.uniform(0, 0.08), 0.35 + math.sin(a) * 0.14), 0.04,
                            GLOSSY, hexc("#E8442E" if s < 0 else "#FFFFFF"), subd=1)

    # -- telhados ----------------------------------------------------------
    def slope(self, xf_s, width, run, pitch, col, eave_trim=True):
        """Agua de telhado em quadro proprio: cumeeira no eixo X em (0,0,0), descendo para +Z ate o beiral."""
        th = math.radians(pitch)
        L = run / math.cos(th)
        rows = max(2, int(L / 0.25))
        L = rows * 0.25
        dn = Vector((0, -math.sin(th), math.cos(th)))
        nrm = Vector((0, math.cos(th), math.sin(th)))
        # base (forro / tabuado), visto por baixo no beiral
        c = dn * (L / 2) - nrm * 0.07
        self.m.box((0, 0, 0), (width, 0.06, L + 0.05), WOOD, hexc("#8E6A48"), 0.0, 1, rot=xf_s @ T(*c) @ R(rx=pitch),
                   rng=self.rng)
        for i in range(rows):
            s_lo = L - i * 0.25
            sc = s_lo - 0.155
            cc = dn * sc + nrm * (0.01 + 0.004 * (i % 2))
            tone = tuple(x * self.rng.uniform(0.93, 1.05) for x in col)
            self.m.box((0, 0, 0), (width, 0.05, 0.31), ROOF, tone, 0.012, 1,
                       rot=xf_s @ T(*cc) @ R(rx=pitch - 3.0), uvrot=math.pi,
                       uvoff=(self.rng.uniform(0, 1), 0.155 + 0.0))
        if eave_trim:
            e = dn * L + Vector((0, -0.08, 0))
            self.m.box((0, 0, 0), (width + 0.02, 0.2, 0.05), PAINT, TRIM, 0.01, 1, rot=xf_s @ T(*e), rng=self.rng)
        return L

    def roof_eave(self, W, D, H):
        p = self.p
        pitch = p.get("pitch", 34.0)
        o, so = 0.42, 0.25
        run = D / 2 + o
        ridge_h = H + (D / 2) * math.tan(math.radians(pitch)) + 0.05
        col = p["roof_col"]
        width = W + 2 * so
        for ry in (0, 180):
            xf_s = self.xf @ T(W / 2, ridge_h, -D / 2) @ R(ry=ry)
            L = self.slope(xf_s, width, run, pitch, col)
        # cumeeira
        self.cyl((-so - 0.02, ridge_h + 0.05, -D / 2), 0.11, width + 0.04, ROOF, tuple(x * 0.85 for x in col), rot=R(rz=-90), seg=10,
                 bevel=0.02)
        # oitoes laterais
        tri = [(0.0, H), (D, H), (D / 2, ridge_h)]
        for x in (0.15, W - 0.15):
            self.prism((x, 0, 0), [(a, b) for a, b in tri], 0.3, PLASTER, p["wall"], rot=R(ry=90), uv="world")
        self.chimneys(W, D, ridge_h, pitch, "eave")

    def roof_gable(self, W, D, H):
        p = self.p
        pitch = p.get("pitch", 40.0)
        o, fo = 0.35, 0.4
        run = W / 2 + o
        ridge_h = H + (W / 2) * math.tan(math.radians(pitch)) + 0.05
        col = p["roof_col"]
        width = D + fo + 0.3
        zc = -D / 2 + fo / 2 - 0.15 + 0.15
        for ry in (90, -90):
            xf_s = self.xf @ T(W / 2, ridge_h, zc) @ R(ry=ry)
            self.slope(xf_s, width, run, pitch, col)
        self.cyl((W / 2, ridge_h + 0.05, zc + width / 2 + 0.02), 0.11, width + 0.04, ROOF, tuple(x * 0.85 for x in col), rot=R(rx=-90),
                 seg=10, bevel=0.02)
        # oitao da frente (com oculo) e dos fundos
        tri = [(0.0, H), (W, H), (W / 2, ridge_h)]
        self.prism((0, 0, -0.15), tri, 0.3, PLASTER, p["wall"], uv="world")
        self.prism((0, 0, -D + 0.15), tri, 0.3, PLASTER, p["wall"], uv="world")
        # beiral de madeira acompanhando o oitao
        th = math.atan2(ridge_h - H, W / 2)
        Lb = math.hypot(W / 2 + o, (W / 2 + o) * math.tan(th))
        for s in (-1, 1):
            mx = W / 2 + s * (W / 2 + o) / 2
            my = ridge_h - (W / 2 + o) / 2 * math.tan(th) - 0.12
            self.box((mx, my, fo - 0.02), (Lb, 0.2, 0.06), PAINT, TRIM, 0.01, 1, rot=R(rz=-s * math.degrees(th)))
        oy = H + (ridge_h - H) * 0.42
        self.cyl((W / 2, oy, -0.05), 0.42, 0.06, PLASTER, TRIM, rot=R(rx=90), seg=20, bevel=0.02)
        self.cyl((W / 2, oy, 0.005), 0.3, 0.03, "wv2_glass", (1, 1, 1), rot=R(rx=90), seg=20)
        self.box((W / 2, oy, 0.05), (0.04, 0.6, 0.04), PAINT, TRIM, grain="y")
        self.box((W / 2, oy, 0.05), (0.6, 0.04, 0.04), PAINT, TRIM)
        self.chimneys(W, D, ridge_h, pitch, "gable")

    def chimneys(self, W, D, ridge_h, pitch, kind):
        p = self.p
        for i in range(p.get("chimneys", 1)):
            if kind == "eave":
                cx = W * (0.25 + 0.5 * i) + self.rng.uniform(-0.3, 0.3)
                cz = -D / 2 - 0.7
            else:
                cx = W / 2 + 0.9
                cz = -D * (0.35 + 0.4 * i)
            top = ridge_h + 0.85
            base = ridge_h - 1.6
            self.box((cx, (top + base) / 2, cz), (0.62, top - base, 0.62), PLASTER, p["wall"], 0.02, 1, uv="world")
            self.box((cx, top - 0.18, cz), (0.68, 0.12, 0.68), STONE, (1, 1, 1), 0.02, 1)
            self.box((cx, top + 0.03, cz), (0.74, 0.08, 0.74), STONE, (1, 1, 1), 0.02, 1)
            for k in range(self.rng.choice([1, 2])):
                self.cyl((cx - 0.14 + k * 0.28, top + 0.07, cz), 0.085, 0.26, GLOSSY, TERRA, r1=0.07, seg=10)


def build_house(mb, pos, ry, params, seed, lights):
    rng = random.Random(seed)
    xf = T(*pos) @ R(ry=ry)
    h = House(mb, xf, params, rng, lights)
    return h.build()
