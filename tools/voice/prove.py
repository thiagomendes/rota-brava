#!/usr/bin/env python3
"""Rota Brava D19: prova do tratamento (medidas, sem escuta).

Para cada WAV de entrada e cada preset: trata, gera espectrograma antes/depois
(ffmpeg showspectrumpic) e mede F0 mediana (autocorrelacao, quadros vozeados),
duracao, LUFS e pico verdadeiro. Escreve report.json no diretorio de saida.

Uso: prove.py --out captures/d19 in1.wav [in2.wav ...]
Requer numpy + soundfile (venv em .tools/audio-venv).
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

import numpy as np
import soundfile as sf

sys.path.insert(0, str(Path(__file__).resolve().parent))
from treat import PRESETS, loudness, treat  # noqa: E402


def f0_stats(path: Path, fmin: float = 70.0, fmax: float = 600.0) -> dict:
    x, sr = sf.read(str(path), dtype="float64", always_2d=True)
    x = x.mean(axis=1)
    frame, hop = int(0.04 * sr), int(0.01 * sr)
    rms_all = np.sqrt(np.mean(x ** 2)) + 1e-12
    lo, hi = int(sr / fmax), int(sr / fmin)
    f0s = []
    for s in range(0, len(x) - frame, hop):
        w = x[s:s + frame] * np.hanning(frame)
        if np.sqrt(np.mean(w ** 2)) < 0.3 * rms_all:
            continue
        ac = np.fft.irfft(np.abs(np.fft.rfft(w, 2 * frame)) ** 2)[:frame]
        if ac[0] <= 0:
            continue
        ac = ac / ac[0]
        lag = lo + int(np.argmax(ac[lo:hi]))
        if ac[lag] < 0.45:  # limiar de vozeamento
            continue
        # interpolacao parabolica do pico
        a, b, c = ac[lag - 1], ac[lag], ac[lag + 1]
        d = 0.5 * (a - c) / (a - 2 * b + c) if (a - 2 * b + c) else 0.0
        f0s.append(sr / (lag + d))
    f = np.array(f0s)
    if not len(f):
        return {"f0_median_hz": None, "f0_mean_hz": None, "voiced_frames": 0}
    return {"f0_median_hz": round(float(np.median(f)), 1), "f0_mean_hz": round(float(f.mean()), 1),
            "f0_p10_hz": round(float(np.percentile(f, 10)), 1), "f0_p90_hz": round(float(np.percentile(f, 90)), 1),
            "voiced_frames": int(len(f)), "duration_s": round(len(x) / sr, 3)}


def spectrum(src: Path, png: Path, title: str) -> None:
    subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", str(src), "-lavfi",
                    f"showspectrumpic=s=960x360:legend=1:fscale=lin:stop=8000,drawtext=text='{title}':x=10:y=4:fontcolor=white",
                    str(png)], check=False)
    if not png.exists():  # drawtext pode faltar sem fonte
        subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", str(src), "-lavfi",
                        "showspectrumpic=s=960x360:legend=1:fscale=lin:stop=8000", str(png)], check=True)


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", type=Path, required=True)
    ap.add_argument("--presets", default=",".join(PRESETS))
    ap.add_argument("inputs", nargs="+", type=Path)
    a = ap.parse_args(argv)
    a.out.mkdir(parents=True, exist_ok=True)
    rep = []
    for src in a.inputs:
        stem = src.stem
        spectrum(src, a.out / f"{stem}__antes.png", f"{stem} antes")
        before = {**f0_stats(src), **loudness(src)}
        for pr in a.presets.split(","):
            dst = a.out / f"{stem}__{pr}.wav"
            treat(pr, src, dst)
            spectrum(dst, a.out / f"{stem}__{pr}.png", f"{stem} {pr}")
            after = {**f0_stats(dst), **loudness(dst)}
            ratio = (after["f0_median_hz"] / before["f0_median_hz"]) if after["f0_median_hz"] and before["f0_median_hz"] else None
            rep.append({"input": str(src), "preset": pr, "semitones_pedidos": PRESETS[pr]["semitones"],
                        "before": before, "after": after,
                        "f0_shift_semitones_medido": round(12 * float(np.log2(ratio)), 2) if ratio else None,
                        "wav": str(dst)})
            print(f"{stem:40s} {pr:8s} F0 {before['f0_median_hz']}->{after['f0_median_hz']} Hz "
                  f"({rep[-1]['f0_shift_semitones_medido']} st) {after['lufs']} LUFS {after['true_peak_dbtp']} dBTP")
    (a.out / "report.json").write_text(json.dumps(rep, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    sys.exit(main())
