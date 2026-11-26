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
## Um salto da cadeia do Pico foi interrompido (sem pouso); a cadeia parou e `busy` foi solto.
signal hop_aborted

const PROVISIONAL := &"provisional"
const HOP_TIME := 0.42
const HOP_HEIGHT := 0.55
## Folga alem da duracao do salto antes de considerar o salto interrompido (s).
const HOP_GRACE := 0.6
## Teto da espera de um salto ainda no ar, em multiplos de HOP_TIME + HOP_GRACE.
const HOP_HARD_LIMIT := 4.0
## Varal: o marcador e o centro; 3 ganchos a 0,6 m ao longo da corda real do mundo (diagonal a -23 graus em Y, corda a
## ~1,75 m; aviso do lead na E5, nao medido aqui); a peca pendura com o centro 0,17 m abaixo da corda; cesto 0,9 m ao norte.
const LINE_SLOTS: Array[float] = [-0.6, 0.0, 0.6]
const LINE_YAW_DEG := -23.0
const LINE_HEIGHT := 1.58
## Carrinho a frente da Leme (m) e cores das cargas (barraca -> cor do caixote).
const CART_AHEAD := 1.05
const STALL_COLORS := {&"M4_Stall_Apple": Color("e0412b"), &"M4_Stall_Lemon": Color("f2c81d"), &"M4_Stall_Grapes": Color("4a6fd8")}
const CARGO_ORDER: Array[StringName] = [&"M4_Stall_Apple", &"M4_Stall_Lemon", &"M4_Stall_Grapes"]
const CART_STATIC_SHAPE := "Collision/Props/cart_1_0"
const CART_KIT_INDEX := 1
## F2 (M1): bota do capitao junto a amarra vazia (lugar testado pelo art3d em clues_v3_capture.gd) e trilha da pata do
## cais ate a margem (rota andavel da grade do bot, tabua -> terra). As 4 pegadinhas automaticas ficam na trilha: a 1a a
## 1,7 m da pata do cais.
const BOOT_FROM_MOORING := Vector3(2.3, 0.0, 1.4)
const BOOT_YAW_DEG := 300.0
const M1_PAW_PATH: Array[Vector3] = [Vector3(1.0, 0.0, -1.0), Vector3(0.75, 0.0, -0.5), Vector3(-0.25, -0.05, 3.5),
	Vector3(1.0, 0.01, 4.0), Vector3(0.5, 0.02, 5.25), Vector3(5.2, 0.0, 7.3), Vector3(7.6, -0.01, 8.3)]
const M1_PAW_SPOTS: Array[int] = [0, 3, 5, 6]
const DECAL_DIR := "res://worlds/village_v3/decals/%s.tscn"

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
var _hop_serial: int = 0


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
		points[StringName("LineSlot_%d" % i)] = line + Basis(Vector3.UP, deg_to_rad(LINE_YAW_DEG)) * Vector3(LINE_SLOTS[i], 0, 0) \
			+ Vector3(0, LINE_HEIGHT, 0)
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
	_hop_serial += 1
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


## Posicao real da pista de um marcador (F2): a bota do M1 fica junto a amarra vazia; o resto e o proprio marcador.
func clue_point(marker: StringName) -> Vector3:
	match marker:
		&"M1_BootPrint":
			return _mk(&"M1_EmptyMooring") + BOOT_FROM_MOORING
		&"M1_PawTrail_4":
			return M1_PAW_PATH[M1_PAW_PATH.size() - 1]
	return _mk(marker)


static func m1_paw_points() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for i in M1_PAW_SPOTS:
		out.append(M1_PAW_PATH[i])
	return out


## Chao sob `p` (camada 1, de 0,9 m acima para baixo: tabua, terra, pedra; nao telhado nem copa). Sem fisica pronta
## (montagem no _ready), fica a altura dada.
func _floor_at(p: Vector3) -> Vector3:
	if not is_inside_tree():
		return p
	var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, 0.9, 0), p + Vector3(0, -3.0, 0), 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return hit.position if not hit.is_empty() else p


## Decalque do art3d (pegada, pena, bota) no chao com a frente (-Z) para `toward`.
func _decal(id: String, pos: Vector3, toward: Vector3, parent: Node = null) -> Node3D:
	var path := DECAL_DIR % id
	if not ResourceLoader.exists(path):
		return null
	var d := (load(path) as PackedScene).instantiate() as Node3D
	(parent if parent != null else _root).add_child(d)
	d.global_position = _floor_at(pos)
	var dir := Vector3(toward.x - pos.x, 0.0, toward.z - pos.z)
	if dir.length() > 0.01:
		d.rotation.y = atan2(-dir.x, -dir.z)
	d.add_to_group(&"ep01v3_clue")
	return d


## Rastro de decalques ao longo de uma linha (um a cada `gap` m, alternando esquerda/direita), virados para a frente.
func trail_decals(parent: Node, id: String, path: Array[Vector3], gap: float) -> Array[Node3D]:
	var out: Array[Node3D] = []
	var left := true
	var carry := 0.0
	for i in path.size() - 1:
		var a := path[i]
		var b := path[i + 1]
		var seg := Vector3(b.x - a.x, 0, b.z - a.z)
		var length := seg.length()
		if length < 0.01:
			continue
		var dir := seg / length
		var t := carry
		while t <= length:
			var p := a.lerp(b, t / length) + Vector3(-dir.z, 0, dir.x) * (0.14 if left else -0.14)
			var d := _decal(id, p, p + dir, parent)
			if d != null:
				out.append(d)
			left = not left
			t += gap
		carry = t - length
	return out


func _emblem(id: StringName, pos: Vector3, member: StringName) -> void:
	var it := _spot(id, pos, &"star", "ui.action.pick", member, 1.1)
	it.set_meta(&"emblem", true)
	Ep01V3Pieces.emblem(it, member)


func _cloth(pos: Vector3, color: Color, n: String) -> Node3D:
	var c := Ep01V3Pieces.cloth(_root, n, color, _pieces.size())
	c.global_position = pos
	_pieces.append(c)
	return c


# M1 (F2, auditoria 2.1): pata de lama na tabua junto ao barco, 3 pegadas de bota ate a bota do capitao caida junto a
# amarra vazia, e as pegadinhas grandes saindo da pata do cais ate a margem (Rastro). Os marcadores do mundo nao mudam:
# a bota e a trilha sao deslocadas aqui (`clue_point`, M1_PAWS).
func _build_m1() -> void:
	var bench := _mk(&"M1_BenchClue")
	var boot := clue_point(&"M1_BootPrint")
	_spot(&"bench", bench, &"paw", "ui.action.examine", &"tracker")
	_spot(&"boot", boot, &"boot", "ui.action.examine", &"tracker")
	_decal("decal_paw_dock", bench + Vector3(0, 0, 0.3), bench + Vector3(-1, 0, 2))
	var b := Ep01V3Pieces.final(_root, "captain_boot", "CaptainBoot")
	if b == null:
		b = Blocks.box(_root, "CaptainBoot", Vector3(0.3, 0.3, 0.14), Vector3(0, 0.15, 0), Color("3a2a20"))
		b.set_meta(PROVISIONAL, true)
	b.global_position = _floor_at(boot)
	b.rotation.y = deg_to_rad(BOOT_YAW_DEG)
	b.add_to_group(&"ep01v3_clue")
	var east := Vector3(bench.x - boot.x, 0.0, bench.z - boot.z).normalized()
	for i in 3:
		var side := Vector3(-east.z, 0, east.x) * (0.18 if i % 2 == 0 else -0.18)
		_decal("decal_boot_print_%s" % ("l" if i % 2 == 0 else "r"), boot + east * (1.0 + 1.6 * i) + side, boot)
	var paws := m1_paw_points()
	trail_decals(_root, "decal_paw_big", M1_PAW_PATH, 1.7)
	for i in paws.size():
		_spot(StringName("paw_%d" % (i + 1)), paws[i], &"paw", "", &"tracker", 0.9, true)
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
		_decal("decal_paw_wet_big", a.lerp(b, 0.25 + i * 0.25), b)
	_emblem(&"emb_m2_shed", _mk(&"M2_ShedTop") + Vector3(-0.55, 0, -0.25), &"climber")
	_emblem(&"emb_m2_reeds", b + Vector3(0.9, 0, 0.3), &"tracker")


# M3: Rastro segue o filete ate a grade (bola presa); Pico sobe 3 degraus e puxa as folhas; a bola rola.
func _build_m3() -> void:
	_spot(&"stream_1", _mk(&"M3_ChannelStart"), &"look", "ui.action.examine", &"tracker")
	_spot(&"stream_2", _mk(&"M3_Grate"), &"look", "ui.action.examine", &"tracker")
	_spot(&"fountain_climb", points[&"FountainBase"], &"carabiner", "ui.action.climb", &"climber")
	_spot(&"leaves", _mk(&"M3_UpperBasin"), &"leaf", "ui.action.pull", &"climber", 1.1)
	_ball = Ep01V3Pieces.ball(_root)
	_ball.global_position = _mk(&"M3_Grate") + Vector3(0, 0.16, 0)
	var leaves := Ep01V3Pieces.leaves(_root)
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
		var sign := Ep01V3Pieces.stall_sign(_root, "Sign_" + String(st), STALL_COLORS[st])
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
		var b := Ep01V3Pieces.crate(_cargo_box, "Crate%d" % i, col, CARGO_ORDER[i])
		b.position = Vector3(0, 0.01 + (i - _cargo) * 0.28, 0)
		b.set_meta(&"stall", CARGO_ORDER[i])


func cargo_stall() -> StringName:
	return CARGO_ORDER[_cargo] if _cargo < CARGO_ORDER.size() else &""


func _attach_cart(actor: MemberActor) -> void:
	cart_holder = actor


func _release_cart() -> void:
	cart_holder = null


## Estado "no alto" (galpao, arvore, chafariz) da ultima `refresh()`. Os pontos ligados dependem dele; se o heroi
## sobe ou cai sem uma cadeia de saltos terminar (salto abortado, queda), religa aqui. Sem isto o M2 travava sem ponto.
var _height_key: int = -1


func _height_state() -> int:
	return int(_on_shed()) | int(_on_tree()) << 1 | int(_on_fountain()) << 2


func _watch_height() -> void:
	if busy or main == null or main.current == null or _root == null:
		return
	var k := _height_state()
	if k != _height_key:
		refresh()


func _physics_process(delta: float) -> void:
	_watch_height()
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
	_height_key = _height_state()
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
				main.say("ep01.dock.tracker.boot_captain")
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
				_pieces[_hung].rotation = Vector3(0, deg_to_rad(LINE_YAW_DEG), 0)
				Ep01V3Pieces.play(_pieces[_hung], &"sway")
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
		main.say(Ep01V3Dialogue.pick("oops.vendor", "ep01.market.vendor.wrong_stall"))
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
## Se um salto for interrompido (teleporte, outro `jump_to`, ator removido), `landed` nunca chega: cada salto espera no
## maximo HOP_TIME + HOP_GRACE e a cadeia termina soltando `busy` (a crianca nunca fica sem controle).
func _hop_chain(a: MemberActor, targets: Array) -> void:
	if a == null:
		return
	_set_busy(true)
	_hop_serial += 1
	var serial := _hop_serial
	for p: Vector3 in targets:
		a.jump_to(p + Vector3(0, 0.04, 0), HOP_TIME, HOP_HEIGHT + maxf(0.0, p.y - a.global_position.y) * 0.5)
		var ok := await _await_landing(a, p + Vector3(0, 0.04, 0), HOP_TIME + HOP_GRACE)
		if not is_inside_tree() or serial != _hop_serial:
			return
		if not ok:
			hop_aborted.emit()
			break
	_set_busy(false)
	refresh()


## Espera o pouso do salto atual; false se o salto sumiu (interrompido) ou passou do limite.
func _await_landing(a: MemberActor, to: Vector3, limit: float) -> bool:
	# Limite contado no passo de fisica; o salto e um Tween no passo de processo. Num quadro lento (varios passos de
	# fisica antes do Tween andar, ex.: Engine.time_scale alto no bot) o limite estourava com o salto ainda no ar e bom.
	# Espera ate HOP_HARD_LIMIT vezes o limite enquanto o ator segue no ar (salto realmente perdido ainda aborta).
	var t := 0.0
	while t < limit * HOP_HARD_LIMIT:
		await get_tree().physics_frame
		if not is_inside_tree() or not is_instance_valid(a):
			return false
		if not a.airborne:
			return a.global_position.distance_to(to) < 0.1
		t += get_physics_process_delta_time()
	return false


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
