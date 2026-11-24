# Licencas do audio de Rota Brava (RB-R1)

Conteudo de terceiros no jogo: **somente CC0 1.0** (texto integral em `CC0-1.0.txt`). Lista por arquivo:
`source_audio/PROVENANCE.md`. Hashes dos downloads: `tools/audio_assets.json`.

## Fontes CC0 e onde a licenca esta declarada (verificado em 2026-11-23)
- **Kenney** (Impact Sounds, RPG Audio, Interface Sounds): `License.txt` dentro de cada pacote (copias aqui: `kenney_*_License.txt`) e pagina <https://kenney.nl/assets/...> ("CC0 licensed").
- **FreePats** (xilofone, kalimba, ukulele, violao classico, harpa, World Percussion, Synth Brass 2): `readme.txt`/`LICENSE.txt` de cada SoundFont (copias `fp_*`), paginas em <https://freepats.zenvoid.org/>. Amostras do VCSL (Versilian Studios) tambem CC0. A foto `picture.jpg` do World Percussion e CC-BY 4.0 e **nao** foi usada nem copiada.
- **OpenGameArt.org** — campo "License(s): CC0" de cada pagina:
  - <https://opengameart.org/content/water-waves> (qubodup; origem Freesound 11505 transitking, CC0)
  - <https://opengameart.org/content/beach-ocean-waves> (qubodup; origem Freesound 18363 jasinski, CC0)
  - <https://opengameart.org/content/solo-seagull-sound-effects> (rango-mango)
  - <https://opengameart.org/content/wind1> (lukerustltd)
  - <https://opengameart.org/content/crowd-shoutingspeaking-ambience> (starninjas)
  - <https://opengameart.org/content/ambient-bird-sounds> (isaiah658)
  - <https://opengameart.org/content/fantozzis-footsteps-grasssand-stone> (qubodup; origem Freesound pack 10338 Fantozzi, CC0)
  - <https://opengameart.org/content/bell-dingschimes> (pwl; "Releasing as public domain", marcado CC0)
  - <https://opengameart.org/content/tree-creaking> (antumdeluge; Department64)

## Voz do radio (Farol 7)
- Modelo `pt_BR-jeff-medium` (repositorio rhasspy/piper-voices, licenca do repositorio **MIT**); dataset **CC0** (OHF-Voice/voice-datasets); base de fine-tuning `rdh` (nl_BE) **CC0**. Card: `piper_pt_BR-jeff-medium_MODEL_CARD.md`.
- Alternativas verificadas e NAO usadas: `pt_BR-faber-medium` (dataset CC0, mas fine-tuning a partir de hifi_tts_92 — Hi-Fi TTS e CC-BY 4.0), `pt_BR-edresson-low` (dataset CC BY 4.0).

## Ferramentas de producao (nao distribuidas com o jogo)
- `piper-tts` 1.8.0 (OHF-Voice/piper1-gpl): GPL-3.0-or-later. Usado so offline para gerar WAV.
- FluidSynth 2.6.3: LGPL-2.1-or-later. Usado so offline para renderizar MIDI.
- numpy/scipy/soundfile: BSD-3-Clause; mido: MIT; onnxruntime: MIT.
