#!/usr/bin/env python3
"""Rota Brava D21: candidatas de voz do narrador (crua, sem rotulo), 1 MP3 por voz.

Uso: narrator_samples.py [--out /home/user/rota-brava/captures/d19/amostras/narrador]
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from gemini_tts import directed_style, load_json, synth  # noqa: E402

LINES = ["Hoje é dia de Festa das Lanternas na Vila Farol 7!", "Mas o barco do capitão chegou... sem o capitão!"]
DIRECTION = {"emotion": "encanto de quem conta uma história", "energy": 2, "pace": "normal",
             "note": "abre a história com sorriso na voz; na segunda frase, pausa de suspense leve e divertido antes de 'sem o capitão'"}


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", type=Path, default=Path("/home/user/rota-brava/captures/d19/amostras/narrador"))
    a = ap.parse_args(argv)
    cast = load_json("cast.json")
    n = cast["characters"]["narrador"]
    a.out.mkdir(parents=True, exist_ok=True)
    calls, report = 0, []
    for voice in n["candidates"]:
        wavs = []
        for i, t in enumerate(LINES, 1):
            w = a.out / "bruto" / f"narrador_{voice}_{i}.wav"
            p = synth(t, voice, directed_style("narrador", direction=DIRECTION), cast["model"], w, mode=cast["style_mode"])
            calls += p["api_calls"]
            wavs.append(w)
            report.append({"voz": voice, "texto": t, "wav": str(w), "duracao_s": p["duration_s"],
                           "tentativas": p["tries"], "suspeita_instrucao_lida": p["suspect_instruction_read"]})
        mp3 = a.out / f"narrador_{voice}.mp3"
        subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", str(wavs[0]), "-i", str(wavs[1]),
                        "-filter_complex", "[0:a]apad=pad_dur=0.8[a];[a][1:a]concat=n=2:v=0:a=1[o]", "-map", "[o]",
                        "-ac", "1", "-c:a", "libmp3lame", "-b:a", "128k", str(mp3)], check=True)
    (a.out / "index.json").write_text(json.dumps(report, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print(f"chamadas TTS: {calls}")
    for r in report:
        print(r["voz"], r["duracao_s"], r["tentativas"], r["suspeita_instrucao_lida"])
    return 0


if __name__ == "__main__":
    sys.exit(main())
