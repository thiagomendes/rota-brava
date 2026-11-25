class_name MainMenu
extends TitleScreen
## Menu inicial = tela-titulo v2 (game/ui/title/). Jogar, Opcoes, Referencias, Sair. Foco inicial em Jogar
## (SPEC secao 5, Menu e retomada). Os visuais vem de TitleScreen; aqui fica o comportamento.

const PLAY_SCENE := "res://episodes/ep01/v3/ep01_v3_main.tscn"
const REFERENCE_SCENE := "res://episodes/reference/reference_demo.tscn"


func _ready() -> void:
	super._ready()
	play_button.pressed.connect(_on_play_pressed)
	options_button.pressed.connect(_open_options)
	references_button.pressed.connect(_on_references_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	options_panel.back_requested.connect(_close_options)
	play_button.grab_focus()
	print("[RB] menu_ready focus=%s" % play_button.name)
	# Gravacao/demonstracao da build exportada: o exe so abre o menu, entao o bot entra por aqui.
	if OS.get_cmdline_user_args().has("--ep01-demo") or OS.get_cmdline_args().has("--ep01-demo"):
		_on_play_pressed.call_deferred()
	elif OS.get_cmdline_user_args().has("--ref-demo") or OS.get_cmdline_args().has("--ref-demo"):
		_on_references_pressed.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if options_panel.visible and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		ui_sound.emit(&"back")
		_close_options()


func _on_play_pressed() -> void:
	print("[RB] play")
	get_tree().change_scene_to_file(PLAY_SCENE)


func _on_references_pressed() -> void:
	print("[RB] references")
	get_tree().change_scene_to_file(REFERENCE_SCENE)


func _open_options() -> void:
	menu.visible = false
	logo.visible = false
	_layout()
	options_panel.open()
	print("[RB] options_open")


func _close_options() -> void:
	options_panel.visible = false
	menu.visible = true
	logo.visible = true
	options_button.grab_focus()
	print("[RB] options_close")


func _on_quit_pressed() -> void:
	print("[RB] quit")
	get_tree().quit(0)
