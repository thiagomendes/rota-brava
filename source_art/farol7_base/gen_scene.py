"""Rota Brava · RB-R1 G21 · base Farol 7: gera game/worlds/farol7_base/farol7_base.tscn (palco de cutscene fora da vila)
a partir dos GLB de build_farol7_base.py e das medidas em farol7_base.info.json. Python 3 puro. PROVISORIO.

Marcadores de camera olham para -Z local (como Camera3D). Uso: python3 -I source_art/farol7_base/gen_scene.py
"""
import json
import math
import os

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(REPO, "game", "worlds", "farol7_base", "farol7_base.tscn")
RES = "res://assets/models/farol7_base/"
EXTERIOR = (80.0, 0.0, 0.0)      # casa-torre por fora, longe da sala (a escotilha olha para o norte e nao a ve)


def norm(v):
    L = math.sqrt(sum(x * x for x in v))
    return tuple(x / L for x in v)


def cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def look(pos, target):
    """Transform3D de um no em `pos` olhando para `target` (-Z local para o alvo, Y para cima)."""
    f = norm(tuple(t - p for t, p in zip(target, pos)))
    z = tuple(-x for x in f)
    x = norm(cross((0.0, 1.0, 0.0), z))
    y = cross(z, x)
    return xf((x, y, z), pos)


def yaw(deg, pos):
    a = math.radians(deg)
    return xf(((math.cos(a), 0.0, -math.sin(a)), (0.0, 1.0, 0.0), (math.sin(a), 0.0, math.cos(a))), pos)


def xf(cols, pos):
    x, y, z = cols
    rows = (x[0], y[0], z[0], x[1], y[1], z[1], x[2], y[2], z[2])
    return "Transform3D(%s)" % ", ".join("%.5g" % v for v in rows + tuple(pos))


def add(v, o):
    return tuple(a + b for a, b in zip(v, o))


def main():
    with open(os.path.join(HERE, "farol7_base.info.json"), encoding="utf-8") as f:
        info = json.load(f)
    mk = info["marcos"]
    chair = tuple(mk["Base_Chair"])
    sky = tuple(mk["Base_Skylight"])
    mic = tuple(mk["Mic"])
    port = tuple(mk["Base_Porthole"])
    lines = ['[gd_scene load_steps=7 format=3]', '',
             '[ext_resource type="Script" path="res://worlds/farol7_base/farol7_base.gd" id="1_script"]',
             '[ext_resource type="PackedScene" path="%sfarol7_room.glb" id="2_room"]' % RES,
             '[ext_resource type="PackedScene" path="%sfarol7_chair.glb" id="3_chair"]' % RES,
             '[ext_resource type="PackedScene" path="%sfarol7_beacon.glb" id="4_beacon"]' % RES,
             '[ext_resource type="PackedScene" path="%sfarol7_tower.glb" id="5_tower"]' % RES,
             '[ext_resource type="PackedScene" path="%sfarol7_backdrop.glb" id="6_backdrop"]' % RES, '',
             '[node name="Farol7Base" type="Node3D"]', 'script = ExtResource("1_script")', 'metadata/provisional = true',
             'metadata/agent = "art3d"', 'metadata/stage = "base_farol7"', '',
             '[node name="StageEnvironment" type="Node3D" parent="."]', '',
             '[node name="Room" parent="." instance=ExtResource("2_room")]', '',
             '[node name="Backdrop" parent="." instance=ExtResource("6_backdrop")]', '',
             # cadeira: de costas para a camera (assento virado para a mesa) no comeco do plano 9a
             '[node name="Chair" parent="." instance=ExtResource("3_chair")]', 'transform = %s' % yaw(180.0, chair), '',
             # assento: o Lumi sentado fica filho deste no e gira junto com a cadeira (Farol7Base.set_chair_yaw)
             '[node name="Seat" type="Marker3D" parent="Chair"]', 'transform = %s' % yaw(180.0, (0.0, 0.0, 0.06)), '',
             '[node name="SkylightBeacon" parent="." instance=ExtResource("4_beacon")]',
             'transform = %s' % xf(((1, 0, 0), (0, 1, 0), (0, 0, 1)), (sky[0], 3.30, sky[2])), '']
    lights = [
        # luz amarela da claraboia: poca no chao e brilho no teto
        ("SkylightPool", "SpotLight3D", look((sky[0], 3.4, sky[2]), (sky[0] + 0.15, 0.0, sky[2] + 0.35)),
         {"light_color": 'Color(1, 0.86, 0.42, 1)', "light_energy": "12.0", "spot_range": "5.0", "spot_angle": "24.0",
          "spot_attenuation": "0.6", "shadow_enabled": "true"}),
        ("SkylightGlow", "OmniLight3D", xf(((1, 0, 0), (0, 1, 0), (0, 0, 1)), (sky[0], 2.6, sky[2])),
         {"light_color": 'Color(1, 0.84, 0.36, 1)', "light_energy": "0.9", "omni_range": "3.2"}),
        ("DeskLamp", "OmniLight3D", xf(((1, 0, 0), (0, 1, 0), (0, 0, 1)), (-0.90, 1.05, -1.75)),
         {"light_color": 'Color(1, 0.88, 0.62, 1)', "light_energy": "0.9", "omni_range": "1.6", "shadow_enabled": "true"}),
        ("Key", "SpotLight3D", look((-1.3, 2.5, 1.2), (0.0, 1.0, -1.2)),
         {"light_color": 'Color(1, 0.95, 0.86, 1)', "light_energy": "3.0", "spot_range": "7.0", "spot_angle": "40.0",
          "shadow_enabled": "true"}),
        ("Fill", "OmniLight3D", xf(((1, 0, 0), (0, 1, 0), (0, 0, 1)), (0.9, 2.1, 1.4)),
         {"light_color": 'Color(0.8, 0.88, 1, 1)', "light_energy": "0.7", "omni_range": "6.0"}),
        ("PortholeSpill", "OmniLight3D", xf(((1, 0, 0), (0, 1, 0), (0, 0, 1)), (port[0], port[1], port[2] + 0.35)),
         {"light_color": 'Color(0.85, 0.93, 1, 1)', "light_energy": "0.6", "omni_range": "2.4"}),
    ]
    for name, typ, t, props in lights:
        lines += ['[node name="%s" type="%s" parent="."]' % (name, typ), 'transform = %s' % t]
        lines += ['%s = %s' % (k, v) for k, v in props.items()]
        lines.append('')
    ext = EXTERIOR
    lines += ['[node name="Exterior" type="Node3D" parent="."]', 'transform = %s' % xf(((1, 0, 0), (0, 1, 0), (0, 0, 1)), ext), '',
              '[node name="Tower" parent="Exterior" instance=ExtResource("5_tower")]', '',
              '[node name="TowerBeacon" parent="Exterior" instance=ExtResource("4_beacon")]',
              'transform = %s' % xf(((1.6, 0, 0), (0, 1.6, 0), (0, 0, 1.6)), (0.0, 7.32, 0.0)), '',
              '[node name="TowerBeaconLight" type="OmniLight3D" parent="Exterior"]',
              'transform = %s' % xf(((1, 0, 0), (0, 1, 0), (0, 0, 1)), (0.0, 7.75, 0.0)),
              'light_color = Color(1, 0.85, 0.35, 1)', 'light_energy = 2.0', 'omni_range = 5.0', '']
    markers = [
        ("Base_Chair", yaw(180.0, chair)),
        ("Base_Seat", yaw(0.0, (chair[0], 0.0, chair[2] - 0.06))),
        ("Base_LumiStand", yaw(180.0, (-0.30, 0.0, -0.95))),
        ("Base_Porthole", xf(((1, 0, 0), (0, 1, 0), (0, 0, 1)), port)),
        ("Base_Mic", xf(((1, 0, 0), (0, 1, 0), (0, 0, 1)), mic)),
        # 9a (dentro): da escotilha ate a cadeira de costas; aberto, mostra mapa, emblema e claraboia
        ("Base_CamWide", look((0.70, 1.75, 1.90), (0.05, 1.20, -1.30))),
        # 9b: plano medio frontal; mapa atras a esquerda
        ("Base_CamFront", look((0.45, 1.45, 1.30), (-0.30, 1.22, -1.00))),
        # 9c: mao no microfone, escotilha e a vila ao fundo
        ("Base_CamMic", look((1.35, 1.50, -0.80), (0.50, 1.15, -1.80))),
        ("Base_Exterior", xf(((1, 0, 0), (0, 1, 0), (0, 0, 1)), ext)),
        ("Base_CamExterior", look(add(ext, (7.0, 1.2, -15.0)), add(ext, (0.0, 4.0, 0.0)))),
    ]
    lines += ['[node name="Markers" type="Node3D" parent="."]', '']
    for name, t in markers:
        lines += ['[node name="%s" type="Marker3D" parent="Markers"]' % name, 'transform = %s' % t, '']
    lines += ['[node name="Actors" type="Node3D" parent="."]', '']
    with open(OUT, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))
    print("cena:", os.path.relpath(OUT, REPO))


if __name__ == "__main__":
    main()
