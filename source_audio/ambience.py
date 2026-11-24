"""Loops de ambiente do cais (RB-04). Sintese por ruido filtrado e eventos aleatorios deterministicos por semente.
Cada loop e renderizado de forma circular: modulacoes com numero inteiro de ciclos no loop, eventos com cauda dobrada
no inicio e base de ruido com fusao de potencia igual na emenda. Biblioteca padrao apenas."""
import math, os, random, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from synthlib import *

TWO_PI = 2 * math.pi
PEAK_DB = -6.0


def lfo(n_total, sr, dur, cycles, phase):
    """Senoide com `cycles` ciclos exatos em `dur` segundos (periodica no loop)."""
    w = TWO_PI * cycles / dur / sr
    return [math.sin(w * i + phase) for i in range(n_total)]


def water(sr=44100, dur=20.0, seed=101):
    rng = random.Random(seed)
    n = int(sr * dur)
    xf = int(sr * 1.5)
    chans = []
    swell = [0.55 + 0.2 * a + 0.15 * b for a, b in zip(lfo(n + xf, sr, dur, 2, 0.3), lfo(n + xf, sr, dur, 5, 1.7))]
    for ch in range(2):
        base = noise(rng, n + xf)
        low = biquad(biquad(base, "lp", 520, sr), "lp", 520, sr)
        mid = biquad(noise(rng, n + xf), "bp", 1300, sr, 0.8)
        low, mid = norm_rms(low), norm_rms(mid)
        wob = lfo(n + xf, sr, dur, 7 + ch, 0.9 * ch)  # filtro "abre e fecha" lento: mistura entre grave e medio
        x = [(0.9 * lo + (0.25 + 0.2 * w) * mi) * s for lo, mi, w, s in zip(low, mid, wob, swell)]
        chans.append(loopify(x, n, xf))
    # batidas de agua (slaps) no cais e glugs nas estacas: eventos circulares
    ev = [[0.0] * n, [0.0] * n]
    for _ in range(46):
        t0 = rng.uniform(0, dur)
        f = rng.uniform(450, 1800)
        d = rng.uniform(0.10, 0.34)
        a = rng.uniform(0.15, 0.55)
        ln = int(sr * d * 3)
        src = biquad(noise(rng, ln), "bp", f, sr, rng.uniform(0.7, 2.0))
        env = [math.exp(-7.0 / d * i / sr) * min(1.0, i / (0.004 * sr)) for i in range(ln)]
        src = [s * e * a * 3 for s, e in zip(src, env)]
        gl, gr = pan_gains(rng.uniform(-0.9, 0.9))
        add_into(ev[0], src, int(t0 * sr), gl * 1.2, True)
        add_into(ev[1], src, int(t0 * sr), gr * 1.2, True)
    for _ in range(16):
        t0 = rng.uniform(0, dur)
        f0 = rng.uniform(180, 320)
        d = rng.uniform(0.10, 0.22)
        ln = int(sr * d)
        ph = 0.0
        g = []
        for i in range(ln):
            t = i / sr
            ph += TWO_PI * f0 * (1 + 1.6 * t / d) / sr  # glug: sobe de tom rapidamente
            g.append(0.22 * math.sin(ph) * math.sin(math.pi * i / ln) ** 2)
        gl, gr = pan_gains(rng.uniform(-1, 1))
        add_into(ev[0], g, int(t0 * sr), gl, True)
        add_into(ev[1], g, int(t0 * sr), gr, True)
    # a base tem RMS ~ 0.55; eventos entram relativos
    chans = [[a * 0.35 + b * 0.5 for a, b in zip(c, e)] for c, e in zip(chans, ev)]
    return sr, chans


def wind(sr=22050, dur=24.0, seed=202):
    rng = random.Random(seed)
    n = int(sr * dur)
    xf = int(sr * 2.0)
    nt = n + xf
    g1 = lfo(nt, sr, dur, 3, 0.4)
    g2 = lfo(nt, sr, dur, 7, 2.0)
    g3 = lfo(nt, sr, dur, 1, 0.0)
    gust = [max(0.0, 0.5 * a + 0.3 * b + 0.35 * c + 0.1) ** 1.5 for a, b, c in zip(g1, g2, g3)]
    chans = []
    for ch in range(2):
        x = noise(rng, nt)
        y1 = y2 = 0.0
        out = []
        for v, g in zip(x, gust):
            a = 0.012 + 0.07 * g  # passa-baixa de 1 polo com corte variavel: rajada abre o brilho
            y1 += a * (v - y1)
            y2 += a * (y1 - y2)
            out.append(y2)
        out = norm_rms(out)
        whistle = norm_rms(biquad(noise(rng, nt), "bp", 780 + 90 * ch, sr, 6.0))
        x = [(0.25 + 0.75 * g) * o + 0.10 * g * g * w for o, w, g in zip(out, whistle, gust)]
        chans.append(loopify(x, n, xf))
    return sr, chans


def _creak(sr, rng, f0, d, rope=False):
    ln = int(sr * d)
    ph = 0.0
    src = []
    sl = rng.uniform(0.6, 1.5)
    rate = rng.uniform(22, 60)
    for i in range(ln):
        t = i / sr
        f = f0 * (1 + 0.18 * math.sin(TWO_PI * rng.uniform(0.0, 0.0) + t * 5.0) + 0.25 * (t / d) * sl)
        ph = (ph + f / sr) % 1.0
        saw = 2 * ph - 1
        stick = 0.55 + 0.45 * (1 if math.sin(TWO_PI * rate * t * (1 + 0.2 * math.sin(7 * t))) > 0 else 0.15)
        src.append(saw * stick)
    ff = (420, 1100) if not rope else (700, 1900)
    y = [a + 0.7 * b for a, b in zip(biquad(src, "bp", ff[0], sr, 4.0), biquad(src, "bp", ff[1], sr, 5.0))]
    env = [math.sin(math.pi * (i / ln)) ** 1.5 for i in range(ln)]
    return [a * e for a, e in zip(y, env)]


def creaks(sr=22050, dur=26.0, seed=303):
    rng = random.Random(seed)
    n = int(sr * dur)
    chans = [[0.0] * n, [0.0] * n]
    slots = [1.5 + k * 3.7 + rng.uniform(-0.8, 0.8) for k in range(7)]  # esparsos: ~um a cada 3,7 s
    for k, t0 in enumerate(slots):
        rope = k % 3 == 2
        f0 = rng.uniform(260, 420) if rope else rng.uniform(85, 190)
        c = _creak(sr, rng, f0, rng.uniform(0.35, 0.8) if rope else rng.uniform(0.5, 1.3), rope)
        c = norm_rms(c, 0.25 if rope else 0.3)
        gl, gr = pan_gains(rng.uniform(-0.8, 0.8))
        add_into(chans[0], c, int(t0 * sr), gl, True)
        add_into(chans[1], c, int(t0 * sr), gr, True)
    # cama quase inaudivel de madeira assentando (nunca silencio digital)
    bed = norm_rms(biquad(biquad(noise(rng, n + sr), "lp", 160, sr), "lp", 160, sr), 0.012)
    bed = loopify(bed, n, sr)
    return sr, [[a + b for a, b in zip(c, bed)] for c in chans]


def _gull_call(sr, rng, f_start, syll):
    out = []
    for s in range(syll):
        d = rng.uniform(0.22, 0.42) * (1.25 if s == syll - 1 else 1.0)
        ln = int(sr * d)
        ph = 0.0
        seg = []
        base = f_start * (1 - 0.06 * s)
        for i in range(ln):
            u = i / ln
            f = base * (0.62 + 1.0 * math.sin(math.pi * min(1.0, u * 1.35)) ** 0.8 - 0.25 * u)
            f *= 1 + 0.025 * math.sin(TWO_PI * 38 * i / sr) + rng.uniform(-0.004, 0.004)
            ph += TWO_PI * f / sr
            v = 0.0
            k = 1
            while f * k < 6500:
                fk = f * k
                w = math.exp(-((fk - 1700) / 800) ** 2) + 0.55 * math.exp(-((fk - 3300) / 1000) ** 2) + 0.05
                v += w / k ** 0.6 * math.sin(k * ph)
                k += 1
            env = min(1.0, i / (0.025 * sr)) * math.exp(-2.6 * u) * min(1.0, (ln - i) / (0.03 * sr))
            seg.append(v * env)
        out += seg + [0.0] * int(sr * rng.uniform(0.08, 0.14))
    return out


def gulls(sr=22050, dur=28.0, seed=404):
    rng = random.Random(seed)
    n = int(sr * dur)
    chans = [[0.0] * n, [0.0] * n]
    for t0 in (2.2, 8.9, 16.0, 22.1):
        c = _gull_call(sr, rng, rng.uniform(1050, 1350), rng.choice((2, 3, 4)))
        c = biquad(biquad(c, "lp", 3600, sr), "hp", 500, sr)  # distancia: sem graves nem agudos
        c = norm_rms(c, 0.2)
        # ecos curtos de espaco aberto
        echoed = c + [0.0] * int(sr * 1.0)
        for dly, g in ((0.29, 0.35), (0.63, 0.18)):
            k = int(sr * dly)
            for i, v in enumerate(c):
                echoed[i + k] += v * g
        pan = rng.uniform(-0.8, 0.8)
        gl, gr = pan_gains(pan)
        add_into(chans[0], echoed, int(t0 * sr), gl, True)
        add_into(chans[1], echoed, int(t0 * sr), gr, True)
    bed = loopify(norm_rms(biquad(noise(rng, n + sr), "bp", 2400, sr, 0.5), 0.01), n, sr)
    return sr, [[a + b for a, b in zip(c, bed)] for c in chans]


AMBIENCE = {
    "amb_dock_water": (water, 6.0, -4.0, "Agua batendo no cais e nas estacas, ondulacao lenta."),
    "amb_wind_light": (wind, 6.0, -9.0, "Vento leve com rajadas suaves."),
    "amb_dock_creaks": (creaks, 6.0, -6.0, "Rangidos de madeira e cordas, esparsos (semente 303)."),
    "amb_gulls_far": (gulls, 6.0, -12.0, "Gaivotas distantes e esparsas (sintese formantica)."),
}


def main(only=None):
    res = {}
    for name, (fn, _, gain, desc) in AMBIENCE.items():
        sr, chans = fn()
        path = os.path.join(AUDIO, "ambience", name + ".wav")
        m = finalize(path, sr, chans, PEAK_DB)
        m.update(file="res://audio/ambience/%s.wav" % name, gain_db=gain, description=desc)
        res[name] = m
        print(name, m["duration_s"], "s peak", m["peak_dbfs"], "tp~", m["true_peak_est_dbfs"], "rms", m["rms_dbfs"], "seam", m["loop_seam_step"], "max_step", m["max_step"])
    merge_report("ambience", res)


if __name__ == "__main__":
    main()
