"""Efeitos sonoros do primeiro minuto (RB-04): mono 22,05 kHz 16 bits, sintetizados por script, deterministicos.
Pico de amostra -3 dBFS no arquivo (o nivel de mistura vem de gain_db no sfx_catalog)."""
import math, os, random, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from synthlib import *

SR = 22050
TWO_PI = 2 * math.pi
PEAK_DB = -3.0


def zeros(d):
    return [0.0] * int(SR * d)


def horn():
    """Buzina de barco: dois tons (A3 220 + C#4 277,2 = terca maior) em duas buzinadas, curta e longa, com
    ataque de 30 ms, leve tremolo, cauda de eco do porto. Harmonicos impares dominantes + par fraco."""
    out = zeros(3.6)

    def blast(t0, d, rel):
        ln = int(SR * (d + rel))
        seg = [0.0] * ln
        for f, a in ((220.0, 1.0), (277.2, 0.85)):
            for det in (0.9975, 1.0025):
                w = TWO_PI * f * det / SR
                for k in range(1, 12):
                    if f * k > 8000:
                        break
                    amp = a / k ** (1.1 if k % 2 else 1.9)
                    wk = w * k
                    for i in range(ln):
                        seg[i] += amp * math.sin(wk * i)
        for i in range(ln):
            t = i / SR
            e = min(1.0, t / 0.03) * (1.0 if t < d else math.exp(-6.0 * (t - d) / rel * 1.5))
            e *= 1 + 0.04 * math.sin(TWO_PI * 5.5 * t)
            seg[i] *= e
        seg = biquad(seg, "lp", 3200, SR)
        add_into(out, seg, int(t0 * SR))

    blast(0.0, 0.42, 0.25)
    blast(0.62, 1.15, 0.7)
    # eco do porto: duas repeticoes filtradas
    dry = list(out)
    lp = biquad(dry, "lp", 1400, SR)
    for dly, g in ((0.55, 0.22), (1.1, 0.10)):
        add_into(out, lp, int(dly * SR), g)
    return out[: int(SR * 3.4)]


def hull_bump():
    n = int(SR * 0.8)
    out = [0.0] * n
    ph = 0.0
    for i in range(n):
        t = i / SR
        f = 45 + 40 * math.exp(-18 * t)
        ph += TWO_PI * f / SR
        out[i] += 0.9 * math.sin(ph) * math.exp(-7 * t) * min(1.0, t / 0.002)
    rng = random.Random(5)
    nz = biquad(noise(rng, n), "lp", 420, SR)
    for i in range(n):
        t = i / SR
        out[i] += 2.2 * nz[i] * math.exp(-28 * t) * min(1.0, t / 0.001)
    for f, d, a in ((165, 11, 0.35), (298, 16, 0.2), (470, 22, 0.1)):  # madeira batendo no casco
        add_into(out, damped(n, SR, f, d, a), 0)
    # rangido curto de roce depois do toque
    rub = biquad(noise(rng, n), "bp", 320, SR, 3.0)
    for i in range(n):
        t = i / SR
        out[i] += 0.5 * rub[i] * (math.exp(-3 * max(0, t - 0.12)) if t > 0.12 else 0.0) * min(1.0, (t - 0.12) / 0.08 if t > 0.12 else 0.0) * (0.5 + 0.5 * math.sin(TWO_PI * 17 * t))
    return fade_edges(out, SR, 1, 40)


def crate_slide():
    rng = random.Random(9)
    n = int(SR * 1.1)
    base = biquad(noise(rng, n), "bp", 900, SR, 0.7)
    low = biquad(noise(rng, n), "lp", 260, SR)
    out = []
    rough = 0.0
    for i in range(n):
        t = i / SR
        rough += 0.02 * (rng.uniform(0, 1) - rough) + 0.0
        fric = 0.35 + 0.65 * abs(math.sin(TWO_PI * 11 * t + 1.3 * math.sin(TWO_PI * 3 * t)))
        env = min(1.0, t / 0.015) * (1.0 if t < 0.8 else math.exp(-9 * (t - 0.8)))
        out.append((base[i] * 0.9 + low[i] * 0.9) * fric * env)
    # batida seca de parada
    stop = 0.85
    add_into(out, damped(int(SR * 0.25), SR, 130, 22, 0.5), int(stop * SR))
    return fade_edges(out, SR, 2, 20)


STEPS = [  # (f_corpo, decaimento corpo, f_res madeira, freq. do clique, duracao s, ganho clique, semente)
    (96, 40, 310, 1900, 0.15, 0.9, 11),
    (118, 48, 385, 2300, 0.12, 1.0, 12),
    (84, 36, 270, 1500, 0.19, 0.8, 13),
    (132, 55, 420, 2700, 0.11, 1.1, 14),
    (104, 42, 340, 1700, 0.16, 0.85, 15),
    (90, 45, 295, 2100, 0.14, 1.0, 16),
]


def step(idx):
    f, dec, fr, fc, d, gc, seed = STEPS[idx]
    rng = random.Random(seed)
    n = int(SR * d)
    out = [0.0] * n
    ph = 0.0
    for i in range(n):  # corpo: pe pesando na tabua
        t = i / SR
        ph += TWO_PI * (f * (1 + 0.5 * math.exp(-60 * t))) / SR
        out[i] += math.sin(ph) * math.exp(-dec * t) * min(1.0, t / 0.002)
    add_into(out, damped(n, SR, fr, 38, 0.28, 0.0), 0)  # ressonancia da tabua
    add_into(out, damped(n, SR, fr * 1.9, 55, 0.12, 0.5), 0)
    clk = biquad(noise(rng, n), "bp", fc, SR, 1.2)  # solado: clique de ruido
    for i in range(n):
        t = i / SR
        out[i] += gc * 1.6 * clk[i] * math.exp(-170 * t) * min(1.0, t / 0.0006)
    return fade_edges(out, SR, 0.5, 15)


def creak_core(f0, d, seed, rope, tension=1.0):
    rng = random.Random(seed)
    n = int(SR * d)
    ph = 0.0
    src = []
    rate = rng.uniform(26, 48) * (1.4 if rope else 1.0)
    for i in range(n):
        t = i / SR
        f = f0 * (1 + 0.28 * tension * (t / d) + 0.04 * math.sin(TWO_PI * 6.5 * t))
        ph = (ph + f / SR) % 1.0
        stick = 1 if math.sin(TWO_PI * rate * t * (1 + 0.25 * math.sin(TWO_PI * 2.2 * t))) > -0.2 else 0.12
        src.append((2 * ph - 1) * stick)
    ff = (780, 2100) if rope else (480, 1250)
    y = [a + 0.7 * b for a, b in zip(biquad(src, "bp", ff[0], SR, 4.0), biquad(src, "bp", ff[1], SR, 5.0))]
    return [v * (min(1.0, i / (0.02 * SR))) * (math.sin(math.pi * i / n) ** 0.7) for i, v in enumerate(y)]


def rope_creak():
    return fade_edges(creak_core(330, 0.95, 21, True), SR, 3, 25)


def rope_tug():
    """Puxao: estalo grave de tensao + rangido que sobe. Para o futuro (segundo momento da ilha)."""
    n = int(SR * 0.9)
    out = creak_core(180, 0.9, 22, True, 1.6)
    rng = random.Random(23)
    thud = biquad(noise(rng, n), "lp", 300, SR)
    for i in range(int(SR * 0.2)):
        t = i / SR
        out[i] += 1.4 * thud[i] * math.exp(-22 * t) * min(1.0, t / 0.003)
    add_into(out, damped(n, SR, 70, 14, 0.6), 0)
    return fade_edges(out, SR, 1, 25)


def engine_loop():
    """Motor pequeno de 2 cilindros, 4 tempos, ~800 rpm: uma explosao por rotacao = 13,33 Hz. Loop de 3 s com
    40 pulsos exatos; variacao de amplitude periodica no loop. Pensado para pitch_scale 0,8 (parado) a ~2,4."""
    dur, pulses = 3.0, 40
    n = int(SR * dur)
    out = [0.0] * n
    rng = random.Random(31)
    per = n / pulses
    lump = [1.0, 0.82, 0.93, 0.76]  # irregularidade periodica (cada 4 pulsos)
    pl = int(SR * 0.11)
    pulse = []
    ph = 0.0
    nz = biquad(noise(rng, pl), "lp", 600, SR)
    for i in range(pl):
        t = i / SR
        ph += TWO_PI * (62 - 20 * min(1.0, t / 0.05)) / SR
        pulse.append((0.9 * math.sin(ph) + 0.7 * nz[i] + 0.35 * math.sin(2.02 * ph)) * math.exp(-34 * t) * min(1.0, t / 0.004))
    for k in range(pulses):
        add_into(out, pulse, int(k * per), lump[k % 4], True)
    # sopro mecanico e escape: ruido passa-baixa periodico por fusao
    xf = int(SR * 0.4)
    hiss = loopify(norm_rms(biquad(biquad(noise(rng, n + xf), "lp", 900, SR), "hp", 120, SR), 0.12), n, xf)
    out = [a + b for a, b in zip(out, hiss)]
    return biquad_circular(out, 2400)


def biquad_circular(x, fc):
    """Passa-baixa circular: aquece o filtro numa passada e usa a segunda (sem emenda)."""
    y = biquad(x + x, "lp", fc, SR)
    return y[len(x):]


def bell(n, f, amp=1.0, decay=5.0):
    out = [0.0] * n
    for k, a, d in ((1.0, 1.0, decay), (2.76, 0.35, decay * 1.6), (5.4, 0.12, decay * 2.5)):
        add_into(out, damped(n, SR, f * k, d, amp * a, 0.0, 2.0), 0)
    return out


def ui_confirm():
    out = zeros(0.32)
    add_into(out, bell(len(out), hz("C6"), 0.7, 16), 0)
    add_into(out, bell(len(out), hz("G6"), 0.8, 14), int(0.07 * SR))
    return fade_edges(out, SR, 0.5, 30)


def ui_move():
    out = zeros(0.09)
    add_into(out, damped(len(out), SR, 1320, 60, 0.8, 0.0, 1.0), 0)
    add_into(out, damped(len(out), SR, 2640, 90, 0.25, 0.0, 1.0), 0)
    return fade_edges(out, SR, 0.5, 10)


def clue_found():
    """Descoberta suave: dois tons ascendentes (E5 -> B5, quinta justa) com timbre de sino e cauda longa."""
    out = zeros(1.5)
    add_into(out, bell(len(out), hz("E5"), 0.8, 3.6), 0)
    add_into(out, bell(len(out), hz("B5"), 0.9, 3.0), int(0.16 * SR))
    add_into(out, bell(len(out), hz("E6"), 0.25, 4.5), int(0.16 * SR))
    return fade_edges(out, SR, 1.0, 120)


def notebook():
    """Rabisco curto de lapis: quatro tracos de ruido alto (2-6 kHz) com envelopes e pausas diferentes."""
    rng = random.Random(41)
    out = zeros(0.55)
    strokes = [(0.00, 0.11, 3200), (0.13, 0.09, 4100), (0.25, 0.12, 3600), (0.40, 0.10, 4500)]
    for t0, d, f in strokes:
        ln = int(SR * d)
        src = biquad(biquad(noise(rng, ln), "bp", f, SR, 1.0), "hp", 1800, SR)
        seg = [v * math.sin(math.pi * i / ln) ** 0.8 * (0.6 + 0.4 * math.sin(TWO_PI * 70 * i / SR)) for i, v in enumerate(src)]
        add_into(out, seg, int(t0 * SR))
    return fade_edges(out, SR, 1.5, 30)


# nome -> (funcao, tipo, bus, gain_db, loop, caption_key|None, descricao)
SFX = {
    "sfx_horn_boat": (horn, "oneshot", "Efeitos", 0.0, False, "audio.caption.horn_boat", "Buzina de barco, dois tons (A3 + C#4)."),
    "sfx_hull_bump": (hull_bump, "oneshot", "Efeitos", -2.0, False, "audio.caption.hull_bump", "Casco encostando no cais."),
    "sfx_crate_slide": (crate_slide, "oneshot", "Efeitos", -4.0, False, "audio.caption.crate_slide", "Caixa deslizando no conves."),
    "sfx_rope_creak": (rope_creak, "oneshot", "Efeitos", -6.0, False, "audio.caption.rope_creak", "Corda rangendo."),
    "sfx_rope_tug": (rope_tug, "oneshot", "Efeitos", -3.0, False, "audio.caption.rope_tug", "Puxao de corda (uso futuro)."),
    "sfx_engine_loop": (engine_loop, "loop", "Efeitos", -9.0, True, None, "Motor pequeno ~800 rpm; variar pitch_scale."),
    "sfx_ui_confirm": (ui_confirm, "ui", "Efeitos", -8.0, False, None, "Confirmacao de interface."),
    "sfx_ui_move": (ui_move, "ui", "Efeitos", -12.0, False, None, "Movimento de foco."),
    "sfx_clue_found": (clue_found, "oneshot", "Efeitos", -5.0, False, "audio.caption.clue_found", "Pista encontrada: dois tons ascendentes."),
    "sfx_notebook": (notebook, "oneshot", "Efeitos", -8.0, False, "audio.caption.notebook", "Rabisco de lapis."),
}
for _i in range(6):
    SFX["sfx_step_wood_%02d" % (_i + 1)] = (lambda i=_i: step(i), "step", "Efeitos", -8.0, False, None, "Passo em madeira, variacao %d." % (_i + 1))


def main():
    res = {}
    for name, (fn, kind, bus, gain, loop, cap, desc) in SFX.items():
        x = fn()
        path = os.path.join(AUDIO, "sfx", name + ".wav")
        m = finalize(path, SR, [x], PEAK_DB)
        m.update(file="res://audio/sfx/%s.wav" % name, type=kind, bus=bus, gain_db=gain, loop=loop, caption_key=cap, description=desc)
        res[name] = m
        print(name, m["duration_s"], "s peak", m["peak_dbfs"], "tp~", m["true_peak_est_dbfs"], "rms", m["rms_dbfs"], "lead", m["lead_silence_ms"], "ms", "seam", m["loop_seam_step"])
    merge_report("sfx", res)


if __name__ == "__main__":
    main()
