#!/usr/bin/env bash
# Importa o projeto e roda a suite de testes headless com limite de tempo (padrao 15 min).
# Uso: bash tools/test.sh [filtro]      ex.: bash tools/test.sh dialogue
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LIMIT="${RB_TEST_TIMEOUT:-900}"
bash "$ROOT/tools/godot.sh" --headless --path "$ROOT/game" --import >/dev/null 2>&1 || true
ARGS=(--headless --path "$ROOT/game" --script res://tests/run_tests.gd)
[ -n "${1:-}" ] && ARGS+=(-- "--only=$1")
timeout "$LIMIT" bash "$ROOT/tools/godot.sh" "${ARGS[@]}" 2>&1 | grep -E "^(==|FAIL|RESULTADO)|SCRIPT ERROR|Parse Error"
code=${PIPESTATUS[0]}
git -C "$ROOT" checkout -- game/audio/default_bus_layout.tres 2>/dev/null || true   # a Godot reescreve; nunca commitar
[ "$code" = "124" ] && echo "TIMEOUT: suite passou de ${LIMIT}s (teste travado?)"
exit $code
