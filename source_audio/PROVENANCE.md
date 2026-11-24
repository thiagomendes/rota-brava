# Proveniência e permissões do áudio (RB-04, provisório)

Ambiente de geração: `[System.Environment]::OSVersion` = **Microsoft Windows NT 10.0.26300.0**; Python 3.12.10 (só biblioteca padrão); vozes SAPI instaladas: Microsoft Daniel, Maria, Maria Desktop (e Zira Desktop, não usada). Data: 2026-11-23. Registro automático em `source_audio/env.json` (por `tools/gen-audio.ps1`). Tudo regenerado por `./tools/gen-audio.ps1`.

| Item | Ferramenta | Origem | Status | Permissão de uso |
|---|---|---|---|---|
| Falas (21; `game/audio/voice/`, takes em `source_audio/takes/`) | `System.Speech` (SAPI) via `synth_voices.ps1`; Daniel = Rastro e rádio (filtro do rádio, falante `team`), Maria Desktop = Pico, Maria = Leme; parâmetros em `source_audio/lines.json` | Síntese do Windows desta máquina | **PROVISÓRIO** | **Distribuição NÃO confirmada** (licença Microsoft). Uso interno/demonstração. Trocar por locução própria na tarefa final. |
| Pós-processo de voz (corte ≤150 ms de silêncio, RMS alvo -19 dBFS limitado a pico -3 dBFS, fade, filtro de rádio) | `source_audio/voice_post.py` | Código do projeto | Referência | Do projeto |
| Ambiente (`game/audio/ambience/`) | `source_audio/ambience.py` (ruído filtrado, eventos por semente 101/202/303/404) | Síntese original | Provisório | Do projeto |
| Efeitos (`game/audio/sfx/`) | `source_audio/sfx.py` (sementes fixas) | Síntese original | Provisório | Do projeto |
| Música (`game/audio/music/`) | `source_audio/music/themes.py` | Composição e síntese originais; nenhuma amostra nem melodia de terceiros | Esboço | Do projeto |
| Catálogos | `source_audio/build_catalogs.py` -> `game/audio/sfx_catalog.json`, `voice_catalog.json` | Código do projeto | - | Do projeto |

Direção das vozes (mesma voz + parâmetros entre falas): **Rastro** baixo e claro (Daniel -3 st, -10%); **Pico** frases curtas (Maria Desktop +3 st, +8%; descoberta +5 st); **Leme** em movimento (Maria -1 st, +14%; urgência +1 st, +24%). Rádio: Daniel + filtro 300-3400 Hz, saturação, ruído e estalos de squelch.

Timbre, pronúncia, musicalidade, mistura e ausência de emendas **não foram ouvidos**: aceite perceptual pendente (Thiago). Medidas: `source_audio/report.json` (duração, pico, pico verdadeiro ESTIMADO por sobreamostragem 4x, RMS, salto na emenda). dBFS de amostra não é dBTP; LUFS não foi medido.