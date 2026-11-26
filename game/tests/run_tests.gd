extends SceneTree
## Executa todos os game/tests/test_*.gd. Uso (apos --import):
##   ./tools/godot.ps1 --headless --path game --script res://tests/run_tests.gd
##   ./tools/godot.ps1 --headless --path game --script res://tests/run_tests.gd -- --only=director
##
## Contrato de um arquivo de teste: `extends RefCounted` e `func run(r) -> void` (pode usar await).
## O runner `r` oferece: r.check(cond: bool, label: String), r.tree (SceneTree),
## r.frames(n := 2) para aguardar quadros. Testes nao comprovam render, som, UX nem desempenho.

const SUITE_SLOTS_PREFIX := "user://suite_"

var tree: SceneTree
var failures: int = 0
var passes: int = 0


func check(condition: bool, label: String) -> void:
	if condition:
		passes += 1
		print("PASS  ", label)
	else:
		failures += 1
		printerr("FAIL  ", label)


func frames(count: int = 2) -> void:
	for i in count:
		await process_frame


func _initialize() -> void:
	tree = self
	_run.call_deferred()


func _only_filter() -> String:
	# O PowerShell pode remover o `--`; aceita o filtro tambem entre os argumentos comuns.
	for arg in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if arg.begins_with("--only="):
			return arg.trim_prefix("--only=")
	return ""


func _run() -> void:
	var only := _only_filter()
	var files: Array[String] = []
	for f in DirAccess.get_files_at("res://tests"):
		if f.begins_with("test_") and f.ends_with(".gd") and (only.is_empty() or only in f):
			files.append(f)
	files.sort()
	if files.is_empty():
		printerr("FAIL  nenhum teste encontrado (filtro '%s')" % only)
		quit(1)
		return
	# Nenhum teste grava no salvo real do jogador (user://slot_<n>.save.json, G13): quem quer salvo define o proprio caminho.
	Ep01V3Main.save_path = ""
	Ep01V3Main.start_mission = &""
	_reset_cutscenes()
	_reset_slots()
	for f in files:
		print("== ", f)
		var script := load("res://tests/" + f) as GDScript
		# Script com erro de sintaxe carrega mas nao instancia: falhar e seguir (antes travava a suite).
		if script == null or not script.can_instantiate():
			failures += 1
			printerr("FAIL  nao foi possivel carregar ", f)
			continue
		var test: Object = script.new()
		await test.run(self)
		_reset_shared_state()
	print("RESULTADO: %s (%d PASS, %d FALHA(S))" % ["OK" if failures == 0 else "FALHOU", passes, failures])
	quit(0 if failures == 0 else 1)


## Entre arquivos de teste: tempo normal, nada pressionado, arvore sem pausa (um teste que abortou no meio nao
## contamina os seguintes).
func _reset_shared_state() -> void:
	Engine.time_scale = 1.0
	Ep01V3Main.save_path = ""
	Ep01V3Main.start_mission = &""
	_reset_cutscenes()
	_reset_slots()
	Ep01V3Dialogue.reset_picks()
	for action: StringName in InputMap.get_actions():
		Input.action_release(action)
	paused = false


## D21: cutscenes desligadas por padrao na suite (os testes de cena religam) e vistas so em memoria, nunca no salvo real.
func _reset_cutscenes() -> void:
	Ep01V3Cutscene.enabled = false
	Ep01V3Cutscene.auto_skip = false
	Ep01V3Cutscene.seen_path = ""
	Ep01V3Cutscene.reset_seen()
	GameIntroScene.next_scene = GameIntroScene.EP01_SCENE


## G13: os espacos de jogo da suite sao arquivos proprios (user://suite_slot_<n>...), vazios no inicio de cada arquivo
## de teste; os espacos reais do jogador (user://slot_<n>...) nunca sao lidos nem gravados.
func _reset_slots() -> void:
	SaveSlots.prefix = SUITE_SLOTS_PREFIX
	SaveSlots.active = 0
	for i in SaveSlots.COUNT:
		SaveSlots.erase(i + 1)
	# select() durante um teste aponta o salvo/vistas para o espaco: volta ao "nao grava" da suite
	Ep01V3Main.save_path = ""
	Ep01V3Cutscene.seen_path = ""
