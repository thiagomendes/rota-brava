class_name MemberActor
extends CharacterBody3D
## Integrante da equipe a pe (bloco PROVISORIO). Anda relativo a camera; so responde a entrada quando `controlled`.

const SPEED := 4.5
const GRAVITY := 20.0
const TURN_SPEED := 12.0

const COLORS := {
	&"tracker": Color("f28c28"),
	&"climber": Color("5aa469"),
	&"pilot": Color("3f7fd0"),
}

var member: StringName = &""
var controlled: bool = false
## Giro (rad, em Y) da camera; define o que significa "para cima" na entrada.
var move_yaw: float = 0.0
var speed_scale: float = 1.0
var riding_on: Node3D = null
var ride_offset: Vector3 = Vector3.ZERO
var _visual: Node3D
var _face_target: Variant = null


func setup(member_id: StringName) -> void:
	member = member_id
	name = "Actor_" + String(member_id)
	collision_layer = 2
	collision_mask = 1
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.5
	shape.shape = cap
	shape.position.y = 0.75
	add_child(shape)
	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)
	var c: Color = COLORS.get(member_id, Color.WHITE)
	Blocks.cylinder(_visual, "Body", 0.32, 1.0, Vector3(0, 0.6, 0), c)
	Blocks.sphere(_visual, "Head", 0.26, Vector3(0, 1.4, 0), Color("f1d2b0"))
	Blocks.box(_visual, "Nose", Vector3(0.1, 0.1, 0.16), Vector3(0, 1.38, -0.28), Color("e0b48a"))
	match member_id:
		&"tracker":
			Blocks.box(_visual, "Notebook", Vector3(0.08, 0.4, 0.3), Vector3(0.38, 0.8, 0.0), Color("fff3c4"))
		&"climber":
			Blocks.cylinder(_visual, "RopeCoil", 0.26, 0.2, Vector3(0, 0.95, 0.3), Color("ffd24d"))
		&"pilot":
			Blocks.box(_visual, "Vest", Vector3(0.7, 0.45, 0.5), Vector3(0, 0.85, 0.0), Color("f4f4f4"))


func face_point(point: Vector3) -> void:
	_face_target = point


func face_now(point: Vector3) -> void:
	var d := point - global_position
	d.y = 0.0
	if d.length() > 0.01:
		_visual.rotation.y = atan2(-d.x, -d.z)
	_face_target = null


func _physics_process(delta: float) -> void:
	if riding_on != null and is_instance_valid(riding_on):
		global_position = riding_on.to_global(ride_offset)
		velocity = Vector3.ZERO
		if _face_target != null:
			var f: Vector3 = (_face_target as Vector3) - global_position
			f.y = 0.0
			if f.length() > 0.01:
				_visual.rotation.y = lerp_angle(_visual.rotation.y, atan2(-f.x, -f.z), clampf(TURN_SPEED * delta, 0.0, 1.0))
		return
	var dir := Vector2.ZERO
	if controlled:
		dir = Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	var world := Basis(Vector3.UP, move_yaw) * Vector3(dir.x, 0.0, dir.y)
	velocity.x = world.x * SPEED * speed_scale
	velocity.z = world.z * SPEED * speed_scale
	if is_on_floor():
		velocity.y = -0.5
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()
	if world.length() > 0.1:
		_face_target = null
		_visual.rotation.y = lerp_angle(_visual.rotation.y, atan2(-world.x, -world.z), clampf(TURN_SPEED * delta, 0.0, 1.0))
	elif _face_target != null:
		var d: Vector3 = (_face_target as Vector3) - global_position
		d.y = 0.0
		if d.length() > 0.01:
			_visual.rotation.y = lerp_angle(_visual.rotation.y, atan2(-d.x, -d.z), clampf(TURN_SPEED * delta, 0.0, 1.0))


func teleport(pos: Vector3) -> void:
	global_position = pos
	velocity = Vector3.ZERO


## Acompanha um no (ex.: convés do barco) em vez de usar fisica.
func ride(node: Node3D, local_offset: Vector3 = Vector3.ZERO) -> void:
	riding_on = node
	ride_offset = local_offset
	collision_layer = 0


func dismount(pos: Vector3) -> void:
	riding_on = null
	collision_layer = 2
	teleport(pos)
