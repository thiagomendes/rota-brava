"""Utilitarios de WAV e medicao (biblioteca padrao). Amostras float em [-1, 1]."""
import array, math, struct, wave


def read_wav(path):
    with wave.open(path, "rb") as w:
        assert w.getsampwidth() == 2 and w.getnchannels() == 1, "esperado mono 16 bits"
        sr = w.getframerate()
        raw = w.readframes(w.getnframes())
    a = array.array("h")
    a.frombytes(raw)
    return sr, [v / 32768.0 for v in a]


def write_wav(path, sr, channels):
    """channels: lista de listas (mono = 1, estereo = 2); 16 bits com clip duro (nunca deve ocorrer)."""
    n = len(channels[0])
    a = array.array("h")
    for i in range(n):
        for ch in channels:
            a.append(max(-32768, min(32767, int(round(ch[i] * 32767)))))
    with wave.open(path, "wb") as w:
        w.setnchannels(len(channels)); w.setsampwidth(2); w.setframerate(sr)
        w.writeframes(a.tobytes())


def db(v):
    return round(20 * math.log10(v), 2) if v > 0 else -120.0


def true_peak(x, taps=16, over=4):
    """Pico verdadeiro estimado: interpola 3 pontos entre amostras com sinc/Hann. Considera so regioes de pico alto."""
    pk = max(abs(v) for v in x)
    thr = pk * 0.5
    best = pk
    n = len(x)
    for i in range(n):
        if abs(x[i]) < thr:
            continue
        for k in range(1, over):
            f = k / over
            s = 0.0
            for j in range(-taps + 1, taps + 1):
                idx = i + j
                if 0 <= idx < n:
                    t = j - f
                    sinc = 1.0 if t == 0 else math.sin(math.pi * t) / (math.pi * t)
                    win = 0.5 * (1 + math.cos(math.pi * t / (taps + 1)))
                    s += x[idx] * sinc * win
            best = max(best, abs(s))
    return best


def measure(x, sr=None):
    """x: mono (lista) ou lista de canais. Devolve duracao, pico, pico verdadeiro estimado, RMS em dBFS."""
    chans = x if x and isinstance(x[0], list) else [x]
    n = len(chans[0])
    pk = max(max(abs(v) for v in c) for c in chans)
    tp = max(true_peak(c) for c in chans)
    ss = sum(v * v for c in chans for v in c) / (n * len(chans))
    return {"duration_s": round(n / sr, 3) if sr else None, "peak_dbfs": db(pk), "true_peak_est_dbfs": db(tp),
            "rms_dbfs": db(math.sqrt(ss))}
