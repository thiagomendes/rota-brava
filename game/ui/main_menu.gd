class_name MainMenu
extends TitleScreen
## Menu inicial = tela-titulo v2 (game/ui/title/). Jogar, Opcoes, Referencias, Sair. Foco inicial em Jogar
## (SPEC secao 5, Menu e retomada). Os visuais vem de TitleScreen; aqui fica o comportamento.

const PLAY_SCENE := "res://episodes/ep01/v3/ep01_v3_main.tscn"
const REFERENCE_SCENE := "res://episodes/reference/reference_demo.tscn"

var intro_button: Button


func _ready() -> void:
	super._ready()
	play_button.pressed.connect(_on_play_pressed)
	options_button.pressed.connect(_open_options)
	references_button.pressed.connect(_on_references_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	# D21: "Ver abertura" revê a abertura do jogo (pulavel depois da primeira vez) e volta ao menu.
	intro_button = _button("IntroButton", "ui.menu.watch_intro", &"star", &"QuietButton")
	menu.move_child(intro_button, references_button.get_index())
	intro_button.custom_minimum_size.x = references_button.custom_minimum_size.x
	intro_button.pressed.connect(_on_intro_pressed)
	_layout()
	options_panel.back_requested.connect(_close_options)
	play_button.grab_focus()
	print("[RB] menu_ready focus=%s" % play_button.name)
	# Gravacao/demonstracao da build exportada: o exe so abre o menu, entao o bot entra por aqui.
	if OS.get_cmdline_user_args().has("--ep01-demo") or OS.get_cmdline_args().has("--ep01-demo"):
		Ep01V3Cutscene.seen_path = ""  # demonstracao nao grava as cenas vistas
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
	# D21: na primeira vez, a abertura do jogo antes do Ep01 (GameIntroScene segue para PLAY_SCENE).
	var target := GameIntroScene.play_target()
	get_tree().change_scene_to_file(target if target != GameIntroScene.EP01_SCENE else PLAY_SCENE)


func _on_intro_pressed() -> void:
	print("[RB] watch_intro")
	GameIntroScene.next_scene = GameIntroScene.MENU_SCENE
	get_tree().change_scene_to_file(GameIntroScene.SELF_SCENE)


func _on_references_pressed() -> void:
	print("[RB] references")
	get_tree().change_scene_to_file(REFERENCE_SCENE)


func _layout() -> void:
	if intro_button != null:
		intro_button.custom_minimum_size.x = play_button.custom_minimum_size.x
	super._layout()
	if intro_button != null:
		intro_button.custom_minimum_size.x = play_button.custom_minimum_size.x


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
