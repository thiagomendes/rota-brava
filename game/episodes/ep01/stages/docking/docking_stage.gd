class_name DockingStage
extends StageBase
## Etapas 4 e 5 - Atracar (`docking`) e Voltar (`return_trip`), com Leme. A MESMA instancia atende os dois estados.
## Todo o cenario e PROVISORIO (Blocks). A corda entre ANCHOR_A/B pertence ao estagio `island`.

const ASSIST_RANGE := 10.0
const ASSIST_MAX := 0.9
const ASSIST_SPEECH_COOLDOWN_MS := 20000
const OVERSHOOT_Z := -9.0
const STUCK_HITS := 5
const STUCK_WINDOW := 3.0
## Corrente fraca do braco (m/s); some conforme a assistencia cresce. Ajustavel.
const ARM_CURRENT := Vector3(-0.3, 0.0, -0.2)
## Limites do braco (clearance): margem oeste, ilha/pier a leste, norte, entrada sul.
const BOUND_WEST := 92.0 + Ep01Layout.STAGE3_SHIFT
const BOUND_EAST := 100.0 + Ep01Layout.STAGE3_SHIFT
const BOUND_NORTH := -9.0
const BOUND_SOUTH := 16.0

const RIDE_PILOT := BoatActor.CREW[&"pilot"]
const RIDE_TRACKER := BoatActor.CREW[&"tracker"]
const CAPTAIN_ON_BOAT := Vector3(-0.5, 0.6, -1.0)
const PUP_ON_BOAT := Vector3(0.4, 0.6, -1.7)

const COLOR_OFF := Color("7fd6c2")
const COLOR_ON := Color("fff27a")

var board_it: Ep01Interactable
var depart_it: Ep01Interactable
var beacons: Node3D
var target_zone: Node3D
var passengers: Node3D
var pier: Node3D

var _target_mats: Array[StandardMaterial3D] = []
var _light: OmniLight3D
var _lit: bool = false
var _pulse: float = 0.0
var _last_assist_say_ms: int = -1000000
var _assist_said: bool = false
var _hits: Array[float] = []
var _clock: float = 0.0
var _departing: bool = false
var _tween: Tween
var _retry_count: int = 0


# ---------- cenografia ----------

func setup(main: Ep01Main) -> void:
	super.setup(main)
	_build_pier()
	_build_target()
	_build_beacons()
	_build_passengers()
	board_it = _make_interactable(&"board", "ui.action.board", &"boat")
	depart_it = _make_interactable(&"depart", "ui.action.depart", &"helm")
	board_it.triggered.connect(func(_a: Node3D) -> void: board())
	depart_it.triggered.connect(func(_a: Node3D) -> void: depart_now())
	ctx.boat.soft_hit.connect(_on_soft_hit)


func _make_interactable(id: StringName, label: String, icon_id: StringName) -> Ep01Interactable:
	var it := Ep01Interactable.new()
	it.name = "Interact_" + String(id)
	it.action_id = id
	it.label_key = label
	it.icon = icon_id
	it.member = &"pilot"
	it.radius = 3.0
	it.enabled = false
	add_child(it)
	it.global_position = Ep01Layout.DOCKING_TARGET_POS
	return it


func _build_pier() -> void:
	pier = Node3D.new()
	pier.name = "Pier"
	pier.set_meta(Blocks.PROVISIONAL, true)
	add_child(pier)
	pier.position = Ep01Layout.PIER_POS
	# Com a cena de mundo da ilha, o atracadouro vem dela; o bloco provisorio fica escondido.
	pier.visible = not ResourceLoader.exists(IslandStage.WORLD_SCENE)
	Blocks.box(pier, "PierDeck", Vector3(3.4, 0.3, 8.0), Vector3(0, 0.0, 0), Color("a77a4b"))
	for i in 4:
		Blocks.box(pier, "PierPlank%d" % i, Vector3(3.4, 0.04, 0.12), Vector3(0, 0.17, -3.0 + 2.0 * i), Color("7e5a35"))
	for sz in [-3.6, 3.6]:
		for sx in [-1.5, 1.5]:
			Blocks.cylinder(pier, "Bollard", 0.18, 0.6, Vector3(sx, 0.45, sz), Color("4a3a2a"))
	# Defensa (para-choque) no lado do barco (oeste).
	for sz in [-2.0, 0.0, 2.0]:
		Blocks.box(pier, "Fender", Vector3(0.25, 0.4, 0.8), Vector3(-1.7, 0.0, sz), Color("2b2b2b"))
	for sz in [-3.6, 3.6]:
		Blocks.cylinder(pier, "Post", 0.2, 1.8, Vector3(1.5, -0.4, sz), Color("5a3a22"))


func _glow_mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 0.4
	m.roughness = 0.6
	return m


func _glow_box(parent: Node3D, name: String, size: Vector3, pos: Vector3) -> MeshInstance3D:
	var mi := Blocks.box(parent, name, size, pos, COLOR_OFF)
	var m := _glow_mat(COLOR_OFF)
	mi.material_override = m
	_target_mats.append(m)
	return mi


func _build_target() -> void:
	target_zone = Node3D.new()
	target_zone.name = "DockingTarget"
	target_zone.set_meta(Blocks.PROVISIONAL, true)
	add_child(target_zone)
	target_zone.position = Ep01Layout.DOCKING_TARGET_POS + Vector3(0, Ep01Layout.WATER_Y + 0.06, 0)
	var hw := 1.9
	var hl := 3.2
	_glow_box(target_zone, "RingW", Vector3(0.18, 0.04, hl * 2.0), Vector3(-hw, 0, 0))
	_glow_box(target_zone, "RingE", Vector3(0.18, 0.04, hl * 2.0), Vector3(hw, 0, 0))
	_glow_box(target_zone, "RingN", Vector3(hw * 2.0, 0.04, 0.18), Vector3(0, 0, -hl))
	_glow_box(target_zone, "RingS", Vector3(hw * 2.0, 0.04, 0.18), Vector3(0, 0, hl))
	# Seta para o rumo alvo (proa ao norte: -Z), fora do casco, a frente da zona.
	var arrow := Node3D.new()
	arrow.name = "Arrow"
	target_zone.add_child(arrow)
	arrow.position = Vector3(0, 0, -hl - 1.4)
	arrow.rotation.y = Ep01Layout.DOCKING_TARGET_HEADING
	_glow_box(arrow, "Shaft", Vector3(0.3, 0.04, 1.4), Vector3(0, 0, 0.3))
	var l := _glow_box(arrow, "HeadL", Vector3(0.3, 0.04, 0.9), Vector3(-0.3, 0, -0.5))
	l.rotation.y = deg_to_rad(-40.0)
	var rr := _glow_box(arrow, "HeadR", Vector3(0.3, 0.04, 0.9), Vector3(0.3, 0, -0.5))
	rr.rotation.y = deg_to_rad(40.0)
	_light = OmniLight3D.new()
	_light.name = "TargetLight"
	_light.position = Vector3(0, 1.5, 0)
	_light.light_color = COLOR_ON
	_light.omni_range = 7.0
	_light.light_energy = 0.3
	target_zone.add_child(_light)
	target_zone.visible = false


func _build_beacons() -> void:
	beacons = Node3D.new()
	beacons.name = "ApproachBeacons"
	beacons.set_meta(Blocks.PROVISIONAL, true)
	add_child(beacons)
	for z in [11.0, 7.0, 3.0]:
		Blocks.cylinder(beacons, "BeaconL", 0.22, 1.2, Vector3(BOUND_WEST + 2.0, Ep01Layout.WATER_Y + 0.5, z), Color("e04a3a"), 0.3)
		Blocks.sphere(beacons, "BeaconLTop", 0.28, Vector3(BOUND_WEST + 2.0, Ep01Layout.WATER_Y + 1.2, z), Color("ff7a6a"), 0.8)
		Blocks.cylinder(beacons, "BeaconR", 0.22, 1.2, Vector3(BOUND_EAST - 1.0, Ep01Layout.WATER_Y + 0.5, z), Color("3aa86a"), 0.3)
		Blocks.sphere(beacons, "BeaconRTop", 0.28, Vector3(BOUND_EAST - 1.0, Ep01Layout.WATER_Y + 1.2, z), Color("7af0a0"), 0.8)
	beacons.visible = false


func _build_passengers() -> void:
	passengers = Node3D.new()
	passengers.name = "Passengers"
	add_child(passengers)
	var captain := Node3D.new()
	captain.name = "PierCaptain"
	captain.set_meta(Blocks.PROVISIONAL, true)
	passengers.add_child(captain)
	Blocks.cylinder(captain, "Body", 0.32, 1.0, Vector3(0, 0.6, 0), Color("8a8f98"))
	Blocks.sphere(captain, "Head", 0.26, Vector3(0, 1.4, 0), Color("f1d2b0"))
	Blocks.box(captain, "Cap", Vector3(0.6, 0.18, 0.6), Vector3(0, 1.7, 0), Color("22344f"))
	var pup := Node3D.new()
	pup.name = "PierPup"
	pup.set_meta(Blocks.PROVISIONAL, true)
	passengers.add_child(pup)
	Blocks.box(pup, "Body", Vector3(0.35, 0.3, 0.6), Vector3(0, 0.25, 0), Color("c98f4f"))
	Blocks.box(pup, "Head", Vector3(0.28, 0.26, 0.28), Vector3(0, 0.45, -0.4), Color("c98f4f"))
	Blocks.box(pup, "Ear", Vector3(0.08, 0.16, 0.08), Vector3(0.1, 0.65, -0.4), Color("7a5530"))
	_place_passengers_on_pier()


func _place_passengers_on_pier() -> void:
	if passengers.get_parent() != self:
		passengers.reparent(self, false)
	passengers.position = Vector3.ZERO
	var cap := passengers.get_node("PierCaptain") as Node3D
	var pup := passengers.get_node("PierPup") as Node3D
	cap.position = Ep01Layout.PIER_POS + Vector3(-0.4, 0.15, 1.0)
	pup.position = Ep01Layout.PIER_POS + Vector3(0.3, 0.15, 2.0)


func _place_passengers_on_boat() -> void:
	if passengers.get_parent() != ctx.boat:
		passengers.reparent(ctx.boat, false)
	passengers.position = Vector3.ZERO
	passengers.rotation = Vector3.ZERO
	(passengers.get_node("PierCaptain") as Node3D).position = CAPTAIN_ON_BOAT
	(passengers.get_node("PierPup") as Node3D).position = PUP_ON_BOAT


# ---------- mundo coerente com o diretor ----------

func refresh_world() -> void:
	var st: StringName = ctx.director.state
	var live := ctx.director.line_fixed and (st == &"docking" or st == &"return_trip")
	beacons.visible = live
	target_zone.visible = live
	if st == &"return_trip":
		_dock_boat_at_target()
		_place_passengers_on_boat()
	elif st == &"complete":
		if not _departing:
			_place_passengers_on_boat()
			ctx.boat.input_locked = true
			ctx.boat.visible = false
	else:
		_place_passengers_on_pier()
		if st == &"docking":
			ctx.boat.visible = true
	_apply_light(is_aligned() and st == &"docking")


# ---------- estados ----------

func enter() -> void:
	var st: StringName = ctx.director.state
	_reset_flags()
	var boat := ctx.boat
	boat.visible = true
	var pilot: MemberActor = ctx.actors[&"pilot"]
	var tracker: MemberActor = ctx.actors[&"tracker"]
	var climber: MemberActor = ctx.actors[&"climber"]
	if climber.global_position.x < 85.0 + Ep01Layout.STAGE3_SHIFT:
		climber.teleport(Ep01Layout.LANDING_POS)
	if st == &"return_trip":
		_dock_boat_at_target()
		boat.input_locked = true
		boat.current_func = Callable()
		boat.assist = 0.0
		pilot.ride(boat, RIDE_PILOT)
		tracker.ride(boat, RIDE_TRACKER)
		_place_passengers_on_boat()
		depart_it.enabled = true
		board_it.enabled = false
		_apply_light(false)
		return
	# docking
	boat.input_locked = false
	var in_arm := boat.global_position.x >= BOUND_WEST and boat.global_position.x <= BOUND_EAST \
		and boat.global_position.z >= BOUND_NORTH and boat.global_position.z <= BOUND_SOUTH
	if not in_arm:
		boat.place(Ep01Layout.BOAT_ARM_START, 0.0)
	pilot.ride(boat, RIDE_PILOT)
	tracker.ride(boat, RIDE_TRACKER)
	boat.current_func = _current_at
	boat.clearance_func = _clearance_at
	boat.assist_heading = Ep01Layout.DOCKING_TARGET_HEADING
	boat.assist = 0.0
	_place_passengers_on_pier()
	board_it.enabled = false
	depart_it.enabled = false


func _reset_flags() -> void:
	_hits.clear()
	_assist_said = false
	_last_assist_say_ms = -1000000
	_retry_count = 0


func exit() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	board_it.enabled = false
	depart_it.enabled = false
	ctx.boat.assist = 0.0
	if ctx.director.state == &"complete":
		_start_departure()


func control_started(_member: StringName) -> void:
	var st: StringName = ctx.director.state
	if st == &"docking" or st == &"return_trip":
		_say_keys(Ep01Content.lines(st, "enter"))


func _say_keys(keys: Array[String]) -> void:
	for k in keys:
		ctx.hud.say(k)


func controlled_node(member: StringName) -> Node3D:
	if member == &"pilot":
		return ctx.boat
	return super.controlled_node(member)


func focus_node(member: StringName) -> Node3D:
	return controlled_node(member)


func camera_view() -> Dictionary:
	# Alta e a oeste/sul do barco: linha (z=4), barco (alvo) e pier (a leste) ficam juntos e livres.
	return {"offset": Vector3(-7.0, 12.0, 13.0), "yaw": 0.0}


func gesture_hint(_key: String) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	for i in 3:
		_tween.tween_method(_set_pulse, 0.0, 1.0, 0.35)
		_tween.tween_method(_set_pulse, 1.0, 0.0, 0.35)
	var wheel := ctx.boat.wheel
	if wheel:
		var base := wheel.basis
		_tween.parallel().tween_method(func(v: float) -> void: wheel.basis = base * Basis(Vector3.UP, v), 0.0, TAU, 1.5)


func _set_pulse(v: float) -> void:
	_pulse = v
	_apply_light(_lit)


# ---------- fisica e assistencia ----------

func _current_at(pos: Vector3) -> Vector3:
	var a := assist_for(pos)
	return ARM_CURRENT * (1.0 - a / ASSIST_MAX)


func _clearance_at(pos: Vector3) -> float:
	return minf(minf(pos.x - BOUND_WEST, BOUND_EAST - pos.x), minf(pos.z - BOUND_NORTH, BOUND_SOUTH - pos.z))


func _flat_dist(pos: Vector3) -> float:
	var d := pos - Ep01Layout.DOCKING_TARGET_POS
	d.y = 0.0
	return d.length()


## 0 longe; cresce linearmente ate ASSIST_MAX dentro de ASSIST_RANGE do alvo.
func assist_for(pos: Vector3) -> float:
	return clampf(1.0 - _flat_dist(pos) / ASSIST_RANGE, 0.0, 1.0) * ASSIST_MAX


func is_aligned() -> bool:
	var b := ctx.boat
	var herr := absf(wrapf(b.heading - Ep01Layout.DOCKING_TARGET_HEADING, -PI, PI))
	return _flat_dist(b.global_position) <= Ep01Layout.DOCKING_POS_TOLERANCE \
		and herr <= Ep01Layout.DOCKING_HEADING_TOLERANCE \
		and b.speed <= Ep01Layout.DOCKING_SPEED_TOLERANCE


func process_stage(delta: float) -> void:
	_clock += delta
	var st: StringName = ctx.director.state
	if st == &"docking":
		update_docking()
	elif st == &"return_trip" and not _departing:
		depart_it.global_position = ctx.boat.global_position


## Um quadro da logica de atracacao (publico para testes).
func update_docking() -> void:
	if ctx.director.state != &"docking":
		return
	var boat := ctx.boat
	boat.assist = assist_for(boat.global_position)
	boat.assist_heading = Ep01Layout.DOCKING_TARGET_HEADING
	if boat.assist > 0.05 and not _assist_said:
		_say_assist()
	var ok := is_aligned()
	board_it.global_position = boat.global_position
	board_it.enabled = ok
	_apply_light(ok)
	if boat.global_position.z < OVERSHOOT_Z:
		restart_approach()
		return
	while not _hits.is_empty() and _clock - _hits[0] > STUCK_WINDOW:
		_hits.pop_front()
	if _hits.size() >= STUCK_HITS:
		restart_approach()


func _say_assist() -> void:
	var now := Time.get_ticks_msec()
	if now - _last_assist_say_ms < ASSIST_SPEECH_COOLDOWN_MS:
		return
	_assist_said = true
	_last_assist_say_ms = now
	_say_keys(Ep01Content.lines(&"docking", "assist"))


func _on_soft_hit() -> void:
	if ctx.director.state == &"docking":
		_hits.append(_clock)


## Nova aproximacao sem reiniciar a etapa: o diretor continua em docking.
func restart_approach() -> void:
	_hits.clear()
	_retry_count += 1
	ctx.boat.place(Ep01Layout.BOAT_ARM_START, 0.0)
	ctx.boat.assist = 0.0
	board_it.enabled = false
	_say_keys(Ep01Content.lines(&"docking", "retry"))


func _apply_light(on: bool) -> void:
	_lit = on
	var e := (1.8 if on else 0.4) + _pulse * 1.5
	for m in _target_mats:
		var c := COLOR_ON if on else COLOR_OFF
		m.albedo_color = c
		m.emission = c
		m.emission_energy_multiplier = e
	if _light:
		_light.light_energy = (1.6 if on else 0.3) + _pulse
		_light.light_color = COLOR_ON if on else COLOR_OFF


# ---------- acoes ----------

## Tenta atracar. `aligned` vem do estado real do barco; o diretor decide.
func board() -> Dictionary:
	var res := ctx.submit(&"boat_docked", &"pilot", {"aligned": is_aligned()})
	if res.get("accepted", false):
		_say_keys(Ep01Content.lines(&"docking", "boat_docked"))
	else:
		_say_keys(Ep01Content.lines(&"docking", "retry"))
	return res


func depart_now() -> Dictionary:
	return ctx.submit(&"departure_confirmed", &"pilot")


func place_boat_for_test(pos: Vector3, heading: float, speed: float = 0.0) -> void:
	ctx.boat.place(pos, heading)
	ctx.boat.speed = speed


func dock_now() -> Dictionary:
	place_boat_for_test(Ep01Layout.DOCKING_TARGET_POS, Ep01Layout.DOCKING_TARGET_HEADING, 0.0)
	return board()


func _dock_boat_at_target() -> void:
	ctx.boat.place(Ep01Layout.DOCKING_TARGET_POS, Ep01Layout.DOCKING_TARGET_HEADING)


func is_departing() -> bool:
	return _departing


func _start_departure() -> void:
	# Chamado no exit() ao ir para `complete`: o barco parte enquanto as falas finais passam.
	_departing = true
	var boat := ctx.boat
	boat.input_locked = true
	boat.current_func = Callable()
	boat.clearance_func = Callable()
	_say_keys(Ep01Content.lines(&"return_trip", "departure_confirmed"))
	var from := boat.global_position
	var to := Ep01Layout.BOAT_ARM_START + Vector3(0, 0, 14.0)
	_tween = create_tween()
	_tween.tween_method(func(t: float) -> void:
		boat.heading = lerpf(0.0, PI, smoothstep(0.0, 0.35, t))
		boat.rotation.y = boat.heading
		boat.global_position = from.lerp(to, t * t * (3.0 - 2.0 * t)), 0.0, 1.0, 6.0)
	_tween.finished.connect(_finish_departure)


func _finish_departure() -> void:
	_departing = false
	ctx.boat.visible = false
