"""RB-R1 arte das cenas: atualiza no source_art/manifest.json as entradas do filhote (walk/run), do Pico v2 (point) e cria a
de Dona Amora, a partir dos .info.json dos builds e do sha256 dos GLB versionados. Python puro (sem Blender).

Uso: python3 -I source_art/scripts/manifest_arte_cenas.py
"""
import hashlib
import json
import os

REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
MAN = os.path.join(REPO, "source_art", "manifest.json")
FPS = 30.0


def sha(path):
    h = hashlib.sha256()
    with open(os.path.join(REPO, path), "rb") as f:
        h.update(f.read())
    return h.hexdigest()


def info(path):
    with open(os.path.join(REPO, path), encoding="utf-8") as f:
        return json.load(f)


def durations(inf):
    return {k: round((v[1] - v[0]) / FPS, 4) for k, v in sorted(inf["animations"].items())}


def common(entry, inf, glb):
    entry["glb_sha256"] = sha(glb)
    entry["glb_bytes"] = os.path.getsize(os.path.join(REPO, glb))
    entry["triangulos"] = inf["tris"]
    entry["animacoes_duracao_s"] = durations(inf)
    entry["altura_m"] = inf["height_m"]
    entry["velocidade_walk_mps"] = inf.get("walk_speed_mps", 0.0)
    entry["velocidade_run_mps"] = inf.get("run_speed_mps", 0.0)


def main():
    with open(MAN, encoding="utf-8") as f:
        man = json.load(f)
    by_id = {a["id"]: a for a in man["ativos"]}
    # filhote
    pup = by_id["pup"]
    inf = info("source_art/characters/heroes/pup/pup.info.json")
    common(pup, inf, pup["saida_glb"])
    pup["objetos"] = inf["objects"]
    pup["data_arte_cenas"] = "2026-11-26"
    pup["nota_arte_cenas"] = ("RB-R1 arte das cenas: clipes walk (1,0 s, 3 ciclos de passo lateral, %.3f m/s) e run (0,6 s, 2 ciclos de "
                              "meio-galope com fase aerea, %.3f m/s) por IK de 2 ossos por pata, sem root motion; rabo passa a nascer "
                              "dentro da garupa (antes ficava ~7 cm solto) e so pesa no quadril e nos ossos do rabo."
                              % (inf["walk_speed_mps"], inf["run_speed_mps"]))
    # Pico v2
    pv = by_id["pico_v2"]
    inf = info("source_art/characters/pico_v2/pico_v2.info.json")
    common(pv, inf, pv["saida_glb"])
    pv["razao_cabeca_altura"] = inf["head_ratio"]
    pv["nota_arte_cenas"] = "RB-R1 arte das cenas (2026-11-26): clipe point (1,2 s, sem loop) para as falas que apontam; demais clipes iguais."
    # Dona Amora
    inf = info("source_art/characters/amora/amora.info.json")
    glb = "game/assets/models/characters/amora.glb"
    am = by_id.get("amora") or {"id": "amora"}
    am.update({
        "nome": "Dona Amora", "papel": "vendor", "agente": "art3d", "status": "provisorio",
        "processo": {"script": "source_art/characters/amora/build_amora.py",
                     "ferramenta": "Blender 4.5.16 (tools/blender.sh, headless)",
                     "exportador": "glTF 2.0 binario (GLB), +Y up, metros, skin, shape keys, animacoes por NLA, KHR_materials_clearcoat",
                     "tecnicas": "construtor procedural dos adultos (hero_lib, proporcao EL: SKIN + SUBSURF, metaballs, bmesh) + partes "
                                 "proprias (coque, lenco, saia por torno com pregas, avental por grade + solidify, amoras); pesos por "
                                 "distancia normalizada; cinematica FK/IK em Python; acabamento vinil por cor (Principled + coat)"},
        "origem": ["source_art/characters/amora/build_amora.py", "source_art/scripts/hero_lib.py", "source_art/scripts/hero_face.py",
                   "source_art/scripts/hero_anim.py", "source_art/scripts/char_lib.py", "source_art/scripts/char_anim.py",
                   "source_art/scripts/rbart.py", "source_art/characters/amora/amora.blend"],
        "referencia_do_projeto": "game/ui/brand/icons/vendor.svg (retrato da E7: cores, coque, lenco com amoras, avental)",
        "saida_glb": glb, "cena": "game/actors/characters/amora_model.tscn",
        "materiais": inf["materials"], "objetos": inf["objects"], "ossos": inf["bones"], "quantidade_ossos": inf["bone_count"],
        "shape_keys": inf["shape_keys"], "razao_cabeca_altura": inf["head_ratio"],
        "variacao": "amora", "aprovacao": "pendente (Thiago)",
        "originalidade": "geometria procedural propria; rig e animacoes autorais por script; nenhum modelo, malha, rig, mocap, textura "
                         "ou personagem-base de terceiros",
        "data": "2026-11-26",
        "nota": "RB-R1 arte das cenas: feirante parada na barraca (marcador M4_Vendor). Clipes idle (loop), wave, thanks, point, talk "
                "(3,0 s, comeca e termina na mesma pose; o loop de talk depende de CharacterVisual.LOOPING, do gameplay). Sem walk.",
    })
    common(am, inf, glb)
    # mundo: marcadores novos (M4_Vendor, Cut_VillageWide, Cut_LighthouseView) mudaram village_world.tscn
    ws = by_id["world_v3_village_scenes"]
    vw = "game/worlds/village_v3/village_world.tscn"
    ws["arquivos_sha256"]["village_world.tscn"] = sha(vw)
    ws["arquivos_bytes"]["village_world.tscn"] = os.path.getsize(os.path.join(REPO, vw))
    ws["nota_arte_cenas"] = ("RB-R1 arte das cenas (2026-11-26): marcadores M4_Vendor, Cut_VillageWide e Cut_LighthouseView "
                             "(estes dois com metadata camera/look_at), tambem em wv3_collision.py EXTRA_MARKERS.")
    if "amora" not in by_id:
        idx = [a["id"] for a in man["ativos"]].index("pup") + 1
        man["ativos"].insert(idx, am)
    with open(MAN, "w", encoding="utf-8") as f:
        json.dump(man, f, indent=2, ensure_ascii=False)
        f.write("\n")
    for k in ("pup", "pico_v2", "amora"):
        e = {a["id"]: a for a in man["ativos"]}[k]
        print(k, e["glb_sha256"], e["triangulos"], e["animacoes_duracao_s"])


if __name__ == "__main__":
    main()
