"""Gera game/audio/sfx_catalog.json a partir de source_audio/report.json (medidas reais dos WAV gerados)
e source_audio/env.json (ambiente de geracao). Biblioteca padrao apenas."""
import json, os
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
rep = json.load(open(os.path.join(HERE, "report.json"), encoding="utf-8"))
TOOLS = {"sfx": "source_audio/sfx.py", "ambience": "source_audio/ambience.py", "music": "source_audio/music/themes.py"}
entries = []


def add(name, m, kind, bus, loop, caption=None, tool=""):
    entries.append({
        "name": name, "file": m["file"], "type": kind, "duration": m["duration_s"], "peak_dbfs": m["peak_dbfs"],
        "true_peak_est_dbfs": m["true_peak_est_dbfs"], "rms_dbfs": m["rms_dbfs"], "sample_rate": m["sample_rate"],
        "channels": m["channels"], "bus": bus, "gain_db": m.get("gain_db", 0.0), "loop": loop,
        "caption_key": caption, "status": "provisorio" if kind != "music" else "esboco", "tool": tool,
        "source": "sintese original por script do projeto; sem material de terceiros", "description": m.get("description", ""),
    })


for n, m in rep["sfx"].items():
    add(n, m, m["type"], m["bus"], m["loop"], m.get("caption_key"), TOOLS["sfx"])
for n, m in rep["ambience"].items():
    add(n, m, "ambience", "Ambiente", True, None, TOOLS["ambience"])
for n, m in rep["music"].items():
    m = dict(m, gain_db=0.0, description={"theme_explore": "Tema de exploracao, 16 compassos ABA'.", "theme_explore_low": "Versao esparsa para usar durante a fala.", "theme_discovery": "Sting de descoberta."}[n])
    add(n, m, "music", "Musica", m["loop"], None, TOOLS["music"])
json.dump({"version": 2, "entries": entries}, open(os.path.join(ROOT, "game", "audio", "sfx_catalog.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=2)
print("sfx_catalog.json:", len(entries), "entradas")
