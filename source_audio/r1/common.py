"""RB-R1: utilitarios de audio (numpy/scipy/soundfile do venv .tools/py).

Inclui loudness integrada BS.1770-4 (K-weighting + gating absoluto -70 LUFS e relativo -10 LU), pico verdadeiro
por sobreamostragem 4x (resample_poly), limitador com look-ahead, emendas de loop e escrita WAV PCM16/OGG Vorbis.
Medidas sao numericas: nao substituem audicao.
"""
from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path

import numpy as np
import soundfile as sf
from scipy import signal

ROOT = Path(__file__).resolve().parents[2]
GAME = ROOT / "game"
TOOLS = ROOT / ".tools" / "audio"
SRC = TOOLS / "src"
OUT_AUDIO = GAME / "audio"
CAPTURES = ROOT / "captures" / "rb-r1" / "audio"


def res_path(p: Path) -> str:
    return "res://" + p.resolve().relative_to(GAME.resolve()).as_posix()


# ---------------------------------------------------------------- E/S

def load(path, sr: int, mono: bool = True) -> np.ndarray:
    """Le qualquer formato do libsndfile (wav/flac/ogg/mp3); devolve float64 (n,) ou (n, 2) em `sr`."""
    x, fs = sf.read(str(path), always_2d=True, dtype="float64")
    if mono:
        x = x.mean(axis=1, keepdims=True)
    elif x.shape[1] == 1:
        x = np.repeat(x, 2, axis=1)
    else:
        x = x[:, :2]
    if fs != sr:
        g = np.gcd(int(fs), int(sr))
        x = signal.resample_poly(x, sr // g, int(fs) // g, axis=0)
    return x[:, 0] if mono else x


def write_wav(path: Path, x: np.ndarray, sr: int) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    sf.write(str(path), np.clip(x, -1.0, 1.0), sr, subtype="PCM_16")


def write_ogg(path: Path, x: np.ndarray, sr: int, quality: float = 0.5) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    x = np.clip(x, -1.0, 1.0)
    ch = 1 if x.ndim == 1 else x.shape[1]
    # em blocos: escrever tudo de uma vez estoura a pilha do libvorbis no Windows
    with sf.SoundFile(str(path), "w", sr, ch, format="OGG", subtype="VORBIS", compression_level=1.0 - quality) as f:
        for i in range(0, len(x), 16384):
            f.write(x[i:i + 16384])


def sha256(path: Path) -> str:
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


# ---------------------------------------------------------------- medidas

def db(v: float) -> float:
    return float(20 * np.log10(v)) if v > 1e-12 else -200.0


def _k_filter(sr: int):
    # Coeficientes BS.1770 recalculados para qualquer taxa (pre-filtro de prateleira + RLB passa-altas).
    f0, G, Q = 1681.974450955533, 3.999843853973347, 0.7071752369554196
    K = np.tan(np.pi * f0 / sr)
    Vh = 10 ** (G / 20)
    Vb = Vh ** 0.4996667741545416
    a0 = 1 + K / Q + K * K
    b1 = [(Vh + Vb * K / Q + K * K) / a0, 2 * (K * K - Vh) / a0, (Vh - Vb * K / Q + K * K) / a0]
    a1 = [1, 2 * (K * K - 1) / a0, (1 - K / Q + K * K) / a0]
    f0, Q = 38.13547087602444, 0.5003270373238773
    K = np.tan(np.pi * f0 / sr)
    a2 = [1, 2 * (K * K - 1) / (1 + K / Q + K * K), (1 - K / Q + K * K) / (1 + K / Q + K * K)]
    b2 = [1, -2, 1]
    return (b1, a1), (b2, a2)


def lufs(x: np.ndarray, sr: int) -> float:
    """Loudness integrada BS.1770-4 (LUFS). Mono conta como um canal (sem +3 dB)."""
    x = x.reshape(len(x), -1)
    (b1, a1), (b2, a2) = _k_filter(sr)
    y = signal.lfilter(b2, a2, signal.lfilter(b1, a1, x, axis=0), axis=0)
    blk, hop = int(0.4 * sr), int(0.1 * sr)
    if len(y) < blk:
        y = np.pad(y, ((0, blk - len(y)), (0, 0)))
    n = 1 + (len(y) - blk) // hop
    ms = np.array([np.mean(y[i * hop:i * hop + blk] ** 2, axis=0).sum() for i in range(n)])
    lk = -0.691 + 10 * np.log10(np.maximum(ms, 1e-20))
    g = ms[lk > -70]
    if len(g) == 0:
        return -200.0
    rel = -0.691 + 10 * np.log10(g.mean()) - 10
    g2 = ms[(lk > -70) & (lk > rel)]
    return float(-0.691 + 10 * np.log10(g2.mean())) if len(g2) else -200.0


def true_peak(x: np.ndarray) -> float:
    """Pico verdadeiro (dBTP) por sobreamostragem 4x (BS.1770 Anexo 2, filtro polifasico)."""
    x = x.reshape(len(x), -1)
    up = signal.resample_poly(x, 4, 1, axis=0)
    return db(max(np.abs(up).max(), np.abs(x).max()))


def sample_peak(x: np.ndarray) -> float:
    return db(np.abs(x).max())


def seam_jump(x: np.ndarray) -> float:
    """Salto na emenda do loop (ultima -> primeira amostra) relativo ao maior passo tipico do sinal."""
    x = x.reshape(len(x), -1)
    return float(np.abs(x[0] - x[-1]).max())


def seam_ratio(x: np.ndarray) -> float:
    """Salto da emenda dividido pelo percentil 99,9 dos passos internos (<= ~1 = indistinguivel de um passo normal)."""
    x = x.reshape(len(x), -1)
    d = np.abs(np.diff(x, axis=0)).max(axis=1)
    p = np.percentile(d, 99.9)
    return float(seam_jump(x) / max(p, 1e-9))


def measure(x: np.ndarray, sr: int) -> dict:
    return {"duration": round(len(x) / sr, 3), "peak_dbfs": round(sample_peak(x), 2),
            "true_peak_dbtp": round(true_peak(x), 2), "lufs": round(lufs(x, sr), 2),
            "rms_dbfs": round(db(np.sqrt(np.mean(x ** 2))), 2)}


# ---------------------------------------------------------------- processamento

def normalize_lufs(x: np.ndarray, sr: int, target: float, tp_ceiling: float = -1.5) -> np.ndarray:
    l = lufs(x, sr)
    if l > -150:
        x = x * 10 ** ((target - l) / 20)
    return limit(x, sr, tp_ceiling)


def limit(x: np.ndarray, sr: int, ceiling_db: float = -1.5, release: float = 0.08) -> np.ndarray:
    """Limitador com look-ahead de 2 ms e ganho suave; garante pico verdadeiro <= teto (com 2 passes)."""
    for _ in range(4):
        tp = true_peak(x)
        if tp <= ceiling_db:
            return x
        c = 10 ** ((ceiling_db - 0.3) / 20)
        env = np.abs(x.reshape(len(x), -1)).max(axis=1)
        need = np.minimum(1.0, c / np.maximum(env, 1e-9))
        la = max(1, int(0.002 * sr))
        need = -_maxfilt(-need, 2 * la + 1)
        g = np.empty_like(need)
        a = np.exp(-1 / (release * sr))
        cur = 1.0
        for i in range(len(need)):  # ataque instantaneo (look-ahead ja aplicado), liberacao exponencial
            cur = need[i] if need[i] < cur else need[i] + (cur - need[i]) * a
            g[i] = cur
        g = signal.lfilter([0.5, 0.5], [1], g)
        x = x * (g if x.ndim == 1 else g[:, None])
        if true_peak(x) > ceiling_db:
            x = x * 10 ** ((ceiling_db - true_peak(x) - 0.05) / 20)
    return x


def _maxfilt(v: np.ndarray, w: int) -> np.ndarray:
    from scipy.ndimage import maximum_filter1d
    return maximum_filter1d(v, size=w, mode="nearest")


def fade(x: np.ndarray, sr: int, fin: float = 0.003, fout: float = 0.01) -> np.ndarray:
    x = x.copy()
    a, b = int(fin * sr), int(fout * sr)
    if a:
        x[:a] *= (np.sin(np.linspace(0, np.pi / 2, a)) ** 2).reshape(-1, *([1] * (x.ndim - 1)))
    if b:
        x[-b:] *= (np.cos(np.linspace(0, np.pi / 2, b)) ** 2).reshape(-1, *([1] * (x.ndim - 1)))
    return x


def trim(x: np.ndarray, sr: int, thr_db: float = -50.0, keep: float = 0.004, end_db: float = -60.0) -> np.ndarray:
    """Corta silencio: inicio no 1o ponto acima de thr_db (dBFS), fim no ultimo acima de end_db (preserva caudas)."""
    env = np.abs(x.reshape(len(x), -1)).max(axis=1)
    idx = np.nonzero(env > 10 ** (thr_db / 20))[0]
    if len(idx) == 0:
        return x
    tail = np.nonzero(env > 10 ** (end_db / 20))[0]
    a = max(0, idx[0] - int(keep * sr))
    b = min(len(x), tail[-1] + int(0.03 * sr))
    return x[a:b]


def crossfade_loop(x: np.ndarray, sr: int, length: float, xf: float = 2.0) -> np.ndarray:
    """Loop sem emenda: usa length+xf segundos; os ultimos xf s entram em fade de potencia constante sobre o inicio."""
    L, X = int(length * sr), int(xf * sr)
    assert len(x) >= L + X, "material curto para o loop"
    y = x[:L].copy()
    t = np.linspace(0, np.pi / 2, X)
    fi, fo = np.sin(t), np.cos(t)
    sh = (-1,) + (1,) * (x.ndim - 1)
    y[:X] = x[:X] * fi.reshape(sh) + x[L:L + X] * fo.reshape(sh)
    return y


def best_roll(x: np.ndarray) -> np.ndarray:
    """Para um loop ja continuo (periodico), gira o inicio para o ponto de menor passo e menor amplitude;
    a emenda continua continua e passa a cair num ponto quieto (bom tambem apos codificar em Vorbis)."""
    y = x.reshape(len(x), -1)
    d = np.abs(np.diff(y, axis=0, append=y[:1])).max(axis=1) + 0.5 * np.abs(y).max(axis=1)
    i = int(np.argmin(d)) + 1
    return np.roll(x, -i, axis=0)


def fold_tail(x: np.ndarray, L: int) -> np.ndarray:
    """Loop musical: soma a cauda (reverb/release apos L) no inicio; a emenda fica continua."""
    y = x[:L].copy()
    tail = x[L:]
    while len(tail):
        k = min(len(tail), L)
        y[:k] += tail[:k]
        tail = tail[k:]
    return y


def biquad(kind: str, f: float, sr: int, q: float = 0.707, gain_db: float = 0.0):
    """Coeficientes RBJ (lowpass, highpass, bandpass, peak, lowshelf, highshelf)."""
    A = 10 ** (gain_db / 40)
    w = 2 * np.pi * f / sr
    c, s = np.cos(w), np.sin(w)
    al = s / (2 * q)
    if kind == "lowpass":
        b = [(1 - c) / 2, 1 - c, (1 - c) / 2]; a = [1 + al, -2 * c, 1 - al]
    elif kind == "highpass":
        b = [(1 + c) / 2, -(1 + c), (1 + c) / 2]; a = [1 + al, -2 * c, 1 - al]
    elif kind == "bandpass":
        b = [al, 0, -al]; a = [1 + al, -2 * c, 1 - al]
    elif kind == "peak":
        b = [1 + al * A, -2 * c, 1 - al * A]; a = [1 + al / A, -2 * c, 1 - al / A]
    elif kind in ("lowshelf", "highshelf"):
        sq = 2 * np.sqrt(A) * al
        if kind == "lowshelf":
            b = [A * ((A + 1) - (A - 1) * c + sq), 2 * A * ((A - 1) - (A + 1) * c), A * ((A + 1) - (A - 1) * c - sq)]
            a = [(A + 1) + (A - 1) * c + sq, -2 * ((A - 1) + (A + 1) * c), (A + 1) + (A - 1) * c - sq]
        else:
            b = [A * ((A + 1) + (A - 1) * c + sq), -2 * A * ((A - 1) + (A + 1) * c), A * ((A + 1) + (A - 1) * c - sq)]
            a = [(A + 1) - (A - 1) * c + sq, 2 * ((A - 1) - (A + 1) * c), (A + 1) - (A - 1) * c - sq]
    else:
        raise ValueError(kind)
    b, a = np.array(b) / a[0], np.array(a) / a[0]
    return b, a


def filt(x: np.ndarray, kind: str, f: float, sr: int, q: float = 0.707, gain_db: float = 0.0) -> np.ndarray:
    b, a = biquad(kind, f, sr, q, gain_db)
    return signal.lfilter(b, a, x, axis=0)


def compress(x: np.ndarray, sr: int, thr_db: float = -18, ratio: float = 3.0, att: float = 0.005,
             rel: float = 0.08, makeup_db: float = 0.0) -> np.ndarray:
    env = np.abs(x.reshape(len(x), -1)).max(axis=1)
    e = signal.lfilter([1 - np.exp(-1 / (att * sr))], [1, -np.exp(-1 / (att * sr))], env)
    e = np.maximum(e, signal.lfilter([1 - np.exp(-1 / (rel * sr))], [1, -np.exp(-1 / (rel * sr))], env))
    lv = 20 * np.log10(np.maximum(e, 1e-9))
    gr = np.minimum(0, (thr_db - lv) * (1 - 1 / ratio))
    g = 10 ** ((gr + makeup_db) / 20)
    return x * (g if x.ndim == 1 else g[:, None])


def reverb(x: np.ndarray, sr: int, size: float = 0.5, wet: float = 0.15, damp: float = 0.4, seed: int = 7) -> np.ndarray:
    """Reverb curto por convolucao com ruido decaindo (resposta sintetica original)."""
    rng = np.random.default_rng(seed)
    n = int(sr * (0.3 + 1.7 * size))
    t = np.arange(n) / sr
    ir = rng.standard_normal(n) * np.exp(-t * (6.9 / (0.3 + 1.7 * size)))
    ir = filt(ir, "lowpass", 9000 * (1 - damp) + 1500, sr)
    ir[: int(0.012 * sr)] = 0
    ir /= np.sqrt(np.sum(ir ** 2)) + 1e-9
    def conv(a, h):
        w = signal.fftconvolve(a, h)
        return np.pad(w, (0, max(0, len(a) + n - len(w))))[: len(a) + n]
    if x.ndim == 1:
        return np.pad(x, (0, n)) * (1 - wet) + conv(x, ir) * wet
    ir2 = np.roll(ir, int(0.007 * sr))
    return np.stack([np.pad(x[:, 0], (0, n)) * (1 - wet) + conv(x[:, 0], ir) * wet,
                     np.pad(x[:, 1], (0, n)) * (1 - wet) + conv(x[:, 1], ir2) * wet], axis=1)


def pan(x: np.ndarray, p: float) -> np.ndarray:
    """Mono -> estereo, p em -1..1 (lei de potencia constante)."""
    a = (p + 1) * np.pi / 4
    return np.stack([x * np.cos(a), x * np.sin(a)], axis=1)


def save_json(path: Path, data) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def load_json(path: Path):
    return json.loads(Path(path).read_text(encoding="utf-8"))
