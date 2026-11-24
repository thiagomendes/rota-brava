#!/usr/bin/env bash
# Roda a Godot fixada (Linux). Em worktrees usa a .tools do checkout principal. Uso: bash tools/godot.sh <args>
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TOOLS="${RB_TOOLS_ROOT:-$ROOT}"
if [ ! -d "$TOOLS/.tools/godot-linux" ]; then
  COMMON="$(git -C "$ROOT" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
  [ -n "$COMMON" ] && [ -d "$(dirname "$COMMON")/.tools/godot-linux" ] && TOOLS="$(dirname "$COMMON")"
fi
BIN="$TOOLS/.tools/godot-linux/Godot_v4.7.2-stable_linux.x86_64"
[ -x "$BIN" ] || { echo "Godot ausente. Rode: bash tools/setup-linux.sh"; exit 1; }
exec "$BIN" "$@"
