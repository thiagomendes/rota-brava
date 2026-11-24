class_name IslandStage
extends StageBase
## Etapa 3 - Abrir a travessia (Pico): PULA de apoio em apoio sobre o braco de rio e fixa a linha na ilha.
## Cenografia PROVISORIA (blocos) quando nao existe a cena de mundo `island_world.tscn`.
## Nao ha laje continua: entre os apoios ha agua. Errar (isca escura ou agua) devolve, com um pulinho, ao ULTIMO
## apoio seguro, sem culpa.
##
## Decisao de design (RB-R1): salto AUTOMATICO ao chegar a borda empurrando o analogico para um apoio, com mira
## assistida (o apoio mais proximo da direcao do analogico, ate JUMP_RANGE). Para 5 anos e o mais claro: apontar
## para onde quer ir basta, sem coordenar um segundo botao. `interact` tambem pula para o alvo mirado (quem ja
## aprendeu "botao = acao" nao fica sem resposta). Uma sombra no alvo mostra onde Pico vai pousar.
## A corda e uma curva de 16 segmentos entre ANCHOR_A e ANCHOR_B (sem fisica).

const SEGMENTS := 16
const FOOT_RADIUS := 0.9
const DECOY_RADIUS := 0.7
const FALL_Y := -1.2
const SLACK_SAG := 0.7
const TAUT_SAG := 0.1
const ROPE_THICK := 0.08
const FOOT_SIZE := 1.4
const WORLD_SCENE := "res://episodes/ep01/world/island_world.tscn"
## Salto: alcance horizontal maximo, cone da mira (rad) e tempo empurrando ate pular na borda.
const JUMP_RANGE := 3.8
const JUMP_MIN := 0.9
const AIM_CONE := 0.9
const EDGE_LOOK := 0.55
const EDGE_HOLD := 0.1
const JUMP_TIME := 0.55
const JUMP_HEIGHT := 0.9
const RECOVER_TIME := 0.6
const S := Ep01Layout.STAGE3_SHIFT
## Iscas (pedras escuras e molhadas, um pouco abaixo dos apoios); pousar = passo perdido.
const DECOYS := [Vector3(93.8 + S, -0.15, 3.4), Vector3(95.0 + S, -0.15, 7.6), Vector3(97.4 + S, -0.15, 7.0), Vector3(98.8 + S, -0.15, 6.6)]
## Chao firme (x,z; topo y = 0): margem oeste do braco e ilha. Os apoios ficam na agua entre os dois.
const BANK_RECT := Rect2(175.5, 1.5, 6.5, 16.5)      # lingua de terra do pouso (river_world Floors/PicoLanding)
const ISLAND_RECT := Rect2(191.5, -10.0, 15.0, 22.0)  # ilha (island_world Floors/IslandFloor)
const ISLAND_SAFE_POS := Vector3(192.5, 0.0, 5.6)
## Pontos de pouso em terra (para pular de volta a margem e do apoio 3 para a ilha).
const BANK_LAND := Vector3(181.2, 0.0, 6.5)
const ISLAND_LAND := Vector3(192.0, 0.0, 4.2)

var rope_visible: bool = false
var world_mounted: bool = false
var jumps: int = 0
## Ultimo alvo da mira (posicao dos pes) ou null.
var aim_target: Variant = null
var _marks: Array[MeshInstance3D] = []
var _rope: Node3D
var _segs: Array[MeshInstance3D] = []
var _rope_tween: Tween
var _pulse_tween: Tween
var _sag: float = SLACK_SAG
var _fix_it: Ep01Interactable
var _jump_it: Ep01Interactable
var _shadow: MeshInstance3D
var _miss_cooldown: float = 0.0
var _edge_clock: float = 0.0
var _recovering: bool = false
var _clock: float = 0.0


func setup(main: Ep01Main) -> void:
	super.setup(main)
	if ResourceLoader.exists(WORLD_SCENE):
		add_child((load(WORLD_SCENE) as PackedScene).instantiate())
		world_mounted = true
	else:
		_build_land()
	_build_rock()
	_build_anchors()
	_build_rope()
	_build_shadow()
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
	_jump_it = Ep01Interactable.new()
	_jump_it.name = "Jump"
	_jump_it.action_id = &"jump"
	_jump_it.label_key = "ui.action.jump"
	_jump_it.icon = &"line"
	_jump_it.member = &"climber"
	_jump_it.radius = 1.0
	_jump_it.enabled = false
	add_child(_jump_it)
	_jump_it.triggered.connect(func(_a: Node3D) -> void: jump_to_aim())


# ---------- cenografia ----------

func _build_land() -> void:
	var b := BANK_RECT
	var i := ISLAND_RECT
	Blocks.solid_box(self, "Bank", Vector3(b.size.x, 1.0, b.size.y), Vector3(b.get_center().x, -0.5, b.get_center().y), Color("8aa05a"))
	Blocks.solid_box(self, "Island", Vector3(i.size.x, 1.0, i.size.y), Vector3(i.get_center().x, -0.5, i.get_center().y), Color("a7b86a"))
	Blocks.solid_box(self, "IslandSand", Vector3(3.0, 0.04, 5.0), Vector3(101.5 + S, 0.02, 5.0), Color("e8d9a0"))
	# Muros invisiveis: o jogador nao sai do mapa por terra (o lado da agua fica aberto: cair = voltar ao apoio).
	for w: Array in [[Vector3(0.5, 4, 14), Vector3(b.position.x - 0.25, 2, b.get_center().y)],
			[Vector3(b.size.x, 4, 0.5), Vector3(b.get_center().x, 2, b.end.y + 0.25)],
			[Vector3(0.5, 4, i.size.y), Vector3(i.end.x + 0.25, 2, i.get_center().y)],
			[Vector3(i.size.x, 4, 0.5), Vector3(i.get_center().x, 2, i.position.y - 0.25)],
			[Vector3(i.size.x, 4, 0.5), Vector3(i.get_center().x, 2, i.end.y + 0.25)]]:
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
	# Apoios seguros: pedras claras com brilho suave (topo em p.y). Iscas: pedras escuras e molhadas, quase na agua.
	for i in Ep01Layout.ROCK_FOOTHOLDS.size():
		var p: Vector3 = Ep01Layout.ROCK_FOOTHOLDS[i]
		var h := p.y - Ep01Layout.WATER_Y + 0.6
		var b := Blocks.solid_box(self, "Foothold%d" % (i + 1), Vector3(FOOT_SIZE, h, FOOT_SIZE), Vector3(p.x, p.y - h * 0.5, p.z), Color("d9d4c0"))
		_marks.append(Blocks.box(b, "Mark", Vector3(0.8, 0.02, 0.8), Vector3(0, h * 0.5 + 0.01, 0), Color("ffd24d"), 0.6))
	for j in DECOYS.size():
		var d: Vector3 = DECOYS[j]
		var h := d.y - Ep01Layout.WATER_Y + 0.6
		var m := Blocks.solid_box(self, "Decoy%d" % (j + 1), Vector3(1.1, h, 1.1), Vector3(d.x, d.y - h * 0.5, d.z), Color("22303a"))
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


## Sombra no alvo do salto (disco escuro achatado).
func _build_shadow() -> void:
	_shadow = Blocks.cylinder(self, "JumpShadow", 0.45, 0.01, Vector3.ZERO, Color("1b2430"))
	_shadow.visible = false


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
				a.ride(ctx.boat, BoatActor.CREW[m])
		ctx.boat.place(Ep01Layout.ENSEADA_POS, 0.0)
		_miss_cooldown = 0.0
		_recovering = false
	refresh_world()


func exit() -> void:
	_fix_it.enabled = false
	_jump_it.enabled = false
	_shadow.visible = false


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
	# Camera a oeste-sudoeste olhando para leste: braco, apoios e ilha a frente; o barco na enseada atras/a direita.
	return {"offset": Vector3(0, 3.4, 4.8), "yaw": -1.2}


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
	_clock += delta
	_animate_marks()
	var climber: MemberActor = ctx.actors[&"climber"]
	if ctx.director.state != &"island_crossing":
		_shadow.visible = false
		if (ctx.director.state == &"docking" or ctx.director.state == &"return_trip") \
				and climber.riding_on == null and climber.global_position.y < FALL_Y:
			climber.teleport(ISLAND_SAFE_POS)
		return
	_miss_cooldown = maxf(0.0, _miss_cooldown - delta)
	if climber.riding_on != null or climber.airborne:
		_shadow.visible = climber.airborne and _shadow.visible
		_jump_it.enabled = false
		return
	var pos := climber.global_position
	if pos.y < FALL_Y and _miss_cooldown <= 0.0:
		fall_into_water()
		return
	if _recovering:
		_jump_it.enabled = false
		_shadow.visible = false
	else:
		_update_aim(climber, delta)
	if _miss_cooldown > 0.0 or pos.y < -0.3:
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


## Brilho suave e respirado nos apoios seguros (as iscas continuam escuras e opacas).
func _animate_marks() -> void:
	var s := 1.0 + 0.08 * sin(_clock * 2.6)
	for m in _marks:
		if not (_pulse_tween and _pulse_tween.is_valid()):
			m.scale = Vector3(s, 1.0, s)


func _on_any_foothold(pos: Vector3) -> bool:
	for p: Vector3 in Ep01Layout.ROCK_FOOTHOLDS:
		if _horiz(pos, p) <= FOOT_RADIUS:
			return true
	return false


static func _horiz(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


# ---------- salto ----------

## Alvos de salto (posicao dos pes): margem, apoios, iscas e ilha.
func jump_targets() -> Array[Vector3]:
	var out: Array[Vector3] = [BANK_LAND]
	for p: Vector3 in Ep01Layout.ROCK_FOOTHOLDS:
		out.append(p)
	for d: Vector3 in DECOYS:
		out.append(d)
	out.append(ISLAND_LAND)
	return out


## Mira assistida: alvo mais alinhado com `dir` (plano XZ) dentro do alcance, ou null.
func aim_from(pos: Vector3, dir: Vector3) -> Variant:
	dir.y = 0.0
	if dir.length() < 0.2:
		return null
	dir = dir.normalized()
	var best: Variant = null
	var best_score := INF
	for t in jump_targets():
		var d := Vector3(t.x - pos.x, 0.0, t.z - pos.z)
		var dist := d.length()
		if dist < JUMP_MIN or dist > JUMP_RANGE:
			continue
		var ang := dir.angle_to(d / dist)
		if ang > AIM_CONE:
			continue
		var score := ang * 2.0 + dist * 0.25
		if score < best_score:
			best_score = score
			best = t
	return best


## Ha chao firme (margem, ilha, apoio ou isca) sob o ponto?
func has_ground(p: Vector3) -> bool:
	var q := Vector2(p.x, p.z)
	if BANK_RECT.has_point(q) or ISLAND_RECT.has_point(q):
		return true
	for f: Vector3 in Ep01Layout.ROCK_FOOTHOLDS:
		if absf(p.x - f.x) <= FOOT_SIZE * 0.5 and absf(p.z - f.z) <= FOOT_SIZE * 0.5:
			return true
	for d: Vector3 in DECOYS:
		if absf(p.x - d.x) <= 0.55 and absf(p.z - d.z) <= 0.55:
			return true
	return false


func _stick_world(climber: MemberActor) -> Vector3:
	if not climber.controlled:
		return Vector3.ZERO
	var v := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	return Basis(Vector3.UP, climber.move_yaw) * Vector3(v.x, 0.0, v.y)


func _update_aim(climber: MemberActor, delta: float) -> void:
	var dir := _stick_world(climber)
	aim_target = aim_from(climber.global_position, dir)
	_jump_it.enabled = aim_target != null
	_jump_it.global_position = climber.global_position
	_shadow.visible = aim_target != null
	if aim_target == null:
		_edge_clock = 0.0
		return
	var t: Vector3 = aim_target
	_shadow.global_position = t + Vector3(0, 0.03, 0)
	# Na borda (sem chao logo a frente) e ainda empurrando para o alvo: pula sozinho.
	var ahead := climber.global_position + dir.normalized() * EDGE_LOOK
	if has_ground(ahead):
		_edge_clock = 0.0
		return
	_edge_clock += delta
	if _edge_clock >= EDGE_HOLD:
		_edge_clock = 0.0
		jump_to_aim()


## Pula para o alvo mirado (salto automatico na borda ou `interact`). Devolve true se saltou.
func jump_to_aim() -> bool:
	if aim_target == null:
		return false
	return jump_to(aim_target as Vector3)


func jump_to(target: Vector3) -> bool:
	var climber: MemberActor = ctx.actors[&"climber"]
	if climber.airborne or _recovering or ctx.director.state != &"island_crossing":
		return false
	jumps += 1
	_shadow.visible = true
	_shadow.global_position = target + Vector3(0, 0.03, 0)
	_jump_it.enabled = false
	climber.jump_to(target, JUMP_TIME, JUMP_HEIGHT)
	climber.landed.connect(_on_landed, CONNECT_ONE_SHOT)
	return true


func _on_landed(pos: Vector3) -> void:
	_shadow.visible = false
	FeedbackFx.dust(self, pos)
	for d: Vector3 in DECOYS:
		if _horiz(pos, d) <= DECOY_RADIUS:
			step_on_decoy()
			return


# ---------- acoes publicas (tambem usadas pelos testes) ----------

func step_on_foothold(index: int) -> Dictionary:
	var res := ctx.submit(&"foothold_reached", &"climber", {"index": index})
	if res.get("accepted", false):
		ctx.hud.say(Ep01Content.lines(&"island_crossing", "foothold_reached")[0])
		FeedbackFx.sparkle(self, Ep01Layout.ROCK_FOOTHOLDS[index - 1] + Vector3(0, 0.2, 0))
		refresh_world()
	return res


func step_on_decoy() -> Dictionary:
	return _miss()


func fall_into_water() -> Dictionary:
	return _miss()


## Posicao do ultimo apoio seguro (pes) para `idx` (0 = margem).
func safe_pos(idx: int) -> Vector3:
	if idx >= 1:
		return Ep01Layout.ROCK_FOOTHOLDS[idx - 1]
	return Ep01Layout.LANDING_POS


## Erro sem culpa: respingo, e um pulinho curto de volta ao ultimo apoio seguro. Posicao final ja definida no retorno.
func _miss() -> Dictionary:
	_miss_cooldown = 1.0
	var res := ctx.submit(&"foothold_missed", &"climber")
	var idx := int(res.get("respawn_foothold", ctx.director.last_safe_foothold))
	var pos := safe_pos(idx)
	var climber: MemberActor = ctx.actors[&"climber"]
	FeedbackFx.splash(self, Vector3(climber.global_position.x, Ep01Layout.WATER_Y, climber.global_position.z))
	var from := climber.global_position
	climber.teleport(pos)
	climber.face_point(_next_target())
	ctx.hud.say(Ep01Content.lines(&"island_crossing", "foothold_missed")[0])
	_animate_recover(climber, from, pos)
	return res


## Animacao curta (so visual): o pivo do modelo sai de onde Pico errou e volta em arco ate o apoio. O corpo ja esta
## no apoio seguro (estado consistente mesmo se a cena for interrompida).
func _animate_recover(climber: MemberActor, from: Vector3, to: Vector3) -> void:
	var vis := climber.get_node_or_null("Visual") as Node3D
	if vis == null or ctx.camera_rig.reduced_motion:
		return
	_recovering = true
	var offset := from - to
	var tw := create_tween()
	tw.tween_method(func(t: float) -> void:
		var p := offset * (1.0 - t)
		p.y = offset.y * (1.0 - t) + 1.2 * 4.0 * t * (1.0 - t)
		vis.position = p, 0.0, 1.0, RECOVER_TIME)
	tw.finished.connect(func() -> void:
		vis.position = Vector3.ZERO
		_recovering = false)


func fix_line() -> Dictionary:
	var res := ctx.submit(&"line_fixed", &"climber")
	if not res.get("accepted", false):
		var hints := Ep01Content.hints(&"island_crossing")
		if hints.size() > 1:
			ctx.hud.say(String(hints[1]["key"]), {}, true)
		return res
	_set_rope_visible(true)
	_apply_sag(SLACK_SAG)
	FeedbackFx.ring(self, Ep01Layout.ANCHOR_B, Color("ffe14d"))
	FeedbackFx.ring(self, Ep01Layout.ANCHOR_A, Color("ffe14d"))
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
