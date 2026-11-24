# Áudio de Rota Brava (RB-04)

Regerar tudo: `./tools/gen-audio.ps1`; depois `./tools/godot.ps1 --headless --path game --import`. Os `.import` precisam de `compress/mode=0` (PCM): o padrão do Godot para WAV novo é ADPCM e quebra os testes.

## Mixagem (níveis-alvo aproximados, NÃO medidos em LUFS)
Voz ~ -14 LUFS (bus 0 dB; RMS dos arquivos -19 a -22 dBFS) · Música ~ -24 (bus -4 dB; abaixa pelo sidechain da Voz) · Efeitos (bus -2 dB + `gain_db` por som) · Ambiente ~ -30 (bus -8 dB + `gain_db`: água -4, vento -9, rangidos -6, gaivotas -12) · Master: limitador teto -1 dB. Detalhes em `default_bus_layout.tres` e `source_audio/music/README.md`.

## Como ligar no jogo (integrador, `ep01_main.gd`)
```gdscript
var audio := AudioDirector.new()
add_child(audio)
audio.start_ambience()                     # ao entrar no cais
audio.play_music("theme_explore", 2.0)
# chegada: a buzina ANTES do barco entrar no quadro (posicao fora de quadro, ex. 40 m antes do cais)
audio.play_sfx("sfx_horn_boat", boat_start_position)   # legenda visual: Loc.t(audio.caption_key("sfx_horn_boat"))
audio.set_engine_rpm(boat_speed / boat_max_speed)       # a cada quadro; set_engine_rpm(-1.0) ao parar
audio.play_sfx("sfx_hull_bump", dock_contact_position)  # encosto; "sfx_crate_slide" na fala da caixa
var secs := audio.play_voice(line_key)     # 0.0 se ausente: manter a legenda e liberar a sequencia
audio.voice_finished.connect(_on_voice_finished)  # id; voice_cancelled(id) se outra fala entrar
audio.play_footstep(actor_speed, &"wood", actor_position)  # a cada contato do pe (passo da animacao)
audio.play_sfx("sfx_clue_found"); audio.play_music("theme_discovery", 0.2)  # na pegada que resolve; depois play_music("theme_explore_low")
audio.play_sfx("sfx_notebook"); audio.play_sfx("sfx_rope_creak", rope_position)
audio.duck_music(true)   # opcional, alem do sidechain; false ao fim da fala
```
`play_voice(id)` usa `VoiceCatalog` com `Loc.language`; as chaves de fala = chaves de texto (`ep01.arrival.*`, `ep01.dock.*`). Sons essenciais têm `caption_key` (equivalente visual) em `sfx_catalog.json`.