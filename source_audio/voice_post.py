"""Pos-processamento das falas: corte de silencio, filtro de radio (so a fala do radio), normalizacao a -3 dBFS,
fade anti-clique e medicao. Biblioteca padrao apenas. Escreve game/audio/voice/*.wav, game/audio/voice_catalog.json
e source_audio/report.json (secao "voices"; a musica acrescenta "music").

Nota: dBFS de amostra NAO e dBTP. O pico verdadeiro e ESTIMADO por sobreamostragem 4x (sinc com janela de Hann,
16 pontos por lado); e uma estimativa, nao medidor ITU-R BS.1770 certificado.
"""
import json, math, os, platform, random, struct, sys, wave
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
from audio_measure import read_wav, write_wav, measure

TARGET_DB = -3.0
LEAD_MS, TAIL_MS, FADE_MS = 40, 80, 6
SILENCE_DB = -45.0


def trim(x, sr):
    thr = 10 ** (SILENCE_DB / 20)
    a = next((i for i, v in enumerate(x) if abs(v) > thr), 0)
    b = len(x) - next((i for i, v in enumerate(reversed(x)) if abs(v) > thr), 0)
    a = max(0, a - int(sr * LEAD_MS / 1000))
    b = min(len(x), b + int(sr * TAIL_MS / 1000))
    return x[a:b]


def fade(x, sr, ms=FADE_MS):
    n = min(int(sr * ms / 1000), len(x) // 2)
    for i in range(n):
        g = i / n
        x[i] *= g
        x[-1 - i] *= g
    return x


def biquad(x, kind, f0, sr, q=0.7071):
    w = 2 * math.pi * f0 / sr
    al = math.sin(w) / (2 * q)
    c = math.cos(w)
    if kind == "lp":
        b0, b1, b2 = (1 - c) / 2, 1 - c, (1 - c) / 2
    else:
        b0, b1, b2 = (1 + c) / 2, -(1 + c), (1 + c) / 2
    a0, a1, a2 = 1 + al, -2 * c, 1 - al
    b0, b1, b2, a1, a2 = b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0
    y = []
    x1 = x2 = y1 = y2 = 0.0
    for v in x:
        o = b0 * v + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2, x1, y2, y1 = x1, v, y1, o
        y.append(o)
    return y


def radio(x, sr):
    rng = random.Random(7)
    # passa-faixa ~300-3400 Hz (2 biquads Butterworth por borda)
    for _ in range(2):
        x = biquad(x, "hp", 300, sr)
        x = biquad(x, "lp", 3400, sr)
    pk = max(abs(v) for v in x) or 1.0
    x = [v / pk for v in x]
    # saturacao suave
    drive = 2.2
    x = [math.tanh(drive * v) / math.tanh(drive) for v in x]
    # ruido de fundo baixo, passa-faixa (~ -34 dB do pico da fala)
    noise = [rng.uniform(-1, 1) for _ in x]
    noise = biquad(biquad(noise, "hp", 400, sr), "lp", 3000, sr)
    npk = max(abs(v) for v in noise) or 1.0
    x = [v + 0.02 * n / npk for v, n in zip(x, noise)]
    # estalos de squelch: rajada curta de ruido com decaimento, na abertura e no fechamento
    def click(level):
        n = int(sr * 0.018)
        return [level * rng.uniform(-1, 1) * math.exp(-5.0 * i / n) for i in range(n)]
    pad = int(sr * 0.03)
    x = click(0.35) + [0.0] * 0 + x + [0.0] * 0 + click(0.28)
    return x


def true_peak_ok(x):
    return measure(x)


def process(line, voice_cfg):
    sr, x = read_wav(os.path.join(HERE, "takes", line["file"] + ".wav"))
    x = trim(x, sr)
    if line.get("radio"):
        x = radio(x, sr)
    fade(x, sr)
    # RB-04: nivel consistente entre falas (RMS alvo -19 dBFS), limitado ao pico de -3 dBFS.
    pk = max(abs(v) for v in x)
    rms = math.sqrt(sum(v * v for v in x) / len(x))
    g = min(10 ** (TARGET_DB / 20) / pk, 10 ** (-19.0 / 20) / rms)
    x = [v * g for v in x]
    out = os.path.join(ROOT, "game", "audio", "voice", line["file"] + ".wav")
    write_wav(out, sr, [x])
    m = measure(x, sr)
    m["lead_silence_ms"] = lead_silence_ms(x, sr)
    return out, sr, m


def lead_silence_ms(x, sr, db=-40.0):
    thr = 10 ** (db / 20)
    n = next((i for i, v in enumerate(x) if abs(v) > thr), len(x))
    return round(1000 * n / sr, 1)


def main():
    cfg = json.load(open(os.path.join(HERE, "lines.json"), encoding="utf-8"))
    tool = "Windows System.Speech (SAPI) + source_audio/voice_post.py"
    cat, rep = [], {}
    for l in cfg["lines"]:
        v = cfg["voices"][l["voice"]]
        out, sr, m = process(l, v)
        rel = "res://audio/voice/" + l["file"] + ".wav"
        cat.append({
            "id": l["id"], "character": l.get("character", v["character"]), "intent": l["intent"],
            "language": "pt_BR", "subtitle": l["key"], "file": rel,
            "duration": m["duration_s"], "peak_dbfs": m["peak_dbfs"], "status": "provisorio",
            "tool": tool, "voice": v["sapi"], "direction": v["direction"],
        })
        rep[l["id"]] = dict(m, file=rel, sample_rate=sr, radio_filter=bool(l.get("radio")))
    json.dump({"version": 1, "lines": cat}, open(os.path.join(ROOT, "game", "audio", "voice_catalog.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=2)
    rp = os.path.join(HERE, "report.json")
    full = json.load(open(rp)) if os.path.exists(rp) else {}
    full["voices"] = rep
    full["note"] = "dBFS de amostra nao e dBTP; true_peak_est_dbfs e estimativa por sobreamostragem 4x."
    json.dump(full, open(rp, "w", encoding="utf-8"), indent=2)
    for k, m in rep.items():
        print(k, m["duration_s"], "s peak", m["peak_dbfs"], "tp~", m["true_peak_est_dbfs"], "rms", m["rms_dbfs"], "lead", m["lead_silence_ms"], "ms")


if __name__ == "__main__":
    main()
