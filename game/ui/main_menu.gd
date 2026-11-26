class_name MainMenu
extends TitleScreen
## Menu inicial = tela-titulo v2 (game/ui/title/). G12: so Jogar, Opcoes e Sair, foco inicial em Jogar (SPEC secao 5,
## Menu e retomada). "Rever abertura" fica dentro de Opcoes. A demo antiga de referencias saiu da interface: abre so
## por `--ref-demo` na linha de comando. G13: Jogar abre os 3 espacos de jogo (SlotScreen) por cima do menu, sem
## carregar 3D; escolher um cartao entra no Ep01 daquele espaco. Os visuais vem de TitleScreen; aqui fica o
## comportamento.

const PLAY_SCENE := "res://episodes/ep01/v3/ep01_v3_main.tscn"
const REFERENCE_SCENE := "res://episodes/reference/reference_demo.tscn"

## Opcoes > Rever abertura.
var intro_button: Button
## G13: tela dos espacos de jogo (escondida ate apertar Jogar).
var slot_screen: SlotScreen


func _ready() -> void:
	# G13: o salvo antigo (user://missions.save.json) vira o espaco 1 uma unica vez, antes de qualquer leitura.
	SaveSlots.migrate()
	super._ready()
	play_button.pressed.connect(_on_play_pressed)
	options_button.pressed.connect(_open_options)
	quit_button.pressed.connect(_on_quit_pressed)
	# G12/D21: "Rever abertura" (pulavel depois da primeira vez) dentro de Opcoes; volta ao menu no fim.
	intro_button = options_panel.add_intro_button()
	options_panel.intro_requested.connect(_on_intro_pressed)
	options_panel.back_requested.connect(_close_options)
	slot_screen = SlotScreen.new()
	slot_screen.visible = false
	add_child(slot_screen)
	slot_screen.ui_sound.connect(func(n: StringName) -> void: ui_sound.emit(n))
	slot_screen.back_requested.connect(_close_slots)
	slot_screen.play_requested.connect(func(_slot: int) -> void: _start_episode())
	_layout()
	play_button.grab_focus()
	print("[RB] menu_ready focus=%s" % play_button.name)
	# Gravacao/demonstracao da build exportada: o exe so abre o menu, entao o bot entra por aqui (sem espaco de jogo:
	# o bot comeca do zero e nao grava).
	if OS.get_cmdline_user_args().has("--ep01-demo") or OS.get_cmdline_args().has("--ep01-demo"):
		Ep01V3Cutscene.seen_path = ""  # demonstracao nao grava as cenas vistas
		_start_episode.call_deferred()
	elif OS.get_cmdline_user_args().has("--ref-demo") or OS.get_cmdline_args().has("--ref-demo"):
		_open_reference_demo.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if options_panel.visible and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		ui_sound.emit(&"back")
		_close_options()


func _process(delta: float) -> void:
	super._process(delta)
	# a arte-chave pode terminar de carregar com os espacos abertos: fica escondida (nada de 3D atras deles)
	if slot_screen != null and slot_screen.visible and key_art != null and key_art.visible:
		key_art.visible = false


## G13: Jogar abre os espacos de jogo.
func _on_play_pressed() -> void:
	print("[RB] play")
	menu.visible = false
	logo.visible = false
	if key_art != null:
		key_art.visible = false
	slot_screen.open()
	print("[RB] slots_open")


func _close_slots() -> void:
	slot_screen.visible = false
	menu.visible = true
	logo.visible = true
	if key_art != null:
		key_art.visible = true
	play_button.grab_focus()
	print("[RB] slots_close")


## Entra no Ep01 do espaco escolhido (ou da demonstracao). D21: na primeira vez do espaco, a abertura do jogo antes
## (GameIntroScene segue para PLAY_SCENE).
func _start_episode() -> void:
	var target := GameIntroScene.play_target()
	SceneLoaderService.go(target if target != GameIntroScene.EP01_SCENE else PLAY_SCENE)


func _on_intro_pressed() -> void:
	print("[RB] replay_intro")
	GameIntroScene.next_scene = GameIntroScene.MENU_SCENE
	SceneLoaderService.go(GameIntroScene.SELF_SCENE)


## So pela linha de comando (`--ref-demo`): a demo antiga de referencias saiu da interface (G12).
func _open_reference_demo() -> void:
	print("[RB] references")
	SceneLoaderService.go(REFERENCE_SCENE)


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
