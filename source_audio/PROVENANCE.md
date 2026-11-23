# Proveniência e permissões do áudio (RB-03, provisório)

| Item | Ferramenta | Origem | Status | Permissão de uso |
|---|---|---|---|---|
| Falas (takes em `source_audio/takes/`, WAV em `game/audio/voice/`) | `System.Speech` (SAPI) via `source_audio/synth_voices.ps1`; vozes `Microsoft Daniel` (Rastro), `Microsoft Maria Desktop` (Pico), `Microsoft Maria` (Leme) | Síntese do sistema Windows desta máquina (versão exata do SO não registrada pelo script), gerada em 2026-11-23 | **PROVISÓRIO** | **Distribuição NÃO confirmada** (licença da Microsoft). Uso só interno/demonstração. Trocar por locução própria na tarefa final. |
| Filtro de rádio, cortes, normalização | `source_audio/voice_post.py` (Python 3.12, biblioteca padrão) | Código do projeto | Referência | Do projeto |
| Música (`game/audio/music/*.wav`) | `source_audio/music/theme_sketch.py` | Composta e sintetizada por script do projeto; nenhuma amostra ou melodia de terceiros | Esboço | Do projeto |

Direção provisória: **Rastro** fala baixo e claro (Daniel, −3 st, −10%); **Pico** confirma em frases curtas (Maria Desktop, +3 st, +8%; descoberta +5 st); **Leme** conversa em movimento (Maria, −1 st, +14%; urgência +1 st, +24%). A fala do rádio é de Rastro/equipe (`team`).

Timbre, pronúncia e corte de sílaba **não foram ouvidos**: aceite perceptual pendente (Thiago).

Medidas: `source_audio/report.json`. dBFS de amostra não é dBTP; o "pico verdadeiro" é estimado por sobreamostragem 4x (sinc/Hann), não por medidor BS.1770.
