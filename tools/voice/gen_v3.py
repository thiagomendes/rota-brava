#!/usr/bin/env python3
"""Rota Brava D19/D21: gera TODAS as vozes do Ep01 v3 e da abertura (cutscenes + narrador) com o elenco aprovado.

Fontes: game/episodes/ep01/v3/ep01_v3_dialogue.json (lines + groups), ep01_v3_cutscenes.json (falas dos planos),
texto em game/i18n/pt_BR*.json, elenco em cast.json, direcao em direction.json (lines > grupo > estilo base).
Cada fala: gemini_tts.synth (cache + refacao automatica) -> treat preset raw -> OGG mono em
game/audio/voice/v3/<chave>.ogg + visemas (abertura da boca pelo envelope RMS, 30 ms).
Catalogo: game/audio/voice/v3/voice_v3_catalog.json (formato do voice_catalog.json + procedencia por take).
Excecoes explicitas (sem take): filhote (late com o som que ja existe).
Para em erro de cota (gemini_tts.QuotaError), grava o que ja fez e informa quantas faltam.

Fala que ja tem take no catalogo com o mesmo texto (text_at_generation == i18n) e OGG presente e reaproveitada
sem chamar a API (o cache fica fora do Git e pode nao existir na sessao). Texto mudou ou --force: gera de novo;
o take antigo so e substituido depois de o novo passar no detector (senao o antigo fica, se o texto nao mudou).

G21i: fala com marcador na legenda (ex.: "{help}", desenhado como glifo do aparelho) tem texto falado proprio em
ep01_v3_dialogue.json -> "spoken" (chave -> texto para a voz). A API recebe o texto falado; text_at_generation
continua sendo o texto da legenda (test_voice_v3 compara com o i18n) e spoken_at_generation guarda o que foi dito.
Fala com "{" sem texto falado e recusada (a voz leria o marcador).

Uso: gen_v3.py [--limit N] [--max-calls N] [--only prefixo] [--force chave,chave] [--dry-run]
--dry-run: lista o que seria gerado (chave, falante, texto falado) sem chamar a API e sem gravar nada.
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


HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
sys.path.insert(0, str(HERE))
import gemini_tts as g  # noqa: E402

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
        it["mission"] = d["lines"].get(it["key"], {}).get("mission", "")
    return list(items.values())


def spoken_texts() -> dict:
    d = json.loads((ROOT / "game/episodes/ep01/v3/ep01_v3_dialogue.json").read_text(encoding="utf-8"))
    return dict(d.get("spoken", {}))


def spoken_of(key: str, tx: dict, sp: dict) -> str:
    """Texto que a voz diz: o texto falado proprio, senao a legenda. Marcador sem texto falado e erro."""
    if key in sp:
        return sp[key]
    if "{" in tx[key]:
        raise SystemExit(f"{key}: legenda com marcador ({tx[key]!r}) sem texto falado em ep01_v3_dialogue.json 'spoken'")
    return tx[key]


def priority(it: dict) -> tuple:
    """Abertura do jogo primeiro, depois M0..M8 (o que Thiago joga), grupos e demais cutscenes no fim."""
    src, m = it["source"], it.get("mission") or ""
    if src in ("cutscene:game_intro", "cutscene:opening"):
        return (0, src)
    if m:
        return (1, m)
    if src.startswith("cutscene:"):
        return (2, src)
    return (3, it.get("group") or "")


def direction_for(dr: dict, key: str, group: str | None) -> dict | None:
    if key in dr["lines"]:
        return dr["lines"][key]
    if group and isinstance(dr["groups"].get(group), dict):
        return dr["groups"][group].get("direction")
    return None


def visemes(wav: Path, dst: Path, key: str, character: str) -> None:
    import numpy as np
    import soundfile as sf
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
    ap.add_argument("--max-calls", type=int, default=0, help="para antes de passar deste numero de pedidos a API")
    ap.add_argument("--force", default="", help="chaves separadas por virgula para gerar de novo mesmo com take")
    ap.add_argument("--dry-run", action="store_true", help="lista o que seria gerado, sem API e sem gravar")
    a = ap.parse_args(argv)
    cast, dr, tx, sp_tx = g.load_json("cast.json"), g.load_json("direction.json"), texts(), spoken_texts()
    if a.dry_run:
        return dry_run(a, tx, sp_tx)
    import soundfile as sf
    from treat import loudness, treat
    OUT.mkdir(parents=True, exist_ok=True)
    (WORK / "raw").mkdir(parents=True, exist_ok=True)
    old = json.loads(CATALOG.read_text(encoding="utf-8")) if CATALOG.exists() else {"lines": []}
    done = {e["id"]: e for e in old["lines"]}
    items = sorted([i for i in inventory() if i["key"].startswith(a.only)], key=priority)
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
        force = key in {k for k in a.force.split(",") if k}
        ogg = OUT / f"{stem}.ogg"
        said = spoken_of(key, tx, sp_tx)
        if key in done and not force and up_to_date(done[key], tx[key], said) and ogg.exists():
            lines.append(done[key])
            continue
        if stopped or (a.limit and made >= a.limit) or (a.max_calls and calls + g.MAX_TRIES > a.max_calls):
            if key in done:
                lines.append(done[key])
            continue
        try:
            p = g.synth(said, c["voice"], style, cast["model"], raw, mode=cast["style_mode"])
        except g.QuotaError as e:
            stopped = str(e)
            if key in done:
                lines.append(done[key])
            continue
        calls += p["api_calls"]
        made += 1
        if p["suspect_instruction_read"]:
            # reprovado pelo detector depois de 3 tentativas: o OGG antigo nao e tocado; fica so se o texto nao mudou
            suspects.append(key)
            if key in done and up_to_date(done[key], tx[key], said):
                lines.append(done[key])
            continue
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
        lines.append({
            "id": key, "character": ch, "speaker": sp, "intent": intent_of(d, sp), "language": "pt_BR", "subtitle": key,
            "type": "gemini_tts", "file": f"res://audio/voice/v3/{stem}.ogg", "duration": dur,
            "peak_dbfs": loud["true_peak_dbtp"], "true_peak_dbtp": loud["true_peak_dbtp"], "lufs": loud["lufs"],
            "visemes": f"res://audio/voice/v3/{stem}.visemes.json", "emotes": it["emotes"], "group": it["group"],
            "origin": it["source"], "status": "provisorio", "tool": "tools/voice/gen_v3.py (Gemini TTS + treat raw)",
            "voice": c["voice"], "model": p["model"], "style_mode": p["style_mode"],
            "style_sha256": hashlib.sha256(style.encode()).hexdigest(), "date": p["date"], "raw_sha256": p["sha256"],
            "sha256": hashlib.sha256(ogg.read_bytes()).hexdigest(), "tries": p["tries"],
            "suspect_instruction_read": p["suspect_instruction_read"], "text_at_generation": tx[key],
            **({"spoken_at_generation": said} if said != tx[key] else {})})
        print(f"[{len(lines):3d}] {key} {dur:.2f} s{' SUSPEITA' if p['suspect_instruction_read'] else ''}", flush=True)
    have = {e["id"] for e in lines}
    pend_keys = [i["key"] for i in items if i["speaker"] not in EXCEPTIONS and i["key"] not in have]
    # takes antigos que nao foram refeitos nesta execucao ficam so se passam no detector
    from detect_double import analyze
    kept = []
    for e in lines:
        det = analyze(ROOT / "game" / e["file"].removeprefix("res://"), e.get("spoken_at_generation", e["text_at_generation"]))
        e["double_check"] = {k: det[k] for k in ("duracao_s", "esperada_s", "razao", "segmentos", "leitura_dupla", "reprova")}
        if not det["reprova"]:
            kept.append(e)
    lines = kept
    have = {e["id"] for e in lines}
    pend_keys = [i["key"] for i in items if i["speaker"] not in EXCEPTIONS and i["key"] not in have]
    pending = len(pend_keys)
    cat = {"version": 1, "_note": "D19/D21: vozes Gemini TTS do Ep01 v3 (elenco cast.json, preset raw). Gerado por "
           "tools/voice/gen_v3.py; formato do voice_catalog.json + procedencia por take. Prompt de estilo inteiro "
           "reconstruivel de cast.json + direction.json (style_sha256).", "exceptions": exceptions,
           "pending": {"reason": stopped or ("reprovadas pelo detector apos 3 tentativas: " + ", ".join(suspects) if suspects else ""), "suspects": suspects, "keys": pend_keys} if pend_keys else {"reason": "", "keys": []},
           "lines": lines}
    CATALOG.write_text(json.dumps(cat, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    total = sum(e["duration"] for e in lines)
    print(json.dumps({"falas_no_catalogo": len(lines), "excecoes": len(exceptions), "chamadas_nesta_execucao": calls,
                      "suspeitas_apos_3": suspects, "duracao_total_s": round(total, 1), "faltam": pending,
                      "parado_por_cota": stopped or None, "tempo_s": round(time.time() - t0)}, ensure_ascii=False, indent=1))
    return 0


def up_to_date(e: dict, text: str, said: str) -> bool:
    return e.get("text_at_generation") == text and e.get("spoken_at_generation", e.get("text_at_generation")) == said


def dry_run(a, tx: dict, sp_tx: dict) -> int:
    old = json.loads(CATALOG.read_text(encoding="utf-8")) if CATALOG.exists() else {"lines": []}
    done = {e["id"]: e for e in old["lines"]}
    force = {k for k in a.force.split(",") if k}
    todo = []
    for it in sorted([i for i in inventory() if i["key"].startswith(a.only)], key=priority):
        key, sp = it["key"], it["speaker"]
        if sp in EXCEPTIONS:
            continue
        said = spoken_of(key, tx, sp_tx)
        ogg = OUT / (key.replace(".", "_") + ".ogg")
        if key in done and key not in force and up_to_date(done[key], tx[key], said) and ogg.exists():
            continue
        todo.append({"key": key, "speaker": sp, "voice": g.load_json("cast.json")["characters"][SPEAKER_CAST[sp]]["voice"],
                     "subtitle": tx[key], "spoken": said})
    if a.limit:
        todo = todo[:a.limit]
    for i, t in enumerate(todo, 1):
        extra = "" if t["spoken"] == t["subtitle"] else f"  (legenda: {t['subtitle']})"
        print(f"[{i:3d}] {t['key']} [{t['speaker']}/{t['voice']}] fala: {t['spoken']}{extra}")
    print(json.dumps({"seriam_geradas": len(todo), "api": "nao chamada (--dry-run)"}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
