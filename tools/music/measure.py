#!/usr/bin/env python3
"""Rota Brava D20: medidas de trilha (sem escuta) e teste de emenda de loop.

measure.py stats a.mp3 [...]        -> duracao, LUFS, pico verdadeiro, LRA, faixa de frequencia
                                       (frequencia abaixo da qual ficam 95% e 99% da energia), andamento estimado
measure.py loop in.mp3 out.wav [--bpm 100] [--beats-xfade 1]
    -> testa 2 emendas: (a) corte no cruzamento por zero mais proximo do fim de compasso;
       (b) crossfade de 1 batida, com a cauda dobrada sobre o inicio. Mede a diferenca de energia
       (RMS em 50 ms antes x 50 ms depois da emenda, em dB) e grava o loop (b) repetido 2x para conferencia.
Requer numpy + soundfile (venv .tools/audio-venv).
"""
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

import numpy as np
import soundfile as sf


def decode(path: Path, sr: int = 44100) -> np.ndarray:
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", str(path), "-f", "f32le", "-ac", "2", "-ar", str(sr), "-"],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype=np.float32).reshape(-1, 2).astype(np.float64)


def ebur(path: Path) -> dict:
    err = subprocess.run(["ffmpeg", "-hide_banner", "-nostats", "-i", str(path), "-af", "ebur128=peak=true",
                          "-f", "null", "-"], capture_output=True, text=True).stderr
    t = err[err.rindex("Summary:"):]
    return {"lufs": float(t.split("I:")[1].split("LUFS")[0]), "lra_lu": float(t.split("LRA:")[1].split("LU")[0]),
            "true_peak_dbtp": float(t.split("Peak:")[1].split("dBFS")[0])}


def bandwidth(x: np.ndarray, sr: int) -> dict:
    m = x.mean(axis=1)
    n = 8192
    acc = np.zeros(n // 2 + 1)
    for s in range(0, len(m) - n, n):
        acc += np.abs(np.fft.rfft(m[s:s + n] * np.hanning(n))) ** 2
    c = np.cumsum(acc) / acc.sum()
    f = np.fft.rfftfreq(n, 1 / sr)
    # limite superior: maior frequencia com energia acima de -80 dB do pico do espectro medio
    db = 10 * np.log10(acc / acc.max() + 1e-20)
    top = f[np.nonzero(db > -80)[0].max()]
    return {"f95_hz": round(float(f[np.searchsorted(c, 0.95)])), "f99_hz": round(float(f[np.searchsorted(c, 0.99)])),
            "f_top_minus80db_hz": round(float(top))}


def tempo(x: np.ndarray, sr: int) -> float:
    m = x.mean(axis=1)
    hop = 512
    e = np.array([np.sum(m[i:i + 1024] ** 2) for i in range(0, len(m) - 1024, hop)])
    o = np.maximum(0, np.diff(np.log(e + 1e-9)))
    o -= o.mean()
    ac = np.correlate(o, o, "full")[len(o) - 1:]
    fps = sr / hop
    lags = np.arange(len(ac))
    lo, hi = int(fps * 60 / 180), int(fps * 60 / 60)
    lag = lo + int(np.argmax(ac[lo:hi]))
    return round(60 * fps / lags[lag], 1)


def stats(path: Path) -> dict:
    x = decode(path)
    return {"file": str(path), "duration_s": round(len(x) / 44100, 2), **ebur(path), **bandwidth(x, 44100),
            "tempo_bpm_estimado": tempo(x, 44100)}


def rms_db(a: np.ndarray) -> float:
    return 20 * np.log10(np.sqrt(np.mean(a ** 2)) + 1e-12)


def seam_jump(y: np.ndarray, sr: int) -> dict:
    """y ja em loop: compara o fim com o inicio (o que o ouvinte escuta na volta)."""
    w = int(0.05 * sr)
    a, b = y[-w:], y[:w]
    return {"rms_fim_db": round(rms_db(a), 2), "rms_inicio_db": round(rms_db(b), 2),
            "diferenca_db": round(abs(rms_db(a) - rms_db(b)), 2),
            "salto_amostra": round(float(np.max(np.abs(y[0] - y[-1]))), 4)}


def loop(src: Path, dst: Path, bpm: float, beats_xfade: float = 1.0, bars: int | None = None) -> dict:
    sr = 44100
    x = decode(src, sr)
    beat = 60.0 / bpm
    bar = 4 * beat
    usable = len(x) / sr - 1.0  # ignora o ultimo segundo (cauda/fim do modelo)
    nbars = bars or int(usable // bar)
    end = int(round(nbars * bar * sr))
    # (a) corte seco: fim no cruzamento por zero mais proximo de `end`
    m = x.mean(axis=1)
    zc = np.nonzero(np.diff(np.signbit(m[end - 2000:end + 2000])))[0]
    cut = end - 2000 + int(zc[np.argmin(np.abs(zc - 2000))]) if len(zc) else end
    ya = x[:cut]
    # (b) crossfade de N batidas: os N tempos depois do fim sao dobrados sobre o inicio (equal power)
    xf = int(beats_xfade * beat * sr)
    tail = x[end:end + xf]
    if len(tail) < xf:
        xf = len(tail)
    t = np.linspace(0, np.pi / 2, xf)[:, None]
    yb = x[:end].copy()
    yb[:xf] = yb[:xf] * np.sin(t) + tail[:xf] * np.cos(t)
    dst.parent.mkdir(parents=True, exist_ok=True)
    sf.write(str(dst), np.vstack([yb, yb]), sr, subtype="PCM_16")
    return {"src": str(src), "bpm": bpm, "compassos": nbars, "loop_s": round(end / sr, 3),
            "corte_zero": seam_jump(ya, sr), "crossfade_1_batida": seam_jump(yb, sr), "teste_2x": str(dst)}


def main(argv: list[str]) -> int:
    if argv[0] == "stats":
        r = [stats(Path(p)) for p in argv[1:]]
    else:
        bpm = float(argv[argv.index("--bpm") + 1]) if "--bpm" in argv else 100.0
        r = loop(Path(argv[1]), Path(argv[2]), bpm)
    print(json.dumps(r, ensure_ascii=False, indent=1))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
