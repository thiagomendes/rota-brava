# Base Farol 7 (RB-R1 G21) · proveniência — PROVISÓRIO

Palco de cutscene fora da vila para os planos 9a/9b/9c da abertura (`docs/proposals/g21_farol7.md`, seção 2): a sala do
rádio onde o Lumi trabalha, a cadeira giratória, a luz giratória amarela da base (na claraboia e no topo da casa-torre),
o exterior da casa-torre na ponta das pedras e o fundo visto pela escotilha (mar, a Vila Maré pequena e o farol da vila
ao longe, listrado de creme e vermelho como o do M7).

## Origem de tudo (100% gerado no projeto)
| Item | Como foi feito |
|---|---|
| Geometria | `build_farol7_base.py`: caixas, cilindros, tornos, prismas, tubos e esferas da `source_art/environment_v2/wv2lib.py` (bmesh do Blender), placas com furo redondo (escotilha e claraboia) e torno sem tampas feitos aqui |
| Emblema da parede, do colete e da porta da torre | contornos do escudo, da faixa e da rosa dos ventos de `source_art/props_v3/build_props_v3.py` (os mesmos das moedas do Ep01 v3, tirados do SVG da marca do projeto), importados só para leitura |
| Acabamento | materiais `wv2_*`/`pv3_*` da vila v2.1 (texturas procedurais do projeto, trocadas na Godot por `WV2Materials`/`PropsV3Piece`) e `f7_*` em `game/worlds/farol7_base/farol7_base.gd` (mar, feixe, lâmpada, vidro do farolete, LED, tela) |
| Pinos do mapa | discos com os retratos do HUD do trio (`game/ui/portraits/<id>_alegre.png`, renders do próprio projeto) pelo shader `f7_pin.gdshader` |
| Cena | `gen_scene.py` escreve `game/worlds/farol7_base/farol7_base.tscn` (luzes, marcadores, instâncias); o céu e o sol são os da vila v3, montados em código |

Nenhum modelo, malha, textura, foto, HDRI ou kit de terceiros.

## Arquivos
- Fonte: `build_farol7_base.py`, `gen_scene.py`, `manifest_g21.py`, `farol7_base.blend`, `farol7_base.info.json`.
- Saída: `game/assets/models/farol7_base/{farol7_room,farol7_chair,farol7_beacon,farol7_tower,farol7_backdrop}.glb`
  (glTF 2.0, metros, +Y para cima, cor de vértice, UV em metros); cena `game/worlds/farol7_base/farol7_base.tscn`.
- Marcadores: `Base_Chair`, `Base_Seat`, `Base_LumiStand`, `Base_Porthole`, `Base_Mic`, `Base_CamWide`, `Base_CamFront`,
  `Base_CamMic`, `Base_Exterior`, `Base_CamExterior`.

## Reproduzir
```bash
bash tools/blender.sh --background --factory-startup --python source_art/farol7_base/build_farol7_base.py
python3 -I source_art/farol7_base/gen_scene.py
python3 -I source_art/farol7_base/manifest_g21.py
bash tools/godot.sh --headless --path game --import
xvfb-run -a -s "-screen 0 1600x900x24" bash tools/godot.sh --path game --rendering-driver vulkan --resolution 1600x900 \
  res://tests/capture_g21.tscn -- --g21-out=$PWD/captures/g21 --g21-shots=front,wide,mic,exterior
```

## Limites conhecidos
- Sem vidro na escotilha e na claraboia: o vidro transparente lia como chapa leitosa na captura.
- Sem clipes sentados do Lumi (`idle_seated`, `turn_chair`): a cadeira tem pivô e `set_chair_yaw`, mas o Lumi sentado
  ainda não existe; a captura mostra o Lumi de pé no console.
- A ligação com a ficha da cutscene (`stage` ou instância longe da vila) é do `gameplay`. O nó `StageEnvironment`
  (céu e sol) sai com `use_own_environment = false` se o palco for instanciado dentro de uma cena que já tem ambiente.
