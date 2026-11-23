class_name Ep01Interactable
extends Node3D
## Alvo de interacao contextual. O jogador mostra a acao quando o integrante ativo esta ao alcance
## (distancia horizontal <= radius) e a pressao de `interact` dispara `triggered` uma vez por pressao.

signal triggered(actor: Node3D)

const GROUP := &"ep01_interactables"

@export var action_id: StringName = &""
## Chave de Loc para o rotulo curto da acao (ex.: ui.action.examine).
@export var label_key: String = ""
## Icone desenhado por IconView: paw, boot, notebook, line, helm, boat, bank, harbor.
@export var icon: StringName = &"notebook"
## Integrante exigido; vazio aceita qualquer ativo.
@export var member: StringName = &""
@export var radius: float = 1.8
var enabled: bool = true
var label_params: Dictionary = {}


func _ready() -> void:
	add_to_group(GROUP)


func can_use(active_member: StringName) -> bool:
	return enabled and is_visible_in_tree() and (member == &"" or member == active_member)


func distance_to(point: Vector3) -> float:
	var d := global_position - point
	d.y = 0.0
	return d.length()


func trigger(actor: Node3D) -> void:
	triggered.emit(actor)
