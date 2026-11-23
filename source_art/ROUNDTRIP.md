# Ida e volta Blender -> Godot (RB-03-art)

Alteracao pequena na fonte: `source_art/params/rastro.json`, `hat_height` 1.0 -> 1.6 (copa do chapeu mais alta).
Sonda: `game/actors/preview/probe_roundtrip.gd` (`./tools/godot.ps1 --headless --path game --script res://actors/preview/probe_roundtrip.gd`).

## Comandos
```powershell
./tools/godot.ps1 --headless --path game --script res://actors/preview/probe_roundtrip.gd   # antes
# editar source_art/params/rastro.json (hat_height 1.6)
./tools/export-assets.ps1
./tools/godot.ps1 --headless --path game --import
./tools/godot.ps1 --headless --path game --script res://actors/preview/probe_roundtrip.gd   # depois
# reverter para 1.0, repetir export + import + sonda
```

## Resultado (executado)
| Medida (Godot, GLB importado) | Antes | Depois (1.6) | Revertido (1.0) |
|---|---|---|---|
| altura do Rastro (AABB) | 1,3083 m | 1,3883 m | 1,3083 m |
| altura da copa+aba do chapeu (AABB) | 0,2665 m | 0,4264 m | 0,2665 m |
| sha256 de `actors/rastro/rastro.tscn` | 498117d8... | 498117d8... (igual) | 498117d8... (igual) |
| sha256 de `actors/boat_model/boat_model.tscn` | 49213ffb... | igual | igual |
| cor do casco lida do material | #f5c518 | #f5c518 | #f5c518 |

A cena propria nao foi tocada. Capturas (fora do Git): `captures/rb-03/art/roundtrip_antes.png` e `roundtrip_depois.png`
(camera do jogo, zoom 0,3); sondas em `roundtrip_*.txt`.

## Decisao
Revertido para `hat_height = 1.0`: a copa mais alta funciona, mas altera a silhueta A ja comparada nas pranchas;
a versao final fica consistente com o teste e com as pranchas. Nota: o GLB nao e byte-identico entre exportacoes
(hash mudou apos reverter), apesar de AABB, nos e materiais voltarem iguais.
