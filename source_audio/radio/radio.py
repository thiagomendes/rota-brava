"""Radio de Farol 7 (RB-R1 D2): voz Piper pt_BR-jeff-medium (TTS neural LOCAL, offline, so na producao) + filtro de radio.

Cadeia: Piper 22,05 kHz -> 32 kHz -> passa-altas 320 Hz / passa-baixas 3,4 kHz (2x2 polos) + pico nasal 1,8 kHz ->
compressor (4:1) -> saturacao leve (tanh) -> chiado de banda baixo (-44 dB abaixo da voz) -> squelch de abertura
(ruido 70 ms + clique) e de fechamento (cauda de ruido + bipe duplo curto) -> -18 LUFS, pico verdadeiro <= -2 dBTP.
Uso: python source_audio/radio/radio.py [--only ID]
"""
from __future__ import annotations

import io
import sys
import wave
import zlib
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "r1"))
from common import (OUT_AUDIO, ROOT, compress, filt, limit, load_json, lufs, measure, res_path, save_json,  # noqa: E402
                    write_wav)
from lines import gather  # noqa: E402

HERE = Path(__file__).resolve().parent
SR = 32000
VOICE = ROOT / ".tools" / "audio" / "voices" / "pt_BR-jeff-medium.onnx"
LENGTH_SCALE = 1.08
TARGET_LUFS = -18.0
PRONUNCIATION_TEST = "ep01.radio.team.found_boat"


def piper_tts(voice, text: str) -> tuple[np.ndarray, int]:
    from piper import SynthesisConfig
    buf = io.BytesIO()
    with wave.open(buf, "wb") as wf:
        voice.synthesize_wav(text, wf, syn_config=SynthesisConfig(length_scale=LENGTH_SCALE, noise_scale=0.5, noise_w_scale=0.6))
    buf.seek(0)
    with wave.open(buf, "rb") as wf:
        sr = wf.getframerate()
        x = np.frombuffer(wf.readframes(wf.getnframes()), dtype="<i2").astype(np.float64) / 32768.0
    return x, sr


def process(x22: np.ndarray, sr_in: int, seed: int) -> np.ndarray:
    from scipy import signal
    rng = np.random.default_rng(seed)
    g = np.gcd(SR, sr_in)
    x = signal.resample_poly(x22, SR // g, sr_in // g)
    # corta silencio do Piper nas pontas
    env = np.abs(x)
    nz = np.nonzero(env > 0.01)[0]
    x = x[max(0, nz[0] - int(0.01 * SR)): nz[-1] + int(0.06 * SR)]
    x = x / (np.abs(x).max() + 1e-9) * 0.7
    for _ in range(2):
        x = filt(x, "highpass", 320, SR, 0.707)
        x = filt(x, "lowpass", 3400, SR, 0.707)
    x = filt(x, "peak", 1800, SR, 1.2, 3.0)
    x = compress(x, SR, -24, 4.0, 0.003, 0.06, makeup_db=8)
    drive = 2.0
    x = 0.65 * x + 0.35 * np.tanh(drive * x) / np.tanh(drive)
    x = filt(x, "lowpass", 3800, SR)  # remove harmonicos da saturacao acima da banda
    # normaliza a voz antes do ruido para o chiado ter nivel relativo fixo
    x = x * 10 ** ((TARGET_LUFS - lufs(x, SR)) / 20)
    vrms = np.sqrt(np.mean(x[np.abs(x) > 0.01] ** 2)) if (np.abs(x) > 0.01).any() else 0.05

    def band_noise(n, lo=600, hi=5000, level=1.0):
        w = rng.standard_normal(n)
        w = filt(filt(w, "highpass", lo, SR), "lowpass", hi, SR)
        return w / (np.sqrt(np.mean(w ** 2)) + 1e-9) * level

    open_n, close_n = int(0.075 * SR), int(0.16 * SR)
    pre = band_noise(open_n, 400, 6000, vrms * 0.55) * np.linspace(1, 0.25, open_n)
    pre[:3] = 0
    pre[int(0.004 * SR)] += vrms * 2.0  # clique de abertura
    post = band_noise(close_n, 400, 6000, vrms * 0.6) * np.concatenate([np.linspace(0.3, 1, close_n // 4),
                                                                          np.linspace(1, 0, close_n - close_n // 4)])
    t = np.arange(int(0.05 * SR)) / SR
    beep = np.concatenate([np.sin(2 * np.pi * 1400 * t), np.zeros(int(0.02 * SR)), np.sin(2 * np.pi * 1050 * t)])
    beep *= vrms * 0.6 * np.concatenate([np.hanning(len(t)), np.zeros(int(0.02 * SR)), np.hanning(len(t))])
    body = x + band_noise(len(x), 500, 6000, vrms * 10 ** (-44 / 20 + 0))  # chiado continuo ~ -44 dB da voz
    hiss_tail = band_noise(len(beep), 500, 6000, vrms * 10 ** (-44 / 20))
    y = np.concatenate([pre, body, beep + hiss_tail, post])
    y[-int(0.01 * SR):] *= np.linspace(1, 0, int(0.01 * SR))
    y = y * 10 ** ((TARGET_LUFS - lufs(y, SR)) / 20)
    return limit(y, SR, -2.0)


TAKES = HERE / "takes"


def take(voice, e: dict, force: bool) -> tuple[np.ndarray, int]:
    """Take seco do Piper, guardado em source_audio/radio/takes/ (FLAC). O Piper sorteia ruido a cada sintese;
    reaproveitar o take aprovado deixa o build reproduzivel. Regera se o texto/voz/ajustes mudarem ou com --force."""
    import soundfile as sf
    TAKES.mkdir(exist_ok=True)
    meta_p = TAKES / "takes.json"
    meta = load_json(meta_p) if meta_p.exists() else {}
    key = {"text": e["text"], "voice": VOICE.name, "length_scale": LENGTH_SCALE}
    f = TAKES / (e["id"].replace(".", "_") + ".flac")
    if not force and f.exists() and meta.get(e["id"]) == key:
        x, sr = sf.read(str(f), dtype="float64")
        return x, sr
    x, sr = piper_tts(voice, e["text"])
    sf.write(str(f), x, sr, subtype="PCM_16")
    meta[e["id"]] = key
    save_json(meta_p, dict(sorted(meta.items())))
    return x, sr


def main(argv: list[str]) -> int:
    only = argv[argv.index("--only") + 1] if "--only" in argv else None
    force = "--force" in argv
    if not VOICE.exists():
        print("voz Piper ausente: rode ./tools/setup-audio-tools.ps1", file=sys.stderr)
        return 2
    from piper import PiperVoice
    voice = PiperVoice.load(str(VOICE))
    vdir = OUT_AUDIO / "voice"
    report = []
    for e in gather():
        if e["type"] != "radio" or (only and e["id"] != only):
            continue
        seed = zlib.crc32(e["id"].encode()) & 0xFFFFFFFF
        raw, sr = take(voice, e, force)
        dry = raw.copy()
        y = process(raw, sr, seed)
        stem = e["id"].replace(".", "_")
        wav = vdir / f"{stem}.wav"
        write_wav(wav, y, SR)
        vis = _visemes(y)
        vjs = vdir / f"{stem}.visemes.json"
        save_json(vjs, {"id": e["id"], "character": e["character"], "intent": "radio", "duration": round(len(y) / SR, 3),
                        "frame_s": 0.03, "open": vis, "syllables": [], "tool": "Piper pt_BR-jeff-medium + source_audio/radio/radio.py"})
        m = measure(y, SR)
        rec = {"id": e["id"], "character": e["character"], "speaker_key": e["origin_speaker"], "text": e["text"],
               "file": res_path(wav), "visemes": res_path(vjs), **m, "dry_duration": round(len(dry) / sr, 3)}
        if e["id"] == PRONUNCIATION_TEST:
            try:
                rec["phonemes"] = [" ".join(p) for p in voice.phonemize(e["text"])]
            except Exception as ex:  # noqa: BLE001
                rec["phonemes"] = f"indisponivel: {ex}"
            write_wav(ROOT / "captures" / "rb-r1" / "audio" / "found_boat_dry.wav", dry, sr)
        report.append(rec)
        print(f"radio  {e['id']:45s} {m['duration']:5.2f}s {m['lufs']:6.1f} LUFS {m['true_peak_dbtp']:5.1f} dBTP")
    if not only:
        save_json(HERE / "generated.json", {"tool": "piper-tts 1.8.0 + pt_BR-jeff-medium (CC0) + radio.py",
                                            "length_scale": LENGTH_SCALE, "lines": report})
    return 0


def _visemes(y: np.ndarray) -> list[float]:
    hop = int(0.03 * SR)
    n = int(np.ceil(len(y) / hop))
    r = np.array([np.sqrt(np.mean(y[i * hop:(i + 1) * hop] ** 2)) for i in range(n)])
    r = r / (r.max() + 1e-9)
    return [round(float(min(1.0, (v ** 0.6) * 1.1)) if v > 0.08 else 0.0, 3) for v in r]


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
