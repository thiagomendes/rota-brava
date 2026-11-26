#!/usr/bin/env python3
"""Rota Brava D20a: registra as faixas de tools/music/final_tracks.json no catalogo de sons
(game/audio/sfx_catalog.json) e no source_audio/PROVENANCE.md. Idempotente (substitui music_v3_*/sting_v3_*)."""
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
CAT = ROOT / "game/audio/sfx_catalog.json"
PROV = ROOT / "source_audio/PROVENANCE.md"
MARK = "## Musica gerada pelo Lyria (D20a)"


def main() -> int:
    fin = json.loads((ROOT / "tools/music/final_tracks.json").read_text(encoding="utf-8"))
    cat = json.loads(CAT.read_text(encoding="utf-8"))
    names = {t["name"] for t in fin["tracks"]}
    cat["entries"] = [e for e in cat["entries"] if e["name"] not in names]
    for t in fin["tracks"]:
        e = {"name": t["name"], "file": t["file"], "type": "music", "duration": t["duration"],
             "peak_dbfs": t["true_peak_dbtp"], "true_peak_dbtp": t["true_peak_dbtp"], "lufs": t["lufs"],
             "channels": 2, "sample_rate": 44100, "bus": "Musica", "gain_db": 0.0, "loop": t["loop"],
             "caption_key": None, "status": "provisorio",
             "tool": f"Gemini API {t['source']['model']} + tools/music/finalize.py",
             "source": f"gerado pelo Lyria ({t['source']['model']}, {t['source']['date']}); bruto sha256 {t['source']['raw_sha256']}",
             "license": "audio gerado por IA (Google Lyria); termos de uso a confirmar (docs/proposals/d20_trilhas.md)",
             "sha256": t["sha256"], "scene": t["scene"]}
        if t["loop"]:
            e["seam_jump"] = t["seam_jump"]
        cat["entries"].append(e)
    CAT.write_text(json.dumps(cat, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    txt = PROV.read_text(encoding="utf-8")
    if MARK in txt:
        txt = txt[:txt.index(MARK)].rstrip() + "\n"
    rows = ["", MARK, "",
            "Gerada pela Gemini API (Lyria) com prompts da biblia `tools/music/music_bible.json`; escolha de Thiago (D20a: candidata 1 de cada cena + vinhetas).",
            "Loop, corte e volume por `tools/music/finalize.py`; dados completos (prompt inteiro) em `tools/music/final_tracks.json`.",
            "Termos de uso do audio gerado: NAO verificados (ver `docs/proposals/d20_trilhas.md`).", "",
            "| arquivo | licenca | fonte | ferramenta | sha256 (ogg / bruto) |", "|---|---|---|---|---|"]
    for t in fin["tracks"]:
        s = t["source"]
        rows.append(f"| `{t['file']}` | gerado (Lyria) | cena {t['scene']}, {s['model']}, {s['date']}, prompt em final_tracks.json | "
                    f"Gemini API + `tools/music/finalize.py` | `{t['sha256'][:16]}…` / `{s['raw_sha256'][:16]}…` |")
    PROV.write_text(txt + "\n".join(rows) + "\n", encoding="utf-8")
    print(len(fin["tracks"]))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
