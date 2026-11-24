"""Temas instrumentais ORIGINAIS de Rota Brava (RB-04), compostos e sintetizados por este script.
Gera game/audio/music/theme_explore.wav (16 compassos, loop), theme_explore_low.wav (versao esparsa, loop) e
theme_discovery.wav (sting 5,4 s, sem loop). Estereo 32 kHz 16 bits. Notacao e progressao: README.md.
Renderizacao CIRCULAR (caudas dobram no inicio): a ultima amostra continua a primeira. Biblioteca padrao apenas."""
import math, os, random, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))
from synthlib import *

SR = 32000
BPM = 104
BEAT = 60.0 / BPM
BARS = 16
N = int(round(SR * BEAT * 4 * BARS))
PEAK_DB = -6.0
TWO_PI = 2 * math.pi
_cache = {}


# ---------- instrumentos (mono, cacheados por nota) ----------
def _cached(key, fn):
    if key not in _cache:
        _cache[key] = fn()
    return _cache[key]


def marimba(name):
    f = hz(name)

    def mk():
        n = int(SR * 1.3)
        out = [0.0] * n
        for k, a, d in ((1.0, 1.0, 4.2), (4.0, 0.22, 20.0), (9.9, 0.05, 45.0)):
            if f * k < 12000:
                add_into(out, damped(n, SR, f * k, d, a, 0.0, 1.5), 0)
        return out
    return _cached(("mar", name), mk)


def pluck(name):
    f = hz(name)

    def mk():
        n = int(SR * 0.7)
        out = [0.0] * n
        for k, a, d in ((1, 1.0, 6.5), (2, 0.45, 9.0), (3, 0.18, 14.0), (4, 0.07, 20.0)):
            add_into(out, damped(n, SR, f * k, d, a, 0.0, 1.0), 0)
        return out
    return _cached(("plk", name), mk)


def bass(name):
    f = hz(name)

    def mk():
        n = int(SR * 1.0)
        out = [0.0] * n
        for k, a, d in ((1, 1.0, 3.8), (2, 0.3, 5.0), (3, 0.08, 8.0)):
            add_into(out, damped(n, SR, f * k, d, a, 0.0, 6.0), 0)
        return out
    return _cached(("bas", name), mk)


def bell(name):
    f = hz(name)

    def mk():
        n = int(SR * 2.8)
        out = [0.0] * n
        for k, a, d in ((1.0, 1.0, 2.2), (2.76, 0.28, 3.4), (5.4, 0.09, 5.5)):
            add_into(out, damped(n, SR, f * k, d, a, 0.0, 2.0), 0)
        return out
    return _cached(("bel", name), mk)


def flute(name, dur):
    f = hz(name)

    def mk():
        n = int(SR * (dur + 0.25))
        out = []
        for i in range(n):
            t = i / SR
            vib = 1 + 0.004 * min(1.0, t / 0.3) * math.sin(TWO_PI * 5.0 * t)
            ph = TWO_PI * f * vib * t
            e = min(1.0, t / 0.09) * (1.0 if t < dur else math.exp(-14 * (t - dur)))
            out.append(e * (math.sin(ph) + 0.16 * math.sin(2 * ph) + 0.05 * math.sin(3 * ph)))
        return out
    return _cached(("flu", name, round(dur, 3)), mk)


def pad(name, dur):
    f = hz(name)

    def mk():
        n = int(SR * (dur + 1.0))
        out = [0.0] * n
        for det in (0.9965, 1.0035):
            w = TWO_PI * f * det / SR
            for i in range(n):
                t = i / SR
                e = min(1.0, t / 0.8) * (1.0 if t < dur else math.exp(-5.0 * (t - dur)))
                out[i] += e * (math.sin(w * i) + 0.12 * math.sin(2 * w * i))
        return out
    return _cached(("pad", name, round(dur, 3)), mk)


def shaker(accent):
    def mk():
        rng = random.Random(77 + int(accent * 10))
        n = int(SR * 0.07)
        x = biquad(noise(rng, n), "hp", 5000, SR)
        return [v * math.exp(-48 * i / SR) * min(1.0, i / (0.002 * SR)) for i, v in enumerate(x)]
    return _cached(("shk", accent), mk)


def clave():
    def mk():
        n = int(SR * 0.09)
        out = [0.0] * n
        add_into(out, damped(n, SR, 2450, 95, 1.0, 0.0, 0.5), 0)
        add_into(out, damped(n, SR, 3150, 130, 0.5, 0.0, 0.5), 0)
        return out
    return _cached(("clv",), mk)


# ---------- composicao ----------
CHORDS = {"C": ("C", False), "G": ("G", False), "Am": ("A", True), "F": ("F", False), "Em": ("E", True)}
NAMES = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]


def triad(sym, octave):
    root, minor = CHORDS[sym]
    i = NAMES.index(root)
    out = []
    for iv in (0, 3 if minor else 4, 7):
        k = i + iv
        out.append(NAMES[k % 12] + str(octave + k // 12))
    return out


# Forma ABA' (A A' B A''), 4 compassos cada. Acordes por compasso:
PROG = ["C", "G", "Am", "F",  "C", "G", "F", "G",  "F", "G", "Em", "Am",  "C", "G", "F", "G"]
# Motivo (assobiavel): G4 C5 E5 | D5 C5 G4 -> salto de quarta, subida a terca, volta por grau conjunto.
M1 = [(0, .5, "G4"), (.5, .5, "C5"), (1, 1, "E5"), (2, .5, "D5"), (2.5, .5, "C5"), (3, 1, "G4")]
M2 = [(0, .5, "B4"), (.5, .5, "D5"), (1, 1, "G5"), (2, .5, "E5"), (2.5, .5, "D5"), (3, 1, "B4")]
M3 = [(0, .5, "A4"), (.5, .5, "C5"), (1, 1, "E5"), (2, .5, "D5"), (2.5, .5, "C5"), (3, 1, "A4")]
M4 = [(0, .5, "A4"), (.5, .5, "C5"), (1, 1, "F5"), (2, 1, "C5"), (3, 1, "D5")]
M4b = [(0, .5, "A4"), (.5, .5, "C5"), (1, 1, "F5"), (2, .5, "E5"), (2.5, .5, "D5"), (3, 1, "C5")]
M5 = [(0, 1, "B4"), (1, 1, "D5"), (2, 2, "G5")]
M5b = [(0, 1, "B4"), (1, 1, "D5"), (2, .5, "F5"), (2.5, .5, "D5"), (3, .5, "B4"), (3.5, .5, "G4")]
MELODY = [
    M1, M2, M3, M4,                       # A
    M1, M2, M4b, M5,                      # A' (final em suspensao)
    [(0, 1.5, "C6"), (1.5, .5, "A5"), (2, 1, "F5"), (3, 1, "A5")],     # B (ponte: notas longas, registro agudo)
    [(0, 1.5, "B5"), (1.5, .5, "G5"), (2, 1, "D5"), (3, 1, "G5")],
    [(0, 1, "E5"), (1, 1, "G5"), (2, 1, "B5"), (3, 1, "G5")],
    [(0, 1, "C6"), (1, .5, "B5"), (1.5, .5, "A5"), (2, 2, "E5")],
    M1, M2, M4b, M5b,                     # A'' (volta; o G4 final puxa o G4 inicial do loop)
]
# Contramelodia (flauta suave): duas notas de acorde por compasso, linha mais lenta abaixo da melodia.
COUNTER = {
    "C": [(0, 2, "E4"), (2, 2, "G4")], "G": [(0, 2, "D4"), (2, 2, "G4")], "Am": [(0, 2, "E4"), (2, 2, "C5")],
    "F": [(0, 2, "C5"), (2, 2, "A4")], "Em": [(0, 2, "B4"), (2, 2, "G4")],
}
DYN = [.82, .88, .88, .94, .95, 1.0, .95, 1.0, .9, .95, 1.0, 1.05, 1.0, 1.0, 1.0, 1.05]


class Mix:
    def __init__(self, n=N):
        self.n = n
        self.l = [0.0] * n
        self.r = [0.0] * n

    def put(self, tone, beat, gain, pan=0.0, wrap=True, jitter=0.0):
        s0 = int((beat * BEAT + jitter) * SR)
        gl, gr = pan_gains(pan)
        n = self.n
        for i, v in enumerate(tone):
            j = s0 + i
            if wrap:
                j %= n
            elif j >= n or j < 0:
                continue
            self.l[j] += v * gain * gl
            self.r[j] += v * gain * gr


def render_explore(profile):
    low = profile == "low"
    m = Mix()
    rng = random.Random(2026)
    for bar in range(BARS):
        b0 = bar * 4
        sym = PROG[bar]
        root = CHORDS[sym][0]
        d = DYN[bar] * (0.75 if low else 1.0)
        sect = bar // 4  # 0=A, 1=A', 2=B, 3=A''
        # pad: sustentado, mais presente na ponte
        for nme in triad(sym, 4):
            m.put(pad(nme, 4 * BEAT - 0.05), b0, (0.045 if sect != 2 else 0.06) * (1.25 if low else 1.0), rng.uniform(-.5, .5))
        # baixo: raiz e quinta (A); sincopado na ponte; so raiz no tema reduzido
        bn = root + "2"
        fifth = triad(sym, 2)[2]
        if low:
            m.put(bass(bn), b0, 0.18 * d)
        elif sect == 2:
            for bt, nm, g in ((0, bn, .26), (1.5, fifth, .17), (2.5, bn, .2), (3.5, fifth, .12)):
                m.put(bass(nm), b0 + bt, g * d, 0.0, True, rng.uniform(-.004, .004))
        else:
            for bt, nm, g in ((0, bn, .27), (2, fifth, .19)):
                m.put(bass(nm), b0 + bt, g * d, 0.0, True, rng.uniform(-.004, .004))
        # melodia (marimba). No tema reduzido, so notas longas, mais suaves.
        for bt, dur, nme in MELODY[bar]:
            if low and dur < 1:
                continue
            g = (0.21 if not low else 0.12) * d * rng.uniform(0.92, 1.06)
            jit = rng.uniform(-.005, .005)
            m.put(marimba(nme), b0 + bt, g, -0.15, True, jit)
            if sect == 1 and not low:  # A': dobra grave da marimba, "enche" a repeticao
                lo = nme[:-1] + str(int(nme[-1]) - 1)
                m.put(marimba(lo), b0 + bt, g * 0.38, 0.2, True, jit + 0.006)
            if sect == 3 and bt == 0 and not low:  # A'': sino suave no inicio do compasso
                m.put(bell(nme), b0 + bt, 0.055 * d, 0.45)
            if sect == 2 and not low:  # B: eco curto da melodia, mais aberto
                m.put(marimba(nme), b0 + bt + 0.75, g * 0.28, 0.6, True, jit)
        if low:
            if bar % 8 == 0:
                m.put(bell(triad(sym, 5)[0]), b0, 0.05, 0.4)
            continue
        # arpejo de pizzicato: leve em A' e A'', "contratempos" na ponte
        if sect in (1, 3):
            tri = triad(sym, 4)
            for k, nme in enumerate((tri[0], tri[2], tri[1], tri[2], tri[0], tri[2], tri[1], tri[2])):
                m.put(pluck(nme), b0 + k * 0.5 + 0.0, (0.05 if k % 2 else 0.065) * d, -0.55 + 0.1 * (k % 3), True, rng.uniform(-.004, .004))
        elif sect == 2:
            tri = triad(sym, 4)
            for bt in (0.5, 1.5, 2.5, 3.5):
                for nme in tri:
                    m.put(pluck(nme), b0 + bt, 0.035 * d, -0.4, True, rng.uniform(-.003, .006))
        # contramelodia da flauta a partir da segunda repeticao
        if sect >= 1:
            for bt, dur, nme in COUNTER[sym]:
                g = (0.075 if sect != 2 else 0.095) * d
                m.put(flute(nme, dur * BEAT * 0.95), b0 + bt, g, 0.35)
        # percussao leve: shaker em colcheias desde o compasso 3; claves desde o compasso 7
        if bar >= 2:
            for k in range(8):
                acc = 1.0 if k % 2 == 0 else 0.55
                if k == 7:
                    acc = 0.75
                m.put(shaker(acc if k % 2 else 1.0), b0 + k * 0.5 + (0.03 if k % 2 else 0.0), 0.05 * acc * d, 0.5 if k % 2 else -0.3, True, rng.uniform(-.003, .003))
        if bar >= 6:
            for bt in (0, 1.5, 3):
                m.put(clave(), b0 + bt, 0.055 * d, -0.35 if bt != 1.5 else 0.3)
    return m


def finish(m, name, lp_a=None):
    out = []
    for ch in (m.l, m.r):
        x = ch
        if lp_a:  # passa-baixa de 1 polo circular (aquece numa passada)
            prev = 0.0
            for v in x:
                prev += lp_a * (v - prev)
            y = []
            for v in x:
                prev += lp_a * (v - prev)
                y.append(prev)
            x = y
        out.append(x)
    return out


def render_discovery():
    """Sting de 5,4 s: Am - F - G -> C. Pergunta (E5 F5 G5 B5) e resposta (C6 sustentado). Sem loop."""
    n = int(SR * 5.4)
    m = Mix(n)
    notes = [(0, 1, "E5"), (1, 1, "F5"), (2, 1, "G5"), (3, 1, "B5"), (4, 3.5, "C6")]
    for bt, dur, nme in notes:
        m.put(marimba(nme), bt, 0.22, -0.1, False)
        m.put(bell(nme), bt, 0.05, 0.4, False)
    for bt, sym in ((0, "Am"), (2, "F"), (3, "G"), (4, "C")):
        dur = (2 if bt in (0, 2) else (1 if bt == 3 else 4)) * BEAT
        for nme in triad(sym, 4):
            m.put(pad(nme, dur), bt, 0.05, 0.0, False)
        m.put(bass(CHORDS[sym][0] + "2"), bt, 0.22, 0.0, False)
    m.put(bell("E6"), 4, 0.07, 0.3, False)
    m.put(bell("G6"), 4.15, 0.05, -0.3, False)
    m.put(flute("G4", 3.0 * BEAT), 4, 0.07, 0.3, False)
    # fim: queda suave de 1,2 s sobre a cauda
    k = int(SR * 1.5)
    for ch in (m.l, m.r):
        for i in range(k):
            ch[-1 - i] *= (i / k) ** 1.5
    return m


def main():
    full = {}
    lowm = render_explore("low")
    outs = {
        "theme_explore": (finish(render_explore("full"), "theme_explore", 0.55), True),
        "theme_explore_low": (finish(lowm, "theme_explore_low", 0.4), True),
        "theme_discovery": (finish(render_discovery(), "theme_discovery"), False),
    }
    for name, (chans, loop) in outs.items():
        path = os.path.join(AUDIO, "music", name + ".wav")
        m = finalize(path, SR, chans, PEAK_DB if name != "theme_explore_low" else -9.0)
        m.update(file="res://audio/music/%s.wav" % name, loop=loop, bpm=BPM, bars=BARS if loop else 2)
        full[name] = m
        print(name, m["duration_s"], "s peak", m["peak_dbfs"], "tp~", m["true_peak_est_dbfs"], "rms", m["rms_dbfs"], "seam", m["loop_seam_step"], "max_step", m["max_step"])
    merge_report("music", full)


if __name__ == "__main__":
    main()
