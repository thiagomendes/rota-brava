#!/usr/bin/env bash
# Importa o projeto e roda a suite de testes headless com limite de tempo (padrao 15 min).
# Uso: bash tools/test.sh [filtro]      ex.: bash tools/test.sh dialogue   (filtro aceita a,b,c)
#
# Modo paralelo (RB-R1 E7, 2026-11-27): a suite roda em RB_TEST_JOBS processos Godot ao mesmo tempo (padrao 3;
# RB_TEST_JOBS=1 = um processo so, como antes). `run_tests.gd --shard=k/n` divide os arquivos pelos tempos medidos
# (WEIGHTS em game/tests/run_tests.gd, mais lento primeiro para o processo menos carregado).
# Os arquivos em FIXED_FPS (hoje camera_tremor) rodam num processo a parte com `--fixed-fps 60`: o delta de cada
# quadro deixa de depender do relogio da maquina e a medida fica deterministica.
# Cada processo tem o seu XDG_DATA_HOME (user:// proprio) e log em logs/test-<processo>.log. A saida mostra as linhas
# ==/FAIL/erros de cada processo e um RESULTADO: unico com a soma; codigo != 0 se algum processo falhar.
# RB_TEST_TIMEOUT vale para cada processo (rodam juntos). Tempos por arquivo: linhas "== TEMPO" de cada processo;
# copie-as para WEIGHTS quando a divisao ficar desequilibrada.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
JOBS="${RB_TEST_JOBS:-3}"
# serial (RB_TEST_JOBS=1) leva ~20 min: limite padrao maior nesse modo
if [ "$JOBS" = "1" ]; then LIMIT="${RB_TEST_TIMEOUT:-2700}"; else LIMIT="${RB_TEST_TIMEOUT:-900}"; fi
FIXED_FPS="camera_tremor"
FILTER="${1:-}"
# user:// isolado por checkout: worktrees rodando testes ao mesmo tempo nao dividem saves (G, 2026-11-26)
XDG_BASE="${RB_TEST_XDG:-$ROOT/logs/test-xdg}"
mkdir -p "$XDG_BASE" "$ROOT/logs"
bash "$ROOT/tools/godot.sh" --headless --path "$ROOT/game" --import >/dev/null 2>&1 || true
PAT="^(==|FAIL|RESULTADO)|SCRIPT ERROR|Parse Error"
start=$(date +%s)

run_one() {  # <processo> <xdg> <argumentos da Godot...>
	local tag="$1" xdg="$2"; shift 2
	mkdir -p "$xdg"
	XDG_DATA_HOME="$xdg" timeout "$LIMIT" bash "$ROOT/tools/godot.sh" --headless --path "$ROOT/game" "$@" \
		> "$ROOT/logs/test-$tag.log" 2>&1
	echo $? > "$ROOT/logs/test-$tag.code"
}

only=()
[ -n "$FILTER" ] && only=("--only=$FILTER")
tags=()
if [ "$JOBS" -le 1 ]; then
	run_one serial "$XDG_BASE" --script res://tests/run_tests.gd -- "${only[@]}"
	tags=(serial)
else
	for k in $(seq 1 "$JOBS"); do
		run_one "shard-$k" "$XDG_BASE/shard-$k" --script res://tests/run_tests.gd -- "${only[@]}" \
			"--skip=$FIXED_FPS" "--shard=$k/$JOBS" &
		tags+=("shard-$k")
	done
	want_fixed=0; [ -z "$FILTER" ] && want_fixed=1
	IFS=',' read -ra parts <<<"$FILTER"
	for p in "${parts[@]}"; do [[ "test_${FIXED_FPS}.gd" == *"$p"* ]] && want_fixed=1; done
	if [ "$want_fixed" = 1 ]; then
		run_one fixed "$XDG_BASE/fixed" --fixed-fps 60 --script res://tests/run_tests.gd -- "--only=$FIXED_FPS" &
		tags+=(fixed)
	fi
	wait
fi

pass=0; fail=0; code=0
for t in "${tags[@]}"; do
	log="$ROOT/logs/test-$t.log"; c=$(cat "$ROOT/logs/test-$t.code")
	[ "$JOBS" -gt 1 ] && echo "## processo $t (codigo $c)"
	grep -E "$PAT" "$log" | grep -v "^RESULTADO"
	r=$(grep "^RESULTADO" "$log" | tail -1)
	if [ -n "$r" ]; then
		pass=$((pass + $(sed -E 's/.*\(([0-9]+) PASS.*/\1/' <<<"$r")))
		fail=$((fail + $(sed -E 's/.*, ([0-9]+) FALHA.*/\1/' <<<"$r")))
	else
		fail=$((fail + 1)); echo "FAIL  processo $t terminou sem RESULTADO (codigo $c)"
	fi
	[ "$c" = "124" ] && echo "TIMEOUT: processo $t passou de ${LIMIT}s (teste travado?)"
	[ "$c" != "0" ] && code=$c
done
# G26: SCRIPT ERROR / Parse Error em qualquer log de processo reprova a rodada (um erro desses aborta a funcao no
# meio sem nenhum FAIL). Excecoes so pela lista versionada tools/test_error_allow.txt (regex ERE | motivo).
ALLOW="$ROOT/tools/test_error_allow.txt"
allow_re="$ROOT/logs/test-error-allow.re"
: > "$allow_re"
[ -f "$ALLOW" ] && grep -vE '^[[:space:]]*(#|$)' "$ALLOW" | sed -E 's/[[:space:]]+\|[[:space:]].*$//' > "$allow_re"
errs="$ROOT/logs/test-errors.txt"; : > "$errs"
for t in "${tags[@]}"; do
	grep -hE "SCRIPT ERROR|Parse Error" "$ROOT/logs/test-$t.log" >> "$errs"
done
allowed=0
if [ -s "$allow_re" ]; then
	allowed=$(grep -cEf "$allow_re" "$errs")
	grep -vEf "$allow_re" "$errs" > "$errs.tmp"; mv "$errs.tmp" "$errs"
fi
nerr=$(wc -l < "$errs")
[ "$allowed" -gt 0 ] && echo "== erros permitidos por tools/test_error_allow.txt: $allowed"
if [ "$nerr" -gt 0 ]; then
	echo "FAIL  $nerr erro(s) de script nos logs (contagem por mensagem):"
	sed -E 's/^[[:space:]]+//' "$errs" | sort | uniq -c | sort -rn | head -40
	fail=$((fail + 1)); [ "$code" = "0" ] && code=1
fi
git -C "$ROOT" checkout -- game/audio/default_bus_layout.tres 2>/dev/null || true   # a Godot reescreve; nunca commitar
[ "$fail" -gt 0 ] && [ "$code" = "0" ] && code=1
if [ $((pass + fail)) = 0 ]; then echo "FAIL  nenhum teste encontrado (filtro '$FILTER')"; fail=1; code=1; fi
echo "== tempo total $(( $(date +%s) - start )) s com $JOBS processo(s)"
echo "RESULTADO: $([ "$code" = 0 ] && echo OK || echo FALHOU) ($pass PASS, $fail FALHA(S))"
exit $code
