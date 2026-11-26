#!/usr/bin/env bash
# RB-R1 G6: lista props que se interpenetram ou flutuam na vila v3 com as pecas das missoes montadas.
# Uso: bash tools/prop-overlap.sh [--missions=M4,M5] [--json=/caminho/absoluto.json]
# Criterios: game/tests/prop_overlap.gd. So leitura: nao altera o projeto.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
timeout "${RB_OVERLAP_TIMEOUT:-1200}" bash "$ROOT/tools/godot.sh" --headless --path "$ROOT/game" \
  --script res://tests/prop_overlap_report.gd -- "$@" 2>&1 | grep --line-buffered -E "^\[G6\]|SCRIPT ERROR|Parse Error|ERROR: .*prop_overlap"
code=${PIPESTATUS[0]}
git -C "$ROOT" checkout -- game/audio/default_bus_layout.tres 2>/dev/null || true
exit $code
