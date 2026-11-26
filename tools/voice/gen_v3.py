#!/usr/bin/env python3
"""Rota Brava D19/D21: gera TODAS as vozes do Ep01 v3 e da abertura (cutscenes + narrador) com o elenco aprovado.

Fontes: game/episodes/ep01/v3/ep01_v3_dialogue.json (lines + groups), ep01_v3_cutscenes.json (falas dos planos),
texto em game/i18n/pt_BR*.json, elenco em cast.json, direcao em direction.json (lines > grupo > estilo base).
Cada fala: gemini_tts.synth (cache + refacao automatica) -> treat preset raw -> OGG mono em
game/audio/voice/v3/<chave>.ogg + visemas (abertura da boca pelo envelope RMS, 30 ms).
Catalogo: game/audio/voice/v3/voice_v3_catalog.json (formato do voice_catalog.json + procedencia por take).
Excecoes explicitas (sem take): filhote (late com o som que ja existe).
Para em erro de cota (gemini_tts.QuotaError), grava o que ja fez e informa quantas faltam.

Uso: gen_v3.py [--limit N] [--only prefixo]
"""
from __future__ import annotations

import argparse
import glob
import hashlib
import json
import subprocess
import sys
import time
from pathlib import Path

import numpy as np
import soundfile as sf

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
sys.path.insert(0, str(HERE))
import gemini_tts as g  # noqa: E402
from treat import loudness, treat  # noqa: E402

OUT = ROOT / "game/audio/voice/v3"
WORK = Path("/home/user/rota-brava/captures/d19/v3_takes")
CATALOG = OUT / "voice_v3_catalog.json"
SPEAKER_CAST = {"tracker": "rastro", "climber": "pico", "pilot": "leme", "captain": "capitao", "radio": "farol7",
                "vendor": "dona_amora", "narrator": "narrador"}
EXCEPTIONS = {"pup": "filhote late com o som que ja existe (sem TTS)"}
INTENT_BY_EMOTION = [("pergunta", "pergunta"), ("dúvida", "pergunta"), ("descoberta", "descoberta"),
                     ("surpresa", "descoberta"), ("alegria", "alegria"), ("orgulho", "alegria"), ("dica", "dica")]


def texts() -> dict:
    t: dict = {}
    for f in sorted(glob.glob(str(ROOT / "game/i18n/pt_BR*.json"))):
        t.update(json.loads(Path(f).read_text(encoding="utf-8")))
    return t


def inventory() -> list[dict]:
    d = json.loads((ROOT / "game/episodes/ep01/v3/ep01_v3_dialogue.json").read_text(encoding="utf-8"))
    c = json.loads((ROOT / "game/episodes/ep01/v3/ep01_v3_cutscenes.json").read_text(encoding="utf-8"))
    group_of: dict = {}
    for gid, ks in d["groups"].items():
        for k in ks:
            group_of.setdefault(k, gid)
    items: dict = {}
    for k, v in d["lines"].items():
        items[k] = {"key": k, "speaker": v["speaker"], "emotes": v.get("emotes", []), "source": "dialogue"}
    for gid, ks in d["groups"].items():
        for k in ks:
            items.setdefault(k, {"key": k, "speaker": d["lines"].get(k, {}).get("speaker", ""), "emotes": [], "source": "group"})
    for s in c["scenes"]:
        for sh in s["shots"]:
            ln = sh.get("line")
            if ln:
                items.setdefault(ln["key"], {"key": ln["key"], "speaker": ln["speaker"], "emotes": [], "source": "cutscene:" + s["id"]})
    for it in items.values():
        it["group"] = group_of.get(it["key"])
    return list(items.values())


def direction_for(dr: dict, key: str, group: str | None) -> dict | None:
    if key in dr["lines"]:
        return dr["lines"][key]
    if group and isinstance(dr["groups"].get(group), dict):
        return dr["groups"][group].get("direction")
    return None


def visemes(wav: Path, dst: Path, key: str, character: str) -> None:
    x, sr = sf.read(str(wav), dtype="float64", always_2d=True)
    m = x.mean(axis=1)
    hop = int(0.03 * sr)
    n = max(1, len(m) // hop)
    r = np.sqrt(np.mean(m[:n * hop].reshape(n, hop) ** 2, axis=1))
    top = np.percentile(r, 95) + 1e-9
    o = np.clip((r / top - 0.08) / 0.92, 0, 1)
    dst.write_text(json.dumps({"id": key, "character": character, "intent": "normal", "duration": round(len(m) / sr, 3),
                               "frame_s": 0.03, "open": [round(float(v), 3) for v in o]}, indent=1) + "\n", encoding="utf-8")


def intent_of(d: dict | None, speaker: str) -> str:
    if speaker == "radio":
        return "radio"
    e = (d or {}).get("emotion", "")
    for word, it in INTENT_BY_EMOTION:
        if word in e:
            return it
    return "normal"


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--limit", type=int, default=0)
    ap.add_argument("--only", default="")
    a = ap.parse_args(argv)
    cast, dr, tx = g.load_json("cast.json"), g.load_json("direction.json"), texts()
    OUT.mkdir(parents=True, exist_ok=True)
    (WORK / "raw").mkdir(parents=True, exist_ok=True)
    old = json.loads(CATALOG.read_text(encoding="utf-8")) if CATALOG.exists() else {"lines": []}
    done = {e["id"]: e for e in old["lines"]}
    items = [i for i in inventory() if i["key"].startswith(a.only)]
    lines, exceptions, calls, suspects, stopped, made = [], [], 0, [], "", 0
    t0 = time.time()
    for it in items:
        key, sp = it["key"], it["speaker"]
        if sp in EXCEPTIONS:
            exceptions.append({"id": key, "reason": EXCEPTIONS[sp]})
            continue
        ch = SPEAKER_CAST[sp]
        c = cast["characters"][ch]
        d = direction_for(dr, key, it["group"])
        style = g.directed_style(ch, direction=d) if d else g.directed_style(ch)
        stem = key.replace(".", "_")
        raw = WORK / "raw" / f"{stem}.wav"
        if stopped or (a.limit and made >= a.limit):
            if key in done:
                lines.append(done[key])
            continue
        try:
            p = g.synth(tx[key], c["voice"], style, cast["model"], raw, mode=cast["style_mode"])
        except g.QuotaError as e:
            stopped = str(e)
            if key in done:
                lines.append(done[key])
            continue
        calls += p["api_calls"]
        made += 1
        ogg = OUT / f"{stem}.ogg"
        if not (key in done and done[key].get("raw_sha256") == p["sha256"] and ogg.exists()):
            tw = WORK / f"{stem}_raw.wav"
            treat(c["preset"], raw, tw)
            subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", str(tw), "-ac", "1", "-c:a",
                            "libvorbis", "-q:a", "5", str(ogg)], check=True)
            visemes(tw, OUT / f"{stem}.visemes.json", key, ch)
            loud = loudness(tw)
            info = sf.info(str(tw))
            dur = round(info.frames / info.samplerate, 3)
        else:
            loud = {"lufs": done[key]["lufs"], "true_peak_dbtp": done[key]["true_peak_dbtp"]}
            dur = done[key]["duration"]
        if p["suspect_instruction_read"]:
            suspects.append(key)
        lines.append({
            "id": key, "character": ch, "speaker": sp, "intent": intent_of(d, sp), "language": "pt_BR", "subtitle": key,
            "type": "gemini_tts", "file": f"res://audio/voice/v3/{stem}.ogg", "duration": dur,
            "peak_dbfs": loud["true_peak_dbtp"], "true_peak_dbtp": loud["true_peak_dbtp"], "lufs": loud["lufs"],
            "visemes": f"res://audio/voice/v3/{stem}.visemes.json", "emotes": it["emotes"], "group": it["group"],
            "origin": it["source"], "status": "provisorio", "tool": "tools/voice/gen_v3.py (Gemini TTS + treat raw)",
            "voice": c["voice"], "model": p["model"], "style_mode": p["style_mode"],
            "style_sha256": hashlib.sha256(style.encode()).hexdigest(), "date": p["date"], "raw_sha256": p["sha256"],
            "sha256": hashlib.sha256(ogg.read_bytes()).hexdigest(), "tries": p["tries"],
            "suspect_instruction_read": p["suspect_instruction_read"], "text_at_generation": tx[key]})
        print(f"[{len(lines):3d}] {key} {dur:.2f} s{' SUSPEITA' if p['suspect_instruction_read'] else ''}", flush=True)
    have = {e["id"] for e in lines}
    pend_keys = [i["key"] for i in items if i["speaker"] not in EXCEPTIONS and i["key"] not in have]
    pending = len(pend_keys)
    cat = {"version": 1, "_note": "D19/D21: vozes Gemini TTS do Ep01 v3 (elenco cast.json, preset raw). Gerado por "
           "tools/voice/gen_v3.py; formato do voice_catalog.json + procedencia por take. Prompt de estilo inteiro "
           "reconstruivel de cast.json + direction.json (style_sha256).", "exceptions": exceptions,
           "pending": {"reason": stopped or "", "keys": pend_keys} if pend_keys else {"reason": "", "keys": []},
           "lines": lines}
    CATALOG.write_text(json.dumps(cat, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    total = sum(e["duration"] for e in lines)
    print(json.dumps({"falas_no_catalogo": len(lines), "excecoes": len(exceptions), "chamadas_nesta_execucao": calls,
                      "suspeitas_apos_3": suspects, "duracao_total_s": round(total, 1), "faltam": pending,
                      "parado_por_cota": stopped or None, "tempo_s": round(time.time() - t0)}, ensure_ascii=False, indent=1))
    return 0


if __name__ == "__main__":
    sys.exit(main())
