class_name Ep01V3Late
extends Ep01V3Land
## Missoes M5-M8 do Ep01 v3 (RB-R1 E5), sobre a mesma base de pontos de acao das M1-M4 (Ep01V3Land):
## - M5 gaivota com o peixe: Rastro segue as penas (passar por cima), Leme le a bussola do cata-vento, Pico sobe caixotes,
##   toldo e telhado (saltos encadeados pelos marcadores), a gaivota foge, ele pega o peixe e baixa na corda.
## - M6 resgate na baia (unica de barco): Leme embarca com o Pico (colete so nesta missao), passa as 2 boias, encosta no bote
##   (atracacao assistida nos metros finais), Pico joga a corda; reboque curto e corte para o cais.
## - M7 lanterna do farol: Rastro acha a lente, Pico sobe escada e patamares ate a galeria (saltos encadeados; as rampas
##   AccessRamps ficam desligadas), resgata o filhote e repoe a lente; Leme gira a lanterna para os 4 barquinhos da festa.
## - M8 festa: noite de festa, barquinhos com lanterna e icone acesos, o capitao agradece na praca e a tela final mostra os
##   emblemas por heroi.
## Pecas PROVISORIAS por Ep01V3Pieces (um ponto de troca por peca). Nada e gravado no mundo do art3d: so posicao e
## visibilidade das pecas soltas dele (bote, lente, lanterna) mudam em tempo de jogo.

const LATE: Array[StringName] = [&"M5", &"M6", &"M7", &"M8"]
## Heroi de cada emblema do episodio (tela final: emblemas por heroi).
const EMBLEM_HERO := {
	&"emb_m1_mooring": &"tracker", &"emb_m2_shed": &"climber", &"emb_m2_reeds": &"tracker", &"emb_m3_basin": &"climber",
	&"emb_m4_stall": &"pilot", &"emb_m5_vane": &"pilot", &"emb_m5_roof": &"climber", &"emb_m6_bay": &"pilot",
	&"emb_m7_lens": &"tracker", &"emb_m7_gallery": &"climber",
}
## Ordem das penas (da rua do mercado ate o cata-vento) e barquinhos da festa (marcador, icone).
const FEATHERS: Array[StringName] = [&"M5_FeatherTrail_4", &"M5_FeatherTrail_3", &"M5_FeatherTrail_2", &"M5_FeatherTrail_1"]
const FESTA_BOATS: Array[StringName] = [&"M7_FestaBoat_1_star", &"M7_FestaBoat_2_moon", &"M7_FestaBoat_3_fish", &"M7_FestaBoat_4_flower"]
## Icones PROVISORIOS: a marca ainda nao tem lua, peixe e flor (pedir ao ux); usam pictogramas que ja existem.
const FESTA_ICONS: Array[StringName] = Ep01V3Pieces.FESTA_BOAT_ICONS
## Barco: raio do casco para a folga (m), raio de passagem nas boias e da aproximacao assistida.
const HULL := 1.0
const BOW_HULL := 0.5
const BUOY_RADIUS := 3.0
const APPROACH_RADIUS := 3.5
const DOCK_TIME := 1.4
const TOW_TIME := 2.4
const FADE_TIME := 0.35
## Visao de barco: mais alta e mais longe (o casco tem 5 m).
const BOAT_VIEW := Vector3(0, 3.4, 8.0)
const BOAT_LOOK_Y := 0.9
## Cais: lugar do bote rebocado e onde o trio desembarca (perto do capitao).
const DINGHY_DOCKED := Vector3(-6.0, -0.38, -4.3)
## Retomada do M5: na rua de pedra, entre o mercado e a 1a pena (chao conferido por raio).
const M5_START_OFFSET := Vector3(-0.5, 0.0, 1.4)

var _keep: Node3D
var _icons: Array[Sprite3D] = []
var _feather_next: int = 0
var _lit: int = 0
var _rope: Node3D
var _gull: Node3D
var _fish: Node3D
var captain: Node3D
var pup: Node3D
var _dinghy_home: Transform3D
var _fade: ColorRect
var sailing: bool = false


func setup(m: Ep01V3Main) -> void:
	super.setup(m)
	name = "Land"
	_keep = Node3D.new()
	_keep.name = "Keep"
	_keep.set_meta(PROVISIONAL, true)
	add_child(_keep)
	_derive_late_points()
	var d := _dinghy()
	if d != null:
		_dinghy_home = d.global_transform
	for i in FESTA_BOATS.size():
		var s := Ep01V3Pieces.boat_icon(_keep, "FestaIcon_%d" % i, FESTA_ICONS[i])
		s.global_position = _mk(FESTA_BOATS[i]) + Vector3(0, 2.2, 0)
		_icons.append(s)
	captain = StoryFigure.spawn(_keep, "captain_model", "Captain")
	pup = StoryFigure.spawn(_keep, "pup_model", "Pup")
	captain.visible = false
	pup.visible = false
	main.boat.clearance_func = boat_clearance
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(0.02, 0.05, 0.12, 0.0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_fade)


func _dinghy() -> Node3D:
	return world.props.get("wv3_dinghy") as Node3D


func _ground(p: Vector3) -> Vector3:
	var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, 3.0, 0), p + Vector3(0, -4.0, 0), 1)
	var hit := world.get_world_3d().direct_space_state.intersect_ray(q)
	return hit.position if not hit.is_empty() else p


## Pontos derivados das M5-M8 (no proprio no, como os da E4): base dos caixotes, base e bussola do farol, embarque.
func _derive_late_points() -> void:
	var c := _mk(&"M5_Crates")
	var aw := _mk(&"M5_Awning")
	var away := c - aw
	away.y = 0.0
	points[&"CratesBase"] = Vector3(c.x, 0.0, c.z) + away.normalized() * 0.8
	var st := _mk(&"M7_StairStep")
	var sb := _mk(&"M7_StairBase")
	var out := st - sb
	out.y = 0.0
	points[&"StairFoot"] = Vector3(st.x, st.y, st.z) + out.normalized() * 0.85
	points[&"Compass"] = Vector3(st.x, st.y, st.z) + out.normalized() * 2.2 + Vector3(-1.0, 0, 0)
	var berth := _mk(&"M6_BoatStart")
	points[&"BoardSpot"] = Vector3(berth.x, 0.0, -2.6)
	points[&"DockLanding"] = _mk(&"M8_CaptainDock") + Vector3(2.0, 0, -1.0)
	var holder := get_node("DerivedPoints")
	for k: StringName in [&"CratesBase", &"StairFoot", &"Compass", &"BoardSpot", &"DockLanding"]:
		var mk := Marker3D.new()
		mk.name = String(k)
		holder.add_child(mk)
		mk.position = points[k]


func _ready() -> void:
	# Alturas do chao dos pontos derivados do farol (o promontorio nao e plano); fisica pronta so depois de entrar.
	await get_tree().physics_frame
	for k: StringName in [&"StairFoot", &"Compass"]:
		points[k] = _ground(points[k])
		var mk := get_node_or_null("DerivedPoints/" + String(k)) as Marker3D
		if mk != null:
			mk.global_position = points[k]
	# M7 montada antes da fisica (retomada direto no M7): reposiciona os pontos no chao.
	if mission_id == &"M7" and spots.has(&"stair_climb"):
		(spots[&"stair_climb"] as Ep01Interactable).global_position = points[&"StairFoot"]
		(spots[&"aim"] as Ep01Interactable).global_position = points[&"Compass"]
		var c := _root.get_node_or_null("Compass") as Node3D
		if c != null:
			c.global_position = points[&"Compass"]


func handles(id: StringName) -> bool:
	return super.handles(id) or id in LATE


## F2: a mira da lanterna (passo `aim`, marcador M7_StairStep) e feita na bussola ao lado da escada.
func clue_point(marker: StringName) -> Vector3:
	if marker == &"M7_StairStep":
		return points[&"Compass"]
	return super.clue_point(marker)


func start_position(id: StringName) -> Vector3:
	match id:
		&"M5":
			# F2: antes (+1,5; +1,0) caia num vao sem chao (dentro de uma casa) e o trio despencava (tela azul).
			return _mk(&"M5_FeatherTrail_4") + M5_START_OFFSET
		&"M6", &"M7":
			return points[&"DockLanding"]
		&"M8":
			return _mk(&"M8_FestaPlaza")
	return super.start_position(id)


# ---------------------------------------------------------------- montagem

func build(id: StringName) -> void:
	super.build(id)
	if not id in LATE:
		return
	match id:
		&"M5":
			_build_m5()
		&"M6":
			_build_m6()
		&"M7":
			_build_m7()
		&"M8":
			_build_m8()
	refresh()


func clear() -> void:
	_end_sailing()
	if main != null and is_instance_valid(main.actors.get(&"pilot")):
		(main.actors[&"pilot"] as MemberActor).set_accessory(&"Acc_LifeVest", false)
	_feather_next = 0
	_lit = 0
	_rope = null
	_gull = null
	_fish = null
	super.clear()


func _build_m5() -> void:
	# F2: penas de verdade na rua (antes so pontos invisiveis): decalque grande entre as penas e uma pena 3D em cada uma.
	var path: Array[Vector3] = []
	for i in FEATHERS.size():
		path.append(_mk(FEATHERS[i]))
		_spot(StringName("feather_%d" % (i + 1)), _mk(FEATHERS[i]), &"paw", "", &"tracker", 1.0, true)
		var f := Ep01V3Pieces.final(_root, "feather", "Feather_%d" % (i + 1))
		if f != null:
			f.global_position = _floor_at(_mk(FEATHERS[i]) + Vector3(0.25, 0, 0.2))
			f.rotation.y = deg_to_rad(70.0 + 40.0 * i)
			f.add_to_group(&"ep01v3_clue")
	trail_decals(_root, "decal_feather_big", path, 1.8)
	_spot(&"vane", _mk(&"M5_Weathervane"), &"star", "ui.action.examine", &"pilot", 1.6)
	_spot(&"crates_climb", points[&"CratesBase"], &"carabiner", "ui.action.climb", &"climber")
	_spot(&"fish", _mk(&"M5_ShedRoof"), &"rope", "ui.action.pick", &"climber", 1.3)
	_gull = Ep01V3Pieces.gull_with_fish(_root)
	_gull.global_position = _mk(&"M5_ShedRoof") + Vector3(0.2, 0.02, -0.3)
	_emblem(&"emb_m5_vane", _mk(&"M5_Weathervane") + Vector3(-1.2, 0, 0.9), &"pilot")
	_emblem(&"emb_m5_roof", _mk(&"M5_ShedRoof") + Vector3(0.75, 0, 0.45), &"climber")


func _build_m6() -> void:
	var boat := main.boat
	var berth := world.marker(&"M6_BoatStart")
	boat.place(berth.global_position, berth.global_rotation.y)
	boat.input_locked = false
	var d := _dinghy()
	if d != null:
		d.global_transform = _dinghy_home
	(main.actors[&"pilot"] as MemberActor).set_accessory(&"Acc_LifeVest", true)
	captain.visible = d != null
	if d != null:
		captain.global_position = d.global_position + Vector3(0, 0.25, 0)
		StoryFigure.face(captain, _mk(&"M6_DinghyApproach"))
	pup.visible = false
	_spot(&"board", points[&"BoardSpot"], &"boat", "ui.action.board", &"pilot", 1.7)
	_spot(&"buoy_a", _mk(&"M6_BuoyA"), &"buoy", "", &"pilot", BUOY_RADIUS, true)
	_spot(&"buoy_b", _mk(&"M6_BuoyB"), &"buoy", "", &"pilot", BUOY_RADIUS, true)
	_spot(&"approach", _mk(&"M6_DinghyApproach"), &"helm", "", &"pilot", APPROACH_RADIUS, true)
	_spot(&"rope", _mk(&"M6_DinghyApproach"), &"rope", "ui.action.throw", &"climber", 3.0)
	var a := _mk(&"M6_BuoyB")
	var b := _mk(&"M6_DinghyApproach")
	_emblem(&"emb_m6_bay", a.lerp(b, 0.5) + Vector3(0, 0.0, -0.6), &"pilot")
	var em := spots[&"emb_m6_bay"] as Ep01Interactable
	em.radius = 2.6
	em.set_meta(&"auto", true)


func _build_m7() -> void:
	_dinghy_docked()
	captain.visible = true
	captain.global_position = _mk(&"M8_CaptainDock")
	pup.visible = true
	var g := _mk(&"M7_Gallery")
	pup.global_position = g + (g - Vector3(31.0, g.y, -24.0)).normalized().cross(Vector3.UP) * 0.7
	StoryFigure.face(pup, Vector3(31.0, g.y, -24.0) + (g - Vector3(31.0, g.y, -24.0)) * 3.0)
	var lens := world.props.get("wv3_lens") as Node3D
	if lens != null:
		lens.visible = true
	world.set_beam(false)
	_lit = 0
	for s in _icons:
		Ep01V3Pieces.light_boat_icon(s, false)
	# Lente meio tapada por arbustos: o ponto fica do lado do caminho (rumo ao pe da escada), com a lente a vista.
	var lens_side := _mk(&"M7_Lens").lerp(points[&"StairFoot"] as Vector3, 0.25)
	_spot(&"lens", Vector3(lens_side.x, _mk(&"M7_Lens").y, lens_side.z), &"magnifier", "ui.action.examine", &"tracker", 1.8)
	_spot(&"stair_climb", points[&"StairFoot"], &"carabiner", "ui.action.climb", &"climber", 1.5)
	# Filhote ao lado do pouso; o emblema fica no proprio pouso (a galeria e estreita: nada de andar nela).
	_spot(&"pup", g + Vector3(0, 0, 0.4), &"heart", "ui.action.rescue", &"climber", 1.4)
	_spot(&"aim", points[&"Compass"], &"star", "ui.action.aim", &"pilot", 1.6)
	var c := Ep01V3Pieces.compass(_root)
	c.global_position = points[&"Compass"]
	_emblem(&"emb_m7_lens", _ground(_mk(&"M7_Lens") + Vector3(-1.3, 0, 0.6)), &"tracker")
	_emblem(&"emb_m7_gallery", g, &"climber")


func _build_m8() -> void:
	_dinghy_docked()
	world.set_festival(true)
	for s in _icons:
		Ep01V3Pieces.light_boat_icon(s, true)
	_aim_lantern(_icons.size() - 1, 0.0)
	var plaza := _mk(&"M8_FestaPlaza")
	captain.visible = true
	pup.visible = true
	captain.global_position = plaza + Vector3(1.6, 0, -1.2)
	pup.global_position = plaza + Vector3(0.6, 0, -1.5)
	StoryFigure.face(captain, plaza)
	StoryFigure.face(pup, plaza)
	_spot(&"captain", captain.global_position, &"heart", "ui.action.talk", &"", 1.9)
	# Corte para a praca (o farol fica a ~55 m): o trio chega junto para a festa.
	if main.controlled_node != null and main.controlled_node.global_position.distance_to(plaza) > 8.0:
		_cut(func() -> void: main._place_trio_at(plaza + Vector3(-1.0, 0, 1.2)))


func _dinghy_docked() -> void:
	var d := _dinghy()
	if d != null:
		d.global_position = DINGHY_DOCKED
		d.rotation.y = PI / 2.0


# ---------------------------------------------------------------- estado

func refresh() -> void:
	super.refresh()
	if main == null or main.current == null or _root == null or not mission_id in LATE:
		return
	var step: StringName = main.current.current_step().get("id", &"")
	match mission_id:
		&"M5":
			match step:
				&"feathers":
					_enable(StringName("feather_%d" % (_feather_next + 1)), true)
				&"compass":
					_enable(&"vane", true)
				&"fish":
					var up := _on_roof()
					_enable(&"crates_climb", not up)
					_enable(&"fish", up)
		&"M6":
			match step:
				&"board":
					_enable(&"board", true)
				&"buoys":
					_enable(&"buoy_a" if not spots[&"buoy_a"].get_meta(&"passed", false) else &"buoy_b", true)
				&"approach":
					_enable(&"approach", true)
				&"rope":
					_enable(&"rope", true)
			# Emblema da baia so com o barco e depois das boias (nunca chama quem esta no cais para a agua).
			if spots.has(&"emb_m6_bay"):
				(spots[&"emb_m6_bay"] as Ep01Interactable).enabled = sailing and step in [&"approach", &"rope"]
		&"M7":
			match step:
				&"lens":
					_enable(&"lens", true)
				&"climb":
					var up := _on_gallery()
					_enable(&"stair_climb", not up)
					_enable(&"pup", up)
				&"aim":
					_enable(&"aim", true)
		&"M8":
			_enable(&"captain", true)


func _on_roof() -> bool:
	var a := _actor()
	return a != null and a.global_position.y > 2.4 and a.global_position.distance_to(_mk(&"M5_ShedRoof")) < 2.5


func _on_gallery() -> bool:
	var a := _actor()
	return a != null and a.global_position.y > 7.0 and a.global_position.distance_to(_mk(&"M7_Gallery")) < 2.5


func help_target() -> Node3D:
	if mission_id == &"M6" and main.current != null and main.current.current_step().get("id", &"") == &"buoys":
		for k: StringName in [&"buoy_a", &"buoy_b"]:
			if (spots[k] as Ep01Interactable).enabled:
				return spots[k] as Node3D
	return super.help_target()


func emblem_for(member: StringName) -> Ep01Interactable:
	var e := super.emblem_for(member)
	if e != null and e.action_id == &"emb_m6_bay" and not (sailing and e.enabled):
		return null
	return e


func _on_spot(id: StringName, actor: Node3D) -> void:
	var it := spots.get(id) as Ep01Interactable
	if it == null or it.get_meta(&"emblem", false) or not mission_id in LATE:
		super._on_spot(id, actor)
		return
	match id:
		&"feather_1", &"feather_2", &"feather_3", &"feather_4":
			FeedbackFx.pulse(world, it.global_position)
			_feather_next += 1
			if main.notify_mission(&"feather_followed") and _feather_next == 1:
				main.say("ep01.street.tracker.feathers")
		&"vane":
			_examine(actor, it)
			if main.notify_mission(&"compass_read"):
				main.say("ep01.street.pilot.compass_west")
				FeedbackFx.ring(world, points[&"CratesBase"] + Vector3(0, 0.2, 0))
		&"crates_climb":
			await _hop_chain(actor as MemberActor, [_mk(&"M5_Crates"), _mk(&"M5_Awning"), _mk(&"M5_ShedRoof")])
		&"fish":
			await _recover_fish(actor as MemberActor)
		&"board":
			_board()
		&"buoy_a", &"buoy_b":
			it.set_meta(&"passed", true)
			FeedbackFx.ring(world, it.global_position + Vector3(0, 0.6, 0))
			if main.notify_mission(&"buoy_passed") and id == &"buoy_a":
				main.say("ep01.bay.pilot.slow")
		&"approach":
			await _assisted_docking()
		&"rope":
			await _throw_rope_and_tow(actor as MemberActor)
		&"lens":
			_examine(actor, it)
			var lens := world.props.get("wv3_lens") as Node3D
			if lens != null:
				_fly(lens, lens.global_position + Vector3(0, 0.6, 0), 0.3)
				lens.create_tween().tween_callback(func() -> void: lens.visible = false).set_delay(0.4)
			if main.notify_mission(&"lens_found"):
				main.say("ep01.lighthouse.tracker.lens")
		&"stair_climb":
			await _hop_chain(actor as MemberActor, [_mk(&"M7_StairStep"), _mk(&"M7_StairBase"), _mk(&"M7_Landing_1"),
				_mk(&"M7_Landing_2"), _mk(&"M7_Landing_3"), _mk(&"M7_Gallery")])
		&"pup":
			await _rescue_pup(actor as MemberActor)
		&"aim":
			_aim_next(actor as MemberActor)
		&"captain":
			_examine(actor, it)
			main.say("ep01.festival.captain.thanks")
			main.notify_mission(&"captain_thanked")
	refresh()


# ---------------------------------------------------------------- M5

func _recover_fish(a: MemberActor) -> void:
	if a == null:
		return
	_set_busy(true)
	# A gaivota foge (sobe e vai para o mar) e solta o peixe no telhado.
	if _gull != null:
		_fish = _gull.get_node_or_null("Fish") as Node3D
		if _fish != null:
			var at := _fish.global_position
			_gull.remove_child(_fish)
			_root.add_child(_fish)
			_fish.global_position = at
			_fish.visible = true
		if "carrying_fish" in _gull:
			_gull.set("carrying_fish", false)
		Ep01V3Pieces.play(_gull, &"flee")
		var tw := _gull.create_tween()
		tw.tween_property(_gull, "global_position", _gull.global_position + Vector3(6.0, 7.0, 8.0), 1.6) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tw.tween_callback(_gull.hide)
	if _fish != null:
		_fly(_fish, a.global_position + Vector3(0, 0.9, 0), 0.3)
	main.say("ep01.street.climber.fish_got")
	# Baixa o peixe na corda ate a rua, onde o Rastro e a Leme esperam.
	_rope = Ep01V3Pieces.rope(_root)
	var down: Vector3 = (points[&"CratesBase"] as Vector3) + Vector3(0.6, 0.1, 0.4)
	Ep01V3Pieces.aim_rope(_rope, a.global_position + Vector3(0, 0.9, 0), down)
	if _fish != null:
		var tw2 := _fish.create_tween()
		tw2.tween_interval(0.35)
		tw2.tween_property(_fish, "global_position", down, 0.9).set_trans(Tween.TRANS_QUAD)
	FeedbackFx.sparkle(world, down)
	main.say("ep01.street.climber.sees_boat")
	# Desce antes de concluir: a missao seguinte desmonta esta (e cortaria a cadeia de saltos no meio).
	await _hop_chain(a, [_mk(&"M5_Awning"), _mk(&"M5_Crates"), points[&"CratesBase"]])
	if not is_inside_tree():
		return
	main.notify_mission(&"fish_recovered")


# ---------------------------------------------------------------- M6

## Folga do casco (m) para o BoatActor: raios na camada 1 (inclui as paredes WaterLimits, que contem o barco na bacia)
## a partir do centro, da proa e da popa. Descontado o raio do casco. Travado (atracado/rebocando): sem folga minima.
func boat_clearance(pos: Vector3) -> float:
	var boat := main.boat
	if boat.input_locked:
		return 1000.0
	var space := world.get_world_3d().direct_space_state
	var f := boat.forward()
	var best := 1000.0
	# Centro (meia boca do casco) e proa (estreita). A popa encosta no cais na atracacao (fica de fora de proposito).
	for o: Array in [[Vector3.ZERO, HULL], [f * 2.3, BOW_HULL]]:
		var p := pos + (o[0] as Vector3)
		p.y = pos.y + 0.3
		for i in 8:
			var d := Vector3(sin(i * TAU / 8.0), 0, cos(i * TAU / 8.0))
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p, p + d * 7.0, 1))
			if not hit.is_empty():
				best = minf(best, p.distance_to(hit.position) - float(o[1]))
	return best


func _board() -> void:
	var boat := main.boat
	for m: StringName in [&"pilot", &"climber"]:
		var a := main.actors[m] as MemberActor
		a.ride(boat, BoatActor.CREW[m])
	(main.actors[&"pilot"] as MemberActor).set_accessory(&"Acc_LifeVest", true)
	sailing = true
	main.set_controlled(boat)
	main.camera_rig.set_view(BOAT_VIEW, boat.heading, BOAT_LOOK_Y)
	main.camera_rig.orbit_enabled = false
	main.camera_rig.follow(boat, true)
	main.say("ep01.bay.pilot.start")
	main.notify_mission(&"boat_boarded")


func _end_sailing() -> void:
	if main == null:
		return
	if sailing:
		sailing = false
		main.boat.input_locked = false
		main.camera_rig.orbit_enabled = true
		main.camera_rig.set_low_view(main.camera_rig.yaw)


func _process(delta: float) -> void:
	if main != null and main.controlled_node == main.boat and sailing:
		main.camera_rig.yaw = lerp_angle(main.camera_rig.yaw, main.boat.heading, clampf(delta * 2.5, 0.0, 1.0))


## Atracacao assistida: nos metros finais o barco desliza sozinho ate encostar no bote (sem reinicio, sem castigo).
func _assisted_docking() -> void:
	var boat := main.boat
	_set_busy(true)
	boat.input_locked = true
	boat.speed = 0.0
	var to := _mk(&"M6_DinghyApproach")
	var dinghy := _mk(&"M6_Dinghy")
	var d := dinghy - to
	var want := atan2(-d.x, -d.z)
	var from_heading := boat.heading
	var tw := boat.create_tween().set_parallel(true)
	tw.tween_property(boat, "global_position", Vector3(to.x, boat.global_position.y, to.z), DOCK_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(t: float) -> void: boat.heading = lerp_angle(from_heading, want, t), 0.0, 1.0, DOCK_TIME)
	await tw.finished
	if not is_inside_tree():
		return
	(spots[&"rope"] as Ep01Interactable).global_position = boat.global_position + boat.forward() * 1.2
	_set_busy(false)
	main.notify_mission(&"dinghy_reached")


func _throw_rope_and_tow(a: MemberActor) -> void:
	var boat := main.boat
	var d := _dinghy()
	_set_busy(true)
	if a != null:
		a.face_now(_mk(&"M6_Dinghy"))
		if a.model != null and a.model.has_animation(&"point"):
			a.play_action(&"point")
	var bow := boat.global_position + boat.forward() * 2.6 + Vector3(0, 0.6, 0)
	var bow_node := boat.find_child("RopeBow", true, false) as Node3D
	if bow_node != null:
		bow = bow_node.global_position
	_rope = Ep01V3Pieces.rope(_root)
	var tie := (d.global_position if d != null else _mk(&"M6_Dinghy")) + Vector3(0, 0.3, 0)
	Ep01V3Pieces.aim_rope(_rope, bow, tie)
	FeedbackFx.sparkle(world, tie)
	main.say("ep01.bay.climber.throw_rope")
	main.say("ep01.bay.captain.thanks_tow")
	# Reboque curto: o barco recua e o bote desencalha atras dele; depois corte para o cais (a volta inteira nao aparece).
	var back := boat.global_position - boat.forward() * 4.0
	var tw := boat.create_tween().set_parallel(true)
	tw.tween_property(boat, "global_position", back, TOW_TIME).set_trans(Tween.TRANS_SINE)
	if d != null:
		tw.tween_property(d, "global_position", d.global_position - boat.forward() * 3.0, TOW_TIME).set_trans(Tween.TRANS_SINE)
	var follow := func(_t: float) -> void:
		if is_instance_valid(_rope) and bow_node != null and d != null:
			Ep01V3Pieces.aim_rope(_rope, bow_node.global_position, d.global_position + Vector3(0, 0.3, 0))
		if d != null and captain.visible:
			captain.global_position = d.global_position + Vector3(0, 0.25, 0)
	tw.tween_method(follow, 0.0, 1.0, TOW_TIME)
	await tw.finished
	if not is_inside_tree():
		return
	await _cut(_land_on_dock)
	if not is_inside_tree():
		return
	main.say("ep01.bay.captain.pup_lighthouse")
	_set_busy(false)
	main.notify_mission(&"rope_thrown")


## Volta do reboque (dentro do corte): barco no cais, bote amarrado ao lado, trio no cais junto do capitao.
func _land_on_dock() -> void:
	var boat := main.boat
	var berth := world.marker(&"M6_BoatStart")
	boat.place(berth.global_position, berth.global_rotation.y)
	_dinghy_docked()
	if is_instance_valid(_rope):
		_rope.queue_free()
	_rope = null
	var land := points[&"DockLanding"] as Vector3
	for m: StringName in [&"pilot", &"climber"]:
		(main.actors[m] as MemberActor).dismount(land + (Ep01V3Main.TRIO_OFFSETS[m] as Vector3) + Vector3(0, 0.05, 0))
	(main.actors[&"tracker"] as MemberActor).teleport(land + Vector3(0, 0.05, 0))
	(main.actors[&"pilot"] as MemberActor).set_accessory(&"Acc_LifeVest", false)
	captain.visible = true
	captain.global_position = _mk(&"M8_CaptainDock")
	StoryFigure.face(captain, land)
	sailing = false
	main.camera_rig.orbit_enabled = true
	boat.input_locked = false
	main.set_controlled(main.actors[main.active_member])
	main.camera_rig.set_low_view(main.camera_rig.yaw)
	main.camera_rig.follow(main.controlled_node, true)


## Corte curto com escurecer/clarear (PROVISORIO). Sem movimento reduzido: o mesmo corte, so mais rapido.
func _cut(during: Callable) -> void:
	var t := FADE_TIME * (0.5 if Options.reduced_motion() else 1.0)
	var tw := _fade.create_tween()
	tw.tween_property(_fade, "color:a", 1.0, t)
	await tw.finished
	if not is_inside_tree():
		return
	during.call()
	var tw2 := _fade.create_tween()
	tw2.tween_property(_fade, "color:a", 0.0, t)
	await tw2.finished


# ---------------------------------------------------------------- M7

func _rescue_pup(a: MemberActor) -> void:
	if a == null:
		return
	_set_busy(true)
	a.face_now(pup.global_position)
	var lens_on := world.props.get("wv3_lens") as Node3D
	if lens_on != null:
		lens_on.visible = false
	world.set_beam(true)
	if world.lantern != null:
		FeedbackFx.sparkle(world, world.lantern.global_position + Vector3(0, 0.6, 0))
	main.say("ep01.lighthouse.climber.pup_safe")
	# O filhote desce na corda ate o pe da escada.
	var foot := points[&"StairFoot"] as Vector3
	_rope = Ep01V3Pieces.rope(_root)
	Ep01V3Pieces.aim_rope(_rope, a.global_position + Vector3(0, 0.9, 0), foot + Vector3(0.8, 0.2, 0.4))
	var tw := pup.create_tween()
	tw.tween_property(pup, "global_position", foot + Vector3(0.8, 0.0, 0.4), 1.2).set_trans(Tween.TRANS_QUAD)
	_set_busy(false)
	main.notify_mission(&"pup_rescued")
	await _hop_chain(a, [_mk(&"M7_Landing_3"), _mk(&"M7_Landing_2"), _mk(&"M7_Landing_1"), _mk(&"M7_StairBase"),
		_mk(&"M7_StairStep"), points[&"StairFoot"]])
	if is_instance_valid(_rope):
		_rope.queue_free()


## Bussola da Leme: cada aperto gira a lanterna para o proximo barquinho apagado e o acende (4 no total).
func _aim_next(a: MemberActor) -> void:
	if _lit >= FESTA_BOATS.size():
		return
	if a != null:
		a.face_now(_mk(FESTA_BOATS[_lit]))
		if a.model != null and a.model.has_animation(&"point"):
			a.play_action(&"point")
	if _lit == 0:
		main.say("ep01.lighthouse.pilot.aim")
	var i := _lit
	_aim_lantern(i, 0.6)
	Ep01V3Pieces.light_boat_icon(_icons[i], true)
	FeedbackFx.ring(world, _mk(FESTA_BOATS[i]) + Vector3(0, 1.4, 0))
	_lit += 1
	main.notify_mission(&"boat_lit")
	if _lit == FESTA_BOATS.size():
		main.say("ep01.lighthouse.pup.horn")
		if pup != null:
			var cv := StoryFigure.visual(pup)
			if cv != null and cv.has_animation(&"wave"):
				cv.play(&"wave")


## Lanterna do farol (frente = -Z local) virada para o barquinho `i`.
func _aim_lantern(i: int, t: float) -> void:
	var lan := world.lantern
	if lan == null:
		return
	var d := _mk(FESTA_BOATS[i]) - lan.global_position
	var yaw := atan2(-d.x, -d.z)
	if t <= 0.0:
		lan.rotation.y = yaw
	else:
		var from := lan.rotation.y
		lan.create_tween().tween_method(func(k: float) -> void: lan.rotation.y = lerp_angle(from, yaw, k), 0.0, 1.0, t)
	if _root != null:
		for c in _root.find_children("Needle", "", true, false):
			(c as Node3D).rotation.y = yaw


func lantern_yaw_to(i: int) -> float:
	var d := _mk(FESTA_BOATS[i]) - world.lantern.global_position
	return atan2(-d.x, -d.z)


func lit_count() -> int:
	return _lit


## Emblemas achados por heroi (tela final): heroi -> [achados, total].
func emblems_by_hero(missions: Array[Mission]) -> Dictionary:
	var out := {&"tracker": [0, 0], &"climber": [0, 0], &"pilot": [0, 0]}
	for m in missions:
		for e: StringName in m.emblems:
			var h: StringName = EMBLEM_HERO.get(e, &"")
			if out.has(h):
				var row: Array = out[h]
				row[1] += 1
				if e in m.found_emblems:
					row[0] += 1
	return out
