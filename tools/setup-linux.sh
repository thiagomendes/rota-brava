#!/usr/bin/env bash
# Instala a toolchain fixada (tools/toolchain.json) em .tools/ no Linux x86_64 (ex.: Claude Code na nuvem).
# Godot 4.7.2-stable (editor + templates, modo self-contained) e Blender 4.5.16 LTS, com SHA-256 conferido.
# Uso: bash tools/setup-linux.sh [--skip-blender]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CACHE="$ROOT/.tools/cache"; GODOT_DIR="$ROOT/.tools/godot-linux"; BLENDER_DIR="$ROOT/.tools/blender-linux"
mkdir -p "$CACHE" "$GODOT_DIR" "$BLENDER_DIR"

GODOT_VER="4.7.2-stable"; TPL_DIR="4.7.2.stable"
GODOT_URL="https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64.zip"
GODOT_SHA="cadd3204e728a35d3f13adb7fd0d7902636b79f6b95c40c265eb73b6c35329e4"
GODOT_BIN="Godot_v4.7.2-stable_linux.x86_64"
TPL_URL="https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz"
TPL_SHA="f298490b8d44d934be425a5a65a51bf15f422428b229a06a6e11d9ffea248011"
BLENDER_URL="https://download.blender.org/release/Blender4.5/blender-4.5.16-linux-x64.tar.xz"
BLENDER_SHA="23432b064977908beb1ab4b7f32f024e7331105c875c187dce002aff84b10c11"

fetch() { # url sha arquivo
  local url="$1" sha="$2" out="$CACHE/$3"
  if [ ! -f "$out" ]; then echo "Baixando $3"; curl -fL --retry 3 -o "$out" "$url"; fi
  echo "$sha  $out" | sha256sum -c - >/dev/null || { echo "SHA-256 divergente em $3"; rm -f "$out"; exit 1; }
  echo "$out"
}
need() { command -v "$1" >/dev/null 2>&1 || { echo "Falta '$1' (instale: sudo apt-get install -y $2)"; exit 1; }; }
need curl curl; need unzip unzip; need sha256sum coreutils; need xz xz-utils

if [ ! -x "$GODOT_DIR/$GODOT_BIN" ]; then
  z=$(fetch "$GODOT_URL" "$GODOT_SHA" godot-linux.zip | tail -1); unzip -oq "$z" -d "$GODOT_DIR"; chmod +x "$GODOT_DIR/$GODOT_BIN"
fi
touch "$GODOT_DIR/._sc_"   # self-contained: templates e configuracao ao lado do binario
TPL_TARGET="$GODOT_DIR/editor_data/export_templates/$TPL_DIR"
if [ ! -f "$TPL_TARGET/windows_release_x86_64.exe" ]; then
  t=$(fetch "$TPL_URL" "$TPL_SHA" godot-export-templates.tpz | tail -1)
  tmp="$CACHE/tpl"; rm -rf "$tmp"; mkdir -p "$tmp" "$TPL_TARGET"; unzip -oq "$t" -d "$tmp"; cp -r "$tmp/templates/." "$TPL_TARGET/"; rm -rf "$tmp"
fi
"$GODOT_DIR/$GODOT_BIN" --headless --version

if [ "${1:-}" != "--skip-blender" ]; then
  if [ ! -x "$BLENDER_DIR/blender-4.5.16-linux-x64/blender" ]; then
    b=$(fetch "$BLENDER_URL" "$BLENDER_SHA" blender-linux.tar.xz | tail -1); tar -xJf "$b" -C "$BLENDER_DIR"
  fi
  "$BLENDER_DIR/blender-4.5.16-linux-x64/blender" --background --version | head -1 || echo "Aviso: Blender precisa de libs do sistema (ex.: sudo apt-get install -y libxi6 libxkbcommon0 libsm6 libgl1 libegl1)"
fi
echo "Toolchain pronta em $ROOT/.tools"
