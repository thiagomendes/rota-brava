"""RB-R1 G19: atualiza no source_art/manifest.json as entradas rastro_v2, pico_v2 e leme_v2 a partir dos GLB e info.json
reexportados (sha256, bytes, ossos, duracoes dos clipes, nota). Malha e materiais nao mudam (conferido no info.json).

Uso: python3 source_art/scripts/manifest_g19.py
"""
import hashlib
import json
import os

REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
MAN = os.path.join(REPO, "source_art", "manifest.json")
NOTE = ("RB-R1 G19 (2026-11-27): clipes novos pick_up, carry_idle, carry_walk (mesmo passo do walk), place_high, place_low, "
        "inspect%s; ossos sem deformacao HoldPoint (filho de hand.R) e HoldPoint_L (filho de hand.L) no centro da palma. "
        "Malha, materiais e texturas sem mudanca (regravados por build_%s_v2.py --anim-only sobre o .blend).")
EXTRA = {"rastro_v2": "", "pico_v2": ", climb_up_low/climb_up/climb_up_high, climb_wall, climb_top, climb_down, throw_rope, lower_rope",
         "leme_v2": ", push_cart"}
NEW_SRC = ["source_art/scripts/g19_rebuild.py", "source_art/scripts/render_g19.py", "source_art/scripts/compose_g19.py"]


def sha(p):
    h = hashlib.sha256()
    with open(p, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


with open(MAN, encoding="utf-8") as f:
    man = json.load(f)
for a in man["ativos"]:
    if a["id"] not in EXTRA:
        continue
    hid = a["id"][:-3]
    info_p = os.path.join(REPO, "source_art", "characters", a["id"], a["id"] + ".info.json")
    with open(info_p, encoding="utf-8") as f:
        info = json.load(f)
    glb = os.path.join(REPO, a["saida_glb"])
    a["glb_sha256"] = sha(glb)
    a["glb_bytes"] = os.path.getsize(glb)
    assert a["triangulos"] == info["tris"], (a["id"], a["triangulos"], info["tris"])
    assert sorted(a["materiais"]) == sorted(info["materials"]), a["id"]
    a["ossos"] = info["bones"]
    a["quantidade_ossos"] = info["bone_count"]
    a["animacoes_duracao_s"] = {k: round((v[1] - v[0]) / 30.0, 4) for k, v in sorted(info["animations"].items())
                                if not k.endswith(("_key", "_gear", "_hand"))}
    a["encaixes"] = {"HoldPoint": "hand.R", "HoldPoint_L": "hand.L"}
    a["nota_g19"] = NOTE % (EXTRA[a["id"]], hid)
    for s in NEW_SRC:
        if s not in a["origem"]:
            a["origem"].append(s)
    print(a["id"], a["glb_sha256"], a["glb_bytes"], a["quantidade_ossos"], len(a["animacoes_duracao_s"]))
with open(MAN, "w", encoding="utf-8") as f:
    json.dump(man, f, indent=2, ensure_ascii=False)
    f.write("\n")
