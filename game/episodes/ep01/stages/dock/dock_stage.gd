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
	var wood := Color("b58a5a")
	var dark_wood := Color("7a5636")
	Blocks.solid_box(self, "DockDeck", Vector3(16, 0.4, 6), Vector3(0, -0.2, 0), wood)
	Blocks.solid_box(self, "BankGround", Vector3(20, 0.4, 13), Vector3(0, -0.2, 9.5), Color("7d9a54"))
	# Tabuas e cabecos
	for i in range(-7, 8, 2):
		Blocks.box(self, "Plank%d" % i, Vector3(0.06, 0.02, 5.9), Vector3(i, 0.01, 0), dark_wood)
	for p: Vector3 in [Vector3(-7.5, 0.35, -2.6), Vector3(7.5, 0.35, -2.6), Vector3(-7.5, 0.35, 2.6), Vector3(7.5, 0.35, 2.6)]:
		Blocks.cylinder(self, "Bollard", 0.18, 0.7, p, dark_wood)
	# Caixotes no cais (fora do caminho do banco)
	Blocks.solid_box(self, "Crate1", Vector3(0.9, 0.8, 0.9), Vector3(6.2, 0.4, 1.8), Color("d9a05b"))
	Blocks.solid_box(self, "Crate2", Vector3(0.7, 0.6, 0.7), Vector3(5.2, 0.3, 2.2), Color("c48a45"))
	# Cabana na margem
	Blocks.solid_box(self, "HutBody", Vector3(3.4, 2.2, 2.8), Vector3(-7.0, 1.1, 13.5), Color("e3cfa5"))
	Blocks.box(self, "HutRoof", Vector3(3.9, 0.35, 3.3), Vector3(-7.0, 2.4, 13.5), Color("a8503c"))
	Blocks.box(self, "HutDoor", Vector3(0.8, 1.4, 0.06), Vector3(-7.0, 0.7, 12.08), dark_wood)
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
	for x in range(-10, 11, 4):
		Blocks.box(self, "FencePost%d" % x, Vector3(0.14, 0.9, 0.14), Vector3(x, 0.45, 16.0), dark_wood)
	Blocks.box(self, "FenceRail", Vector3(20.0, 0.1, 0.1), Vector3(0, 0.8, 16.0), dark_wood)
	Blocks.box(self, "DockRail", Vector3(16.0, 0.08, 0.08), Vector3(0, 0.5, -3.0), dark_wood)


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
	Blocks.cylinder(paw, "PawMarkPad", 0.11, 0.02, Vector3(0, 0.012, 0.05), DARK)
	for i in 4:
		var a := -0.45 + 0.3 * i
		Blocks.cylinder(paw, "PawMarkToe%d" % i, 0.045, 0.02, Vector3(sin(a) * 0.2, 0.012, -0.08 - cos(a) * 0.08), DARK)
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
	Blocks.cylinder(boot, "BootMarkMud", 0.9, 0.02, Vector3(0, 0.011, 0), Color("6b5236"))
	bg.append(Blocks.cylinder(boot, "BootMarkGlow", 0.75, 0.01, Vector3(0, 0.025, 0), GLOW_COLOR, 1.6))
	Blocks.box(boot, "BootMarkSole", Vector3(0.28, 0.02, 0.55), Vector3(0, 0.04, -0.15), DARK)
	Blocks.box(boot, "BootMarkHeel", Vector3(0.24, 0.02, 0.2), Vector3(0, 0.04, 0.22), DARK)
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
	pilot.ride(ctx.boat, Vector3(-0.45, 0.6, 0.9))
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
	return {"offset": Vector3(0.0, 7.5, 8.5), "yaw": 0.0}


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
	_speak_clue(keys, follow_choice)
	return res


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
