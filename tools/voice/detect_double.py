#!/usr/bin/env python3
"""Rota Brava D19: detector de leitura dupla (e de fala longa demais) num take de TTS. Sem escuta.

Criterios (qualquer um reprova):
- duracao > RATIO_MAX x a esperada (gemini_tts.expected_duration, calibrada pelos takes bons);
- leitura dupla: o take, segmentado por silencio (ffmpeg silencedetect, -38 dB, >= 0,16 s), tem um ponto de corte
  numa pausa >= 0,22 s em que os dois lados tem fala de duracao parecida (razao 0,6-1,6) e cada lado tem
  pelo menos 60% da duracao esperada do texto inteiro.

Uso: detect_double.py --catalog game/audio/voice/v3/voice_v3_catalog.json | detect_double.py arquivo.wav --text "..."
"""
from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
sys.path.insert(0, str(HERE))
from gemini_tts import expected_duration  # noqa: E402

RATIO_MAX = 1.35
## Calibracao: mediana de (duracao / estimativa) nos 11 takes bons do primeiro lote = 0,92 (0,67-1,17).
CAL = 0.92
SIL_DB, SIL_MIN, PAUSE_MIN = -38, 0.16, 0.22


def segments(path: Path) -> tuple[list[tuple[float, float]], float]:
    err = subprocess.run(["ffmpeg", "-hide_banner", "-nostats", "-i", str(path), "-af",
                          f"silencedetect=noise={SIL_DB}dB:d={SIL_MIN}", "-f", "null", "-"],
                         capture_output=True, text=True).stderr
    m = re.search(r"Duration: (\d+):(\d+):([\d.]+)", err)
    total = int(m.group(1)) * 3600 + int(m.group(2)) * 60 + float(m.group(3))
    starts = [float(x) for x in re.findall(r"silence_start: ([\d.]+)", err)]
    ends = [float(x) for x in re.findall(r"silence_end: ([\d.]+)", err)]
    sil = list(zip(starts, ends + [total] * (len(starts) - len(ends))))
    speech, cur = [], 0.0
    for a, b in sil:
        if a > cur:
            speech.append((cur, a))
        cur = b
    if cur < total:
        speech.append((cur, total))
    return [s for s in speech if s[1] - s[0] > 0.05], total


def analyze(path: Path, text: str) -> dict:
    sp, total = segments(path)
    exp = CAL * expected_duration(text)
    voiced = sum(b - a for a, b in sp)
    double = None
    for i in range(1, len(sp)):
        pause = sp[i][0] - sp[i - 1][1]
        if pause < PAUSE_MIN:
            continue
        left = sum(b - a for a, b in sp[:i])
        right = sum(b - a for a, b in sp[i:])
        speech_exp = max(0.5, exp - 0.6)  # parte falada da estimativa (sem a margem)
        if 0.6 <= left / max(right, 1e-6) <= 1.6 and min(left, right) >= max(0.5, 0.6 * speech_exp):
            double = {"corte_s": round(sp[i - 1][1], 2), "pausa_s": round(pause, 2), "esq_s": round(left, 2), "dir_s": round(right, 2)}
            break
    ratio = total / exp
    return {"file": str(path), "duracao_s": round(total, 2), "esperada_s": round(exp, 2), "razao": round(ratio, 2),
            "fala_s": round(voiced, 2), "segmentos": len(sp), "leitura_dupla": double,
            "longa": ratio > RATIO_MAX, "reprova": bool(double) or ratio > RATIO_MAX}


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--catalog", type=Path)
    ap.add_argument("file", nargs="?", type=Path)
    ap.add_argument("--text", default="")
    a = ap.parse_args(argv)
    if a.catalog:
        cat = json.loads(a.catalog.read_text(encoding="utf-8"))
        res = []
        for e in cat["lines"]:
            f = ROOT / "game" / e["file"].removeprefix("res://")
            r = analyze(f, e.get("spoken_at_generation", e["text_at_generation"]))
            r["id"] = e["id"]
            res.append(r)
            print(f"{'REPROVA' if r['reprova'] else 'ok     '} {e['id']:42s} {r['duracao_s']:5.2f} s / {r['esperada_s']:4.2f} "
                  f"x{r['razao']:.2f} seg {r['segmentos']} {'DUPLA ' + str(r['leitura_dupla']) if r['leitura_dupla'] else ''}")
        print(json.dumps({"takes": len(res), "reprovados": [r["id"] for r in res if r["reprova"]]}, ensure_ascii=False))
    else:
        print(json.dumps(analyze(a.file, a.text), ensure_ascii=False, indent=1))
    return 0


if __name__ == "__main__":
    sys.exit(main())
