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
## G19: corda baixada mao a mao: lower_rope desce 0,333 m por ciclo; tocado LOWER_SPEED vezes mais rapido. O peixe
## (2,9 m) leva ~2,9 s e o filhote (5,5 m) ~4 s: excecao declarada a regra de 0,6-1,5 s (como o reboque).
const LOWER_MPS := 0.3333
const LOWER_SPEED := 3.0
## Estaca do canto oeste-norte do cais (a da amarra vazia, wv3_world.dock_loose_rope): voltas de corda do mundo com raio
## ~0,21 m entre 0,39 e 0,61 m (medido nas pecas wv2_dock#230-232).
const MOORING_POST := Vector3(-7.6, 0.0, -3.12)
const MOORING_RING_Y := 0.5
const MOORING_RING_R := 0.2
## Lente (wv3_lens: aro deitado no plano XZ, centro a 0,04 m do pivo): de pe, virada para a frente, nas maos e no encaixe.
const LENS_UPRIGHT := Basis(Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0, -1, 0))
const LENS_CENTER := Vector3(0, 0.04, 0)
## Encaixe a esta altura acima do piso da galeria (mao erguida do Pico no place_high: 0,81 m) e o Pico a esta distancia.
const LENS_HEIGHT := 0.81
const LENS_REACH := 0.13

var _keep: Node3D
var _icons: Array[Sprite3D] = []
var _feather_next: int = 0
var _lit: int = 0
var _rope: Node3D
var _gull: Node3D
var _fish: Node3D
## G25: a Dona Amora espera o peixe na rua do M5; folga (m) do peixe contra o chao quando a corda o pousou na rua.
var amora: Node3D
var fish_street_gap: float = INF
var captain: Node3D
var pup: Node3D
var _dinghy_home: Transform3D
var _fade: ColorRect
var sailing: bool = false
var _hand_compass: Node3D


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
	# G6: 0,6 m para -z: a rosa dos ventos (raio 0,45) ficava sob a base da casa do faroleiro (x 27-31, z > -19) e a
	# agulha entrava 3 cm nela. O ponto de acao `aim` usa o mesmo ponto.
	points[&"Compass"] = Vector3(st.x, st.y, st.z) + out.normalized() * 2.2 + Vector3(-1.0, 0, -0.6)
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
		if is_instance_valid(_hand_compass) and carried != _hand_compass:
			_hand_compass.global_transform = rest_xf(_hand_compass, _compass_spot(), 0.0)


## G19: onde a bussola de mao descansa: em cima da rosa dos ventos (disco de 0,06 m), ao lado da agulha.
func _compass_spot() -> Vector3:
	return (points[&"Compass"] as Vector3) + Vector3(0.24, 0.06, 0.0)


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
	amora = null
	fish_street_gap = INF
	_hand_compass = null
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
	# G25: a Dona Amora espera o peixe na rua, alem do ponto onde a corda o pousa (longe dos caixotes).
	amora = StoryFigure.spawn(_root, "amora_model", "Amora")
	amora.global_position = amora_point()
	StoryFigure.face(amora, fish_down_point())


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
	_hand_compass = Ep01V3Pieces.final(_root, "hand_compass", "HandCompass")
	if _hand_compass != null:
		_hand_compass.global_transform = rest_xf(_hand_compass, _compass_spot(), 0.0)
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
		_cut(func() -> void: main._place_trio_at(plaza + Vector3(1.0, 0, 1.2)))   # F2: longe da borda do chafariz


func _dinghy_docked() -> void:
	var d := _dinghy()
	if d != null:
		d.global_position = DINGHY_DOCKED
		d.rotation.y = PI / 2.0
		_tie_dinghy(d)


## G19 (M6): o bote fica amarrado no cais depois do reboque: a corda sai das voltas de corda que ja existem na estaca do
## canto do cais (a amarra vazia do M1, wv3_world.dock_loose_rope) ate a proa do bote. Fica no `Keep` (M7, M8, retomada).
func _tie_dinghy(d: Node3D) -> void:
	var line := _keep.get_node_or_null(^"RopeDinghyLine") as Node3D
	if line == null:
		line = Ep01V3Pieces.rope(_keep, "RopeDinghyLine")
	var bow := d.global_position + d.global_basis.z.normalized() * -1.1 + Vector3(0, 0.45, 0)
	var knot := Vector3(MOORING_POST.x, MOORING_RING_Y, MOORING_POST.z)
	knot += (Vector3(bow.x, knot.y, bow.z) - knot).normalized() * MOORING_RING_R
	Ep01V3Pieces.aim_rope(line, knot, bow)


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
		await super._on_spot(id, actor)
		return
	match id:
		&"feather_1", &"feather_2", &"feather_3", &"feather_4":
			FeedbackFx.pulse(world, it.global_position)
			_feather_next += 1
			if main.notify_mission(&"feather_followed") and _feather_next == 1:
				main.say("ep01.street.tracker.feathers")
		&"vane":
			_examine(actor, it, [&"point"])
			if main.notify_mission(&"compass_read"):
				main.say("ep01.street.pilot.compass_west")
				FeedbackFx.ring(world, points[&"CratesBase"] + Vector3(0, 0.2, 0))
		&"crates_climb":
			await _hop_chain(actor as MemberActor, [_mk(&"M5_Crates"), _mk(&"M5_Awning"), _mk(&"M5_ShedRoof")])
		&"fish":
			await _recover_fish(actor as MemberActor)
		&"board":
			await _board()
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
			await _act_find_lens(actor as MemberActor)
			if main.notify_mission(&"lens_found"):
				main.say("ep01.lighthouse.tracker.lens")
		&"stair_climb":
			var pico := actor as MemberActor
			var s := _act_begin(pico)
			if carried != null and carried.get_meta(&"lens", false) and carrier != pico:
				if not await _give(carrier, pico, s):
					_act_end(pico, s)
					return
			if not await _climb_chain(pico, [_mk(&"M7_StairStep"), _mk(&"M7_StairBase"), _mk(&"M7_Landing_1"),
					_mk(&"M7_Landing_2"), _mk(&"M7_Landing_3"), _mk(&"M7_Gallery")], s):
				_act_end(pico, s)
				return
			_act_end(pico, s)
		&"pup":
			await _rescue_pup(actor as MemberActor)
		&"aim":
			_aim_next(actor as MemberActor)
		&"captain":
			_examine(actor, it, [&"wave", &"point"])
			var cv := StoryFigure.visual(captain)
			if cv != null and cv.has_animation(&"thanks"):
				cv.play(&"thanks")
			main.say("ep01.festival.captain.first_lantern")
			main.notify_mission(&"captain_thanked")
	refresh()


# ---------------------------------------------------------------- M5

func _recover_fish(a: MemberActor) -> void:
	if a == null:
		return
	var s := _act_begin(a)
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
		# G19: o peixe cai na telha a frente do Pico (queda, nao voo), ele abaixa e pega (pick_up)
		var roof := _floor_at(a.global_position + a.facing() * 0.4 + Vector3(0, 0.3, 0))
		var land_xf := rest_xf(_fish, roof, 30.0)
		var f0 := _fish.global_position
		var q0 := _fish.global_basis.get_rotation_quaternion()
		if not await _over(0.3, s, func(k: float) -> void:
			if is_instance_valid(_fish):
				_fish.global_transform = Transform3D(Basis(q0.slerp(land_xf.basis.get_rotation_quaternion(), k)),
					f0.lerp(land_xf.origin, k * k))):
			_act_end(a, s)
			return
		a.face_now(_fish.global_position)
		var L := _clip(a, &"pick_up", 1.0)
		if not await _wait(L * 0.5, s):
			_act_end(a, s)
			return
		_take(a, _fish, true, Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3.ZERO))
		if not await _wait(L * 0.5, s):
			_act_end(a, s)
			return
	main.say("ep01.street.climber.fish_got")
	# Baixa o peixe na corda ate a rua (lower_rope): a corda sai da mao e o peixe desce na ponta dela.
	var down := fish_down_point()
	if not await _lower_on_rope(a, _fish, down, s):
		_act_end(a, s)
		return
	if is_instance_valid(_fish):
		fish_street_gap = _fish.global_position.y + piece_low(_fish, _fish.global_basis) - _floor_y(_fish.global_position)
	FeedbackFx.sparkle(world, down)
	main.say("ep01.street.climber.sees_boat")
	# Desce escalando antes de concluir (a missao seguinte desmonta esta).
	if not await _climb_chain(a, [_mk(&"M5_Awning"), _mk(&"M5_Crates"), points[&"CratesBase"]], s):
		_act_end(a, s)
		return
	if not await _return_fish(a, s):
		_act_end(a, s)
		return
	_act_end(a, s)
	main.notify_mission(&"fish_recovered")


## G25: ponto da rua onde a corda pousa o peixe, e onde a Dona Amora espera (1,4 m alem, longe dos caixotes).
func fish_down_point() -> Vector3:
	return _floor_at((points[&"CratesBase"] as Vector3) + Vector3(0.6, 0.1, 0.4))


func amora_point() -> Vector3:
	var down := fish_down_point()
	var away := Vector3(down.x - (points[&"CratesBase"] as Vector3).x, 0.0, down.z - (points[&"CratesBase"] as Vector3).z)
	return _floor_at(down + away.normalized() * 1.4 + Vector3(0, 0.3, 0))


## G25: o Pico pega o peixe na rua (pick_up), leva ate a Dona Amora e entrega (place_low): no alto do gesto o peixe passa
## para a mao direita dela, que agradece (thanks). Sem a Amora (ou sem peixe) nao faz nada.
func _return_fish(a: MemberActor, s: int) -> bool:
	if not is_instance_valid(_fish) or amora == null or not is_instance_valid(amora):
		return true
	var to_fish := Vector3(_fish.global_position.x - a.global_position.x, 0.0, _fish.global_position.z - a.global_position.z)
	if to_fish.length() > 0.55:
		if not await _step_walk(a, a.global_position + to_fish.normalized() * (to_fish.length() - 0.4), s):
			return false
	a.face_now(_fish.global_position)
	var L := _clip(a, &"pick_up", 1.0)
	if not await _wait(L * 0.5, s):
		return false
	_take(a, _fish, true, Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3.ZERO))
	if not await _wait(L * 0.5, s):
		return false
	var front := -amora.global_basis.z
	var meet := amora.global_position + Vector3(front.x, 0.0, front.z).normalized() * 0.6
	meet.y = a.global_position.y
	if not await _step_walk(a, meet, s):
		return false
	a.face_now(amora.global_position)
	StoryFigure.face(amora, a.global_position)
	var P := _clip(a, &"place_low", 1.3)
	if not await _wait(P * 0.45, s):
		return false
	var hand := _figure_hand(amora)
	var piece := _fish
	still(piece)
	piece.reparent(hand, false)
	piece.transform = Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3.ZERO)
	piece.set_meta(&"in_hand", &"vendor")
	piece.set_meta(&"returned_to", &"vendor")
	carried = null
	carrier = null
	a.hands = &""
	hand_log.append({"piece": piece, "member": &"vendor", "two": false})
	StoryFigure.once(amora, &"thanks")
	FeedbackFx.sparkle(world, amora.global_position + Vector3(0, 1.2, 0))
	if not await _wait(P * 0.55, s):
		return false
	_rest(a)
	return true


## Ponto de pega na mao direita de um figurante (BoneAttachment3D no osso hand.R; sem esqueleto, o proprio figurante).
func _figure_hand(fig: Node3D) -> Node3D:
	var cv := StoryFigure.visual(fig)
	var sk := cv.skeleton() if cv != null else null
	if sk == null or sk.find_bone("hand.R") < 0:
		return fig
	var att := sk.get_node_or_null(^"G25_HandR") as Node3D
	if att == null:
		var b := BoneAttachment3D.new()
		b.name = "G25_HandR"
		b.bone_name = "hand.R"
		sk.add_child(b)
		att = b
	return att


## G19 (M5/M7): baixa `thing` na corda, mao a mao (lower_rope em laco). A corda vai da mao do Pico (a ponta fica presa no
## alto) ate o objeto, que desce a LOWER_MPS e termina apoiado em `down` (chao). Fica a corda pendurada.
func _lower_on_rope(a: MemberActor, thing: Node3D, down: Vector3, serial: int) -> bool:
	if thing == null or not is_instance_valid(thing):
		return true
	var top := _grip(a, true).global_position
	if carried == thing:
		thing.reparent(_root, true)
		thing.remove_meta(&"in_hand")
		carried = null
		carrier = null
		a.hands = &""
	_rope = Ep01V3Pieces.rope(_root)
	var from := thing.global_position
	var end_xf := rest_xf(thing, down, rad_to_deg(thing.global_rotation.y))
	var hang := Vector3(0, maxf(0.05, from.y - (thing.global_position.y + piece_low(thing, thing.global_basis))), 0)
	_clip(a, &"lower_rope", LOWER_SPEED)
	var ok := await _over(from.distance_to(end_xf.origin) / (LOWER_MPS * LOWER_SPEED), serial, func(k: float) -> void:
		if is_instance_valid(thing):
			thing.global_position = from.lerp(end_xf.origin, k)
			if is_instance_valid(_rope):
				Ep01V3Pieces.aim_rope(_rope, top, thing.global_position + hang * 0.0 + Vector3(0, 0.12, 0)))
	if not ok:
		return false
	thing.global_transform = end_xf
	if is_instance_valid(_rope):
		Ep01V3Pieces.aim_rope(_rope, top, thing.global_position + Vector3(0, 0.12, 0))
	_rest(a)
	return true


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
	# G19 (sem clipe board_step): a Leme e depois o Pico dao um pulinho do cais para o conves (clipe `jump`), cada um no
	# lugar dele; so entao embarcam (antes iam para o barco na hora).
	for m: StringName in [&"pilot", &"climber"]:
		var a := main.actors[m] as MemberActor
		if a.global_position.distance_to(boat.to_global(BoatActor.CREW[m])) < 4.0:
			var s := _act_begin(a)
			if not await _hop_to(a, boat.to_global(BoatActor.CREW[m]), 0.45, 0.3, s):
				_act_end(a, s)
				return
			_act_end(a, s)
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
	super._process(delta)
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
	# G19: a Leme gira o leme para o lado da curva durante a atracacao (steer_left/steer_right)
	var pilot := main.actors[&"pilot"] as MemberActor
	var turn: StringName = &"steer_left" if wrapf(want - from_heading, -PI, PI) > 0.0 else &"steer_right"
	if pilot != null and pilot.model != null and pilot.model.has_animation(turn):
		pilot.play_action(turn, pilot.model.animation_length(turn) / DOCK_TIME)
	await tw.finished
	if not is_inside_tree():
		return
	(spots[&"rope"] as Ep01Interactable).global_position = boat.global_position + boat.forward() * 1.2
	_set_busy(false)
	main.notify_mission(&"dinghy_reached")


func _throw_rope_and_tow(a: MemberActor) -> void:
	var boat := main.boat
	var d := _dinghy()
	var s := _act_begin(a)
	var bow := boat.global_position + boat.forward() * 2.6 + Vector3(0, 0.6, 0)
	var bow_node := boat.find_child("RopeBow", true, false) as Node3D
	if bow_node != null:
		bow = bow_node.global_position
	var tie := (d.global_position if d != null else _mk(&"M6_Dinghy")) + Vector3(0, 0.3, 0)
	# G19: o Pico gira o rolo de corda e lanca (throw_rope); a ponta sai da mao no instante do lancamento (0,74 s do
	# clipe) e voa em arco ate o bote; a outra ponta fica presa na proa.
	_rope = Ep01V3Pieces.rope(_root)
	if a != null:
		a.face_now(_mk(&"M6_Dinghy"))
		if _rope.get_meta(&"final_rope", false):
			_rope.set("coiled", true)
			_take(a, _rope, false, Transform3D(Basis(), Vector3(0, -0.08, 0)))
		var L := _clip(a, &"throw_rope", 1.0)
		if not await _wait(L * (0.74 / 1.2), s):
			_act_end(a, s)
			return
		var hand := _rope.global_position
		_rope.reparent(_root, true)
		_rope.remove_meta(&"in_hand")
		carried = null
		carrier = null
		a.hands = &""
		if _rope.get_meta(&"final_rope", false):
			_rope.set("coiled", false)
		if not await _over(0.4, s, func(k: float) -> void:
			if is_instance_valid(_rope):
				var e := hand.lerp(tie, k)
				e.y += 1.2 * 4.0 * k * (1.0 - k)
				Ep01V3Pieces.aim_rope(_rope, bow, e)):
			_act_end(a, s)
			return
	Ep01V3Pieces.aim_rope(_rope, bow, tie)
	FeedbackFx.sparkle(world, tie)
	var cv := StoryFigure.visual(captain)
	if cv != null and cv.has_animation(&"thanks"):
		cv.play(&"thanks")
	main.say("ep01.bay.climber.throw_rope")
	main.say("ep01.bay.captain.thanks_tow")
	# no reboque o Pico puxa a corda (pull_rope) e a Leme pilota (steer_*)
	if a != null:
		_clip(a, &"pull_rope", 1.6 / TOW_TIME)
	var pilot := main.actors[&"pilot"] as MemberActor
	if pilot != null and pilot.model != null and pilot.model.has_animation(&"steer_left"):
		pilot.play_action(&"steer_left", pilot.model.animation_length(&"steer_left") / TOW_TIME)
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
		_act_end(a, s)
		return
	await _cut(_land_on_dock)
	if not is_inside_tree() or s != _hop_serial:
		_act_end(a, s)
		return
	main.say("ep01.bay.captain.pup_lighthouse")
	_act_end(a, s)
	main.notify_mission(&"rope_thrown")


## Volta do reboque (dentro do corte): barco no cais, bote amarrado ao lado, trio no cais junto do capitao.
func _land_on_dock() -> void:
	var boat := main.boat
	var berth := world.marker(&"M6_BoatStart")
	boat.place(berth.global_position, berth.global_rotation.y)
	_dinghy_docked()
	# G19: a corda do reboque fica: amarrada da proa do bote a estaca do cais (antes sumia no corte)
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
	var s := _act_begin(a)
	# G19 (M7): a lente vai para o encaixe na parede do farol, junto a galeria (place_high), e a luz acende. A lanterna
	# fica 9 m acima da galeria (LANTERN_Y 16,75 x galeria 7,8), fora do alcance do Pico: o encaixe e o ponto alcancavel.
	if carried != null and carried.get_meta(&"lens", false) and carrier == a:
		var mxf := lens_mount_xf()
		var mount := Ep01V3Pieces.final(_root, "lens_mount", "LensMount")
		if mount != null:
			mount.global_transform = mxf
		var stand := mxf.origin + mxf.basis.z * (0.12 + LENS_REACH)
		stand.y = a.global_position.y
		if not await _step_walk(a, stand, s):
			_act_end(a, s)
			return
		a.face_now(mxf.origin)
		var L := _clip(a, &"place_high", 1.3)
		if not await _wait(L * 0.5, s):
			_act_end(a, s)
			return
		var lens := carried
		if not await _put(lens, _root, mxf * Transform3D(LENS_UPRIGHT, Vector3(0, 0, 0.12)) * Transform3D(Basis(), -LENS_CENTER), 0.1, s):
			_act_end(a, s)
			return
		lens.set_meta(&"mounted", true)
		if not await _wait(L * 0.5, s):
			_act_end(a, s)
			return
	world.set_beam(true)
	if world.lantern != null:
		FeedbackFx.sparkle(world, world.lantern.global_position + Vector3(0, 0.6, 0))
	main.say("ep01.lighthouse.climber.pup_safe")
	# O filhote desce na corda, mao a mao, ate o pe da escada (fica pendurado na ponta; sem pose de arnes no modelo).
	a.face_now(pup.global_position)
	var foot := points[&"StairFoot"] as Vector3
	if not await _lower_on_rope(a, pup, _floor_at(foot + Vector3(0.8, 0.3, 0.4)), s):
		_act_end(a, s)
		return
	main.notify_mission(&"pup_rescued")
	if not await _climb_chain(a, [_mk(&"M7_Landing_3"), _mk(&"M7_Landing_2"), _mk(&"M7_Landing_1"), _mk(&"M7_StairBase"),
			_mk(&"M7_StairStep"), points[&"StairFoot"]], s):
		_act_end(a, s)
		return
	_act_end(a, s)


## Encaixe da lente na parede da torre, na altura da mao erguida (place_high) acima do piso da galeria; frente = para fora.
func lens_mount_xf() -> Transform3D:
	var g := _mk(&"M7_Gallery")
	var center := Vector3(31.0, g.y, -24.0)
	var out := g - center
	out.y = 0.0
	out = out.normalized()
	var h := g + Vector3(0, LENS_HEIGHT, 0)
	var hit := world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(h, h - out * 3.0, 1))
	var wall: Vector3 = hit.position if not hit.is_empty() else h - out * 0.45
	return Transform3D(Basis(out.cross(Vector3.UP).normalized() * -1.0, Vector3.UP, out), wall)


## Rastro acha a lente: examina (inspect), abaixa e pega com as duas maos (pick_up); fica com ela (nada some).
func _act_find_lens(a: MemberActor) -> void:
	var src := world.props.get("wv3_lens") as Node3D
	if a == null or src == null:
		return
	var s := _act_begin(a)
	a.face_now(src.global_position)
	if not await _wait(_clip(a, &"inspect", 1.8), s):
		_act_end(a, s)
		return
	var L := _clip(a, &"pick_up", 1.0)
	if not await _wait(L * 0.5, s):
		_act_end(a, s)
		return
	# a lente do mundo vira peca da missao no mesmo lugar (o mundo do art3d nao e alterado; so a visibilidade)
	var lens := src.duplicate() as Node3D
	lens.name = "Lens"
	_root.add_child(lens)
	lens.global_transform = src.global_transform
	src.visible = false
	lens.set_meta(&"lens", true)
	_take(a, lens, true, Transform3D(LENS_UPRIGHT, -(LENS_UPRIGHT * LENS_CENTER)))
	if not await _wait(L * 0.5, s):
		_act_end(a, s)
		return
	_rest(a)
	_act_end(a, s)


## Entrega de mao para mao (Rastro -> Pico): os dois de frente, quem da estende (place_low) e a peca passa para as maos
## de quem recebe no alto do gesto.
func _give(from: MemberActor, to: MemberActor, serial: int) -> bool:
	if from == null or to == null or carried == null:
		return true
	var s2 := _act_begin(from)
	var meet := to.global_position + to.facing() * 0.55
	meet.y = from.global_position.y
	if from.global_position.distance_to(meet) > 4.0:
		from.teleport(to.global_position - to.facing() * 1.2)   # longe (fora do quadro): chega perto antes
	if not await _step_walk(from, meet, serial):
		_act_end(from, s2)
		return false
	from.face_now(to.global_position)
	to.face_now(from.global_position)
	var L := _clip(from, &"place_low", 1.3)
	if not await _wait(L * 0.45, serial):
		_act_end(from, s2)
		return false
	var piece := carried
	from.hands = &""
	_take(to, piece, true, piece.transform)
	if not await _wait(L * 0.55, serial):
		_act_end(from, s2)
		return false
	_rest(to)
	_act_end(from, s2)
	return true


## Bussola da Leme: cada aperto gira a lanterna para o proximo barquinho apagado e o acende (4 no total).
func _aim_next(a: MemberActor) -> void:
	if _lit >= FESTA_BOATS.size():
		return
	var s := _act_begin(a)
	# G19 (sem clipe hold_compass): a Leme pega a bussola de mao (pick_up) e segura a frente (carry_idle); cada "agir"
	# ela gira o corpo para o barquinho e a lanterna acompanha. No fim devolve a bussola a rosa (pick_up ao contrario).
	if a != null and _lit == 0 and carried == null and is_instance_valid(_hand_compass):
		a.face_now(_hand_compass.global_position)
		var L := _clip(a, &"pick_up", 1.0)
		if not await _wait(L * 0.5, s):
			_act_end(a, s)
			return
		_take(a, _hand_compass, true, _box_local(_hand_compass))
		if not await _wait(L * 0.5, s):
			_act_end(a, s)
			return
	if a != null:
		var want := _mk(FESTA_BOATS[_lit]) - a.global_position
		var y0 := a.visual().rotation.y
		var y1 := atan2(-want.x, -want.z)
		_rest(a)
		if not await _over(0.3, s, func(k: float) -> void:
			if is_instance_valid(a):
				a.visual().rotation.y = lerp_angle(y0, y1, k)):
			_act_end(a, s)
			return
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
		if a != null and carried == _hand_compass and _hand_compass != null:
			var L2 := _clip(a, &"pick_up", 1.2, true)
			if not await _wait(L2 * 0.5, s):
				_act_end(a, s)
				return
			if not await _put(_hand_compass, _root, rest_xf(_hand_compass, _compass_spot(), 0.0), 0.1, s):
				_act_end(a, s)
				return
			if not await _wait(L2 * 0.4, s):
				_act_end(a, s)
				return
	if not await _wait(0.6, s):   # a lanterna termina de girar (0,6 s)
		_act_end(a, s)
		return
	_act_end(a, s)


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
