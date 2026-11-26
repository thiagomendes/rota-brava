#!/usr/bin/env python3
"""Rota Brava D19/D21: registra os takes de game/audio/voice/v3/voice_v3_catalog.json no source_audio/PROVENANCE.md
(uma linha por arquivo; idempotente: substitui a secao)."""
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
PROV = ROOT / "source_audio/PROVENANCE.md"
MARK = "## Vozes Gemini TTS do Ep01 v3 (D19/D21)"


def main() -> int:
    cat = json.loads((ROOT / "game/audio/voice/v3/voice_v3_catalog.json").read_text(encoding="utf-8"))
    txt = PROV.read_text(encoding="utf-8")
    if MARK in txt:
        a = txt.index(MARK)
        b = txt.find("\n## ", a + len(MARK))
        txt = txt[:a].rstrip() + "\n" + (txt[b:] if b >= 0 else "")
    rows = ["", MARK, "",
            "Gemini API (TTS, vozes pre-prontas) com o elenco aprovado por Thiago (`tools/voice/cast.json`) e direcao por fala "
            "(`tools/voice/direction.json`); tratamento `raw` (silencio aparado + loudnorm) em `tools/voice/treat.py`. "
            "Procedencia completa por take (modelo, voz, data, sha256 do bruto e do OGG, hash do estilo) no proprio catalogo. "
            "Termos de uso: NAO verificados (`docs/proposals/d19_vozes.md`).", "",
            "| arquivo | licenca | fonte | ferramenta | sha256 |", "|---|---|---|---|---|"]
    for e in cat["lines"]:
        rows.append(f"| `{e['file']}` | gerado (Gemini TTS) | {e['model']}, voz {e['voice']}, {e['date']} | "
                    f"`tools/voice/gen_v3.py` | `{e['sha256'][:16]}…` |")
    PROV.write_text(txt.rstrip() + "\n" + "\n".join(rows) + "\n", encoding="utf-8")
    print(len(cat["lines"]))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
