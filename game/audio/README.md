# Audio de Rota Brava (RB-R1)

Regerar: `./tools/setup-audio-tools.ps1` (uma vez; ferramentas em `.tools/`, hashes conferidos) e
`./tools/gen-audio.ps1`; depois `./tools/godot.ps1 --headless --path game --import`. WAV ficam em PCM
(`compress/mode=0`, fixado por `source_audio/r1/fix_imports.py`); musica longa e ambiente em OGG Vorbis (loop ligado
em codigo). Procedencia por arquivo: `source_audio/PROVENANCE.md`. Medidas: `source_audio/report.json`.
Nada foi ouvido por agentes: aceite perceptual com Thiago.

- Falas de personagem: **balbucio** sintetizado (`voice/*.wav`) + visemas (`voice/*.visemes.json`, abertura 0..1 a cada 30 ms).
- Instrucoes e dicas faladas: **Farol 7 no radio** (Piper `pt_BR-jeff-medium`, CC0) com filtro de radio.
- Musica: secoes `explore`, `explore_low`, `crossing`, `return` (loops) e vinhetas `discovery`, `victory`, `team_call`.
- Ambiente por zona: `dock`, `village`, `river`, `island`.

## Integracao (lead, `ep01_main.gd`)
```gdscript
var audio := AudioDirector.new(); add_child(audio)
audio.set_ambience_zone(&"dock")            # village / river / island ao trocar de area (crossfade 2 s)
audio.play_music("explore")                 # explore_low sob dialogo longo; crossing na travessia; return na volta
audio.play_music("team_call")               # vinheta 1,5 s na troca de integrante (toca por cima e devolve a secao)
audio.play_music("discovery")               # pista que resolve; "victory" no fim do episodio
var info := audio.play_line(line_id)        # {duration, type babble|radio, visemes, frame_s, emotes, character, intent}
# duration == 0.0 -> fala ausente: manter a legenda e liberar a sequencia (sem erro)
# boca: a cada quadro, mouth_open = audio.current_viseme()  (ou audio.viseme_at(t) com t desde o inicio da fala)
audio.voice_finished.connect(_on_line_done) # voice_cancelled(id) se outra fala entrar
audio.play_footstep(speed, &"wood", pos)    # wood / stone / sand / grass, 6 variacoes sem repetir
audio.set_engine_rpm(speed / max_speed)     # loop do motor; set_engine_rpm(-1) desliga
audio.play_sfx("sfx_boat_wake")             # loop da esteira (2D) enquanto o barco anda
audio.play_ui(&"confirm")                   # move / confirm / back / open / swap / clue / star
audio.play_sfx("sfx_horn_boat", pos)        # efeitos essenciais tem caption_key -> Loc.t(audio.caption_key(nome))
```
Radio do Farol 7 (G20): fala com speaker `radio` (ou chave `*.radio.*`) toca clique de abrir, voz pelo bus `Radio`
(criado por codigo em `radio_bus.gd`, filho de `Voz`; nao fica no `default_bus_layout.tres`, que a Godot reescreve) com
chiado em laco e clique de fechar. `info.duration` inclui os cliques; `Hud.line_seconds(chave, voice_s)` para cutscenes.
Sons: `tools/audio/radio_fx.py`; amostras: `tools/audio/radio_samples.py` -> `captures/g20/`.
`play_line` abaixa a musica (-6 dB, 0,3 s / volta 0,8 s) e o bus Musica ainda tem sidechain na Voz.
API antiga continua valida (`play_voice`, `start_ambience`, `play_music("theme_explore")`, `duck_music`).

## Mixagem (mix de referencia offline, 60 s, BS.1770)
Arquivos: balbucio -19 LUFS, radio -18, musica -18 (explore) a -23 (explore_low), ambiente -23 a -31.
Buses: Voz +2 dB, Musica -7, Efeitos -3 (motor -8 no catalogo), Ambiente -9; Master: limitador pre-ganho +3,5 dB, teto -1 dB.
Resultado medido: ver `source_audio/report.json` -> `mix_ref_60s`.
