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


### Atualizacao RB-04-chars (2a rodada)
- **Pico (`climber`)** criado: `char_build.py --id pico` (capacete leve, corda enrolada nas costas + tiracolo, 4 mosquetoes, mochila, luvas, jaqueta verde #5AA469), mesmo rig de 28 ossos e as mesmas shape keys, `mat_pico_*`. Clipes: `idle`, `walk`, `react_surprise`, `pull_rope` (1,6 s, dois puxoes), `look_up`. Cena `game/actors/characters/pico_model.tscn`.
- **Idle dos figurantes/Pico:** pes quase juntos (calcanhares ~12 cm), tronco < 2 graus; `CharacterVisual.play` agora troca de clipe na hora quando o no nao esta processando (evita congelar a ultima pose da caminhada).
- **Polimento:** cabelo sem o bloco lateral, mangas mais finas com punho, colete e peso da camisa mais suaves, `walk` com passo de 0,34 m (velocidade nominal 0,586 m/s, `CharacterVisual.WALK_SPEED_MPS`), agachada com tronco a 24 graus.
- **Triangulos (antes -> depois):** Rastro 22.588 -> 14.944; Leme 20.208 -> 14.076; figurantes 11.448/11.920/10.696 -> 8.420/9.212/7.844; Pico 16.568 (novo).


## RB-R1 lookdev (D11/D12): materiais procedurais e vitrine de luz (PROVISORIO)
- **Agente:** `art3d`. **Status:** `provisorio`, so vitrine; aprovacao de Thiago pendente. Nada do jogo foi alterado alem do renderizador.
- **Originalidade:** sem geometria nova e sem imagem. Os materiais sao sombreadores Godot escritos para o projeto em
  `game/lookdev/materials/` (`ld_*.gdshader` + presets `mat_ld_*.tres`): ruido de valor, celulas (Voronoi), aneis de madeira e
  tramas de tecido calculados no sombreador, relevo pelo gradiente numerico da altura. Nenhuma textura, material ou sombreador de terceiros.
  O jogo citado por Thiago como referencia de qualidade nao foi copiado (nenhum elemento, cor-assinatura ou forma).
- **Uso:** `game/lookdev/lookdev_materials.gd` (`LookdevMaterials.make/apply`) troca os materiais em tempo de execucao, sem editar os recursos
  importados. Vitrine: `game/lookdev/lookdev_dock.tscn` (`--lookdev=before|after`, `--lookdev-cam=low|close|high`).


## RB-R1 E3b: retratos do HUD dos herois v2 (PROVISORIO)
- **Agente:** `art3d`, 2026-11-25. **Status:** `provisorio`; aprovacao de Thiago pendente. Manifesto: entrada `portraits_v2`
  (a entrada `portraits` passa a cobrir so `captain` e `pup`, que continuam os da primeira geracao).
- **Originalidade:** renders dos proprios herois v2 do projeto (`source_art/characters/{rastro,pico,leme}_v2/*.blend`, geometria,
  rig, shape keys e texturas 100% por script, ver os PROVENANCE de cada pasta). Nenhum modelo, imagem ou retrato de terceiros;
  sem modelo de imagem.
- **Processo:** `source_art/scripts/hero_portraits_v2.py` abre o `.blend` v2 (sem salvar), poe o corpo no quadro 0 do `idle`,
  o rosto na shape key `neutra`/`alegre`/`surpresa`, esconde `Acc_*` (colete da Leme) e renderiza em Cycles (96 amostras +
  OpenImageDenoise) com a luz de cena das provas v2, fundo transparente. Mesmo tamanho (512x512), formato (PNG RGBA) e caminho
  (`game/ui/portraits/<id>_<expr>.png`) dos antigos; enquadramento calibrado lado a lado com os antigos (camera 1,60 m do meio
  do osso `head` menos 7 cm, elevacao 6 graus, giro -20 graus, lente 85 mm).
- **Reproduzir:** `bash tools/blender.sh --background source_art/characters/<id>_v2/<id>_v2.blend --python source_art/scripts/hero_portraits_v2.py -- <id>`
  para `rastro`, `pico`, `leme`. Comparacao antes/depois: `captures/e3b/retratos_antes_depois.png` (fora do Git).


## RB-R1 F2: pistas do roteiro intuitivo (bota do capitao, pegadas grandes, pena, anel alto)
- **Agente:** `art3d`, 2026-11-26. **Status:** `provisorio` no manifesto (entradas `clues_v3_*`); nas cenas `provisional = false`.
- **Originalidade:** geometria e decalques 100% por script/formula do projeto; nenhum modelo, malha, textura ou imagem de
  terceiros; sem modelo de imagem. Detalhes, arquivos e como reproduzir: `source_art/clues_v3/PROVENANCE.md`.
