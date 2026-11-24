"""Balbucio de desenho (RB-R1 D2): sintese formante ORIGINAL (estilo Klatt, cascata de 4 ressonadores), sem amostras.

Para cada fala de personagem: numero de silabas ~ nucleos voc\u00e1licos do texto; as vogais seguem as do texto (prosodia
reconhecivel sem palavras), as consoantes saem do inventario do personagem; nunca duas silabas iguais seguidas.
Entonacao por intencao (profiles.json). Saida: WAV mono 32 kHz + JSON de visemas (abertura 0..1 a cada 30 ms, com a
lista de silabas e tempos). Deterministico: semente por fala (id + perfil).

Uso: python source_audio/babble/babble.py            (todas as falas de balbucio + bancos de moradores)
     python source_audio/babble/babble.py --only ID
"""
from __future__ import annotations

import sys
import unicodedata
import zlib
from pathlib import Path

import numpy as np
from scipy import signal

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "r1"))
from common import (GAME, OUT_AUDIO, compress, filt, limit, load_json, lufs, measure, res_path, reverb,  # noqa: E402
                    save_json, write_wav)
from lines import gather  # noqa: E402

HERE = Path(__file__).resolve().parent
CFG = load_json(HERE / "profiles.json")
ISR = 64000          # taxa interna (impulsos glotais menos quantizados)
OSR = 32000          # taxa de saida
HOP = 160            # 2,5 ms por quadro de parametros
VIS_FRAME = 0.03
TARGET_LUFS = -19.0
TP_CEIL = -2.0

VOWELS = {  # F1..F4 (Hz) e larguras de banda, base adulta; abertura de boca 0..1
    "a": ([730, 1150, 2450, 3400], [90, 110, 160, 250], 1.00),
    "e": ([500, 1850, 2500, 3450], [70, 100, 160, 250], 0.70),
    "i": ([310, 2250, 3000, 3700], [60, 100, 170, 250], 0.42),
    "o": ([500, 880, 2450, 3350], [80, 100, 150, 250], 0.75),
    "u": ([330, 800, 2300, 3300], [70, 100, 150, 250], 0.38),
}
CONS = {  # tipo, F2 locus / centro do ruido, abertura de boca
    "p": ("plosive", 900, 0.0), "b": ("vplosive", 900, 0.0), "t": ("plosive", 4200, 0.25), "d": ("vplosive", 3500, 0.25),
    "k": ("plosive", 2200, 0.3), "g": ("vplosive", 2000, 0.3), "m": ("nasal", 1100, 0.02), "n": ("nasal", 1600, 0.2),
    "l": ("liquid", 1250, 0.35), "r": ("tap", 1500, 0.4), "s": ("fric", 6000, 0.2), "v": ("vfric", 1800, 0.15),
    "h": ("breath", 1500, 0.5), "": ("none", 0, 0.5),
}


def _fold(c: str) -> str:
    return "".join(ch for ch in unicodedata.normalize("NFD", c.lower()) if unicodedata.category(ch) != "Mn")


def nuclei(text: str) -> list[tuple[str, str]]:
    """Lista de (vogal, pontuacao_depois) para cada nucleo silabico aproximado do texto (pt-BR)."""
    out: list[tuple[str, str]] = []
    word_vowels = ""
    for raw in text + " ":
        c = _fold(raw)
        if c in "aeiouy":
            if word_vowels and word_vowels[-1] == "V":
                prev = out[-1][0]
                # ditongo: so conta um nucleo (vogal mais aberta fica)
                if c in "iu" or prev in "iu" and c not in "iu":
                    if prev in "iu" and c not in "iu":
                        out[-1] = ({"y": "i"}.get(c, c), "")
                    continue
            out.append(({"y": "i"}.get(c, c), ""))
            word_vowels += "V"
        else:
            word_vowels += "C" if c.isalpha() else " "
            if raw in CFG["pauses"] and out:
                out[-1] = (out[-1][0], raw)
            elif raw == " " and out and out[-1][1] == "":
                out[-1] = (out[-1][0], " ")
    return out or [("a", ".")]


class Plan:
    """Parametros por quadro (HOP amostras internas)."""

    def __init__(self, n: int):
        self.f0 = np.zeros(n)
        self.av = np.zeros(n)        # amplitude vozeada
        self.an = np.zeros(n)        # amplitude de ruido (fricacao/explosao)
        self.nf = np.full(n, 3000.0)  # centro do ruido
        self.F = np.zeros((n, 4))
        self.B = np.zeros((n, 4))
        self.open = np.zeros(n)


def _semi(s):
    return 2.0 ** (np.asarray(s) / 12.0)


def plan_speech(text: str, prof: dict, intent: dict, rng: np.random.Generator):
    nuc = nuclei(text)
    rate = intent["rate"]
    cons_inv = prof["consonants"]
    sylls = []
    prev = None
    for v, p in nuc:
        for _ in range(20):
            c = cons_inv[rng.integers(len(cons_inv))]
            if c + v != prev:
                break
        sylls.append({"c": c, "v": v, "s": c + v, "punct": p})
        prev = c + v
    # pitch alvo por silaba (semitons)
    n = len(sylls)
    rngst = prof["pitch_range"] * intent["range"]
    phrase_idx = []
    k = 0
    for s in sylls:
        phrase_idx.append(k)
        if s["punct"] in CFG["pauses"]:
            k += 1
    targets = np.zeros(n)
    acc = rng.normal(0, rngst * 0.35, n)
    acc = signal.lfilter([1 - prof.get("smooth", 0.5) * 0.6], [1, -prof.get("smooth", 0.5) * 0.6], acc)
    for ph in set(phrase_idx):
        ids = [i for i in range(n) if phrase_idx[i] == ph]
        m = len(ids)
        for j, i in enumerate(ids):
            x = j / max(1, m - 1)
            t = rngst * 0.3 + (intent["decl"] - rngst * 0.3) * x
            if prof.get("melodic"):
                t += rngst * 0.35 * np.sin(np.pi * 1.5 * x + ph)
            if prof.get("bounce") or intent.get("bounce"):
                t += rngst * 0.35 * (1 if j % 2 == 0 else -1)
            if j == 0 and intent.get("start_jump"):
                t += intent["start_jump"]
            last = sylls[i]["punct"] in CFG["pauses"] or i == n - 1
            if j >= m - 2 and (sylls[ids[-1]]["punct"] == "?" or (intent["end"] and ph == max(phrase_idx))):
                t += intent["end"] * (0.5 if j == m - 2 else 1.0) if sylls[ids[-1]]["punct"] == "?" or intent["end"] else 0
                if sylls[ids[-1]]["punct"] == "?" and not intent["end"]:
                    t += 4.0 * (0.5 if j == m - 2 else 1.0)
            targets[i] = t + acc[i] + intent["shift"]
            sylls[i]["last"] = last
    # duracoes
    base = prof["syl_dur"] * rate
    segs = []
    t = 0.0
    for i, s in enumerate(sylls):
        d = base * rng.uniform(0.85, 1.18)
        if s.get("last"):
            d *= 1.35
        s["t0"] = t
        s["t1"] = t + d
        s["pitch"] = float(targets[i])
        t += d
        if s["punct"] in CFG["pauses"] and i < n - 1:
            t += CFG["pauses"][s["punct"]] * rng.uniform(0.85, 1.15) * rate
        elif s["punct"] == " ":
            t += rng.uniform(0.0, 0.018)
    total = t + 0.12
    nf = int(np.ceil(total * ISR / HOP)) + 1
    P = Plan(nf)
    fs = prof["formant_scale"]
    fr = np.arange(nf) * HOP / ISR
    # f0 continuo: interpolacao entre centros das silabas + glide
    centers = np.array([(s["t0"] + s["t1"]) / 2 for s in sylls])
    pitches = np.array([s["pitch"] for s in sylls])
    if n == 1:
        st = np.full(nf, pitches[0])
    else:
        st = np.interp(fr, centers, pitches)
        # menos glide = degraus por silaba (mais "saltitante")
        step = pitches[np.clip(np.searchsorted(centers, fr) - 0, 0, n - 1)]
        g = prof.get("glide", 0.3)
        st = g * st + (1 - g) * np.interp(fr, [s["t0"] for s in sylls] + [total], list(pitches) + [pitches[-1]]) * 0 + (1 - g) * step
    st = signal.lfilter([0.15], [1, -0.85], st)  # suaviza degraus (~15 ms)
    vib = prof.get("vibrato", 0.2) * np.sin(2 * np.pi * 5.5 * fr + rng.uniform(0, 6))
    jit = rng.normal(0, 0.06, nf)
    P.f0 = prof["f0"] * _semi(st + vib + jit)
    # formantes e amplitudes por silaba
    P.F[:] = np.array(VOWELS["e"][0]) * fs
    P.B[:] = np.array(VOWELS["e"][1]) * fs
    for i, s in enumerate(sylls):
        a = int(s["t0"] * ISR / HOP)
        b = int(s["t1"] * ISR / HOP)
        L = max(2, b - a)
        F, B, op = VOWELS[s["v"]]
        F = np.array(F) * fs * rng.uniform(0.97, 1.03)
        B = np.array(B) * fs
        kind, locus, cop = CONS[s["c"]]
        cfrac = {"plosive": 0.28, "vplosive": 0.26, "nasal": 0.32, "liquid": 0.25, "tap": 0.14, "fric": 0.36,
                 "vfric": 0.3, "breath": 0.25, "none": 0.0}[kind]
        ca = int(L * cfrac)
        env = np.ones(L)
        att = max(1, int(0.012 * ISR / HOP))
        env[ca:ca + att] = np.linspace(0.2, 1, min(att, L - ca))
        rel = max(1, int((0.05 if s.get("last") else 0.018) * ISR / HOP))
        env[-rel:] *= np.linspace(1, 0.0 if (s.get("last") or s["punct"] in CFG["pauses"]) else 0.35, rel)
        P.av[a:a + L] = env[: len(P.av[a:a + L])]
        P.open[a:a + L] = op
        P.F[a:a + L] = F
        P.B[a:a + L] = B
        if ca > 0:
            seg = slice(a, a + ca)
            P.open[seg] = cop
            if kind in ("plosive", "vplosive"):
                P.av[seg] = 0.0 if kind == "plosive" else 0.12
                bl = max(1, int(0.008 * ISR / HOP))
                P.an[a + ca - bl:a + ca] = 0.45
                P.nf[a + ca - bl:a + ca + 2] = locus * fs
                P.an[a + ca:a + ca + 2] = 0.12  # aspiracao curta
            elif kind == "nasal":
                P.av[seg] = 0.55
                P.F[seg] = np.array([280, locus, 2300, 3300]) * fs
                P.B[seg] = np.array([120, 300, 300, 400]) * fs
            elif kind == "liquid":
                P.av[seg] = 0.7
                P.F[seg] = np.array([360, locus, 2700, 3400]) * fs
            elif kind == "tap":
                P.av[seg] = 0.35
            elif kind in ("fric", "vfric"):
                P.av[seg] = 0.0 if kind == "fric" else 0.25
                P.an[seg] = np.hanning(ca + 2)[1:-1] * (0.32 if kind == "fric" else 0.18)
                P.nf[seg] = locus * (1.0 if kind == "fric" else fs)
            elif kind == "breath":
                P.av[seg] = 0.05
                P.an[seg] = np.hanning(ca + 2)[1:-1] * 0.15
                P.nf[seg] = 1500 * fs
            # transicao de formantes do locus para a vogal (~25 ms)
            tr = min(L - ca, max(2, int(0.025 * ISR / HOP)))
            if kind != "none":
                F2s = locus * fs if kind not in ("fric", "breath") else F[1]
                P.F[a + ca:a + ca + tr, 1] = np.linspace(F2s, F[1], tr)
                P.F[a + ca:a + ca + tr, 0] = np.linspace(F[0] * 0.6, F[0], tr)
    # transicoes suaves de formantes entre quadros
    for j in range(4):
        P.F[:, j] = signal.filtfilt([0.3], [1, -0.7], P.F[:, j])
    P.av = signal.lfilter([0.5], [1, -0.5], P.av)
    return P, sylls, total


def plan_pup(text: str, prof: dict, intent: dict, rng: np.random.Generator):
    nsyl = len(nuclei(text))
    units = int(np.clip(round(nsyl / 2.2), 2, 7))
    sylls, t, prev = [], 0.02, None
    for i in range(units):
        for _ in range(20):
            kind = "au" if rng.random() < 0.68 else "ii"
            var = int(rng.integers(1, 4))
            lab = f"{kind}{var}"
            if lab != prev:
                break
        prev = lab
        d = rng.uniform(0.08, 0.12) if kind == "au" else rng.uniform(0.22, 0.34)
        sylls.append({"s": lab, "kind": kind, "var": var, "t0": t, "t1": t + d, "v": "a" if kind == "au" else "u"})
        t += d + rng.uniform(0.05, 0.12) * intent["rate"]
    total = t + 0.1
    nf = int(np.ceil(total * ISR / HOP)) + 1
    P = Plan(nf)
    fs = prof["formant_scale"]
    P.f0[:] = prof["f0"]
    P.F[:] = np.array(VOWELS["a"][0]) * fs
    P.B[:] = np.array(VOWELS["a"][1]) * fs * 1.3
    for s in sylls:
        a, b = int(s["t0"] * ISR / HOP), int(s["t1"] * ISR / HOP)
        L = b - a
        x = np.linspace(0, 1, L)
        sh = _semi(intent["shift"])
        if s["kind"] == "au":
            f0 = prof["f0"] * sh * (1.35 + 0.1 * s["var"]) * _semi(-9 * x)
            env = np.minimum(1, x / 0.08) * np.exp(-2.2 * x)
            P.an[a:b] = 0.22 * env
            P.nf[a:b] = 2500
            vow = "a" if s["var"] != 2 else "o"
        else:
            f0 = prof["f0"] * sh * (1.5 + 0.08 * s["var"]) * _semi(5 * np.sin(np.pi * x) - 2 * x)
            env = np.sin(np.pi * x) ** 0.7 * 0.75
            vow = "u" if s["var"] != 3 else "i"
        P.f0[a:b] = f0
        P.av[a:b] = env
        P.F[a:b] = np.array(VOWELS[vow][0]) * fs
        P.open[a:b] = VOWELS[vow][2]
    P.av = signal.lfilter([0.5], [1, -0.5], P.av)
    return P, sylls, total


def _res_coef(F, B):
    r = np.exp(-np.pi * B / ISR)
    a1 = -2 * r * np.cos(2 * np.pi * F / ISR)
    a2 = r * r
    return np.array([1 + a1 + a2]), np.array([1, a1, a2])


def render(P: Plan, prof: dict, rng: np.random.Generator) -> np.ndarray:
    nf = len(P.f0)
    n = nf * HOP
    f0 = np.repeat(P.f0, HOP)
    av = np.repeat(P.av, HOP)
    an = np.repeat(P.an, HOP)
    # fonte glotal: trem de impulsos com shimmer -> passa-baixas glotal (2 polos) -> radiacao (+6 dB/oit)
    phase = np.cumsum(f0 / ISR)
    idx = np.nonzero(np.diff(np.floor(phase)) > 0)[0] + 1
    src = np.zeros(n)
    src[idx] = rng.uniform(0.9, 1.1, len(idx))
    tilt = 0.97 - 0.01 * prof.get("bright", 0.0)
    src = signal.lfilter([1], [1, -2 * tilt, tilt * tilt], src)
    src = np.diff(src, prepend=0)
    src /= np.abs(src).max() + 1e-9
    breath = rng.standard_normal(n) * prof.get("breath", 0.1) * 0.35
    breath = filt(breath, "highpass", 1200, ISR)
    exc = (src + breath * (0.5 + 0.5 * np.clip(src * 4, 0, 1))) * av
    # cascata de 4 ressonadores com coeficientes por quadro (estado preservado)
    y = exc
    for j in range(4):
        out = np.zeros(n)
        zi = np.zeros(2)
        for k in range(nf):
            b, a = _res_coef(P.F[k, j], P.B[k, j])
            seg = slice(k * HOP, (k + 1) * HOP)
            out[seg], zi = signal.lfilter(b, a, y[seg], zi=zi)
        y = out
    # ruido de fricacao/explosao (filtro passa-banda por quadro)
    nz = rng.standard_normal(n) * an
    fo = np.zeros(n)
    zi = np.zeros(2)
    for k in range(nf):
        if P.an[k] == 0 and not zi.any():
            continue
        w = 2 * np.pi * min(P.nf[k], ISR * 0.45) / ISR
        al = np.sin(w) / (2 * 1.4)
        b = np.array([al, 0, -al]) / (1 + al)
        a = np.array([1, -2 * np.cos(w) / (1 + al), (1 - al) / (1 + al)])
        seg = slice(k * HOP, (k + 1) * HOP)
        fo[seg], zi = signal.lfilter(b, a, nz[seg], zi=zi)
    y = y / (np.abs(y).max() + 1e-9) + fo * 1.2
    return signal.resample_poly(y, 1, ISR // OSR)


def visemes(y: np.ndarray, P: Plan, total: float) -> list[float]:
    nfr = int(np.ceil(len(y) / OSR / VIS_FRAME))
    hop = int(VIS_FRAME * OSR)
    rms = np.array([np.sqrt(np.mean(y[i * hop:(i + 1) * hop] ** 2)) if i * hop < len(y) else 0 for i in range(nfr)])
    rms = rms / (rms.max() + 1e-9)
    tp = np.arange(len(P.open)) * HOP / ISR
    op = np.interp(np.arange(nfr) * VIS_FRAME + VIS_FRAME / 2, tp, P.open)
    v = np.clip(rms ** 0.6 * (0.35 + 0.65 * op) * 1.15, 0, 1)
    v[rms < 0.04] = 0.0
    v = signal.lfilter([0.6], [1, -0.4], v)
    return [round(float(a), 3) for a in v]


def post(y: np.ndarray, gain_db: float) -> np.ndarray:
    y = filt(y, "highpass", 85, OSR)
    y = filt(y, "peak", 3000, OSR, 0.9, 2.0)    # presenca
    y = compress(y, OSR, -20, 2.5, 0.004, 0.09)
    y = reverb(y, OSR, size=0.12, wet=0.07, damp=0.5, seed=3)
    y = y[: int(len(y) * 1.0)]
    l = lufs(y, OSR)
    y = y * 10 ** ((TARGET_LUFS + gain_db - l) / 20)
    y = limit(y, OSR, TP_CEIL)
    # sem silencio de abertura > 20 ms
    env = np.abs(y)
    first = int(np.argmax(env > 0.01)) if (env > 0.01).any() else 0
    y = y[max(0, first - int(0.004 * OSR)):]
    # cauda: corta silencio final longo
    last = len(y) - int(np.argmax(env[::-1] > 0.002)) if (env > 0.002).any() else len(y)
    y = y[: min(len(y), last + int(0.05 * OSR))]
    n = int(0.01 * OSR)
    y[-n:] *= np.linspace(1, 0, n)
    return y


def synth(text: str, profile: str, intent_name: str, seed_key: str):
    prof = CFG["profiles"][profile]
    intent = CFG["intents"].get(intent_name, CFG["intents"]["normal"])
    seed = (zlib.crc32(seed_key.encode()) ^ prof["seed"]) & 0xFFFFFFFF
    rng = np.random.default_rng(seed)
    if prof.get("mode") == "pup":
        P, sylls, total = plan_pup(text, prof, intent, rng)
    else:
        P, sylls, total = plan_speech(text, prof, intent, rng)
    raw = render(P, prof, rng)
    # posicao do inicio apos o corte de silencio: os tempos das silabas sao relativos ao audio cortado
    y = post(raw, intent.get("gain_db", 0.0))
    shift = (len(raw) + int(OSR * 0) - len(raw)) / OSR
    lead = _lead(raw)
    vis = visemes(np.pad(y, (0, 0)), _shift_plan(P, lead), total)
    syl_out = [{"s": s["s"], "t0": round(max(0.0, s["t0"] - lead), 3), "t1": round(max(0.0, s["t1"] - lead), 3)} for s in sylls]
    return y, vis, syl_out, seed, len(nuclei(text))


def _lead(raw: np.ndarray) -> float:
    env = np.abs(raw) / (np.abs(raw).max() + 1e-9)
    # o mesmo criterio de corte do post (aprox.: limiar relativo apos normalizacao)
    i = int(np.argmax(env > 0.02)) if (env > 0.02).any() else 0
    return max(0, i - int(0.004 * OSR)) / OSR


def _shift_plan(P: Plan, lead: float) -> Plan:
    k = int(lead * ISR / HOP)
    Q = Plan(max(1, len(P.f0) - k))
    Q.open = P.open[k:]
    return Q


def main(argv: list[str]) -> int:
    only = argv[argv.index("--only") + 1] if "--only" in argv else None
    vdir = OUT_AUDIO / "voice"
    report = []
    jobs = [e for e in gather() if e["type"] == "babble"]
    for vname in ("villager_a", "villager_b", "villager_c"):  # bancos de moradores (sem legenda; ambiente/mercado)
        for i, txt in enumerate(["Bom dia, tudo bem?", "Olha o peixe fresquinho!", "Que barco bonito.", "Ah, é mesmo!"]):
            jobs.append({"id": f"crowd.{vname}.{i + 1:02d}", "character": vname, "speaker": vname, "intent": ["pergunta", "alegria", "normal", "descoberta"][i],
                         "text": txt, "type": "babble", "emotes": [], "crowd": True})
    for e in jobs:
        if only and e["id"] != only:
            continue
        prof = e["character"]
        y, vis, syl, seed, ntarget = synth(e["text"], prof, e["intent"], e["id"])
        stem = e["id"].replace(".", "_")
        wav = vdir / f"{stem}.wav"
        vjs = vdir / f"{stem}.visemes.json"
        write_wav(wav, y, OSR)
        dur = round(len(y) / OSR, 3)
        save_json(vjs, {"id": e["id"], "character": prof, "intent": e["intent"], "duration": dur, "frame_s": VIS_FRAME,
                        "open": vis, "syllables": syl, "seed": seed, "target_syllables": ntarget,
                        "tool": "source_audio/babble/babble.py (sintese formante original)"})
        m = measure(y, OSR)
        report.append({**{k: e[k] for k in ("id", "character", "intent", "text")}, "file": res_path(wav),
                       "visemes": res_path(vjs), "syllables": len(syl), "target_syllables": ntarget, "seed": seed,
                       "sec_per_syllable": round(dur / max(1, len(syl)), 3), **m, "crowd": bool(e.get("crowd"))})
        print(f"babble {e['id']:45s} {prof:10s} {e['intent']:10s} {dur:5.2f}s {len(syl):2d} sil  {m['lufs']:6.1f} LUFS  {m['true_peak_dbtp']:5.1f} dBTP")
    if not only:
        save_json(HERE / "generated.json", {"tool": "source_audio/babble/babble.py", "lines": report})
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
