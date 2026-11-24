# Proveniencia dos ativos 3D (RB-03-art) - PROVISORIO

- **Agente:** `art3d`. **Status:** `provisorio`; nenhuma escolha artistica esta aprovada (aprovacao: Thiago).
- **Originalidade:** toda geometria nasce de scripts Python do Blender versionados em `source_art/scripts/`
  (primitivas `bmesh`, secoes procedurais, modificador Solidify). Nenhum modelo, malha, personagem-base,
  textura ou kit de terceiros foi baixado ou importado. Materiais sao cores do projeto (Principled BSDF), sem imagens.
  O elenco nao copia designs existentes; as silhuetas sao proprias.
- **Ferramenta:** Blender 4.5.16 LTS portatil fixado em `tools/toolchain.json` (`tools/blender.ps1`).
- **Fontes:** `source_art/characters/rastro/rastro.blend`, `source_art/vehicles/boat/boat.blend`,
  `source_art/characters/cast/cast_silhouettes.blend` (9 candidatas). Parametros: `source_art/params/rastro.json`.
- **Saidas:** `game/assets/models/rastro.glb`, `boat.glb` (glTF binario, metros, +Y up). Manifesto: `source_art/manifest.json`.
- **Reproducao:** `./tools/export-assets.ps1` (`-Images` regenera pranchas/vistas/malhas em `captures/rb-03/art`, fora do Git).
  Geometria, nomes e materiais sao reproduziveis; os **bytes** do GLB nao sao identicos entre execucoes
  (duas exportacoes consecutivas deram hashes diferentes), por isso o manifesto guarda o hash do arquivo versionado.
- **Orientacao:** frente do personagem/barco em +Y no Blender = -Z na Godot (verificado por teste: nariz com z < 0, proa em -Z).
- **Pivos:** Rastro nos pes; barco no centro de giro (eixo longitudinal, 40% do comprimento a partir da popa; popa y=-2,0, proa y=+3,0 no Blender).
- **Convencao Godot:** nao nomear objetos com sufixo `-wheel`/`_wheel` etc. (o importador cria `VehicleWheel3D`); o volante chama-se `Boat_Helm`.


## RB-04-chars: personagens organicos com rig e animacao (PROVISORIO)

- **Agente:** `art3d`. **Status:** `provisorio`; aprovacao artistica pendente (Thiago). Substitui o Rastro de bastoes do RB-03
  (`rastro.blend`, `build_rastro.py`, `params/rastro.json` ficam so como historico; o GLB antigo foi removido e nao e mais exportado).
- **Originalidade:** geometria 100% procedural em Python do Blender (`source_art/scripts/char_*.py`): modificador SKIN + SUBSURF a partir
  de grafos de vertices com raio, elipsoides/tubos/revolucoes `bmesh`, cascas deslocadas pela normal (colete). Rig (28 ossos), pesos
  (distancia ao segmento do osso + suavizacao + copia por vizinho mais proximo para camadas de roupa), shape keys do rosto e animacoes
  (FK + IK de dois ossos, 30 fps) sao escritos por script. **Nenhum** modelo, malha, rig, animacao/mocap, textura ou personagem-base de
  terceiros; nenhum design de serie existente foi imitado. Materiais sao cores do projeto (Principled BSDF, sem imagens).
- **Fontes:** `source_art/characters/rb04/<id>/<id>.blend` (+ `.info.json`) para `rastro`, `leme`, `extra_a`, `extra_b`, `extra_c`.
  Scripts: `char_build.py` (malha, rig, pesos, export), `char_lib.py` (SKIN, tubos, rig, pesos, IK), `char_face.py` (olhos, palpebras,
  sobrancelhas, boca e shape keys `neutra/atenta/surpresa/alegre/blink`), `char_anim.py` (clipes), `char_render.py` e `char_montage.py`
  (imagens de verificacao, fora do Git). Base compartilhada: `rbart.py`.
- **Saidas:** `game/assets/models/characters/{rastro,leme,extra_a,extra_b,extra_c}.glb` (metros, +Y up, skin, morph targets, animacoes
  exportadas por trilhas NLA com o nome do clipe). Manifesto: `source_art/manifest.json` (ossos, animacoes e duracoes, shape keys, triangulos).
- **Reproducao:** `./tools/export-assets.ps1` (`-Images` regenera vistas, expressoes, malha e poses extremas em `captures/rb-04/chars`,
  fora do Git). Como no RB-03, os **bytes** do GLB mudam a cada exportacao; o manifesto guarda o hash do arquivo versionado.
  Procedimento das demais imagens (tiras de clipes, camera do jogo): `source_art/characters/EVIDENCE.md`.
- **Convencoes:** origem nos pes; frente +Y no Blender = -Z na Godot; lado direito (`.R`) = +X. Ossos: root, hips, spine, chest, neck, head,
  shoulder/upper_arm/forearm/hand/thigh/shin/foot/toe `.L/.R` e auxiliares sem deformacao (`hand_tip`, `toe_tip`, `heel`) usados para medir
  contato dos pes e alcance da mao. Loop dos clipes `idle`, `walk`, `idle_wheel` e definido em `CharacterVisual` (o glTF nao tem flag de loop).
- **Limites conhecidos:** triangulos altos para o tamanho em tela (Rastro ~22,6 mil); sem LOD; roupa nao tem simulacao (caderno/bolsa
  acompanham o quadril); cabelo e colete mostram arestas duras em poses extremas; `walk` tem velocidade nominal de ~0,69 m/s no referencial do corpo.
