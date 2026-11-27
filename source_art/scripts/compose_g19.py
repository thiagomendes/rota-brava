"""RB-R1 G19: junta as pranchas de cada heroi (render_g19.py) numa prancha por clipe, uma linha por heroi, com rotulos.

Uso: python3 source_art/scripts/compose_g19.py <pasta_dos_renders> <saida>
"""
import os
import sys

from PIL import Image, ImageDraw

SRC, OUT = sys.argv[1], sys.argv[2]
HEROES = ("rastro", "pico", "leme")
os.makedirs(OUT, exist_ok=True)
for clip in sorted(os.listdir(SRC)):
    d = os.path.join(SRC, clip)
    rows = [(h, Image.open(os.path.join(d, h + ".png")).convert("RGB")) for h in HEROES if os.path.exists(os.path.join(d, h + ".png"))]
    if not rows:
        continue
    lab = 26
    W = max(im.width for _, im in rows)
    H = sum(im.height + lab for _, im in rows) + lab
    out = Image.new("RGB", (W, H), (247, 245, 240))
    dr = ImageDraw.Draw(out)
    dr.text((10, 6), "G19 - %s (4 quadros, RB-R1, PROVISORIO)" % clip, fill=(20, 20, 20))
    y = lab
    for h, im in rows:
        dr.text((10, y + 6), h, fill=(60, 60, 60))
        out.paste(im, (0, y + lab))
        y += im.height + lab
    p = os.path.join(OUT, clip + ".png")
    out.save(p)
    print("PRANCHA", p, out.size)
