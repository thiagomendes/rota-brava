class_name IslandStage
extends StageBase
## Etapa 3 - Abrir a travessia (Pico): escolhe apoios na rocha, atravessa o braco de rio e fixa a linha na ilha.
## Cenografia PROVISORIA. A corda e uma curva de 16 segmentos entre ANCHOR_A e ANCHOR_B (sem fisica).

const SEGMENTS := 16
const FOOT_RADIUS := 0.9
const DECOY_RADIUS := 0.7
const FALL_Y := -1.2
const SLACK_SAG := 0.7
const TAUT_SAG := 0.1
const ROPE_THICK := 0.08
const SLAB_TOP := -0.03
## Iscas (escuras e molhadas) sobre a laje da rocha; pisar = passo perdido.
const DECOYS := [Vector3(93.8, 0.0, 3.7), Vector3(95.0, 0.0, 3.6), Vector3(97.4, 0.0, 7.0), Vector3(99.0, 0.0, 6.2)]
const ISLAND_SAFE_POS := Vector3(99.9, 0.0, 5.6)

var rope_visible: bool = false
var _marks: Array[MeshInstance3D] = []
var _rope: Node3D
var _segs: Array[MeshInstance3D] = []
var _rope_tween: Tween
var _pulse_tween: Tween
var _sag: float = SLACK_SAG
var _fix_it: Ep01Interactable
var _miss_cooldown: float = 0.0


func setup(main: Ep01Main) -> void:
	super.setup(main)
	_build_land()
	_build_rock()
	_build_anchors()
	_build_rope()
	_fix_it = Ep01Interactable.new()
	_fix_it.name = "FixLine"
	_fix_it.action_id = &"fix_line"
	_fix_it.label_key = "ui.action.fix_line"
	_fix_it.icon = &"line"
	_fix_it.member = &"climber"
	_fix_it.radius = 2.2
	add_child(_fix_it)
	_fix_it.global_position = Ep01Layout.ANCHOR_B
	_fix_it.enabled = false
	_fix_it.triggered.connect(func(_a: Node3D) -> void: fix_line())


# ---------- cenografia ----------

func _build_land() -> void:
	# Margem oeste do braco (a enseada do barco fica mais a oeste, x ~ 88) e a ilha.
	Blocks.solid_box(self, "Bank", Vector3(3.3, 1.0, 14.0), Vector3(91.15, -0.5, 9.0), Color("8aa05a"))
	Blocks.solid_box(self, "Island", Vector3(18.5, 1.0, 19.0), Vector3(108.75, -0.5, -0.5), Color("a7b86a"))
	Blocks.solid_box(self, "IslandSand", Vector3(3.0, 0.04, 5.0), Vector3(101.5, 0.02, 5.0), Color("e8d9a0"))
	# Muros invisiveis: o jogador nao sai do mapa por terra.
	for w: Array in [[Vector3(0.5, 4, 14), Vector3(89.4, 2, 9)], [Vector3(3.3, 4, 0.5), Vector3(91.15, 2, 16.2)],
			[Vector3(0.5, 4, 19), Vector3(118.2, 2, -0.5)], [Vector3(18.5, 4, 0.5), Vector3(108.75, 2, -10.2)],
			[Vector3(18.5, 4, 0.5), Vector3(108.75, 2, 9.2)]]:
		_wall(w[0] as Vector3, w[1] as Vector3)


func _wall(size: Vector3, pos: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = "InvisibleWall"
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = pos
	var sh := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	sh.shape = bs
	body.add_child(sh)
	body.set_meta(Blocks.PROVISIONAL, true)
	add_child(body)


func _build_rock() -> void:
	# Laje cinza da rocha (liga a margem a ilha), 3 apoios seguros claros marcados em amarelo e iscas escuras.
	Blocks.solid_box(self, "RockSlab", Vector3(7.4, 1.0, 5.6), Vector3(96.3, SLAB_TOP - 0.5, 5.6), Color("6c7378"))
	for i in Ep01Layout.ROCK_FOOTHOLDS.size():
		var p: Vector3 = Ep01Layout.ROCK_FOOTHOLDS[i]
		var b := Blocks.solid_box(self, "Foothold%d" % (i + 1), Vector3(1.4, 1.0, 1.4), Vector3(p.x, -0.5, p.z), Color("d9d4c0"))
		_marks.append(Blocks.box(b, "Mark", Vector3(0.7, 0.02, 0.7), Vector3(0, 0.51, 0), Color("ffd24d"), 0.6))
	for j in DECOYS.size():
		var d: Vector3 = DECOYS[j]
		var m := Blocks.box(self, "Decoy%d" % (j + 1), Vector3(1.2, 0.02, 1.2), Vector3(d.x, SLAB_TOP + 0.011, d.z), Color("22303a"))
		m.set_meta(&"decoy", true)


func _build_anchors() -> void:
	for pair: Array in [["AnchorA", Ep01Layout.ANCHOR_A], ["AnchorB", Ep01Layout.ANCHOR_B]]:
		var p: Vector3 = pair[1]
		Blocks.cylinder(self, String(pair[0]) + "Pole", 0.12, p.y, Vector3(p.x, p.y * 0.5, p.z), Color("8a5a2b"))
		Blocks.sphere(self, String(pair[0]) + "Tip", 0.2, p, Color("ffd24d"), 1.5)


func _build_rope() -> void:
	_rope = Node3D.new()
	_rope.name = "Rope"
	add_child(_rope)
	for i in SEGMENTS:
		_segs.append(Blocks.box(_rope, "Seg%d" % i, Vector3(ROPE_THICK, ROPE_THICK, 1.0), Vector3.ZERO, Color("f2c14e")))
	_rope.visible = false
	_apply_sag(SLACK_SAG)


## Ponto i (0..SEGMENTS) da curva: reta A-B com flecha parabolica `sag`.
func rope_point(i: int, sag: float) -> Vector3:
	var t := float(i) / float(SEGMENTS)
	var p := Ep01Layout.ANCHOR_A.lerp(Ep01Layout.ANCHOR_B, t)
	p.y -= sag * 4.0 * t * (1.0 - t)
	return p


func _apply_sag(sag: float) -> void:
	_sag = sag
	for i in SEGMENTS:
		var a := rope_point(i, sag)
		var b := rope_point(i + 1, sag)
		var s := _segs[i]
		s.position = (a + b) * 0.5
		s.look_at(b, Vector3.UP)
		s.scale = Vector3(1, 1, a.distance_to(b))


## Extremos reais da curva montada (inicio do 1o segmento, fim do ultimo), em coordenadas do mundo.
func rope_ends() -> Array[Vector3]:
	var first := _segs[0]
	var last := _segs[SEGMENTS - 1]
	var start := first.global_position + first.global_transform.basis.z.normalized() * first.scale.z * 0.5
	var end := last.global_position - last.global_transform.basis.z.normalized() * last.scale.z * 0.5
	return [start, end]


func rope_sag() -> float:
	return _sag


# ---------- ciclo do estagio ----------

func enter() -> void:
	var climber: MemberActor = ctx.actors[&"climber"]
	if ctx.director.state == &"island_crossing":
		climber.dismount(Ep01Layout.LANDING_POS)
		climber.face_now(Ep01Layout.ANCHOR_A)
		for m: StringName in [&"pilot", &"tracker"]:
			var a: MemberActor = ctx.actors[m]
			if a.riding_on == null:
				a.ride(ctx.boat, Vector3(-0.45 if m == &"pilot" else 0.45, 0.6, 0.9))
		ctx.boat.place(Ep01Layout.ENSEADA_POS, 0.0)
		_miss_cooldown = 0.0
	refresh_world()


func exit() -> void:
	_fix_it.enabled = false


func refresh_world() -> void:
	var d := ctx.director
	_set_rope_visible(d.line_fixed)
	if d.line_fixed and not (_rope_tween and _rope_tween.is_valid()):
		_apply_sag(TAUT_SAG)
	for i in _marks.size():
		var reached := i < d.last_safe_foothold
		_marks[i].material_override = Blocks.material(Color("7dff9a") if reached else Color("ffd24d"), 1.2 if reached else 0.6)
	_fix_it.enabled = d.state == &"island_crossing"
	var climber: MemberActor = ctx.actors[&"climber"]
	if d.state == &"docking" or d.state == &"return_trip":
		if climber.riding_on == null:
			climber.teleport(ISLAND_SAFE_POS)
			climber.face_now(Ep01Layout.PIER_POS)
	elif d.state == &"island_crossing":
		if ctx.boat.global_position.distance_to(Ep01Layout.ENSEADA_POS) > 4.0:
			ctx.boat.place(Ep01Layout.ENSEADA_POS, 0.0)


func control_started(member: StringName) -> void:
	if member == &"climber":
		ctx.hud.say(Ep01Content.lines(&"island_crossing", "enter")[0])


func camera_view() -> Dictionary:
	# Camera a oeste-sudoeste olhando para leste: braco, rocha e ilha a frente; o barco na enseada atras/a direita.
	return {"offset": Vector3(0, 9.0, 15.0), "yaw": -1.2}


func _next_target() -> Vector3:
	var n := ctx.director.last_safe_foothold
	if n < 3:
		return Ep01Layout.ROCK_FOOTHOLDS[n]
	return Ep01Layout.ANCHOR_B


func gesture_hint(_key: String) -> void:
	var n := ctx.director.last_safe_foothold
	(ctx.actors[&"climber"] as MemberActor).face_point(_next_target())
	var node: Node3D = _marks[n] if n < 3 else null
	if node == null:
		return
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
	node.scale = Vector3.ONE
	_pulse_tween = create_tween()
	_pulse_tween.set_loops(3)
	_pulse_tween.tween_property(node, "scale", Vector3(1.6, 1.0, 1.6), 0.3)
	_pulse_tween.tween_property(node, "scale", Vector3.ONE, 0.3)


func process_stage(delta: float) -> void:
	var climber: MemberActor = ctx.actors[&"climber"]
	if ctx.director.state != &"island_crossing":
		if (ctx.director.state == &"docking" or ctx.director.state == &"return_trip") \
				and climber.riding_on == null and climber.global_position.y < FALL_Y:
			climber.teleport(ISLAND_SAFE_POS)
		return
	_miss_cooldown = maxf(0.0, _miss_cooldown - delta)
	if climber.riding_on != null or _miss_cooldown > 0.0:
		return
	var pos := climber.global_position
	if pos.y < FALL_Y:
		fall_into_water()
		return
	if pos.y < -0.3:
		return
	var next := ctx.director.last_safe_foothold + 1
	if next <= 3 and _horiz(pos, Ep01Layout.ROCK_FOOTHOLDS[next - 1]) <= FOOT_RADIUS:
		step_on_foothold(next)
		return
	if _on_any_foothold(pos):
		return
	for d: Vector3 in DECOYS:
		if _horiz(pos, d) <= DECOY_RADIUS:
			step_on_decoy()
			return


func _on_any_foothold(pos: Vector3) -> bool:
	for p: Vector3 in Ep01Layout.ROCK_FOOTHOLDS:
		if _horiz(pos, p) <= FOOT_RADIUS:
			return true
	return false


static func _horiz(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


# ---------- acoes publicas (tambem usadas pelos testes) ----------

func step_on_foothold(index: int) -> Dictionary:
	var res := ctx.submit(&"foothold_reached", &"climber", {"index": index})
	if res.get("accepted", false):
		ctx.hud.say(Ep01Content.lines(&"island_crossing", "foothold_reached")[0])
		refresh_world()
	return res


func step_on_decoy() -> Dictionary:
	return _miss()


func fall_into_water() -> Dictionary:
	return _miss()


func _miss() -> Dictionary:
	_miss_cooldown = 1.0
	var res := ctx.submit(&"foothold_missed", &"climber")
	var idx := int(res.get("respawn_foothold", ctx.director.last_safe_foothold))
	var pos := Ep01Layout.LANDING_POS
	if idx >= 1:
		var f: Vector3 = Ep01Layout.ROCK_FOOTHOLDS[idx - 1]
		pos = Vector3(f.x, 0.1, f.z)
	var climber: MemberActor = ctx.actors[&"climber"]
	climber.teleport(pos)
	climber.face_point(_next_target())
	ctx.hud.say(Ep01Content.lines(&"island_crossing", "foothold_missed")[0])
	return res


func fix_line() -> Dictionary:
	var res := ctx.submit(&"line_fixed", &"climber")
	if not res.get("accepted", false):
		var hints := Ep01Content.hints(&"island_crossing")
		if hints.size() > 1:
			ctx.hud.say(String(hints[1]["key"]), {}, true)
		return res
	_set_rope_visible(true)
	_apply_sag(SLACK_SAG)
	for k in Ep01Content.lines(&"island_crossing", "line_fixed"):
		ctx.hud.say(k)
	_play_tugs()
	return res


func _set_rope_visible(on: bool) -> void:
	rope_visible = on
	_rope.visible = on


## Dois puxoes: a corda estica de repente, afrouxa e estica de novo; termina esticada e persistente.
func _play_tugs() -> void:
	if _rope_tween and _rope_tween.is_valid():
		_rope_tween.kill()
	_rope_tween = create_tween()
	var set_sag := Callable(self, "_apply_sag")
	_rope_tween.tween_interval(1.0)
	_rope_tween.tween_method(set_sag, SLACK_SAG, TAUT_SAG, 0.25)
	_rope_tween.tween_method(set_sag, TAUT_SAG, 0.45, 0.35)
	_rope_tween.tween_interval(1.2)
	_rope_tween.tween_method(set_sag, 0.45, TAUT_SAG, 0.25)
	_rope_tween.tween_method(set_sag, TAUT_SAG, 0.3, 0.2)
	_rope_tween.tween_method(set_sag, 0.3, TAUT_SAG, 0.3)


