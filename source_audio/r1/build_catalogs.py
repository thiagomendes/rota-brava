"""Catalogos de runtime, procedencia por arquivo, mixagem de referencia de 60 s e relatorio de medidas (RB-R1).

Entradas: source_audio/{babble,radio,music,foley}/generated.json (escritos pelos geradores).
Saidas: game/audio/voice_catalog.json, game/audio/sfx_catalog.json, source_audio/PROVENANCE.md,
source_audio/report.json, captures/rb-r1/audio/mix_ref_60s.wav + graficos SVG (fora do Git).
Medidas numericas apenas; aceite perceptual pendente (Thiago).
"""
from __future__ import annotations

import datetime
import re
import sys
from pathlib import Path

import numpy as np
from scipy import signal

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import (CAPTURES, GAME, OUT_AUDIO, ROOT, filt, limit, load, load_json, lufs, measure, save_json,  # noqa: E402
                    true_peak, write_wav)
from lines import gather  # noqa: E402

SA = ROOT / "source_audio"
SR = 44100
TODAY = datetime.date.today().isoformat()
ASSETS = {a["id"]: a for a in load_json(ROOT / "tools" / "audio_assets.json")["assets"]}
TC = load_json(ROOT / "tools" / "toolchain.json")["audio"]


def gpath(res: str) -> Path:
    return GAME / res.removeprefix("res://")


def bus_db() -> dict[str, float]:
    t = (OUT_AUDIO / "default_bus_layout.tres").read_text(encoding="utf-8")
    names = dict(re.findall(r"bus/(\d+)/name = &\"(\w+)\"", t))
    vols = dict(re.findall(r"bus/(\d+)/volume_db = (-?[\d.]+)", t))
    out = {names[i]: float(vols.get(i, 0)) for i in names}
    pg = re.search(r"pre_gain_db = (-?[\d.]+)", t)  # pre-ganho do limitador do Master
    out["Master"] += float(pg.group(1)) if pg else 0.0
    return out


# ------------------------------------------------------------------ catalogos

def build_voice(babble, radio) -> list[dict]:
    lines = []
    by_id = {e["id"]: e for e in gather()}
    for r in babble["lines"]:
        if r.get("crowd"):
            continue
        e = by_id[r["id"]]
        lines.append({"id": r["id"], "character": r["character"], "speaker": e["speaker"], "intent": r["intent"],
                      "language": "pt_BR", "subtitle": r["id"], "type": "babble", "file": r["file"],
                      "duration": r["duration"], "peak_dbfs": r["peak_dbfs"], "lufs": r["lufs"], "visemes": r["visemes"],
                      "emotes": e.get("emotes", []), "status": "provisorio",
                      "tool": "source_audio/babble/babble.py (sintese formante original)", "voice": "balbucio:" + r["character"]})
    for r in radio["lines"]:
        e = by_id[r["id"]]
        lines.append({"id": r["id"], "character": r["character"], "speaker": e["speaker"], "intent": "radio",
                      "language": "pt_BR", "subtitle": r["id"], "type": "radio", "file": r["file"],
                      "duration": r["duration"], "peak_dbfs": r["peak_dbfs"], "lufs": r["lufs"], "visemes": r["visemes"],
                      "emotes": e.get("emotes", []), "status": "provisorio",
                      "tool": "piper-tts 1.8.0 (local) + source_audio/radio/radio.py", "voice": "Piper pt_BR-jeff-medium (Farol 7)"})
    lines.sort(key=lambda x: x["id"])
    return lines


def build_sfx(foley, music, babble) -> list[dict]:
    out = []
    for e in foley["entries"]:
        g = e["gain_db"]
        if e["name"].startswith("sfx_step_grass"):
            g = 3.0  # transientes suaves: compensa o nivel percebido (pico continua <= -3 dBFS no runtime)
        if e["name"] == "sfx_engine_loop":
            g = -8.0  # motor constante: abre espaco para voz e radio (medido na mix_ref_60s)
        out.append({"name": e["name"], "file": e["file"], "type": e["type"], "duration": e["duration"],
                    "peak_dbfs": e["peak_dbfs"], "true_peak_dbtp": e["true_peak_dbtp"], "lufs": e["lufs"],
                    "channels": e["channels"], "sample_rate": e["sample_rate"], "bus": e["bus"], "gain_db": g,
                    "loop": e["loop"], "caption_key": e["caption_key"], "status": "provisorio", "tool": e["tool"],
                    "source": "; ".join(e["sources"]), "license": e["license"],
                    **({"seam_jump": e["seam_jump"]} if e["loop"] else {})})
    for t in music["tracks"]:
        out.append({"name": t["name"], "file": t["file"], "type": "music", "duration": t["duration"],
                    "peak_dbfs": t["peak_dbfs"], "true_peak_dbtp": t["true_peak_dbtp"], "lufs": t["lufs"],
                    "channels": 2, "sample_rate": t["sample_rate"], "bus": "Musica", "gain_db": 0.0, "loop": t["loop"],
                    "caption_key": None, "status": "provisorio", "tool": music["tool"],
                    "source": "composicao original; SoundFonts FreePats CC0", "license": "original + CC0-1.0 (instrumentos)",
                    **({"seam_jump": t["seam_jump"]} if t["loop"] else {})})
    for r in babble["lines"]:
        if r.get("crowd"):
            out.append({"name": "vo_" + r["id"].replace("crowd.", "").replace(".", "_"), "file": r["file"], "type": "voice_crowd",
                        "duration": r["duration"], "peak_dbfs": r["peak_dbfs"], "true_peak_dbtp": r["true_peak_dbtp"],
                        "lufs": r["lufs"], "channels": 1, "sample_rate": 32000, "bus": "Voz", "gain_db": -6.0, "loop": False,
                        "caption_key": None, "status": "provisorio", "tool": "source_audio/babble/babble.py",
                        "source": "original", "license": "original"})
    return out


# ------------------------------------------------------------------ procedencia

def provenance(voice, sfx) -> str:
    rows = []
    src_re = re.compile(r"^(\w+)/(.+)$")

    def src_cell(s: str) -> str:
        m = src_re.match(s)
        if m and m.group(1) in ASSETS:
            a = ASSETS[m.group(1)]
            return f"`{m.group(2)}` — {a['author']} — <{a['page']}> — **{a['license']}**"
        return s

    for e in voice:
        if e["type"] == "babble":
            rows.append((e["file"], "original", "Balbucio sintetizado (formantes) — nenhuma amostra de terceiros", e["tool"]))
        else:
            rows.append((e["file"], "original (TTS)", f"Piper `pt_BR-jeff-medium`: dataset **CC0**, modelo MIT ({TC['piper_voice']['model_card']})", e["tool"]))
    for e in sfx:
        lic = "original" if e["license"] == "original" else "CC0-1.0"
        srcs = [src_cell(s.strip()) for s in e["source"].split(";")]
        rows.append((e["file"], lic, "<br>".join(srcs), e["tool"]))
    files = sorted({r[0] for r in rows})
    md = [
        "# Procedencia e licencas do audio (RB-R1)", "",
        f"Gerado por `source_audio/r1/build_catalogs.py` em {TODAY}. Regra (RB-R1 D3): terceiros **so CC0/dominio publico**;",
        "composicao, edicao, sintese e mixagem originais do projeto. Downloads conferidos por SHA-256 em",
        "`tools/audio_assets.json` (amostras/SoundFonts) e `tools/toolchain.json` chave `audio` (ferramentas e voz).",
        "Textos de licenca em `source_audio/LICENSES/`.", "",
        "## Ferramentas (producao; nada disto vai no jogo)", "",
        f"- Piper `piper-tts {TC['python_packages']['piper-tts']}` (OHF-Voice/piper1-gpl) — **GPL-3.0-or-later**; motor local/offline; o audio gerado nao e obra derivada do codigo.",
        f"- Voz `{TC['piper_voice']['name']}` — {TC['piper_voice']['license']} — {TC['piper_voice']['model_card']}",
        f"- FluidSynth {TC['fluidsynth']['version']} — **LGPL-2.1-or-later** — {TC['fluidsynth']['url']}",
        "- Python: numpy, scipy, soundfile (BSD-3-Clause), mido (MIT), onnxruntime (MIT).", "",
        "## Fontes de terceiros usadas (todas CC0-1.0)", "",
        "| id | autor | pagina | licenca | sha256 |", "|---|---|---|---|---|",
    ]
    for a in ASSETS.values():
        md.append(f"| `{a['id']}` | {a['author']} | <{a['page']}> | {a['license']} | `{a['sha256'][:16]}…` |")
    md += ["", "Nao usado (licenca diferente de CC0): `picture.jpg` do pacote World Percussion (CC-BY 4.0) — nao copiado.", "",
           "## Por arquivo em `game/audio`", "", "| arquivo | licenca | origem | ferramenta |", "|---|---|---|---|"]
    seen = set()
    for f, lic, origin, tool in sorted(rows):
        if f in seen:
            continue
        seen.add(f)
        md.append(f"| `{f}` | {lic} | {origin} | `{tool}` |")
    md += ["", f"Total: {len(files)} arquivos de audio. Data de download/geracao: {TODAY}.", ""]
    return "\n".join(md)


# ------------------------------------------------------------------ mixagem de referencia

def _place(buf, x, t, gain_db=0.0):
    if x.ndim == 1:
        x = np.stack([x, x], axis=1) * 0.7071
    i = int(t * SR)
    n = min(len(x), len(buf) - i)
    if n > 0:
        buf[i:i + n] += x[:n] * 10 ** (gain_db / 20)


def _loop_to(x, n, start=0):
    reps = int(np.ceil((n + start) / len(x))) + 1
    return np.tile(x, (reps, 1) if x.ndim == 2 else reps)[start:start + n]


def mix_ref(voice, sfx):
    D = 60.0
    N = int(D * SR)
    buses = bus_db()
    S = {e["name"]: e for e in sfx}
    V = {e["id"]: e for e in voice}

    def ld(res, mono=False):
        return load(gpath(res), SR, mono=mono)

    amb = np.zeros((N, 2))
    for name, g in (("amb_dock_water", 0), ("amb_wind_light", 0), ("amb_gulls_far", 0), ("amb_dock_creaks", 0), ("amb_village_market", -2)):
        x = ld(S[name]["file"])
        _place(amb, _loop_to(x, N, int(len(x) * 0.37)), 0, g + S[name]["gain_db"])
    amb *= 10 ** (buses["Ambiente"] / 20)

    timeline = [(3.0, "ep01.arrival.radio.horn"), (8.2, "ep01.arrival.pilot.react"), (10.2, "ep01.arrival.pilot.ask_captain"),
                (13.5, "ep01.arrival.tracker.take_over"), (19.5, "ep01.dock.tracker.small_print"),
                (25.0, "ep01.radio.team.found_boat"), (33.5, "ep01.river.pilot.start"), (39.0, "ep01.river.pilot.hint_spoken"),
                (45.5, "ep01.river.pilot.leaves"), (51.0, "ep01.return.radio.joke")]
    vox = np.zeros((N, 2))
    spans = []
    for t, i in timeline:
        x = ld(V[i]["file"], mono=True)
        _place(vox, x, t)
        spans.append((t, t + len(x) / SR, i, V[i]["type"]))
    vox *= 10 ** (buses["Voz"] / 20)

    fx = np.zeros((N, 2))
    _place(fx, ld(S["sfx_horn_boat"]["file"], True), 1.0, -3)
    _place(fx, ld(S["sfx_hull_bump"]["file"], True), 6.5)
    for k, t in enumerate(np.arange(15.0, 24.0, 0.42)):
        _place(fx, ld(S[f"sfx_step_wood_{k % 6 + 1:02d}"]["file"], True), t, -4)
    _place(fx, ld(S["sfx_clue_found"]["file"], True), 22.5)
    eng = ld(S["sfx_engine_loop"]["file"], True)
    rpm = 0.5
    pitch = 0.8 + (2.4 - 0.8) * rpm
    n_e = int(28 * SR)
    eng_p = np.interp(np.arange(n_e) * pitch, np.arange(len(eng) * 40), np.tile(eng, 40))
    _place(fx, eng_p, 32.0, S["sfx_engine_loop"]["gain_db"] - 5 + 8 * rpm)
    fx *= 10 ** (buses["Efeitos"] / 20)

    mus = _loop_to(ld(S["theme_explore"]["file"]), N)
    duck = np.zeros(N)
    for a, b, _, _ in spans:
        duck[int(a * SR):int(b * SR)] = 1
    # rampas 0,3 s / 0,8 s como AudioDirector.duck_music (-6 dB)
    g = np.zeros(N)
    cur = 0.0
    up, dn = 1 / (0.3 * SR), 1 / (0.8 * SR)
    for i in range(0, N, 64):
        tgt = duck[i]
        cur = min(tgt, cur + up * 64) if tgt > cur else max(tgt, cur - dn * 64)
        g[i:i + 64] = cur
    mus = mus * (10 ** ((buses["Musica"] - 6.0 * g) / 20))[:, None]

    pre = amb + vox + fx + mus
    master_gain = buses["Master"]
    out = limit(pre * 10 ** (master_gain / 20), SR, -1.0)

    # inteligibilidade: voz vs fundo em cada fala (LUFS no trecho e banda 300-3400 Hz)
    bg = (amb + fx + mus) * 10 ** (master_gain / 20)
    vv = vox * 10 ** (master_gain / 20)
    intel = []
    for a, b, i, kind in spans:
        s = slice(int(a * SR), int(b * SR))
        lv, lb = lufs(vv[s], SR), lufs(bg[s], SR)
        bv = filt(filt(vv[s], "highpass", 300, SR), "lowpass", 3400, SR)
        bb = filt(filt(bg[s], "highpass", 300, SR), "lowpass", 3400, SR)
        snr_band = 10 * np.log10(np.mean(bv ** 2) / (np.mean(bb ** 2) + 1e-12))
        intel.append({"id": i, "type": kind, "t0": round(a, 2), "t1": round(b, 2), "voice_lufs": round(lv, 1),
                      "background_lufs": round(lb, 1), "voice_minus_background_lu": round(lv - lb, 1),
                      "speech_band_snr_db": round(float(snr_band), 1), "engine_on": a >= 32.0})
    CAPTURES.mkdir(parents=True, exist_ok=True)
    write_wav(CAPTURES / "mix_ref_60s.wav", out, SR)
    st = short_term(out)
    svg_plot(CAPTURES / "mix_ref_60s_loudness.svg", st, spans, "Loudness de curto prazo (3 s) — mix_ref_60s")
    svg_wave(CAPTURES / "mix_ref_60s_wave.svg", out, spans)
    stems = {k: round(lufs(v * 10 ** (master_gain / 20), SR), 2) for k, v in (("ambiente", amb), ("voz", vox), ("efeitos", fx), ("musica", mus))}
    return {"file": "captures/rb-r1/audio/mix_ref_60s.wav (fora do Git)", "duration": D, "buses_db": buses,
            "integrated_lufs": round(lufs(out, SR), 2), "true_peak_dbtp": round(true_peak(out), 2),
            "pre_limiter_true_peak_dbtp": round(true_peak(pre * 10 ** (master_gain / 20)), 2),
            "stems_lufs": stems, "ducking": "musica -6 dB (rampa 0,3 s / 0,8 s) sob voz e radio; sidechain do bus Musica nao simulado",
            "short_term_lufs_max": round(max(st), 2), "intelligibility": intel,
            "intelligibility_min_lu": min(x["voice_minus_background_lu"] for x in intel),
            "intelligibility_min_radio_engine_lu": min([x["voice_minus_background_lu"] for x in intel if x["type"] == "radio" and x["engine_on"]] or [0]),
            "graphs": ["captures/rb-r1/audio/mix_ref_60s_loudness.svg", "captures/rb-r1/audio/mix_ref_60s_wave.svg"]}


def short_term(x):
    hop = SR // 2
    out = []
    for i in range(0, len(x) - 3 * SR, hop):
        out.append(lufs(x[i:i + 3 * SR], SR))
    return out


def svg_plot(path, st, spans, title):
    W, H = 900, 260
    pts = " ".join(f"{40 + i * (W - 60) / max(1, len(st) - 1):.1f},{20 + ( -10 - v) / 40 * (H - 40):.1f}" for i, v in enumerate(st))
    spn = "".join(f'<rect x="{40 + a / 60 * (W - 60):.1f}" y="20" width="{(b - a) / 60 * (W - 60):.1f}" height="{H - 40}" fill="{"#fd8" if k == "radio" else "#adf"}" opacity="0.5"/>' for a, b, _, k in spans)
    grid = "".join(f'<line x1="40" x2="{W - 20}" y1="{20 + (-10 - v) / 40 * (H - 40):.1f}" y2="{20 + (-10 - v) / 40 * (H - 40):.1f}" stroke="#ccc"/><text x="2" y="{24 + (-10 - v) / 40 * (H - 40):.1f}" font-size="10">{v}</text>' for v in (-10, -16, -20, -30, -40, -50))
    path.write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}"><rect width="100%" height="100%" fill="white"/>{spn}{grid}<polyline fill="none" stroke="#c22" stroke-width="2" points="{pts}"/><text x="40" y="14" font-size="12">{title} — azul: balbucio, amarelo: radio; linha -16 = alvo</text></svg>', encoding="utf-8")


def svg_wave(path, x, spans):
    W, H = 900, 200
    m = np.abs(x).max(axis=1)
    n = W - 60
    blk = len(m) // n
    env = [m[i * blk:(i + 1) * blk].max() for i in range(n)]
    bars = "".join(f'<line x1="{40 + i}" x2="{40 + i}" y1="{H / 2 - v * 80:.1f}" y2="{H / 2 + v * 80:.1f}" stroke="#246"/>' for i, v in enumerate(env))
    lim = 10 ** (-1 / 20) * 80
    path.write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}"><rect width="100%" height="100%" fill="white"/>{bars}<line x1="40" x2="{W - 20}" y1="{H / 2 - lim:.1f}" y2="{H / 2 - lim:.1f}" stroke="red"/><text x="40" y="14" font-size="12">Envelope de pico — mix_ref_60s (linha vermelha = -1 dBFS)</text></svg>', encoding="utf-8")


def main() -> int:
    babble = load_json(SA / "babble" / "generated.json")
    radio = load_json(SA / "radio" / "generated.json")
    music = load_json(SA / "music" / "generated.json")
    foley = load_json(SA / "foley" / "generated.json")
    voice = build_voice(babble, radio)
    sfx = build_sfx(foley, music, babble)
    save_json(OUT_AUDIO / "voice_catalog.json", {"version": 2, "lines": voice})
    save_json(OUT_AUDIO / "sfx_catalog.json", {"version": 3, "entries": sfx})
    # remove audio antigo (RB-04) nao referenciado: arquivo, .import e visemas orfaos
    keep = {gpath(e["file"]).resolve() for e in voice + sfx} | {gpath(e["visemes"]).resolve() for e in voice}
    keep |= {(OUT_AUDIO / "voice" / (r["id"].replace(".", "_") + ".visemes.json")).resolve() for r in babble["lines"]}
    for p in list(OUT_AUDIO.rglob("*")):
        if p.suffix in (".wav", ".ogg") or p.name.endswith(".visemes.json"):
            if p.resolve() not in keep:
                print("removendo orfao", p.relative_to(ROOT))
                p.unlink()
                imp = p.with_name(p.name + ".import")
                if imp.exists():
                    imp.unlink()
    (SA / "PROVENANCE.md").write_text(provenance(voice, sfx), encoding="utf-8")
    mix = mix_ref(voice, sfx)
    audio_files = [p for p in OUT_AUDIO.rglob("*") if p.suffix in (".wav", ".ogg")]
    total = sum(p.stat().st_size for p in audio_files)
    sec_syl = [r["sec_per_syllable"] for r in babble["lines"] if not r.get("crowd")]
    report = {
        "ticket": "RB-R1", "date": TODAY, "note": "Medidas numericas; NADA foi ouvido. Aceite perceptual: Thiago (Portao 2).",
        "loudness_method": "BS.1770-4 (K-weighting, gating -70/-10), pico verdadeiro por sobreamostragem 4x (source_audio/r1/common.py)",
        "totals": {"files": len(audio_files), "bytes": total, "mb": round(total / 1e6, 2),
                   "by_dir_mb": {d.name: round(sum(p.stat().st_size for p in d.rglob('*') if p.suffix in ('.wav', '.ogg')) / 1e6, 2)
                                 for d in OUT_AUDIO.iterdir() if d.is_dir()}},
        "babble": {"lines": len(sec_syl), "sec_per_syllable_min": min(sec_syl), "sec_per_syllable_max": max(sec_syl),
                   "sec_per_syllable_mean": round(float(np.mean(sec_syl)), 3), "items": babble["lines"]},
        "radio": radio, "music": music["tracks"], "sfx": foley["entries"], "mix_ref_60s": mix,
    }
    save_json(SA / "report.json", report)
    print(f"catalogos: {len(voice)} falas, {len(sfx)} sons; audio total {total / 1e6:.2f} MB")
    print(f"mix_ref_60s: {mix['integrated_lufs']} LUFS, {mix['true_peak_dbtp']} dBTP; voz-fundo min {mix['intelligibility_min_lu']} LU;"
          f" radio com motor min {mix['intelligibility_min_radio_engine_lu']} LU; stems {mix['stems_lufs']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
