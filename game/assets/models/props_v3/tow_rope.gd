class_name PropsV3TowRope
extends PropsV3Piece
## Corda de reboque do M6 (RB-R1, art3d). `Model/pv3_rope_span` tem 1 m ao longo de +Z a partir da origem; `length`
## escala so esse trecho, leva a alca do fim (`Model/pv3_rope_eye_end`) e o marcador `End` para z = length.
## `coiled` mostra so o rolo (`Model/pv3_rope_coil`, o que o Pico carrega/joga) e esconde o trecho esticado.

@export_range(0.3, 30.0, 0.05) var length: float = 3.0:
	set(v):
		length = v
		_apply()
@export var coiled: bool = false:
	set(v):
		coiled = v
		_apply()


func _ready() -> void:
	_apply()
	super._ready()


func _apply() -> void:
	var span := get_node_or_null(^"Model/pv3_rope_span") as Node3D
	if span == null:
		return
	span.scale = Vector3(1.0, 1.0, length)
	span.visible = not coiled
	for n: NodePath in [^"Model/pv3_rope_eye_start", ^"Model/pv3_rope_eye_end"]:
		var e := get_node_or_null(n) as Node3D
		if e != null:
			e.visible = not coiled
	var eye_end := get_node_or_null(^"Model/pv3_rope_eye_end") as Node3D
	if eye_end != null:
		eye_end.position = Vector3(0.0, 0.0, length)
	var coil := get_node_or_null(^"Model/pv3_rope_coil") as Node3D
	if coil != null:
		coil.visible = coiled
	var end := get_node_or_null(^"End") as Node3D
	if end != null:
		end.position = Vector3(0.0, 0.0, length)
