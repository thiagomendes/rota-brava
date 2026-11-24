class_name RiverStage
extends StageBase
## Etapa 2 - Subir o rio (`river_search`): Leme pilota o barco contra a correnteza, contorna a boia e chega a enseada.
## Cenografia em blocos PROVISORIOS. Correnteza por zonas: ver RiverZones. Boia: RiverBuoyTracker.

const HINT_COOLDOWN := 20.0
const BUOY_TRACK_RADIUS := 9.0
const LEAF_COUNT := 20
const LEAF_GAIN := 1.6                    # ganho visual: a folha anda mais que a agua para ler a direcao
const COVE_LOOK_SECONDS := 2.0
const LOOK_BACK_SECONDS := 1.8
const KEY_HINT_BUOY := "ep01.river.pilot.hint_gesture_buoy"

const RIDE_PILOT := BoatActor.CREW[&"pilot"]
const RIDE_TRACKER := BoatActor.CREW[&"tracker"]
const RIDE_CLIMBER := BoatActor.CREW[&"climber"]

var tracker := RiverBuoyTracker.new(Ep01Layout.BUOY_POS, BUOY_TRACK_RADIUS)
var buoy_node: Node3D
var captain_figure: Node3D
var pup_figure: Node3D
var leaves: Array[MeshInstance3D] = []

var _scenery: Node3D
var _halo: MeshInstance3D
var _arm_pivot: Node3D
var _rng := RandomNumberGenerator.new()
var _clock: float = 0.0
var _active: bool = false
var _cove_busy: bool = false
var _last_cove_hint: float = -100.0
var _last_slow: float = -100.0
var _last_bank: float = -100.0
var _buoy_pulse: float = 0.0
var _leaf_pulse: float = 0.0
var _look_back_at: float = -1.0
var _buoy_spoken: bool = false


func setup(main: Ep01Main) -> void:
	super.setup(main)
	_rng.seed = 20260502
	_scenery = Node3D.new()
	_scenery.name = "RiverScenery"
	_scenery.set_meta(Blocks.PROVISIONAL, true)
	add_child(_scenery)
	_build_banks()
	_build_buoy()
	_build_cove()
	_build_leaves()
	_build_captain_signal()


# ---------- cenografia ----------

func _build_banks() -> void:
	var green := Color("5f9e4a")
	var earth := Color("8a6a43")
	var z_n := -(Ep01Layout.RIVER_Z_HALF + 2.0)
	var z_s := Ep01Layout.RIVER_Z_HALF + 2.0
	# Margem norte (x 10..95) e sul (x 10..76; a baia ocupa o resto).
	Blocks.box(_scenery, "BankNorth", Vector3(85, 1.0, 4), Vector3(52.5, -0.1, z_n), green)
	Blocks.box(_scenery, "BankNorthEdge", Vector3(85, 0.6, 0.6), Vector3(52.5, -0.2, z_n + 2.3), earth)
	Blocks.box(_scenery, "BankSouth", Vector3(66, 1.0, 4), Vector3(43, -0.1, z_s), green)
	Blocks.box(_scenery, "BankSouthEdge", Vector3(66, 0.6, 0.6), Vector3(43, -0.2, z_s - 2.3), earth)
	for i in 34:
		var x := 12.0 + float(i) * 2.4 + _rng.randf_range(-0.6, 0.6)
		var depth := _rng.randf_range(0.5, 4.5)
		if _rng.randf() < 0.65:
			_tree("TreeN%d" % i, Vector3(x, 0.4, z_n - 1.0 - depth))
		else:
			_rock("RockN%d" % i, Vector3(x, 0.4, z_n + 1.0 - depth * 0.3))
		if x < 74.0:
			if _rng.randf() < 0.65:
				_tree("TreeS%d" % i, Vector3(x, 0.4, z_s + 1.0 + depth))
			else:
				_rock("RockS%d" % i, Vector3(x, 0.4, z_s - 1.0 + depth * 0.3))


func _tree(node_name: String, pos: Vector3) -> void:
	var h := _rng.randf_range(1.8, 3.0)
	Blocks.cylinder(_scenery, node_name + "Trunk", 0.3, h, pos + Vector3(0, h * 0.5, 0), Color("6b4a2b"))
	Blocks.sphere(_scenery, node_name + "Crown", _rng.randf_range(1.2, 1.8), pos + Vector3(0, h + 0.8, 0), Color("3f8a3c"))


func _rock(node_name: String, pos: Vector3) -> void:
	var r := Blocks.sphere(_scenery, node_name, _rng.randf_range(0.5, 1.0), pos + Vector3(0, 0.1, 0), Color("8d8f93"))
	r.scale = Vector3(1.2, 0.65, 1.0)


func _build_buoy() -> void:
	buoy_node = Node3D.new()
	buoy_node.name = "Buoy"
	buoy_node.set_meta(Blocks.PROVISIONAL, true)
	add_child(buoy_node)
	buoy_node.position = Ep01Layout.BUOY_POS + Vector3(0, Ep01Layout.WATER_Y, 0)
	Blocks.cylinder(buoy_node, "BuoyBodyRed", 0.7, 0.9, Vector3(0, 0.35, 0), Color("e0262b"), 0.25)
	Blocks.cylinder(buoy_node, "BuoyBandWhite", 0.72, 0.28, Vector3(0, 0.45, 0), Color("fafafa"))
	Blocks.cylinder(buoy_node, "BuoyMast", 0.08, 1.4, Vector3(0, 1.4, 0), Color("fafafa"))
	Blocks.sphere(buoy_node, "BuoyTopRed", 0.32, Vector3(0, 2.2, 0), Color("e0262b"), 0.4)
	_halo = Blocks.cylinder(buoy_node, "BuoyHalo", 2.4, 0.04, Vector3(0, 0.15, 0), Color("ffe14d"), 1.2)
	_halo.visible = false


func _build_cove() -> void:
	var sand := Color("e3cf9a")
	Blocks.box(_scenery, "CoveSandSouth", Vector3(16, 0.8, 3), Vector3(84, -0.45, 19.5), sand)
	Blocks.box(_scenery, "CoveSandEast", Vector3(3, 0.8, 19), Vector3(90.5, -0.45, 11.5), sand)
	Blocks.box(_scenery, "RiverEndBank", Vector3(4, 0.8, 17), Vector3(90, -0.45, -5.5), sand)
	Blocks.box(_scenery, "CoveBankWest", Vector3(2, 0.8, 4), Vector3(75, -0.45, 16), sand)
	_rock("CoveRock1", Vector3(80.0, 0.4, 20.5))
	_rock("CoveRock2", Vector3(87.0, 0.4, 20.0))


func _build_leaves() -> void:
	for i in LEAF_COUNT:
		var leaf := Blocks.cylinder(_scenery, "Leaf%d" % i, 0.5, 0.04, _random_leaf_pos(true), Color("7fbf4a"))
		leaf.rotation.y = _rng.randf() * TAU
		leaves.append(leaf)


func _random_leaf_pos(anywhere: bool) -> Vector3:
	var x := Ep01Layout.RIVER_X_MAX - _rng.randf_range(0.0, 4.0)
	if anywhere:
		x = _rng.randf_range(Ep01Layout.RIVER_X_MIN + 2.0, Ep01Layout.RIVER_X_MAX)
	var z := _rng.randf_range(-Ep01Layout.RIVER_Z_HALF + 1.0, Ep01Layout.RIVER_Z_HALF - 1.0)
	return Vector3(x, Ep01Layout.WATER_Y + 0.04, z)


## Sinalizacao do reencontro: dois bonequinhos em blocos na ilha (piloto acenando e filhote). Escondidos ate a enseada.
func _build_captain_signal() -> void:
	captain_figure = Node3D.new()
	captain_figure.name = "CaptainSignal"
	captain_figure.set_meta(Blocks.PROVISIONAL, true)
	add_child(captain_figure)
	captain_figure.position = Ep01Layout.PILOT_CAPTAIN_POS
	Blocks.box(captain_figure, "CaptainBody", Vector3(0.7, 1.1, 0.5), Vector3(0, 0.55, 0), Color("2d5fa8"))
	Blocks.sphere(captain_figure, "CaptainHead", 0.3, Vector3(0, 1.4, 0), Color("e8b98a"))
	Blocks.cylinder(captain_figure, "CaptainHat", 0.34, 0.16, Vector3(0, 1.72, 0), Color("fafafa"))
	_arm_pivot = Node3D.new()
	_arm_pivot.name = "CaptainArmPivot"
	_arm_pivot.position = Vector3(0.45, 1.0, 0)
	captain_figure.add_child(_arm_pivot)
	Blocks.box(_arm_pivot, "CaptainArm", Vector3(0.2, 0.8, 0.2), Vector3(0, 0.4, 0), Color("2d5fa8"))
	pup_figure = Node3D.new()
	pup_figure.name = "PupSignal"
	pup_figure.set_meta(Blocks.PROVISIONAL, true)
	add_child(pup_figure)
	pup_figure.position = Ep01Layout.PILOT_CAPTAIN_POS + Vector3(-1.4, 0, 0.8)
	Blocks.box(pup_figure, "PupBody", Vector3(0.6, 0.45, 0.9), Vector3(0, 0.4, 0), Color("c98f4e"))
	Blocks.sphere(pup_figure, "PupHead", 0.28, Vector3(0, 0.75, -0.55), Color("c98f4e"))
	Blocks.box(pup_figure, "PupEarLeft", Vector3(0.12, 0.2, 0.1), Vector3(-0.17, 1.0, -0.55), Color("7a4e26"))
	Blocks.box(pup_figure, "PupEarRight", Vector3(0.12, 0.2, 0.1), Vector3(0.17, 1.0, -0.55), Color("7a4e26"))
	Blocks.box(pup_figure, "PupTail", Vector3(0.1, 0.1, 0.4), Vector3(0, 0.6, 0.6), Color("7a4e26"))
	captain_figure.visible = false
	pup_figure.visible = false


func _show_signal(on: bool) -> void:
	captain_figure.visible = on
	pup_figure.visible = on


# ---------- contrato do estagio ----------

func controlled_node(member: StringName) -> Node3D:
	if member == &"pilot":
		return ctx.boat
	return ctx.actors.get(member)


func focus_node(member: StringName) -> Node3D:
	return controlled_node(member)


func camera_view() -> Dictionary:
	return {"offset": Vector3(-3.0, 13.0, 14.0), "yaw": 0.0}


func refresh_world() -> void:
	var state := ctx.director.state
	var past := not (state in [&"arrival", &"dock_investigation", &"river_search"])
	if state == &"island_crossing":
		ctx.boat.place(Ep01Layout.ENSEADA_POS, 0.0)
		_board_all()
	_show_signal(past or _cove_busy)
	if past or ctx.director.buoy_rounded:
		tracker.done = true


func _board_all() -> void:
	var pilot: MemberActor = ctx.actors[&"pilot"]
	var tracker_a: MemberActor = ctx.actors[&"tracker"]
	var climber: MemberActor = ctx.actors[&"climber"]
	if pilot.riding_on == null:
		pilot.ride(ctx.boat, RIDE_PILOT)
	if tracker_a.riding_on == null:
		tracker_a.ride(ctx.boat, RIDE_TRACKER)
	if climber.riding_on == null:
		climber.ride(ctx.boat, RIDE_CLIMBER)


func enter() -> void:
	_active = true
	_cove_busy = false
	_buoy_spoken = false
	tracker.reset()
	tracker.done = ctx.director.buoy_rounded
	_clock = 0.0
	_last_cove_hint = -100.0
	_last_slow = -100.0
	_last_bank = -100.0
	var d := ctx.boat.global_position.distance_to(Ep01Layout.BOAT_DOCKED_POS)
	if d < 1.0 or d > 40.0 or RiverZones.clearance(ctx.boat.global_position) <= 0.6:
		ctx.boat.place(Ep01Layout.BOAT_DOCKED_POS, -PI / 2.0)   # proa para leste (rio acima)
	ctx.boat.input_locked = false
	ctx.boat.current_func = Callable(RiverZones, "current_at")
	ctx.boat.clearance_func = Callable(RiverZones, "clearance")
	(ctx.actors[&"pilot"] as MemberActor).ride(ctx.boat, RIDE_PILOT)
	(ctx.actors[&"tracker"] as MemberActor).ride(ctx.boat, RIDE_TRACKER)
	(ctx.actors[&"climber"] as MemberActor).ride(ctx.boat, RIDE_CLIMBER)
	for m: StringName in [&"pilot", &"tracker", &"climber"]:
		(ctx.actors[m] as MemberActor).face_now(ctx.boat.global_position + ctx.boat.forward() * 10.0)
	_show_signal(false)
	ctx.camera_rig.set_view(camera_view()["offset"], 0.0)
	ctx.camera_rig.follow(ctx.boat)


func exit() -> void:
	_active = false
	_cove_busy = false
	ctx.boat.input_locked = false
	ctx.boat.current_func = Callable()
	ctx.boat.clearance_func = Callable()


func control_started(member: StringName) -> void:
	if member != &"pilot":
		return
	var lines := Ep01Content.lines(&"river_search", "enter")
	if not lines.is_empty():
		ctx.hud.say(lines[0])


func gesture_hint(key: String) -> void:
	var pilot := ctx.actors[&"pilot"] as MemberActor
	if key.ends_with("leaves") or tracker.done:
		_leaf_pulse = 2.5
		pilot.face_point(ctx.boat.global_position + Ep01Layout.RIVER_CURRENT.normalized() * 10.0)
		return
	_buoy_pulse = 3.0
	pilot.face_point(buoy_node.global_position)
	ctx.camera_rig.follow(buoy_node)
	_look_back_at = _clock + LOOK_BACK_SECONDS


# ---------- simulacao e eventos ----------

func process_stage(delta: float) -> void:
	_clock += delta
	_animate(delta)
	step_leaves(delta)
	if not _active:
		return
	_look_back()
	feed_buoy(ctx.boat.global_position)
	_check_cove()
	_guidance()


func _animate(delta: float) -> void:
	buoy_node.position.y = Ep01Layout.WATER_Y + 0.08 * sin(_clock * 2.2)
	buoy_node.rotation.z = 0.05 * sin(_clock * 1.7)
	if _buoy_pulse > 0.0:
		_buoy_pulse -= delta
		buoy_node.scale = Vector3.ONE * (1.0 + 0.3 * absf(sin(_clock * 6.0)))
		_halo.visible = true
	else:
		buoy_node.scale = Vector3.ONE
		_halo.visible = false
	if _leaf_pulse > 0.0:
		_leaf_pulse -= delta
	var s := 1.0
	if _leaf_pulse > 0.0:
		s += 0.8 * absf(sin(_clock * 5.0))
	for leaf in leaves:
		leaf.scale = Vector3(s, 1.0, s)
	if captain_figure.visible:
		_arm_pivot.rotation.z = 2.4 + 0.5 * sin(_clock * 9.0)


func _look_back() -> void:
	if _look_back_at > 0.0 and _clock >= _look_back_at and not _cove_busy:
		_look_back_at = -1.0
		ctx.camera_rig.follow(ctx.boat)


## Derivam com a direcao e a velocidade da correnteza local; reaparecem a montante ao sair da area.
func step_leaves(delta: float) -> void:
	for leaf in leaves:
		var p := leaf.global_position
		p += RiverZones.zone_current(p) * LEAF_GAIN * delta
		if p.x < Ep01Layout.RIVER_X_MIN - 2.0 or p.x > Ep01Layout.RIVER_X_MAX + 1.0:
			p = _random_leaf_pos(false)
		leaf.global_position = p


func leaf_positions() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for leaf in leaves:
		out.append(leaf.global_position)
	return out


## Alimenta a deteccao da boia; na amostra que completa a volta envia `buoy_rounded` (uma vez). Devolve true nessa amostra.
func feed_buoy(pos: Vector3) -> bool:
	if not tracker.feed(pos):
		return false
	var res := ctx.submit(&"buoy_rounded", &"pilot")
	if bool(res.get("accepted", false)):
		var lines := Ep01Content.lines(&"river_search", "buoy_rounded")
		if not lines.is_empty() and not _buoy_spoken:
			_buoy_spoken = true
			ctx.hud.say(lines[0])
		_buoy_pulse = 2.0
	return true


func at_cove(pos: Vector3) -> bool:
	return Vector2(pos.x - Ep01Layout.ENSEADA_POS.x, pos.z - Ep01Layout.ENSEADA_POS.z).length() <= Ep01Layout.ENSEADA_RADIUS


func _check_cove() -> void:
	if _cove_busy or not at_cove(ctx.boat.global_position):
		return
	if ctx.director.buoy_rounded:
		_cove_busy = true
		_cove_sequence()
	elif _clock - _last_cove_hint >= HINT_COOLDOWN:
		try_cove()


## Envia `cove_reached` agora. Rejeitado (sem boia): dica curta (no maximo 1x/20 s), sem travar. Devolve o resultado do diretor.
func try_cove() -> Dictionary:
	var res := ctx.submit(&"cove_reached", &"pilot")
	if bool(res.get("accepted", false)):
		_show_signal(true)
	elif _clock - _last_cove_hint >= HINT_COOLDOWN:
		_last_cove_hint = _clock
		ctx.hud.say(KEY_HINT_BUOY, {}, true)
	return res


## Reencontro: mostra piloto e filhote por ~2 s antes de enviar o evento (o diretor nao fica bloqueado).
func _cove_sequence() -> void:
	_show_signal(true)
	ctx.boat.input_locked = true
	ctx.camera_rig.set_view(Vector3(-7.0, 5.0, 9.0), 0.0)
	ctx.camera_rig.follow(captain_figure)
	for k in Ep01Content.lines(&"river_search", "cove_reached"):
		ctx.hud.say(k)
	await ctx.get_tree().create_timer(COVE_LOOK_SECONDS).timeout
	if not _active:
		return
	var res := ctx.submit(&"cove_reached", &"pilot")
	if not bool(res.get("accepted", false)):
		_cove_busy = false
		ctx.boat.input_locked = false
		ctx.camera_rig.set_view(camera_view()["offset"], 0.0)
		ctx.camera_rig.follow(ctx.boat)


func _guidance() -> void:
	var boat := ctx.boat
	if boat.input_locked or not boat.controlled:
		return
	var c := RiverZones.clearance(boat.global_position)
	if c < 1.5 and _clock - _last_bank >= HINT_COOLDOWN:
		_last_bank = _clock
		_say_first("bank_guide")
	elif boat.throttle > 0.1 and boat.last_slow_factor < 0.5 and _clock - _last_slow >= HINT_COOLDOWN:
		_last_slow = _clock
		_say_first("slow_down")


func _say_first(line: String) -> void:
	var lines := Ep01Content.lines(&"river_search", line)
	if not lines.is_empty():
		ctx.hud.say(lines[0], {}, true)


# ---------- API de teste (sem fisica de entrada) ----------

## Avanca o barco `steps` passos fixos com `throttle`/`steer` dados; devolve a posicao final.
## Heading 0 = norte; leste = -PI/2. Alimenta tambem a deteccao da boia.
func simulate_boat(steps: int, throttle: float, steer: float, delta: float = 1.0 / 60.0) -> Vector3:
	var boat := ctx.boat
	boat.controlled = false
	for i in steps:
		boat.throttle = throttle
		boat.steer = steer
		boat.step(delta)
		_clock += delta
		feed_buoy(boat.global_position)
	return boat.global_position


func boat_position_changed(from: Vector3, min_distance: float = 0.05) -> bool:
	return ctx.boat.global_position.distance_to(from) >= min_distance
