#!/usr/bin/env bash
# Roda o Blender fixado (Linux). Uso: bash tools/blender.sh --background arquivo.blend --python script.py -- args
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TOOLS="${RB_TOOLS_ROOT:-$ROOT}"
if [ ! -d "$TOOLS/.tools/blender-linux" ]; then
  COMMON="$(git -C "$ROOT" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
  [ -n "$COMMON" ] && [ -d "$(dirname "$COMMON")/.tools/blender-linux" ] && TOOLS="$(dirname "$COMMON")"
fi
BIN="$TOOLS/.tools/blender-linux/blender-4.5.16-linux-x64/blender"
[ -x "$BIN" ] || { echo "Blender ausente. Rode: bash tools/setup-linux.sh"; exit 1; }
exec "$BIN" "$@"
