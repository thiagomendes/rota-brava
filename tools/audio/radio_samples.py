#!/usr/bin/env python3
"""Rota Brava G20: amostras offline do radio do Farol 7 para o Thiago (captures/g20/, fora do Git).

Para cada take: <id>_antes.wav (take original) e <id>_depois.wav (abrir + voz pela cadeia do bus Radio com o
chiado no mesmo bus + fechar, igual a ordem do jogo). Mede espectro (fracao de energia por banda) e niveis
(pico, RMS, LUFS integrado BS.1770 simplificado com filtro K) e grava captures/g20/report.json.
Uso: .tools/audio-venv/bin/python tools/audio/radio_samples.py [ids...]
Nada foi ouvido: so medidas. A cadeia e uma aproximacao (Butterworth/tanh/compressor proprio), nao a DSP da Godot.
"""
import json
import sys
from pathlib import Path

import numpy as np
import soundfile as sf
from scipy import signal

sys.path.insert(0, str(Path(__file__).resolve().parent))
import radio_fx as fx  # noqa: E402

ROOT = fx.ROOT
OUT = ROOT / "captures/g20"
SR = fx.SR
DEFAULT_IDS = ["ep01.radio.intro.hello", "ep01.radio.v3_m1.trail"]
HISS_DB = -4.0  # RADIO_HISS_DB do AudioDirector


def load(res_path):
    x, sr = sf.read(ROOT / "game" / res_path.removeprefix("res://"), always_2d=True)
    x = x.mean(axis=1)
    if sr != SR:
        x = signal.resample_poly(x, SR, sr)
    return x


def lufs(x):
    # filtro K (BS.1770) com bloqueio absoluto -70 e relativo -10; blocos de 400 ms, passo 100 ms
    b1, a1 = [1.53512485958697, -2.69169618940638, 1.19839281085285], [1.0, -1.69065929318241, 0.73248077421585]
    b2, a2 = [1.0, -2.0, 1.0], [1.0, -1.99004745483398, 0.99007225036621]
    y = signal.lfilter(b2, a2, signal.lfilter(b1, a1, x))
    n, h = int(0.4 * SR), int(0.1 * SR)
    ms = np.array([np.mean(y[i:i + n] ** 2) for i in range(0, max(len(y) - n, 1), h)])
    lk = -0.691 + 10 * np.log10(ms + 1e-12)
    g = ms[lk > -70]
    if g.size == 0:
        return -99.0
    rel = -0.691 + 10 * np.log10(np.mean(g)) - 10
    g = ms[(lk > -70) & (lk > rel)]
    return round(float(-0.691 + 10 * np.log10(np.mean(g))), 2)


def bands(x):
    f, p = signal.welch(x, SR, nperseg=4096)
    tot = p.sum()
    edges = [(0, 300), (300, 3400), (3400, 8000), (8000, SR / 2)]
    return {"%d-%d Hz" % e: round(float(p[(f >= e[0]) & (f < e[1])].sum() / tot * 100), 2) for e in edges}


def levels(x):
    return {"duration_s": round(len(x) / SR, 3), "peak_dbfs": round(float(20 * np.log10(np.max(np.abs(x)) + 1e-12)), 2),
            "rms_dbfs": round(float(20 * np.log10(np.sqrt(np.mean(x ** 2)) + 1e-12)), 2), "lufs_i": lufs(x),
            "energy_pct_by_band": bands(x)}


def main():
    ids = sys.argv[1:] or DEFAULT_IDS
    cat = {e["id"]: e for e in json.load(open(ROOT / "game/audio/voice/v3/voice_v3_catalog.json"))["lines"]}
    opn, cls, hiss = (load("res://audio/radio/" + n) for n in ("sfx_radio_open.ogg", "sfx_radio_close.ogg", "amb_radio_hiss.ogg"))
    OUT.mkdir(parents=True, exist_ok=True)
    rep = {"chain": fx.CHAIN, "hiss_player_db": HISS_DB, "note": "medidas apenas; nada foi ouvido", "lines": {}}
    for i in ids:
        e = cat[i]
        v = load(e["file"])
        # no jogo: abrir (0..0,16 s), voz a partir de 0,16 s com o chiado (laco) no bus Radio, fechar ao fim da voz
        o = len(opn)
        bed = np.zeros(o + len(v))
        bed[o:] = v + np.resize(hiss, len(v)) * fx.db(HISS_DB)
        voice_fx = fx.radio_chain(bed)
        clicks = np.zeros_like(voice_fx)
        clicks[:o] = opn
        wet = np.concatenate([voice_fx + fx.radio_chain(clicks), fx.radio_chain(cls)])
        base = i.replace(".", "_")
        sf.write(OUT / (base + "_antes.wav"), v.astype(np.float32), SR, subtype="PCM_16")
        sf.write(OUT / (base + "_depois.wav"), wet.astype(np.float32), SR, subtype="PCM_16")
        rep["lines"][i] = {"file": e["file"], "before": levels(v), "after": levels(wet),
                           "after_voice_only": levels(fx.radio_chain(np.r_[np.zeros(o), v])[o:]),
                           "hiss_after_chain": levels(fx.radio_chain(np.resize(hiss, SR * 2) * fx.db(HISS_DB)))}
    (OUT / "report.json").write_text(json.dumps(rep, indent=2, ensure_ascii=False) + "\n")
    print(json.dumps(rep["lines"], indent=1))


if __name__ == "__main__":
    main()
