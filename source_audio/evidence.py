"""Evidencia MEDIDA (nao auditiva): envelope RMS e espectro (FFT radix-2 propria, janela de Hann) da buzina e de
um passo, em PNG (zlib da biblioteca padrao) e texto, em captures/rb-04/audio/ (fora do Git)."""
import array, cmath, math, os, struct, sys, wave, zlib
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
from audio_measure import read_wav

OUT = os.path.join(ROOT, "captures", "rb-04", "audio")
FILES = [("sfx_horn_boat", "audio/sfx/sfx_horn_boat.wav"), ("sfx_step_wood_01", "audio/sfx/sfx_step_wood_01.wav"), ("sfx_hull_bump", "audio/sfx/sfx_hull_bump.wav")]


def fft(x):
    n = len(x)
    if n == 1:
        return x
    ev, od = fft(x[0::2]), fft(x[1::2])
    t = [cmath.exp(-2j * math.pi * k / n) * od[k] for k in range(n // 2)]
    return [ev[k] + t[k] for k in range(n // 2)] + [ev[k] - t[k] for k in range(n // 2)]


def spectrum(x, sr, size=4096):
    seg = x[:size] + [0.0] * max(0, size - len(x))
    if len(x) > size:  # janela de maior energia
        best, bi = -1, 0
        for i in range(0, len(x) - size, size // 2):
            e = sum(v * v for v in x[i:i + size])
            if e > best:
                best, bi = e, i
        seg = x[bi:bi + size]
    w = [v * (0.5 - 0.5 * math.cos(2 * math.pi * i / (size - 1))) for i, v in enumerate(seg)]
    f = fft([complex(v) for v in w])
    mag = [abs(f[k]) / (size / 4) for k in range(size // 2)]
    return [(k * sr / size, 20 * math.log10(m + 1e-9)) for k, m in enumerate(mag)]


def png(path, w, h, px):
    raw = b"".join(b"\x00" + bytes(px[y * w * 3:(y + 1) * w * 3]) for y in range(h))
    def chunk(t, d):
        c = struct.pack(">I", len(d)) + t + d
        return c + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)
    open(path, "wb").write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))


def plot(path, x, sr, title):
    W, H = 900, 520
    px = bytearray([250] * (W * H * 3))

    def line(x0, y0, x1, y1, col):
        steps = int(max(abs(x1 - x0), abs(y1 - y0), 1))
        for s in range(steps + 1):
            xx = int(x0 + (x1 - x0) * s / steps)
            yy = int(y0 + (y1 - y0) * s / steps)
            if 0 <= xx < W and 0 <= yy < H:
                i = (yy * W + xx) * 3
                px[i:i + 3] = bytes(col)
    # envelope: RMS em janelas de 5 ms, em dBFS (-80..0), parte de cima
    win = max(1, int(sr * 0.005))
    env = [20 * math.log10(math.sqrt(sum(v * v for v in x[i:i + win]) / win) + 1e-6) for i in range(0, len(x) - win, win)]
    top0, top1 = 20, 230
    for g in (0, -20, -40, -60, -80):
        y = top0 + (0 - g) / 80 * (top1 - top0)
        line(40, y, W - 10, y, (215, 215, 215))
    pts = [(40 + i / max(1, len(env) - 1) * (W - 50), top0 + min(80, max(0, -e)) / 80 * (top1 - top0)) for i, e in enumerate(env)]
    for a, b in zip(pts, pts[1:]):
        line(a[0], a[1], b[0], b[1], (20, 90, 200))
    # espectro: 0..sr/2 (eixo log 50 Hz..10 kHz), -100..0 dB
    sp = spectrum(x, sr)
    b0, b1 = 270, 500
    for g in (0, -20, -40, -60, -80):
        y = b0 + (0 - g) / 90 * (b1 - b0)
        line(40, y, W - 10, y, (215, 215, 215))
    last = None
    for f, d in sp:
        if f < 50 or f > min(10000, sr / 2):
            continue
        xx = 40 + (math.log10(f) - math.log10(50)) / (math.log10(10000) - math.log10(50)) * (W - 50)
        yy = b0 + min(90, max(0, -d)) / 90 * (b1 - b0)
        if last:
            line(last[0], last[1], xx, yy, (200, 60, 30))
        last = (xx, yy)
    png(path, W, H, px)
    top = sorted(sp, key=lambda p: -p[1])[:1]
    return {"envelope_peak_db": round(max(env), 1), "spectral_peak_hz": round(top[0][0], 1), "spectral_peak_db": round(top[0][1], 1)}


def main():
    os.makedirs(OUT, exist_ok=True)
    lines = ["Evidencia medida (nao auditiva). PNG: cima = envelope RMS (5 ms, 0..-80 dBFS), baixo = espectro (50 Hz..10 kHz, log)."]
    for name, rel in FILES:
        sr, x = read_wav(os.path.join(ROOT, "game", rel))
        info = plot(os.path.join(OUT, name + ".png"), x, sr, name)
        lines.append("%s: sr=%d n=%d %s" % (name, sr, len(x), info))
    open(os.path.join(OUT, "evidencia_audio.txt"), "w", encoding="utf-8").write("\n".join(lines) + "\n")
    print("\n".join(lines))


if __name__ == "__main__":
    main()
