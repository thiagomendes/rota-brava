"""Musica ORIGINAL de Rota Brava (RB-R1 D3): partitura em codigo -> MIDI (mido) -> FluidSynth com SoundFonts CC0
(FreePats) -> mixagem propria (pan, reverb sintetico, compressao) -> loops sem emenda (cauda dobrada no inicio).

Tema da equipe: motivo de 5 notas  C5-F5-A5-G5-C6  (ritmo  colcheia, colcheia, seminima, colcheia, seminima pontuada:
"Ro-ta Bra-va, ei!"). Tonalidade F maior. Instrumentos (todos CC0): xilofone FreePats/VCSL no papel de marimba
(registro medio), ukulele, harpa (pizzicato substituto), violao classico (baixo dedilhado), kalimba, metais
sintetizados FreePats (metais leves), percussao FreePats World Percussion (cajon, conga, bongo, shaker, pandeiro,
palmas). Nao ha 'marimba' nem 'cordas pizzicato' CC0 verificadas: substitutos declarados (ver report).

Uso: python source_audio/music/compose.py
"""
from __future__ import annotations

import subprocess
import sys
import tempfile
from pathlib import Path

import mido
import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "r1"))
from common import (OUT_AUDIO, ROOT, SRC, compress, filt, fold_tail, limit, load, lufs, measure, pan, res_path,  # noqa: E402
                    reverb, save_json, seam_jump, seam_ratio, write_ogg, write_wav, fade, load as load_audio)

HERE = Path(__file__).resolve().parent
SR = 44100
FONTS = {
    "marimba": "fp_xylophone", "uke": "fp_ukulele", "pizz": "fp_harp", "bass": "fp_guitar", "kalimba": "fp_kalimba",
    "brass": "fp_brass", "perc": "fp_worldperc",
}
PERC = {"cajon": 48, "cajon_slap": 49, "bongo_hi": 52, "bongo_lo": 53, "shaker": 55, "shaker_soft": 56, "tamb": 57,
        "clap": 59, "claves": 60, "conga_hi": 63, "conga_lo": 64, "conga_mute": 65}
CH = {"F": [65, 69, 72], "Bb": [70, 74, 77], "Dm": [62, 65, 69], "C": [60, 64, 67], "Am": [57, 60, 64],
      "Gm": [67, 70, 74], "Gm7": [67, 70, 74, 77], "C7": [60, 64, 67, 70], "A7": [57, 61, 64, 67], "Bbmaj7": [70, 74, 77, 81]}
ROOT_NOTE = {"F": 41, "Bb": 46, "Dm": 50, "C": 48, "Am": 45, "Gm": 43, "Gm7": 43, "C7": 48, "A7": 45, "Bbmaj7": 46}
MOTIF = [(0, .5, 72), (.5, .5, 77), (1, 1, 81), (2, .5, 79), (2.5, 1.5, 84)]


def sf2(key: str) -> Path:
    return next((SRC / FONTS[key]).rglob("*.sf2"))


def fluidsynth_exe() -> Path:
    return next((ROOT / ".tools" / "audio" / "fluidsynth").rglob("fluidsynth.exe"))


class Song:
    def __init__(self, bpm: float, bars: int, seed: int):
        self.bpm, self.bars = bpm, bars
        self.tracks: dict[str, list] = {}
        self.rng = np.random.default_rng(seed)

    @property
    def beat_s(self):
        return 60.0 / self.bpm

    @property
    def length_s(self):
        return self.bars * 4 * self.beat_s

    def note(self, trk: str, beat: float, dur: float, pitch: int, vel: int = 90, human: float = 0.012):
        j = self.rng.normal(0, human) if beat > 0 else abs(self.rng.normal(0, human))
        v = int(np.clip(vel + self.rng.normal(0, 6), 20, 127))
        self.tracks.setdefault(trk, []).append((max(0.0, beat * self.beat_s + j), dur * self.beat_s * 0.95, pitch, v))

    def chord(self, trk, beat, dur, notes, vel=80, spread=0.012):
        for i, n in enumerate(notes):
            self.note(trk, beat + i * spread / self.beat_s, dur, n, vel - 4 * i, human=0.004)

    def phrase(self, trk, bar, notes, vel=95, transpose=0):
        for b, d, p in notes:
            self.note(trk, bar * 4 + b, d, p + transpose, vel)


def to_midi(events, path: Path, tail_s: float = 4.0):
    mid = mido.MidiFile(ticks_per_beat=960)
    tr = mido.MidiTrack()
    mid.tracks.append(tr)
    tr.append(mido.MetaMessage("set_tempo", tempo=500000))  # 120 bpm: 1 beat = 0,5 s -> tempos em s exatos
    tr.append(mido.Message("program_change", program=0, channel=0, time=0))
    tr.append(mido.Message("control_change", control=91, value=0, channel=0, time=0))
    tr.append(mido.Message("control_change", control=93, value=0, channel=0, time=0))
    evs = []
    for t, d, p, v in events:
        evs.append((t, 1, p, v))
        evs.append((t + d, 0, p, 0))
    evs.sort(key=lambda e: (e[0], e[1]))
    last = 0
    for t, on, p, v in evs:
        tick = int(round(t * 1920))
        tr.append(mido.Message("note_on" if on else "note_off", note=int(p), velocity=int(v), channel=0, time=tick - last))
        last = tick
    end = int(round(((evs[-1][0] if evs else 0) + tail_s) * 1920))
    tr.append(mido.MetaMessage("end_of_track", time=end - last))
    mid.save(str(path))


def render_stem(key: str, events, total_s: float) -> np.ndarray:
    if not events:
        return np.zeros((int(total_s * SR), 2))
    with tempfile.TemporaryDirectory() as td:
        mp, wp = Path(td) / "s.mid", Path(td) / "s.wav"
        to_midi(events, mp)
        subprocess.run([str(fluidsynth_exe()), "-ni", "-q", "-g", "0.5", "-r", str(SR), "-R", "0", "-C", "0",
                        "-o", "synth.polyphony=128", "-T", "wav", "-F", str(wp), str(sf2(key)), str(mp)],
                       check=True, capture_output=True)
        x = load_audio(wp, SR, mono=False)
    n = int(total_s * SR)
    if len(x) < n:
        x = np.pad(x, ((0, n - len(x)), (0, 0)))
    return x[:n]


MIX = {  # ganho dB, pan
    "melody": ("marimba", -1.0, 0.1), "arp": ("marimba", -9.0, 0.4), "uke": ("uke", -5.0, -0.35),
    "bass": ("bass", -2.0, 0.0), "pizz": ("pizz", -7.0, 0.3), "kalimba": ("kalimba", -6.0, 0.5),
    "brass": ("brass", -9.0, -0.15), "perc": ("perc", -4.0, 0.0), "shaker": ("perc", -14.0, 0.45),
    "conga": ("perc", -9.0, -0.4), "melody2": ("kalimba", -4.0, -0.2),
}


def mixdown(song: Song, stems: list[str] | None = None, loop: bool = True, wet: float = 0.16,
            extra_gain: dict | None = None) -> np.ndarray:
    tail = 4.0
    total = song.length_s + tail
    acc = np.zeros((int(total * SR), 2))
    for name, ev in song.tracks.items():
        if stems is not None and name not in stems:
            continue
        key, g, p = MIX[name]
        g += (extra_gain or {}).get(name, 0.0)
        x = render_stem(key, ev, total).mean(axis=1)
        if name == "bass":
            x = filt(x, "lowpass", 2500, SR)
        acc += pan(x, p) * 10 ** (g / 20)
    acc = filt(acc, "highpass", 35, SR)
    acc = reverb(acc, SR, size=0.45, wet=wet, damp=0.45, seed=11)[: len(acc)]
    acc = compress(acc, SR, -16, 2.0, 0.01, 0.15)
    L = int(round(song.length_s * SR))
    return fold_tail(acc, L) if loop else acc


def master(x: np.ndarray, target: float, loop: bool) -> np.ndarray:
    l = lufs(x, SR)
    x = x * 10 ** ((target - l) / 20)
    if loop:  # limitador circular: o estado do ganho no inicio continua o do fim
        n = len(x)
        x = limit(np.concatenate([x, x]), SR, -1.5)[n:]
    else:
        x = limit(x, SR, -1.5)
    if not loop:
        x = fade(x, SR, 0.002, 0.25)
    return x


# ------------------------------------------------------------------ partituras

A_PROG = ["F", "Bb", "Dm", "C", "F", "Bb", "Dm", "C"]
B_PROG = ["Bb", "C", "Am", "Dm", "Gm", "C", "F", "F"]
A_MEL = [MOTIF, [(0, 1, 82), (1, .5, 81), (1.5, .5, 79), (2, 2, 77)],
         [(0, .5, 74), (.5, .5, 77), (1, 1, 81), (2, .5, 79), (2.5, 1.5, 77)], [(0, 1, 79), (1, 1, 76), (2, 2, 72)],
         MOTIF, [(0, .5, 82), (.5, .5, 84), (1, 1, 86), (2, 1, 84), (3, 1, 82)],
         [(0, 1, 81), (1, 1, 77), (2, 1, 74), (3, 1, 77)], [(0, 1.5, 79), (1.5, .5, 77), (2, 2, 76)]]
B_MEL = [[(0, 1, 77), (1, .5, 79), (1.5, .5, 81), (2, 2, 82)], [(0, 1, 79), (1, .5, 81), (1.5, .5, 82), (2, 2, 84)],
         [(0, 1.5, 81), (1.5, .5, 79), (2, 1, 76), (3, 1, 72)], [(0, 1, 74), (1, 1, 77), (2, 2, 81)],
         [(0, .5, 79), (.5, .5, 82), (1, 1, 86), (2, 1, 84), (3, 1, 82)], [(0, 2, 79), (2, .5, 76), (2.5, .5, 79), (3, 1, 82)],
         MOTIF, [(0, 2, 77)]]


def uke_strum(s: Song, bar: int, ch: str, vel=70, pattern="island"):
    notes = sorted(CH[ch][:3])
    pat = {"island": [(0, 1, 1), (1, .5, 0), (1.5, .5, 1), (2.5, .5, 1), (3, .5, 0), (3.5, .5, 1)],
           "calm": [(0, 2, 1), (2, 2, 1)]}[pattern]
    for b, d, down in pat:
        vs = notes if down else notes[::-1]
        s.chord("uke", bar * 4 + b, d, vs, vel if down else vel - 12, spread=0.014)


def arp(s: Song, bar: int, ch: str, trk="arp", vel=70, pattern=(0, 1, 2, 3, 2, 1, 0, 1), octave=-12):
    n = CH[ch][:3] + [CH[ch][0] + 12]
    for i, k in enumerate(pattern):
        s.note(trk, bar * 4 + i * .5, .45, n[k] + octave, vel - (0 if i % 2 == 0 else 10))


def bass(s: Song, bar: int, ch: str, vel=88, nxt: str | None = None):
    r = ROOT_NOTE[ch]
    s.note("bass", bar * 4, 1.4, r, vel)
    s.note("bass", bar * 4 + 1.5, .5, r + 7, vel - 15)
    s.note("bass", bar * 4 + 2, 1, r + 12 if r < 46 else r, vel - 5)
    if nxt:
        t = ROOT_NOTE[nxt]
        s.note("bass", bar * 4 + 3, .9, t + (2 if t < r else -1), vel - 18)
    else:
        s.note("bass", bar * 4 + 3, .9, r + 7, vel - 18)


def beach_perc(s: Song, bar: int, intensity: int = 2, fill: bool = False):
    B = bar * 4
    for i in range(8):
        s.note("shaker", B + i * .5, .25, PERC["shaker"], 70 if i % 2 else 50, human=0.006)
    if intensity >= 1:
        s.note("perc", B, .5, PERC["cajon"], 100)
        s.note("perc", B + 2.5, .5, PERC["cajon"], 85)
        s.note("conga", B + 1.5, .5, PERC["conga_hi"], 70)
        s.note("conga", B + 3.5, .5, PERC["conga_hi"], 65)
        s.note("conga", B + 3.75, .25, PERC["conga_lo"], 70)
    if intensity >= 2:
        s.note("perc", B + 1, .5, PERC["cajon_slap"], 80)
        s.note("perc", B + 3, .5, PERC["cajon_slap"], 85)
        s.note("conga", B + 2, .5, PERC["conga_mute"], 55)
    if intensity >= 3:
        s.note("perc", B + 1, .5, PERC["tamb"], 60)
        s.note("perc", B + 3, .5, PERC["tamb"], 60)
    if fill:
        for k, t in enumerate([2, 2.5, 3, 3.25, 3.5, 3.75]):
            s.note("conga", B + t, .25, PERC["bongo_hi"] if k % 2 else PERC["bongo_lo"], 80 + k * 5)
        s.note("perc", B + 3.5, .5, PERC["clap"], 80)


def explore() -> Song:
    s = Song(112, 32, seed=11)
    progs = A_PROG + B_PROG + A_PROG + B_PROG
    mels = A_MEL + B_MEL + A_MEL + B_MEL
    for bar, ch in enumerate(progs):
        nxt = progs[(bar + 1) % len(progs)]
        half2 = bar >= 16
        sec_b = (bar % 16) >= 8
        uke_strum(s, bar, ch, 72 if half2 else 66)
        bass(s, bar, ch, nxt=nxt)
        beach_perc(s, bar, 3 if half2 and not sec_b else 2 if half2 or sec_b else 1, fill=(bar % 8 == 7))
        if sec_b:
            arp(s, bar, ch, vel=72, pattern=(0, 1, 2, 3, 2, 1, 2, 3) if half2 else (0, 2, 1, 3, 2, 1, 0, 2))
        if not half2:
            s.phrase("melody", bar, mels[bar], 96)
            if sec_b and bar % 2 == 1:
                s.phrase("kalimba", bar, [(3, .5, CH[ch][2] + 12), (3.5, .5, CH[ch][1] + 12)], 70)
        else:
            s.phrase("melody2", bar, mels[bar], 92)          # A'/B': melodia passa para a kalimba
            s.phrase("melody", bar, mels[bar], 70, transpose=-12)  # dobra uma oitava abaixo (cor de marimba)
            if not sec_b and bar % 4 == 0:
                s.chord("brass", bar * 4, 1.5, [n - 12 for n in CH[ch][:3]], 78)
                s.chord("brass", bar * 4 + 2.5, .5, [n - 12 for n in CH[ch][:3]], 70)
            if sec_b:
                s.note("pizz", bar * 4, 1, CH[ch][0] - 12, 80)
                s.note("pizz", bar * 4 + 2, 1, CH[ch][2] - 12, 70)
        if bar in (15, 31):
            s.phrase("brass", bar, [(0, .5, 72 - 12), (.5, .5, 77 - 12), (1, 1, 81 - 12)], 90)
    return s


def crossing() -> Song:
    s = Song(100, 24, seed=22)
    prog = ["Dm", "Dm", "Bb", "C", "Dm", "Dm", "Gm", "A7"] * 3
    for bar, ch in enumerate(prog):
        n = CH[ch]
        for i in range(8):  # ostinato de harpa (pizzicato) em colcheias
            s.note("pizz", bar * 4 + i * .5, .4, [n[0], n[1], n[2], n[1]][i % 4] - 12, 74 if i % 2 == 0 else 60)
        s.note("bass", bar * 4, 1.8, ROOT_NOTE[ch], 82)
        s.note("bass", bar * 4 + 2, 1.8, ROOT_NOTE[ch] + (7 if ch != "A7" else 4), 70)
        for i in range(4):
            s.note("conga", bar * 4 + i + .5, .25, PERC["conga_mute"], 58)
        s.note("perc", bar * 4, .5, PERC["cajon"], 80)
        s.note("shaker", bar * 4 + 1, .25, PERC["shaker_soft"], 45)
        s.note("shaker", bar * 4 + 3, .25, PERC["shaker_soft"], 45)
        if bar >= 8 and bar % 2 == 0:  # motivo em menor, tenso mas leve
            s.phrase("melody", bar, [(0, .5, 69), (.5, .5, 74), (1, 1, 77), (2, .5, 76), (2.5, 1.5, 81)] if ch != "Gm" else
                     [(0, 1, 74), (1, 1, 70), (2, 2, 67)], 82)
        if bar >= 16 and bar % 4 == 3:
            s.chord("brass", bar * 4 + 2, 2, [n - 12 for n in CH[ch][:3]], 66)
    return s


def sunset() -> Song:
    s = Song(84, 16, seed=33)
    prog = ["F", "Am", "Bb", "C", "F", "Am", "Bbmaj7", "C7", "Dm", "Am", "Bb", "F", "Gm7", "C", "F", "F"]
    for bar, ch in enumerate(prog):
        n = CH[ch]
        r = ROOT_NOTE[ch]
        for i, k in enumerate([r, n[0] - 12 + 12, n[1], n[2], n[1], n[0]]):  # dedilhado de violao
            s.note("bass", bar * 4 + i * (4 / 6), 1.2, k if i else r, 70 if i else 80)
        uke_strum(s, bar, ch, 50, "calm")
        s.note("shaker", bar * 4 + 1, .25, PERC["shaker_soft"], 38)
        s.note("shaker", bar * 4 + 3, .25, PERC["shaker_soft"], 38)
        if bar in (0, 4, 8, 12):
            s.phrase("kalimba", bar, [(0, 1, 72), (1, 1, 77), (2, 2, 81)] if bar != 12 else MOTIF, 78)
        elif bar % 2 == 1:
            s.phrase("kalimba", bar, [(1, 1, n[2] + 12 if n[2] < 70 else n[2]), (2, 2, n[1] + 12 if n[1] < 70 else n[1])], 64)
    return s


def discovery() -> Song:
    s = Song(120, 2, seed=44)  # ~4 s + cauda
    for i, p in enumerate([65, 69, 72, 77, 81, 84, 89]):
        s.note("kalimba", i * .25, .5, p, 70 + i * 4)
        s.note("melody", i * .25, .3, p, 60 + i * 4)
    s.phrase("brass", 0, [(2, .5, 72 - 12), (2.5, .5, 77 - 12), (3, 1, 81 - 12)], 92)
    s.chord("melody", 4, 3, [77, 81, 84, 89], 92)
    s.chord("uke", 4, 3, [65, 69, 72], 80)
    s.note("bass", 4, 3, 41, 90)
    s.note("perc", 4, .5, PERC["cajon"], 100)
    s.note("shaker", 4, .5, PERC["tamb"], 80)
    return s


def victory() -> Song:
    s = Song(132, 2, seed=55)
    s.phrase("brass", 0, [(b, d, p - 12) for b, d, p in MOTIF], 100)
    s.phrase("melody", 0, MOTIF, 100)
    s.chord("uke", 0, .5, [65, 69, 72], 80)
    s.chord("uke", 1, .5, [65, 69, 72], 70)
    s.chord("uke", 2.5, 3, [65, 69, 72], 85)
    s.chord("brass", 4, 3, [65 - 12, 69 - 12, 72 - 12], 95)
    s.chord("melody", 4, 3, [77, 81, 84], 95)
    s.note("bass", 4, 3, 41, 95)
    for t in (0, 1, 2, 2.5, 4):
        s.note("perc", t, .5, PERC["cajon"] if t != 2.5 else PERC["cajon_slap"], 100)
    s.note("perc", 4, .5, PERC["tamb"], 90)
    s.note("conga", 3.5, .25, PERC["bongo_hi"], 90)
    s.note("conga", 3.75, .25, PERC["bongo_lo"], 90)
    return s


def team_call() -> Song:
    s = Song(160, 1, seed=66)  # 1,5 s
    s.phrase("melody", 0, [(0, .5, 72), (.5, .5, 77), (1, .5, 81), (1.5, .5, 79), (2, 1.5, 84)], 100)
    s.phrase("brass", 0, [(2, 1.5, 72 - 12)], 85)
    s.chord("uke", 2, 1.5, [65, 69, 72], 80)
    s.note("perc", 2, .5, PERC["cajon"], 100)
    s.note("conga", 1.5, .25, PERC["bongo_hi"], 85)
    return s


def main() -> int:
    mdir = OUT_AUDIO / "music"
    report = []

    def out(name, x, loop, ogg=True, extra=None):
        path = mdir / (f"{name}.ogg" if ogg else f"{name}.wav")
        if ogg:
            write_ogg(path, x, SR, quality=0.55)
            dec = load(path, SR, mono=False)
        else:
            from scipy import signal
            x32 = signal.resample_poly(x, 320, 441, axis=0)
            x32 = limit(x32, 32000, -1.5)
            write_wav(path, x32, 32000)
            dec = load(path, 32000, mono=False)
        sr = SR if ogg else 32000
        m = measure(dec, sr)
        rec = {"name": name, "file": res_path(path), "loop": loop, **m, "sample_rate": sr,
               "bytes": path.stat().st_size, **(extra or {})}
        if loop:
            rec["seam_jump"] = round(seam_jump(dec), 5)
            rec["seam_ratio"] = round(seam_ratio(dec), 3)
        else:
            rec["edge_abs"] = round(float(max(np.abs(dec[0]).max(), np.abs(dec[-1]).max())), 5)
        report.append(rec)
        print(f"music  {name:18s} {m['duration']:6.2f}s {m['lufs']:6.1f} LUFS {m['true_peak_dbtp']:5.1f} dBTP"
              + (f" seam {rec['seam_jump']:.4f} (x{rec['seam_ratio']:.2f})" if loop else ""))

    e = explore()
    full = mixdown(e)
    out("theme_explore", master(full, -18.0, True), True,
        extra={"bpm": 112, "bars": 32, "motif": "C5 F5 A5 G5 C6"})
    low = mixdown(e, stems=["uke", "bass", "arp", "shaker", "conga", "pizz", "perc"], extra_gain={"perc": -6, "uke": -2})
    L = len(low)
    low = filt(np.concatenate([low, low]), "lowpass", 4500, SR)[L:]  # filtragem circular: emenda continua
    out("theme_explore_low", master(low, -23.0, True), True, extra={"bpm": 112, "bars": 32})
    out("theme_crossing", master(mixdown(crossing()), -19.0, True), True, extra={"bpm": 100, "bars": 24})
    out("theme_return", master(mixdown(sunset(), wet=0.22), -20.0, True), True, extra={"bpm": 84, "bars": 16})
    d = discovery()
    out("theme_discovery", master(mixdown(d, loop=False)[: int(5.2 * SR)], -17.0, False), False, ogg=False)
    v = victory()
    out("theme_victory", master(mixdown(v, loop=False)[: int(4.6 * SR)], -17.0, False), False)
    t = team_call()
    out("theme_team_call", master(mixdown(t, loop=False, wet=0.12)[: int(1.5 * SR)], -17.0, False), False)
    save_json(HERE / "generated.json", {"tool": "source_audio/music/compose.py + FluidSynth 2.6.3 + SoundFonts FreePats CC0",
                                        "fonts": {k: str(sf2(k).relative_to(ROOT)).replace("\\", "/") for k in FONTS},
                                        "tracks": report})
    return 0


if __name__ == "__main__":
    sys.exit(main())
