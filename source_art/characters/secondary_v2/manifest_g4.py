"""RB-R1 G4: cria/atualiza no source_art/manifest.json as entradas dos secundarios v2 (captain_v2, pup_v2, amora_v2) a
partir dos .info.json dos builds e do sha256 dos GLB versionados. As entradas antigas (captain, pup, amora) ficam como
estao: descrevem os GLB da geracao anterior, que continuam no disco. Python puro (sem Blender).

Uso: python3 -I source_art/characters/secondary_v2/manifest_g4.py
"""
import hashlib
import json
import os

REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".."))
MAN = os.path.join(REPO, "source_art", "manifest.json")
SV2 = "source_art/characters/secondary_v2/"
FPS = 30.0
COMMON_SRC = [SV2 + "sv2_lib.py", "source_art/characters/rastro_v2/rv2_tex.py", "source_art/scripts/hero_lib.py",
              "source_art/scripts/hero_face.py", "source_art/scripts/char_lib.py", "source_art/scripts/rbart.py"]
TEC = ("textura assada e pintada no pipeline do trio v2 (rv2_tex: UV Smart Project, mapas de posicao/normal/parte/AO no Cycles, "
       "pintura procedural em numpy, normal map da altura, cor + ORM, Principled com verniz -> KHR_materials_clearcoat); "
       "malha por grupo de material (uma atlas por grupo)")
ORIG = ("geometria procedural propria (SKIN + SUBSURF, metaballs, torno, bmesh, deslocamento em numpy); texturas pintadas por formula; "
        "rig e animacoes autorais por script; nenhum modelo, malha, rig, mocap, textura, HDRI ou personagem-base de terceiros")
ITEMS = {
    "captain_v2": dict(nome="Capitao v2", papel="captain", build="build_captain_v2.py", extra=[SV2 + "sv2_human.py", "source_art/scripts/hero_anim.py",
                                                                                            "source_art/scripts/char_anim.py"],
                       cena="game/actors/characters/captain_model.tscn",
                       tecnicas="base adulta v2 (sv2_human: cabeca adulta, tronco+mangas SKIN + SUBSURF 3 com forma em numpy, calca, maos, sapatos); "
                                "quepe por torno, pala por grade + solidify, barba e cabelo por metaballs; " + TEC,
                       nota="RB-R1 G4: capitao refeito no padrao do trio v2 e com proporcao adulta (cabeca ~21% da altura). Mesmo esqueleto de "
                            "28 ossos e mesmos clipes (idle, walk, wave, thanks) do captain.glb; velocidades recalculadas pela proporcao nova. G4 r2: pulso continua para dentro da manga (sem vao), idle relaxado (bracos soltos, respiracao)."),
    "pup_v2": dict(nome="Filhote v2", papel="pup", build="build_pup_v2.py", extra=["source_art/scripts/pup_build.py"],
                   cena="game/actors/characters/pup_model.tscn",
                   tecnicas="corpo e pernas numa malha SKIN + SUBSURF 3 com patas assentadas; cabeca por metaballs; orelhas, nariz, coleira e "
                            "pingente em bmesh; creme do focinho/peito/patas pintado; " + TEC,
                   nota="RB-R1 G4: filhote refeito no padrao do trio v2. Mesmo esqueleto (23 ossos, mesmas posicoes) e mesmos clipes "
                        "(idle, wag, jump_happy, bark, step_on_horn, walk, run) do pup_build.py, mesmas velocidades. G4 r2: pelo curto pintado e na normal (tufos, fios), sem verniz no pelo."),
    "amora_v2": dict(nome="Dona Amora v2", papel="vendor", build="build_amora_v2.py", extra=[SV2 + "sv2_human.py", "source_art/characters/amora/build_amora.py",
                                                                                           "source_art/scripts/hero_anim.py", "source_art/scripts/char_anim.py"],
                     cena="game/actors/characters/amora_model.tscn",
                     tecnicas="base adulta v2 (sv2_human) com vestido inteirico (blusa + saia rodada numa malha SKIN), meia, sapatos, avental por "
                              "grade projetada na saia + solidify, peitilho, lenco por tubo achatado; bolinhas de amora, punhos e pespontos "
                              "pintados; " + TEC,
                     nota="RB-R1 G4: Dona Amora refeita com proporcao de senhora (cabeca ~21% da altura; antes 27%, lia como crianca), "
                          "olhos menores, linhas de sorriso e fios grisalhos pintados. Mesmos clipes (idle, wave, thanks, point, talk). G4 r2: rosto de senhora (mandibula mais longa, sem bochecha de bebe, olhos menores e caidos, sobrancelha fina, pes de galinha), pulso dentro da manga, idle relaxado."),
}


def sha(path):
    h = hashlib.sha256()
    with open(os.path.join(REPO, path), "rb") as f:
        h.update(f.read())
    return h.hexdigest()


def main():
    with open(MAN, encoding="utf-8") as f:
        man = json.load(f)
    by_id = {a["id"]: a for a in man["ativos"]}
    for aid, it in ITEMS.items():
        with open(os.path.join(REPO, SV2 + aid + ".info.json"), encoding="utf-8") as f:
            inf = json.load(f)
        glb = "game/assets/models/characters/%s.glb" % aid
        e = by_id.get(aid)
        if e is None:
            e = {"id": aid}
            man["ativos"].append(e)
        e.update({
            "nome": it["nome"], "papel": it["papel"], "agente": "art3d", "status": "provisorio",
            "processo": {"script": SV2 + it["build"], "ferramenta": "Blender 4.5.16 (tools/blender.sh, headless)",
                         "exportador": "glTF 2.0 binario (GLB), +Y up, metros, skin, shape keys, animacoes por NLA, texturas JPEG embutidas, "
                                       "KHR_materials_clearcoat",
                         "tecnicas": it["tecnicas"]},
            "origem": [SV2 + it["build"]] + it["extra"] + COMMON_SRC + [SV2 + aid + ".blend"],
            "saida_glb": glb, "glb_sha256": sha(glb), "glb_bytes": os.path.getsize(os.path.join(REPO, glb)), "cena": it["cena"],
            "importacao": "game/lookdev/gltf_pbr_import.gd (mipmaps e verniz, como no trio v2)",
            "triangulos": inf["tris"], "triangulos_por_objeto": inf["tris_por_objeto"], "materiais": inf["materials"],
            "texturas": inf.get("texturas", {}), "objetos": inf["objects"], "ossos": inf["bones"], "quantidade_ossos": inf["bone_count"],
            "animacoes_duracao_s": {k: round((v[1] - v[0]) / FPS, 4) for k, v in sorted(inf["animations"].items())},
            "shape_keys": inf["shape_keys"], "altura_m": inf["height_m"],
            "velocidade_walk_mps": inf.get("walk_speed_mps", 0.0), "velocidade_run_mps": inf.get("run_speed_mps", 0.0),
            "aprovacao": "pendente (Thiago)", "originalidade": ORIG, "data": "2026-11-26", "nota": it["nota"]})
        if "head_ratio" in inf:
            e["razao_cabeca_altura"] = inf["head_ratio"]
    # retratos da legenda (G4 r2): renderizados de novo a partir dos .blend v2, mesmo script, caminho e formato
    pr = by_id["portraits_v2_npc"]
    names = ["%s_%s.png" % (i, e_) for i in ("captain", "pup") for e_ in ("neutra", "alegre", "surpresa")]
    pr["nome"] = "Retratos da legenda do capitao e do filhote (render dos modelos v2 do G4)"
    pr["processo"]["comando"] = ("bash tools/blender.sh --background source_art/characters/secondary_v2/<id>_v2.blend --python "
                                 "source_art/scripts/hero_portraits_v2.py -- <id>  (id = captain | pup)")
    pr["origem"] = [SV2 + "captain_v2.blend", SV2 + "pup_v2.blend", "source_art/characters/rastro_v2/rv2_render.py",
                    "source_art/scripts/hero_portraits_v2.py"]
    pr["arquivos_sha256"] = {n: sha("game/ui/portraits/" + n) for n in names}
    pr["arquivos_bytes"] = {n: os.path.getsize(os.path.join(REPO, "game/ui/portraits", n)) for n in names}
    pr["enquadramento"] = ("busto, elevacao 6 graus, giro -20 graus, lente 85 mm (como os herois v2); capitao v2 a 1,62 m do meio "
                           "do osso head + 3 cm (cabeca adulta menor, cabe o quepe), filhote a 0,95 m menos 2 cm; calibrado lado a lado "
                           "com leme_neutra")
    pr["originalidade"] = "renders dos personagens procedurais do projeto (captain_v2.blend, pup_v2.blend); nada de terceiros; sem modelo de imagem"
    pr["data_g4"] = "2026-11-26"
    pr["nota_g4"] = "RB-R1 G4 r2 (art3d): regerados dos modelos v2 (capitao adulto, filhote com pelo) no mesmo caminho; agente original ux."
    with open(MAN, "w", encoding="utf-8") as f:
        json.dump(man, f, indent=2, ensure_ascii=False)
        f.write("\n")
    print("manifesto: %s" % ", ".join(ITEMS))


if __name__ == "__main__":
    main()
