class_name PlayPlaceholder
extends Control
## Tela provisoria que prova a entrada por intencoes. Sera substituida pelo episodio (RB-02).

const MENU_SCENE := "res://ui/main_menu.tscn"

var action_count: int = 0

@onready var counter: Label = %Counter
@onready var back_button: Button = %BackButton


func _ready() -> void:
	back_button.pressed.connect(_back_to_menu)
	print("[RB] play_ready")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"interact") and not event.is_echo():
		action_count += 1
		counter.text = "Ações: %d" % action_count
		print("[RB] interact count=%d" % action_count)
	elif event.is_action_pressed(&"pause") and not event.is_echo():
		get_viewport().set_input_as_handled()
		_back_to_menu()


func _back_to_menu() -> void:
	print("[RB] back_to_menu")
	get_tree().change_scene_to_file(MENU_SCENE)
