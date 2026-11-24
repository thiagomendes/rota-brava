"""Mede o audio embutido num AVI do Movie Maker da Godot (PCM 16 bits), em Python puro.

Uso: python tools/measure_video_audio.py captures/ep01-playthrough.avi [--json saida.json]

Reporta: formato, duracao, pico de amostra (dBFS), pico verdadeiro estimado (sobreamostragem 4x por
interpolacao cubica nos trechos mais altos), RMS global, e por segundo (RMS e pico) com os trechos
silenciosos. NAO substitui audicao: so mede nivel, nao timbre, pronuncia nem mixagem percebida.
"""
import json
import math
import struct
import sys


def read_avi_audio(path):
    with open(path, "rb") as f:
        data = f.read()
    if data[:4] != b"RIFF" or data[8:12] != b"AVI ":
        raise SystemExit("Nao e um AVI.")
    channels = rate = bits = 0
    # formato do fluxo de audio: strf com WAVEFORMATEX PCM (wFormatTag == 1) depois de um strh 'auds'
    pos = 0
    while True:
        i = data.find(b"auds", pos)
        if i < 0:
            break
        j = data.find(b"strf", i)
        size = struct.unpack_from("<I", data, j + 4)[0]
        tag, ch, sr, _avg, _align, bps = struct.unpack_from("<HHIIHH", data, j + 8)
        if tag == 1:
            channels, rate, bits = ch, sr, bps
            break
        pos = i + 4
    if not channels:
        raise SystemExit("AVI sem fluxo de audio PCM.")
    chunks = []
    i = data.find(b"movi")
    end = len(data)
    p = i + 4
    while p + 8 <= end:
        cid = data[p:p + 4]
        size = struct.unpack_from("<I", data, p + 4)[0]
        if cid == b"LIST":
            p += 12
            continue
        if cid.endswith(b"wb"):
            chunks.append(data[p + 8:p + 8 + size])
        p += 8 + size + (size & 1)
    pcm = b"".join(chunks)
    n = len(pcm) // 2
    samples = struct.unpack("<%dh" % n, pcm[: n * 2])
    return samples, channels, rate, bits


def db(x):
    return -200.0 if x <= 0 else 20.0 * math.log10(x)


def true_peak_estimate(samples, channels, top=400):
    """Pico verdadeiro estimado: interpola 4x (Catmull-Rom) em torno das amostras de maior modulo."""
    # Varre TODAS as amostras e guarda as que ficam a menos de ~2 dB do pico de amostra: o pico verdadeiro
    # so pode superar o de amostra perto dessas posicoes.
    peak_int = max(abs(s) for s in samples) if samples else 0
    threshold = int(peak_int * 0.79)
    idx = [k for k, s in enumerate(samples) if abs(s) >= threshold]
    if len(idx) > top * 5:
        idx = sorted(idx, key=lambda k: -abs(samples[k]))[: top * 5]
    best = 0.0
    for k in idx:
        ch = k % channels
        pts = [samples[k + (t - 1) * channels] if 0 <= k + (t - 1) * channels < len(samples) else 0 for t in range(-1, 3)]
        p0, p1, p2, p3 = pts
        for s in (0.25, 0.5, 0.75):
            v = 0.5 * ((2 * p1) + (-p0 + p2) * s + (2 * p0 - 5 * p1 + 4 * p2 - p3) * s * s + (-p0 + 3 * p1 - 3 * p2 + p3) * s ** 3)
            best = max(best, abs(v))
        best = max(best, abs(p1))
    return best / 32768.0


def main():
    if len(sys.argv) < 2:
        raise SystemExit(__doc__)
    path = sys.argv[1]
    samples, ch, rate, bits = read_avi_audio(path)
    frames = len(samples) // ch
    dur = frames / rate
    peak = max(abs(s) for s in samples) / 32768.0 if samples else 0.0
    rms = math.sqrt(sum(s * s for s in samples) / max(len(samples), 1)) / 32768.0
    tp = true_peak_estimate(samples, ch)
    per_sec = []
    win = rate * ch
    for s in range(int(dur)):
        seg = samples[s * win:(s + 1) * win]
        if not seg:
            break
        sp = max(abs(x) for x in seg) / 32768.0
        sr = math.sqrt(sum(x * x for x in seg) / len(seg)) / 32768.0
        per_sec.append((s, round(db(sr), 1), round(db(sp), 1)))
    quiet = [s for s, r, _p in per_sec if r < -60.0]
    report = {
        "file": path, "channels": ch, "rate": rate, "bits": bits, "duration_s": round(dur, 2),
        "sample_peak_dbfs": round(db(peak), 2), "true_peak_estimate_dbfs": round(db(tp), 2),
        "rms_dbfs": round(db(rms), 2), "silent_seconds": quiet,
        "per_second": per_sec,
        "note": "Medicao de nivel apenas. Pico verdadeiro por interpolacao cubica 4x (estimativa); nao e medidor BS.1770.",
    }
    print("formato: %d canais, %d Hz, %d bits; duracao %.1f s" % (ch, rate, bits, dur))
    print("pico de amostra: %.2f dBFS | pico verdadeiro estimado: %.2f dBFS | RMS: %.2f dBFS" % (db(peak), db(tp), db(rms)))
    print("segundos silenciosos (RMS < -60 dBFS): %d de %d %s" % (len(quiet), len(per_sec), quiet[:20]))
    if "--json" in sys.argv:
        out = sys.argv[sys.argv.index("--json") + 1]
        with open(out, "w", encoding="utf-8") as f:
            json.dump(report, f, ensure_ascii=False, indent=1)
        print("relatorio:", out)


if __name__ == "__main__":
    main()
