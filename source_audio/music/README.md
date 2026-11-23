# Tema instrumental (esboço original)

Gerado por `theme_sketch.py` (via `./tools/gen-audio.ps1`). 100 bpm, 4/4, 8 compassos (19,2 s), estéreo 44,1 kHz 16 bits, pico −6 dBFS (voz em −3 dBFS). Marimba aditiva (fundamental + parcial 4x) em C5–D6, baixo grave, pad discreto e percussão leve. Melodia acima de ~500 Hz e baixo/pad abaixo, deixando a faixa da voz relativamente livre; o ducking fica no bus Musica (`game/audio/default_bus_layout.tres`). Não verificado de ouvido.

Loop: renderização circular (caudas dobram sobre o início; passa-baixa circular). Salto na emenda: `report.json` (`loop_seam_step`) e `test_audio_catalog.gd`.

## theme_explore (Dó maior, luminoso)
| Compasso | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 |
|---|---|---|---|---|---|---|---|---|
| Acorde | C | G | Am | F | C | G | F | G |

## theme_discovery (esparso, misterioso, resolve)
| Compasso | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 |
|---|---|---|---|---|---|---|---|---|
| Acorde | Am | F | C | G | Am | F | G | C |

Notas longas com eco estéreo suave, percussão rara; resolve em C no compasso 8.
