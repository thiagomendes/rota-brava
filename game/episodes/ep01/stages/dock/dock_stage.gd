class_name DockStage
extends StageBase
## Etapa 1 - Investigar (Rastro): pegada de pata no banco do barco + pegada de bota na margem; escolher o destino.
## Cenografia toda em blocos PROVISORIOS. O progresso e decidido pelo EpisodeDirector (via ctx.submit).

const PAW := &"paw_print_bench"
const BOOT := &"boot_print_bank"
const GLOW_COLOR := Color("ffe27a")
const DARK := Color("3a2a22")
const REGION_X := 12.0
const REGION_Z_MIN := -6.0
const REGION_Z_MAX := 18.0

var _paw_it: Ep01Interactable
var _boot_it: Ep01Interactable
var _choose_it: Ep01Interactable
var _marks: Dictionary = {}   # clue_id -> Node3D raiz da marca
var _glows: Dictionary = {}   # clue_id -> Array[Node3D] (brilho: some ao examinar)
var _pulse: Tween
var _choice_active: bool = false
var _active: bool = false


func setup(main: Ep01Main) -> void:
	super.setup(main)
	_build_scenery()
	_build_marks()
	_paw_it = _make_interactable(&"examine_paw", "ui.action.examine", &"paw", &"tracker", Ep01Layout.BENCH_INTERACT_POS)
	_paw_it.triggered.connect(func(_a: Node3D) -> void: examine_clue(PAW))
	_boot_it = _make_interactable(&"examine_boot", "ui.action.examine", &"boot", &"tracker", Ep01Layout.BANK_PRINT_POS)
	_boot_it.triggered.connect(func(_a: Node3D) -> void: examine_clue(BOOT))
	_choose_it = _make_interactable(&"choose_destination", "ui.action.choose", &"notebook", &"tracker", Ep01Layout.RASTRO_START)
	_choose_it.triggered.connect(func(_a: Node3D) -> void: open_destination_choice())
	_choose_it.enabled = false


func _make_interactable(id: StringName, label: String, icon: StringName, who: StringName, pos: Vector3) -> Ep01Interactable:
	var it := Ep01Interactable.new()
	it.name = "Interact_" + String(id)
	it.action_id = id
	it.label_key = label
	it.icon = icon
	it.member = who
	it.radius = 2.0
	add_child(it)
	it.global_position = pos
	return it


# ---------- cenografia (provisoria) ----------

func _wall(wname: String, size: Vector3, pos: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = wname
	body.position = pos
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	shape.shape = bs
	body.add_child(shape)
	body.set_meta(Blocks.PROVISIONAL, true)
	add_child(body)


func _build_scenery() -> void:
	# Cais, margem, adereços, cabana, vegetacao e rochas: montagem modular do RB-04 (art3d), com o sombreador estilizado.
	var assembled := (load("res://episodes/ep01/world/harbor_slice.tscn") as PackedScene).instantiate()
	assembled.name = "DockAssembled"
	add_child(assembled)
	Stylize.apply(assembled)
	Stylize.trim_small_shadows(assembled)
	var dark_wood := Color("7a5636")
	# Moradores/multidao em blocos neutros (sem colisao)
	var spots: Array[Vector3] = [Vector3(5.5, 0, 12.5), Vector3(6.6, 0, 13.4), Vector3(7.6, 0, 12.2), Vector3(4.6, 0, 14.0), Vector3(8.2, 0, 14.2)]
	var tones: Array[Color] = [Color("9aa5ab"), Color("b9b3a4"), Color("8e9aa0"), Color("a9a2b4"), Color("b0b8a8")]
	for i in spots.size():
		Blocks.cylinder(self, "CrowdBody%d" % i, 0.28, 0.9, spots[i] + Vector3(0, 0.45, 0), tones[i])
		Blocks.sphere(self, "CrowdHead%d" % i, 0.22, spots[i] + Vector3(0, 1.1, 0), tones[i].lightened(0.2))
	# Limites (colisao): margem e extremos do cais; trilho visivel baixo na borda do cais
	_wall("FenceWest", Vector3(0.4, 3.0, 13.0), Vector3(-10.2, 1.5, 9.5))
	_wall("FenceEast", Vector3(0.4, 3.0, 13.0), Vector3(10.2, 1.5, 9.5))
	_wall("FenceSouth", Vector3(20.8, 3.0, 0.4), Vector3(0, 1.5, 16.2))
	_wall("DockEndWest", Vector3(0.4, 3.0, 6.0), Vector3(-8.2, 1.5, 0))
	_wall("DockEndEast", Vector3(0.4, 3.0, 6.0), Vector3(8.2, 1.5, 0))
	_wall("DockEdgeNorth", Vector3(16.8, 3.0, 0.4), Vector3(0, 1.5, -3.2))


func _build_marks() -> void:
	# Pata: filhos do barco, sobre o banco (referencial do barco).
	var top := Ep01Layout.BENCH_LOCAL + Vector3(0.0, 0.085, 0.0)
	var paw := Node3D.new()
	paw.name = "PawMark"
	paw.position = top
	paw.set_meta(Blocks.PROVISIONAL, true)
	ctx.boat.add_child(paw)
	var pg: Array[Node3D] = []
	pg.append(Blocks.cylinder(paw, "PawMarkGlow", 0.3, 0.01, Vector3(0, 0.0, 0), GLOW_COLOR, 1.6))
	var light := OmniLight3D.new()
	light.name = "PawMarkLight"
	light.light_color = GLOW_COLOR
	light.light_energy = 0.7
	light.omni_range = 1.8
	light.position = Vector3(0, 0.4, 0)
	paw.add_child(light)
	pg.append(light)
	_marks[PAW] = paw
	_glows[PAW] = pg
	# Bota: no chao da margem.
	var boot := Node3D.new()
	boot.name = "BootMark"
	boot.set_meta(Blocks.PROVISIONAL, true)
	add_child(boot)
	boot.global_position = Ep01Layout.BANK_PRINT_POS
	var bg: Array[Node3D] = []
	bg.append(Blocks.cylinder(boot, "BootMarkGlow", 0.75, 0.01, Vector3(0, 0.025, 0), GLOW_COLOR, 1.6))
	var bl := OmniLight3D.new()
	bl.name = "BootMarkLight"
	bl.light_color = GLOW_COLOR
	bl.light_energy = 0.7
	bl.omni_range = 2.2
	bl.position = Vector3(0, 0.6, 0)
	boot.add_child(bl)
	bg.append(bl)
	_marks[BOOT] = boot
	_glows[BOOT] = bg


# ---------- mundo ----------

func refresh_world() -> void:
	var found := ctx.director.clues_found
	for id: StringName in _marks:
		var done := found.has(id)
		for g: Node3D in _glows[id]:
			g.visible = not done
		(_marks[id] as Node3D).scale = Vector3.ONE
	var both := found.has(PAW) and found.has(BOOT)
	var in_stage := ctx.director.state == &"dock_investigation"
	_choose_it.enabled = both and in_stage
	_paw_it.enabled = in_stage
	_boot_it.enabled = in_stage
	if in_stage:
		ctx.boat.place(Ep01Layout.BOAT_DOCKED_POS, Ep01Layout.BOAT_DOCKED_HEADING)


func enter() -> void:
	_active = true
	if not ctx.hud.choice_made.is_connected(_on_choice_made):
		ctx.hud.choice_made.connect(_on_choice_made)
	var tracker: MemberActor = ctx.actors[&"tracker"]
	var climber: MemberActor = ctx.actors[&"climber"]
	if _outside_region(tracker.global_position):
		tracker.teleport(Ep01Layout.RASTRO_START)
	if _outside_region(climber.global_position):
		climber.teleport(tracker.global_position + Vector3(-2.5, 0, 0.5))
		climber.face_now(tracker.global_position)
	var pilot: MemberActor = ctx.actors[&"pilot"]
	pilot.ride(ctx.boat, BoatActor.CREW[&"pilot"])
	if ctx.director.state == &"dock_investigation":
		ctx.boat.place(Ep01Layout.BOAT_DOCKED_POS, Ep01Layout.BOAT_DOCKED_HEADING)
	refresh_world()


func exit() -> void:
	_active = false
	_choice_active = false
	if _pulse and _pulse.is_valid():
		_pulse.kill()


func _outside_region(p: Vector3) -> bool:
	return absf(p.x) > REGION_X or p.z < REGION_Z_MIN or p.z > REGION_Z_MAX


func control_started(_member: StringName) -> void:
	var lines := Ep01Content.lines(&"dock_investigation", "enter")
	if not lines.is_empty():
		ctx.hud.say_all(lines)


func camera_view() -> Dictionary:
	return {"offset": Vector3(0.0, 4.6, 6.2), "yaw": 0.0}


func gesture_hint(key: String) -> void:
	var found := ctx.director.clues_found
	var target: StringName = &""
	if key.contains("bench") and not found.has(PAW):
		target = PAW
	elif key.contains("boot") and not found.has(BOOT):
		target = BOOT
	elif not found.has(PAW):
		target = PAW
	elif not found.has(BOOT):
		target = BOOT
	if target == &"":
		return
	var node: Node3D = _marks[target]
	(ctx.actors[&"tracker"] as MemberActor).face_point(node.global_position)
	if _pulse and _pulse.is_valid():
		_pulse.kill()
	node.scale = Vector3.ONE
	_pulse = create_tween()
	_pulse.set_loops(3)
	_pulse.tween_property(node, "scale", Vector3(1.8, 1.0, 1.8), 0.35).set_trans(Tween.TRANS_SINE)
	_pulse.tween_property(node, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_SINE)


# ---------- jogo (publico, tambem usado pelas interacoes) ----------

## Examina uma pista. Retorna o resultado do diretor; a fala segue em segundo plano.
func examine_clue(clue_id: StringName) -> Dictionary:
	var res := ctx.submit(&"clue_examined", &"tracker", {"clue_id": clue_id})
	var clue := Ep01Content.clue(clue_id)
	var keys: Array[String] = []
	keys.append(String(clue.get("observation_key", "")))
	var follow_choice := false
	if bool(res.get("accepted", false)):
		var found := ctx.director.clues_found
		if found.has(PAW) and found.has(BOOT):
			for k in Ep01Content.lines(&"dock_investigation", "both_clues"):
				keys.append(k)
			follow_choice = true
		else:
			keys.append(String(clue.get("partial_key", "")))
		refresh_world()
		_act_examine(clue_id, follow_choice)
	_speak_clue(keys, follow_choice)
	return res


## Camera dirigida: aproxima-se da pista durante a inspecao e volta depois (a mao nao encobre o alvo: enquadra de cima).
func _frame_inspection(duration: float) -> void:
	var cam := ctx.camera_rig
	if cam.reduced_motion:
		return
	var base := cam.offset
	var tw := create_tween()
	tw.tween_property(cam, "offset", Vector3(base.x, base.y * 0.72, base.z * 0.62), 0.7).set_trans(Tween.TRANS_SINE)
	tw.tween_interval(maxf(duration - 1.4, 0.2))
	tw.tween_property(cam, "offset", base, 0.7).set_trans(Tween.TRANS_SINE)


## Rastro olha para a pista, toca nela (agacha e estende a mao) e reage; a segunda pista traz o susto da descoberta.
func _act_examine(clue_id: StringName, discovery: bool) -> void:
	var tracker := ctx.actors[&"tracker"] as MemberActor
	var node: Node3D = _marks.get(clue_id)
	# RB-R1: a pata fica no banco do barco, fora do alcance do cais; o Rastro sobe ao conves (sem fisica, como embarcado)
	# no ponto PAW_INSPECT_STAND_LOCAL, toca a marca e volta ao cais onde estava.
	var back := tracker.global_position
	var on_boat := clue_id == PAW and tracker.riding_on == null
	if on_boat:
		tracker.ride_briefly(ctx.boat, Ep01Layout.PAW_INSPECT_STAND_LOCAL)
	if on_boat:
		var ahead := ctx.boat.to_global(Ep01Layout.PAW_INSPECT_STAND_LOCAL + Vector3(0.0, 0.0, 1.0))
		tracker.face_now(ahead)
		tracker.face_point(ahead)
	elif node != null:
		tracker.face_point(node.global_position)
	tracker.set_expression(&"atenta")
	var duration := tracker.play_action(&"inspect_touch")
	if duration <= 0.0:
		if on_boat:
			tracker.dismount(back)
		return
	_frame_inspection(duration)
	get_tree().create_timer(duration).timeout.connect(func() -> void:
		if not is_inside_tree():
			return
		if on_boat and tracker.riding_on == ctx.boat:
			tracker.dismount(back)
		if discovery:
			tracker.set_expression(&"surpresa")
			tracker.play_action(&"react_surprise")
			get_tree().create_timer(1.2).timeout.connect(func() -> void:
				if is_inside_tree():
					tracker.set_expression(&"neutra"))
		else:
			tracker.set_expression(&"neutra"))


func _speak_clue(keys: Array[String], then_choice: bool) -> void:
	await ctx.hud.say_all(keys)
	if then_choice:
		open_destination_choice()


func open_destination_choice() -> void:
	var found := ctx.director.clues_found
	if ctx.director.state != &"dock_investigation" or not (found.has(PAW) and found.has(BOOT)):
		return
	if ctx.hud.choice_open:
		return
	var prompt := Loc.t(String(Ep01Content.data().get("destination_prompt_key", "")))
	var options: Array[Dictionary] = []
	for d: Dictionary in Ep01Content.data().get("destinations", []):
		options.append({"id": StringName(d["id"]), "label": Loc.t(String(d["label_key"])), "icon": StringName(d["id"])})
	_choice_active = true
	ctx.hud.open_choice(prompt, options)


func _on_choice_made(id: StringName) -> void:
	if not _choice_active:
		return
	_choice_active = false
	if id == &"":
		return
	choose_destination(id)


## Escolhe o destino. `bank` avanca (o Ep01Main troca para Leme); `harbor` e rejeitado e vira observacao.
func choose_destination(id: StringName) -> Dictionary:
	var res := ctx.submit(&"destination_chosen", &"tracker", {"destination": id})
	if not bool(res.get("accepted", false)) and res.get("reason", &"") == &"wrong_destination":
		_reject_and_reopen(id)
	return res


func _reject_and_reopen(id: StringName) -> void:
	var keys := Ep01Content.lines(&"dock_investigation", "destination_rejected:%s" % id)
	await ctx.hud.say_all(keys)
	if _active and ctx.director.state == &"dock_investigation":
		open_destination_choice()


func is_examined(clue_id: StringName) -> bool:
	return ctx.director.clues_found.has(clue_id)
