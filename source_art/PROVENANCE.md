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
