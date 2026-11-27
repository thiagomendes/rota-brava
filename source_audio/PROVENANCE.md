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
| `res://audio/radio/sfx_radio_open.ogg` | original | original: "kssh" de abrir o radio: ruido em banda 900-4200 Hz + clique de tecla; gerado pelo projeto (semente 7007), sha256 `98c8dd3753eb83d6468845b419066cd0e7959ae4c61c7d574d3961a1ee7544fb` | `tools/audio/radio_fx.py` |
| `res://audio/radio/sfx_radio_close.ogg` | original | original: clique de fechar o radio + cauda curta de chiado (700-3800 Hz); gerado pelo projeto (semente 7007), sha256 `da172b4bf7fd03463babb5a437c6961b317768f2600e7db0133e7a50f8cd8570` | `tools/audio/radio_fx.py` |
| `res://audio/radio/amb_radio_hiss.ogg` | original | original: chiado de fundo do radio em laco (ruido 300-3400 Hz, -42 dBFS RMS, estalos raros); gerado pelo projeto (semente 7007), sha256 `b78fc7a358e48a3126d5b8342077b60c91abeb560f7668c028e2ebc2cf7e38f2` | `tools/audio/radio_fx.py` |

Total: 145 arquivos de audio. Data de download/geracao: 2026-11-23.

## Musica gerada pelo Lyria (D20a)

Gerada pela Gemini API (Lyria) com prompts da biblia `tools/music/music_bible.json`; escolha de Thiago (D20a: candidata 1 de cada cena + vinhetas).
Loop, corte e volume por `tools/music/finalize.py`; dados completos (prompt inteiro) em `tools/music/final_tracks.json`.
Termos de uso do audio gerado: NAO verificados (ver `docs/proposals/d20_trilhas.md`).

| arquivo | licenca | fonte | ferramenta | sha256 (ogg / bruto) |
|---|---|---|---|---|
| `res://audio/music/music_v3_village.ogg` | gerado (Lyria) | cena village, lyria-3-pro-preview, 2026-11-25T23:50:26+00:00, prompt em final_tracks.json | Gemini API + `tools/music/finalize.py` | `5156a6b77bd9c7a3…` / `bb2187748894935e…` |
| `res://audio/music/music_v3_mystery.ogg` | gerado (Lyria) | cena mystery, lyria-3-pro-preview, 2026-11-25T23:51:43+00:00, prompt em final_tracks.json | Gemini API + `tools/music/finalize.py` | `2f5bb282d79ce925…` / `0f4416255704dd50…` |
| `res://audio/music/music_v3_boat.ogg` | gerado (Lyria) | cena boat, lyria-3-pro-preview, 2026-11-25T23:53:21+00:00, prompt em final_tracks.json | Gemini API + `tools/music/finalize.py` | `98398af1220eb687…` / `8fa965cd1f43d256…` |
| `res://audio/music/music_v3_lighthouse.ogg` | gerado (Lyria) | cena lighthouse, lyria-3-pro-preview, 2026-11-25T23:54:52+00:00, prompt em final_tracks.json | Gemini API + `tools/music/finalize.py` | `651ab1aee4f661fe…` / `d0ca21692af49430…` |
| `res://audio/music/music_v3_festival.ogg` | gerado (Lyria) | cena festival, lyria-3-pro-preview, 2026-11-25T23:56:14+00:00, prompt em final_tracks.json | Gemini API + `tools/music/finalize.py` | `bea8e9b31ee8b5ef…` / `b30722c9c5536148…` |
| `res://audio/music/sting_v3_mission_win.ogg` | gerado (Lyria) | cena mission_win, lyria-3-clip-preview, 2026-11-25T23:57:21+00:00, prompt em final_tracks.json | Gemini API + `tools/music/finalize.py` | `f21ed1581b5497e5…` / `3747d6acf7318dea…` |
| `res://audio/music/sting_v3_badge.ogg` | gerado (Lyria) | cena badge, lyria-3-clip-preview, 2026-11-25T23:57:39+00:00, prompt em final_tracks.json | Gemini API + `tools/music/finalize.py` | `2e8640244469b40a…` / `61ba4db1fc4cdf57…` |
| `res://audio/music/sting_v3_hero_switch.ogg` | gerado (Lyria) | cena hero_switch, lyria-3-clip-preview, 2026-11-25T23:58:08+00:00, prompt em final_tracks.json | Gemini API + `tools/music/finalize.py` | `dab81161eda90c44…` / `8aec96682a658760…` |

## Sons de radio do Farol 7 (G20)
Gerados pelo projeto, sem amostras de terceiros: `tools/audio/radio_fx.py` (numpy/scipy/soundfile em `.tools/audio-venv`),
semente fixa 7007, OGG Vorbis 44,1 kHz mono. Parametros, medidas e sha256 por arquivo em `source_audio/radio/g20_generated.json`.
Data de geracao: 2026-11-27. Nada foi ouvido por agentes; aceite perceptual com Thiago.

## Vozes Gemini TTS do Ep01 v3 (D19/D21)

Gemini API (TTS, vozes pre-prontas) com o elenco aprovado por Thiago (`tools/voice/cast.json`) e direcao por fala (`tools/voice/direction.json`); tratamento `raw` (silencio aparado + loudnorm) em `tools/voice/treat.py`. Procedencia completa por take (modelo, voz, data, sha256 do bruto e do OGG, hash do estilo) no proprio catalogo. Termos de uso: NAO verificados (`docs/proposals/d19_vozes.md`).

| arquivo | licenca | fonte | ferramenta | sha256 |
|---|---|---|---|---|
| `res://audio/voice/v3/ep01_narrator_intro_team.ogg` | gerado (Gemini TTS) | gemini-3.8-flash-tts, voz Sadaltager, 2026-11-26T13:32:56+00:00 | `tools/voice/gen_v3.py` | `a14d5c111002c992…` |
| `res://audio/voice/v3/ep01_narrator_intro_tracker.ogg` | gerado (Gemini TTS) | gemini-3.8-flash-tts, voz Sadaltager, 2026-11-27T08:24:51+00:00 | `tools/voice/gen_v3.py` | `829b2866b7bbd088…` |
| `res://audio/voice/v3/ep01_intro_tracker_hello.ogg` | gerado (Gemini TTS) | gemini-3.8-flash-tts, voz Leda, 2026-11-26T13:32:56+00:00 | `tools/voice/gen_v3.py` | `36bddfd58fb48ee4…` |
| `res://audio/voice/v3/ep01_narrator_intro_climber.ogg` | gerado (Gemini TTS) | gemini-3.8-flash-tts, voz Sadaltager, 2026-11-27T08:24:57+00:00 | `tools/voice/gen_v3.py` | `ab10e3ac5cc1642f…` |
| `res://audio/voice/v3/ep01_intro_climber_hello.ogg` | gerado (Gemini TTS) | gemini-3.8-flash-tts, voz Fenrir, 2026-11-26T13:32:56+00:00 | `tools/voice/gen_v3.py` | `78ec56d32db378f9…` |
| `res://audio/voice/v3/ep01_narrator_intro_pilot.ogg` | gerado (Gemini TTS) | gemini-3.8-flash-tts, voz Sadaltager, 2026-11-27T08:25:04+00:00 | `tools/voice/gen_v3.py` | `9dae6e7518d385a0…` |
| `res://audio/voice/v3/ep01_intro_pilot_hello.ogg` | gerado (Gemini TTS) | gemini-3.8-flash-tts, voz Erinome, 2026-11-26T13:32:57+00:00 | `tools/voice/gen_v3.py` | `93db6b7ed6ab4558…` |
| `res://audio/voice/v3/ep01_narrator_intro_call.ogg` | gerado (Gemini TTS) | gemini-3.8-flash-tts, voz Sadaltager, 2026-11-26T13:32:59+00:00 | `tools/voice/gen_v3.py` | `72ed5ca1e64973b8…` |
| `res://audio/voice/v3/ep01_narrator_opening_team.ogg` | gerado (Gemini TTS) | gemini-3.8-flash-tts, voz Sadaltager, 2026-11-26T13:33:00+00:00 | `tools/voice/gen_v3.py` | `e30a4b266a2676a5…` |
| `res://audio/voice/v3/ep01_narrator_opening_empty_boat.ogg` | gerado (Gemini TTS) | gemini-3.8-flash-tts, voz Sadaltager, 2026-11-26T13:33:00+00:00 | `tools/voice/gen_v3.py` | `040f42b1def5de81…` |
| `res://audio/voice/v3/ep01_arrival_pilot_no_captain.ogg` | gerado (Gemini TTS) | gemini-3.8-flash-tts, voz Erinome, 2026-11-26T13:33:00+00:00 | `tools/voice/gen_v3.py` | `01adb64e660b07a6…` |
| `res://audio/voice/v3/ep01_arrival_tracker_clue_dock.ogg` | gerado (Gemini TTS) | gemini-3.8-flash-tts, voz Leda, 2026-11-27T08:25:50+00:00 | `tools/voice/gen_v3.py` | `e0a5c170d7f46c1f…` |
| `res://audio/voice/v3/ep01_dock_tracker_small_print.ogg` | gerado (Gemini TTS) | gemini-3.8-flash-tts, voz Leda, 2026-11-26T13:33:00+00:00 | `tools/voice/gen_v3.py` | `f2417b51104321a9…` |
| `res://audio/voice/v3/ep01_dock_tracker_two_trails.ogg` | gerado (Gemini TTS) | gemini-3.8-flash-tts, voz Leda, 2026-11-26T13:33:00+00:00 | `tools/voice/gen_v3.py` | `ab460d0f8e83af21…` |
| `res://audio/voice/v3/ep01_bank_tracker_pup_village.ogg` | gerado (Gemini TTS) | gemini-3.8-flash-tts, voz Leda, 2026-11-26T13:33:00+00:00 | `tools/voice/gen_v3.py` | `c1981b0a960435fc…` |
| `res://audio/voice/v3/ep01_radio_v3_m1_bench.ogg` | gerado (Gemini TTS) | gemini-3.8-flash-tts, voz Schedar, 2026-11-26T13:33:00+00:00 | `tools/voice/gen_v3.py` | `22667405eb0e6d36…` |
| `res://audio/voice/v3/ep01_radio_v3_m1_boot.ogg` | gerado (Gemini TTS) | gemini-3.8-flash-tts, voz Schedar, 2026-11-26T13:33:00+00:00 | `tools/voice/gen_v3.py` | `a76ca44303a5550f…` |
| `res://audio/voice/v3/ep01_radio_v3_m1_trail.ogg` | gerado (Gemini TTS) | gemini-3.8-flash-tts, voz Schedar, 2026-11-26T13:33:00+00:00 | `tools/voice/gen_v3.py` | `832ca83e0acbffb9…` |
| `res://audio/voice/v3/ep01_dock_tracker_look_paw.ogg` | gerado (Gemini TTS) | gemini-3.8-flash-tts, voz Leda, 2026-11-26T13:33:00+00:00 | `tools/voice/gen_v3.py` | `5c92d96f67ef867b…` |
| `res://audio/voice/v3/ep01_dock_tracker_boot_steps.ogg` | gerado (Gemini TTS) | gemini-3.8-flash-tts, voz Leda, 2026-11-26T13:33:01+00:00 | `tools/voice/gen_v3.py` | `607f3818880c8a4a…` |
| `res://audio/voice/v3/ep01_dock_tracker_follow_paws.ogg` | gerado (Gemini TTS) | gemini-3.8-flash-tts, voz Leda, 2026-11-26T13:33:01+00:00 | `tools/voice/gen_v3.py` | `dc6d18c05185263c…` |
| `res://audio/voice/v3/ep01_bank_tracker_pup_to_line.ogg` | gerado (Gemini TTS) | gemini-3.8-flash-tts, voz Leda, 2026-11-26T13:33:01+00:00 | `tools/voice/gen_v3.py` | `2d8bae731e8d9cd5…` |
| `res://audio/voice/v3/ep01_dock_pilot_captain_rowed.ogg` | gerado (Gemini TTS) | gemini-3.8-flash-tts, voz Erinome, 2026-11-27T08:26:14+00:00 | `tools/voice/gen_v3.py` | `a679b6e5054647b8…` |
| `res://audio/voice/v3/ep01_bank_pilot_pup_clothes.ogg` | gerado (Gemini TTS) | gemini-3.8-flash-tts, voz Erinome, 2026-11-26T13:33:01+00:00 | `tools/voice/gen_v3.py` | `5ad2d71619ca2a3a…` |
| `res://audio/voice/v3/ep01_bank_tracker_call_climber.ogg` | gerado (Gemini TTS) | gemini-3.8-flash-tts, voz Leda, 2026-11-27T08:26:27+00:00 | `tools/voice/gen_v3.py` | `a0a8f115822b54cb…` |
| `res://audio/voice/v3/ep01_bank_climber_sock_high.ogg` | gerado (Gemini TTS) | gemini-3.8-flash-tts, voz Fenrir, 2026-11-26T13:33:01+00:00 | `tools/voice/gen_v3.py` | `46eafc948541a29d…` |
| `res://audio/voice/v3/ep01_bank_climber_call_tracker.ogg` | gerado (Gemini TTS) | gemini-3.8-flash-tts, voz Fenrir, 2026-11-26T13:33:01+00:00 | `tools/voice/gen_v3.py` | `878786740b553213…` |
| `res://audio/voice/v3/ep01_bank_pilot_m2_done.ogg` | gerado (Gemini TTS) | gemini-3.8-flash-tts, voz Erinome, 2026-11-26T13:33:02+00:00 | `tools/voice/gen_v3.py` | `23e35f49f6fff99d…` |
| `res://audio/voice/v3/ep01_radio_v3_m2_free_pieces.ogg` | gerado (Gemini TTS) | gemini-3.8-flash-tts, voz Schedar, 2026-11-26T13:33:02+00:00 | `tools/voice/gen_v3.py` | `b91a1a0f7ea5ea03…` |
| `res://audio/voice/v3/ep01_radio_v3_m2_find_third.ogg` | gerado (Gemini TTS) | gemini-3.8-flash-tts, voz Schedar, 2026-11-26T13:33:02+00:00 | `tools/voice/gen_v3.py` | `4306535ba41837d7…` |
| `res://audio/voice/v3/ep01_radio_v3_m2_hang.ogg` | gerado (Gemini TTS) | gemini-3.8-flash-tts, voz Schedar, 2026-11-26T13:33:02+00:00 | `tools/voice/gen_v3.py` | `7fa9d5b78143cce1…` |
| `res://audio/voice/v3/ep01_bank_climber_cloth_on_shed.ogg` | gerado (Gemini TTS) | gemini-3.8-flash-tts, voz Fenrir, 2026-11-26T13:33:02+00:00 | `tools/voice/gen_v3.py` | `1e58f27bb71f0605…` |
| `res://audio/voice/v3/ep01_bank_tracker_cloth_reeds.ogg` | gerado (Gemini TTS) | gemini-3.8-flash-tts, voz Leda, 2026-11-26T13:33:02+00:00 | `tools/voice/gen_v3.py` | `b913ebe5d1ec81fd…` |
| `res://audio/voice/v3/ep01_bank_pilot_hang_line.ogg` | gerado (Gemini TTS) | gemini-3.8-flash-tts, voz Erinome, 2026-11-26T13:33:02+00:00 | `tools/voice/gen_v3.py` | `100346b6692dd0a9…` |
| `res://audio/voice/v3/ep01_plaza_tracker_no_water.ogg` | gerado (Gemini TTS) | gemini-3.8-flash-tts, voz Leda, 2026-11-26T13:33:02+00:00 | `tools/voice/gen_v3.py` | `74002a7c1d680192…` |
| `res://audio/voice/v3/ep01_plaza_tracker_dry_stream.ogg` | gerado (Gemini TTS) | gemini-3.8-flash-tts, voz Leda, 2026-11-26T13:33:02+00:00 | `tools/voice/gen_v3.py` | `9ca2755517701809…` |
| `res://audio/voice/v3/ep01_plaza_tracker_ball_stuck.ogg` | gerado (Gemini TTS) | gemini-3.8-flash-tts, voz Leda, 2026-11-26T13:33:02+00:00 | `tools/voice/gen_v3.py` | `550770b27ee87815…` |
| `res://audio/voice/v3/ep01_plaza_tracker_call_climber.ogg` | gerado (Gemini TTS) | gemini-3.8-flash-tts, voz Leda, 2026-11-26T13:33:03+00:00 | `tools/voice/gen_v3.py` | `6d5ebeea2786601a…` |
| `res://audio/voice/v3/ep01_plaza_climber_top_basin.ogg` | gerado (Gemini TTS) | gemini-3.8-flash-tts, voz Fenrir, 2026-11-26T13:33:03+00:00 | `tools/voice/gen_v3.py` | `a5100e8ba8d16383…` |
| `res://audio/voice/v3/ep01_plaza_climber_m3_done.ogg` | gerado (Gemini TTS) | gemini-3.8-flash-tts, voz Fenrir, 2026-11-26T13:33:03+00:00 | `tools/voice/gen_v3.py` | `c3bf86dfa28b093d…` |
| `res://audio/voice/v3/ep01_radio_v3_m3_stream.ogg` | gerado (Gemini TTS) | gemini-3.8-flash-tts, voz Schedar, 2026-11-26T13:33:03+00:00 | `tools/voice/gen_v3.py` | `799440c29116e878…` |
| `res://audio/voice/v3/ep01_radio_v3_m3_leaves.ogg` | gerado (Gemini TTS) | gemini-3.8-flash-tts, voz Schedar, 2026-11-26T13:33:03+00:00 | `tools/voice/gen_v3.py` | `e9fe689c6c77523f…` |
| `res://audio/voice/v3/ep01_bank_tracker_paws_to_fountain.ogg` | gerado (Gemini TTS) | gemini-3.8-flash-tts, voz Leda, 2026-11-26T13:33:03+00:00 | `tools/voice/gen_v3.py` | `1d1a793ed54b3ef9…` |
| `res://audio/voice/v3/ep01_plaza_tracker_see_channel.ogg` | gerado (Gemini TTS) | gemini-3.8-flash-tts, voz Leda, 2026-11-26T13:33:03+00:00 | `tools/voice/gen_v3.py` | `179c22536c859bfd…` |
| `res://audio/voice/v3/ep01_plaza_climber_leaves_top.ogg` | gerado (Gemini TTS) | gemini-3.8-flash-tts, voz Fenrir, 2026-11-26T13:33:03+00:00 | `tools/voice/gen_v3.py` | `444dd5e6f95adafc…` |
| `res://audio/voice/v3/ep01_plaza_tracker_ball_rolls.ogg` | gerado (Gemini TTS) | gemini-3.8-flash-tts, voz Leda, 2026-11-27T08:27:10+00:00 | `tools/voice/gen_v3.py` | `6683dd5f94b6068a…` |
| `res://audio/voice/v3/ep01_plaza_vendor_help_call.ogg` | gerado (Gemini TTS) | gemini-3.8-flash-tts, voz Vindemiatrix, 2026-11-27T08:27:17+00:00 | `tools/voice/gen_v3.py` | `431b80a72336d553…` |
| `res://audio/voice/v3/ep01_market_vendor_pup_crates.ogg` | gerado (Gemini TTS) | gemini-3.8-flash-tts, voz Vindemiatrix, 2026-11-26T13:33:07+00:00 | `tools/voice/gen_v3.py` | `a43da94010205ed5…` |
| `res://audio/voice/v3/ep01_market_tracker_read_icon.ogg` | gerado (Gemini TTS) | gemini-3.8-flash-tts, voz Leda, 2026-11-27T08:27:30+00:00 | `tools/voice/gen_v3.py` | `b2b74b6b53ce5a1b…` |
| `res://audio/voice/v3/ep01_market_tracker_call_pilot.ogg` | gerado (Gemini TTS) | gemini-3.8-flash-tts, voz Leda, 2026-11-27T08:27:36+00:00 | `tools/voice/gen_v3.py` | `8eda6caef9839901…` |
| `res://audio/voice/v3/ep01_market_pilot_cart_go.ogg` | gerado (Gemini TTS) | gemini-3.8-flash-tts, voz Erinome, 2026-11-27T08:27:43+00:00 | `tools/voice/gen_v3.py` | `21f4cbd3ae180f12…` |
| `res://audio/voice/v3/ep01_market_vendor_wrong_stall.ogg` | gerado (Gemini TTS) | gemini-3.8-flash-tts, voz Vindemiatrix, 2026-11-27T08:27:56+00:00 | `tools/voice/gen_v3.py` | `0c8b0589fd6283f5…` |
| `res://audio/voice/v3/ep01_radio_v3_m4_read.ogg` | gerado (Gemini TTS) | gemini-3.8-flash-tts, voz Schedar, 2026-11-27T08:28:09+00:00 | `tools/voice/gen_v3.py` | `8abee3a3e31ed26c…` |
| `res://audio/voice/v3/ep01_plaza_tracker_see_market.ogg` | gerado (Gemini TTS) | gemini-3.8-flash-tts, voz Leda, 2026-11-27T08:28:39+00:00 | `tools/voice/gen_v3.py` | `83926f16cd1a131e…` |
| `res://audio/voice/v3/ep01_market_tracker_see_cart.ogg` | gerado (Gemini TTS) | gemini-3.8-flash-tts, voz Leda, 2026-11-27T08:28:45+00:00 | `tools/voice/gen_v3.py` | `cd236bd9585151fe…` |
| `res://audio/voice/v3/ep01_market_pilot_see_stalls.ogg` | gerado (Gemini TTS) | gemini-3.8-flash-tts, voz Erinome, 2026-11-27T08:28:53+00:00 | `tools/voice/gen_v3.py` | `975373f96e7fc8f2…` |
| `res://audio/voice/v3/ep01_market_pilot_we_help.ogg` | gerado (Gemini TTS) | gemini-3.8-flash-tts, voz Erinome, 2026-11-27T08:28:59+00:00 | `tools/voice/gen_v3.py` | `fa951a1fc9511bca…` |
| `res://audio/voice/v3/ep01_market_tracker_gull_where.ogg` | gerado (Gemini TTS) | gemini-3.8-flash-tts, voz Leda, 2026-11-27T08:29:05+00:00 | `tools/voice/gen_v3.py` | `acda747ff60e0c8a…` |
| `res://audio/voice/v3/ep01_market_climber_see_gull.ogg` | gerado (Gemini TTS) | gemini-3.8-flash-tts, voz Fenrir, 2026-11-27T08:29:20+00:00 | `tools/voice/gen_v3.py` | `cd7bddfc6fc59038…` |
| `res://audio/voice/v3/ep01_street_climber_gull_fish.ogg` | gerado (Gemini TTS) | gemini-3.8-flash-tts, voz Fenrir, 2026-11-27T08:29:27+00:00 | `tools/voice/gen_v3.py` | `0c9517ef10c45924…` |
| `res://audio/voice/v3/ep01_street_tracker_feathers.ogg` | gerado (Gemini TTS) | gemini-3.8-flash-tts, voz Leda, 2026-11-27T08:29:41+00:00 | `tools/voice/gen_v3.py` | `ee26aa10510a8526…` |
| `res://audio/voice/v3/ep01_street_tracker_call_pilot.ogg` | gerado (Gemini TTS) | gemini-3.8-flash-tts, voz Leda, 2026-11-27T08:30:02+00:00 | `tools/voice/gen_v3.py` | `5b315cfa116d922d…` |
| `res://audio/voice/v3/ep01_street_pilot_compass_west.ogg` | gerado (Gemini TTS) | gemini-3.8-flash-tts, voz Erinome, 2026-11-27T08:30:09+00:00 | `tools/voice/gen_v3.py` | `5b433b469121645b…` |
| `res://audio/voice/v3/ep01_street_pilot_call_climber.ogg` | gerado (Gemini TTS) | gemini-3.8-flash-tts, voz Erinome, 2026-11-27T08:30:15+00:00 | `tools/voice/gen_v3.py` | `10655a6660cb3a65…` |
| `res://audio/voice/v3/ep01_street_climber_sees_boat.ogg` | gerado (Gemini TTS) | gemini-3.8-flash-tts, voz Fenrir, 2026-11-27T08:30:28+00:00 | `tools/voice/gen_v3.py` | `2914598a6e955267…` |
| `res://audio/voice/v3/ep01_radio_v3_m5_feathers.ogg` | gerado (Gemini TTS) | gemini-3.8-flash-tts, voz Schedar, 2026-11-27T08:30:35+00:00 | `tools/voice/gen_v3.py` | `6f8c6fcef1998377…` |
| `res://audio/voice/v3/ep01_radio_v3_m5_compass.ogg` | gerado (Gemini TTS) | gemini-3.8-flash-tts, voz Schedar, 2026-11-27T08:30:41+00:00 | `tools/voice/gen_v3.py` | `5d63947f7242fb05…` |
| `res://audio/voice/v3/ep01_radio_v3_m5_fish.ogg` | gerado (Gemini TTS) | gemini-3.8-flash-tts, voz Schedar, 2026-11-27T08:30:48+00:00 | `tools/voice/gen_v3.py` | `e4413715f13dc6d9…` |
| `res://audio/voice/v3/ep01_street_tracker_see_feathers.ogg` | gerado (Gemini TTS) | gemini-3.8-flash-tts, voz Leda, 2026-11-27T08:30:55+00:00 | `tools/voice/gen_v3.py` | `49c89ec1716ec13c…` |
| `res://audio/voice/v3/ep01_street_pilot_see_vane.ogg` | gerado (Gemini TTS) | gemini-3.8-flash-tts, voz Erinome, 2026-11-27T08:31:20+00:00 | `tools/voice/gen_v3.py` | `34ef6df46e8dc4e8…` |
| `res://audio/voice/v3/ep01_street_climber_gull_roof.ogg` | gerado (Gemini TTS) | gemini-3.8-flash-tts, voz Fenrir, 2026-11-27T08:31:27+00:00 | `tools/voice/gen_v3.py` | `601822d5612e271d…` |
| `res://audio/voice/v3/ep01_narrator_bridge_m4_m5.ogg` | gerado (Gemini TTS) | gemini-3.8-flash-tts, voz Sadaltager, 2026-11-27T08:31:33+00:00 | `tools/voice/gen_v3.py` | `0fe6e6e7c748900b…` |
| `res://audio/voice/v3/ep01_street_tracker_captain_knows.ogg` | gerado (Gemini TTS) | gemini-3.8-flash-tts, voz Leda, 2026-11-27T08:32:06+00:00 | `tools/voice/gen_v3.py` | `fe919d090201073a…` |
| `res://audio/voice/v3/ep01_bay_tracker_go_boat.ogg` | gerado (Gemini TTS) | gemini-3.8-flash-tts, voz Leda, 2026-11-27T08:32:12+00:00 | `tools/voice/gen_v3.py` | `fff9737a32938931…` |
| `res://audio/voice/v3/ep01_bay_pilot_start.ogg` | gerado (Gemini TTS) | gemini-3.8-flash-tts, voz Erinome, 2026-11-27T08:32:25+00:00 | `tools/voice/gen_v3.py` | `14f9986d258b8f04…` |
| `res://audio/voice/v3/ep01_bay_pilot_slow.ogg` | gerado (Gemini TTS) | gemini-3.8-flash-tts, voz Erinome, 2026-11-27T08:32:32+00:00 | `tools/voice/gen_v3.py` | `462d0a9126d32148…` |
| `res://audio/voice/v3/ep01_bay_pilot_call_climber.ogg` | gerado (Gemini TTS) | gemini-3.8-flash-tts, voz Erinome, 2026-11-27T08:32:45+00:00 | `tools/voice/gen_v3.py` | `99cdb2078d8498a4…` |
| `res://audio/voice/v3/ep01_bay_climber_throw_rope.ogg` | gerado (Gemini TTS) | gemini-3.8-flash-tts, voz Fenrir, 2026-11-27T08:32:51+00:00 | `tools/voice/gen_v3.py` | `c0f7a7c716ca1350…` |
| `res://audio/voice/v3/ep01_bay_captain_thanks_tow.ogg` | gerado (Gemini TTS) | gemini-3.8-flash-tts, voz Algieba, 2026-11-27T08:32:58+00:00 | `tools/voice/gen_v3.py` | `01728b13beac980e…` |
| `res://audio/voice/v3/ep01_bay_captain_pup_lighthouse.ogg` | gerado (Gemini TTS) | gemini-3.8-flash-tts, voz Algieba, 2026-11-27T08:33:11+00:00 | `tools/voice/gen_v3.py` | `27d620cba3ba60ec…` |
| `res://audio/voice/v3/ep01_radio_v3_m6_board.ogg` | gerado (Gemini TTS) | gemini-3.8-flash-tts, voz Schedar, 2026-11-27T08:33:17+00:00 | `tools/voice/gen_v3.py` | `ea381a93009457ce…` |
| `res://audio/voice/v3/ep01_radio_v3_m6_buoys.ogg` | gerado (Gemini TTS) | gemini-3.8-flash-tts, voz Schedar, 2026-11-27T08:33:24+00:00 | `tools/voice/gen_v3.py` | `ff8510721c1c7521…` |
| `res://audio/voice/v3/ep01_radio_v3_m6_approach.ogg` | gerado (Gemini TTS) | gemini-3.8-flash-tts, voz Schedar, 2026-11-27T08:33:30+00:00 | `tools/voice/gen_v3.py` | `41bda94c2d0f9183…` |
| `res://audio/voice/v3/ep01_radio_v3_m6_rope.ogg` | gerado (Gemini TTS) | gemini-3.8-flash-tts, voz Schedar, 2026-11-27T08:33:37+00:00 | `tools/voice/gen_v3.py` | `2166c1b57e3ab4c6…` |
