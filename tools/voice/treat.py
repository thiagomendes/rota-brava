#!/usr/bin/env python3
"""Rota Brava D19: tratamento local de voz por personagem (ffmpeg + rubberband).

Cadeia: apara silencio (inicio e fim) -> altura/formantes (rubberband) -> EQ
-> [preset radio: banda de telefone + chiado sintetizado] -> loudnorm 2 passadas
(-16 LUFS, -1 dBTP) -> 48 kHz mono PCM16. Sem reverb. Sem amostra de terceiros:
o chiado do Farol 7 e ruido gerado pelo ffmpeg (anoisesrc).

Uso: treat.py --preset rastro in.wav out.wav   |   treat.py --list
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

TRIM = ("silenceremove=start_periods=1:start_threshold=-50dB:start_silence=0.02,"
        "areverse,silenceremove=start_periods=1:start_threshold=-50dB:start_silence=0.06,areverse")

# semitons: altura; tempo: fator de duracao do rubberband (1 = igual); eq: filtros ffmpeg.
# D19d: em uso so o "raw" (Thiago escolheu as vozes cruas). Os demais ficam como opcao, desligados.
PRESETS: dict[str, dict] = {
    "raw": {"desc": "D19d: so apara silencio e normaliza (-16 LUFS, -1 dBTP); sem altura, formantes nem EQ",
            "semitones": 0.0, "tempo": 1.0, "eq": "", "enabled": True},
    "rastro": {"enabled": False, "desc": "menina atenta: +3 st com formantes deslocados, corte de grave, presenca suave",
               "semitones": 3.0, "tempo": 1.0,
               "eq": "highpass=f=150,equalizer=f=320:t=q:w=1.2:g=-2,equalizer=f=3500:t=q:w=1.0:g=3"},
    "pico": {"enabled": False, "desc": "menino energetico: +3.5 st, 4% mais rapido, presenca mais forte",
             "semitones": 3.5, "tempo": 1.04,
             "eq": "highpass=f=150,equalizer=f=280:t=q:w=1.2:g=-2,equalizer=f=4000:t=q:w=1.0:g=4"},
    "leme": {"enabled": False, "desc": "menina firme, pilota: +2 st, corpo medio mantido, presenca em 2,5 kHz",
             "semitones": 2.0, "tempo": 1.0,
             "eq": "highpass=f=130,equalizer=f=2500:t=q:w=1.0:g=2.5,acompressor=threshold=-20dB:ratio=2.5:attack=5:release=80"},
    "capitao": {"enabled": False, "desc": "adulto caloroso: sem altura, calor em 160 Hz, aspereza 3 kHz contida",
                "semitones": 0.0, "tempo": 1.0,
                "eq": "highpass=f=70,equalizer=f=160:t=q:w=1.0:g=2,equalizer=f=3000:t=q:w=1.2:g=-1.5"},
    "farol7": {"enabled": False, "desc": "radio: banda 300-3400 Hz, leve saturacao, chiado sintetizado -38 dB",
               "semitones": 0.0, "tempo": 1.0, "radio": True,
               "eq": "highpass=f=300,lowpass=f=3400,equalizer=f=1800:t=q:w=1.0:g=4,"
                     "acompressor=threshold=-24dB:ratio=4:attack=3:release=60,asoftclip=type=tanh"},
    "amora": {"enabled": False, "desc": "senhora feirante: -0.5 st, 3% mais lenta, calor e presenca leves",
              "semitones": -0.5, "tempo": 0.97,
              "eq": "highpass=f=90,equalizer=f=220:t=q:w=1.0:g=1.5,equalizer=f=2800:t=q:w=1.2:g=1.5"},
}
TARGET_I, TARGET_TP, TARGET_LRA = -16.0, -1.0, 11.0
NOISE_DB = -38.0


def core_chain(p: dict) -> str:
    parts = [TRIM]
    if p["semitones"] or p["tempo"] != 1.0:
        parts.append(f"rubberband=pitch={2 ** (p['semitones'] / 12):.6f}:tempo={p['tempo']:.4f}"
                     ":formant=shifted:pitchq=quality")
    if p["eq"]:
        parts.append(p["eq"])
    return ",".join(parts)


def _run(cmd: list[str]) -> str:
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode:
        raise RuntimeError(r.stderr[-1500:])
    return r.stderr


def graph(p: dict, tail: str) -> list[str]:
    if p.get("radio"):
        amp = 10 ** (NOISE_DB / 20)
        fc = (f"[0:a]{core_chain(p)}[v];anoisesrc=color=pink:amplitude={amp:.5f}:seed=7:sample_rate=24000,"
              f"highpass=f=300,lowpass=f=3400[n];[v][n]amix=inputs=2:duration=first:normalize=0,{tail}[o]")
    else:
        fc = f"[0:a]{core_chain(p)},{tail}[o]"
    return ["-filter_complex", fc, "-map", "[o]"]


def treat(preset: str, src: Path, dst: Path) -> dict:
    p = PRESETS[preset]
    ln = f"loudnorm=I={TARGET_I}:TP={TARGET_TP}:LRA={TARGET_LRA}"
    err = _run(["ffmpeg", "-hide_banner", "-nostats", "-i", str(src), *graph(p, ln + ":print_format=json"),
                "-f", "null", "-"])
    m = json.loads(err[err.rindex("{"):err.rindex("}") + 1])
    ln2 = (f"{ln}:measured_I={m['input_i']}:measured_TP={m['input_tp']}:measured_LRA={m['input_lra']}"
           f":measured_thresh={m['input_thresh']}:offset={m['target_offset']}:linear=true")
    dst.parent.mkdir(parents=True, exist_ok=True)
    _run(["ffmpeg", "-hide_banner", "-nostats", "-y", "-i", str(src), *graph(p, ln2 + ",aresample=48000"),
          "-ac", "1", "-c:a", "pcm_s16le", str(dst)])
    # Falas curtas: o loudnorm linear fica limitado pelo pico e nao chega ao alvo.
    # Correcao: ganho que falta + limitador (oversampling 4x) em -1,3 dBFS de teto.
    got = loudness(dst)
    fix = None
    if abs(got["lufs"] - TARGET_I) > 0.5 or got["true_peak_dbtp"] > TARGET_TP:
        fix = round(TARGET_I - got["lufs"], 2)
        tmp = dst.with_name(dst.stem + ".tmp.wav")
        dst.rename(tmp)
        _run(["ffmpeg", "-hide_banner", "-nostats", "-y", "-i", str(tmp), "-af",
              f"aresample=192000,volume={fix}dB,alimiter=limit={10 ** (-1.3 / 20):.4f}:attack=1:release=40:level=false,"
              "aresample=48000", "-ac", "1", "-c:a", "pcm_s16le", str(dst)])
        tmp.unlink()
    return {"preset": preset, "src": str(src), "dst": str(dst), "first_pass": m, "gain_fix_db": fix}


def loudness(path: Path) -> dict:
    """Mede loudness integrada e pico verdadeiro (ebur128) do arquivo final."""
    err = _run(["ffmpeg", "-hide_banner", "-nostats", "-i", str(path), "-af", "ebur128=peak=true", "-f", "null", "-"])
    tail = err[err.rindex("Summary:"):]
    i = float(tail.split("I:")[1].split("LUFS")[0])
    tp = float(tail.split("Peak:")[1].split("dBFS")[0])
    return {"lufs": i, "true_peak_dbtp": tp}


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--preset", choices=sorted(PRESETS))
    ap.add_argument("--list", action="store_true")
    ap.add_argument("src", nargs="?", type=Path)
    ap.add_argument("dst", nargs="?", type=Path)
    a = ap.parse_args(argv)
    if a.list:
        for k, v in PRESETS.items():
            print(f"{k:8s} {v['desc']}")
        return 0
    if not (a.preset and a.src and a.dst):
        ap.error("informe --preset, src e dst")
    treat(a.preset, a.src, a.dst)
    print(json.dumps({"dst": str(a.dst), **loudness(a.dst)}))
    return 0


if __name__ == "__main__":
    sys.exit(main())
