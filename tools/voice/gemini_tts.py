#!/usr/bin/env python3
"""Rota Brava D19: gera uma fala com o Gemini TTS (API nativa generateContent).

A chave NUNCA passa por aqui: o script envia `x-goog-api-key: proxy-injected`
e o proxy da sessao substitui pelo segredo. Nada de chave em log ou JSON.

Saida: <out>.wav (PCM 16 bits mono, 24 kHz, bruto) + <out>.json (procedencia).
Cache: tools/voice/.cache/<sha256 da entrada>.wav (fora do Git).

Formato da requisicao (verificado por chamada real em 2026-11-25; a pagina
oficial ai.google.dev nao era acessivel pela rede desta sessao):
  systemInstruction.parts[0].text = estilo (padrao, --style-mode system) e
  contents[0].parts[0].text = texto falado; ou "<estilo>: <texto>" (--style-mode prefix)
  generationConfig.responseModalities = ["AUDIO"]
  generationConfig.speechConfig.voiceConfig.prebuiltVoiceConfig.voiceName
Resposta: candidates[0].content.parts[0].inlineData, base64: audio/L16;rate=24000 cru
(gemini-2.5-*) ou audio/wav com cabecalho (gemini-3.8-*); os dois viram WAV aqui.
"""
from __future__ import annotations

import argparse
import base64
import datetime as dt
import hashlib
import json
import os
import re
import ssl
import sys
import time
import urllib.error
import urllib.request
import wave
from pathlib import Path

ENDPOINT = "https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent"
DEFAULT_MODEL = "gemini-3.8-flash-tts"
CACHE = Path(__file__).resolve().parent / ".cache"
MIN_INTERVAL_S = float(os.environ.get("RB_TTS_MIN_INTERVAL", "6.5"))  # limite de taxa local: Tier 1 = 10 pedidos/min (D19e)
_STAMP = CACHE / ".last_call"


MAX_TRIES = int(os.environ.get("RB_TTS_TRIES", "3"))
SUSPECT_RATIO = 1.8
VOWELS = set("aeiouáéíóúâêôãõày")


def expected_duration(text: str) -> float:
    """Estimativa grosseira: ~1 silaba por grupo de vogais, ~5 silabas/s + 0,3 s por pausa e 0,6 s de margem."""
    t = text.lower()
    syl, prev = 0, False
    for ch in t:
        v = ch in VOWELS
        syl += v and not prev
        prev = v
    return syl / 5.0 + 0.3 * sum(t.count(c) for c in ".!?,:") + 0.6


class AuthError(RuntimeError):
    pass


class QuotaError(RuntimeError):
    """429 persistente (cota esgotada): quem chama deve parar e manter o cache."""


HERE = Path(__file__).resolve().parent


def load_json(name: str) -> dict:
    return json.loads((HERE / name).read_text(encoding="utf-8"))


def directed_style(character: str, line: str | None = None, direction: dict | None = None) -> str:
    """Estilo base do personagem (cast.json) + direcao da fala (direction.json ou dict dado)."""
    cast, dr = load_json("cast.json"), load_json("direction.json")
    parts = [cast["characters"][character]["style"]]
    d = direction or (dr["lines"].get(line) if line else None)
    if d:
        parts.append(f"Emocao: {d['emotion']}; {dr['energy_text'][str(d['energy'])]}; {dr['pace_text'][d['pace']]}.")
        parts.append(f"Atuacao: {d['note']}.")
    parts.append("Publico de 4 a 8 anos: tom acolhedor, sem medo e sem bronca. Leia so a transcricao.")
    return "\n".join(parts)


def build_prompt(text: str, style: str) -> str:
    return f"{style.strip()}: {text.strip()}" if style.strip() else text.strip()


STYLE_MODES = ("notes", "once", "once_t", "paren", "system", "prefix")
TEMP_LOW = 0.4


def request_body(text: str, voice: str, style: str, mode: str = "notes") -> dict:
    """mode=system: estilo em systemInstruction e so o texto falado em contents.
    mode=prefix: "<estilo>: <texto>" (forma dos exemplos do Google; pode ler o estilo em voz alta)."""
    if mode == "prefix":
        spoken = build_prompt(text, style)
    elif mode == "notes" and style.strip():
        spoken = (f"### NOTAS DE DIRECAO (nao ler em voz alta)\n{style.strip()}\n\n"
                  f"### TRANSCRICAO (ler somente isto, exatamente)\n{text.strip()}")
    elif mode in ("once", "once_t") and style.strip():
        spoken = (f"### NOTAS DE DIRECAO (nao ler em voz alta)\n{style.strip()}\n"
                  "Leia a transcricao UMA unica vez, do inicio ao fim, e pare. Nao repita, nao acrescente palavras.\n\n"
                  f"### TRANSCRICAO (uma unica leitura)\n{text.strip()}")
    elif mode == "paren" and style.strip():
        short = next((ln for ln in style.splitlines() if ln.startswith("Emocao:")), style.splitlines()[0])
        spoken = f"({short.removeprefix('Emocao: ').rstrip('.')}) {text.strip()}"
    else:
        spoken = text.strip()
    body = {
        "contents": [{"parts": [{"text": spoken}]}],
        "generationConfig": {
            "responseModalities": ["AUDIO"],
            "speechConfig": {"voiceConfig": {"prebuiltVoiceConfig": {"voiceName": voice}}},
        },
    }
    if mode.endswith("_t"):
        body["generationConfig"]["temperature"] = TEMP_LOW
    if mode == "system" and style.strip():
        body["systemInstruction"] = {"parts": [{"text": style.strip()}]}
    return body


def input_hash(model: str, voice: str, style: str, text: str, mode: str = "notes") -> str:
    key = json.dumps({"model": model, "voice": voice, "style": style, "text": text, "mode": mode}, ensure_ascii=False, sort_keys=True)
    return hashlib.sha256(key.encode("utf-8")).hexdigest()


def _ssl_ctx() -> ssl.SSLContext:
    for c in (os.environ.get("SSL_CERT_FILE"), os.environ.get("REQUESTS_CA_BUNDLE"), "/root/.ccr/ca-bundle.crt"):
        if c and Path(c).exists():
            return ssl.create_default_context(cafile=c)
    return ssl.create_default_context()


def _rate_limit() -> None:
    CACHE.mkdir(parents=True, exist_ok=True)
    try:
        last = float(_STAMP.read_text())
    except (OSError, ValueError):
        last = 0.0
    wait = MIN_INTERVAL_S - (time.time() - last)
    if wait > 0:
        time.sleep(wait)
    _STAMP.write_text(str(time.time()))


def call_api(model: str, body: dict, retries: int = 5) -> tuple[bytes, str, int]:
    """Devolve (pcm, mime, chamadas_feitas). Repete em 429/5xx com espera exponencial."""
    data = json.dumps(body).encode("utf-8")
    calls = 0
    for attempt in range(retries + 1):
        _rate_limit()
        req = urllib.request.Request(ENDPOINT.format(model=model), data=data, method="POST", headers={
            "Content-Type": "application/json", "x-goog-api-key": "proxy-injected"})
        calls += 1
        try:
            with urllib.request.urlopen(req, timeout=120, context=_ssl_ctx()) as r:
                resp = json.loads(r.read())
            part = resp["candidates"][0]["content"]["parts"][0]["inlineData"]
            return base64.b64decode(part["data"]), part.get("mimeType", ""), calls
        except urllib.error.HTTPError as e:
            if e.code in (401, 403):
                raise AuthError(
                    f"HTTP {e.code}: a API nativa recusou a autenticacao. O segredo do ambiente precisa ser "
                    "injetado no cabecalho x-goog-api-key (nao Bearer). Nada foi gerado.") from None
            last_code = e.code
            if e.code == 429:
                body = e.read().decode("utf-8", "replace")
                if "per_day" in body or "PerDay" in body:  # cota diaria: nao adianta esperar minutos
                    retry = body.split("Please retry in ")[1].split("s.")[0] + "s" if "Please retry in " in body else "?"
                    raise QuotaError(f"cota diaria do modelo {model} esgotada (tentar de novo em {retry})") from None
            if e.code == 429 or e.code >= 500:
                ra = e.headers.get("Retry-After")
                wait = float(ra) if ra and ra.isdigit() else min(60.0, 5.0 * 2 ** attempt)
                print(f"[gemini_tts] HTTP {e.code}, nova tentativa em {wait:.0f} s", file=sys.stderr)
                time.sleep(wait)
                continue
            raise RuntimeError(f"HTTP {e.code}: {e.read()[:300]!r}") from None
        except (urllib.error.URLError, TimeoutError) as e:
            wait = min(60.0, 5.0 * 2 ** attempt)
            print(f"[gemini_tts] rede: {e}; nova tentativa em {wait:.0f} s", file=sys.stderr)
            time.sleep(wait)
    if locals().get("last_code") == 429:
        raise QuotaError("HTTP 429 persistente depois de todas as tentativas (cota?)")
    raise RuntimeError("esgotou as tentativas (429/5xx/rede)")


def rate_from_mime(mime: str) -> int:
    m = re.search(r"rate=(\d+)", mime)
    return int(m.group(1)) if m else 24000


def write_wav(path: Path, pcm: bytes, rate: int) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if pcm[:4] == b"RIFF":  # gemini-3.8-*: mimeType audio/wav, ja com cabecalho
        path.write_bytes(pcm)
        return
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes(pcm)


def synth(text: str, voice: str, style: str, model: str, out: Path, dry_run: bool = False,
          mode: str = "notes") -> dict:
    h = input_hash(model, voice, style, text, mode)
    body = request_body(text, voice, style, mode)
    if dry_run:
        return {"dry_run": True, "endpoint": ENDPOINT.format(model=model), "body": body, "input_sha256": h}
    calls, cache_hit, suspect, tries = 0, True, False, 0
    exp = expected_duration(text)
    for tries in range(1, MAX_TRIES + 1):
        # tentativa 1 usa o hash da entrada; refacoes ganham sufixo, para nao reler o mesmo cache
        cached = CACHE / (f"{h}.wav" if tries == 1 else f"{h}.r{tries}.wav")
        if not cached.exists():
            cache_hit = False
            pcm, mime, c = call_api(model, body)
            calls += c
            write_wav(cached, pcm, rate_from_mime(mime))
        pcm_wav = cached.read_bytes()
        with wave.open(str(cached)) as w:
            dur = w.getnframes() / w.getframerate()
        from detect_double import analyze  # leitura dupla por silencio + duracao > 1,35x calibrada
        det = analyze(cached, text)
        suspect = det["reprova"]
        if not suspect:
            break
        print(f"[gemini_tts] reprovado pelo detector ({dur:.1f} s, esperado {exp:.1f} s, dupla={bool(det['leitura_dupla'])}); "
              f"tentativa {tries}/{MAX_TRIES}", file=sys.stderr)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_bytes(pcm_wav)
    with wave.open(str(out)) as w:
        dur = w.getnframes() / w.getframerate()
        rate = w.getframerate()
    prov = {
        "tool": "tools/voice/gemini_tts.py (Gemini API nativa, generateContent)",
        "model": model, "voice": voice, "style_prompt": style, "style_mode": mode, "text": text,
        "prompt_sent": body["contents"][0]["parts"][0]["text"], "input_sha256": h,
        "sha256": hashlib.sha256(pcm_wav).hexdigest(), "sample_rate": rate, "duration_s": round(dur, 3),
        "date": dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds"),
        "cache_hit": cache_hit, "api_calls": calls, "tries": tries,
        "expected_duration_s": round(exp, 2), "suspect_instruction_read": suspect,
        "status": "provisorio (aguarda aprovacao de Thiago; termos de uso a confirmar)",
    }
    out.with_suffix(".json").write_text(json.dumps(prov, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return prov


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[1])
    ap.add_argument("--text", required=True)
    ap.add_argument("--voice", help="voz pre-pronta (ex.: Leda); padrao: a do personagem em cast.json")
    ap.add_argument("--character", help="chave em cast.json; monta o estilo base + direcao")
    ap.add_argument("--line", help="chave da fala em direction.json (com --character)")
    ap.add_argument("--style", default="", help="instrucao de estilo em linguagem natural")
    ap.add_argument("--model", default=DEFAULT_MODEL)
    ap.add_argument("--out", required=True, type=Path, help="arquivo .wav de saida")
    ap.add_argument("--style-mode", choices=STYLE_MODES, default="notes")
    ap.add_argument("--dry-run", action="store_true", help="mostra a requisicao sem chamar a API")
    a = ap.parse_args(argv)
    if a.character:
        a.style = directed_style(a.character, a.line) + (("\n" + a.style) if a.style else "")
        a.voice = a.voice or load_json("cast.json")["characters"][a.character]["voice"]
    if not a.voice:
        ap.error("informe --voice ou --character")
    try:
        r = synth(a.text, a.voice, a.style, a.model, a.out, a.dry_run, a.style_mode)
    except AuthError as e:
        print(f"[gemini_tts] {e}", file=sys.stderr)
        return 2
    print(json.dumps(r, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
