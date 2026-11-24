"""Biblioteca de sintese do projeto (biblioteca padrao apenas). Tudo e original, gerado por script, deterministico
por semente. Amostras em float [-1, 1]; escrita 16 bits via audio_measure."""
import json, math, os, random, sys
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
from audio_measure import write_wav, measure, db

REPORT = os.path.join(HERE, "report.json")
AUDIO = os.path.join(ROOT, "game", "audio")
NOTE = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def hz(name):
    """'C#5' -> Hz (A4 = 440)."""
    s = 1 if "#" in name else (-1 if "b" in name[1:-1] else 0)
    return 440.0 * 2 ** ((NOTE[name[0]] + s + 12 * (int(name[-1]) + 1) - 69) / 12)


def biquad(x, kind, f0, sr, q=0.7071):
    """kind: lp, hp, bp (ganho de pico 0 dB). Estado inicial zero."""
    w = 2 * math.pi * f0 / sr
    al = math.sin(w) / (2 * q)
    c = math.cos(w)
    if kind == "lp":
        b0, b1, b2 = (1 - c) / 2, 1 - c, (1 - c) / 2
    elif kind == "hp":
        b0, b1, b2 = (1 + c) / 2, -(1 + c), (1 + c) / 2
    else:
        b0, b1, b2 = al, 0.0, -al
    a0, a1, a2 = 1 + al, -2 * c, 1 - al
    b0, b1, b2, a1, a2 = b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0
    y = []
    x1 = x2 = y1 = y2 = 0.0
    for v in x:
        o = b0 * v + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2, x1, y2, y1 = x1, v, y1, o
        y.append(o)
    return y


def noise(rng, n):
    return [rng.uniform(-1, 1) for _ in range(n)]


def rms(x):
    return math.sqrt(sum(v * v for v in x) / max(1, len(x))) or 1.0


def norm_rms(x, target=1.0):
    g = target / rms(x)
    return [v * g for v in x]


def loopify(x, n, xf):
    """x tem n + xf amostras; devolve n amostras que fecham em loop: a cauda extra (n..n+xf) funde (potencia igual)
    com o inicio. out[0] == x[n], continuacao natural de x[n-1]."""
    out = x[:n]
    for i in range(xf):
        a = i / xf
        out[i] = x[i] * math.sin(a * math.pi / 2) + x[n + i] * math.cos(a * math.pi / 2)
    return out


def pan_gains(p):
    """p em [-1, 1] -> (gl, gr), lei de potencia constante."""
    return math.cos((p + 1) * math.pi / 4), math.sin((p + 1) * math.pi / 4)


def peak(chans):
    return max(max(abs(v) for v in c) for c in chans)


def fade_edges(x, sr, in_ms=2.0, out_ms=8.0):
    a = int(sr * in_ms / 1000)
    b = int(sr * out_ms / 1000)
    for i in range(min(a, len(x))):
        x[i] *= i / a
    for i in range(min(b, len(x))):
        x[-1 - i] *= i / b
    return x


def finalize(path, sr, chans, peak_db):
    """Normaliza ao pico alvo (dBFS de amostra), escreve o WAV e devolve as medidas."""
    g = 10 ** (peak_db / 20) / peak(chans)
    chans = [[v * g for v in c] for c in chans]
    os.makedirs(os.path.dirname(path), exist_ok=True)
    write_wav(path, sr, chans)
    m = measure(chans, sr)
    m["sample_rate"] = sr
    m["channels"] = len(chans)
    thr = 10 ** (-40 / 20)
    n = next((i for i, v in enumerate(chans[0]) if abs(v) > thr), len(chans[0]))
    m["lead_silence_ms"] = round(1000 * n / sr, 1)
    m["loop_seam_step"] = round(max(abs(c[0] - c[-1]) for c in chans), 5)
    m["max_step"] = round(max(max(abs(c[i + 1] - c[i]) for i in range(len(c) - 1)) for c in chans), 5)
    return m


def merge_report(section, data):
    full = json.load(open(REPORT, encoding="utf-8")) if os.path.exists(REPORT) else {}
    full.setdefault(section, {}).update(data)
    json.dump(full, open(REPORT, "w", encoding="utf-8"), indent=2, ensure_ascii=False)


class Env:
    """Envelope ADSR-exponencial simples por amostra: a * (1-exp) ... usado por instrumentos."""


def damped(n, sr, f, decay, amp=1.0, phase=0.0, attack_ms=1.0):
    """Senoide amortecida com ataque curto (sem clique)."""
    w = 2 * math.pi * f / sr
    att = max(1, int(sr * attack_ms / 1000))
    out = []
    for i in range(n):
        e = math.exp(-decay * i / sr) * (i / att if i < att else 1.0)
        out.append(amp * e * math.sin(w * i + phase))
    return out


def add_into(dst, src, start, gain=1.0, wrap=False):
    n = len(dst)
    if wrap:
        for i, v in enumerate(src):
            dst[(start + i) % n] += v * gain
    else:
        for i, v in enumerate(src):
            j = start + i
            if 0 <= j < n:
                dst[j] += v * gain
