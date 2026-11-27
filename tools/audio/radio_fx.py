#!/usr/bin/env python3
"""Rota Brava G20: sons de radio (walkie-talkie) do Farol 7, sintetizados pelo projeto.

Gera em game/audio/radio/:
  sfx_radio_open.ogg   "kssh" curto (ruido filtrado em banda + clique de tecla), 160 ms
  sfx_radio_close.ogg  clique de soltar a tecla + cauda curta de chiado, 190 ms
  amb_radio_hiss.ogg   chiado de fundo em laco (2 s, emenda por crossfade), nivel baixo
e source_audio/radio/g20_generated.json (parametros, semente, medidas e sha256 por arquivo).

radio_chain(): aproximacao offline do bus "Radio" da Godot (game/audio/radio_bus.gd): passa-altas 300 Hz e
passa-baixas 3400 Hz de 12 dB/oit, saturacao suave (tanh), compressor. Usada nas amostras de captures/g20.
Uso: .tools/audio-venv/bin/python tools/audio/radio_fx.py
Nada foi ouvido: so medidas.
"""
import hashlib
import json
import sys
from pathlib import Path

import numpy as np
import soundfile as sf
from scipy import signal

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "game/audio/radio"
SR = 44100
SEED = 7007
CLICK_OFFSET_MS = 3.0
# Cadeia do G20 (modelo aproximado em Python do bus Radio de game/audio/radio_bus.gd).
# G22b: na Godot a cadeia atenua ~13 LU a mais que este modelo; o ganho do bus (+10 dB) e o make-up (+14 dB) de la
# foram medidos na propria Godot (game/tests/capture_g22b.gd) e NAO valem aqui. Nao use este modelo para nivel.
CHAIN = {"hp_hz": 300.0, "lp_hz": 3400.0, "order": 2, "drive": 0.2, "pre_gain_db": 0.0, "post_gain_db": -1.0,
         "comp_threshold_db": -18.0, "comp_ratio": 3.0, "comp_attack_ms": 5.0, "comp_release_ms": 150.0,
         "comp_gain_db": 2.0}
PARAMS = {
    "open": {"dur_s": 0.16, "noise_band_hz": [900, 4200], "noise_peak_dbfs": -14.0, "attack_ms": 4,
             "decay_tau_ms": 45, "click_ms": 3.0, "click_hz": 2400, "click_peak_dbfs": -8.0},
    "close": {"dur_s": 0.19, "click_ms": 2.5, "click_hz": 1900, "click_peak_dbfs": -9.0,
              "tail_band_hz": [700, 3800], "tail_peak_dbfs": -18.0, "tail_delay_ms": 6, "tail_tau_ms": 55},
    "hiss": {"dur_s": 2.0, "band_hz": [300, 3400], "rms_dbfs": -42.0, "crossfade_ms": 200, "crackle_per_s": 3,
             "crackle_gain": 4.0},
}


def db(x):
    return 10 ** (x / 20.0)


def bandpass(x, lo, hi, order=2):
    return signal.sosfilt(signal.butter(order, [lo, hi], btype="band", fs=SR, output="sos"), x)


def norm_peak(x, dbfs):
    return x / (np.max(np.abs(x)) + 1e-12) * db(dbfs)


def click(ms, hz, dbfs):
    n = int(SR * ms / 1000)
    t = np.arange(n) / SR
    c = np.sin(2 * np.pi * hz * t) * np.exp(-t / (ms / 3000))
    c[0] += 0.8  # impulso da tecla
    return norm_peak(c, dbfs)


def fade_edges(x, ms=2):
    n = int(SR * ms / 1000)
    x[:n] *= np.linspace(0, 1, n)
    x[-n:] *= np.linspace(1, 0, n)
    return x


def make_open(rng):
    p = PARAMS["open"]
    n = int(SR * p["dur_s"])
    t = np.arange(n) / SR
    env = np.minimum(t / (p["attack_ms"] / 1000), 1.0) * np.exp(-t / (p["decay_tau_ms"] / 1000))
    x = norm_peak(bandpass(rng.standard_normal(n), *p["noise_band_hz"]) * env, p["noise_peak_dbfs"])
    c = click(p["click_ms"], p["click_hz"], p["click_peak_dbfs"])
    o = int(SR * CLICK_OFFSET_MS / 1000)  # depois da rampa de entrada, para o clique nao ser apagado
    x[o:o + c.size] += c
    return fade_edges(x, 1)


def make_close(rng):
    p = PARAMS["close"]
    n = int(SR * p["dur_s"])
    x = np.zeros(n)
    c = click(p["click_ms"], p["click_hz"], p["click_peak_dbfs"])
    o = int(SR * CLICK_OFFSET_MS / 1000)
    x[o:o + c.size] += c
    d = o + int(SR * p["tail_delay_ms"] / 1000)
    tt = np.arange(n - d) / SR
    tail = bandpass(rng.standard_normal(n - d), *p["tail_band_hz"]) * np.exp(-tt / (p["tail_tau_ms"] / 1000))
    x[d:] += norm_peak(tail, p["tail_peak_dbfs"])
    return fade_edges(x, 1)


def make_hiss(rng):
    p = PARAMS["hiss"]
    n = int(SR * p["dur_s"])
    f = int(SR * p["crossfade_ms"] / 1000)
    raw = bandpass(rng.standard_normal(n + f), *p["band_hz"])
    sd = np.std(raw)
    for i in rng.integers(0, n + f - 200, int(p["crackle_per_s"] * p["dur_s"])):
        raw[i:i + 60] += rng.standard_normal(60) * sd * p["crackle_gain"]  # estalos curtos
    w = np.linspace(0, 1, f)
    x = raw[:n].copy()
    x[:f] = raw[:f] * w + raw[n:n + f] * (1 - w)  # o trecho apos o fim entra por baixo do inicio: laco sem degrau
    return x / np.sqrt(np.mean(x ** 2)) * db(p["rms_dbfs"])


def radio_chain(x, c=CHAIN):
    """Aproximacao offline do bus Radio (Butterworth; tanh; compressor de pico com envelope ataque/liberacao)."""
    y = signal.sosfilt(signal.butter(c["order"], c["hp_hz"], "highpass", fs=SR, output="sos"), x)
    y = signal.sosfilt(signal.butter(c["order"], c["lp_hz"], "lowpass", fs=SR, output="sos"), y)
    k = 1.0 + 9.0 * c["drive"]
    y = np.tanh(k * y * db(c["pre_gain_db"])) / np.tanh(k) * db(c["post_gain_db"])
    a = np.exp(-1 / (SR * c["comp_attack_ms"] / 1000))
    r = np.exp(-1 / (SR * c["comp_release_ms"] / 1000))
    mag = np.abs(y)
    env = np.empty_like(y)
    e = 0.0
    for i in range(mag.size):
        v = mag[i]
        e = a * e + (1 - a) * v if v > e else r * e + (1 - r) * v
        env[i] = e
    over = np.maximum(20 * np.log10(env + 1e-9) - c["comp_threshold_db"], 0)
    return y * db(-over * (1 - 1 / c["comp_ratio"]) + c["comp_gain_db"])


def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()


def main():
    rng = np.random.default_rng(SEED)
    OUT.mkdir(parents=True, exist_ok=True)
    files = {"sfx_radio_open.ogg": make_open(rng), "sfx_radio_close.ogg": make_close(rng),
             "amb_radio_hiss.ogg": make_hiss(rng)}
    rec = {"generator": "tools/audio/radio_fx.py", "license": "original (gerado pelo projeto)", "seed": SEED, "click_offset_ms": CLICK_OFFSET_MS,
           "sample_rate": SR, "params": PARAMS, "bus_chain": CHAIN, "files": {}}
    for name, x in files.items():
        p = OUT / name
        sf.write(p, x.astype(np.float32), SR, format="OGG", subtype="VORBIS")
        y, _ = sf.read(p)
        rec["files"]["res://audio/radio/" + name] = {
            "duration_s": round(len(y) / SR, 3),
            "peak_dbfs": round(float(20 * np.log10(np.max(np.abs(y)) + 1e-12)), 2),
            "rms_dbfs": round(float(20 * np.log10(np.sqrt(np.mean(y ** 2)) + 1e-12)), 2),
            "sha256": sha(p)}
    (ROOT / "source_audio/radio/g20_generated.json").write_text(json.dumps(rec, indent=2, ensure_ascii=False) + "\n")
    json.dump(rec["files"], sys.stdout, indent=1)
    print()


if __name__ == "__main__":
    main()
