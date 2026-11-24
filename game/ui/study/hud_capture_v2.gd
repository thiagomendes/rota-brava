extends Node
## Captura do HUD v2 REAL sobre o episodio 01 (estado dock_investigation) ou da tela-titulo, salvando um PNG.
## Uso (com janela): ./tools/godot.ps1 --path game res://ui/study/hud_capture_v2.tscn -- --out=<png> [--title] [--state=hud|handoff|complete]
## O tamanho vem do viewport do projeto (use um game/override.cfg temporario para 20:9 e 4:3).

var _main: Node
var _frame: int = 0
var _out: String = ""
var _state: String = "hud"


func _arg(prefix: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if a.begins_with(prefix):
			return a.trim_prefix(prefix)
	return fallback


func _ready() -> void:
	_out = _arg("--out=", "user://hud_v2.png")
	_state = _arg("--state=", "hud")
	if (OS.get_cmdline_user_args() + OS.get_cmdline_args()).has("--title"):
		_state = "title"
		_main = (load("res://ui/main_menu.tscn") as PackedScene).instantiate()
	else:
		Ep01Main.start_state = &"dock_investigation"
		Ep01Main.carry_completed = []
		_main = (load("res://episodes/ep01/ep01_main.tscn") as PackedScene).instantiate()
	add_child(_main)


func _process(_delta: float) -> void:
	_frame += 1
	if _state == "title":
		if _frame == 90:
			_save()
		return
	var hud: Hud = (_main as Ep01Main).hud
	if hud == null:
		return
	if _state == "hud" and _frame >= 50:
		# O episodio esconde a acao sem alvo; reaplica ao fim do quadro para a captura mostrar o botao.
		(func() -> void: hud.show_prompt(Loc.t("ui.action.examine"), &"magnifier")).call_deferred()
	match _frame:
		30:
			if hud.handoff_open:
				hud.close_handoff()
				hud.handoff_confirmed.emit()
		40:
			hud.clear_speech()
			match _state:
				"handoff":
					hud.open_handoff(Loc.t("study.handoff.text"), &"climber")
				"complete":
					hud.open_complete()
				_:
					var emotes: Array[StringName] = [&"look", &"paw"]
					hud.say("study.sub.tracker.normal", {}, false, emotes)
		50:
			if _state == "hud":
				hud.show_prompt(Loc.t("ui.action.examine"), &"magnifier")
		230:
			if _state == "complete":
				_save.call_deferred()
		110:
			if _state == "hud":
				hud.show_prompt(Loc.t("ui.action.examine"), &"magnifier")
			if _state != "complete":
				_save.call_deferred()


func _save() -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(_out.get_base_dir())
	print("[RB] hud_capture_v2 %s size=%s err=%d" % [_out, img.get_size(), img.save_png(_out)])
	get_tree().quit(0)
