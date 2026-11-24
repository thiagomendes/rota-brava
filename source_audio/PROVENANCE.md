# Procedencia e licencas do audio (RB-R1)

Gerado por `source_audio/r1/build_catalogs.py` em 2026-11-23. Regra (RB-R1 D3): terceiros **so CC0/dominio publico**;
composicao, edicao, sintese e mixagem originais do projeto. Downloads conferidos por SHA-256 em
`tools/audio_assets.json` (amostras/SoundFonts) e `tools/toolchain.json` chave `audio` (ferramentas e voz).
Textos de licenca em `source_audio/LICENSES/`.

## Ferramentas (producao; nada disto vai no jogo)

- Piper `piper-tts 1.8.0` (OHF-Voice/piper1-gpl) — **GPL-3.0-or-later**; motor local/offline; o audio gerado nao e obra derivada do codigo.
- Voz `pt_BR-jeff-medium` — Repositorio rhasspy/piper-voices: MIT; dataset (OHF-Voice/voice-datasets): CC0; base de fine-tuning rdh (nl_BE): CC0 — https://huggingface.co/rhasspy/piper-voices/blob/main/pt/pt_BR/jeff/medium/MODEL_CARD
- FluidSynth 2.6.3 — **LGPL-2.1-or-later** — https://github.com/FluidSynth/fluidsynth/releases/download/v2.6.3/fluidsynth-v2.6.3-win10-x64-cpp11.zip
- Python: numpy, scipy, soundfile (BSD-3-Clause), mido (MIT), onnxruntime (MIT).

## Fontes de terceiros usadas (todas CC0-1.0)

| id | autor | pagina | licenca | sha256 |
|---|---|---|---|---|
| `fp_xylophone` | FreePats (samples VCSL, Versilian Studios) | <https://freepats.zenvoid.org/ChromaticPercussion/xylophone.html> | CC0-1.0 | `b142f2a25f0610f1…` |
| `fp_kalimba` | FreePats | <https://freepats.zenvoid.org/Ethnic/kalimba.html> | CC0-1.0 | `c391c9c9ed4e91f3…` |
| `fp_ukulele` | FreePats | <https://freepats.zenvoid.org/GuitarFamily/ukulele.html> | CC0-1.0 | `38eeee4b5a040c9c…` |
| `fp_guitar` | FreePats | <https://freepats.zenvoid.org/Guitar/acoustic-guitar.html> | CC0-1.0 | `8c192f1fc640a553…` |
| `fp_harp` | FreePats (samples VCSL, Versilian Studios) | <https://freepats.zenvoid.org/OrchestralStrings/harp.html> | CC0-1.0 | `04d149bd7446e24c…` |
| `fp_worldperc` | FreePats (samples VCSL) | <https://freepats.zenvoid.org/Percussion/world-and-rare-percussion.html> | CC0-1.0 | `5d72c35572259804…` |
| `fp_brass` | FreePats | <https://freepats.zenvoid.org/Synthesizer/synth-brass.html> | CC0-1.0 | `d094cd3067efd057…` |
| `kenney_impact` | Kenney (kenney.nl) | <https://kenney.nl/assets/impact-sounds> | CC0-1.0 | `029d734af1582474…` |
| `kenney_rpg` | Kenney (kenney.nl) | <https://kenney.nl/assets/rpg-audio> | CC0-1.0 | `6dbeaf8544da958d…` |
| `kenney_interface` | Kenney (kenney.nl) | <https://kenney.nl/assets/interface-sounds> | CC0-1.0 | `f2193d072726d675…` |
| `oga_waves_a1` | transitking (Freesound 11505), editado por qubodup | <https://opengameart.org/content/water-waves> | CC0-1.0 | `0bd84b2061a82c23…` |
| `oga_waves_a2` | transitking (Freesound 11505), editado por qubodup | <https://opengameart.org/content/water-waves> | CC0-1.0 | `afa112a66c4cafe0…` |
| `oga_waves_a3` | transitking (Freesound 11505), editado por qubodup | <https://opengameart.org/content/water-waves> | CC0-1.0 | `1657a0002367e6e9…` |
| `oga_waves_a4` | transitking (Freesound 11505), editado por qubodup | <https://opengameart.org/content/water-waves> | CC0-1.0 | `6c5b59562bf9b00e…` |
| `oga_beach_1` | jasinski (Freesound 18363), editado por qubodup | <https://opengameart.org/content/beach-ocean-waves> | CC0-1.0 | `fcfca178eca2eac5…` |
| `oga_beach_2` | jasinski (Freesound 18363), editado por qubodup | <https://opengameart.org/content/beach-ocean-waves> | CC0-1.0 | `53b5c28c0edc36f0…` |
| `oga_beach_3` | jasinski (Freesound 18363), editado por qubodup | <https://opengameart.org/content/beach-ocean-waves> | CC0-1.0 | `fc795f95f352b354…` |
| `oga_beach_4` | jasinski (Freesound 18363), editado por qubodup | <https://opengameart.org/content/beach-ocean-waves> | CC0-1.0 | `3c490e736365fdd6…` |
| `oga_gull_1` | rango-mango | <https://opengameart.org/content/solo-seagull-sound-effects> | CC0-1.0 | `3e891a8cf944797b…` |
| `oga_gull_2` | rango-mango | <https://opengameart.org/content/solo-seagull-sound-effects> | CC0-1.0 | `477246beafe31569…` |
| `oga_gull_3` | rango-mango | <https://opengameart.org/content/solo-seagull-sound-effects> | CC0-1.0 | `f9e5e283197945d3…` |
| `oga_gull_4` | rango-mango | <https://opengameart.org/content/solo-seagull-sound-effects> | CC0-1.0 | `14b6fcd3f05376a7…` |
| `oga_gull_5` | rango-mango | <https://opengameart.org/content/solo-seagull-sound-effects> | CC0-1.0 | `3c8fed4e1f9c43f8…` |
| `oga_wind_1` | lukerustltd | <https://opengameart.org/content/wind1> | CC0-1.0 | `a2856f794fbf77e0…` |
| `oga_wind_2` | lukerustltd | <https://opengameart.org/content/wind1> | CC0-1.0 | `76a05480733ee021…` |
| `oga_wind_3` | lukerustltd | <https://opengameart.org/content/wind1> | CC0-1.0 | `8def85e8546fb485…` |
| `oga_crowd` | starninjas | <https://opengameart.org/content/crowd-shoutingspeaking-ambience> | CC0-1.0 | `a2c23a64c127c777…` |
| `oga_birds` | isaiah658 | <https://opengameart.org/content/ambient-bird-sounds> | CC0-1.0 | `359e4e3f9da9d75a…` |
| `oga_steps_fantozzi` | Fantozzi (Freesound pack 10338), recortado por qubodup | <https://opengameart.org/content/fantozzis-footsteps-grasssand-stone> | CC0-1.0 | `415d360e0911c1c1…` |
| `oga_bell_1` | pwl | <https://opengameart.org/content/bell-dingschimes> | CC0-1.0 | `8ce40f49cd211125…` |
| `oga_bell_3` | pwl | <https://opengameart.org/content/bell-dingschimes> | CC0-1.0 | `99b9cdb7b9536c97…` |
| `oga_tree_creak` | Department64, limpo por antumdeluge | <https://opengameart.org/content/tree-creaking> | CC0-1.0 | `9bab7c7f68850136…` |

Nao usado (licenca diferente de CC0): `picture.jpg` do pacote World Percussion (CC-BY 4.0) — nao copiado.

## Por arquivo em `game/audio`

| arquivo | licenca | origem | ferramenta |
|---|---|---|---|
| `res://audio/ambience/amb_beach_waves.ogg` | CC0-1.0 | `wave_01_cc0-18363__jasinski__alkaibeach.flac` — jasinski (Freesound 18363), editado por qubodup — <https://opengameart.org/content/beach-ocean-waves> — **CC0-1.0**<br>`wave_02_cc0-18363__jasinski__alkaibeach.flac` — jasinski (Freesound 18363), editado por qubodup — <https://opengameart.org/content/beach-ocean-waves> — **CC0-1.0**<br>`wave_03_cc0-18363__jasinski__alkaibeach.flac` — jasinski (Freesound 18363), editado por qubodup — <https://opengameart.org/content/beach-ocean-waves> — **CC0-1.0**<br>`wave_04_cc0-18363__jasinski__alkaibeach.flac` — jasinski (Freesound 18363), editado por qubodup — <https://opengameart.org/content/beach-ocean-waves> — **CC0-1.0**<br>original: lavagem do mar (ruido periodico) | `source_audio/foley/build_sfx.py` |
| `res://audio/ambience/amb_birds.ogg` | CC0-1.0 | `birds-isaiah658_0.ogg` — isaiah658 — <https://opengameart.org/content/ambient-bird-sounds> — **CC0-1.0** | `source_audio/foley/build_sfx.py` |
| `res://audio/ambience/amb_dock_creaks.ogg` | CC0-1.0 | `tree_creak.flac` — Department64, limpo por antumdeluge — <https://opengameart.org/content/tree-creaking> — **CC0-1.0**<br>`creak1.ogg` — Kenney (kenney.nl) — <https://kenney.nl/assets/rpg-audio> — **CC0-1.0**<br>`creak2.ogg` — Kenney (kenney.nl) — <https://kenney.nl/assets/rpg-audio> — **CC0-1.0**<br>`creak3.ogg` — Kenney (kenney.nl) — <https://kenney.nl/assets/rpg-audio> — **CC0-1.0** | `source_audio/foley/build_sfx.py` |
| `res://audio/ambience/amb_dock_water.ogg` | CC0-1.0 | `wave_01_cc0-11505__transitking__wavesound.flac` — transitking (Freesound 11505), editado por qubodup — <https://opengameart.org/content/water-waves> — **CC0-1.0**<br>`wave_02_cc0-11505__transitking__wavesound.flac` — transitking (Freesound 11505), editado por qubodup — <https://opengameart.org/content/water-waves> — **CC0-1.0**<br>`wave_03_cc0-11505__transitking__wavesound.flac` — transitking (Freesound 11505), editado por qubodup — <https://opengameart.org/content/water-waves> — **CC0-1.0**<br>`wave_04_cc0-11505__transitking__wavesound.flac` — transitking (Freesound 11505), editado por qubodup — <https://opengameart.org/content/water-waves> — **CC0-1.0**<br>original: lavagem do mar (ruido periodico) | `source_audio/foley/build_sfx.py` |
| `res://audio/ambience/amb_gulls_far.ogg` | CC0-1.0 | `Seagull Ambient 1.wav` — rango-mango — <https://opengameart.org/content/solo-seagull-sound-effects> — **CC0-1.0**<br>`Seagull Ambient 2.wav` — rango-mango — <https://opengameart.org/content/solo-seagull-sound-effects> — **CC0-1.0**<br>`Seagull Ambient 3.wav` — rango-mango — <https://opengameart.org/content/solo-seagull-sound-effects> — **CC0-1.0**<br>`Seagull Ambient 4.wav` — rango-mango — <https://opengameart.org/content/solo-seagull-sound-effects> — **CC0-1.0**<br>`Seagull Ambient 5.wav` — rango-mango — <https://opengameart.org/content/solo-seagull-sound-effects> — **CC0-1.0** | `source_audio/foley/build_sfx.py` |
| `res://audio/ambience/amb_river.ogg` | original | original: corrente (ruido periodico + bolhas sintetizadas) | `source_audio/foley/build_sfx.py` |
| `res://audio/ambience/amb_village_market.ogg` | CC0-1.0 | `crowd_shouting_0.ogg` — starninjas — <https://opengameart.org/content/crowd-shoutingspeaking-ambience> — **CC0-1.0**<br>original: crowd_villager_a_01.wav (babble.py)<br>original: crowd_villager_a_02.wav (babble.py)<br>original: crowd_villager_a_03.wav (babble.py)<br>original: crowd_villager_a_04.wav (babble.py)<br>original: crowd_villager_b_01.wav (babble.py)<br>original: crowd_villager_b_02.wav (babble.py)<br>original: crowd_villager_b_03.wav (babble.py)<br>original: crowd_villager_b_04.wav (babble.py)<br>original: crowd_villager_c_01.wav (babble.py)<br>original: crowd_villager_c_02.wav (babble.py)<br>original: crowd_villager_c_03.wav (babble.py)<br>original: crowd_villager_c_04.wav (babble.py) | `source_audio/foley/build_sfx.py` |
| `res://audio/ambience/amb_wind_light.ogg` | CC0-1.0 | `wind1.wav` — lukerustltd — <https://opengameart.org/content/wind1> — **CC0-1.0**<br>`wind2.wav` — lukerustltd — <https://opengameart.org/content/wind1> — **CC0-1.0** | `source_audio/foley/build_sfx.py` |
| `res://audio/music/theme_crossing.ogg` | CC0-1.0 | composicao original<br>SoundFonts FreePats CC0 | `source_audio/music/compose.py + FluidSynth 2.6.3 + SoundFonts FreePats CC0` |
| `res://audio/music/theme_discovery.wav` | CC0-1.0 | composicao original<br>SoundFonts FreePats CC0 | `source_audio/music/compose.py + FluidSynth 2.6.3 + SoundFonts FreePats CC0` |
| `res://audio/music/theme_explore.ogg` | CC0-1.0 | composicao original<br>SoundFonts FreePats CC0 | `source_audio/music/compose.py + FluidSynth 2.6.3 + SoundFonts FreePats CC0` |
| `res://audio/music/theme_explore_low.ogg` | CC0-1.0 | composicao original<br>SoundFonts FreePats CC0 | `source_audio/music/compose.py + FluidSynth 2.6.3 + SoundFonts FreePats CC0` |
| `res://audio/music/theme_return.ogg` | CC0-1.0 | composicao original<br>SoundFonts FreePats CC0 | `source_audio/music/compose.py + FluidSynth 2.6.3 + SoundFonts FreePats CC0` |
| `res://audio/music/theme_team_call.ogg` | CC0-1.0 | composicao original<br>SoundFonts FreePats CC0 | `source_audio/music/compose.py + FluidSynth 2.6.3 + SoundFonts FreePats CC0` |
| `res://audio/music/theme_victory.ogg` | CC0-1.0 | composicao original<br>SoundFonts FreePats CC0 | `source_audio/music/compose.py + FluidSynth 2.6.3 + SoundFonts FreePats CC0` |
| `res://audio/sfx/sfx_boat_wake.ogg` | CC0-1.0 | `wave_01_cc0-11505__transitking__wavesound.flac` — transitking (Freesound 11505), editado por qubodup — <https://opengameart.org/content/water-waves> — **CC0-1.0**<br>`wave_03_cc0-11505__transitking__wavesound.flac` — transitking (Freesound 11505), editado por qubodup — <https://opengameart.org/content/water-waves> — **CC0-1.0**<br>original: espuma (ruido periodico) | `source_audio/foley/build_sfx.py` |
| `res://audio/sfx/sfx_clue_found.wav` | CC0-1.0 | `bell_ding1.wav` — pwl — <https://opengameart.org/content/bell-dingschimes> — **CC0-1.0**<br>`glass_002.ogg` — Kenney (kenney.nl) — <https://kenney.nl/assets/interface-sounds> — **CC0-1.0**<br>`glass_004.ogg` — Kenney (kenney.nl) — <https://kenney.nl/assets/interface-sounds> — **CC0-1.0** | `source_audio/foley/build_sfx.py` |
| `res://audio/sfx/sfx_crate_slide.wav` | CC0-1.0 | `impactWood_medium_001.ogg` — Kenney (kenney.nl) — <https://kenney.nl/assets/impact-sounds> — **CC0-1.0**<br>original: raspado (ruido filtrado) | `source_audio/foley/build_sfx.py` |
| `res://audio/sfx/sfx_engine_loop.wav` | original | original: motor de popa pequeno (pulsos de ignicao + ruido periodico) | `source_audio/foley/build_sfx.py` |
| `res://audio/sfx/sfx_horn_boat.wav` | original | original: buzina de dois tons (sintese) | `source_audio/foley/build_sfx.py` |
| `res://audio/sfx/sfx_horn_fomfom.wav` | original | original: buzina (sintese) | `source_audio/foley/build_sfx.py` |
| `res://audio/sfx/sfx_hull_bump.wav` | CC0-1.0 | `impactWood_heavy_002.ogg` — Kenney (kenney.nl) — <https://kenney.nl/assets/impact-sounds> — **CC0-1.0**<br>`impactPlank_medium_003.ogg` — Kenney (kenney.nl) — <https://kenney.nl/assets/impact-sounds> — **CC0-1.0**<br>`wave_02_cc0-11505__transitking__wavesound.flac` — transitking (Freesound 11505), editado por qubodup — <https://opengameart.org/content/water-waves> — **CC0-1.0**<br>original: baque grave | `source_audio/foley/build_sfx.py` |
| `res://audio/sfx/sfx_notebook.wav` | CC0-1.0 | `bookFlip2.ogg` — Kenney (kenney.nl) — <https://kenney.nl/assets/rpg-audio> — **CC0-1.0**<br>original: rabisco (ruido) | `source_audio/foley/build_sfx.py` |
| `res://audio/sfx/sfx_rope_creak.wav` | CC0-1.0 | `creak2.ogg` — Kenney (kenney.nl) — <https://kenney.nl/assets/rpg-audio> — **CC0-1.0** | `source_audio/foley/build_sfx.py` |
| `res://audio/sfx/sfx_rope_snap.wav` | CC0-1.0 | `beltHandle1.ogg` — Kenney (kenney.nl) — <https://kenney.nl/assets/rpg-audio> — **CC0-1.0**<br>original: estalo (ruido) | `source_audio/foley/build_sfx.py` |
| `res://audio/sfx/sfx_rope_tug.wav` | CC0-1.0 | `cloth2.ogg` — Kenney (kenney.nl) — <https://kenney.nl/assets/rpg-audio> — **CC0-1.0**<br>`creak1.ogg` — Kenney (kenney.nl) — <https://kenney.nl/assets/rpg-audio> — **CC0-1.0**<br>original: tranco grave | `source_audio/foley/build_sfx.py` |
| `res://audio/sfx/sfx_rope_tug_02.wav` | CC0-1.0 | `cloth4.ogg` — Kenney (kenney.nl) — <https://kenney.nl/assets/rpg-audio> — **CC0-1.0**<br>`creak3.ogg` — Kenney (kenney.nl) — <https://kenney.nl/assets/rpg-audio> — **CC0-1.0**<br>original: tranco grave | `source_audio/foley/build_sfx.py` |
| `res://audio/sfx/sfx_step_grass_01.wav` | CC0-1.0 | `footstep_grass_000.ogg` — Kenney (kenney.nl) — <https://kenney.nl/assets/impact-sounds> — **CC0-1.0** | `source_audio/foley/build_sfx.py` |
| `res://audio/sfx/sfx_step_grass_02.wav` | CC0-1.0 | `footstep_grass_001.ogg` — Kenney (kenney.nl) — <https://kenney.nl/assets/impact-sounds> — **CC0-1.0** | `source_audio/foley/build_sfx.py` |
| `res://audio/sfx/sfx_step_grass_03.wav` | CC0-1.0 | `footstep_grass_002.ogg` — Kenney (kenney.nl) — <https://kenney.nl/assets/impact-sounds> — **CC0-1.0** | `source_audio/foley/build_sfx.py` |
| `res://audio/sfx/sfx_step_grass_04.wav` | CC0-1.0 | `footstep_grass_003.ogg` — Kenney (kenney.nl) — <https://kenney.nl/assets/impact-sounds> — **CC0-1.0** | `source_audio/foley/build_sfx.py` |
| `res://audio/sfx/sfx_step_grass_05.wav` | CC0-1.0 | `footstep_grass_004.ogg` — Kenney (kenney.nl) — <https://kenney.nl/assets/impact-sounds> — **CC0-1.0** | `source_audio/foley/build_sfx.py` |
| `res://audio/sfx/sfx_step_grass_06.wav` | CC0-1.0 | `footstep_carpet_002.ogg` — Kenney (kenney.nl) — <https://kenney.nl/assets/impact-sounds> — **CC0-1.0** | `source_audio/foley/build_sfx.py` |
| `res://audio/sfx/sfx_step_sand_01.wav` | CC0-1.0 | `Fantozzi-SandL1.flac` — Fantozzi (Freesound pack 10338), recortado por qubodup — <https://opengameart.org/content/fantozzis-footsteps-grasssand-stone> — **CC0-1.0**<br>`footstep_snow_000.ogg` — Kenney (kenney.nl) — <https://kenney.nl/assets/impact-sounds> — **CC0-1.0** | `source_audio/foley/build_sfx.py` |
| `res://audio/sfx/sfx_step_sand_02.wav` | CC0-1.0 | `Fantozzi-SandL2.flac` — Fantozzi (Freesound pack 10338), recortado por qubodup — <https://opengameart.org/content/fantozzis-footsteps-grasssand-stone> — **CC0-1.0**<br>`footstep_snow_001.ogg` — Kenney (kenney.nl) — <https://kenney.nl/assets/impact-sounds> — **CC0-1.0** | `source_audio/foley/build_sfx.py` |
| `res://audio/sfx/sfx_step_sand_03.wav` | CC0-1.0 | `Fantozzi-SandL3.flac` — Fantozzi (Freesound pack 10338), recortado por qubodup — <https://opengameart.org/content/fantozzis-footsteps-grasssand-stone> — **CC0-1.0**<br>`footstep_snow_002.ogg` — Kenney (kenney.nl) — <https://kenney.nl/assets/impact-sounds> — **CC0-1.0** | `source_audio/foley/build_sfx.py` |
| `res://audio/sfx/sfx_step_sand_04.wav` | CC0-1.0 | `Fantozzi-SandR1.flac` — Fantozzi (Freesound pack 10338), recortado por qubodup — <https://opengameart.org/content/fantozzis-footsteps-grasssand-stone> — **CC0-1.0**<br>`footstep_snow_003.ogg` — Kenney (kenney.nl) — <https://kenney.nl/assets/impact-sounds> — **CC0-1.0** | `source_audio/foley/build_sfx.py` |
| `res://audio/sfx/sfx_step_sand_05.wav` | CC0-1.0 | `Fantozzi-SandR2.flac` — Fantozzi (Freesound pack 10338), recortado por qubodup — <https://opengameart.org/content/fantozzis-footsteps-grasssand-stone> — **CC0-1.0**<br>`footstep_snow_004.ogg` — Kenney (kenney.nl) — <https://kenney.nl/assets/impact-sounds> — **CC0-1.0** | `source_audio/foley/build_sfx.py` |
| `res://audio/sfx/sfx_step_sand_06.wav` | CC0-1.0 | `Fantozzi-SandR3.flac` — Fantozzi (Freesound pack 10338), recortado por qubodup — <https://opengameart.org/content/fantozzis-footsteps-grasssand-stone> — **CC0-1.0**<br>`footstep_snow_000.ogg` — Kenney (kenney.nl) — <https://kenney.nl/assets/impact-sounds> — **CC0-1.0** | `source_audio/foley/build_sfx.py` |
| `res://audio/sfx/sfx_step_stone_01.wav` | CC0-1.0 | `Fantozzi-StoneL1.flac` — Fantozzi (Freesound pack 10338), recortado por qubodup — <https://opengameart.org/content/fantozzis-footsteps-grasssand-stone> — **CC0-1.0** | `source_audio/foley/build_sfx.py` |
| `res://audio/sfx/sfx_step_stone_02.wav` | CC0-1.0 | `Fantozzi-StoneL2.flac` — Fantozzi (Freesound pack 10338), recortado por qubodup — <https://opengameart.org/content/fantozzis-footsteps-grasssand-stone> — **CC0-1.0** | `source_audio/foley/build_sfx.py` |
| `res://audio/sfx/sfx_step_stone_03.wav` | CC0-1.0 | `Fantozzi-StoneL3.flac` — Fantozzi (Freesound pack 10338), recortado por qubodup — <https://opengameart.org/content/fantozzis-footsteps-grasssand-stone> — **CC0-1.0** | `source_audio/foley/build_sfx.py` |
| `res://audio/sfx/sfx_step_stone_04.wav` | CC0-1.0 | `Fantozzi-StoneR1.flac` — Fantozzi (Freesound pack 10338), recortado por qubodup — <https://opengameart.org/content/fantozzis-footsteps-grasssand-stone> — **CC0-1.0** | `source_audio/foley/build_sfx.py` |
| `res://audio/sfx/sfx_step_stone_05.wav` | CC0-1.0 | `Fantozzi-StoneR2.flac` — Fantozzi (Freesound pack 10338), recortado por qubodup — <https://opengameart.org/content/fantozzis-footsteps-grasssand-stone> — **CC0-1.0** | `source_audio/foley/build_sfx.py` |
| `res://audio/sfx/sfx_step_stone_06.wav` | CC0-1.0 | `Fantozzi-StoneR3.flac` — Fantozzi (Freesound pack 10338), recortado por qubodup — <https://opengameart.org/content/fantozzis-footsteps-grasssand-stone> — **CC0-1.0** | `source_audio/foley/build_sfx.py` |
| `res://audio/sfx/sfx_step_wood_01.wav` | CC0-1.0 | `footstep_wood_000.ogg` — Kenney (kenney.nl) — <https://kenney.nl/assets/impact-sounds> — **CC0-1.0** | `source_audio/foley/build_sfx.py` |
| `res://audio/sfx/sfx_step_wood_02.wav` | CC0-1.0 | `footstep_wood_001.ogg` — Kenney (kenney.nl) — <https://kenney.nl/assets/impact-sounds> — **CC0-1.0** | `source_audio/foley/build_sfx.py` |
| `res://audio/sfx/sfx_step_wood_03.wav` | CC0-1.0 | `footstep_wood_002.ogg` — Kenney (kenney.nl) — <https://kenney.nl/assets/impact-sounds> — **CC0-1.0** | `source_audio/foley/build_sfx.py` |
| `res://audio/sfx/sfx_step_wood_04.wav` | CC0-1.0 | `footstep_wood_003.ogg` — Kenney (kenney.nl) — <https://kenney.nl/assets/impact-sounds> — **CC0-1.0** | `source_audio/foley/build_sfx.py` |
| `res://audio/sfx/sfx_step_wood_05.wav` | CC0-1.0 | `footstep_wood_004.ogg` — Kenney (kenney.nl) — <https://kenney.nl/assets/impact-sounds> — **CC0-1.0** | `source_audio/foley/build_sfx.py` |
| `res://audio/sfx/sfx_step_wood_06.wav` | CC0-1.0 | `impactPlank_medium_001.ogg` — Kenney (kenney.nl) — <https://kenney.nl/assets/impact-sounds> — **CC0-1.0** | `source_audio/foley/build_sfx.py` |
| `res://audio/sfx/sfx_ui_back.wav` | CC0-1.0 | `back_002.ogg` — Kenney (kenney.nl) — <https://kenney.nl/assets/interface-sounds> — **CC0-1.0** | `source_audio/foley/build_sfx.py` |
| `res://audio/sfx/sfx_ui_confirm.wav` | CC0-1.0 | `confirmation_001.ogg` — Kenney (kenney.nl) — <https://kenney.nl/assets/interface-sounds> — **CC0-1.0** | `source_audio/foley/build_sfx.py` |
| `res://audio/sfx/sfx_ui_move.wav` | CC0-1.0 | `select_002.ogg` — Kenney (kenney.nl) — <https://kenney.nl/assets/interface-sounds> — **CC0-1.0** | `source_audio/foley/build_sfx.py` |
| `res://audio/sfx/sfx_ui_open.wav` | CC0-1.0 | `maximize_006.ogg` — Kenney (kenney.nl) — <https://kenney.nl/assets/interface-sounds> — **CC0-1.0** | `source_audio/foley/build_sfx.py` |
| `res://audio/sfx/sfx_ui_star.wav` | CC0-1.0 | `bell_ding3.wav` — pwl — <https://opengameart.org/content/bell-dingschimes> — **CC0-1.0**<br>`glass_002.ogg` — Kenney (kenney.nl) — <https://kenney.nl/assets/interface-sounds> — **CC0-1.0** | `source_audio/foley/build_sfx.py` |
| `res://audio/sfx/sfx_ui_swap.wav` | CC0-1.0 | `pluck_001.ogg` — Kenney (kenney.nl) — <https://kenney.nl/assets/interface-sounds> — **CC0-1.0**<br>original: sopro filtrado | `source_audio/foley/build_sfx.py` |
| `res://audio/voice/crowd_villager_a_01.wav` | original | original | `source_audio/babble/babble.py` |
| `res://audio/voice/crowd_villager_a_02.wav` | original | original | `source_audio/babble/babble.py` |
| `res://audio/voice/crowd_villager_a_03.wav` | original | original | `source_audio/babble/babble.py` |
| `res://audio/voice/crowd_villager_a_04.wav` | original | original | `source_audio/babble/babble.py` |
| `res://audio/voice/crowd_villager_b_01.wav` | original | original | `source_audio/babble/babble.py` |
| `res://audio/voice/crowd_villager_b_02.wav` | original | original | `source_audio/babble/babble.py` |
| `res://audio/voice/crowd_villager_b_03.wav` | original | original | `source_audio/babble/babble.py` |
| `res://audio/voice/crowd_villager_b_04.wav` | original | original | `source_audio/babble/babble.py` |
| `res://audio/voice/crowd_villager_c_01.wav` | original | original | `source_audio/babble/babble.py` |
| `res://audio/voice/crowd_villager_c_02.wav` | original | original | `source_audio/babble/babble.py` |
| `res://audio/voice/crowd_villager_c_03.wav` | original | original | `source_audio/babble/babble.py` |
| `res://audio/voice/crowd_villager_c_04.wav` | original | original | `source_audio/babble/babble.py` |
| `res://audio/voice/ep01_arrival_pilot_ask_captain.wav` | original | Balbucio sintetizado (formantes) — nenhuma amostra de terceiros | `source_audio/babble/babble.py (sintese formante original)` |
| `res://audio/voice/ep01_arrival_pilot_react.wav` | original | Balbucio sintetizado (formantes) — nenhuma amostra de terceiros | `source_audio/babble/babble.py (sintese formante original)` |
| `res://audio/voice/ep01_arrival_radio_crate.wav` | original (TTS) | Piper `pt_BR-jeff-medium`: dataset **CC0**, modelo MIT (https://huggingface.co/rhasspy/piper-voices/blob/main/pt/pt_BR/jeff/medium/MODEL_CARD) | `piper-tts 1.8.0 (local) + source_audio/radio/radio.py` |
| `res://audio/voice/ep01_arrival_radio_hint_gesture.wav` | original (TTS) | Piper `pt_BR-jeff-medium`: dataset **CC0**, modelo MIT (https://huggingface.co/rhasspy/piper-voices/blob/main/pt/pt_BR/jeff/medium/MODEL_CARD) | `piper-tts 1.8.0 (local) + source_audio/radio/radio.py` |
| `res://audio/voice/ep01_arrival_radio_hint_spoken.wav` | original (TTS) | Piper `pt_BR-jeff-medium`: dataset **CC0**, modelo MIT (https://huggingface.co/rhasspy/piper-voices/blob/main/pt/pt_BR/jeff/medium/MODEL_CARD) | `piper-tts 1.8.0 (local) + source_audio/radio/radio.py` |
| `res://audio/voice/ep01_arrival_radio_horn.wav` | original (TTS) | Piper `pt_BR-jeff-medium`: dataset **CC0**, modelo MIT (https://huggingface.co/rhasspy/piper-voices/blob/main/pt/pt_BR/jeff/medium/MODEL_CARD) | `piper-tts 1.8.0 (local) + source_audio/radio/radio.py` |
| `res://audio/voice/ep01_arrival_tracker_take_over.wav` | original | Balbucio sintetizado (formantes) — nenhuma amostra de terceiros | `source_audio/babble/babble.py (sintese formante original)` |
| `res://audio/voice/ep01_complete_body.wav` | original (TTS) | Piper `pt_BR-jeff-medium`: dataset **CC0**, modelo MIT (https://huggingface.co/rhasspy/piper-voices/blob/main/pt/pt_BR/jeff/medium/MODEL_CARD) | `piper-tts 1.8.0 (local) + source_audio/radio/radio.py` |
| `res://audio/voice/ep01_complete_title.wav` | original (TTS) | Piper `pt_BR-jeff-medium`: dataset **CC0**, modelo MIT (https://huggingface.co/rhasspy/piper-voices/blob/main/pt/pt_BR/jeff/medium/MODEL_CARD) | `piper-tts 1.8.0 (local) + source_audio/radio/radio.py` |
| `res://audio/voice/ep01_dock_tracker_ask_destination.wav` | original | Balbucio sintetizado (formantes) — nenhuma amostra de terceiros | `source_audio/babble/babble.py (sintese formante original)` |
| `res://audio/voice/ep01_dock_tracker_boot_not_enough.wav` | original | Balbucio sintetizado (formantes) — nenhuma amostra de terceiros | `source_audio/babble/babble.py (sintese formante original)` |
| `res://audio/voice/ep01_dock_tracker_boot_observation.wav` | original | Balbucio sintetizado (formantes) — nenhuma amostra de terceiros | `source_audio/babble/babble.py (sintese formante original)` |
| `res://audio/voice/ep01_dock_tracker_deduction.wav` | original | Balbucio sintetizado (formantes) — nenhuma amostra de terceiros | `source_audio/babble/babble.py (sintese formante original)` |
| `res://audio/voice/ep01_dock_tracker_hint_gesture_bench.wav` | original | Balbucio sintetizado (formantes) — nenhuma amostra de terceiros | `source_audio/babble/babble.py (sintese formante original)` |
| `res://audio/voice/ep01_dock_tracker_hint_gesture_boot.wav` | original | Balbucio sintetizado (formantes) — nenhuma amostra de terceiros | `source_audio/babble/babble.py (sintese formante original)` |
| `res://audio/voice/ep01_dock_tracker_hint_spoken.wav` | original (TTS) | Piper `pt_BR-jeff-medium`: dataset **CC0**, modelo MIT (https://huggingface.co/rhasspy/piper-voices/blob/main/pt/pt_BR/jeff/medium/MODEL_CARD) | `piper-tts 1.8.0 (local) + source_audio/radio/radio.py` |
| `res://audio/voice/ep01_dock_tracker_paw_not_enough.wav` | original | Balbucio sintetizado (formantes) — nenhuma amostra de terceiros | `source_audio/babble/babble.py (sintese formante original)` |
| `res://audio/voice/ep01_dock_tracker_small_print.wav` | original | Balbucio sintetizado (formantes) — nenhuma amostra de terceiros | `source_audio/babble/babble.py (sintese formante original)` |
| `res://audio/voice/ep01_dock_tracker_wrong_bank_hint.wav` | original | Balbucio sintetizado (formantes) — nenhuma amostra de terceiros | `source_audio/babble/babble.py (sintese formante original)` |
| `res://audio/voice/ep01_dock_tracker_wrong_destination.wav` | original | Balbucio sintetizado (formantes) — nenhuma amostra de terceiros | `source_audio/babble/babble.py (sintese formante original)` |
| `res://audio/voice/ep01_docking_pilot_aligned.wav` | original | Balbucio sintetizado (formantes) — nenhuma amostra de terceiros | `source_audio/babble/babble.py (sintese formante original)` |
| `res://audio/voice/ep01_docking_pilot_assist.wav` | original | Balbucio sintetizado (formantes) — nenhuma amostra de terceiros | `source_audio/babble/babble.py (sintese formante original)` |
| `res://audio/voice/ep01_docking_pilot_hint_gesture.wav` | original | Balbucio sintetizado (formantes) — nenhuma amostra de terceiros | `source_audio/babble/babble.py (sintese formante original)` |
| `res://audio/voice/ep01_docking_pilot_hint_spoken.wav` | original (TTS) | Piper `pt_BR-jeff-medium`: dataset **CC0**, modelo MIT (https://huggingface.co/rhasspy/piper-voices/blob/main/pt/pt_BR/jeff/medium/MODEL_CARD) | `piper-tts 1.8.0 (local) + source_audio/radio/radio.py` |
| `res://audio/voice/ep01_docking_pilot_retry.wav` | original | Balbucio sintetizado (formantes) — nenhuma amostra de terceiros | `source_audio/babble/babble.py (sintese formante original)` |
| `res://audio/voice/ep01_docking_pilot_start.wav` | original | Balbucio sintetizado (formantes) — nenhuma amostra de terceiros | `source_audio/babble/babble.py (sintese formante original)` |
| `res://audio/voice/ep01_island_climber_foothold.wav` | original | Balbucio sintetizado (formantes) — nenhuma amostra de terceiros | `source_audio/babble/babble.py (sintese formante original)` |
| `res://audio/voice/ep01_island_climber_hint_gesture.wav` | original | Balbucio sintetizado (formantes) — nenhuma amostra de terceiros | `source_audio/babble/babble.py (sintese formante original)` |
| `res://audio/voice/ep01_island_climber_hint_spoken.wav` | original (TTS) | Piper `pt_BR-jeff-medium`: dataset **CC0**, modelo MIT (https://huggingface.co/rhasspy/piper-voices/blob/main/pt/pt_BR/jeff/medium/MODEL_CARD) | `piper-tts 1.8.0 (local) + source_audio/radio/radio.py` |
| `res://audio/voice/ep01_island_climber_line_ready.wav` | original | Balbucio sintetizado (formantes) — nenhuma amostra de terceiros | `source_audio/babble/babble.py (sintese formante original)` |
| `res://audio/voice/ep01_island_climber_missed.wav` | original | Balbucio sintetizado (formantes) — nenhuma amostra de terceiros | `source_audio/babble/babble.py (sintese formante original)` |
| `res://audio/voice/ep01_island_climber_start.wav` | original | Balbucio sintetizado (formantes) — nenhuma amostra de terceiros | `source_audio/babble/babble.py (sintese formante original)` |
| `res://audio/voice/ep01_island_climber_tug_1.wav` | original | Balbucio sintetizado (formantes) — nenhuma amostra de terceiros | `source_audio/babble/babble.py (sintese formante original)` |
| `res://audio/voice/ep01_island_climber_tug_2.wav` | original | Balbucio sintetizado (formantes) — nenhuma amostra de terceiros | `source_audio/babble/babble.py (sintese formante original)` |
| `res://audio/voice/ep01_radio_dock_choice.wav` | original (TTS) | Piper `pt_BR-jeff-medium`: dataset **CC0**, modelo MIT (https://huggingface.co/rhasspy/piper-voices/blob/main/pt/pt_BR/jeff/medium/MODEL_CARD) | `piper-tts 1.8.0 (local) + source_audio/radio/radio.py` |
| `res://audio/voice/ep01_radio_dock_conclusion.wav` | original (TTS) | Piper `pt_BR-jeff-medium`: dataset **CC0**, modelo MIT (https://huggingface.co/rhasspy/piper-voices/blob/main/pt/pt_BR/jeff/medium/MODEL_CARD) | `piper-tts 1.8.0 (local) + source_audio/radio/radio.py` |
| `res://audio/voice/ep01_radio_dock_hint_bench.wav` | original (TTS) | Piper `pt_BR-jeff-medium`: dataset **CC0**, modelo MIT (https://huggingface.co/rhasspy/piper-voices/blob/main/pt/pt_BR/jeff/medium/MODEL_CARD) | `piper-tts 1.8.0 (local) + source_audio/radio/radio.py` |
| `res://audio/voice/ep01_radio_dock_hint_boot.wav` | original (TTS) | Piper `pt_BR-jeff-medium`: dataset **CC0**, modelo MIT (https://huggingface.co/rhasspy/piper-voices/blob/main/pt/pt_BR/jeff/medium/MODEL_CARD) | `piper-tts 1.8.0 (local) + source_audio/radio/radio.py` |
| `res://audio/voice/ep01_radio_dock_hint_examine.wav` | original (TTS) | Piper `pt_BR-jeff-medium`: dataset **CC0**, modelo MIT (https://huggingface.co/rhasspy/piper-voices/blob/main/pt/pt_BR/jeff/medium/MODEL_CARD) | `piper-tts 1.8.0 (local) + source_audio/radio/radio.py` |
| `res://audio/voice/ep01_radio_dock_try_again.wav` | original (TTS) | Piper `pt_BR-jeff-medium`: dataset **CC0**, modelo MIT (https://huggingface.co/rhasspy/piper-voices/blob/main/pt/pt_BR/jeff/medium/MODEL_CARD) | `piper-tts 1.8.0 (local) + source_audio/radio/radio.py` |
| `res://audio/voice/ep01_radio_docking_hint_approach.wav` | original (TTS) | Piper `pt_BR-jeff-medium`: dataset **CC0**, modelo MIT (https://huggingface.co/rhasspy/piper-voices/blob/main/pt/pt_BR/jeff/medium/MODEL_CARD) | `piper-tts 1.8.0 (local) + source_audio/radio/radio.py` |
| `res://audio/voice/ep01_radio_docking_hint_line.wav` | original (TTS) | Piper `pt_BR-jeff-medium`: dataset **CC0**, modelo MIT (https://huggingface.co/rhasspy/piper-voices/blob/main/pt/pt_BR/jeff/medium/MODEL_CARD) | `piper-tts 1.8.0 (local) + source_audio/radio/radio.py` |
| `res://audio/voice/ep01_radio_island_hint_line.wav` | original (TTS) | Piper `pt_BR-jeff-medium`: dataset **CC0**, modelo MIT (https://huggingface.co/rhasspy/piper-voices/blob/main/pt/pt_BR/jeff/medium/MODEL_CARD) | `piper-tts 1.8.0 (local) + source_audio/radio/radio.py` |
| `res://audio/voice/ep01_radio_island_hint_stone.wav` | original (TTS) | Piper `pt_BR-jeff-medium`: dataset **CC0**, modelo MIT (https://huggingface.co/rhasspy/piper-voices/blob/main/pt/pt_BR/jeff/medium/MODEL_CARD) | `piper-tts 1.8.0 (local) + source_audio/radio/radio.py` |
| `res://audio/voice/ep01_radio_objective_arrival.wav` | original (TTS) | Piper `pt_BR-jeff-medium`: dataset **CC0**, modelo MIT (https://huggingface.co/rhasspy/piper-voices/blob/main/pt/pt_BR/jeff/medium/MODEL_CARD) | `piper-tts 1.8.0 (local) + source_audio/radio/radio.py` |
| `res://audio/voice/ep01_radio_objective_dock_investigation.wav` | original (TTS) | Piper `pt_BR-jeff-medium`: dataset **CC0**, modelo MIT (https://huggingface.co/rhasspy/piper-voices/blob/main/pt/pt_BR/jeff/medium/MODEL_CARD) | `piper-tts 1.8.0 (local) + source_audio/radio/radio.py` |
| `res://audio/voice/ep01_radio_objective_docking.wav` | original (TTS) | Piper `pt_BR-jeff-medium`: dataset **CC0**, modelo MIT (https://huggingface.co/rhasspy/piper-voices/blob/main/pt/pt_BR/jeff/medium/MODEL_CARD) | `piper-tts 1.8.0 (local) + source_audio/radio/radio.py` |
| `res://audio/voice/ep01_radio_objective_island_crossing.wav` | original (TTS) | Piper `pt_BR-jeff-medium`: dataset **CC0**, modelo MIT (https://huggingface.co/rhasspy/piper-voices/blob/main/pt/pt_BR/jeff/medium/MODEL_CARD) | `piper-tts 1.8.0 (local) + source_audio/radio/radio.py` |
| `res://audio/voice/ep01_radio_objective_return_trip.wav` | original (TTS) | Piper `pt_BR-jeff-medium`: dataset **CC0**, modelo MIT (https://huggingface.co/rhasspy/piper-voices/blob/main/pt/pt_BR/jeff/medium/MODEL_CARD) | `piper-tts 1.8.0 (local) + source_audio/radio/radio.py` |
| `res://audio/voice/ep01_radio_objective_river_search.wav` | original (TTS) | Piper `pt_BR-jeff-medium`: dataset **CC0**, modelo MIT (https://huggingface.co/rhasspy/piper-voices/blob/main/pt/pt_BR/jeff/medium/MODEL_CARD) | `piper-tts 1.8.0 (local) + source_audio/radio/radio.py` |
| `res://audio/voice/ep01_radio_return_hint_button.wav` | original (TTS) | Piper `pt_BR-jeff-medium`: dataset **CC0**, modelo MIT (https://huggingface.co/rhasspy/piper-voices/blob/main/pt/pt_BR/jeff/medium/MODEL_CARD) | `piper-tts 1.8.0 (local) + source_audio/radio/radio.py` |
| `res://audio/voice/ep01_radio_return_hint_press.wav` | original (TTS) | Piper `pt_BR-jeff-medium`: dataset **CC0**, modelo MIT (https://huggingface.co/rhasspy/piper-voices/blob/main/pt/pt_BR/jeff/medium/MODEL_CARD) | `piper-tts 1.8.0 (local) + source_audio/radio/radio.py` |
| `res://audio/voice/ep01_radio_river_cove.wav` | original (TTS) | Piper `pt_BR-jeff-medium`: dataset **CC0**, modelo MIT (https://huggingface.co/rhasspy/piper-voices/blob/main/pt/pt_BR/jeff/medium/MODEL_CARD) | `piper-tts 1.8.0 (local) + source_audio/radio/radio.py` |
| `res://audio/voice/ep01_radio_river_hint_buoy.wav` | original (TTS) | Piper `pt_BR-jeff-medium`: dataset **CC0**, modelo MIT (https://huggingface.co/rhasspy/piper-voices/blob/main/pt/pt_BR/jeff/medium/MODEL_CARD) | `piper-tts 1.8.0 (local) + source_audio/radio/radio.py` |
| `res://audio/voice/ep01_radio_river_hint_cove.wav` | original (TTS) | Piper `pt_BR-jeff-medium`: dataset **CC0**, modelo MIT (https://huggingface.co/rhasspy/piper-voices/blob/main/pt/pt_BR/jeff/medium/MODEL_CARD) | `piper-tts 1.8.0 (local) + source_audio/radio/radio.py` |
| `res://audio/voice/ep01_radio_river_hint_leaves.wav` | original (TTS) | Piper `pt_BR-jeff-medium`: dataset **CC0**, modelo MIT (https://huggingface.co/rhasspy/piper-voices/blob/main/pt/pt_BR/jeff/medium/MODEL_CARD) | `piper-tts 1.8.0 (local) + source_audio/radio/radio.py` |
| `res://audio/voice/ep01_radio_river_leaves.wav` | original (TTS) | Piper `pt_BR-jeff-medium`: dataset **CC0**, modelo MIT (https://huggingface.co/rhasspy/piper-voices/blob/main/pt/pt_BR/jeff/medium/MODEL_CARD) | `piper-tts 1.8.0 (local) + source_audio/radio/radio.py` |
| `res://audio/voice/ep01_radio_river_slow.wav` | original (TTS) | Piper `pt_BR-jeff-medium`: dataset **CC0**, modelo MIT (https://huggingface.co/rhasspy/piper-voices/blob/main/pt/pt_BR/jeff/medium/MODEL_CARD) | `piper-tts 1.8.0 (local) + source_audio/radio/radio.py` |
| `res://audio/voice/ep01_radio_river_start.wav` | original (TTS) | Piper `pt_BR-jeff-medium`: dataset **CC0**, modelo MIT (https://huggingface.co/rhasspy/piper-voices/blob/main/pt/pt_BR/jeff/medium/MODEL_CARD) | `piper-tts 1.8.0 (local) + source_audio/radio/radio.py` |
| `res://audio/voice/ep01_radio_team_found_boat.wav` | original (TTS) | Piper `pt_BR-jeff-medium`: dataset **CC0**, modelo MIT (https://huggingface.co/rhasspy/piper-voices/blob/main/pt/pt_BR/jeff/medium/MODEL_CARD) | `piper-tts 1.8.0 (local) + source_audio/radio/radio.py` |
| `res://audio/voice/ep01_return_captain_thanks.wav` | original | Balbucio sintetizado (formantes) — nenhuma amostra de terceiros | `source_audio/babble/babble.py (sintese formante original)` |
| `res://audio/voice/ep01_return_pilot_depart.wav` | original | Balbucio sintetizado (formantes) — nenhuma amostra de terceiros | `source_audio/babble/babble.py (sintese formante original)` |
| `res://audio/voice/ep01_return_pilot_hint_gesture.wav` | original | Balbucio sintetizado (formantes) — nenhuma amostra de terceiros | `source_audio/babble/babble.py (sintese formante original)` |
| `res://audio/voice/ep01_return_pilot_hint_spoken.wav` | original (TTS) | Piper `pt_BR-jeff-medium`: dataset **CC0**, modelo MIT (https://huggingface.co/rhasspy/piper-voices/blob/main/pt/pt_BR/jeff/medium/MODEL_CARD) | `piper-tts 1.8.0 (local) + source_audio/radio/radio.py` |
| `res://audio/voice/ep01_return_pup_horn.wav` | original | Balbucio sintetizado (formantes) — nenhuma amostra de terceiros | `source_audio/babble/babble.py (sintese formante original)` |
| `res://audio/voice/ep01_return_radio_joke.wav` | original (TTS) | Piper `pt_BR-jeff-medium`: dataset **CC0**, modelo MIT (https://huggingface.co/rhasspy/piper-voices/blob/main/pt/pt_BR/jeff/medium/MODEL_CARD) | `piper-tts 1.8.0 (local) + source_audio/radio/radio.py` |
| `res://audio/voice/ep01_river_captain_wave.wav` | original | Balbucio sintetizado (formantes) — nenhuma amostra de terceiros | `source_audio/babble/babble.py (sintese formante original)` |
| `res://audio/voice/ep01_river_pilot_bank_guide.wav` | original | Balbucio sintetizado (formantes) — nenhuma amostra de terceiros | `source_audio/babble/babble.py (sintese formante original)` |
| `res://audio/voice/ep01_river_pilot_buoy.wav` | original | Balbucio sintetizado (formantes) — nenhuma amostra de terceiros | `source_audio/babble/babble.py (sintese formante original)` |
| `res://audio/voice/ep01_river_pilot_hint_gesture_buoy.wav` | original | Balbucio sintetizado (formantes) — nenhuma amostra de terceiros | `source_audio/babble/babble.py (sintese formante original)` |
| `res://audio/voice/ep01_river_pilot_hint_gesture_leaves.wav` | original | Balbucio sintetizado (formantes) — nenhuma amostra de terceiros | `source_audio/babble/babble.py (sintese formante original)` |
| `res://audio/voice/ep01_river_pilot_hint_spoken.wav` | original (TTS) | Piper `pt_BR-jeff-medium`: dataset **CC0**, modelo MIT (https://huggingface.co/rhasspy/piper-voices/blob/main/pt/pt_BR/jeff/medium/MODEL_CARD) | `piper-tts 1.8.0 (local) + source_audio/radio/radio.py` |
| `res://audio/voice/ep01_river_pilot_leaves.wav` | original | Balbucio sintetizado (formantes) — nenhuma amostra de terceiros | `source_audio/babble/babble.py (sintese formante original)` |
| `res://audio/voice/ep01_river_pilot_slow_down.wav` | original | Balbucio sintetizado (formantes) — nenhuma amostra de terceiros | `source_audio/babble/babble.py (sintese formante original)` |
| `res://audio/voice/ep01_river_pilot_spot_captain.wav` | original | Balbucio sintetizado (formantes) — nenhuma amostra de terceiros | `source_audio/babble/babble.py (sintese formante original)` |
| `res://audio/voice/ep01_river_pilot_start.wav` | original | Balbucio sintetizado (formantes) — nenhuma amostra de terceiros | `source_audio/babble/babble.py (sintese formante original)` |

Total: 145 arquivos de audio. Data de download/geracao: 2026-11-23.
