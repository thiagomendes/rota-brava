#!/usr/bin/env python3
"""Rota Brava D19: amostras de elenco para Thiago aprovar (fora do Git, em captures/).

Por personagem: para cada candidata, rotulo falado ("voz um"...), 2 falas cruas,
as mesmas 2 tratadas pelo preset do personagem. Um MP3 por personagem (128 kbps
mono, 0,8 s entre candidatas) + MP3 de emocoes (mesma frase em 2 direcoes) +
index.json + LEIA.txt. Checa leitura da instrucao em voz alta pela duracao.

Uso: samples.py [--out captures/d19/amostras] [--only rastro,pico] [--dry-run]
"""
from __future__ import annotations

import argparse
import glob
import json
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
sys.path.insert(0, str(HERE))
from gemini_tts import AuthError, directed_style, load_json, synth  # noqa: E402
from treat import loudness, treat  # noqa: E402

LINES = {
    "rastro": ["ep01.dock.tracker.two_trails", "ep01.dock.tracker.small_print"],
    "pico": ["ep01.street.climber.gull_fish", "ep01.plaza.climber.m3_done"],
    "leme": ["ep01.arrival.pilot.no_captain", "ep01.market.pilot.cart_go"],
    "capitao": ["ep01.bay.captain.thanks_tow", "ep01.festival.captain.first_lantern"],
    "farol7": ["ep01.call.c1.lumi_alert", "ep01.lumi.lantern_2"],
    "dona_amora": ["ep01.market.vendor.mess", "ep01.market.vendor.gull_hint"],
}
ORDINAL = ["voz um", "voz dois", "voz tres", "voz quatro"]
LABEL_VOICE = "Schedar"  # rotulo neutro, sem estilo e sem tratamento
GAP_CAND, GAP_IN = 0.8, 0.4


def texts() -> dict:
    t: dict = {}
    for f in sorted(glob.glob(str(ROOT / "game/i18n/pt_BR*.json"))):
        t.update(json.loads(Path(f).read_text(encoding="utf-8")))
    return t


def ff(*args: str) -> None:
    subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", *args], check=True)


def norm48(src: Path, dst: Path) -> Path:
    ff("-i", str(src), "-ar", "48000", "-ac", "1", "-c:a", "pcm_s16le", str(dst))
    return dst


def concat_mp3(parts: list[tuple[Path | None, float]], mp3: Path, work: Path) -> None:
    """parts: (wav ou None, silencio depois)."""
    lst = work / (mp3.stem + ".txt")
    sil = {}
    lines = []
    for i, (w, gap) in enumerate(parts):
        if w is not None:
            lines.append(f"file '{norm48(w, work / f'{mp3.stem}_{i:03d}.wav')}'")
        if gap > 0:
            if gap not in sil:
                sil[gap] = work / f"sil_{int(gap * 1000)}.wav"
                ff("-f", "lavfi", "-i", "anullsrc=r=48000:cl=mono", "-t", str(gap), "-c:a", "pcm_s16le", str(sil[gap]))
            lines.append(f"file '{sil[gap]}'")
    lst.write_text("\n".join(lines) + "\n")
    ff("-f", "concat", "-safe", "0", "-i", str(lst), "-ac", "1", "-c:a", "libmp3lame", "-b:a", "128k", str(mp3))


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", type=Path, default=ROOT.parent.parent.parent / "captures/d19/amostras"
                    if ".claude/worktrees" in str(ROOT) else ROOT / "captures/d19/amostras")
    ap.add_argument("--only", default=",".join(k for k in LINES if k != "dona_amora"))
    ap.add_argument("--no-emotions", action="store_true", help="so as candidatas; acrescenta ao indice existente")
    ap.add_argument("--dry-run", action="store_true")
    a = ap.parse_args(argv)
    cast, dr, tx = load_json("cast.json"), load_json("direction.json"), texts()
    model = cast["model"]
    raw, trt, work = a.out / "bruto", a.out / "tratado", a.out / "_work"
    for d in (raw, trt, work):
        d.mkdir(parents=True, exist_ok=True)
    index: list[dict] = []
    calls = 0
    leia = ["Amostras D19 (provisorias). Cada MP3: rotulo 'voz um/dois/...' (voz neutra, sem tratamento),",
            "depois as 2 falas CRUAS, depois as mesmas 2 TRATADAS. 0,8 s de silencio entre candidatas.", ""]

    def gen(text: str, voice: str, style: str, out: Path) -> dict:
        nonlocal calls
        p = synth(text, voice, style, model, out, a.dry_run, cast["style_mode"])
        calls += p.get("api_calls", 0)
        return p

    labels = {}
    for i, o in enumerate(ORDINAL):
        labels[i] = raw / f"rotulo_{i + 1}.wav"
        gen(o.replace("tres", "três") + ".", LABEL_VOICE, "", labels[i])
    try:
        for ch in a.only.split(","):
            c = cast["characters"][ch]
            parts: list[tuple[Path | None, float]] = []
            leia.append(f"{ch}.mp3 (preset {c['preset']}, recomendada: {c['voice']})")
            for i, voice in enumerate(c["candidates"]):
                parts.append((labels[i], GAP_IN))
                rws, tts = [], []
                for key in LINES[ch]:
                    text = tx[key]
                    style = directed_style(ch, key)
                    stem = f"{ch}__{voice}__{key.split('.')[-1]}"
                    p = gen(text, voice, style, raw / f"{stem}.wav")
                    if a.dry_run:
                        continue
                    treat(c["preset"], raw / f"{stem}.wav", trt / f"{stem}.wav")
                    exp = p["expected_duration_s"]
                    index.append({"personagem": ch, "voz": voice, "fala": key, "texto": text,
                                  "bruto": str(raw / f"{stem}.wav"), "tratado": str(trt / f"{stem}.wav"),
                                  "duracao_bruto_s": p["duration_s"], "duracao_esperada_s": round(exp, 2),
                                  "suspeita_instrucao_lida": p["suspect_instruction_read"], "tentativas": p["tries"],
                                  **{f"tratado_{k}": v for k, v in loudness(trt / f"{stem}.wav").items()}})
                    rws.append(raw / f"{stem}.wav")
                    tts.append(trt / f"{stem}.wav")
                seq = rws + tts
                for j, w in enumerate(seq):
                    parts.append((w, GAP_CAND if j == len(seq) - 1 else GAP_IN))
                leia.append(f"  {ORDINAL[i]}: {voice} - {c['candidates'][voice]}")
            if not a.dry_run:
                concat_mp3(parts, a.out / f"{ch}.mp3", work)
        # emocoes: voz recomendada de cada heroi, mesma frase em 2 direcoes
        if a.no_emotions:
            raise StopIteration
        demo = dr["demo"]
        parts = []
        leia += ["", "emocoes.mp3: para cada heroi (rastro, pico, leme), a mesma frase 'curiosa' e depois 'animada', crua e depois tratada."]
        for ch, key in demo["text"].items():
            c = cast["characters"][ch]
            for vname, d in demo["variants"].items():
                stem = f"emocao__{ch}__{c['voice']}__{vname}"
                p = gen(tx[key], c["voice"], directed_style(ch, direction=d), raw / f"{stem}.wav")
                if a.dry_run:
                    continue
                treat(c["preset"], raw / f"{stem}.wav", trt / f"{stem}.wav")
                index.append({"personagem": ch, "voz": c["voice"], "fala": key, "texto": tx[key], "emocao": vname,
                              "bruto": str(raw / f"{stem}.wav"), "tratado": str(trt / f"{stem}.wav"),
                              "duracao_bruto_s": p["duration_s"]})
                parts += [(raw / f"{stem}.wav", GAP_IN), (trt / f"{stem}.wav", GAP_CAND)]
            leia.append(f"  {ch} ({c['voice']}): \"{tx[key]}\" curiosa (crua, tratada), animada (crua, tratada)")
        if not a.dry_run:
            concat_mp3(parts, a.out / "emocoes.mp3", work)
    except StopIteration:
        pass
    except AuthError as e:
        print(f"[samples] {e}", file=sys.stderr)
        return 2
    if a.no_emotions and (a.out / "index.json").exists():
        old = json.loads((a.out / "index.json").read_text(encoding="utf-8"))
        names = set(a.only.split(","))
        index = [e for e in old if e["personagem"] not in names] + index
        leia = [(a.out / "LEIA.txt").read_text(encoding="utf-8").rstrip(), ""] + leia[3:]
    (a.out / "index.json").write_text(json.dumps(index, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    (a.out / "LEIA.txt").write_text("\n".join(leia) + "\n", encoding="utf-8")
    print(f"chamadas a API nesta execucao: {calls}; itens no indice: {len(index)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
