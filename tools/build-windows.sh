#!/usr/bin/env bash
# Exporta a build Windows a partir do Linux (templates 4.7.2 instalados por tools/setup-linux.sh).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/build/windows"; rm -rf "$OUT"; mkdir -p "$OUT"
echo "> godot --headless --path game --import"
bash "$ROOT/tools/godot.sh" --headless --path "$ROOT/game" --import
echo "> godot --headless --path game --export-release 'Windows Desktop' $OUT/RotaBrava.exe"
bash "$ROOT/tools/godot.sh" --headless --path "$ROOT/game" --export-release "Windows Desktop" "$OUT/RotaBrava.exe"
git -C "$ROOT" checkout -- game/audio/default_bus_layout.tres 2>/dev/null || true
ls -la "$OUT"
