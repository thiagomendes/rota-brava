class_name MemberActor
extends CharacterBody3D
## Integrante da equipe a pe (bloco PROVISORIO). Anda relativo a camera; so responde a entrada quando `controlled`.

## Emitido a cada contato de pe com o chao (so a pe, nao embarcado), para o som dos passos acompanhar o movimento.
signal footstep(speed: float, position: Vector3)
## Fim de um salto programado (`jump_to`).
signal landed(position: Vector3)

## Velocidade de crianca correndo (m/s, segurando `run`) e rampas de partida/parada (s) - sensacao a pe (RB-R1).
const SPEED := 3.2
const RUN_SPEED := SPEED
const ACCEL_TIME := 0.12
const STOP_TIME := 0.08
## RB-R1 C2: andar e o padrao (ate WALK_SPEED); segurando `run`, ate RUN_SPEED. A inclinacao do analogico escala as duas.
const WALK_SPEED := 1.4
const DEADZONE := 0.12
## Acima deste ritmo o clipe e `run`; abaixo, `walk` (entre os dois so passa a rampa de 0,12 s).
const RUN_THRESHOLD := 2.2
const GRAVITY := 20.0
## Pulo do jogador (C2): curto e infantil, so fisica (respeita colisao e limites do mapa), sem dano de queda.
const JUMP_HEIGHT := 0.42
const JUMP_VELOCITY := 4.0988  # sqrt(2 * GRAVITY * JUMP_HEIGHT)
## Seguidores (C2): param em formacao atras e ao lado do lider (m, referencial do lider: +X direita, +Z atras).
const FORMATION_SLOTS: Array[Vector3] = [Vector3(-0.95, 0.0, 1.05), Vector3(0.95, 0.0, 1.05)]
## Distancia minima mantida entre integrantes (m) e zonas de chegada/retomada do lugar (histerese: sem tremer).
const MIN_GAP := 0.9
const SLOT_ARRIVE := 0.12
const SLOT_RESUME := 0.45
## Seguidor longe do lider corre mesmo que o lider ande (para alcancar).
const CATCHUP_DIST := 4.0
const CAPSULE_RADIUS := 0.35
const SLOT_CLEARANCE := 0.55
const TURN_SPEED := 14.0

const MODEL_SCENES := {
	&"tracker": "res://actors/characters/rastro_model.tscn",
	&"pilot": "res://actors/characters/leme_model.tscn",
	&"climber": "res://actors/characters/pico_model.tscn",
}
## Cadencia (C2): escala do clipe = velocidade real / avanco do pe de apoio por segundo no clipe (`walk_speed_mps` e
## `run_speed_mps` de cada modelo). Proporcional, sem teto que faria patinar; so um limite de seguranca.
const ANIM_SCALE_MAX := 4.0
const WALK_SPEED_FALLBACK := 0.586

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
## Fora de controle: direcao no mundo (0..1) para acompanhar o heroi em controle (Ep01 v3); ignorada quando controlado.
var auto_dir: Vector3 = Vector3.ZERO
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
## C2: ritmo de corrida (jogador segurando `run`, ou seguidor acompanhando um lider que corre).
var running: bool = false
## Pulo livre do jogador em curso (fisica), distinto do salto programado `jump_to`.
var jumping: bool = false
var jumps: int = 0
## Devolve true quando o pulo deve ficar bloqueado. Vazio: usa `blocked()` do primeiro ancestral que o tiver (episodio).
var jump_gate: Callable
## Seguidor: lider de quem acompanha ritmo e formacao (null: o irmao MemberActor em controle).
var leader: MemberActor = null
var _settled: bool = true
var _following: bool = false


func setup(member_id: StringName) -> void:
	member = member_id
	name = "Actor_" + String(member_id)
	collision_layer = 2
	collision_mask = 1
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = CAPSULE_RADIUS
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
	elif jumping and not is_on_floor():
		return
	elif planar > 0.2 and model.has_animation(&"walk"):
		var g := gait(planar)
		var anim: StringName = g["anim"]
		var anim_scale: float = g["scale"]
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


## Clipe e escala de tempo para o ritmo `planar` (m/s): o pe de apoio anda para tras na velocidade do corpo.
func gait(planar: float) -> Dictionary:
	var anim := &"walk"
	var nominal := WALK_SPEED_FALLBACK
	if model != null:
		nominal = model.walk_speed_mps
		if planar > RUN_THRESHOLD and model.has_animation(&"run") and model.run_speed_mps > 0.0:
			anim = &"run"
			nominal = model.run_speed_mps
	return {"anim": anim, "scale": clampf(planar / maxf(nominal, 0.01), 0.0, ANIM_SCALE_MAX)}


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
	var world := Vector3.ZERO
	if controlled:
		dir = Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
		running = Input.is_action_pressed(&"run")
		world = Basis(Vector3.UP, move_yaw) * Vector3(dir.x, 0.0, dir.y)
	else:
		world = _follow_dir()
		dir = Vector2(world.x, world.z)
	var want := Vector3.ZERO
	if world.length() > 0.01:
		want = world.normalized() * target_speed(dir.length(), running) * speed_scale
	var planar_v := step_planar(Vector3(velocity.x, 0.0, velocity.z), want, delta)
	velocity.x = planar_v.x
	velocity.z = planar_v.z
	if controlled and Input.is_action_just_pressed(&"jump") and can_jump():
		velocity.y = JUMP_VELOCITY
		jumping = true
		jumps += 1
		if model != null and model.has_animation(&"jump"):
			play_action(&"jump", model.animation_length(&"jump") / jump_duration())
	elif is_on_floor():
		velocity.y = -0.5
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()
	if jumping and is_on_floor() and velocity.y <= 0.0:
		jumping = false
		_action_until = 0.0
		footstep.emit(Vector2(velocity.x, velocity.z).length(), global_position)
	_update_animation()
	if world.length() > 0.1:
		_face_target = null
		_visual.rotation.y = lerp_angle(_visual.rotation.y, atan2(-world.x, -world.z), clampf(TURN_SPEED * delta, 0.0, 1.0))
	elif _face_target != null:
		var d: Vector3 = (_face_target as Vector3) - global_position
		d.y = 0.0
		if d.length() > 0.01:
			_visual.rotation.y = lerp_angle(_visual.rotation.y, atan2(-d.x, -d.z), clampf(TURN_SPEED * delta, 0.0, 1.0))
	elif not controlled and _following and _settled and lead() != null:
		_visual.rotation.y = lerp_angle(_visual.rotation.y, lead()._visual.rotation.y, clampf(TURN_SPEED * 0.4 * delta, 0.0, 1.0))


## Duracao do pulo livre no chao plano (s): sobe e desce com a mesma gravidade.
static func jump_duration() -> float:
	return 2.0 * JUMP_VELOCITY / GRAVITY


## Pulo do jogador permitido agora: no chao, a pe, fora de salto programado e com o episodio livre (`busy`, cartoes, pausa).
func can_jump() -> bool:
	if not controlled or airborne or jumping or not is_on_floor():
		return false
	if riding_on != null and is_instance_valid(riding_on):
		return false
	if _jump_tween and _jump_tween.is_valid() and _jump_tween.is_running():
		return false
	if jump_gate.is_valid():
		return not bool(jump_gate.call())
	var n := get_parent()
	while n != null:
		if n.has_method(&"blocked"):
			return not bool(n.call(&"blocked"))
		n = n.get_parent()
	return true


## Lider atual: `leader` se definido, senao o irmao MemberActor em controle.
func lead() -> MemberActor:
	if leader != null and is_instance_valid(leader):
		return leader if leader != self else null
	var p := get_parent()
	if p == null:
		return null
	for c in p.get_children():
		if c is MemberActor and c != self and (c as MemberActor).controlled:
			return c as MemberActor
	return null


## Lugar fixo de cada seguidor do mesmo lider (ordem pelo id), para os dois nao disputarem o mesmo ponto.
func _formation_index(l: MemberActor) -> int:
	var ids: Array[String] = []
	for c in get_parent().get_children():
		if c is MemberActor and c != l and (c as MemberActor).riding_on == null:
			ids.append(String((c as MemberActor).member))
	ids.sort()
	return maxi(ids.find(String(member)), 0)


## Lugar deste seguidor na formacao (mundo, na altura do proprio seguidor).
func formation_slot() -> Vector3:
	var l := lead()
	if l == null:
		return global_position
	var i := _formation_index(l)
	var basis := Basis(Vector3.UP, l._visual.rotation.y)
	# Lugar proprio; se a parede/agua o impede, o do outro lado; senao fica onde esta (nunca entra num canto sem saida).
	for k in [i, i + 1]:
		var p := l.global_position + basis * FORMATION_SLOTS[k % FORMATION_SLOTS.size()]
		if _slot_clear(l.global_position, p):
			p.y = global_position.y
			return p
	return global_position


## Lugar livre: linha reta do lider ate ele sem parede (largura da capsula) e chao firme na mesma altura.
func _slot_clear(from: Vector3, to: Vector3) -> bool:
	if not is_inside_tree():
		return false
	var space := get_world_3d().direct_space_state
	var side := (to - from).cross(Vector3.UP).normalized() * CAPSULE_RADIUS
	for off: Vector3 in [Vector3.ZERO, side, -side]:
		for h: float in [0.3, 0.9]:
			var q := PhysicsRayQueryParameters3D.create(from + off + Vector3(0, h, 0), to + off + Vector3(0, h, 0), 1)
			if not space.intersect_ray(q).is_empty():
				return false
	# Folga em volta do lugar (nada encostado), para o heroi nao ficar colado num obstaculo quando virar o lider.
	var probe := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = SLOT_CLEARANCE
	probe.shape = sphere
	probe.collision_mask = 1
	for h: float in [0.8, 1.2]:
		probe.transform = Transform3D(Basis(), to + Vector3(0, h, 0))
		if not space.intersect_shape(probe, 1).is_empty():
			return false
	var down := PhysicsRayQueryParameters3D.create(to + Vector3(0, 0.6, 0), to + Vector3(0, -0.4, 0), 1)
	var hit := space.intersect_ray(down)
	return not hit.is_empty() and absf((hit["position"] as Vector3).y - from.y) < 0.3


## Seguidor: o episodio pede para seguir com `auto_dir`; o ator acompanha o ritmo do lider, depois vai ao seu lugar da
## formacao e para ali (histerese), mantendo MIN_GAP dos outros. Nunca empurra o lider: so o seguidor se desvia.
func _follow_dir() -> Vector3:
	var l := lead()
	var asked := auto_dir.length() > 0.01
	if l == null:
		running = false
		return Vector3(auto_dir.x, 0.0, auto_dir.z) if asked else Vector3.ZERO
	var to_lead := l.global_position - global_position
	to_lead.y = 0.0
	running = l.running or to_lead.length() > CATCHUP_DIST
	var out := Vector3.ZERO
	if asked:
		_following = true
		_settled = false
		out = Vector3(auto_dir.x, 0.0, auto_dir.z).normalized()
	elif _following:
		var to_slot := formation_slot() - global_position
		to_slot.y = 0.0
		if _settled and to_slot.length() > SLOT_RESUME:
			_settled = false
		if not _settled:
			if to_slot.length() <= SLOT_ARRIVE:
				_settled = true
			else:
				# Freia perto do lugar (inclinacao cai com a distancia) para nao passar do ponto nem tremer.
				out = to_slot.normalized() * clampf(to_slot.length() / 0.6, 0.3, 1.0)
	# So quem esta no modo seguidor (Ep01 v3) se afasta; posicoes encenadas pelas fases antigas ficam como estao.
	var sep := _separation() if _following else Vector3.ZERO
	if sep.length() > 0.01:
		out += sep
		if out.length() < DEADZONE + 0.05:
			out = sep.normalized() * (DEADZONE + 0.05)
	if out.length() > 1.0:
		out = out.normalized()
	return out


## Afasta este seguidor de quem estiver a menos de MIN_GAP (o lider tambem conta, mas so o seguidor se move).
func _separation() -> Vector3:
	var push := Vector3.ZERO
	var p := get_parent()
	if p == null or (riding_on != null):
		return push
	for c in p.get_children():
		if c == self or not (c is MemberActor):
			continue
		var o := c as MemberActor
		if o.riding_on != null or absf(o.global_position.y - global_position.y) > 1.0:
			continue
		var d := global_position - o.global_position
		d.y = 0.0
		var dist := d.length()
		if dist >= MIN_GAP:
			continue
		if dist < 0.01:
			d = Vector3.RIGHT.rotated(Vector3.UP, float(absi(String(member).hash()) % 628) / 100.0)
			dist = 0.01
		push += d.normalized() * clampf((MIN_GAP - dist) / MIN_GAP * 2.0, 0.35, 1.0)
	return push


## Velocidade alvo para uma inclinacao do analogico (0..1): anda (ate WALK_SPEED) por padrao; com `run`, ate RUN_SPEED.
static func target_speed(tilt: float, run: bool = false) -> float:
	tilt = clampf(tilt, 0.0, 1.0)
	if tilt < DEADZONE:
		return 0.0
	return (RUN_SPEED if run else WALK_SPEED) * tilt


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
	jumping = false
	_following = false
	_settled = true


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

