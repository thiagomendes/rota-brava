# Evidencia visual dos personagens (RB-04-chars)

Imagens ficam em `captures/rb-04/chars/` (fora do Git). Comandos usados (PowerShell 7, a partir da raiz; em chamadas diretas o `--` some, entao
passe os argumentos do Blender como array, como faz `tools/export-assets.ps1`).

```powershell
./tools/export-assets.ps1 -Images          # vistas, expressoes, malha (wireframe) e poses extremas de todos os personagens
# tiras de clipe (exemplo): quadros do walk visto de lado
$a = @('--background','--factory-startup','--python','source_art/scripts/char_render.py','--','--id','rastro','--mode','clip','--clip','walk','--frames','0,4,8,12','--view','lado')
./tools/blender.ps1 @a
# montagem de uma faixa: char_montage.py --out X.png --cols 4 --in a.png b.png ...   (--crop x,y,w,h --height 48 --upscale 5 para miniaturas)
# camera real do jogo (offset (0,7.5,9.5), fov 55), Movie Maker:
./tools/godot.ps1 --path game res://actors/characters/preview_characters.tscn --write-movie C:\tmp\f.png --fixed-fps 10 --resolution 1280x720 --quit-after 14 --old --facing=camera --zoom=1.0 --clip=idle
```

Modos de `char_render.py`: `views` (frente/lado/costas/perspectiva), `expr` (5 expressoes), `face`, `extremes` (ombro, cotovelo, joelho,
quadril, pescoco, tronco), `clip` (quadros de um clipe), `mesh` (malha). `--rest` renderiza no pose de repouso.

Camera do dock: o preview usa offset (0, 4.6, 6.2), fov 55 (preview_characters.gd, --zoom=0.4 aproxima). Antes/depois do idle: char_render.py --blend <blend antigo extraido do git> --tag _antes.
