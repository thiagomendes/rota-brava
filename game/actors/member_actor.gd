class_name MemberActor
extends CharacterBody3D
## Integrante da equipe a pe (bloco PROVISORIO). Anda relativo a camera; so responde a entrada quando `controlled`.

## Emitido a cada contato de pe com o chao (so a pe, nao embarcado), para o som dos passos acompanhar o movimento.
signal footstep(speed: float, position: Vector3)
## Fim de um salto programado (`jump_to`).
signal landed(position: Vector3)

## Velocidade alvo de crianca correndo (m/s) e rampas de partida/parada (s) - sensacao a pe (RB-R1).
const SPEED := 3.2
const ACCEL_TIME := 0.12
const STOP_TIME := 0.08
## Analogico pouco inclinado: anda devagar (ate WALK_SPEED) antes de chegar a corrida.
const WALK_SPEED := 1.3
const WALK_INPUT := 0.55
const RUN_THRESHOLD := 1.8
const GRAVITY := 20.0
const TURN_SPEED := 14.0

const MODEL_SCENES := {
	&"tracker": "res://actors/characters/rastro_model.tscn",
	&"pilot": "res://actors/characters/leme_model.tscn",
	&"climber": "res://actors/characters/pico_model.tscn",
}
## Velocidade de caminhada; o clipe `walk` anda ~0,69 m/s, entao a animacao e acelerada (limitada) para o pe nao patinar.
const WALK_ANIM_MAX_SCALE := 3.2

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
## Em salto programado: a fisica de caminhada fica parada ate pousar.
var airborne: bool = false
var _jump_tween: Tween


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
	CharacterVisual.stylize_if_toon(m, 0.008)
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


## Liga/desliga um acessorio do modelo (ex.: `set_accessory(&"Acc_LifeVest", true)` na missao de barco). False se nao existe.
func set_accessory(acc_name: StringName, on: bool) -> bool:
	return model != null and model.set_accessory(acc_name, on)


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
	if airborne:
		return
	var dir := Vector2.ZERO
	if controlled:
		dir = Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	var world := Basis(Vector3.UP, move_yaw) * Vector3(dir.x, 0.0, dir.y)
	var want := Vector3.ZERO
	if world.length() > 0.01:
		want = world.normalized() * target_speed(dir.length()) * speed_scale
	var planar_v := step_planar(Vector3(velocity.x, 0.0, velocity.z), want, delta)
	velocity.x = planar_v.x
	velocity.z = planar_v.z
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


## Velocidade alvo para uma inclinacao do analogico (0..1): ate WALK_INPUT anda devagar; acima, rampa ate a corrida.
static func target_speed(tilt: float) -> float:
	tilt = clampf(tilt, 0.0, 1.0)
	if tilt < 0.12:
		return 0.0
	if tilt <= WALK_INPUT:
		return WALK_SPEED * tilt / WALK_INPUT
	return lerpf(WALK_SPEED, SPEED, (tilt - WALK_INPUT) / (1.0 - WALK_INPUT))


## Um passo da rampa: acelera ate SPEED em ACCEL_TIME e para em STOP_TIME (freia tambem ao inverter).
static func step_planar(current: Vector3, want: Vector3, delta: float) -> Vector3:
	var rate := SPEED / ACCEL_TIME
	if want.length() < current.length() - 0.01 or want.dot(current) < 0.0:
		rate = SPEED / STOP_TIME
	return current.move_toward(want, rate * delta)


## Direcao para onde o ator olha (plano XZ).
func facing() -> Vector3:
	return Basis(Vector3.UP, _visual.rotation.y) * Vector3.FORWARD


## Salto programado em arco ate `to` (posicao dos pes). Suspende a caminhada; emite `landed` ao pousar.
## Usa o clipe `jump` se o modelo tiver; o arco e sempre programatico (o clipe so anima o corpo).
func jump_to(to: Vector3, duration: float = 0.55, height: float = 1.0) -> void:
	if _jump_tween and _jump_tween.is_valid():
		_jump_tween.kill()
	airborne = true
	velocity = Vector3.ZERO
	var from := global_position
	var d := to - from
	d.y = 0.0
	if d.length() > 0.05:
		_face_target = null
		_visual.rotation.y = atan2(-d.x, -d.z)
	if model != null and model.has_animation(&"jump"):
		play_action(&"jump", model.animation_length(&"jump") / maxf(duration, 0.1))
	_jump_tween = create_tween()
	_jump_tween.tween_method(func(t: float) -> void:
		var p := from.lerp(to, t)
		p.y += height * 4.0 * t * (1.0 - t)
		global_position = p, 0.0, 1.0, duration)
	_jump_tween.finished.connect(func() -> void:
		global_position = to
		airborne = false
		velocity = Vector3.ZERO
		landed.emit(to))


func teleport(pos: Vector3) -> void:
	if _jump_tween and _jump_tween.is_valid():
		_jump_tween.kill()
	airborne = false
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

