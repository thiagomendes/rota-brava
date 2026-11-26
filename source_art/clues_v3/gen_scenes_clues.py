"""Rota Brava · pistas F2 (RB-R1, art3d) · gera as cenas .tscn das pistas e as entradas do manifesto. Python 3 puro.

Le source_art/clues_v3/clues_v3.info.json (build_clues_v3.py, Blender) e decals_v3.info.json (gen_decals.py) e escreve:
  game/assets/models/props_v3/{captain_boot,feather,target_ring_tall}.tscn   (raiz PropsV3Piece na origem)
  game/worlds/village_v3/decals/<id>.tscn                                    (raiz Decal na origem)
  source_art/manifest.json                                                   (entradas clues_v3_*: sha256 e bytes)
Uso: python3 source_art/clues_v3/gen_scenes_clues.py   (depois do build e dos decalques; rode a importacao da Godot)
"""
import hashlib
import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, os.path.join(REPO, "source_art", "props_v3"))
import gen_scenes as GS  # noqa: E402  (texto da Godot: xf, gd_value, anim_block, wave)

OUT = os.path.join(REPO, "game", "assets", "models", "props_v3")
RES = "res://assets/models/props_v3/"
DEC_OUT = os.path.join(REPO, "game", "worlds", "village_v3", "decals")
DEC_RES = "res://worlds/village_v3/decals/"
TAU = 2 * math.pi
DATE = "2026-11-25"
SRC = "source_art/clues_v3/build_clues_v3.py"
SRC_DEC = "source_art/clues_v3/gen_decals.py"

# id: (missao, interativo, verbo, heroi, observacao)
META = {
    "captain_boot": ("M1", True, "examine", "tracker",
                     "bota do capitao caida de lado (M1.boot): junto a amarra vazia M1_EmptyMooring; le a 8 m na camera baixa"),
    "feather": ("M5", True, "examine", "tracker",
                "pena de gaivota solta (M5.feathers), opcional ao decalque decal_feather_big; balanca no vento"),
    "target_ring_tall": ("", False, "", "",
                         "anel de alvo para grama alta: o anel do chao + um anel a 0,5 m + pilar de luz suave de 1,9 m"),
}

# id do decalque: (missao, pisos testados, energia da emissao, altura da caixa de projecao, observacao)
DECALS = {
    "decal_paw_big": ("M1", "terra, grama, pedra, tabua", 0.35, 0.6, "pata do filhote grande (P4); substitui decal_paw nas trilhas"),
    "decal_paw_wet_big": ("M2", "terra, grama, pedra, tabua", 0.35, 0.6, "pata molhada grande (M2, cesto -> juncos)"),
    "decal_paw_dock": ("M1", "tabua do cais", 0.3, 0.5, "pata de lama na tabua do cais (M1.bench), junto ao barco"),
    "decal_feather_big": ("M5", "pedra, terra, grama, tabua", 0.6, 0.6, "pena de gaivota grande (M5.feathers)"),
    "decal_boot_print_l": ("M1", "tabua, terra", 0.3, 0.5, "pegada da bota do capitao, pe esquerdo (M1.boot)"),
    "decal_boot_print_r": ("M1", "tabua, terra", 0.3, 0.5, "pegada da bota do capitao, pe direito (M1.boot)"),
}


def piece_scene(pid, info):
    mission, interactive, verb, member, note = META[pid]
    meta = {"piece_id": pid, "mission": mission, "interactive": interactive, "interaction": verb, "member": member,
            "note": note, "tris": int(info["triangulos"]), "tris_budget": int(info["orcamento_tris"]), "pivot": info["pivo"],
            "provisional": False, "approval": "pendente (Thiago)", "source": SRC}
    head = ["[gd_scene format=3]", "",
            '[ext_resource type="Script" path="%sprops_v3_piece.gd" id="1_script"]' % RES]
    anims = []
    auto = ""
    body_nodes = []
    if pid == "captain_boot":
        head.append('[ext_resource type="PackedScene" path="%scaptain_boot.glb" id="2_glb"]' % RES)
        body_nodes.append('[node name="Model" parent="." instance=ExtResource("2_glb")]\n')
    elif pid == "feather":
        head.append('[ext_resource type="PackedScene" path="%sfeather.glb" id="2_glb"]' % RES)
        flutter = [("Flutter:rotation", GS.wave(12, 2.4, lambda t: (0.06 * max(0.0, math.sin(TAU * t / 2.4)) ** 2,
                                                                        0.05 * math.sin(TAU * t / 1.2),
                                                                        0.08 * math.sin(TAU * t / 2.4 + 0.6))), 0),
                   ("Flutter:position", GS.wave(12, 2.4, lambda t: (0.0, 0.008 * max(0.0, math.sin(TAU * t / 2.4)), 0.0)), 0)]
        anims = [("flutter", 2.4, True, flutter)]
        auto = "flutter"
        body_nodes.append('[node name="Flutter" type="Node3D" parent="."]\n')
        body_nodes.append('[node name="Model" parent="Flutter" instance=ExtResource("2_glb")]\n')
    elif pid == "target_ring_tall":
        head.append('[ext_resource type="PackedScene" path="%starget_ring.glb" id="2_glb"]' % RES)
        head.append('[ext_resource type="PackedScene" path="%starget_beam.glb" id="3_beam"]' % RES)
        tr = []
        for node in ("Rings", "RingsHigh"):
            tr += [(node + "/Model/pv3_ring_outer:scale", [(0.0, (0.8, 1, 0.8)), (1.2, (2.2, 1, 2.2))], 0),
                   (node + "/Model/pv3_ring_outer:transparency", [(0.0, 0.1), (1.2, 1.0)], 0),
                   (node + "/Model/pv3_ring_inner:scale", [(0.0, (1.5, 1, 1.5)), (0.599, (2.2, 1, 2.2)), (0.6, (0.8, 1, 0.8)),
                                                           (1.2, (1.5, 1, 1.5))], 0),
                   (node + "/Model/pv3_ring_inner:transparency", [(0.0, 0.55), (0.599, 1.0), (0.6, 0.1), (1.2, 0.55)], 0)]
        tr += [("Beam/Model/pv3_target_beam:transparency", GS.wave(8, 1.2, lambda t: 0.25 + 0.2 * math.cos(TAU * t / 1.2)), 0)]
        anims = [("pulse", 1.2, True, tr)]
        auto = "pulse"
        body_nodes.append('[node name="Rings" type="Node3D" parent="."]\ntransform = %s\n' % GS.xf(0, 0.03, 0))
        body_nodes.append('[node name="Model" parent="Rings" instance=ExtResource("2_glb")]\n')
        body_nodes.append('[node name="RingsHigh" type="Node3D" parent="."]\ntransform = %s\n' % GS.xf(0, 0.55, 0, 0.8))
        body_nodes.append('[node name="Model" parent="RingsHigh" instance=ExtResource("2_glb")]\n')
        body_nodes.append('[node name="Beam" type="Node3D" parent="."]\n')
        body_nodes.append('[node name="Model" parent="Beam" instance=ExtResource("3_beam")]\n')
    head.append("")
    body = ""
    if anims:
        ids = []
        for name, length, loop, tracks in anims:
            aid = "Animation_" + name
            ids.append((name, aid))
            body += GS.anim_block(aid, name, length, loop, tracks)
        body += '[sub_resource type="AnimationLibrary" id="AnimationLibrary_pv3"]\n_data = {\n%s\n}\n\n' % ",\n".join(
            '&"%s": SubResource("%s")' % (n, a) for n, a in ids)
    root = '[node name="%s" type="Node3D"]\nscript = ExtResource("1_script")\n' % "".join(
        w.capitalize() for w in ("pv3_" + pid).split("_"))
    if auto:
        root += 'autoplay_anim = &"%s"\n' % auto
    for k, v in meta.items():
        root += "metadata/%s = %s\n" % (k, GS.gd_value(v))
    lines = head + [body.rstrip("\n") + ("\n" if body else ""), root] + body_nodes
    if anims:
        lines.append('[node name="AnimationPlayer" type="AnimationPlayer" parent="."]\nlibraries = {\n&"": '
                     'SubResource("AnimationLibrary_pv3")\n}\n')
    return "\n".join(lines).replace("\n\n\n", "\n\n"), [a[0] for a in anims]


def decal_scene(did, dinfo):
    mission, floors, energy, depth, note = DECALS[did]
    sx, sz = dinfo["tamanho_decal_m"]
    name = "".join(w.capitalize() for w in did.split("_"))
    meta = {"piece_id": did, "mission": mission, "provisional": False, "tris": 0, "tris_note": "decalque projetado (sem malha)",
            "size_m": (sx, depth, sz), "visible_m": dinfo["extensao_visivel_m"], "floors": floors, "note": note,
            "front": "-Z (dedos, ponta e bico para a frente da cena)", "approval": "pendente (Thiago)", "source": SRC_DEC}
    out = ["[gd_scene format=3]", "",
           '[ext_resource type="Texture2D" path="%stex/%s_albedo.png" id="1_alb"]' % (DEC_RES, did),
           '[ext_resource type="Texture2D" path="%stex/%s_emission.png" id="2_emi"]' % (DEC_RES, did), "",
           '[node name="%s" type="Decal"]' % name,
           "size = %s" % GS.v3(sx, depth, sz),
           'texture_albedo = ExtResource("1_alb")',
           'texture_emission = ExtResource("2_emi")',
           "emission_energy = %s" % GS._n(energy),
           "normal_fade = 0.25",
           "upper_fade = 0.2",
           "lower_fade = 0.35"]
    for k, v in meta.items():
        out.append("metadata/%s = %s" % (k, GS.gd_value(v)))
    return "\n".join(out) + "\n"


def sha(path):
    with open(path, "rb") as f:
        return hashlib.sha256(f.read()).hexdigest()


def rel(p):
    return os.path.relpath(p, REPO).replace(os.sep, "/")


def main():
    with open(os.path.join(HERE, "clues_v3.info.json"), encoding="utf-8") as f:
        info = json.load(f)
    with open(os.path.join(HERE, "decals_v3.info.json"), encoding="utf-8") as f:
        dinfo = json.load(f)
    pieces = info["pecas"]
    anims_of = {}
    scene_ids = ["captain_boot", "feather", "target_ring_tall"]
    for pid in scene_ids:
        src = pieces["target_beam"] if pid == "target_ring_tall" else pieces[pid]
        if pid == "target_ring_tall":
            src = dict(src)
            src["triangulos"] = src["triangulos"] + 2 * 176        # pilar + 2 anéis do target_ring.glb
            src["orcamento_tris"] = 1000
            src["pivo"] = "centro, no chao"
        text, names = piece_scene(pid, src)
        anims_of[pid] = (names, src)
        with open(os.path.join(OUT, pid + ".tscn"), "w", encoding="utf-8", newline="\n") as f:
            f.write(text)
    for did in DECALS:
        with open(os.path.join(DEC_OUT, did + ".tscn"), "w", encoding="utf-8", newline="\n") as f:
            f.write(decal_scene(did, dinfo[did]))
    # manifesto
    man_path = os.path.join(REPO, "source_art", "manifest.json")
    with open(man_path, encoding="utf-8") as f:
        man = json.load(f)
    sources = [SRC, SRC_DEC, "source_art/clues_v3/gen_scenes_clues.py", "source_art/clues_v3/clues_v3.blend",
               "source_art/clues_v3/PROVENANCE.md", "source_art/props_v3/build_props_v3.py", "source_art/environment_v2/wv2lib.py"]
    orig = ("geometria 100% por script (bmesh e formulas proprias); nenhum modelo, malha, textura ou kit de terceiros; "
            "materiais = os do props v3 (wv2_* procedurais + pv3_* da Godot)")
    entries = []
    for pid in scene_ids:
        names, src = anims_of[pid]
        glbs = ["target_ring.glb", "target_beam.glb"] if pid == "target_ring_tall" else [pid + ".glb"]
        tscn = os.path.join(OUT, pid + ".tscn")
        e = {"id": "clues_v3_" + pid, "nome": "Ep01 v3 F2 · %s" % META[pid][4], "agente": "art3d", "status": "provisorio",
             "aprovacao": "modelo final para o jogo (nao e bloco); aprovacao estetica pendente (Thiago)", "data": DATE,
             "originalidade": orig,
             "processo": {"script": SRC, "ferramenta": "Blender %s (tools/blender.sh, headless)" % info["blender"],
                          "exportador": "glTF 2.0 binario (GLB), +Y up, metros, cor de vertice"},
             "origem": sources, "missao": META[pid][0] or "geral",
             "saida_glb": ["game/assets/models/props_v3/" + g for g in glbs],
             "glb_sha256": {g: sha(os.path.join(OUT, g)) for g in glbs},
             "glb_bytes": {g: os.path.getsize(os.path.join(OUT, g)) for g in glbs},
             "cena": rel(tscn), "cena_sha256": sha(tscn), "cena_bytes": os.path.getsize(tscn),
             "triangulos": src["triangulos"], "orcamento_tris": src["orcamento_tris"], "materiais": src["materiais"],
             "pivo": src["pivo"], "animacoes": names}
        if "tamanho_m" in src and pid != "target_ring_tall":
            e["tamanho_m"] = src["tamanho_m"]
        entries.append(e)
    for did in DECALS:
        tscn = os.path.join(DEC_OUT, did + ".tscn")
        texs = [os.path.join(DEC_OUT, "tex", "%s_%s.png" % (did, k)) for k in ("albedo", "emission")]
        entries.append({"id": "clues_v3_" + did, "nome": "Ep01 v3 F2 · decalque %s" % DECALS[did][4], "agente": "art3d",
                        "status": "provisorio", "aprovacao": "final para o jogo; aprovacao estetica pendente (Thiago)",
                        "data": DATE, "originalidade": "desenho 100% por formulas proprias (campos de distancia em numpy); "
                                                       "nenhuma imagem de terceiros; sem modelo de imagem",
                        "processo": {"script": SRC_DEC, "ferramenta": "Python 3 + numpy (PNG proprio do wv2_textures)"},
                        "origem": [SRC_DEC, "source_art/clues_v3/gen_scenes_clues.py", "source_art/environment_v2/wv2_textures.py"],
                        "missao": DECALS[did][0], "cena": rel(tscn), "cena_sha256": sha(tscn), "cena_bytes": os.path.getsize(tscn),
                        "texturas": [rel(t) for t in texs], "texturas_sha256": {os.path.basename(t): sha(t) for t in texs},
                        "texturas_bytes": {os.path.basename(t): os.path.getsize(t) for t in texs},
                        "tamanho_decal_m": dinfo[did]["tamanho_decal_m"], "extensao_visivel_m": dinfo[did]["extensao_visivel_m"],
                        "triangulos": 0})
    pscript = os.path.join(OUT, "props_v3_piece.gd")
    entries.append({"id": "clues_v3_scripts", "nome": "Ep01 v3 F2 · script das pecas (material pv3_beam)", "agente": "art3d",
                    "status": "provisorio", "data": DATE, "saida": "game/assets/models/props_v3",
                    "arquivos_sha256": {"props_v3_piece.gd": sha(pscript)},
                    "arquivos_bytes": {"props_v3_piece.gd": os.path.getsize(pscript)}})
    ids = {e["id"] for e in entries}
    man["ativos"] = [a for a in man["ativos"] if a.get("id") not in ids] + entries
    # a entrada props_v3_scripts tambem guarda o sha do props_v3_piece.gd: mantem coerente
    for a in man["ativos"]:
        if a.get("id") == "props_v3_scripts" and "props_v3_piece.gd" in a.get("arquivos_sha256", {}):
            a["arquivos_sha256"]["props_v3_piece.gd"] = sha(pscript)
            a["arquivos_bytes"]["props_v3_piece.gd"] = os.path.getsize(pscript)
    with open(man_path, "w", encoding="utf-8", newline="\n") as f:
        json.dump(man, f, indent=2, ensure_ascii=False)
        f.write("\n")
    print("CV3 cenas: %d pecas + %d decalques; manifesto: %d entradas clues_v3" % (len(scene_ids), len(DECALS), len(entries)))


if __name__ == "__main__":
    main()
