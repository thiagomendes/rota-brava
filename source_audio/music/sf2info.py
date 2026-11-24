"""Lista presets (banco, programa, nome) e, para kits, as teclas mapeadas de um SoundFont 2."""
import struct
import sys


def presets(path):
    data = open(path, "rb").read()
    out = []
    i = data.find(b"phdr")
    size = struct.unpack_from("<I", data, i + 4)[0]
    for k in range(size // 38 - 1):
        name, prog, bank = struct.unpack_from("<20sHH", data, i + 8 + k * 38)
        out.append((bank, prog, name.split(b"\0")[0].decode("latin1")))
    return out


if __name__ == "__main__":
    for p in sys.argv[1:]:
        print(p)
        for b in presets(p):
            print("  ", b)
