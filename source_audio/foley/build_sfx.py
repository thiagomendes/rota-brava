"""Efeitos e ambientes (RB-R1 D3): foley CC0 (Kenney, OpenGameArt) editado, em camadas, com variacoes; partes
sinteticas ORIGINAIS onde nao ha CC0 adequado (motor, buzina, corrente do rio, lavagem do mar).

Loops sem emenda por construcao: (1) eventos espalhados de forma CIRCULAR (o que passa do fim volta ao inicio),
(2) ruido moldado por FFT de comprimento L (periodico por definicao), (3) crossfade de potencia constante para
gravacoes longas (vento, mercado, passaros). Saida: OGG (ambiente/loops longos) e WAV PCM16 (curtos).
Uso: python source_audio/foley/build_sfx.py
"""
from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from scipy import signal

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "r1"))
from common import (OUT_AUDIO, best_roll, SRC, compress, crossfade_loop, fade, filt, limit, load, lufs, measure, pan,  # noqa: E402
                    res_path, reverb, sample_peak, save_json, seam_jump, seam_ratio, trim, write_ogg, write_wav)

HERE = Path(__file__).resolve().parent
SR = 44100
RNG = np.random.default_rng(2026)
ENTRIES: list[dict] = []


def src(asset: str, name: str | None = None) -> Path:
    base = SRC / asset
    if name is None:
        return next(p for p in base.rglob("*") if p.suffix.lower() in (".wav", ".flac", ".ogg"))
    return next(base.rglob(name))


def k(asset: str, name: str) -> tuple[np.ndarray, str]:
    p = src(asset, name)
    return load(p, SR, mono=True), f"{asset}/{p.name}"


def pitch(x: np.ndarray, semis: float) -> np.ndarray:
    """Varispeed (muda altura e duracao), como fita."""
    if abs(semis) < 1e-3:
        return x
    r = 2 ** (semis / 12)
    n = int(len(x) / r)
    return signal.resample(x, n) if len(x) < 400000 else np.interp(np.arange(n) * r, np.arange(len(x)), x)


def periodic_noise(L: int, shape) -> np.ndarray:
    """Ruido com espectro |H(f)| = shape(f), periodico em L amostras (loop perfeito)."""
    f = np.fft.rfftfreq(L, 1 / SR)
    spec = (RNG.standard_normal(len(f)) + 1j * RNG.standard_normal(len(f))) * shape(np.maximum(f, 1.0))
    spec[0] = 0
    x = np.fft.irfft(spec, n=L)
    return x / (np.sqrt(np.mean(x ** 2)) + 1e-12)


def scatter(L: int, events: list[tuple[float, np.ndarray]], stereo=True) -> np.ndarray:
    """Soma eventos (t_s, sinal mono ou estereo) num buffer circular de L amostras."""
    out = np.zeros((L, 2)) if stereo else np.zeros(L)
    for t, x in events:
        if stereo and x.ndim == 1:
            x = pan(x, 0)
        i = int(t * SR) % L
        n = len(x)
        while n > 0:
            m = min(n, L - i)
            out[i:i + m] += x[len(x) - n:len(x) - n + m]
            n -= m
            i = 0
    return out


def periodic_lfo(L: int, cycles: int, phase: float = 0.0) -> np.ndarray:
    return 0.5 + 0.5 * np.cos(2 * np.pi * cycles * np.arange(L) / L + phase)


def norm_lufs(x, target, ceil=-1.5, loop=False):
    x = x * 10 ** ((target - lufs(x, SR)) / 20)
    if loop:
        n = len(x)
        return limit(np.concatenate([x, x]), SR, ceil)[n:]
    return limit(x, SR, ceil)


def norm_peak(x, peak_db):
    return x * (10 ** (peak_db / 20) / (np.abs(x).max() + 1e-12))


def emit(name: str, x: np.ndarray, kind: str, bus: str, sources: list[str], loop=False, caption=None,
         gain_db=0.0, ogg=False, note=""):
    folder = {"ambience": "ambience", "music": "music"}.get(kind, "sfx")
    path = OUT_AUDIO / folder / (f"{name}.ogg" if ogg else f"{name}.wav")
    if loop:
        x = best_roll(x)
    else:
        x = fade(trim(x, SR, -38.0, 0.002), SR, 0.001, 0.01)
    if ogg:
        write_ogg(path, x, SR, 0.4)
    else:
        write_wav(path, x, SR)
    dec = load(path, SR, mono=(x.ndim == 1))
    m = measure(dec, SR)
    rec = {"name": name, "file": res_path(path), "type": kind, "bus": bus, "loop": loop, "gain_db": gain_db,
           "caption_key": caption, "channels": 1 if x.ndim == 1 else 2, "sample_rate": SR, **m,
           "bytes": path.stat().st_size, "sources": sources,
           "license": "CC0-1.0 (fontes) + edicao/sintese original" if any(not s.startswith("original") for s in sources) else "original",
           "tool": "source_audio/foley/build_sfx.py", "note": note}
    if loop:
        rec["seam_jump"] = round(seam_jump(dec), 5)
        rec["seam_ratio"] = round(seam_ratio(dec), 3)
    ENTRIES.append(rec)
    print(f"sfx    {name:24s} {m['duration']:6.2f}s pk {m['peak_dbfs']:6.1f} {m['lufs']:6.1f} LUFS"
          + (f" seam {rec['seam_jump']:.4f} (x{rec['seam_ratio']:.2f})" if loop else ""))


# ------------------------------------------------------------------ ambientes

def sea_wash(L: int, level=1.0) -> np.ndarray:
    a = periodic_noise(L, lambda f: 1 / np.sqrt(f) * np.exp(-f / 2500))
    b = periodic_noise(L, lambda f: 1 / np.sqrt(f) * np.exp(-f / 2500))
    swell_a = 0.35 + 0.65 * periodic_lfo(L, 7) ** 2
    swell_b = 0.35 + 0.65 * periodic_lfo(L, 9, 1.3) ** 2
    return np.stack([a * swell_a, b * swell_b], axis=1) * level


def wave_events(L_s: float, n: int, assets: list[str], dist_lp: float) -> tuple[list, list[str]]:
    used, ev = set(), []
    for i in range(n):
        a = assets[i % len(assets)]
        x, s = k(a, "*.flac")
        used.add(s)
        x = pitch(x, RNG.uniform(-3, 1))
        x = filt(x, "lowpass", dist_lp * RNG.uniform(0.8, 1.2), SR) * RNG.uniform(0.4, 1.0)
        ev.append((RNG.uniform(0, L_s), pan(x, RNG.uniform(-0.7, 0.7))))
    return ev, sorted(used)


def amb_dock_water():
    L_s = 40.0
    L = int(L_s * SR)
    bed = sea_wash(L) * 0.25
    bed = filt(np.concatenate([bed, bed]), "lowpass", 1800, SR)[L:]
    ev, used = wave_events(L_s, 22, ["oga_waves_a1", "oga_waves_a2", "oga_waves_a3", "oga_waves_a4"], 3500)
    # batidas de agua no pilar (cais): ondas curtas, graves
    x = scatter(L, ev) + bed
    emit("amb_dock_water", norm_lufs(x, -24, loop=True), "ambience", "Ambiente", used + ["original: lavagem do mar (ruido periodico)"],
         loop=True, ogg=True)


def amb_beach_waves():
    L_s = 44.0
    L = int(L_s * SR)
    bed = sea_wash(L) * 0.35
    ev, used = wave_events(L_s, 14, ["oga_beach_1", "oga_beach_2", "oga_beach_3", "oga_beach_4"], 7000)
    x = scatter(L, ev) + bed
    emit("amb_beach_waves", norm_lufs(x, -23, loop=True), "ambience", "Ambiente", used + ["original: lavagem do mar (ruido periodico)"],
         loop=True, ogg=True)


def amb_wind_light():
    a, sa = k("oga_wind_1", "wind1.wav")
    b, sb = k("oga_wind_2", "wind2.wav")
    a = filt(a, "lowpass", 3000, SR)
    b = filt(b, "lowpass", 3000, SR)
    x = np.stack([crossfade_loop(a, SR, 36, 4), crossfade_loop(b[int(3 * SR):], SR, 36, 4)], axis=1)
    emit("amb_wind_light", norm_lufs(x, -29, loop=True), "ambience", "Ambiente", [sa, sb], loop=True, ogg=True)


def amb_gulls_far():
    L_s = 45.0
    L = int(L_s * SR)
    used, ev = [], []
    for i in range(16):
        a = f"oga_gull_{i % 5 + 1}"
        x, s = k(a, "*.wav")
        used.append(s)
        x = pitch(x, RNG.uniform(-2, 2))
        x = filt(x, "lowpass", RNG.uniform(3500, 6500), SR) * RNG.uniform(0.25, 0.9)
        ev.append((RNG.uniform(0, L_s), pan(x, RNG.uniform(-0.9, 0.9))))
    x = scatter(L, ev)
    x = reverb(x, SR, size=0.6, wet=0.3, seed=5)
    x = x[:L] + np.pad(x[L:], ((0, max(0, 2 * L - len(x))), (0, 0)))[:L]  # cauda volta ao inicio
    emit("amb_gulls_far", norm_lufs(x, -30, loop=True), "ambience", "Ambiente", sorted(set(used)), loop=True, ogg=True)


def amb_dock_creaks():
    L_s = 36.0
    L = int(L_s * SR)
    tree, st = k("oga_tree_creak", "tree_creak.flac")
    cr = [k("kenney_rpg", f"creak{i}.ogg") for i in (1, 2, 3)]
    used = [st] + [c[1] for c in cr]
    ev = []
    for i in range(10):
        if i % 3 == 0:
            a = int(RNG.uniform(0, len(tree) - 2 * SR))
            x = tree[a:a + int(RNG.uniform(0.8, 1.8) * SR)]
        else:
            x = cr[i % 3][0]
        x = fade(pitch(x, RNG.uniform(-5, -1)), SR, 0.02, 0.1)
        x = filt(x, "lowpass", 2500, SR) * RNG.uniform(0.3, 0.8)
        ev.append((RNG.uniform(0, L_s), pan(x, RNG.uniform(-0.6, 0.6))))
    x = scatter(L, ev)
    x = x + sea_wash(L) * 0.002  # piso minimo para o limitador nao bombear silencio
    emit("amb_dock_creaks", norm_lufs(x, -31, loop=True), "ambience", "Ambiente", used, loop=True, ogg=True)


def villager_babble() -> tuple[list[np.ndarray], list[str]]:
    out, used = [], []
    for p in sorted((OUT_AUDIO / "voice").glob("crowd_villager_*.wav")):
        out.append(load(p, SR))
        used.append("original: " + p.name + " (babble.py)")
    return out, used


def amb_village_market():
    crowd, sc = k("oga_crowd", "crowd_shouting_0.ogg")
    crowd = filt(filt(crowd, "lowpass", 2200, SR), "highpass", 150, SR)
    c1 = crossfade_loop(crowd, SR, 24, 3)
    L = 2 * len(c1)
    bed = np.tile(c1, 2)
    bed = np.stack([bed, np.roll(bed, int(9.3 * SR))], axis=1) * 0.5
    voices, used = villager_babble()
    ev = []
    for i in range(14):
        v = voices[i % len(voices)] if voices else np.zeros(10)
        v = filt(v, "lowpass", RNG.uniform(2500, 4000), SR) * RNG.uniform(0.15, 0.4)
        ev.append((RNG.uniform(0, L / SR), pan(v, RNG.uniform(-0.8, 0.8))))
    x = bed + scatter(L, ev)
    x = reverb(x, SR, size=0.5, wet=0.25, seed=9)
    x = x[:L] + np.pad(x[L:], ((0, max(0, 2 * L - len(x))), (0, 0)))[:L]
    emit("amb_village_market", norm_lufs(x, -30, loop=True), "ambience", "Ambiente", [sc] + used, loop=True, ogg=True,
         note="mercado distante: multidao CC0 filtrada + balbucio original dos moradores")


def amb_river():
    L_s = 40.0
    L = int(L_s * SR)
    flow = np.stack([periodic_noise(L, lambda f: np.exp(-((np.log(f) - np.log(700)) ** 2) / 1.2)),
                     periodic_noise(L, lambda f: np.exp(-((np.log(f) - np.log(800)) ** 2) / 1.2))], axis=1) * 0.12
    ev = []
    for i in range(900):  # bolhas: senoides curtas com glissando ascendente (sintese original)
        d = RNG.uniform(0.008, 0.03)
        t = np.arange(int(d * SR)) / SR
        f0 = RNG.uniform(350, 1400)
        b = np.sin(2 * np.pi * f0 * t * (1 + t / d * RNG.uniform(0.2, 0.8))) * np.exp(-t / (d / 3))
        ev.append((RNG.uniform(0, L_s), pan(b * RNG.uniform(0.02, 0.12), RNG.uniform(-0.8, 0.8))))
    x = flow * (0.7 + 0.3 * periodic_lfo(L, 5)[:, None]) + scatter(L, ev)
    emit("amb_river", norm_lufs(x, -25, loop=True), "ambience", "Ambiente", ["original: corrente (ruido periodico + bolhas sintetizadas)"],
         loop=True, ogg=True)


def amb_birds():
    b, s = k("oga_birds", "birds-isaiah658_0.ogg")
    st = load(src("oga_birds", "birds-isaiah658_0.ogg"), SR, mono=False)
    x = np.stack([crossfade_loop(st[:, 0], SR, 27, 3), crossfade_loop(st[:, 1], SR, 27, 3)], axis=1)
    x = filt(x, "highpass", 600, SR)
    emit("amb_birds", norm_lufs(x, -31, loop=True), "ambience", "Ambiente", [s], loop=True, ogg=True)


# ------------------------------------------------------------------ passos

def steps():
    sets = {
        "wood": [("kenney_impact", f"footstep_wood_00{i}.ogg") for i in range(5)] + [("kenney_impact", "impactPlank_medium_001.ogg")],
        "stone": [("oga_steps_fantozzi", f"Fantozzi-Stone{s}{i}.flac") for s in "LR" for i in (1, 2, 3)],
        "sand": [("oga_steps_fantozzi", f"Fantozzi-Sand{s}{i}.flac") for s in "LR" for i in (1, 2, 3)],
        "grass": [("kenney_impact", f"footstep_grass_00{i}.ogg") for i in range(5)] + [("kenney_impact", "footstep_carpet_002.ogg")],
    }
    for surf, items in sets.items():
        for i, (a, n) in enumerate(items):
            x, s = k(a, n)
            x = trim(x, SR, -45)
            used = [s]
            if surf == "wood":
                x = filt(x, "peak", 180, SR, 1.0, 3.0)  # corpo de tabua oca
                if n.startswith("impactPlank"):
                    x = pitch(x, -2) * 0.6
            if surf == "sand":
                snow, s2 = k("kenney_impact", f"footstep_snow_00{i % 5}.ogg")
                snow = filt(trim(snow, SR, -45), "lowpass", 3000, SR)
                m = min(len(x), len(snow))
                x = x[:m] + 0.35 * snow[:m] * (np.abs(x).max() / (np.abs(snow).max() + 1e-9))
                used.append(s2)
            x = x[: int(0.45 * SR)]
            x = fade(x, SR, 0.001, 0.06)
            x = x * 10 ** ((-27.0 - lufs(x, SR)) / 20)
            if sample_peak(x) > -6.0:
                x = norm_peak(x, -6.0)
            emit(f"sfx_step_{surf}_{i + 1:02d}", x, "step", "Efeitos", used)


# ------------------------------------------------------------------ barco

def engine_loop():
    L_s = 2.0
    L = int(L_s * SR)
    fire = 24.0  # Hz de ignicao no loop base (pitch 1.0); inteiro de ciclos em L
    cycles = int(fire * L_s)
    t = np.arange(L) / SR
    ph = (t * cycles / L_s) % 1.0
    pulse = np.exp(-ph * 9) * (1 + 0.3 * np.cos(2 * np.pi * 2 * t / L_s))  # leve desigualdade entre cilindros
    body = filt(filt(pulse - pulse.mean(), "lowpass", 900, SR), "peak", 140, SR, 2.0, 6)
    rattle = periodic_noise(L, lambda f: np.exp(-((np.log(f) - np.log(2400)) ** 2) / 0.6)) * (0.2 + pulse * 0.6) * 0.05
    whine = np.sin(2 * np.pi * (cycles * 9) * t / L_s) * 0.015
    water = periodic_noise(L, lambda f: 1 / np.sqrt(f) * np.exp(-f / 1200)) * 0.06
    x = body / (np.abs(body).max() + 1e-9) * 0.7 + rattle + whine + water
    n = len(x)
    x = limit(np.concatenate([x, x]), SR, -3.0)[n:]
    x = norm_peak(x, -3.0)
    emit("sfx_engine_loop", x, "loop", "Efeitos", ["original: motor de popa pequeno (pulsos de ignicao + ruido periodico)"], loop=True)


def boat_wake():
    L_s = 8.0
    L = int(L_s * SR)
    hiss = np.stack([periodic_noise(L, lambda f: np.exp(-((np.log(f) - np.log(1500)) ** 2) / 1.5)) for _ in range(2)], axis=1)
    hiss *= (0.6 + 0.4 * periodic_lfo(L, 3)[:, None]) * 0.2
    ev, used = wave_events(L_s, 6, ["oga_waves_a1", "oga_waves_a3"], 5000)
    x = hiss + scatter(L, ev) * 0.5
    x = norm_peak(x, -3.0)
    emit("sfx_boat_wake", x, "loop", "Efeitos", used + ["original: espuma (ruido periodico)"], loop=True, ogg=True)


def horn():
    d = 1.6
    t = np.arange(int(d * SR)) / SR
    env = np.minimum(1, t / 0.06) * np.minimum(1, (d - t) / 0.25)
    vib = 1 + 0.004 * np.sin(2 * np.pi * 5 * t)
    x = np.zeros_like(t)
    for f in (233.0, 293.0):  # dois tons (Bb3 + D4) de buzina de barco pequeno
        ph = np.cumsum(f * vib / SR)
        saw = 2 * (ph % 1) - 1
        x += saw
    x = filt(filt(x, "peak", 650, SR, 1.5, 9), "peak", 1700, SR, 2, 6)
    x = filt(x, "lowpass", 4500, SR) * env
    x = reverb(x, SR, 0.8, 0.25, seed=21)
    emit("sfx_horn_boat", norm_peak(x, -3.0), "oneshot", "Efeitos", ["original: buzina de dois tons (sintese)"], caption="audio.caption.horn_boat")
    # "Fom fom" do filhote: dois toques curtos
    one = x[: int(0.35 * SR)] * np.linspace(1, 0.7, int(0.35 * SR))
    fom = np.concatenate([fade(one, SR, 0.005, 0.05), np.zeros(int(0.12 * SR)), fade(one, SR, 0.005, 0.12)])
    emit("sfx_horn_fomfom", norm_peak(fom, -3.0), "oneshot", "Efeitos", ["original: buzina (sintese)"], caption="audio.caption.horn_boat")


def hull_bump():
    a, sa = k("kenney_impact", "impactWood_heavy_002.ogg")
    b, sb = k("kenney_impact", "impactPlank_medium_003.ogg")
    t = np.arange(int(0.5 * SR)) / SR
    thump = np.sin(2 * np.pi * 70 * t * (1 - 0.3 * t)) * np.exp(-t * 10)
    m = max(len(a), len(b), len(thump))
    x = np.pad(pitch(a, -4), (0, m))[:m] + 0.6 * np.pad(pitch(b, -2), (0, m))[:m] + 0.5 * np.pad(thump, (0, m))[:m]
    ev, used = wave_events(1.0, 2, ["oga_waves_a2"], 3000)
    splash = scatter(int(1.2 * SR), [(0.05, e[1][:, 0]) for e in ev], stereo=False)
    x = np.pad(x, (0, max(0, len(splash) - len(x))))
    x[: len(splash)] += splash * 0.25
    emit("sfx_hull_bump", norm_peak(x, -3.0), "oneshot", "Efeitos", [sa, sb] + used + ["original: baque grave"], caption="audio.caption.hull_bump")


def crate_slide():
    d = 0.9
    t = np.arange(int(d * SR)) / SR
    scrape = RNG.standard_normal(len(t)) * (0.5 + 0.5 * np.abs(np.sin(2 * np.pi * 23 * t))) * np.minimum(1, t / 0.05)
    scrape = filt(filt(scrape, "bandpass", 900, SR, 1.2), "lowpass", 3000, SR) * np.linspace(1, 0.4, len(t))
    hit, s = k("kenney_impact", "impactWood_medium_001.ogg")
    x = np.concatenate([scrape, np.zeros(len(hit))])
    x[len(scrape) - int(0.03 * SR):len(scrape) - int(0.03 * SR) + len(hit)] += pitch(hit, -3)[: len(hit)] * 2
    emit("sfx_crate_slide", norm_peak(x, -3.0), "oneshot", "Efeitos", [s, "original: raspado (ruido filtrado)"], caption="audio.caption.crate_slide")


# ------------------------------------------------------------------ corda

def rope():
    c1, s1 = k("kenney_rpg", "creak2.ogg")
    emit("sfx_rope_creak", norm_peak(filt(pitch(c1, 3), "highpass", 300, SR), -3.0), "oneshot", "Efeitos", [s1], caption="audio.caption.rope_creak")
    for i, (cl, cr) in enumerate([("cloth2.ogg", "creak1.ogg"), ("cloth4.ogg", "creak3.ogg")]):
        a, sa = k("kenney_rpg", cl)
        b, sb = k("kenney_rpg", cr)
        b = filt(pitch(b, 4 + i), "highpass", 400, SR)[: int(0.5 * SR)]
        m = max(len(a), len(b))
        x = np.pad(a, (0, m))[:m] + 0.6 * np.pad(b, (0, m))[:m]
        t = np.arange(int(0.25 * SR)) / SR
        x[: len(t)] += 0.4 * np.sin(2 * np.pi * (110 + 15 * i) * t) * np.exp(-t * 18)  # tranco da linha esticando
        name = "sfx_rope_tug" if i == 0 else "sfx_rope_tug_02"
        emit(name, norm_peak(x, -3.0), "oneshot", "Efeitos", [sa, sb, "original: tranco grave"], caption="audio.caption.rope_tug")
    belt, sb = k("kenney_rpg", "beltHandle1.ogg")
    t = np.arange(int(0.12 * SR)) / SR
    snap = RNG.standard_normal(len(t)) * np.exp(-t * 60)
    snap = filt(snap, "highpass", 1500, SR)
    x = np.concatenate([snap, np.zeros(int(0.1 * SR))])
    x[: min(len(x), len(belt))] += 0.7 * pitch(belt, 2)[: min(len(x), len(belt))]
    emit("sfx_rope_snap", norm_peak(x, -3.0), "oneshot", "Efeitos", [sb, "original: estalo (ruido)"], caption="audio.caption.rope_snap")


# ------------------------------------------------------------------ UI

def ui():
    def kk(n):
        return k("kenney_interface", n)
    m, s = kk("select_002.ogg")
    emit("sfx_ui_move", norm_peak(m, -6.0), "ui", "Efeitos", [s])
    c, s = kk("confirmation_001.ogg")
    emit("sfx_ui_confirm", norm_peak(c, -4.0), "ui", "Efeitos", [s])
    b, s = kk("back_002.ogg")
    emit("sfx_ui_back", norm_peak(b, -5.0), "ui", "Efeitos", [s])
    o, s = kk("maximize_006.ogg")
    emit("sfx_ui_open", norm_peak(o, -5.0), "ui", "Efeitos", [s])
    # troca de heroi: sopro (ruido com varredura) + dedilhado
    d = 0.35
    t = np.arange(int(d * SR)) / SR
    wh = RNG.standard_normal(len(t)) * np.sin(np.pi * t / d) ** 2
    wh = signal.lfilter(*signal.butter(2, [800 / (SR / 2), 4000 / (SR / 2)], "band"), wh)
    p, s = kk("pluck_001.ogg")
    x = np.pad(wh * 0.3, (0, len(p)))
    x[int(0.15 * SR):int(0.15 * SR) + len(p)] += p
    emit("sfx_ui_swap", norm_peak(x, -4.0), "ui", "Efeitos", [s, "original: sopro filtrado"])
    # pista encontrada: sino CC0 + brilho de vidro, subindo
    bell, sb = k("oga_bell_1", "bell_ding1.wav")
    g1, sg1 = kk("glass_002.ogg")
    g2, sg2 = kk("glass_004.ogg")
    x = np.zeros(int(1.6 * SR))
    for t0, v, sh in ((0.0, g1, 0), (0.07, g2, 3), (0.14, g1, 7)):
        v = pitch(v, sh)
        x[int(t0 * SR):int(t0 * SR) + len(v)] += v[: len(x) - int(t0 * SR)] * 0.5
    bb = pitch(bell, 2)[: len(x) - int(0.2 * SR)]
    x[int(0.2 * SR):int(0.2 * SR) + len(bb)] += bb
    emit("sfx_clue_found", norm_peak(x, -3.0), "ui", "Efeitos", [sb, sg1, sg2], caption="audio.caption.clue_found")
    # estrela: sino 3 + arpejo de brilhos
    bell3, sb3 = k("oga_bell_3", "bell_ding3.wav")
    x = np.zeros(int(1.8 * SR))
    for i, sh in enumerate((0, 4, 7, 12, 16)):
        v = pitch(g1, sh) * (0.35 + 0.08 * i)
        a = int(i * 0.06 * SR)
        x[a:a + len(v)] += v[: len(x) - a]
    bb = pitch(bell3, 5)[: len(x) - int(0.3 * SR)]
    x[int(0.3 * SR):int(0.3 * SR) + len(bb)] += bb * 0.9
    emit("sfx_ui_star", norm_peak(x, -3.0), "ui", "Efeitos", [sb3, sg1], caption="audio.caption.star")
    # caderno: folha virando + rabisco (ruido em rajadas)
    f, sf_ = k("kenney_rpg", "bookFlip2.ogg")
    t = np.arange(int(0.5 * SR)) / SR
    scr = RNG.standard_normal(len(t)) * (np.sin(2 * np.pi * 9 * t) > 0.2) * 0.25
    scr = filt(scr, "bandpass", 3500, SR, 1.0)
    x = np.concatenate([f, scr])
    emit("sfx_notebook", norm_peak(x, -3.0), "oneshot", "Efeitos", [sf_, "original: rabisco (ruido)"], caption="audio.caption.notebook")


def main() -> int:
    for fn in (amb_dock_water, amb_beach_waves, amb_wind_light, amb_gulls_far, amb_dock_creaks, amb_village_market,
               amb_river, amb_birds, steps, engine_loop, boat_wake, horn, hull_bump, crate_slide, rope, ui):
        fn()
    save_json(HERE / "generated.json", {"tool": "source_audio/foley/build_sfx.py", "entries": ENTRIES})
    return 0


if __name__ == "__main__":
    sys.exit(main())
