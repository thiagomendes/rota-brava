#!/usr/bin/env python3
"""Rota Brava D20: amostras de trilha para Thiago (fora do Git, em captures/d19/musica/).

- 2 candidatas por cena (modelo de cena) e 1 por vinheta (modelo de vinheta);
- um MP3 por cena: rotulo falado (Gemini TTS, voz Schedar, cru) + candidata (ate EXCERPT_S, com fade);
- vinhetas.mp3: rotulo + vinheta, cortada no tamanho pedido pela biblia;
- medley_coesao.mp3: 8 s de cada cena (candidata 1) em sequencia, crossfade de 0,5 s;
- teste de loop (measure.loop) por candidata; index.json e LEIA.txt.
Para se a API devolver erro de cota.
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(HERE.parent / "voice"))
import lyria  # noqa: E402
import measure  # noqa: E402
from gemini_tts import synth  # noqa: E402

EXCERPT_S = 75.0
MEDLEY_S, MEDLEY_FROM = 8.0, 6.0
LABEL_VOICE, LABEL_MODEL = "Schedar", "gemini-3.8-flash-tts"
ORD = ["candidata um", "candidata dois"]


def ff(*a: str) -> None:
    subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", *a], check=True)


def to_wav(src: Path, dst: Path, start: float = 0.0, dur: float | None = None, fade: float = 1.5) -> Path:
    af = "aresample=44100,aformat=channel_layouts=stereo"
    if dur:
        af += f",afade=t=out:st={max(0.0, dur - fade):.2f}:d={fade}"
    args = ["-ss", f"{start}", "-i", str(src)] + (["-t", f"{dur}"] if dur else []) + ["-af", af, "-c:a", "pcm_s16le", str(dst)]
    ff(*args)
    return dst


def concat(parts: list[Path], gap: float, mp3: Path, work: Path) -> None:
    sil = work / f"sil_{int(gap * 1000)}.wav"
    ff("-f", "lavfi", "-i", "anullsrc=r=44100:cl=stereo", "-t", str(gap), "-c:a", "pcm_s16le", str(sil))
    lst = work / (mp3.stem + ".txt")
    lst.write_text("".join(f"file '{p}'\nfile '{sil}'\n" for p in parts))
    ff("-f", "concat", "-safe", "0", "-i", str(lst), "-c:a", "libmp3lame", "-b:a", "160k", str(mp3))


def label(text: str, work: Path) -> Path:
    w = work / ("lbl_" + "".join(c if c.isalnum() else "_" for c in text) + ".wav")
    synth(text, LABEL_VOICE, "", LABEL_MODEL, w)
    return to_wav(w, w.with_name(w.stem + "_st.wav"))


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", type=Path, default=Path("/home/user/rota-brava/captures/d19/musica"))
    ap.add_argument("--scene-model", default="lyria-3-pro-preview")
    ap.add_argument("--sting-model", default="lyria-3-clip-preview")
    a = ap.parse_args(argv)
    b = lyria.bible()
    raw, work = a.out / "bruto", a.out / "_work"
    raw.mkdir(parents=True, exist_ok=True)
    work.mkdir(parents=True, exist_ok=True)
    index, calls = [], 0
    leia = ["Trilhas D20 (provisorias, Lyria). Cada MP3 de cena: rotulo falado e a candidata (primeiros "
            f"{EXCERPT_S:.0f} s, com fade); a faixa inteira esta em bruto/.", ""]
    medley: list[Path] = []
    try:
        for sc, s in b["scenes"].items():
            parts = [label(s["label"], work)]
            leia.append(f"{sc}.mp3: {s['label']} ({s['key']}, {s['bpm']} BPM, energia {s['energy']})")
            for take in (1, 2):
                p = lyria.generate(lyria.scene_prompt(sc, take), a.scene_model, raw / f"{sc}_{take}.mp3",
                                   meta={"scene": sc, "take": take})
                calls += p["api_calls"]
                f = Path(p["file"])
                st = measure.stats(f)
                lp = measure.loop(f, work / f"{sc}_{take}_loop2x.wav", float(s["bpm"]))
                index.append({"cena": sc, "take": take, "modelo": a.scene_model, "arquivo": str(f),
                              "medidas": st, "loop": lp, "texto_do_modelo": p["text_part"][:200]})
                parts += [label(ORD[take - 1], work), to_wav(f, work / f"{sc}_{take}_ex.wav", 0, min(EXCERPT_S, st["duration_s"]))]
                leia.append(f"  {ORD[take - 1]}: {f.name}, {st['duration_s']} s, {st['lufs']} LUFS")
                if take == 1:
                    medley.append(to_wav(f, work / f"medley_{sc}.wav", MEDLEY_FROM, MEDLEY_S, 0.5))
            concat(parts, 0.6, a.out / f"{sc}.mp3", work)
        parts = []
        leia += ["", "vinhetas.mp3: rotulo + vinheta (cortada no tamanho da biblia + 1 s, com fade)"]
        for sc, s in b["stings"].items():
            p = lyria.generate(lyria.scene_prompt(sc), a.sting_model, raw / f"vinheta_{sc}.mp3", meta={"scene": sc})
            calls += p["api_calls"]
            f = Path(p["file"])
            st = measure.stats(f)
            index.append({"cena": sc, "take": 1, "modelo": a.sting_model, "arquivo": str(f), "medidas": st,
                          "corte_s": s["seconds"] + 1})
            parts += [label(s["label"], work), to_wav(f, work / f"st_{sc}.wav", 0, s["seconds"] + 1.0, 0.8)]
            leia.append(f"  {s['label']}: {f.name} (gerada com {st['duration_s']} s; tocada ate {s['seconds'] + 1} s)")
        concat(parts, 0.8, a.out / "vinhetas.mp3", work)
        concat(medley, 0.05, a.out / "medley_coesao.mp3", work)
        leia += ["", "medley_coesao.mp3: 8 s da candidata um de cada cena, nesta ordem: " + ", ".join(b["scenes"])]
    except lyria.QuotaError as e:
        print(f"[music_samples] PARADO por cota: {e}", file=sys.stderr)
        leia.append(f"PARADO por cota: {e}")
    (a.out / "index.json").write_text(json.dumps(index, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    (a.out / "LEIA.txt").write_text("\n".join(leia) + "\n", encoding="utf-8")
    print(f"chamadas Lyria nesta execucao: {calls}; itens: {len(index)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
