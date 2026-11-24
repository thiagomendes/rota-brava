class_name MemberActor
extends CharacterBody3D
## Integrante da equipe a pe (bloco PROVISORIO). Anda relativo a camera; so responde a entrada quando `controlled`.

## Emitido a cada contato de pe com o chao (so a pe, nao embarcado), para o som dos passos acompanhar o movimento.
signal footstep(speed: float, position: Vector3)

const SPEED := 2.6
const GRAVITY := 20.0
const TURN_SPEED := 12.0

const MODEL_SCENES := {
	&"tracker": "res://actors/characters/rastro_model.tscn",
	&"pilot": "res://actors/characters/leme_model.tscn",
	&"climber": "res://actors/characters/pico_model.tscn",
}
## Velocidade de caminhada; o clipe `walk` anda ~0,69 m/s, entao a animacao e acelerada (limitada) para o pe nao patinar.
const WALK_ANIM_MAX_SCALE := 3.2
## Acima desta velocidade (m/s) o integrante corre, se o modelo tiver o clipe `run` (RB-R1: criancas correm).
const RUN_THRESHOLD := 1.1

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
var model: CharacterVisual
var riding_on: Node3D = null
var _action_until: float = 0.0
var _step_clock: float = 0.0
var _was_moving: bool = false
var _brief_ride: bool = false
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
	_mount_model(member_id)


## Monta o modelo animado (rig do RB-04) dentro do pivo visual; o corpo fisico continua sendo este CharacterBody3D.
func _mount_model(member_id: StringName) -> void:
	var path: String = MODEL_SCENES.get(member_id, "")
	if path.is_empty() or not ResourceLoader.exists(path):
		return
	var inst := (load(path) as PackedScene).instantiate()
	var m := inst.get_node_or_null("Model")
	if m == null:
		inst.queue_free()
		return
	inst.remove_child(m)
	m.owner = null
	inst.queue_free()
	_visual.add_child(m)
	model = m as CharacterVisual
	Stylize.apply(m)
	Stylize.add_outline(m, 0.008)
	if model != null:
		model.play(&"idle")


## Toca um clipe de uma vez (agachar, tocar a pista, olhar, susto); a selecao automatica espera o fim. Retorna a duracao.
func play_action(anim: StringName, speed: float = 1.0) -> float:
	if model == null or not model.has_animation(anim):
		return 0.0
	var length := model.animation_length(anim) / maxf(speed, 0.01)
	_action_until = Time.get_ticks_msec() / 1000.0 + length
	model.play(anim, speed)
	return length


func set_expression(expr: StringName, weight: float = 1.0) -> void:
	if model != null:
		model.set_expression(expr, weight)


func _update_animation() -> void:
	if model == null or Time.get_ticks_msec() / 1000.0 < _action_until:
		return
	var planar := Vector2(velocity.x, velocity.z).length()
	if riding_on != null and is_instance_valid(riding_on):
		var want: StringName = &"idle"
		if member == &"pilot" and riding_on is BoatActor:
			var boat := riding_on as BoatActor
			if boat.steer > 0.35 and model.has_animation(&"steer_left"):
				want = &"steer_left"
			elif boat.steer < -0.35 and model.has_animation(&"steer_right"):
				want = &"steer_right"
			elif model.has_animation(&"idle_wheel"):
				want = &"idle_wheel"
		model.play(want)
	elif planar > 0.2 and model.has_animation(&"walk"):
		var anim := &"walk"
		var anim_scale := minf(model.walk_speed_scale(planar), WALK_ANIM_MAX_SCALE)
		if planar > RUN_THRESHOLD and model.has_animation(&"run") and model.run_speed_scale(planar) > 0.0:
			anim = &"run"
			anim_scale = model.run_speed_scale(planar)
		model.play(anim, anim_scale)
		_was_moving = true
		# Um passo a cada meio ciclo do clipe, no ritmo real da animacao.
		_step_clock += get_physics_process_delta_time() * anim_scale
		if _step_clock >= model.animation_length(anim) * 0.5 and is_on_floor():
			_step_clock = 0.0
			footstep.emit(planar, global_position)
	else:
		_step_clock = 0.0
		if _was_moving and model.has_animation(&"stop"):
			_was_moving = false
			play_action(&"stop")
			return
		_was_moving = false
		model.play(&"idle")


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
		_update_animation()
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
	_update_animation()
	if world.length() > 0.1:
		_face_target = null
		_visual.rotation.y = lerp_angle(_visual.rotation.y, atan2(-world.x, -world.z), clampf(TURN_SPEED * delta, 0.0, 1.0))
	elif _face_target != null:
		var d: Vector3 = (_face_target as Vector3) - global_position
		d.y = 0.0
		if d.length() > 0.01:
			_visual.rotation.y = lerp_angle(_visual.rotation.y, atan2(-d.x, -d.z), clampf(TURN_SPEED * delta, 0.0, 1.0))


func teleport(pos: Vector3) -> void:
	if _brief_ride:
		riding_on = null
		collision_layer = 2
		_brief_ride = false
	global_position = pos
	velocity = Vector3.ZERO


## Acompanha um no (ex.: convés do barco) em vez de usar fisica.
func ride(node: Node3D, local_offset: Vector3 = Vector3.ZERO) -> void:
	riding_on = node
	ride_offset = local_offset
	collision_layer = 0


## Embarque breve (RB-R1: subir ao conves para tocar a pista do banco); um teleport ou dismount encerra.
func ride_briefly(node: Node3D, local_offset: Vector3) -> void:
	ride(node, local_offset)
	_brief_ride = true
	global_position = node.to_global(local_offset)


func dismount(pos: Vector3) -> void:
	_brief_ride = false
	riding_on = null
	collision_layer = 2
	teleport(pos)

