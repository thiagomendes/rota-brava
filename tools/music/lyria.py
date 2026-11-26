#!/usr/bin/env python3
"""Rota Brava D20: trilha pelo Lyria (Gemini API nativa, generateContent).

Monta o prompt a partir da biblia musical (tools/music/music_bible.json) + cena,
chama o modelo, salva o audio (MP3) + JSON de procedencia, com cache por hash
da entrada em tools/music/.cache/ (fora do Git), limite de taxa e repeticao em
429/5xx. Chave: so `x-goog-api-key: proxy-injected` (o proxy injeta o segredo).

Uso:
  lyria.py --scene village --take 1 --out captures/d19/musica/village_1.mp3 [--model lyria-3-pro-preview]
  lyria.py --prompt "..." --out x.mp3        (prompt livre)
  lyria.py --scene village --dry-run
  --ref audio.mp3   anexa audio como referencia (inlineData); ver d20_trilhas.md se o modelo aceita.
"""
from __future__ import annotations

import argparse
import base64
import datetime as dt
import hashlib
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "voice"))
import gemini_tts as g  # noqa: E402  (reaproveita taxa, SSL, repeticao e erro de autenticacao)

CACHE = HERE / ".cache"
DEFAULT_MODEL = "lyria-3-pro-preview"
QUOTA_HINTS = ("quota", "RESOURCE_EXHAUSTED", "exceeded")


class QuotaError(RuntimeError):
    pass


def bible() -> dict:
    return json.loads((HERE / "music_bible.json").read_text(encoding="utf-8"))


def scene_prompt(scene: str, take: int = 1) -> str:
    b = bible()
    if scene in b["stings"]:
        s = b["stings"][scene]
        return " ".join([
            "Instrumental only, no vocals, no singing, no spoken words.",
            f"Sound cue for a cheerful 3D adventure game for kids aged 4 to 8, '{b['title']}'.",
            f"Fixed palette: {b['palette_prompt']}.",
            f"Main theme (leitmotif): {b['theme_prompt']}.",
            f"Cue: {s['prompt']}", f"Key: {s['key']}. Tempo: {s['bpm']} BPM.",
            b["global_prompt"].split(" Seamless loop")[0]]) + (f" Take {take}." if take > 1 else "")
    s = b["scenes"][scene]
    parts = [
        "Instrumental only, no vocals, no singing, no spoken words.",
        f"Music for a cheerful 3D adventure game for kids aged 4 to 8, '{b['title']}'.",
        f"Fixed palette: {b['palette_prompt']}.",
        f"Main theme (leitmotif): {b['theme_prompt']}.",
        f"Scene: {s['prompt']}",
        f"Key: {s['key']}. Tempo: {s['bpm']} BPM, steady, no tempo changes.",
        f"Energy {s['energy']}/3. {s['form']}",
        b["global_prompt"],
    ]
    if take > 1:
        parts.append(f"Take {take}: a different arrangement idea within the same rules.")
    return " ".join(parts)


def request_body(prompt: str, ref: Path | None) -> dict:
    parts: list[dict] = [{"text": prompt}]
    if ref:
        mime = "audio/mpeg" if ref.suffix == ".mp3" else "audio/wav"
        parts.append({"inlineData": {"mimeType": mime, "data": base64.b64encode(ref.read_bytes()).decode()}})
    return {"contents": [{"parts": parts}]}


def call(model: str, body: dict) -> tuple[bytes, str, str, int]:
    g.CACHE = CACHE  # carimbo de taxa proprio
    try:
        data = json.dumps(body).encode()
        import urllib.error
        import urllib.request
        calls = 0
        for attempt in range(4):
            g._rate_limit()
            req = urllib.request.Request(g.ENDPOINT.format(model=model), data=data, method="POST", headers={
                "Content-Type": "application/json", "x-goog-api-key": "proxy-injected"})
            calls += 1
            try:
                with urllib.request.urlopen(req, timeout=600, context=g._ssl_ctx()) as r:
                    resp = json.loads(r.read())
                break
            except urllib.error.HTTPError as e:
                msg = e.read()[:600].decode("utf-8", "replace")
                if e.code in (401, 403):
                    raise g.AuthError(f"HTTP {e.code}: autenticacao recusada (cabecalho x-goog-api-key).") from None
                if e.code == 429 and any(h in msg for h in QUOTA_HINTS):
                    raise QuotaError(f"HTTP 429 de cota: {msg[:300]}") from None
                if e.code == 429 or e.code >= 500:
                    import time
                    time.sleep(min(60, 10 * 2 ** attempt))
                    continue
                raise RuntimeError(f"HTTP {e.code}: {msg[:400]}") from None
        else:
            raise RuntimeError("esgotou as tentativas")
    finally:
        pass
    audio, mime, text = b"", "", ""
    for p in resp["candidates"][0]["content"]["parts"]:
        if "inlineData" in p:
            audio += base64.b64decode(p["inlineData"]["data"])
            mime = p["inlineData"].get("mimeType", mime)
        elif "text" in p:
            text += p["text"]
    if not audio:
        raise RuntimeError(f"resposta sem audio; texto: {text[:300]}")
    return audio, mime, text, calls


def generate(prompt: str, model: str, out: Path, ref: Path | None = None, meta: dict | None = None) -> dict:
    h = hashlib.sha256(json.dumps({"model": model, "prompt": prompt,
                                   "ref": hashlib.sha256(ref.read_bytes()).hexdigest() if ref else None},
                                  sort_keys=True).encode()).hexdigest()
    CACHE.mkdir(parents=True, exist_ok=True)
    cached, side = CACHE / f"{h}.bin", CACHE / f"{h}.json"
    calls = 0
    if cached.exists():
        info = json.loads(side.read_text())
    else:
        audio, mime, text, calls = call(model, request_body(prompt, ref))
        cached.write_bytes(audio)
        info = {"mime": mime, "text_part": text}
        side.write_text(json.dumps(info, ensure_ascii=False))
    data = cached.read_bytes()
    ext = ".mp3" if "mpeg" in info["mime"] else ".wav"
    out = out.with_suffix(ext)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_bytes(data)
    prov = {"tool": "tools/music/lyria.py (Gemini API nativa, generateContent)", "model": model, "prompt": prompt,
            "reference_audio": str(ref) if ref else None, "mime": info["mime"], "text_part": info["text_part"],
            "input_sha256": h, "sha256": hashlib.sha256(data).hexdigest(),
            "date": dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds"),
            "cache_hit": calls == 0, "api_calls": calls, "file": str(out),
            "status": "provisorio (aguarda aprovacao de Thiago; termos de uso a confirmar)", **(meta or {})}
    out.with_suffix(".json").write_text(json.dumps(prov, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return prov


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--scene")
    ap.add_argument("--take", type=int, default=1)
    ap.add_argument("--prompt")
    ap.add_argument("--model", default=DEFAULT_MODEL)
    ap.add_argument("--ref", type=Path)
    ap.add_argument("--out", type=Path)
    ap.add_argument("--dry-run", action="store_true")
    a = ap.parse_args(argv)
    prompt = a.prompt or scene_prompt(a.scene, a.take)
    if a.dry_run or not a.out:
        print(prompt)
        return 0
    try:
        print(json.dumps(generate(prompt, a.model, a.out, a.ref, {"scene": a.scene, "take": a.take}), ensure_ascii=False, indent=2))
    except (g.AuthError, QuotaError) as e:
        print(f"[lyria] {e}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
