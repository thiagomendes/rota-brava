"""Fixa a importacao de WAV em PCM (compress/mode=0): o padrao da Godot para WAV novo e compactado, o que
quebra a leitura de amostras nos testes e altera o som. Cria .import minimo para WAV novo; a Godot completa
uid/path no proximo --import. OGG nao precisa (loop ligado em codigo pelo AudioDirector)."""
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import OUT_AUDIO  # noqa: E402

STUB = """[remap]

importer="wav"
type="AudioStreamWAV"

[params]

force/8_bit=false
force/mono=false
force/max_rate=false
force/max_rate_hz=44100
edit/trim=false
edit/normalize=false
edit/loop_mode=0
edit/loop_begin=0
edit/loop_end=-1
compress/mode=0
"""

n_new = n_fix = 0
for wav in OUT_AUDIO.rglob("*.wav"):
    imp = wav.with_name(wav.name + ".import")
    if not imp.exists():
        imp.write_text(STUB, encoding="utf-8")
        n_new += 1
        continue
    t = imp.read_text(encoding="utf-8")
    t2 = re.sub(r"compress/mode=\d+", "compress/mode=0", t)
    t2 = re.sub(r"edit/trim=true", "edit/trim=false", t2)
    t2 = re.sub(r"edit/normalize=true", "edit/normalize=false", t2)
    if t2 != t:
        imp.write_text(t2, encoding="utf-8")
        n_fix += 1
print(f"imports WAV: {n_new} novos (stub PCM), {n_fix} corrigidos para PCM")
