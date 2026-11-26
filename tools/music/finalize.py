#!/usr/bin/env python3
"""Rota Brava D20a: faixas finais do Lyria para o jogo (OGG Vorbis em game/audio/music/).

Loop (cenas): RMS em quadros de 50 ms; o fim musical e o ultimo quadro acima de (mediana - 12 dB),
o que exclui o fade/silencio do modelo. Batida: autocorrelacao de onsets perto do BPM da biblia
(0,5x a 2x). Loop = maior numero de compassos (4 batidas) que termina >= 1 batida antes do fim musical;
a batida seguinte ao fim do loop e dobrada sobre o inicio (crossfade equal power de 1 batida).
Vinhetas: inicio aparado, corte em (segundos da biblia + 1,5 s) com fade de 0,6 s e silencio nas pontas.
Volume: ganho estatico para -18 LUFS (alvo das faixas de musica do catalogo) + limitador de pico
(teto -1,8 dBFS amostral) e conferencia do pico verdadeiro <= -1 dBTP depois do OGG.

Uso: finalize.py [--src captures/d19/musica/bruto] [--dst game/audio/music] [--report saida.json]
"""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import subprocess
import sys
from pathlib import Path

import numpy as np
import soundfile as sf

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
sys.path.insert(0, str(HERE))
import measure  # noqa: E402

SR = 44100
TARGET_LUFS = -18.0
CEIL = 10 ** (-1.8 / 20)
SCENES = {"village": "music_v3_village", "mystery": "music_v3_mystery", "boat": "music_v3_boat",
          "lighthouse": "music_v3_lighthouse", "festival": "music_v3_festival"}
STINGS = {"mission_win": "sting_v3_mission_win", "badge": "sting_v3_badge", "hero_switch": "sting_v3_hero_switch"}


def frames_rms(x: np.ndarray, hop: int) -> np.ndarray:
    m = x.mean(axis=1)
    n = len(m) // hop
    return 20 * np.log10(np.sqrt(np.mean(m[:n * hop].reshape(n, hop) ** 2, axis=1)) + 1e-9)


def musical_end(x: np.ndarray) -> float:
    r = frames_rms(x, int(0.05 * SR))
    thr = np.median(r) - 12.0
    idx = np.nonzero(r > thr)[0]
    return (idx.max() + 1) * 0.05 if len(idx) else len(x) / SR


def beat_period(x: np.ndarray, bpm_hint: float) -> float:
    m = x.mean(axis=1)
    hop = 256
    n = len(m) // hop
    e = np.log(np.sum(m[:n * hop].reshape(n, hop) ** 2, axis=1) + 1e-9)
    o = np.maximum(0, np.diff(e))
    o -= o.mean()
    f = np.fft.rfft(o, 2 * len(o))
    ac = np.fft.irfft(np.abs(f) ** 2)[:len(o)]
    fps = SR / hop
    best, best_v = 60.0 / bpm_hint, -np.inf
    for bpm in np.arange(bpm_hint * 0.5, bpm_hint * 2.0, 0.1):
        lag = fps * 60.0 / bpm
        i = int(lag)
        v = ac[i] + (ac[i + 1] - ac[i]) * (lag - i)
        v *= 1.0 - 0.15 * abs(np.log2(bpm / bpm_hint))  # prefere perto do pedido
        if v > best_v:
            best, best_v = 60.0 / bpm, v
    return best


def gain_and_limit(y: np.ndarray, tmp: Path) -> tuple[np.ndarray, float]:
    sf.write(str(tmp), y, SR, subtype="FLOAT")
    lufs = measure.ebur(tmp)["lufs"]
    g = 10 ** ((TARGET_LUFS - lufs) / 20)
    y = y * g
    # limitador simples, por amostra, com suavizacao de ganho (ataque 1 ms, liberacao 80 ms)
    env = np.max(np.abs(y), axis=1)
    need = np.minimum(1.0, CEIL / np.maximum(env, 1e-9))
    a_rel = np.exp(-1 / (0.08 * SR))
    gr = np.empty_like(need)
    cur = 1.0
    look = int(0.001 * SR)
    need_la = np.minimum.accumulate(need[::-1])[::-1] if False else need
    # olhar a frente: minimo numa janela de 1 ms adiante
    from numpy.lib.stride_tricks import sliding_window_view
    pad = np.concatenate([need_la, np.ones(look)])
    need_la = sliding_window_view(pad, look + 1).min(axis=1)[:len(need)]
    for i, v in enumerate(need_la):
        cur = v if v < cur else v + (cur - v) * a_rel
        gr[i] = cur
    return y * gr[:, None], round(TARGET_LUFS - lufs, 2)


def encode(y: np.ndarray, dst: Path, work: Path) -> None:
    w = work / (dst.stem + ".wav")
    sf.write(str(w), y, SR, subtype="PCM_24")
    subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", str(w), "-c:a", "libvorbis", "-q:a", "6",
                    str(dst)], check=True)


def seam(dst: Path) -> dict:
    y = measure.decode(dst, SR)
    return {"seam_jump": round(float(np.max(np.abs(y[0] - y[-1]))), 5), **{k: v for k, v in measure.seam_jump(y, SR).items()
                                                                          if k != "salto_amostra"}}


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", type=Path, default=Path("/home/user/rota-brava/captures/d19/musica/bruto"))
    ap.add_argument("--dst", type=Path, default=ROOT / "game/audio/music")
    ap.add_argument("--report", type=Path, default=ROOT / "tools/music/final_tracks.json")
    a = ap.parse_args(argv)
    bible = json.loads((HERE / "music_bible.json").read_text(encoding="utf-8"))
    work = a.src.parent / "_final"
    work.mkdir(parents=True, exist_ok=True)
    out = []
    jobs = [(k, n, f"{k}_1", True) for k, n in SCENES.items()] + [(k, n, f"vinheta_{k}", False) for k, n in STINGS.items()]
    for key, name, stem, is_loop in jobs:
        src = a.src / f"{stem}.mp3"
        prov = json.loads((a.src / f"{stem}.json").read_text(encoding="utf-8"))
        x = measure.decode(src, SR)
        info: dict = {}
        if is_loop:
            bpm = float(bible["scenes"][key]["bpm"])
            beat = beat_period(x, bpm)
            end_mus = musical_end(x)
            nbars = int((end_mus - beat) // (4 * beat))
            end = int(round(nbars * 4 * beat * SR))
            xf = int(round(beat * SR))
            t = np.linspace(0, np.pi / 2, xf)[:, None]
            y = x[:end].copy()
            y[:xf] = y[:xf] * np.sin(t) + x[end:end + xf] * np.cos(t)
            info = {"bpm_pedido": bpm, "bpm_medido": round(60 / beat, 2), "fim_musical_s": round(end_mus, 2),
                    "compassos": nbars, "crossfade_s": round(beat, 3)}
        else:
            dur = float(bible["stings"][key]["seconds"]) + 1.5
            m = np.max(np.abs(x), axis=1)
            st = int(np.argmax(m > 0.003))
            y = x[st:st + int(dur * SR)].copy()
            fo = int(0.6 * SR)
            y[-fo:] *= np.linspace(1, 0, fo)[:, None]
            fi = int(0.003 * SR)
            y[:fi] *= np.linspace(0, 1, fi)[:, None]
            y = np.vstack([y, np.zeros((int(0.05 * SR), 2))])
            info = {"inicio_aparado_s": round(st / SR, 3), "corte_s": dur}
        y, gain = gain_and_limit(y, work / f"{name}_tmp.wav")
        dst = a.dst / f"{name}.ogg"
        encode(y, dst, work)
        e = measure.ebur(dst)
        rec = {"name": name, "file": f"res://audio/music/{name}.ogg", "scene": key, "loop": is_loop,
               "duration": round(len(y) / SR, 3), "lufs": e["lufs"], "true_peak_dbtp": e["true_peak_dbtp"],
               "gain_db": gain, **info, **(seam(dst) if is_loop else {}),
               "sha256": hashlib.sha256(dst.read_bytes()).hexdigest(),
               "source": {"model": prov["model"], "prompt": prov["prompt"], "date": prov["date"],
                          "raw_sha256": prov["sha256"], "raw_file": src.name}}
        out.append(rec)
        print(f"{name:24s} {rec['duration']:7.2f} s {e['lufs']:6.1f} LUFS {e['true_peak_dbtp']:5.1f} dBTP "
              + (f"seam {rec['seam_jump']} dif {rec['diferenca_db']} dB bpm {info['bpm_medido']}" if is_loop else ""))
    a.report.write_text(json.dumps({"generated": dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds"),
                                    "tool": "tools/music/finalize.py", "tracks": out}, ensure_ascii=False, indent=1) + "\n",
                        encoding="utf-8")
    return 0


if __name__ == "__main__":
    sys.exit(main())
