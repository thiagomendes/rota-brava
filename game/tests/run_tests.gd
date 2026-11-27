extends SceneTree
## Executa todos os game/tests/test_*.gd. Uso (apos --import):
##   ./tools/godot.ps1 --headless --path game --script res://tests/run_tests.gd
##   ./tools/godot.ps1 --headless --path game --script res://tests/run_tests.gd -- --only=director
##
## Contrato de um arquivo de teste: `extends RefCounted` e `func run(r) -> void` (pode usar await).
## O runner `r` oferece: r.check(cond: bool, label: String), r.tree (SceneTree),
## r.frames(n := 2) para aguardar quadros. Testes nao comprovam render, som, UX nem desempenho.

const SUITE_SLOTS_PREFIX := "user://suite_"
## Segundos por arquivo medidos nesta maquina (== TEMPO no fim da suite); so servem para dividir entre processos.
const WEIGHTS := {
	"test_movement.gd": 206.4,
	"test_cutscenes.gd": 140.3,
	"test_movement_f1.gd": 125.7,
	"test_ep01_v3.gd": 58.3,
	"test_camera_tremor.gd": 52.1,
	"test_ep01_v3_late.gd": 51.4,
	"test_ep01_v3_g19.gd": 75.0,
	"test_ep01_v3_dialogue.gd": 49.6,
	"test_camera_wall.gd": 43.1,
	"test_prop_overlap.gd": 41.3,
	"test_game_feel.gd": 37.5,
	"test_playthrough.gd": 35.6,
	"test_ep01_v3_f2_play.gd": 29.2,
	"test_episode_foundation.gd": 22.9,
	"test_characters.gd": 17.6,
	"test_scene_loader.gd": 15.5,
	"test_ui_slots.gd": 13.1,
	"test_keyart.gd": 9.2,
	"test_stage_island.gd": 8.6,
	"test_touch_controls.gd": 8.0,
	"test_stage_dock.gd": 7.4,
	"test_stage_docking.gd": 6.1,
	"test_ep01_v3_input.gd": 6.0,
	"test_foundation.gd": 5.5,
	"test_audio_director.gd": 4.7,
	"test_options_game.gd": 4.3,
	"test_scene_loader_safety.gd": 4.0,
	"test_stage_river.gd": 3.7,
	"test_reference_demo.gd": 3.1,
	"test_villagers.gd": 3.0,
	"test_ep01_v3_bridge_regroup.gd": 2.9,
	"test_ui_brand.gd": 2.5,
	"test_ui_joypad.gd": 2.4,
	"test_ui_study.gd": 2.3,
	"test_rb_r1_integration.gd": 2.2,
	"test_audio_catalog.gd": 2.0,
	"test_ep01_v3_m2_stuck.gd": 1.6,
	"test_ep01_v3_f2_text.gd": 1.5,
	"test_world_v2.gd": 1.1,
	"test_village_world.gd": 1.0,
	"test_assets.gd": 0.8,
	"test_environment.gd": 0.7,
	"test_props_v3.gd": 0.5,
	"test_music_v3.gd": 0.2,
	"test_ep01_v3_portraits.gd": 0.2,
	"test_clues_v3.gd": 0.1,
	"test_ui_glyphs.gd": 0.1,
	"test_voice_v3.gd": 0.1,
	"test_audio_radio_level.gd": 11.0,
	"test_save_slots.gd": 0.1,
	"test_audio_babble.gd": 0.1,
	"test_content.gd": 0.1,
	"test_director.gd": 0.1,
	"test_mission_system.gd": 0.1,
	"test_dialogue.gd": 0.1,
	"test_audio_provenance.gd": 0.1,
}

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


## --skip=a,b tira arquivos (o tools/test.sh roda os de passo fixo num processo proprio).
func _skip_filter() -> String:
	for arg in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if arg.begins_with("--skip="):
			return arg.trim_prefix("--skip=")
	return ""


## Filtro com varios trechos separados por virgula (ex.: --only=keyart,scene_loader), na ordem normal da suite.
## Paralelo (tools/test.sh): --shard=k/n roda so a parte k (1..n). Divisao gulosa pelos tempos medidos em WEIGHTS
## (mais lento primeiro, sempre para o processo menos carregado); arquivo novo sem tempo conta 5 s.
func _shard_arg() -> Vector2i:
	for arg in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if arg.begins_with("--shard="):
			var p := arg.trim_prefix("--shard=").split("/")
			if p.size() == 2:
				return Vector2i(int(p[0]), int(p[1]))
	return Vector2i(0, 0)


func _shard(files: Array[String], k: int, n: int) -> Array[String]:
	var order := files.duplicate()
	order.sort_custom(func(a: String, b: String) -> bool:
		var wa: float = WEIGHTS.get(a, 5.0)
		var wb: float = WEIGHTS.get(b, 5.0)
		return wa > wb if wa != wb else a < b)
	var load_s: Array[float] = []
	load_s.resize(n)
	load_s.fill(0.0)
	var out: Array[String] = []
	for f: String in order:
		var best := 0
		for i in n:
			if load_s[i] < load_s[best]:
				best = i
		load_s[best] += WEIGHTS.get(f, 5.0)
		if best == k - 1:
			out.append(f)
	out.sort()
	return out


func _matches(only: String, f: String) -> bool:
	for part in only.split(",", false):
		if part in f:
			return true
	return false


func _run() -> void:
	var only := _only_filter()
	var skip := _skip_filter()
	var files: Array[String] = []
	for f in DirAccess.get_files_at("res://tests"):
		if f.begins_with("test_") and f.ends_with(".gd") and (only.is_empty() or _matches(only, f)) \
				and (skip.is_empty() or not _matches(skip, f)):
			files.append(f)
	files.sort()
	var sh := _shard_arg()
	if sh.y > 1:
		files = _shard(files, sh.x, sh.y)
		if files.is_empty():
			print("RESULTADO: OK (0 PASS, 0 FALHA(S))")
			quit(0)
			return
	if files.is_empty():
		printerr("FAIL  nenhum teste encontrado (filtro '%s')" % only)
		quit(1)
		return
	# Nenhum teste grava no salvo real do jogador (user://slot_<n>.save.json, G13): quem quer salvo define o proprio caminho.
	Ep01V3Main.save_path = ""
	Ep01V3Main.start_mission = &""
	_reset_cutscenes()
	_reset_slots()
	var times: Dictionary = {}
	for f in files:
		print("== ", f)
		var t0 := Time.get_ticks_msec()
		var script := load("res://tests/" + f) as GDScript
		# Script com erro de sintaxe carrega mas nao instancia: falhar e seguir (antes travava a suite).
		if script == null or not script.can_instantiate():
			failures += 1
			printerr("FAIL  nao foi possivel carregar ", f)
			continue
		var test: Object = script.new()
		await test.run(self)
		_reset_shared_state()
		times[f] = (Time.get_ticks_msec() - t0) / 1000.0
	var order: Array = times.keys()
	order.sort_custom(func(a: String, b: String) -> bool: return times[a] > times[b])
	for f: String in order:
		print("== TEMPO %7.1f s  %s" % [times[f], f])
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
	InputDevice.reset()
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
