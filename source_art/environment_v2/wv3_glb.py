"""Rota Brava · Mundo v2/v3 (RB-R1 E3, D18) · compactacao SEM PERDA VISIVEL de GLB exportado pelo Blender.

So usa o que o glTF 2.0 basico aceita (nenhuma extensao, a Godot importa direto):
  - COLOR_0 em unsigned short normalizado (8 bytes/vertice) -> unsigned byte normalizado (4 bytes/vertice);
  - indices em uint32 -> uint16 quando a primitiva tem menos de 65.536 vertices.
Posicao, normal e UV continuam em float (sem quantizacao, que exigiria KHR_mesh_quantization).
Python puro (struct), roda dentro ou fora do Blender. PROVISORIO ate aprovacao de Thiago.
"""
import json
import struct

UBYTE, USHORT, UINT = 5121, 5123, 5125
COMP = {5120: ("b", 1), 5121: ("B", 1), 5122: ("h", 2), 5123: ("H", 2), 5125: ("I", 4), 5126: ("f", 4)}
NCOMP = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}


def _read(path):
    b = open(path, "rb").read()
    assert b[:4] == b"glTF"
    jl = struct.unpack("<I", b[12:16])[0]
    j = json.loads(b[20:20 + jl])
    off = 20 + jl
    bl = struct.unpack("<I", b[off:off + 4])[0]
    bin_ = b[off + 8:off + 8 + bl]
    return j, bin_


def _acc_bytes(j, bin_, ai):
    a = j["accessors"][ai]
    bv = j["bufferViews"][a["bufferView"]]
    fmt, size = COMP[a["componentType"]]
    n = NCOMP[a["type"]]
    start = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
    stride = bv.get("byteStride", size * n)
    if stride == size * n:
        return bin_[start:start + a["count"] * stride], fmt, n
    out = bytearray()
    for i in range(a["count"]):
        out += bin_[start + i * stride:start + i * stride + size * n]
    return bytes(out), fmt, n


def compact(path):
    """Reescreve o GLB em `path`. Devolve (bytes_antes, bytes_depois)."""
    import os
    before = os.path.getsize(path)
    j, bin_ = _read(path)
    views = []           # (dados, target)
    remap = {}           # accessor -> novo indice de view

    def add_view(data, target):
        views.append((data, target))
        return len(views) - 1

    done = set()
    for m in j.get("meshes", []):
        for pr in m["primitives"]:
            nverts = j["accessors"][pr["attributes"]["POSITION"]]["count"]
            for key, ai in list(pr["attributes"].items()):
                if ai in done:
                    continue
                done.add(ai)
                a = j["accessors"][ai]
                raw, fmt, n = _acc_bytes(j, bin_, ai)
                if key.startswith("COLOR_") and a["componentType"] == USHORT:
                    vals = struct.unpack("<%d%s" % (a["count"] * n, fmt), raw)
                    raw = bytes(min(255, (v * 255 + 32767) // 65535) for v in vals)
                    if n == 3:   # alinhamento de 4 bytes por vertice: passa a RGBA
                        raw = b"".join(raw[i:i + 3] + b"\xff" for i in range(0, len(raw), 3))
                        a["type"] = "VEC4"
                    a["componentType"] = UBYTE
                    a["normalized"] = True
                remap[ai] = add_view(raw, 34962)
                a["byteOffset"] = 0
            if "indices" in pr and pr["indices"] not in done:
                ai = pr["indices"]
                done.add(ai)
                a = j["accessors"][ai]
                raw, fmt, n = _acc_bytes(j, bin_, ai)
                if a["componentType"] == UINT and nverts < 65536:
                    vals = struct.unpack("<%dI" % a["count"], raw)
                    raw = struct.pack("<%dH" % a["count"], *vals)
                    a["componentType"] = USHORT
                remap[ai] = add_view(raw, 34963)
                a["byteOffset"] = 0
    # demais accessors (animacao, matrizes) copiados como estao
    for ai, a in enumerate(j.get("accessors", [])):
        if ai in remap or "bufferView" not in a:
            continue
        raw, fmt, n = _acc_bytes(j, bin_, ai)
        remap[ai] = add_view(raw, None)
        a["byteOffset"] = 0
    # imagens embutidas (nao ha no mundo v2, mas preserva se houver)
    img_views = {}
    for ii, im in enumerate(j.get("images", [])):
        if "bufferView" in im:
            bv = j["bufferViews"][im["bufferView"]]
            s = bv.get("byteOffset", 0)
            img_views[ii] = add_view(bin_[s:s + bv["byteLength"]], None)
    blob = bytearray()
    new_views = []
    for data, target in views:
        while len(blob) % 4:
            blob += b"\x00"
        v = {"buffer": 0, "byteOffset": len(blob), "byteLength": len(data)}
        if target:
            v["target"] = target
        new_views.append(v)
        blob += data
    while len(blob) % 4:
        blob += b"\x00"
    for ai, vi in remap.items():
        j["accessors"][ai]["bufferView"] = vi
    for ii, vi in img_views.items():
        j["images"][ii]["bufferView"] = vi
    j["bufferViews"] = new_views
    j["buffers"] = [{"byteLength": len(blob)}]
    js = json.dumps(j, separators=(",", ":")).encode()
    while len(js) % 4:
        js += b" "
    total = 12 + 8 + len(js) + 8 + len(blob)
    out = struct.pack("<4sII", b"glTF", 2, total) + struct.pack("<I4s", len(js), b"JSON") + js
    out += struct.pack("<I4s", len(blob), b"BIN\x00") + bytes(blob)
    with open(path, "wb") as f:
        f.write(out)
    return before, len(out)


if __name__ == "__main__":
    import sys
    for p in sys.argv[1:]:
        print(p, compact(p))
