"""Esboco de TEMA INSTRUMENTAL ORIGINAL (composto por este script). Gera game/audio/music/theme_explore.wav e
theme_discovery.wav: estereo 44,1 kHz 16 bits, loop de 8 compassos 4/4 a 100 bpm (19,2 s), sem emenda audivel:
a renderizacao e CIRCULAR (a cauda das notas dobra sobre o inicio), entao a ultima amostra continua a primeira.
Notacao e acordes: ver README.md. Biblioteca padrao apenas.
"""
import math, os, random, sys
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, os.path.dirname(HERE))
from audio_measure import write_wav, measure
import json

SR = 44100
BPM = 100
BEAT = 60.0 / BPM
BARS = 8
N = int(round(SR * BEAT * 4 * BARS))
PEAK_DB = -6.0  # musica abaixo da voz (-3 dBFS)
NOTE = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def hz(name):
    """'C5' -> frequencia (A4 = 440). Aceita sustenido '#'."""
    p, o = name[0], int(name[-1])
    s = 1 if "#" in name else 0
    m = NOTE[p] + s + 12 * (o + 1)
    return 440.0 * 2 ** ((m - 69) / 12)


class Mix:
    def __init__(self):
        self.l = [0.0] * N
        self.r = [0.0] * N

    def add(self, start_beat, dur_s, f, amp, pan, harm, decay, attack=0.004, tail=1.2):
        """Parcial aditiva com envelope exponencial; dobra circularmente (loop)."""
        s0 = int(start_beat * BEAT * SR)
        length = int((dur_s + tail) * SR)
        gl, gr = amp * math.cos((pan + 1) * math.pi / 4), amp * math.sin((pan + 1) * math.pi / 4)
        for i in range(length):
            t = i / SR
            env = min(1.0, t / attack) * math.exp(-decay * t)
            if t > dur_s:
                env *= math.exp(-9.0 * (t - dur_s))
            if env < 1e-5:
                break
            v = 0.0
            for k, a in harm:
                v += a * math.sin(2 * math.pi * f * k * t)
            v *= env
            j = (s0 + i) % N
            self.l[j] += v * gl
            self.r[j] += v * gr

    def marimba(self, b, d, name, amp=0.22, pan=0.0):
        f = hz(name)
        self.add(b, d, f, amp, pan, [(1, 1.0), (4.0, 0.22)], 3.2, tail=0.6)  # corpo + parcial de barra (4x)

    def pluck(self, b, d, name, amp=0.2, pan=0.0):
        f = hz(name)
        self.add(b, d, f, amp, pan, [(1, 1.0), (2, 0.35), (3, 0.12)], 2.4, tail=0.6)

    def bass(self, b, d, name, amp=0.3):
        f = hz(name)
        self.add(b, d, f, amp, 0.0, [(1, 1.0), (2, 0.25)], 1.1, attack=0.01, tail=0.3)

    def pad(self, b, d, names, amp=0.05):
        for n_, name in enumerate(names):
            f = hz(name)
            for det, pan in ((0.997, -0.4), (1.003, 0.4)):
                self.add(b, d, f * det, amp, pan, [(1, 1.0), (2, 0.15)], 0.0, attack=0.6, tail=0.9)

    def hat(self, b, amp=0.02, rng=None):
        s0 = int(b * BEAT * SR)
        n = int(0.05 * SR)
        prev = 0.0
        for i in range(n):
            w = rng.uniform(-1, 1)
            prev = 0.6 * prev + 0.4 * w  # passa-baixa leve: sem degraus bruscos
            v = (w - prev) * amp * math.exp(-9.0 * i / n * 1.0)
            j = (s0 + i) % N
            self.l[j] += v * 0.8
            self.r[j] += v * 1.0

    def thump(self, b, amp=0.18):
        s0 = int(b * BEAT * SR)
        n = int(0.22 * SR)
        ph = 0.0
        for i in range(n):
            t = i / SR
            f = 50 + 70 * math.exp(-30 * t)
            ph += 2 * math.pi * f / SR
            v = amp * math.sin(ph) * math.exp(-14 * t) * min(1.0, t / 0.003)
            j = (s0 + i) % N
            self.l[j] += v
            self.r[j] += v


def chord(root, minor=False, octave=3):
    """Triade em nomes de nota a partir de uma fundamental ('C') -> [C, E, G] com oitavas."""
    names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
    i = names.index(root)
    iv = [0, 3 if minor else 4, 7]
    out = []
    for x in iv:
        k = i + x
        out.append(names[k % 12] + str(octave + k // 12))
    return out


# Progressoes (compasso a compasso). Melodia: lista de (batida_no_compasso, duracao_em_batidas, nota).
EXPLORE = {
    "chords": [("C", 0), ("G", 0), ("A", 1), ("F", 0), ("C", 0), ("G", 0), ("F", 0), ("G", 0)],
    "melody": [
        [(0, .5, "E5"), (.5, .5, "G5"), (1, 1, "C6"), (2, .5, "B5"), (2.5, .5, "G5"), (3, 1, "E5")],
        [(0, .5, "D5"), (.5, .5, "G5"), (1, 1, "B5"), (2, 1, "A5"), (3, 1, "G5")],
        [(0, .5, "C5"), (.5, .5, "E5"), (1, 1, "A5"), (2, .5, "G5"), (2.5, .5, "E5"), (3, 1, "C5")],
        [(0, .5, "C5"), (.5, .5, "F5"), (1, 1, "A5"), (2, 1, "G5"), (3, 1, "F5")],
        [(0, .5, "E5"), (.5, .5, "G5"), (1, 1, "C6"), (2, .5, "D6"), (2.5, .5, "C6"), (3, 1, "G5")],
        [(0, .5, "D5"), (.5, .5, "G5"), (1, 1, "B5"), (2, 1, "G5"), (3, 1, "D5")],
        [(0, .5, "C5"), (.5, .5, "F5"), (1, 1, "A5"), (2, .5, "C6"), (2.5, .5, "A5"), (3, 1, "F5")],
        [(0, 1, "D5"), (1, 1, "G5"), (2, 1, "B5"), (3, 1, "D6")],
    ],
}
# Descoberta: mais esparsa, modal (Lá menor) e resolve em Dó maior no ultimo compasso.
DISCOVERY = {
    "chords": [("A", 1), ("F", 0), ("C", 0), ("G", 0), ("A", 1), ("F", 0), ("G", 0), ("C", 0)],
    "melody": [
        [(0, 3, "E5")], [(0, 2, "F5"), (3, 1, "A5")], [(0, 3, "G5")], [(1, 2, "B5")],
        [(0, 2, "C6"), (2, 2, "B5")], [(0, 3, "A5")], [(0, 2, "D6"), (2, 2, "B5")], [(0, 4, "C6")],
    ],
}


def render(spec, name, busy):
    m = Mix()
    rng = random.Random(11)
    for bar in range(BARS):
        b0 = bar * 4
        root, minor = spec["chords"][bar]
        tri = chord(root, bool(minor), 3)
        m.bass(b0, 1.8 * BEAT, root + "2", 0.3 if busy else 0.24)
        if busy:
            m.bass(b0 + 2, 1.8 * BEAT, root + "2", 0.22)
            m.bass(b0 + 3.5, 0.4 * BEAT, tri[2].replace("3", "2"), 0.12)
        m.pad(b0, 4 * BEAT, chord(root, bool(minor), 4), 0.05 if busy else 0.075)
        for beat, dur, note in spec["melody"][bar]:
            m.marimba(b0 + beat, dur * BEAT, note, 0.2 if busy else 0.17, 0.0)
            if not busy:  # eco suave, mais "misterioso"
                m.marimba(b0 + beat + 1.5, dur * BEAT, note, 0.06, 0.5)
        if busy:
            for k, n_ in enumerate((tri[0], tri[1], tri[2], tri[1])):  # arpejo pluck em colcheias, abaixo da melodia
                m.pluck(b0 + k, 0.4 * BEAT, n_.replace("3", "4"), 0.06, -0.5)
            m.thump(b0)
            m.thump(b0 + 2)
            for k in range(8):
                m.hat(b0 + k * 0.5 + 0.25 if k % 2 else b0 + k * 0.5, 0.025 if k % 2 else 0.015, rng)
        else:
            if bar % 2 == 0:
                m.thump(b0, 0.1)
    # passa-baixa de 1 polo (~5 kHz), CIRCULAR: o estado aquece numa passada inteira antes da saida.
    out = []
    for ch in (m.l, m.r):
        a = 0.45
        prev = 0.0
        for v in ch:
            prev += a * (v - prev)
        y = []
        for v in ch:
            prev += a * (v - prev)
            y.append(prev)
        out.append(y)
    pk = max(max(abs(v) for v in c) for c in out)
    g = 10 ** (PEAK_DB / 20) / pk
    out = [[v * g for v in c] for c in out]
    path = os.path.join(ROOT, "game", "audio", "music", name + ".wav")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    write_wav(path, SR, out)
    res = measure(out, SR)
    res["loop_seam_step"] = [round(abs(c[0] - c[-1]), 5) for c in out]
    res["max_adjacent_step"] = round(max(max(abs(c[i + 1] - c[i]) for i in range(0, N - 1, 7)) for c in out), 5)
    res["bpm"], res["bars"] = BPM, BARS
    return res


def main():
    rp = os.path.join(os.path.dirname(HERE), "report.json")
    full = json.load(open(rp)) if os.path.exists(rp) else {}
    full["music"] = {"theme_explore": render(EXPLORE, "theme_explore", True), "theme_discovery": render(DISCOVERY, "theme_discovery", False)}
    json.dump(full, open(rp, "w", encoding="utf-8"), indent=2)
    for k, v in full["music"].items():
        print(k, v)


if __name__ == "__main__":
    main()

