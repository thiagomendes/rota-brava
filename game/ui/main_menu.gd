class_name MainMenu
extends Control
## Menu inicial: Jogar, Opcoes, Sair. Foco inicial em Jogar (SPEC secao 5, Menu e retomada).

const PLAY_SCENE := "res://ui/play_placeholder.tscn"

@onready var menu: VBoxContainer = %Menu
@onready var play_button: Button = %PlayButton
@onready var options_button: Button = %OptionsButton
@onready var quit_button: Button = %QuitButton
@onready var options_panel: PanelContainer = %OptionsPanel
@onready var back_button: Button = %BackButton


func _ready() -> void:
	play_button.pressed.connect(_on_play_pressed)
	options_button.pressed.connect(_open_options)
	quit_button.pressed.connect(_on_quit_pressed)
	back_button.pressed.connect(_close_options)
	play_button.grab_focus()
	print("[RB] menu_ready focus=%s" % play_button.name)


func _unhandled_input(event: InputEvent) -> void:
	if options_panel.visible and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_close_options()


func _on_play_pressed() -> void:
	print("[RB] play")
	get_tree().change_scene_to_file(PLAY_SCENE)


func _open_options() -> void:
	menu.visible = false
	options_panel.visible = true
	back_button.grab_focus()
	print("[RB] options_open")


func _close_options() -> void:
	options_panel.visible = false
	menu.visible = true
	options_button.grab_focus()
	print("[RB] options_close")


func _on_quit_pressed() -> void:
	print("[RB] quit")
	get_tree().quit(0)
