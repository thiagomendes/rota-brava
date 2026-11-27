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
## Varal (G18): as pecas penduram na corda REAL do mundo, lida do marcador M2_Clothesline (metadados `rope`, a polilinha
## de 13 pontos do tubo do wv2_static, e `rope_slots`, as 3 vagas livres em t ao longo dela; ambos gerados por
## source_art/environment_v2/build_world_v2.py). O pivo de cada roupa (props_v3) e a boca do prendedor: vai no centro da
## corda, com X ao longo dela (inclinacao incluida). Antes: 3 ganchos numa reta a -23 graus (a corda vai a +23), 1,58 m
## sobre o marcador (a corda passa a ~1,75 m) e com o centro da peca 0,17 m abaixo, no meio de 5 panos fixos do cenario.
## Cesto ao pe do varal (fora do barril e da moita vizinhos); as pecas soltas deitam dentro dele, dobradas (escala
## BASKET_FOLD: o cesto oval tem 0,62 x 0,47 m por dentro e a camiseta aberta 0,57 x 0,43) e empilhadas sem se atravessar;
## no voo para o varal elas desdobram (escala volta a 1).
const BASKET_FROM_LINE := Vector3(0.6, 0, -0.9)
const BASKET_YAW_DEG := 23.0
## Altura do fundo util do cesto (topo da toalha dobrada do modelo `basket`, source_art/props_v3/build_props_v3.py).
const BASKET_FLOOR := 0.197
## Onde cada peca deita no cesto (local do cesto: x ao longo do comprimento, z na largura) e o giro dela em graus.
const BASKET_SPOTS: Array[Vector3] = [Vector3(0.0, 0.0, 0.0), Vector3(-0.14, 0.0, 0.0), Vector3(0.15, 0.0, 0.0)]
const BASKET_TURN: Array[float] = [0.0, 90.0, -80.0]
const BASKET_FOLD: Array[float] = [0.7, 0.8, 0.95]
## Galho da arvore do varal (wv3_world.bank_extras): rumo horizontal e raio no ponto do marcador M2_TreeBranch, que fica
## 0,12 m acima do eixo do galho.
const BRANCH_DIR := Vector3(-0.86, 0.0, 0.5)
const BRANCH_RADIUS := 0.107
const BRANCH_MARKER_LIFT := 0.12
## Fallback sem metadado: reta antiga corrigida (rumo +23 graus, corda a 1,75 m).
const LINE_YAW_DEG := 23.0
const LINE_HEIGHT := 1.75
const LINE_SLOTS: Array[float] = [-0.7, 0.0, 0.7]
## Carrinho a frente da Leme (m) e cores das cargas (barraca -> cor do caixote).
const CART_AHEAD := 1.05
const STALL_COLORS := {&"M4_Stall_Apple": Color("e0412b"), &"M4_Stall_Lemon": Color("f2c81d"), &"M4_Stall_Grapes": Color("4a6fd8")}
const CARGO_ORDER: Array[StringName] = [&"M4_Stall_Apple", &"M4_Stall_Lemon", &"M4_Stall_Grapes"]
const CART_STATIC_SHAPE := "Collision/Props/cart_1_0"
## G6: os 3 caixotes ficam em fila sobre o fundo do carrinho (topo do fundo a 0,65 m no kit `cart`; vao interno
## 1,22 x 0,72 m), nao empilhados nem afundados nas laterais. Caixote 0,42 x 0,32 m em escala 0,92: 3 x 0,386 m com
## 1,4 cm entre eles. Conferido por tests/test_prop_overlap.gd.
const CARGO_FLOOR := 0.652
const CARGO_SCALE := 0.92
const CARGO_SLOTS: Array[float] = [-0.4, 0.0, 0.4]
const CART_KIT_INDEX := 1
## G18: onde o caixote entregue fica, no local da barraca (+z = lado do cliente; balcao ate z 0,63 m).
const STALL_DROP := Vector3(0.7, 0.0, 0.95)
## G6: topo da grade do M3 acima do marcador M3_Grate (medido por tests/prop_overlap.gd). A bola final tem origem no chao
## e recebia +0,16 m como o bloco provisorio (origem no centro): flutuava 4,1 cm na grade e 15,6 cm nas barracas.
const BALL_GRATE_TOP := 0.119
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
## Pecas que ficam no mundo depois da missao (roupas no varal depois do M2); `clear()` nao apaga.
var _after: Node3D
var _basket: Node3D


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
	points[&"Basket"] = line + BASKET_FROM_LINE
	for i in 3:
		points[StringName("LineSlot_%d" % i)] = line_slot(i).origin
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
			return _mk(&"M2_Clothesline") + Vector3(-1.2, 0, -0.9)
		&"M4":
			return _mk(&"M3_BallStop") + Vector3(1.2, 0, 0.6)
	return Vector3.INF


## G18: polilinha da corda do varal (mundo). Vazia se o mundo nao trouxer o metadado.
func rope_points() -> PackedVector3Array:
	var mk := world.marker(&"M2_Clothesline") if world != null else null
	if mk == null or not mk.has_meta(&"rope"):
		return PackedVector3Array()
	return mk.get_meta(&"rope") as PackedVector3Array


## G18: ponto da corda no parametro t (0..1, polilinha de passos iguais) com a base da peca pendurada: X ao longo da
## corda (com a inclinacao), Y para cima, Z = frente do pano.
func rope_frame(t: float) -> Transform3D:
	var pts := rope_points()
	if pts.size() < 2:
		var line := _mk(&"M2_Clothesline")
		var b := Basis(Vector3.UP, deg_to_rad(LINE_YAW_DEG))
		return Transform3D(b, line + b * Vector3((t - 0.5) * 2.0 * LINE_SLOTS[2] / 0.115, LINE_HEIGHT, 0))
	var f := clampf(t, 0.0, 1.0) * (pts.size() - 1)
	var i := mini(pts.size() - 2, int(f))
	var p := pts[i].lerp(pts[i + 1], f - i)
	var x := (pts[i + 1] - pts[i]).normalized()
	var z := x.cross(Vector3.UP).normalized()
	return Transform3D(Basis(x, z.cross(x), z), p)


## G18: vaga `i` (0..2) do varal: transformacao da raiz da roupa pendurada (pivo = boca do prendedor no centro da corda).
func line_slot(i: int) -> Transform3D:
	var mk := world.marker(&"M2_Clothesline") if world != null else null
	var slots := PackedFloat32Array([0.385, 0.5, 0.615])
	if mk != null and mk.has_meta(&"rope_slots"):
		slots = mk.get_meta(&"rope_slots") as PackedFloat32Array
	if rope_points().size() < 2:
		var b := Basis(Vector3.UP, deg_to_rad(LINE_YAW_DEG))
		return Transform3D(b, _mk(&"M2_Clothesline") + b * Vector3(LINE_SLOTS[i], LINE_HEIGHT, 0))
	return rope_frame(slots[i])


## Caixa da peca no espaco local da raiz dela (todas as malhas, sem a animacao do no `Cloth`).
static func piece_local_aabb(n: Node3D) -> AABB:
	var out := AABB()
	var first := true
	var inv := n.global_transform.affine_inverse()
	for mi: Node in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		var b: AABB = (inv * m.global_transform) * m.mesh.get_aabb()
		out = b if first else out.merge(b)
		first = false
	return out


## Para a animacao da peca (sway/shake) e zera a pose do no `Cloth`: deitada no cesto, no telhado ou no chao.
static func still(n: Node3D) -> void:
	var ap := n.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap != null:
		ap.stop()
	var c := n.get_node_or_null(^"Cloth") as Node3D
	if c != null:
		c.rotation = Vector3.ZERO


## Menor y (no espaco da base `b`) dos vertices da peca: o ponto que encosta no apoio.
static func piece_low(n: Node3D, b: Basis) -> float:
	var low := INF
	var inv := n.global_transform.affine_inverse()
	for mi: Node in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		var xf := inv * m.global_transform
		for v in m.mesh.get_faces():
			low = minf(low, (b * (xf * v)).y)
	return 0.0 if low == INF else low


## Roupa deitada (pano na horizontal) com o meio em `at` (x, z) e o ponto mais baixo em `at.y`; `yaw` em graus; `fold` =
## escala (roupa dobrada). `tilt` (graus) levanta o pano da horizontal (0 = deitado, 90 = em pe, pendurada).
func lay_flat_xf(n: Node3D, at: Vector3, yaw: float, fold: float = 1.0, tilt: float = 0.0) -> Transform3D:
	var bx := piece_local_aabb(n)
	var b := Basis(Vector3.UP, deg_to_rad(yaw)) * Basis(Vector3.RIGHT, deg_to_rad(tilt) - PI / 2.0) \
		* Basis.from_scale(Vector3.ONE * fold)
	var c := b * bx.get_center()
	var o := Vector3(at.x - c.x, at.y - piece_low(n, b) + 0.002, at.z - c.z)
	return Transform3D(b, o)


func handles(id: StringName) -> bool:
	return id in [&"M1", &"M2", &"M3", &"M4"]


# ---------------------------------------------------------------- montagem por missao

func build(id: StringName) -> void:
	clear()
	mission_id = id
	_ensure_after()
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
	_keep_after()
	spots.clear()
	_pieces.clear()
	_hung = 0
	_paw_next = 0
	_stream_next = 0
	_cargo = 0
	_hop_serial += 1
	_basket = null
	_set_busy(false)
	if _root != null:
		_root.queue_free()
		_root = null
	mission_id = &""


# ---------------------------------------------------------------- estado depois da missao (G18)

## Holder das pecas que ficam no mundo depois da missao (fora do `_root`, que `clear()` apaga).
func _after_root() -> Node3D:
	if _after == null or not is_instance_valid(_after):
		_after = Node3D.new()
		_after.name = "After"
		add_child(_after)
	return _after


## Missao concluida: o que ela deixou no mundo fica (antes sumia quando a missao seguinte montava): M2 as 3 roupas no
## varal e o cesto; M4 os 3 caixotes entregues na frente das barracas.
func _keep_after() -> void:
	var keep: Array = []
	if mission_id == &"M2" and _hung >= 3:
		keep = _pieces + ([_basket] if _basket != null else [])
	elif mission_id == &"M4" and _cargo >= CARGO_ORDER.size() and _root != null:
		for c in _root.get_children():
			if c.get_meta(&"delivered", false):
				keep.append(c)
	if keep.is_empty():
		return
	var h := _after_root()
	for p: Node in keep:
		if is_instance_valid(p):
			p.reparent(h, true)
			p.set_meta(&"after_of", mission_id)
	_basket = null


## Retomada pelo salvo (ou missao comecada depois): monta o que as missoes ja concluidas deixaram no mundo.
func _ensure_after() -> void:
	if main == null:
		return
	if _mission_done(&"M2") and not _has_after(&"M2"):
		var h := _after_root()
		for i in Ep01V3Pieces.CLOTHS.size():
			var c := Ep01V3Pieces.cloth(h, "ClothHung_%d" % i, Color.WHITE, i)
			c.set_meta(&"after_of", &"M2")
			c.global_transform = line_slot(i)
			Ep01V3Pieces.play(c, &"sway")
		var b := Ep01V3Pieces.final(h, "basket", "Basket")
		if b != null:
			b.set_meta(&"after_of", &"M2")
			b.global_position = _floor_at(points[&"Basket"])
			b.rotation.y = deg_to_rad(BASKET_YAW_DEG)
	if _mission_done(&"M4") and not _has_after(&"M4"):
		var h := _after_root()
		for st: StringName in CARGO_ORDER:
			var c := Ep01V3Pieces.crate(h, "Crate_" + String(st), STALL_COLORS[st], st)
			c.set_meta(&"after_of", &"M4")
			c.scale = Vector3.ONE * CARGO_SCALE
			c.global_transform = stall_drop_xf(st, c)


func _has_after(id: StringName) -> bool:
	if _after == null or not is_instance_valid(_after):
		return false
	for c in _after.get_children():
		if c.get_meta(&"after_of", &"") == id and not c.is_queued_for_deletion():
			return true
	return false


## G18: caixote entregue no chao, na frente da barraca (lado do cliente), ao lado do painel do balcao. O balcao e todo
## ocupado pelos caixotes de produtos do kit `stall`; antes o caixote ia para 0,95 m acima do marcador e 0,5 m alem dele,
## no ar (95 cm sem apoio).
func stall_drop_xf(stall: StringName, crate: Node3D) -> Transform3D:
	var m := _mk(stall)
	var c := Vector3(m.x, 0.0, m.z)
	var yaw := 0.0
	var kind := {&"M4_Stall_Apple": "stall_red", &"M4_Stall_Lemon": "stall_yellow", &"M4_Stall_Grapes": "stall_blue"}
	var best := INF
	for r: Array in (world.layout.get("kit", {}) as Dictionary).get(kind.get(stall, ""), []):
		var p := Vector3(float(r[0]), 0.0, float(r[2]))
		var d := p.distance_to(c)
		if d < best and d < 2.5:
			best = d
			yaw = deg_to_rad(float(r[3]))
			c = p
	if best == INF:
		c = m - (m - Vector3(c.x, 0, c.z)).normalized() * 1.4
	var b := Basis(Vector3.UP, yaw)
	var at := _floor_at(c + b * STALL_DROP + Vector3(0, m.y, 0))
	return Transform3D(Basis(Vector3.UP, yaw + deg_to_rad(6.0)).scaled(crate.scale), at)


## O M2 monta de novo (retomada no proprio M2): as roupas do varal saem do estado "depois".
func _drop_after() -> void:
	if _after != null and is_instance_valid(_after):
		for c in _after.get_children():
			if c.get_meta(&"after_of", &"") == &"M2":
				c.queue_free()


func _mission_done(id: StringName) -> bool:
	for m: Mission in main.missions:
		if m.id == id:
			return m.is_completed()
	return false


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
# G18: camiseta deitada no telhado do anexo, lenco preso pelo lado do galho baixo, meia deitada no chao dos juncos; cesto
# no chao ao pe do varal (as soltas deitam nele).
func _build_m2() -> void:
	_drop_after()
	var shed := _cloth(_mk(&"M2_ShedTop"), Color("e85d75"), "ClothShed")
	still(shed)
	shed.global_transform = lay_flat_xf(shed, _mk(&"M2_ShedTop") + Vector3(0.05, 0, 0.3), 200.0)
	var tree := _cloth(_mk(&"M2_TreeBranch"), Color("4fa3e0"), "ClothTree")
	tree.global_transform = branch_xf()
	var reeds := _cloth(_mk(&"M2_ReedsPiece"), Color("f2c81d"), "ClothReeds")
	still(reeds)
	# meia caida de pe entre os juncos, inclinada (deitada ela some no capim alto)
	reeds.global_transform = lay_flat_xf(reeds, _floor_at(_mk(&"M2_ReedsPiece") + Vector3(-0.1, 0, 0.15)), 35.0, 1.0, 62.0)
	_basket = Ep01V3Pieces.final(_root, "basket", "Basket")
	if _basket != null:
		_basket.global_position = _floor_at(points[&"Basket"])
		_basket.rotation.y = deg_to_rad(BASKET_YAW_DEG)
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
	_ball.global_position = _mk(&"M3_Grate") + Vector3(0, BALL_GRATE_TOP + _ball_lift(), 0)
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
	_cargo_box.position = Vector3(0, CARGO_FLOOR, 0)
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
		b.position = Vector3(CARGO_SLOTS[i], 0.0, 0.0)
		b.scale = Vector3.ONE * CARGO_SCALE
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
			FeedbackFx.sparkle(world, piece.global_position)
			_to_basket(piece)
			main.notify_mission(&"piece_freed")
			if id == &"shed_free":
				main.say("ep01.bank.climber.sock_high")
			var base: Vector3 = points[&"ShedBase"] if id == &"shed_free" else points[&"TreeBase"]
			await _hop_chain(actor as MemberActor, [base])
		&"reeds":
			_examine(actor, it)
			_to_basket(_pieces[2])
			if main.notify_mission(&"piece_found"):
				main.say("ep01.bank.tracker.wet_paw")
		&"hang":
			if _hung < 3:
				_fly_xf(_pieces[_hung], line_slot(_hung), 0.45)
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
		crate.set_meta(&"delivered", true)
		_fly_xf(crate, stall_drop_xf(stall, crate), 0.5)
	FeedbackFx.sparkle(world, _mk(stall) + Vector3(0, 1.0, 0))
	_cargo += 1
	_refresh_cargo()
	if _cargo >= CARGO_ORDER.size():
		_release_cart()
		main.say("ep01.market.vendor.gull_hint")
	main.notify_mission(&"cargo_delivered")


## G18: a peca solta voa e deita no cesto, na vaga dela, por cima do que ja esta embaixo (caixas no mundo).
func _to_basket(piece: Node3D) -> void:
	piece.set_meta(&"freed", true)
	_fly_xf(piece, basket_xf(piece), 0.6)


## Onde a peca deita no cesto: vaga fixa por peca (BASKET_SPOTS) e altura = topo do que ja esta no cesto sob ela.
func basket_xf(piece: Node3D) -> Transform3D:
	var k := maxi(0, _pieces.find(piece))
	var bb := Basis(Vector3.UP, deg_to_rad(BASKET_YAW_DEG))
	var base := _floor_at(points[&"Basket"]) if _basket == null else _basket.global_position
	var at := base + bb * BASKET_SPOTS[k] + Vector3(0, BASKET_FLOOR, 0)
	var xf := lay_flat_xf(piece, at, BASKET_YAW_DEG + BASKET_TURN[k], BASKET_FOLD[k])
	var mine: AABB = xf * piece_local_aabb(piece)
	for other in _pieces:
		if other == piece or not other.get_meta(&"in_basket", false):
			continue
		var ob: AABB = (other.get_meta(&"basket_xf") as Transform3D) * piece_local_aabb(other)
		var flat_a := Rect2(mine.position.x, mine.position.z, mine.size.x, mine.size.z)
		var flat_b := Rect2(ob.position.x, ob.position.z, ob.size.x, ob.size.z)
		if flat_a.intersects(flat_b):
			at.y = maxf(at.y, ob.end.y + 0.004)
	xf = lay_flat_xf(piece, at, BASKET_YAW_DEG + BASKET_TURN[k], BASKET_FOLD[k])
	piece.set_meta(&"in_basket", true)
	piece.set_meta(&"basket_xf", xf)
	still(piece)
	return xf


## G18: lenco preso pelo lado do galho baixo (fora da casca), com X ao longo do galho e o pano virado para o varal.
func branch_xf() -> Transform3D:
	var axis := _mk(&"M2_TreeBranch") - Vector3(0, BRANCH_MARKER_LIFT, 0)
	var x := BRANCH_DIR.normalized()
	var out := Vector3(-x.z, 0, x.x)
	if out.dot(_mk(&"M2_Clothesline") - axis) < 0.0:
		out = -out
	var z := out
	return Transform3D(Basis(x, Vector3.UP, z) if x.cross(Vector3.UP).dot(z) > 0.0 else Basis(-x, Vector3.UP, z),
		axis + out * (BRANCH_RADIUS + 0.03) + Vector3(0, 0.02, 0))


## Voo com giro (quaternio) e escala ate a transformacao final; a raiz das pecas e identidade (local = mundo).
func _fly_xf(node: Node3D, to: Transform3D, t: float) -> void:
	var tw := node.create_tween().set_parallel(true)
	tw.tween_property(node, "global_position", to.origin, t).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(node, "quaternion", to.basis.get_rotation_quaternion(), t)
	tw.tween_property(node, "scale", to.basis.get_scale(), t)


func _fly(node: Node3D, to: Vector3, t: float) -> void:
	var tw := node.create_tween()
	tw.tween_property(node, "global_position", to, t).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


func _roll_ball() -> void:
	if _ball == null:
		return
	var to := _mk(&"M3_BallStop") + Vector3(0, _ball_lift(), 0)
	var tw := _ball.create_tween().set_parallel(true)
	tw.tween_property(_ball, "global_position", to, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# G6: a bola final gira no filho Spin (centro); girar a raiz (ponto de contato) afundava a bola no chao ao rolar.
	tw.tween_property(_ball.get_node_or_null("Spin") if _ball.has_node("Spin") else _ball, "rotation:x", -TAU * 2.0, 1.4)


## Altura da origem da bola acima do chao: a bola final tem origem no ponto de contato (centro no filho Spin a 0,16 m);
## o bloco provisorio tem origem no centro.
func _ball_lift() -> float:
	return 0.0 if _ball.has_node("Spin") else 0.16


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
