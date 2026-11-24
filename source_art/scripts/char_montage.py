"""Junta imagens PNG lado a lado numa faixa (strip) usando numpy do Blender. Uso: ... -- --out X.png --in a.png b.png ... [--cols N]"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np
from rbart import load_pixels, save_pixels, script_args

a = script_args()
out = a[a.index("--out") + 1]
cols = int(a[a.index("--cols") + 1]) if "--cols" in a else 0
ins = []
i = a.index("--in") + 1
while i < len(a) and not a[i].startswith("--"):
    ins.append(a[i])
    i += 1
def arg(name, default=None):
    return a[a.index(name) + 1] if name in a else default


crop = [int(v) for v in arg("--crop").split(",")] if arg("--crop") else None   # x,y,w,h a partir do canto superior esquerdo
height = int(arg("--height", 0))
up = int(arg("--upscale", 1))


def prep(path):
    im = load_pixels(path)[:, :, :3]
    if crop:
        x, y, w, h = crop
        H = im.shape[0]
        im = im[H - y - h:H - y, x:x + w]
    if height:
        # reducao por media de caixa ate a altura pedida (aprox. do que o jogo mostra), depois ampliacao inteira (vizinho mais proximo)
        f = im.shape[0] / height
        nh, nw = height, max(1, int(round(im.shape[1] / f)))
        ys = (np.arange(nh + 1) * im.shape[0] / nh).astype(int)
        xs = (np.arange(nw + 1) * im.shape[1] / nw).astype(int)
        out = np.zeros((nh, nw, 3), dtype=np.float32)
        for i in range(nh):
            for j in range(nw):
                out[i, j] = im[ys[i]:max(ys[i + 1], ys[i] + 1), xs[j]:max(xs[j + 1], xs[j] + 1)].reshape(-1, 3).mean(axis=0)
        im = out
    if up > 1:
        im = np.repeat(np.repeat(im, up, axis=0), up, axis=1)
    return im


imgs = [prep(p) for p in ins]
h = max(im.shape[0] for im in imgs)
w = max(im.shape[1] for im in imgs)
padded = []
for im in imgs:
    canvas = np.ones((h, w, 3), dtype=np.float32)
    canvas[: im.shape[0], : im.shape[1]] = im
    padded.append(canvas)
cols = cols or len(padded)
rows = []
for r in range(0, len(padded), cols):
    row = padded[r:r + cols]
    while len(row) < cols:
        row.append(np.ones((h, w, 3), dtype=np.float32))
    rows.append(np.concatenate(row, axis=1))
sheet = np.concatenate(rows[::-1], axis=0)   # imagem do Blender tem origem embaixo
alpha = np.ones(sheet.shape[:2] + (1,), dtype=np.float32)
save_pixels(np.concatenate([sheet, alpha], axis=2), out)
print("Saved:", out)


