"""Lista as falas do episodio a partir dos catalogos de texto (fonte unica: game/i18n e game/episodes).

Regras (RB-R1 D2):
- falante = 3o segmento da chave `ep01.<cena>.<falante>.<nome>`;
- `radio`/`team`, dicas faladas (`hint_spoken*`) e objetivos vao ao RADIO (Farol 7, Piper);
- herois, piloto (captain), filhote (pup) e moradores falam em BALBUCIO.
Se existirem `game/episodes/ep01/ep01_dialogue.json` (emotes/intencao/falante) e `game/i18n/pt_BR.radio.json`,
sao lidos e tem prioridade: basta rodar ./tools/gen-audio.ps1 de novo quando chegarem.
"""
from __future__ import annotations

import re

from common import GAME, load_json

SPEAKERS = {"tracker": "Rastro", "climber": "Pico", "pilot": "Leme", "captain": "captain", "pup": "pup",
            "radio": "radio", "team": "team", "villager_a": "villager_a", "villager_b": "villager_b",
            "villager_c": "villager_c"}
RADIO_SPEAKERS = {"radio", "team"}
KEY = re.compile(r"^ep01\.([a-z_]+)\.([a-z_]+)\.([a-z_0-9]+)$")

URGENT = ("segura", "escorreguei", "devagar", "cadê", "ei!", "muito perto", "buzina no porto")
DISCOVERY = ("olha lá", "achamos", "linha presa", "boia contornada", "alinhado", "tem algo estranho", "pronta")
JOY = ("obrigado", "vamos para casa", "riu", "fom fom", "próximo", "aqui! aqui")


def _intent(name: str, text: str) -> str:
    t = text.lower()
    if name.startswith("hint"):
        return "dica"
    if any(w in t for w in URGENT):
        return "urgencia"
    if t.rstrip().endswith("?"):
        return "pergunta"
    if any(w in t for w in DISCOVERY):
        return "descoberta"
    if any(w in t for w in JOY):
        return "alegria"
    return "normal"


def gather() -> list[dict]:
    texts: dict[str, str] = {}
    for f in ["pt_BR.json", "pt_BR.audio.json", "pt_BR.radio.json"]:
        p = GAME / "i18n" / f
        if p.exists():
            texts.update(load_json(p))
    dialogue = {}
    dp = GAME / "episodes" / "ep01" / "ep01_dialogue.json"
    if dp.exists():
        d = load_json(dp)
        for e in (d.get("lines", d) if isinstance(d, dict) else d):
            if isinstance(e, dict) and "id" in e:
                dialogue[e["id"]] = e
    out = []
    for key, text in texts.items():
        m = KEY.match(key)
        if not m:
            continue
        scene, spk, name = m.groups()
        dl = dialogue.get(key, {})
        spk = dl.get("speaker", spk)
        if name == "objective" or name.startswith("objective"):
            continue  # objetivos: texto de HUD; o radio cobre a instrucao essencial via hint_spoken
        if spk not in SPEAKERS:
            continue
        kind = "radio" if spk in RADIO_SPEAKERS or name.startswith("hint_spoken") else "babble"
        out.append({
            "id": key, "speaker": spk, "character": SPEAKERS[spk] if kind == "babble" else ("team" if spk == "team" else "radio"),
            "scene": scene, "text": text, "type": kind,
            "intent": dl.get("intent", "radio" if kind == "radio" else _intent(name, text)),
            "emotes": dl.get("emotes", []),
            "origin_speaker": m.group(2),
        })
    out.sort(key=lambda e: e["id"])
    return out


if __name__ == "__main__":
    for e in gather():
        print(e["type"], e["speaker"], e["intent"], e["id"], "|", e["text"])
