#!/usr/bin/env python3
"""Rota Brava D19: mede a taxa de repeticao por formato de prompt (1 tentativa por chamada, sem refacao).

Mesmas N falas (abertura/M0-M2) em cada formato; detector detect_double.analyze. Saida em
captures/d19/prompt_trial/<formato>/ + report.json. Para em cota.
Uso: RB_TTS_TRIES=1 prompt_trial.py --formats once,once_t,paren --n 10
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import gemini_tts as g  # noqa: E402
import gen_v3  # noqa: E402
from detect_double import analyze  # noqa: E402

OUT = Path("/home/user/rota-brava/captures/d19/prompt_trial")


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--formats", default="once,once_t,paren")
    ap.add_argument("--n", type=int, default=10)
    a = ap.parse_args(argv)
    cast, dr, tx = g.load_json("cast.json"), g.load_json("direction.json"), gen_v3.texts()
    items = [i for i in gen_v3.inventory() if i["speaker"] not in gen_v3.EXCEPTIONS][: a.n]
    rep: dict = {}
    try:
        for fmt in a.formats.split(","):
            rows = []
            for it in items:
                ch = gen_v3.SPEAKER_CAST[it["speaker"]]
                d = gen_v3.direction_for(dr, it["key"], it["group"])
                style = g.directed_style(ch, direction=d) if d else g.directed_style(ch)
                w = OUT / fmt / (it["key"].replace(".", "_") + ".wav")
                p = g.synth(tx[it["key"]], cast["characters"][ch]["voice"], style, cast["model"], w, mode=fmt)
                r = analyze(w, tx[it["key"]])
                rows.append({"id": it["key"], "calls": p["api_calls"], **{k: r[k] for k in ("duracao_s", "esperada_s", "razao", "leitura_dupla", "reprova")}})
                print(f"{fmt:7s} {it['key']:40s} x{r['razao']:.2f} {'REPROVA' if r['reprova'] else 'ok'}", flush=True)
            rep[fmt] = {"n": len(rows), "reprovados": sum(r["reprova"] for r in rows), "duplas": sum(bool(r["leitura_dupla"]) for r in rows),
                        "chamadas": sum(r["calls"] for r in rows), "rows": rows}
    except g.QuotaError as e:
        rep["_parado"] = str(e)
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "report.json").write_text(json.dumps(rep, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print(json.dumps({k: (v if k.startswith("_") else {kk: vv for kk, vv in v.items() if kk != "rows"}) for k, v in rep.items()}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
