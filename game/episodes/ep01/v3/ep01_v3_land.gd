class_name Ep01V3Land
extends Node3D
## Missoes M1-M4 em terra do Ep01 v3 (RB-R1 E4). Monta, por missao, os pontos de acao (Ep01Interactable), as pecas
## provisorias (roupas, bola, carrinho, caixotes) e os pontos derivados dos marcadores da vila; informa a Mission
## pelos eventos reais (`main.notify_mission`). Nada aqui le entrada: o jogador (ou o bot) aperta `interact` e a
## Ep01V3Main dispara o ponto mais perto. Erro nunca castiga (entrega errada so mostra a barraca certa).
##
## Escalada do Pico sem step-up: cada subida e UM aperto que encadeia saltos programados (`jump_to`) pelos degraus
## marcados no mundo (galpao 0,45/0,95/1,53 m; chafariz 0,5/1,0/1,5 m); depois de soltar/puxar, ele desce sozinho.
## Pontos derivados (no proprio no, nunca no mundo do art3d): base do galpao, base da arvore, base do chafariz,
## cesto e 3 ganchos do varal, carrinho dirigivel. Todos PROVISORIOS.

signal busy_changed(busy: bool)

const PROVISIONAL := &"provisional"
const HOP_TIME := 0.42
const HOP_HEIGHT := 0.55
## Varal: o marcador e o centro; 3 ganchos a 0,6 m no eixo X, a 1,45 m do chao; cesto 0,9 m ao norte.
const LINE_SLOTS: Array[float] = [-0.6, 0.0, 0.6]
const LINE_HEIGHT := 1.45
## Carrinho a frente da Leme (m) e cores das cargas (barraca -> cor do caixote).
const CART_AHEAD := 1.05
const STALL_COLORS := {&"M4_Stall_Apple": Color("e0412b"), &"M4_Stall_Lemon": Color("f2c81d"), &"M4_Stall_Grapes": Color("4a6fd8")}
const CARGO_ORDER: Array[StringName] = [&"M4_Stall_Apple", &"M4_Stall_Lemon", &"M4_Stall_Grapes"]
const CART_STATIC_SHAPE := "Collision/Props/cart_1_0"
const CART_KIT_INDEX := 1

var main: Ep01V3Main
var world: VillageWorld
var mission_id: StringName = &""
## Pontos de acao da missao (id -> Ep01Interactable) e o que avanca a missao agora.
var spots: Dictionary = {}
var points: Dictionary = {}
var busy: bool = false
var _root: Node3D
var _pieces: Array[Node3D] = []
var _hung: int = 0
var _paw_next: int = 0
var _stream_next: int = 0
var _cargo: int = 0
var cart: Node3D
var cart_holder: MemberActor = null
var _cargo_box: Node3D
var _ball: Node3D
var _cart_xf: Transform3D


func setup(m: Ep01V3Main) -> void:
	main = m
	world = m.world
	name = "Land"
	_derive_points()


# ---------------------------------------------------------------- pontos derivados

func _mk(n: StringName) -> Vector3:
	var mk := world.marker(n)
	return mk.global_position if mk != null else Vector3.ZERO


func _derive_points() -> void:
	var s1 := _mk(&"M2_ShedStep_1")
	var s2 := _mk(&"M2_ShedStep_2")
	var away := s1 - s2
	away.y = 0.0
	points[&"ShedBase"] = Vector3(s1.x, 0.0, s1.z) + away.normalized() * 0.75
	var branch := _mk(&"M2_TreeBranch")
	var line := _mk(&"M2_Clothesline")
	var to_line := line - branch
	to_line.y = 0.0
	points[&"TreeBase"] = Vector3(branch.x, 0.0, branch.z) + to_line.normalized() * 1.3
	points[&"Basket"] = line + Vector3(0, 0.0, -0.9)
	for i in LINE_SLOTS.size():
		points[StringName("LineSlot_%d" % i)] = line + Vector3(LINE_SLOTS[i], LINE_HEIGHT, 0)
	var f1 := _mk(&"M3_FountainStep_1")
	var f2 := _mk(&"M3_FountainStep_2")
	var out := f1 - f2
	out.y = 0.0
	points[&"FountainBase"] = Vector3(f1.x, 0.0, f1.z) + out.normalized() * 0.8
	# Marcadores no proprio no do episodio (para testes e para o art3d conferir).
	var holder := Node3D.new()
	holder.name = "DerivedPoints"
	holder.set_meta(PROVISIONAL, true)
	add_child(holder)
	for k: StringName in points:
		var mk := Marker3D.new()
		mk.name = String(k)
		holder.add_child(mk)
		mk.position = points[k]


## Onde o trio fica ao retomar uma missao pelo salvo (onde a missao anterior terminou).
func start_position(id: StringName) -> Vector3:
	match id:
		&"M1":
			return _mk(&"M0_RastroStart")
		&"M2":
			return _mk(&"M1_PawTrail_4")
		&"M3":
			return points[&"Basket"] + Vector3(-1.2, 0, 0)
		&"M4":
			return _mk(&"M3_BallStop") + Vector3(1.2, 0, 0.6)
	return Vector3.INF


func handles(id: StringName) -> bool:
	return id in [&"M1", &"M2", &"M3", &"M4"]


# ---------------------------------------------------------------- montagem por missao

func build(id: StringName) -> void:
	clear()
	mission_id = id
	if not handles(id):
		return
	_root = Node3D.new()
	_root.name = "Mission_" + String(id)
	_root.set_meta(PROVISIONAL, true)
	add_child(_root)
	match id:
		&"M1":
			_build_m1()
		&"M2":
			_build_m2()
		&"M3":
			_build_m3()
		&"M4":
			_build_m4()
	refresh()


func clear() -> void:
	if cart_holder != null:
		_release_cart()
	spots.clear()
	_pieces.clear()
	_hung = 0
	_paw_next = 0
	_stream_next = 0
	_cargo = 0
	_set_busy(false)
	if _root != null:
		_root.queue_free()
		_root = null
	mission_id = &""


func _spot(id: StringName, pos: Vector3, icon: StringName, label_key: String, member: StringName, radius: float = 1.4,
		auto: bool = false) -> Ep01Interactable:
	var it := Ep01Interactable.new()
	it.name = "Spot_" + String(id)
	it.action_id = id
	it.icon = icon
	it.label_key = label_key
	it.member = member
	it.radius = radius
	it.set_meta(&"auto", auto)
	it.set_meta(PROVISIONAL, true)
	_root.add_child(it)
	it.global_position = pos
	it.triggered.connect(func(actor: Node3D) -> void: _on_spot(id, actor))
	spots[id] = it
	return it


func _enable(id: StringName, on: bool) -> void:
	if spots.has(id):
		(spots[id] as Ep01Interactable).enabled = on


func _paw_decal(pos: Vector3, tint: Color = Color("6b4a2f")) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = IconView.texture_for(&"paw")
	s.pixel_size = 0.0016
	s.modulate = tint
	s.rotation.x = -PI / 2.0
	s.set_meta(PROVISIONAL, true)
	_root.add_child(s)
	s.global_position = pos + Vector3(0, 0.03, 0)
	return s


func _emblem(id: StringName, pos: Vector3, member: StringName) -> void:
	var it := _spot(id, pos, &"star", "ui.action.pick", member, 1.1)
	it.set_meta(&"emblem", true)
	var coin := Blocks.cylinder(it, "Coin", 0.26, 0.06, Vector3(0, 0.75, 0), Color("ffc93c"), 0.9)
	coin.rotation.x = PI / 2.0
	var tw := coin.create_tween().set_loops()
	tw.tween_property(coin, "rotation:y", TAU, 2.4).from(0.0)


func _cloth(pos: Vector3, color: Color, n: String) -> Node3D:
	var c := Blocks.box(_root, n, Vector3(0.42, 0.34, 0.04), Vector3.ZERO, color)
	c.global_position = pos
	_pieces.append(c)
	return c


# M1: pata no banco, bota na margem, 4 pegadinhas ate a margem (Rastro).
func _build_m1() -> void:
	_spot(&"bench", _mk(&"M1_BenchClue"), &"paw", "ui.action.examine", &"tracker")
	_spot(&"boot", _mk(&"M1_BootPrint"), &"boot", "ui.action.examine", &"tracker")
	for i in 4:
		var p := _mk(StringName("M1_PawTrail_%d" % (i + 1)))
		_paw_decal(p)
		_spot(StringName("paw_%d" % (i + 1)), p, &"paw", "", &"tracker", 0.9, true)
	_emblem(&"emb_m1_mooring", _mk(&"M1_EmptyMooring"), &"tracker")


# M2: Pico solta 2 pecas (galpao, arvore); Rastro acha a 3a nos juncos; qualquer um pendura as 3.
func _build_m2() -> void:
	_cloth(_mk(&"M2_ShedTop") + Vector3(0, 0.25, 0.3), Color("e85d75"), "ClothShed")
	_cloth(_mk(&"M2_TreeBranch") + Vector3(0, 0.15, 0), Color("4fa3e0"), "ClothTree")
	_cloth(_mk(&"M2_ReedsPiece") + Vector3(0, 0.25, 0), Color("f2c81d"), "ClothReeds")
	_spot(&"shed_climb", points[&"ShedBase"], &"carabiner", "ui.action.climb", &"climber")
	_spot(&"shed_free", _mk(&"M2_ShedTop"), &"rope", "ui.action.free", &"climber", 1.2)
	_spot(&"tree_climb", points[&"TreeBase"], &"carabiner", "ui.action.climb", &"climber")
	_spot(&"tree_free", _mk(&"M2_TreeBranch"), &"rope", "ui.action.free", &"climber", 1.2)
	_spot(&"reeds", _mk(&"M2_ReedsPiece"), &"paw", "ui.action.examine", &"tracker")
	_spot(&"hang", _mk(&"M2_Clothesline"), &"rope", "ui.action.hang", &"", 1.6)
	# Pegadinhas molhadas do cesto aos juncos.
	var a: Vector3 = points[&"Basket"]
	var b := _mk(&"M2_ReedsPiece")
	for i in 3:
		_paw_decal(a.lerp(b, 0.25 + i * 0.25), Color("3b6f9c"))
	_emblem(&"emb_m2_shed", _mk(&"M2_ShedTop") + Vector3(-0.55, 0, -0.25), &"climber")
	_emblem(&"emb_m2_reeds", b + Vector3(0.9, 0, 0.3), &"tracker")


# M3: Rastro segue o filete ate a grade (bola presa); Pico sobe 3 degraus e puxa as folhas; a bola rola.
func _build_m3() -> void:
	_spot(&"stream_1", _mk(&"M3_ChannelStart"), &"look", "ui.action.examine", &"tracker")
	_spot(&"stream_2", _mk(&"M3_Grate"), &"look", "ui.action.examine", &"tracker")
	_spot(&"fountain_climb", points[&"FountainBase"], &"carabiner", "ui.action.climb", &"climber")
	_spot(&"leaves", _mk(&"M3_UpperBasin"), &"leaf", "ui.action.pull", &"climber", 1.1)
	_ball = Blocks.sphere(_root, "Ball", 0.16, Vector3.ZERO, Color("e8452c"))
	_ball.global_position = _mk(&"M3_Grate") + Vector3(0, 0.16, 0)
	var leaves := Blocks.box(_root, "Leaves", Vector3(0.5, 0.08, 0.5), Vector3.ZERO, Color("5c8a2e"))
	leaves.global_position = _mk(&"M3_UpperBasin") + Vector3(0, 0.08, 0)
	_pieces.append(leaves)
	_emblem(&"emb_m3_basin", _mk(&"M3_FountainStep_3") + Vector3(0, 0.05, 0), &"climber")


# M4: Rastro le os icones; Leme empurra o carrinho e entrega 3 caixotes na barraca da mesma cor.
func _build_m4() -> void:
	_build_cart()
	_spot(&"read_icons", cart.global_position, &"look", "ui.action.examine", &"tracker", 1.8)
	_spot(&"take_cart", cart.global_position, &"helm", "ui.action.push", &"pilot", 1.8)
	for st: StringName in CARGO_ORDER:
		_spot(StringName("deliver_" + String(st)), _mk(st), &"heart", "ui.action.deliver", &"pilot", 1.9)
		var sign := Blocks.cylinder(_root, "Sign_" + String(st), 0.22, 0.04, Vector3.ZERO, STALL_COLORS[st], 0.6)
		sign.rotation.x = PI / 2.0
		sign.global_position = _mk(st) + Vector3(0, 2.1, 0)
	_emblem(&"emb_m4_stall", _mk(&"M4_Cart").lerp(_mk(&"M4_Stall_Apple"), 0.45), &"pilot")


## Carrinho dirigivel: mesma malha do kit no mesmo lugar; a instancia estatica some (escala 0) e a caixa de colisao
## gerada fica desligada enquanto a missao existe. Nada e gravado no mundo do art3d.
func _build_cart() -> void:
	var shape := world.get_node_or_null(CART_STATIC_SHAPE) as CollisionShape3D
	_cart_xf = _kit_cart_transform()
	var mmi := world.get_node_or_null("Kit/cart") as MultiMeshInstance3D
	cart = Node3D.new()
	cart.name = "Cart"
	cart.set_meta(PROVISIONAL, true)
	_root.add_child(cart)
	if mmi != null and mmi.multimesh.instance_count > CART_KIT_INDEX:
		var mi := MeshInstance3D.new()
		mi.name = "Mesh"
		mi.mesh = mmi.multimesh.mesh
		cart.add_child(mi)
		mmi.multimesh.set_instance_transform(CART_KIT_INDEX, Transform3D(Basis().scaled(Vector3.ONE * 0.0001), _cart_xf.origin))
	else:
		Blocks.box(cart, "Mesh", Vector3(1.2, 0.6, 0.7), Vector3(0, 0.45, 0), Color("a86b3c"))
	cart.global_transform = _cart_xf
	if shape != null:
		shape.disabled = true
	_root.tree_exiting.connect(_restore_cart_world, CONNECT_ONE_SHOT)
	_cargo_box = Node3D.new()
	_cargo_box.name = "Cargo"
	cart.add_child(_cargo_box)
	_cargo_box.position = Vector3(0, 0.85, 0)
	_refresh_cargo()


## Transformacao do carrinho no layout do mundo (a leitura da MultiMesh volta vazia no renderizador headless).
func _kit_cart_transform() -> Transform3D:
	var rows: Array = (world.layout.get("kit", {}) as Dictionary).get("cart", [])
	if rows.size() > CART_KIT_INDEX:
		var r: Array = rows[CART_KIT_INDEX]
		var b := Basis(Vector3.UP, deg_to_rad(float(r[3]))).scaled(Vector3.ONE * float(r[4]))
		return Transform3D(b, Vector3(float(r[0]), float(r[1]), float(r[2])))
	return Transform3D(Basis(Vector3.UP, deg_to_rad(120.0)), Vector3(-18.6, 0.0, 0.8))


func _restore_cart_world() -> void:
	if not is_instance_valid(world):
		return
	var shape := world.get_node_or_null(CART_STATIC_SHAPE) as CollisionShape3D
	if shape != null:
		shape.disabled = false
	var mmi := world.get_node_or_null("Kit/cart") as MultiMeshInstance3D
	if mmi != null and mmi.multimesh.instance_count > CART_KIT_INDEX:
		mmi.multimesh.set_instance_transform(CART_KIT_INDEX, _cart_xf)


func _refresh_cargo() -> void:
	for c in _cargo_box.get_children():
		c.queue_free()
	for i in range(_cargo, CARGO_ORDER.size()):
		var col: Color = STALL_COLORS[CARGO_ORDER[i]]
		var b := Blocks.box(_cargo_box, "Crate%d" % i, Vector3(0.42, 0.26, 0.32), Vector3(0, 0.14 + (i - _cargo) * 0.28, 0), col, 0.15)
		b.set_meta(&"stall", CARGO_ORDER[i])


func cargo_stall() -> StringName:
	return CARGO_ORDER[_cargo] if _cargo < CARGO_ORDER.size() else &""


func _attach_cart(actor: MemberActor) -> void:
	cart_holder = actor


func _release_cart() -> void:
	cart_holder = null


func _physics_process(delta: float) -> void:
	if cart_holder != null and is_instance_valid(cart) and is_instance_valid(cart_holder):
		var f := cart_holder.facing()
		var want := cart_holder.global_position + f * CART_AHEAD
		want.y = cart_holder.global_position.y
		cart.global_position = cart.global_position.lerp(want, clampf(delta * 12.0, 0.0, 1.0))
		var yaw := atan2(-f.x, -f.z) + PI / 2.0
		cart.rotation.y = lerp_angle(cart.rotation.y, yaw, clampf(delta * 10.0, 0.0, 1.0))


# ---------------------------------------------------------------- estado e eventos

## Liga so os pontos que fazem sentido no passo atual (o resto fica desligado e sem prompt).
func refresh() -> void:
	if main == null or main.current == null or _root == null:
		return
	for k: StringName in spots:
		var it := spots[k] as Ep01Interactable
		if it.get_meta(&"emblem", false):
			it.enabled = true
		else:
			it.enabled = false
	var step: StringName = main.current.current_step().get("id", &"")
	match mission_id:
		&"M1":
			match step:
				&"bench":
					_enable(&"bench", true)
				&"boot":
					_enable(&"boot", true)
				&"trail":
					_enable(StringName("paw_%d" % (_paw_next + 1)), true)
		&"M2":
			match step:
				&"free_pieces":
					var shed_done: bool = _pieces[0].get_meta(&"freed", false)
					var tree_done: bool = _pieces[1].get_meta(&"freed", false)
					var on_top := _on_shed()
					var on_tree := _on_tree()
					_enable(&"shed_climb", not shed_done and not on_top and not on_tree)
					_enable(&"shed_free", not shed_done and on_top)
					_enable(&"tree_climb", not tree_done and shed_done and not on_top and not on_tree)
					_enable(&"tree_free", not tree_done and on_tree)
				&"find_third":
					_enable(&"reeds", true)
				&"hang":
					_enable(&"hang", true)
		&"M3":
			match step:
				&"stream":
					_enable(StringName("stream_%d" % (_stream_next + 1)), true)
				&"leaves":
					var up := _on_fountain()
					_enable(&"fountain_climb", not up)
					_enable(&"leaves", up)
		&"M4":
			match step:
				&"read":
					_enable(&"read_icons", true)
				&"deliver":
					_enable(&"take_cart", cart_holder == null)
					for st: StringName in CARGO_ORDER:
						_enable(StringName("deliver_" + String(st)), cart_holder != null)
	# Emblema de outro heroi continua visivel, mas so o heroi certo pega (Ep01Interactable.member).


func _actor() -> MemberActor:
	return main.controlled_node as MemberActor


func _on_shed() -> bool:
	var a := _actor()
	return a != null and a.global_position.y > 1.2 and a.global_position.distance_to(_mk(&"M2_ShedTop")) < 2.2


func _on_tree() -> bool:
	var a := _actor()
	return a != null and a.global_position.y > 1.2 and a.global_position.distance_to(_mk(&"M2_TreeBranch")) < 1.6


func _on_fountain() -> bool:
	var a := _actor()
	return a != null and a.global_position.y > 1.2 and a.global_position.distance_to(_mk(&"M3_UpperBasin")) < 1.6


func _set_busy(on: bool) -> void:
	if busy != on:
		busy = on
		busy_changed.emit(on)


func _on_spot(id: StringName, actor: Node3D) -> void:
	var it := spots.get(id) as Ep01Interactable
	if it != null and it.get_meta(&"emblem", false):
		if main.find_emblem(id):
			FeedbackFx.ring(world, it.global_position + Vector3(0, 0.7, 0))
			it.queue_free()
			spots.erase(id)
		return
	match id:
		&"bench":
			_examine(actor, it)
			if main.notify_mission(&"paw_examined"):
				main.say("ep01.dock.tracker.small_print")
		&"boot":
			_examine(actor, it)
			if main.notify_mission(&"boot_examined"):
				main.say("ep01.dock.tracker.boot_observation")
				main.say("ep01.dock.tracker.two_trails")
		&"paw_1", &"paw_2", &"paw_3", &"paw_4":
			FeedbackFx.pulse(world, it.global_position)
			_paw_next += 1
			if main.notify_mission(&"paw_followed") and _paw_next == 4:
				main.say("ep01.bank.tracker.pup_village")
		&"shed_climb":
			await _hop_chain(actor as MemberActor, [_mk(&"M2_ShedStep_1"), _mk(&"M2_ShedStep_2"), _mk(&"M2_ShedTop")])
		&"tree_climb":
			await _hop_chain(actor as MemberActor, [_mk(&"M2_TreeBranch")])
		&"shed_free", &"tree_free":
			var piece := _pieces[0] if id == &"shed_free" else _pieces[1]
			piece.set_meta(&"freed", true)
			FeedbackFx.sparkle(world, piece.global_position)
			_fly(piece, _basket_slot(), 0.6)
			main.notify_mission(&"piece_freed")
			if id == &"shed_free":
				main.say("ep01.bank.climber.sock_high")
			var base: Vector3 = points[&"ShedBase"] if id == &"shed_free" else points[&"TreeBase"]
			await _hop_chain(actor as MemberActor, [base])
		&"reeds":
			_examine(actor, it)
			_pieces[2].set_meta(&"freed", true)
			_fly(_pieces[2], _basket_slot(), 0.6)
			if main.notify_mission(&"piece_found"):
				main.say("ep01.bank.tracker.wet_paw")
		&"hang":
			if _hung < 3:
				_fly(_pieces[_hung], points[StringName("LineSlot_%d" % _hung)], 0.45)
				_pieces[_hung].rotation = Vector3.ZERO
				_hung += 1
				FeedbackFx.sparkle(world, points[StringName("LineSlot_%d" % (_hung - 1))])
				main.notify_mission(&"piece_hung")
				if _hung == 3:
					main.say("ep01.bank.tracker.next_clue")
		&"stream_1", &"stream_2":
			_examine(actor, it)
			_stream_next += 1
			if main.notify_mission(&"stream_followed"):
				main.say("ep01.plaza.tracker.dry_stream" if _stream_next == 1 else "ep01.plaza.tracker.ball_stuck")
		&"fountain_climb":
			await _hop_chain(actor as MemberActor, [_mk(&"M3_FountainStep_1"), _mk(&"M3_FountainStep_2"),
				_mk(&"M3_FountainStep_3"), _mk(&"M3_UpperBasin")])
		&"leaves":
			FeedbackFx.splash(world, _mk(&"M3_UpperBasin") + Vector3(0, 0.3, 0))
			_fly(_pieces[0], points[&"FountainBase"] + Vector3(0.6, 0.04, 0), 0.5)
			main.say("ep01.plaza.climber.top_basin")
			main.notify_mission(&"leaves_pulled")
			main.say("ep01.plaza.radio.water_back")
			_roll_ball()
			await _hop_chain(actor as MemberActor, [_mk(&"M3_FountainStep_2"), points[&"FountainBase"]])
		&"read_icons":
			_examine(actor, it)
			for st: StringName in CARGO_ORDER:
				FeedbackFx.ring(world, _mk(st) + Vector3(0, 2.1, 0), STALL_COLORS[st])
			if main.notify_mission(&"icons_read"):
				main.say("ep01.market.vendor.mess")
				main.say("ep01.market.tracker.read_icon")
		&"take_cart":
			_attach_cart(actor as MemberActor)
			main.say("ep01.market.pilot.cart_go")
		_:
			if String(id).begins_with("deliver_"):
				_deliver(StringName(String(id).trim_prefix("deliver_")))
	refresh()


func _deliver(stall: StringName) -> void:
	if stall != cargo_stall():
		# Sem castigo: a feirante aponta a barraca certa; a carga continua no carrinho.
		main.say("ep01.market.vendor.wrong_stall")
		FeedbackFx.ring(world, _mk(cargo_stall()) + Vector3(0, 2.1, 0), STALL_COLORS[cargo_stall()])
		main.flash_help_target()
		return
	var crate := _cargo_box.get_child(0) as Node3D if _cargo_box.get_child_count() > 0 else null
	if crate != null:
		_cargo_box.remove_child(crate)
		_root.add_child(crate)
		crate.global_position = cart.global_position + Vector3(0, 1.0, 0)
		_fly(crate, _mk(stall) + Vector3(0, 0.95, 0) + (_mk(stall) - cart.global_position).normalized() * 0.5, 0.5)
	FeedbackFx.sparkle(world, _mk(stall) + Vector3(0, 1.0, 0))
	_cargo += 1
	_refresh_cargo()
	if _cargo >= CARGO_ORDER.size():
		_release_cart()
		main.say("ep01.market.vendor.gull_hint")
	main.notify_mission(&"cargo_delivered")


func _basket_slot() -> Vector3:
	var n := 0
	for p in _pieces:
		if p.get_meta(&"freed", false):
			n += 1
	return points[&"Basket"] + Vector3(-0.3 + 0.3 * (n - 1), 0.08 + 0.03 * n, 0)


func _fly(node: Node3D, to: Vector3, t: float) -> void:
	var tw := node.create_tween()
	tw.tween_property(node, "global_position", to, t).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


func _roll_ball() -> void:
	if _ball == null:
		return
	var to := _mk(&"M3_BallStop") + Vector3(0, 0.16, 0)
	var tw := _ball.create_tween().set_parallel(true)
	tw.tween_property(_ball, "global_position", to, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(_ball, "rotation:x", -TAU * 2.0, 1.4)


func _examine(actor: Node3D, it: Ep01Interactable) -> void:
	var a := actor as MemberActor
	if a != null and it != null:
		a.face_now(it.global_position)
		for anim: StringName in [&"inspect", &"crouch", &"point"]:
			if a.model != null and a.model.has_animation(anim):
				a.play_action(anim)
				break


## Saltos encadeados do Pico (um aperto): pousa em cada ponto e segue. A Ep01V3Main fica ocupada ate o ultimo pouso.
func _hop_chain(a: MemberActor, targets: Array) -> void:
	if a == null:
		return
	_set_busy(true)
	for p: Vector3 in targets:
		a.jump_to(p + Vector3(0, 0.04, 0), HOP_TIME, HOP_HEIGHT + maxf(0.0, p.y - a.global_position.y) * 0.5)
		await a.landed
		if not is_inside_tree():
			return
	_set_busy(false)
	refresh()


# ---------------------------------------------------------------- alvo da ajuda e do bot

## O que avanca a missao agora (alvo da ajuda: gesto, seta e camera). null se o passo nao tem ponto ligado.
func help_target() -> Node3D:
	if _root == null:
		return null
	var best: Ep01Interactable = null
	if mission_id == &"M4" and cart_holder != null:
		return spots.get(StringName("deliver_" + String(cargo_stall()))) as Node3D
	for k: StringName in spots:
		var it := spots[k] as Ep01Interactable
		if it.enabled and not it.get_meta(&"emblem", false):
			best = it
			break
	return best


## Emblema que o heroi em controle pode pegar agora (o bot passa por ele antes do alvo principal).
func emblem_for(member: StringName) -> Ep01Interactable:
	if _root == null:
		return null
	for k: StringName in spots:
		var it := spots[k] as Ep01Interactable
		if it.get_meta(&"emblem", false) and it.member == member and not it.is_queued_for_deletion():
			return it
	return null
