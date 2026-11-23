class_name CameraRig
extends Node3D
## Camera em terceira pessoa dirigida por area: segue `target` com deslocamento e giro definidos pelo estagio.

var camera: Camera3D
var target: Node3D
var offset: Vector3 = Vector3(0, 7.5, 9.5)
var look_offset: Vector3 = Vector3(0, 1.0, 0)
## Giro em Y do conjunto; a entrada de movimento usa este valor.
var yaw: float = 0.0
var smooth: float = 4.0
var reduced_motion: bool = false


func _ready() -> void:
	name = "CameraRig"
	camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.fov = 55.0
	camera.current = true
	add_child(camera)


func set_view(new_offset: Vector3, new_yaw: float = 0.0) -> void:
	offset = new_offset
	yaw = new_yaw


func follow(node: Node3D, snap: bool = false) -> void:
	target = node
	if snap:
		_update(1.0)


func _process(delta: float) -> void:
	_update(1.0 if reduced_motion else clampf(smooth * delta, 0.0, 1.0))


func _update(weight: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	var focus := target.global_position
	var wanted := focus + Basis(Vector3.UP, yaw) * offset
	camera.global_position = camera.global_position.lerp(wanted, weight)
	camera.look_at(focus + look_offset, Vector3.UP)
