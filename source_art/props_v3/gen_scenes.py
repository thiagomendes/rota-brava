"""Rota Brava · pecas v3 · gera as cenas .tscn (uma por peca) e as entradas do manifesto. Python 3 puro.

Le source_art/props_v3/props_v3.info.json (escrito por build_props_v3.py) e escreve:
  game/assets/models/props_v3/<id>.tscn   (raiz na origem, escala real, metadados, AnimationPlayer quando ha animacao)
  source_art/manifest.json                (entradas props_v3_*: sha256 e bytes do GLB e da cena, tris, orcamento)
Uso: python3 source_art/props_v3/gen_scenes.py   (depois do build do Blender; rode a importacao da Godot em seguida)
"""
import hashlib
import json
import math
import os

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(REPO, "game", "assets", "models", "props_v3")
RES = "res://assets/models/props_v3/"
TAU = 2 * math.pi

# metadados de jogo: missao, interativo, verbo, heroi que age, observacao
META = {
    "cloth_tshirt": ("M2", True, "free_then_hang", "climber", "camiseta rosa (presa no telhado do galpao)"),
    "cloth_scarf": ("M2", True, "free_then_hang", "climber", "lenco azul de bolinhas (preso no galho)"),
    "cloth_sock": ("M2", True, "find_then_hang", "tracker", "meia amarela com pelo do filhote (nos juncos; a pista)"),
    "basket": ("M2", False, "", "", "cesto de vime ao pe do varal (cenario)"),
    "fountain_leaves": ("M3", True, "pull", "climber", "tufo removivel na bacia de cima do chafariz"),
    "ball": ("M3", True, "examine", "tracker", "bola do filhote presa na grade; rola ate as barracas"),
    "crate_apple": ("M4", True, "carry_deliver", "pilot", "entrega na barraca vermelha (M4_Stall_Apple)"),
    "crate_lemon": ("M4", True, "carry_deliver", "pilot", "entrega na barraca amarela (M4_Stall_Lemon)"),
    "crate_grapes": ("M4", True, "carry_deliver", "pilot", "entrega na barraca azul (M4_Stall_Grapes)"),
    "fish": ("M5", True, "pick", "climber", "peixe roubado (no bico da gaivota ou solto no telhado)"),
    "gull": ("M5", True, "chase", "", "gaivota: pousa, foge e voa; leva o peixe no bico"),
    "tow_rope": ("M6", True, "throw", "climber", "corda de reboque (rolo ou trecho esticado de comprimento variavel)"),
    "help_arrow": ("", False, "", "", "seta de ajuda (degrau 3), ponta na origem"),
    "target_ring": ("", False, "", "", "pulso de destaque do alvo (anel no chao)"),
    # G19 (acoes no jogo): pecas novas
    "clothes_bench": ("M2", True, "step_up_hang", "", "banco de 2 degraus ao pe do varal (o heroi sobe para alcancar a corda)"),
    "fruit_box_apple": ("M4", True, "carry_deliver", "pilot", "caixinha de macas: sai do carrinho para a barraca vermelha"),
    "fruit_box_lemon": ("M4", True, "carry_deliver", "pilot", "caixinha de limoes: sai do carrinho para a barraca amarela"),
    "fruit_box_grapes": ("M4", True, "carry_deliver", "pilot", "caixinha de uvas: sai do carrinho para a barraca azul"),
    "lens_mount": ("M7", True, "place", "climber", "encaixe da lente na parede do farol, junto a galeria"),
    "hand_compass": ("M7", True, "hold", "pilot", "bussola de mao da Leme (mira a lanterna)"),
}
EMBLEM_META = {"paw": "tracker", "carabiner": "climber", "helm": "pilot", "compass": "", "star": ""}
for k, hero in EMBLEM_META.items():
    META["emblem_" + k] = ("", True, "pick", hero, "emblema de missao (moeda-brasao) com icone %s" % k)
EXTRA_META = {
    "crate_apple": {"stall": "M4_Stall_Apple", "fruit": "apple", "color": "e0412b"},
    "crate_lemon": {"stall": "M4_Stall_Lemon", "fruit": "lemon", "color": "f2c81d"},
    "crate_grapes": {"stall": "M4_Stall_Grapes", "fruit": "grapes", "color": "4a6fd8"},
    "fruit_box_apple": {"stall": "M4_Stall_Apple", "fruit": "apple", "color": "e0412b"},
    "fruit_box_lemon": {"stall": "M4_Stall_Lemon", "fruit": "lemon", "color": "f2c81d"},
    "fruit_box_grapes": {"stall": "M4_Stall_Grapes", "fruit": "grapes", "color": "4a6fd8"},
}
for k in EMBLEM_META:
    EXTRA_META["emblem_" + k] = {"icon": k}


# ---------------------------------------------------------------- texto da Godot
def v3(x, y, z):
    return "Vector3(%s, %s, %s)" % tuple(_n(c) for c in (x, y, z))


def _n(c):
    c = round(float(c), 5)
    return ("%d" % c) if c == int(c) else ("%r" % c)


def xf(x=0.0, y=0.0, z=0.0, s=1.0):
    return "Transform3D(%s, 0, 0, 0, %s, 0, 0, 0, %s, %s, %s, %s)" % (_n(s), _n(s), _n(s), _n(x), _n(y), _n(z))


def gd_value(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return _n(v)
    if isinstance(v, tuple):
        return v3(*v)
    return json.dumps(v, ensure_ascii=False)


def track(i, path, keys, kind="value", interp=1, update=0):
    """keys: [(tempo, valor)]. Devolve as linhas do trilho i."""
    times = ", ".join(_n(t) for t, _ in keys)
    trans = ", ".join("1" for _ in keys)
    vals = ", ".join(gd_value(v) for _, v in keys)
    return ("tracks/{i}/type = \"value\"\ntracks/{i}/imported = false\ntracks/{i}/enabled = true\n"
            "tracks/{i}/path = NodePath(\"{p}\")\ntracks/{i}/interp = {interp}\ntracks/{i}/loop_wrap = true\n"
            "tracks/{i}/keys = {{\n\"times\": PackedFloat32Array({t}),\n\"transitions\": PackedFloat32Array({tr}),\n"
            "\"update\": {u},\n\"values\": [{v}]\n}}\n").format(i=i, p=path, interp=interp, t=times, tr=trans, u=update, v=vals)


def anim_block(aid, name, length, loop, tracks):
    out = "[sub_resource type=\"Animation\" id=\"%s\"]\nresource_name = \"%s\"\nlength = %s\n" % (aid, name, _n(length))
    if loop:
        out += "loop_mode = 1\n"
    for i, (path, keys, update) in enumerate(tracks):
        out += track(i, path, keys, update=update)
    return out + "\n"


def wave(n, length, fn):
    """Amostra fn(t) em n+1 pontos de 0 a length (o ultimo igual ao primeiro nos loops)."""
    return [(length * k / n, fn(length * k / n)) for k in range(n + 1)]


# ---------------------------------------------------------------- animacoes por peca
def anims_for(pid):
    """Devolve (no_animado, posicao_do_no, lista de (nome, duracao, loop, trilhos)), autoplay."""
    if pid.startswith("cloth_"):
        ph = {"cloth_tshirt": 0.0, "cloth_scarf": 0.7, "cloth_sock": 1.4}[pid]
        sway = [("Cloth:rotation", wave(12, 2.4, lambda t: (0.09 * math.sin(TAU * t / 2.4 + ph) + 0.03,
                                                            0.0, 0.035 * math.sin(TAU * t / 1.2 + ph))), 0)]
        shake = [("Cloth:rotation", [(0.0, (0.0, 0.0, 0.0)), (0.1, (0.35, 0.0, 0.12)), (0.2, (-0.25, 0.0, -0.1)),
                                     (0.32, (0.18, 0.0, 0.06)), (0.45, (-0.08, 0.0, -0.03)), (0.6, (0.0, 0.0, 0.0))], 0)]
        return "Cloth", (0, 0, 0), [("sway", 2.4, True, sway), ("shake", 0.6, False, shake)], "sway"
    if pid == "fountain_leaves":
        rustle = [("Tuft:rotation", wave(8, 1.6, lambda t: (0.025 * math.sin(TAU * t / 1.6), 0.0,
                                                             0.02 * math.sin(TAU * t / 0.8))), 0)]
        pull = [("Tuft:position", [(0.0, (0, 0, 0)), (0.25, (0.0, 0.25, 0.0)), (0.6, (0.15, 0.55, 0.1)), (1.0, (0.3, 0.4, 0.2))], 0),
                ("Tuft:rotation", [(0.0, (0, 0, 0)), (0.25, (0.3, 0.0, 0.1)), (1.0, (1.2, 0.8, 0.6))], 0),
                ("Tuft:scale", [(0.0, (1, 1, 1)), (0.25, (1.1, 1.2, 1.1)), (0.75, (0.8, 0.8, 0.8)), (1.0, (0.01, 0.01, 0.01))], 0),
                ("Tuft:visible", [(0.0, True), (1.0, False)], 1)]
        back = [("Tuft:position", [(0.0, (0, 0, 0))], 0), ("Tuft:rotation", [(0.0, (0, 0, 0))], 0),
                ("Tuft:scale", [(0.0, (1, 1, 1))], 0), ("Tuft:visible", [(0.0, True)], 1)]
        return "Tuft", (0, 0, 0), [("rustle", 1.6, True, rustle), ("pull_out", 1.0, False, pull), ("reset", 0.05, False, back)], ""
    if pid == "ball":
        roll = [("Spin:rotation", [(0.0, (0, 0, 0)), (0.5, (math.pi, 0, 0)), (1.0, (TAU, 0, 0))], 0)]
        bounce = [("Spin:position", [(0.0, (0, 0.16, 0)), (0.18, (0, 0.42, 0)), (0.36, (0, 0.16, 0)), (0.48, (0, 0.24, 0)),
                                     (0.6, (0, 0.16, 0))], 0)]
        return "Spin", (0, 0.16, 0), [("roll", 1.0, True, roll), ("bounce", 0.6, False, bounce)], ""
    if pid == "fish":
        flop = [("Body:rotation", wave(8, 0.5, lambda t: (0.0, 0.35 * math.sin(TAU * t / 0.5), 0.12 * math.sin(TAU * t / 0.25))), 0)]
        return "Body", (0, 0, 0), [("flop", 0.5, True, flop)], ""
    if pid.startswith("emblem_"):
        spin = [("Coin:rotation", [(0.0, (0, 0, 0)), (1.2, (0, math.pi, 0)), (2.4, (0, TAU, 0))], 0),
                ("Coin:position", wave(8, 2.4, lambda t: (0.0, 0.75 + 0.05 * math.sin(TAU * t / 1.2), 0.0)), 0)]
        collect = [("Coin:position", [(0.0, (0, 0.75, 0)), (0.35, (0, 1.3, 0)), (0.6, (0, 1.45, 0))], 0),
                   ("Coin:rotation", [(0.0, (0, 0, 0)), (0.6, (0, 3 * TAU, 0))], 0),
                   ("Coin:scale", [(0.0, (1, 1, 1)), (0.3, (1.25, 1.25, 1.25)), (0.6, (0.01, 0.01, 0.01))], 0),
                   ("Coin:visible", [(0.0, True), (0.6, False)], 1)]
        return "Coin", (0, 0.75, 0), [("spin", 2.4, True, spin), ("collect", 0.6, False, collect)], "spin"
    if pid == "help_arrow":
        point = [("Arrow:position", wave(8, 2.0, lambda t: (0.0, 0.15 * (0.5 - 0.5 * math.cos(TAU * t / 1.0)), 0.0)), 0),
                 ("Arrow:rotation", [(0.0, (0, 0, 0)), (1.0, (0, math.pi, 0)), (2.0, (0, TAU, 0))], 0)]
        appear = [("Arrow:scale", [(0.0, (0.01, 0.01, 0.01)), (0.22, (1.15, 1.15, 1.15)), (0.35, (1, 1, 1))], 0)]
        return "Arrow", (0, 0, 0), [("point", 2.0, True, point), ("appear", 0.35, False, appear)], "point"
    if pid == "target_ring":
        # anel de fora: cresce de 0,8 a 2,2 e some em 1,2 s; anel de dentro igual, meio ciclo atrasado
        tr = [("Rings/Model/pv3_ring_outer:scale", [(0.0, (0.8, 1, 0.8)), (1.2, (2.2, 1, 2.2))], 0),
              ("Rings/Model/pv3_ring_outer:transparency", [(0.0, 0.1), (1.2, 1.0)], 0),
              ("Rings/Model/pv3_ring_inner:scale", [(0.0, (1.5, 1, 1.5)), (0.599, (2.2, 1, 2.2)), (0.6, (0.8, 1, 0.8)),
                                                    (1.2, (1.5, 1, 1.5))], 0),
              ("Rings/Model/pv3_ring_inner:transparency", [(0.0, 0.55), (0.599, 1.0), (0.6, 0.1), (1.2, 0.55)], 0)]
        return "Rings", (0, 0.03, 0), [("pulse", 1.2, True, tr)], "pulse"
    return "", (0, 0, 0), [], ""


# ---------------------------------------------------------------- cena
def scene_text(pid, info):
    mission, interactive, verb, member, note = META[pid]
    script = {"gull": "gull.gd", "tow_rope": "tow_rope.gd"}.get(pid, "props_v3_piece.gd")
    node, pos, anims, auto = anims_for(pid)
    if pid == "gull":
        auto = "perch_idle"
    lines = ["[gd_scene format=3]", "",
             '[ext_resource type="Script" path="%s%s" id="1_script"]' % (RES, script),
             '[ext_resource type="PackedScene" path="%s%s.glb" id="2_glb"]' % (RES, pid)]
    if pid == "gull":
        lines.append('[ext_resource type="PackedScene" path="%sfish.tscn" id="3_fish"]' % RES)
    lines.append("")
    body = ""
    if anims:
        ids = []
        for name, length, loop, tracks in anims:
            aid = "Animation_" + name
            ids.append((name, aid))
            body += anim_block(aid, name, length, loop, tracks)
        body += '[sub_resource type="AnimationLibrary" id="AnimationLibrary_pv3"]\n_data = {\n%s\n}\n\n' % ",\n".join(
            '&"%s": SubResource("%s")' % (n, a) for n, a in ids)
    lines.append(body.rstrip("\n") + ("\n" if body else ""))
    root = "[node name=\"%s\" type=\"Node3D\"]\nscript = ExtResource(\"1_script\")\n" % "".join(
        w.capitalize() for w in ("pv3_" + pid).split("_"))
    if auto:
        root += "autoplay_anim = &\"%s\"\n" % auto
    if pid == "tow_rope":
        root += "length = 3.0\n"
    meta = {"piece_id": pid, "mission": mission, "interactive": interactive, "interaction": verb, "member": member,
            "note": note, "tris": int(info["triangulos"]) + int(info.get("tris_extra", 0)), "tris_budget": int(info["orcamento_tris"]), "pivot": info["pivo"],
            "provisional": False, "approval": "pendente (Thiago)", "source": "source_art/props_v3/build_props_v3.py"}
    meta.update(EXTRA_META.get(pid, {}))
    for k, v in meta.items():
        root += "metadata/%s = %s\n" % (k, gd_value(v))
    lines.append(root)
    parent = "."
    if node:
        lines.append('[node name="%s" type="Node3D" parent="."]\ntransform = %s\n' % (node, xf(*pos)))
        parent = node
    lines.append('[node name="Model" parent="%s" instance=ExtResource("2_glb")]\n' % parent)
    if pid == "gull":
        lines.append('[node name="BeakSocket" type="BoneAttachment3D" parent="Model/gull_rig/Skeleton3D"]\n'
                     'bone_name = "head"\nbone_idx = 2\n')
        lines.append('[node name="FishHold" type="Marker3D" parent="Model/gull_rig/Skeleton3D/BeakSocket"]\n')
        lines.append('[node name="Fish" parent="Model/gull_rig/Skeleton3D/BeakSocket/FishHold" instance=ExtResource("3_fish")]\n'
                     '')
    if pid == "tow_rope":
        lines.append('[node name="End" type="Marker3D" parent="."]\ntransform = %s\n' % xf(0, 0, 3.0))
    if anims:
        lines.append('[node name="AnimationPlayer" type="AnimationPlayer" parent="."]\nlibraries = {\n&"": '
                     'SubResource("AnimationLibrary_pv3")\n}\n')
    if pid == "gull":
        lines.append('[editable path="Model"]\n')
    return "\n".join(lines).replace("\n\n\n", "\n\n")


def sha(path):
    with open(path, "rb") as f:
        return hashlib.sha256(f.read()).hexdigest()


def main():
    with open(os.path.join(HERE, "props_v3.info.json"), encoding="utf-8") as f:
        info = json.load(f)
    pieces = info["pecas"]
    order = sorted(pieces.keys(), key=lambda k: (k != "fish", k))   # fish antes da gaivota (que o instancia)
    pieces["gull"]["tris_extra"] = pieces["fish"]["triangulos"]   # a cena da gaivota inclui o peixe no bico
    for pid in order:
        with open(os.path.join(OUT, pid + ".tscn"), "w", encoding="utf-8", newline="\n") as f:
            f.write(scene_text(pid, pieces[pid]))
    # manifesto
    man_path = os.path.join(REPO, "source_art", "manifest.json")
    with open(man_path, encoding="utf-8") as f:
        man = json.load(f)
    sources = ["source_art/props_v3/build_props_v3.py", "source_art/props_v3/render_props_v3.py",
               "source_art/props_v3/gen_scenes.py", "source_art/props_v3/props_v3.blend", "source_art/props_v3/PROVENANCE.md",
               "source_art/environment_v2/wv2lib.py"]
    entries = []
    for pid in sorted(pieces):
        p = pieces[pid]
        glb = os.path.join(OUT, pid + ".glb")
        tscn = os.path.join(OUT, pid + ".tscn")
        _, _, anims, _ = anims_for(pid)
        names = sorted(p.get("animacoes", {}).keys()) if pid == "gull" else [a[0] for a in anims]
        e = {"id": "props_v3_" + pid, "nome": "Ep01 v3 · %s" % META[pid][4], "agente": "art3d",
             "status": "provisorio", "aprovacao": "modelo final para o jogo (nao e bloco); aprovacao estetica pendente (Thiago)",
             "data": info["data"],
             "originalidade": "geometria 100% por script (bmesh e formulas proprias); nenhum modelo, malha, textura ou kit "
                              "de terceiros; materiais = texturas procedurais do mundo v2 + 5 materiais pv3_* da Godot",
             "processo": {"script": "source_art/props_v3/build_props_v3.py",
                          "ferramenta": "Blender %s (tools/blender.sh, headless)" % info["blender"],
                          "exportador": "glTF 2.0 binario (GLB), +Y up, metros, cor de vertice, UV em metros" +
                                        (", esqueleto + acoes NLA" if pid == "gull" else "")},
             "origem": sources, "missao": META[pid][0] or "geral",
             "saida_glb": "game/assets/models/props_v3/%s.glb" % pid, "glb_sha256": sha(glb), "glb_bytes": os.path.getsize(glb),
             "cena": "game/assets/models/props_v3/%s.tscn" % pid, "cena_sha256": sha(tscn), "cena_bytes": os.path.getsize(tscn),
             "triangulos": p["triangulos"], "orcamento_tris": p["orcamento_tris"], "materiais": p["materiais"],
             "pivo": p["pivo"], "animacoes": names}
        if pid == "gull":
            e["ossos"] = p["ossos"]
            e["animacoes_detalhe"] = p["animacoes"]
        entries.append(e)
    scripts = ["props_v3_piece.gd", "gull.gd", "tow_rope.gd"]
    entries.append({"id": "props_v3_scripts", "nome": "Ep01 v3 · scripts das cenas das pecas", "agente": "art3d",
                    "status": "provisorio", "data": info["data"], "saida": "game/assets/models/props_v3", "arquivos_sha256": {s: sha(os.path.join(OUT, s)) for s in scripts},
                    "arquivos_bytes": {s: os.path.getsize(os.path.join(OUT, s)) for s in scripts}})
    ids = {e["id"] for e in entries}
    man["ativos"] = [a for a in man["ativos"] if a.get("id") not in ids] + entries
    with open(man_path, "w", encoding="utf-8", newline="\n") as f:
        json.dump(man, f, indent=2, ensure_ascii=False)
        f.write("\n")
    print("PV3 cenas: %d; manifesto: %d entradas props_v3" % (len(order), len(entries)))


if __name__ == "__main__":
    main()
