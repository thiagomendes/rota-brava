"""RB-R1 G21: cria/atualiza no source_art/manifest.json as entradas do Lumi v2 (operador do Farol 7), dos retratos do HUD
do Lumi e da base Farol 7 (sala, cadeira, luz giratoria, casa-torre e fundo), a partir dos .info.json dos builds e do
sha256 dos arquivos versionados. Python puro (sem Blender).

Uso: python3 -I source_art/farol7_base/manifest_g21.py
"""
import hashlib
import json
import os

REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
MAN = os.path.join(REPO, "source_art", "manifest.json")
SV2 = "source_art/characters/secondary_v2/"
F7 = "source_art/farol7_base/"
FPS = 30.0
DATA = "2026-11-27"
ORIG_CHAR = ("geometria procedural propria (SKIN + SUBSURF, metaballs, torno, bmesh, deslocamento em numpy); texturas pintadas por "
             "formula; rig e animacoes autorais por script; nenhum modelo, malha, rig, mocap, textura, HDRI ou personagem-base de terceiros")


def sha(path):
    h = hashlib.sha256()
    with open(os.path.join(REPO, path), "rb") as f:
        h.update(f.read())
    return h.hexdigest()


def size(path):
    return os.path.getsize(os.path.join(REPO, path))


def upsert(man, aid):
    for a in man["ativos"]:
        if a["id"] == aid:
            return a
    e = {"id": aid}
    man["ativos"].append(e)
    return e


def main():
    with open(MAN, encoding="utf-8") as f:
        man = json.load(f)
    # ------------------------------------------------------------ Lumi v2
    with open(os.path.join(REPO, SV2 + "lumi_v2.info.json"), encoding="utf-8") as f:
        inf = json.load(f)
    glb = "game/assets/models/characters/lumi_v2.glb"
    e = upsert(man, "lumi_v2")
    e.update({
        "nome": "Lumi v2 (operador do radio da base Farol 7)", "papel": "radio", "agente": "art3d", "status": "provisorio",
        "processo": {"script": SV2 + "build_lumi_v2.py", "ferramenta": "Blender 4.5.16 (tools/blender.sh, headless)",
                     "exportador": "glTF 2.0 binario (GLB), +Y up, metros, skin, shape keys, animacoes por NLA, texturas JPEG embutidas, "
                                   "KHR_materials_clearcoat",
                     "tecnicas": "base adulta v2 (sv2_human: cabeca adulta, tronco+mangas SKIN + SUBSURF 3 com forma em numpy, calca, maos "
                                 "encaixadas na manga, tenis); cabelo crespo e cavanhaque por metaballs; fone de arco por perfil varrido "
                                 "sobre o cabelo (raycast), conchas por torno, haste do microfone e antena por tubo; gola por raycast na "
                                 "jaqueta + solidify; emblema do peito por prisma; faixa coral, emblema das costas, ziper, ribanas e "
                                 "sombra de barba pintados; textura assada e pintada no pipeline do trio v2 (rv2_tex)"},
        "origem": [SV2 + "build_lumi_v2.py", SV2 + "sv2_human.py", SV2 + "sv2_lib.py", "source_art/characters/rastro_v2/rv2_tex.py",
                   "source_art/scripts/hero_lib.py", "source_art/scripts/hero_face.py", "source_art/scripts/hero_anim.py",
                   "source_art/scripts/char_anim.py", "source_art/scripts/char_lib.py", "source_art/scripts/rbart.py", SV2 + "lumi_v2.blend",
                   SV2 + "render_lineup_g21.py"],
        "saida_glb": glb, "glb_sha256": sha(glb), "glb_bytes": size(glb), "cena": "game/actors/characters/lumi_model.tscn",
        "importacao": "game/lookdev/gltf_pbr_import.gd (mipmaps e verniz, como no trio v2)",
        "triangulos": inf["tris"], "triangulos_por_objeto": inf["tris_por_objeto"], "materiais": inf["materials"],
        "texturas": inf.get("texturas", {}), "objetos": inf["objects"], "ossos": inf["bones"], "quantidade_ossos": inf["bone_count"],
        "animacoes_duracao_s": {k: round((v[1] - v[0]) / FPS, 4) for k, v in sorted(inf["animations"].items())},
        "shape_keys": inf["shape_keys"], "altura_m": inf["height_m"], "razao_cabeca_altura": inf["head_ratio"],
        "velocidade_walk_mps": 0.0, "velocidade_run_mps": 0.0, "aprovacao": "pendente (reviewer, depois Thiago)",
        "originalidade": ORIG_CHAR, "data": DATA,
        "nota": "RB-R1 G21: operador do Farol 7 (decisao de Thiago: homem, ~30 anos, nome Lumi). Clipes idle (loop, braços "
                "relaxados), talk (3,0 s, visemas), wave (1,6 s) e point (1,2 s). Sem clipes sentados (idle_seated, turn_chair) "
                "nesta entrega."})
    # ------------------------------------------------------------ retratos do HUD do Lumi
    names = ["lumi_%s.png" % x for x in ("neutra", "alegre", "surpresa")]
    e = upsert(man, "portraits_v2_lumi")
    e.update({
        "nome": "Retratos da legenda do Lumi (operador do radio do Farol 7)", "agente": "art3d", "status": "provisorio",
        "processo": {"script": "source_art/scripts/hero_portraits_v2.py",
                     "ferramenta": "Blender 4.5.16 (tools/blender.sh, headless), Cycles CPU 96 amostras + OpenImageDenoise",
                     "exportador": "PNG RGBA 512x512, fundo transparente (mesmo formato e caminho dos retratos v2)",
                     "comando": "bash tools/blender.sh --background source_art/characters/secondary_v2/lumi_v2.blend --python "
                                "source_art/scripts/hero_portraits_v2.py -- lumi"},
        "origem": [SV2 + "lumi_v2.blend", "source_art/characters/rastro_v2/rv2_render.py", "source_art/scripts/hero_portraits_v2.py"],
        "saida": "game/ui/portraits", "arquivos_sha256": {n: sha("game/ui/portraits/" + n) for n in names},
        "arquivos_bytes": {n: size("game/ui/portraits/" + n) for n in names},
        "luz": "luz de cena das provas v2 (rv2_render.scene_lights), sem o chao de prova",
        "aprovacao": "pendente (Thiago)", "originalidade": "render do personagem procedural do projeto (lumi_v2.blend); nada de terceiros",
        "data": DATA, "nota": "RB-R1 G21: substituem o icone de farol na legenda do radio quando o gameplay ligar `radio` ao Lumi."})
    # ------------------------------------------------------------ base Farol 7
    with open(os.path.join(REPO, F7 + "farol7_base.info.json"), encoding="utf-8") as f:
        fi = json.load(f)
    pec = fi["pecas"]
    glbs = [p["glb"] for p in pec.values()]
    scene = "game/worlds/farol7_base/farol7_base.tscn"
    e = upsert(man, "farol7_base")
    e.update({
        "nome": "Base Farol 7: sala do radio, cadeira, luz giratoria, casa-torre e fundo (mar e Vila Mare ao longe)",
        "agente": "art3d", "status": "provisorio", "aprovacao": "pendente (reviewer, depois Thiago)", "data": DATA,
        "originalidade": "geometria 100% por script (bmesh e formulas proprias, wv2lib); nenhum modelo, malha, textura ou kit de "
                         "terceiros; materiais = texturas procedurais do mundo v2 + materiais f7_* da Godot; pinos do mapa usam os "
                         "retratos do HUD do proprio projeto",
        "processo": {"script": F7 + "build_farol7_base.py", "ferramenta": "Blender 4.5.16 LTS (tools/blender.sh, headless)",
                     "exportador": "glTF 2.0 binario (GLB), +Y up, metros, cor de vertice, UV em metros",
                     "cena": "python3 -I " + F7 + "gen_scene.py"},
        "origem": [F7 + "build_farol7_base.py", F7 + "gen_scene.py", F7 + "manifest_g21.py", F7 + "farol7_base.blend",
                   F7 + "PROVENANCE.md", "source_art/environment_v2/wv2lib.py", "source_art/props_v3/build_props_v3.py",
                   "game/worlds/farol7_base/farol7_base.gd", "game/worlds/farol7_base/f7_pin.gdshader"],
        "saida_glb": glbs, "glb_sha256": {os.path.basename(g): sha(g) for g in glbs},
        "glb_bytes": {os.path.basename(g): size(g) for g in glbs},
        "cena": scene, "cena_sha256": sha(scene), "cena_bytes": size(scene),
        "triangulos": sum(p["triangulos"] for p in pec.values()),
        "triangulos_por_peca": {k: p["triangulos"] for k, p in pec.items()},
        "orcamento_tris": {k: p["orcamento_tris"] for k, p in pec.items()},
        "materiais": sorted({m for p in pec.values() for m in p["materiais"]}),
        "pivo": {k: p["pivo"] for k, p in pec.items()}, "marcos": fi["marcos"],
        "nota": "RB-R1 G21: palco de cutscene fora da vila para os planos 9a/9b/9c da abertura (docs/proposals/g21_farol7.md "
                "secao 2). A ligacao com a ficha da cutscene e do gameplay."})
    with open(MAN, "w", encoding="utf-8") as f:
        json.dump(man, f, indent=2, ensure_ascii=False)
        f.write("\n")
    print("manifesto: lumi_v2, portraits_v2_lumi, farol7_base")


if __name__ == "__main__":
    main()
