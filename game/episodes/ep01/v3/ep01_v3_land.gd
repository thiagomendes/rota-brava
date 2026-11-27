class_name Ep01V3Land
extends Node3D
## Missoes M1-M4 em terra do Ep01 v3 (RB-R1 E4). Monta, por missao, os pontos de acao (Ep01Interactable), as pecas
## provisorias (roupas, bola, carrinho, caixotes) e os pontos derivados dos marcadores da vila; informa a Mission
## pelos eventos reais (`main.notify_mission`). Nada aqui le entrada: o jogador (ou o bot) aperta `interact` e a
## Ep01V3Main dispara o ponto mais perto. Erro nunca castiga (entrega errada so mostra a barraca certa).
##
## G19: toda acao acontece no jogo (camera solta, sem corte): o heroi pega o objeto com a mao (HoldPoint), leva, pousa
## ou pendura com um clipe curto; o Pico ESCALA (climb_up*/climb_wall/climb_top/climb_down) pelos degraus marcados no mundo
## (galpao 0,45/0,95/1,53 m; chafariz 0,5/1,0/1,5 m), sem salto. Cada subida e UM aperto; depois de soltar/puxar, ele desce.
## Pontos derivados (no proprio no, nunca no mundo do art3d): base do galpao, base da arvore, base do chafariz,
## cesto e 3 ganchos do varal, carrinho dirigivel. Todos PROVISORIOS.

signal busy_changed(busy: bool)
## Um salto da cadeia do Pico foi interrompido (sem pouso); a cadeia parou e `busy` foi solto.
signal hop_aborted

const PROVISIONAL := &"provisional"
## G19: o mesmo "agir" durante uma acao acelera o resto dela este tanto.
const SKIP_RATE := 4.0
## Escalada do Pico: clipes de 1,0 a 1,33 s tocados a esta velocidade (0,6 a 0,8 s por degrau); parede mais rapida ainda.
const CLIMB_SPEED := 1.6
const WALL_BOOST := 1.8
## Passinhos programados dentro de uma acao (m/s).
const STEP_WALK := 2.0
## Medidas dos clipes do Pico (source_art/characters/pico_v2/pico_v2.info.json, chave "g19"): face do degrau a frente do
## ator no inicio, avanco do corpo no fim do climb_up*/climb_down, borda acima do ator no climb_top, subida do climb_wall.
const WALL_FACE := 0.203
const CLIMB_FWD := 0.3028
const TOP_UP := 0.7887
const WALL_MPS := 0.25
## Folga extra ate a face do degrau antes de subir (a borda de pedra/telha sobressai da face medida pelo raio).
const FACE_MARGIN := 0.06
## Descida: o pe pousa um pouco mais longe da borda que o clipe (a base do degrau pode sobressair).
const DOWN_MARGIN := 0.12
## Desnivel ate onde basta um passo com impulso (sem clipe de escalar).
const STEP_UP_MAX := 0.4
## Descida menor que isto: pulinho para baixo (o climb_down desce 0,9 m; corrigir 0,4 m faz a ponta do pe mergulhar).
const CLIMB_DOWN_MIN := 0.65
## Subida sem parede (o galho da arvore): o corpo passa este tanto acima da borda e assenta no climb_top.
const NO_WALL_OVER := 0.45
## G19 (M2): banco do varal (props_v3 `clothes_bench`): tampo 0,90 m e degrau 0,45 m; a corda passa sobre a borda de tras
## (z -0,20 local). Em pe no tampo (z -0,06) a mao erguida do place_high (0,81-0,88 m, 0,13 m a frente) chega na corda
## (~1,75 m). A corda do mundo nao desceu: rebaixar pede refazer o wv2_static; o banco cobre a altura.
const BENCH_TOP := 0.90
const BENCH_STEP := 0.45
const BENCH_BACK := -0.20
const BENCH_STAND := Vector3(0, 0.90, -0.06)
const BENCH_STEP_STAND := Vector3(0, 0.45, 0.36)
const BENCH_GROUND := Vector3(0, 0.0, 0.78)
const BENCH_LEN := 2.0
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
const BASKET_SPOTS: Array[Vector3] = [Vector3(0.0, 0.0, 0.0), Vector3(-0.10, 0.0, 0.0), Vector3(0.15, 0.0, 0.0)]
const BASKET_TURN: Array[float] = [0.0, 90.0, -80.0]
## G19: o lenco deita um pouco mais dobrado (0,74): vindo da mao (pose parada) a 0,8 ele encostava 2,5 cm na borda do cesto.
## G25: lenco do filhote nos juncos (rumo, inclinacao em graus a partir de deitado) e raio sem capim em volta dele.
const REEDS_YAW := 35.0
const REEDS_TILT := 78.0
const REEDS_GRASS_R := 0.35
## Raio (m) em volta do cesto sem capim do kit (o cesto oval tem ~0,34 m de meia-largura).
const BASKET_GRASS_R := 0.55
const BASKET_FOLD: Array[float] = [0.7, 0.74, 0.95]
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
## G19: caixas grandes um pouco para tras no fundo do carrinho e as caixinhas (0,16 x 0,13 m) na frente de cada uma;
## a Leme ergue a caixinha parada ao lado do carrinho (palmas a ~0,27 m a frente no place_low) e pousa no chao a
## ~0,23 m a frente (pick_up).
const CRATE_Z := -0.06
const BOX_Z := 0.21
const BOX_REACH := 0.28
const BOX_DROP_REACH := 0.23
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
var _bench: Node3D
var _cart_said: bool = false
## Quantos tufos de capim/flor sairam de baixo do cesto (pendencia do G18).
var grass_cleared: int = 0
## G19: acoes em curso (heroi tomado) e a espera segurada por fora (_set_busy); `busy` = qualquer um dos dois.
var _acts: int = 0
var _hold: bool = false
var _rate: float = 1.0
var _act_actors: Array[MemberActor] = []
var _grips: Dictionary = {}
## Objeto na mao agora (G19) e quem segura.
var carried: Node3D = null
var carrier: MemberActor = null
## G19b (C): peca pousada no chao pelo heroi antigo na troca de heroi (M2/M4); qualquer heroi a pega de novo.
var ground_piece: Node3D = null
## Registros para os testes: cada passagem pela mao, cada clipe tocado e cada apoio da escalada.
var hand_log: Array[Dictionary] = []
var clip_log: Array[Dictionary] = []
var climb_log: Array[Dictionary] = []


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
	_bench = null
	_drop_carried()
	ground_piece = null
	for a in _act_actors:
		if is_instance_valid(a):
			a.scripted = false
			_anim_rate(a, 1.0)
	_act_actors.clear()
	_acts = 0
	_rate = 1.0
	_hold = false
	_sync_busy()
	if _root != null:
		_root.queue_free()
		_root = null
	mission_id = &""


## G19: a missao foi desmontada com algo na mao: a peca sai da mao (some com a missao, que a criou) e as maos ficam livres.
func _drop_carried() -> void:
	if carrier != null and is_instance_valid(carrier):
		carrier.hands = &""
	if carried != null and is_instance_valid(carried) and carried.get_parent() != null \
			and carried.get_parent().name == &"G19Grip":
		carried.get_parent().remove_child(carried)
		carried.queue_free()
	carried = null
	carrier = null
	for a in main.actors.values() if main != null else []:
		if is_instance_valid(a) and (a as MemberActor).hands == &"push":
			(a as MemberActor).hands = &""


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
		keep = _pieces + ([_basket] if _basket != null else []) + ([_bench] if _bench != null else [])
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
	_bench = null


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
		var bench := _make_bench(h)
		bench.set_meta(&"after_of", &"M2")
		_clear_grass(_floor_at(points[&"Basket"]), BASKET_GRASS_R)
	if _mission_done(&"M4") and not _has_after(&"M4"):
		var h := _after_root()
		for st: StringName in CARGO_ORDER:
			var c := Ep01V3Pieces.fruit_box(h, "Box_" + String(st), STALL_COLORS[st], st)
			c.set_meta(&"after_of", &"M4")
			c.set_meta(&"stall", st)
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
		# sem a barraca do kit por perto: 1,4 m do marcador para o lado do carrinho, no plano (antes o desvio era
		# (m - (m.x, 0, m.z)), so em y: o caixote ia para o alto)
		var toward := _mk(&"M4_Cart") - m
		toward.y = 0.0
		toward = toward.normalized() if toward.length() > 0.01 else Vector3.BACK
		c = Vector3(m.x, 0.0, m.z) + toward * 1.4
		yaw = atan2(toward.x, toward.z)
	var b := Basis(Vector3.UP, yaw)
	var at := _floor_at(c + b * (STALL_DROP if best < INF else Vector3.ZERO) + Vector3(0, m.y, 0))
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
	# G25: lenco do filhote caido de pe entre os juncos, quase em pe e com o capim aberto em volta (deitado ou baixo ele
	# some no capim alto; a meia era mais alta)
	reeds.global_transform = lay_flat_xf(reeds, _floor_at(_mk(&"M2_ReedsPiece") + Vector3(-0.1, 0, 0.15)), REEDS_YAW, 1.0, REEDS_TILT)
	_clear_grass(reeds.global_position, REEDS_GRASS_R)
	_basket = Ep01V3Pieces.final(_root, "basket", "Basket")
	if _basket != null:
		_basket.global_position = _floor_at(points[&"Basket"])
		_basket.rotation.y = deg_to_rad(BASKET_YAW_DEG)
	_spot(&"shed_climb", points[&"ShedBase"], &"carabiner", "ui.action.climb", &"climber")
	_spot(&"shed_free", _mk(&"M2_ShedTop"), &"rope", "ui.action.free", &"climber", 1.2)
	_spot(&"tree_climb", points[&"TreeBase"], &"carabiner", "ui.action.climb", &"climber")
	_spot(&"tree_free", _mk(&"M2_TreeBranch"), &"rope", "ui.action.free", &"climber", 1.2)
	_spot(&"reeds", _mk(&"M2_ReedsPiece"), &"paw", "ui.action.examine", &"tracker")
	_clear_grass(_floor_at(points[&"Basket"]), BASKET_GRASS_R)
	_bench = _make_bench(_root)
	_spot(&"basket", _floor_at(points[&"Basket"]), &"rope", "ui.action.pick", &"", 1.4)
	_spot(&"hang", bench_point(1, BENCH_GROUND), &"rope", "ui.action.hang", &"", 1.6)
	# Pegadinhas molhadas do cesto aos juncos.
	var a: Vector3 = points[&"Basket"]
	var b := _mk(&"M2_ReedsPiece")
	for i in 3:
		_decal("decal_paw_wet_big", a.lerp(b, 0.25 + i * 0.25), b)
	_emblem(&"emb_m2_shed", _mk(&"M2_ShedTop") + Vector3(-0.55, 0, -0.25), &"climber")
	_emblem(&"emb_m2_reeds", b + Vector3(0.9, 0, 0.3), &"tracker")


## G19: banco do varal ao longo da corda, do lado oposto ao cesto (do lado dele ha um barril), com a borda de tras sob a corda (no meio das 3 vagas).
## X = ao longo da corda, Z = para fora (lado do degrau). Tem colisao (camada 1): ninguem atravessa o banco.
func bench_xf() -> Transform3D:
	var mid := (line_slot(0).origin + line_slot(2).origin) * 0.5
	var x := line_slot(2).origin - line_slot(0).origin
	x.y = 0.0
	x = x.normalized()
	var z := Vector3(-x.z, 0, x.x)
	var basket: Vector3 = points[&"Basket"]
	if z.dot(basket - mid) > 0.0:
		z = -z
	var at := Vector3(mid.x, 0, mid.z) - z * BENCH_BACK
	# chao do mundo, sem o proprio banco (o raio pararia no tampo dele)
	var skip: Array[RID] = []
	for b in get_tree().get_nodes_in_group(&"g19_bench"):
		skip.append((b as CollisionObject3D).get_rid())
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(
		Vector3(at.x, mid.y, at.z), Vector3(at.x, mid.y - 4.0, at.z), 1, skip))
	at.y = (hit.position as Vector3).y if not hit.is_empty() else mid.y - 1.75
	return Transform3D(Basis(x, Vector3.UP, z), at)


## G19: pe da subida no galho: de lado para o galho (rumo BRANCH_DIR), no chao, do lado do varal; o Pico agarra a lateral
## do galho e passa por cima dele (subir pela ponta do galho fazia a perna atravessar a madeira).
func tree_climb_foot() -> Vector3:
	var axis := _mk(&"M2_TreeBranch")
	var side := Vector3(-BRANCH_DIR.z, 0, BRANCH_DIR.x).normalized()
	if side.dot(points[&"TreeBase"] - axis) < 0.0:
		side = -side
	return _floor_at(Vector3(axis.x, 0.0, axis.z) + side * 0.45)


## Pendencia do G18: os tufos de capim do kit atravessavam o cesto. As instancias de capim a ate `r` m do cesto somem
## (escala ~0, como o carrinho do M4); o mundo do art3d nao e regravado.
func _clear_grass(at: Vector3, r: float) -> void:
	var kit: Dictionary = world.layout.get("kit", {})
	for kind: String in ["grass_tuft", "grass_tall", "flowers_a", "flowers_b"]:
		var mmi := world.get_node_or_null("Kit/" + kind) as MultiMeshInstance3D
		if mmi == null or mmi.multimesh == null:
			continue
		var rows: Array = kit.get(kind, [])
		for i in mini(rows.size(), mmi.multimesh.instance_count):
			var row: Array = rows[i]
			var p := Vector3(float(row[0]), float(row[1]), float(row[2]))
			if Vector2(p.x - at.x, p.z - at.z).length() < r:
				mmi.multimesh.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * 0.0001), p))
				grass_cleared += 1


## Ponto `local` do banco (BENCH_GROUND/BENCH_STEP_STAND/BENCH_STAND) na altura da vaga `i` do varal.
func bench_point(i: int, local: Vector3) -> Vector3:
	var xf := bench_xf()
	var along := (line_slot(i).origin - xf.origin).dot(xf.basis.x)
	return xf * Vector3(along, local.y, local.z)


func _make_bench(parent: Node) -> Node3D:
	var b := Ep01V3Pieces.final(parent, "clothes_bench", "ClothesBench")
	if b == null:
		b = Blocks.box(parent, "ClothesBench", Vector3(BENCH_LEN, BENCH_TOP, 0.36), Vector3(0, BENCH_TOP / 2.0, -0.02),
			Color("c99a68"))
		b.set_meta(PROVISIONAL, true)
	b.global_transform = bench_xf()
	var body := StaticBody3D.new()
	body.name = "Collision"
	body.collision_layer = 1
	body.collision_mask = 0
	body.add_to_group(&"g19_bench")
	b.add_child(body)
	for box: Array in [[Vector3(BENCH_LEN, BENCH_TOP, 0.36), Vector3(0, BENCH_TOP / 2.0, -0.02)],
			[Vector3(BENCH_LEN, BENCH_STEP, 0.28), Vector3(0, BENCH_STEP / 2.0, 0.30)]]:
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = box[0]
		cs.shape = sh
		cs.position = box[1]
		body.add_child(cs)
	return b


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
	_cart_said = false
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


## G19: monta a carga UMA vez: as 3 caixas grandes (ficam no carrinho) e, na frente de cada uma, a caixinha daquela
## barraca. Entregar tira so a caixinha da barraca (antes: `get_child(0)` e tudo recriado a cada entrega).
func _refresh_cargo() -> void:
	if _cargo_box.get_child_count() > 0:
		return
	for i in CARGO_ORDER.size():
		var col: Color = STALL_COLORS[CARGO_ORDER[i]]
		var b := Ep01V3Pieces.crate(_cargo_box, "Crate%d" % i, col, CARGO_ORDER[i])
		b.position = Vector3(CARGO_SLOTS[i], 0.0, CRATE_Z)
		b.scale = Vector3.ONE * CARGO_SCALE
		b.set_meta(&"stall", CARGO_ORDER[i])
		var box := Ep01V3Pieces.fruit_box(_cargo_box, "Box%d" % i, col, CARGO_ORDER[i])
		box.position = Vector3(CARGO_SLOTS[i], 0.0, BOX_Z)
		box.set_meta(&"stall", CARGO_ORDER[i])
		box.set_meta(&"box", true)
		box.set_meta(&"slot", i)


func cargo_stall() -> StringName:
	return CARGO_ORDER[_cargo] if _cargo < CARGO_ORDER.size() else &""


func _attach_cart(actor: MemberActor) -> void:
	cart_holder = actor
	if actor != null:
		actor.hands = &"push"


func _release_cart() -> void:
	if cart_holder != null and is_instance_valid(cart_holder) and cart_holder.hands == &"push":
		cart_holder.hands = &""
	cart_holder = null
	_update_take_cart()


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
	for g: MemberActor in _grips.keys():
		_update_grip(g)
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
					var holding := carried != null
					_enable(&"shed_climb", not shed_done and not on_top and not on_tree and not holding)
					_enable(&"shed_free", not shed_done and on_top)
					_enable(&"tree_climb", not tree_done and shed_done and not on_top and not on_tree and not holding)
					_enable(&"tree_free", not tree_done and on_tree)
					_enable(&"basket", holding)
				&"find_third":
					_enable(&"reeds", carried == null and not _pieces[2].get_meta(&"freed", false))
					_enable(&"basket", carried != null)
				&"hang":
					_enable(&"basket", carried == null and _hung < 3)
					_enable(&"hang", carried != null)
			if spots.has(&"basket"):
				(spots[&"basket"] as Ep01Interactable).label_key = "ui.action.deliver" if carried != null else "ui.action.pick"
			# o ponto fica na frente do meio do banco (andavel); a acao leva o heroi ate a vaga da roupa
			if spots.has(&"hang"):
				(spots[&"hang"] as Ep01Interactable).global_position = bench_point(1, BENCH_GROUND)
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
					_enable(&"take_cart", cart_holder == null and carried == null and _cargo < CARGO_ORDER.size())
					for st: StringName in CARGO_ORDER:
						_enable(StringName("deliver_" + String(st)), cart_holder != null or carried != null)
	_enable(&"pick_ground", ground_piece != null and is_instance_valid(ground_piece) and carried == null)
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



func _on_spot(id: StringName, actor: Node3D) -> void:
	var it := spots.get(id) as Ep01Interactable
	if it != null and it.get_meta(&"emblem", false):
		if main.find_emblem(id):
			FeedbackFx.ring(world, it.global_position + Vector3(0, 0.7, 0))
			it.queue_free()
			spots.erase(id)
		return
	# G19b (C): so quem carrega poe no cesto, pendura ou entrega (nada sai da mao de outro heroi "por magica")
	if carried != null and carrier != null and actor != carrier \
			and (id == &"basket" or id == &"hang" or String(id).begins_with("deliver_")):
		main.flash_help_target()
		return
	match id:
		&"pick_ground":
			await _act_pick_ground(actor as MemberActor)
		&"bench":
			_examine(actor, it)
			if main.notify_mission(&"paw_examined"):
				main.say("ep01.dock.tracker.small_print")
		&"boot":
			await _act_boot(actor as MemberActor)
			if main.notify_mission(&"boot_examined"):
				main.say("ep01.dock.tracker.boot_captain")
				main.say("ep01.dock.tracker.two_trails")
		&"paw_1", &"paw_2", &"paw_3", &"paw_4":
			FeedbackFx.pulse(world, it.global_position)
			_paw_next += 1
			if main.notify_mission(&"paw_followed") and _paw_next == 4:
				main.say("ep01.bank.tracker.pup_village")
		&"shed_climb":
			await _act_climb(actor as MemberActor, [_mk(&"M2_ShedStep_1"), _mk(&"M2_ShedStep_2"), _mk(&"M2_ShedTop")])
		&"tree_climb":
			await _act_climb(actor as MemberActor, [tree_climb_foot(), _mk(&"M2_TreeBranch")])
		&"shed_free", &"tree_free":
			var piece := _pieces[0] if id == &"shed_free" else _pieces[1]
			piece.set_meta(&"event", &"piece_freed")
			if id == &"shed_free":
				main.say("ep01.bank.climber.sock_high")
			var down: Array = [_mk(&"M2_ShedStep_2"), _mk(&"M2_ShedStep_1"), points[&"ShedBase"]] if id == &"shed_free" \
				else [tree_climb_foot(), points[&"TreeBase"]]
			await _act_free_piece(actor as MemberActor, piece, down)
		&"reeds":
			_pieces[2].set_meta(&"event", &"piece_found")
			await _act_find_reeds(actor as MemberActor, it, _pieces[2])
		&"basket":
			if carried != null:
				await _act_to_basket(actor as MemberActor)
			else:
				await _act_from_basket(actor as MemberActor)
		&"hang":
			if _hung < 3 and carried != null:
				await _act_hang(actor as MemberActor)
		&"stream_1", &"stream_2":
			_examine(actor, it)
			_stream_next += 1
			if main.notify_mission(&"stream_followed"):
				main.say("ep01.plaza.tracker.dry_stream" if _stream_next == 1 else "ep01.plaza.tracker.ball_stuck")
		&"fountain_climb":
			await _hop_chain(actor as MemberActor, [_mk(&"M3_FountainStep_1"), _mk(&"M3_FountainStep_2"),
				_mk(&"M3_FountainStep_3"), _mk(&"M3_UpperBasin")])
		&"leaves":
			await _act_pull_leaves(actor as MemberActor)
		&"read_icons":
			_examine(actor, it, [&"point"])
			for st: StringName in CARGO_ORDER:
				FeedbackFx.ring(world, _mk(st) + Vector3(0, 2.1, 0), STALL_COLORS[st])
			if main.notify_mission(&"icons_read"):
				main.say("ep01.market.tracker.read_icon")
		&"take_cart":
			if carried == null:
				_attach_cart(actor as MemberActor)
				if not _cart_said:
					_cart_said = true
					main.say("ep01.market.pilot.cart_go")
		_:
			if String(id).begins_with("deliver_"):
				await _deliver(StringName(String(id).trim_prefix("deliver_")), actor as MemberActor)
	refresh()


## G19 (M4): entrega em dois "agir", sem nada voar. 1) Na barraca certa, empurrando o carrinho: a Leme solta a alca, vai
## ao lado do carrinho e ergue a caixinha daquela barraca DA POSICAO DELA (place_low de tras para frente); as outras e as
## caixas grandes nao se mexem. O controle volta com a caixinha nas maos. 2) Na frente da barraca: abaixa e pousa no chao
## (pick_up de tras para frente). Depois ela pega o carrinho de novo (take_cart).
func _deliver(stall: StringName, a: MemberActor = null) -> void:
	if a == null:
		a = _actor()
	var want := cargo_stall()
	if carried != null and carried.has_meta(&"stall"):
		want = carried.get_meta(&"stall")
	if stall != want:
		# Sem castigo: a feirante aponta a barraca certa; a carga continua onde esta.
		main.say(Ep01V3Dialogue.pick("oops.vendor", "ep01.market.vendor.wrong_stall"))
		FeedbackFx.ring(world, _mk(want) + Vector3(0, 2.1, 0), STALL_COLORS[want])
		main.flash_help_target()
		return
	if carried != null:
		await _act_drop_box(a, stall)
	else:
		await _act_lift_box(a, stall)


func cargo_box(stall: StringName) -> Node3D:
	if _cargo_box == null or not is_instance_valid(_cargo_box):
		return null
	for c in _cargo_box.get_children():
		if c.get_meta(&"box", false) and c.get_meta(&"stall", &"") == stall:
			return c as Node3D
	return null


func _act_lift_box(a: MemberActor, stall: StringName) -> void:
	var box := cargo_box(stall)
	if a == null or box == null:
		return
	var s := _act_begin(a)
	_release_cart()
	_update_take_cart()
	var side := cart.global_basis.z
	side.y = 0.0
	side = side.normalized()
	var stand := box.global_position + side * BOX_REACH
	stand.y = a.global_position.y
	if not await _step_walk(a, _floor_at(stand), s):
		_act_end(a, s)
		return
	a.face_now(box.global_position)
	var L := _clip(a, &"place_low", 1.3, true)
	if not await _wait(L * 0.5, s):
		_act_end(a, s)
		return
	_take(a, box, true, _box_local(box))
	FeedbackFx.sparkle(world, box.global_position)
	if not await _wait(L * 0.5, s):
		_act_end(a, s)
		return
	_rest(a)
	_act_end(a, s)


func _act_drop_box(a: MemberActor, stall: StringName) -> void:
	var box := carried
	if a == null or box == null:
		return
	var s := _act_begin(a)
	var to := stall_drop_xf(stall, box)
	var away := a.global_position - to.origin
	away.y = 0.0
	var stand := to.origin + (away.normalized() if away.length() > 0.01 else -a.facing()) * BOX_DROP_REACH
	if not await _step_walk(a, _floor_at(stand), s):
		_act_end(a, s)
		return
	a.face_now(to.origin)
	var L := _clip(a, &"pick_up", 1.2, true)
	if not await _wait(L * 0.5, s):
		_act_end(a, s)
		return
	if not await _put(box, _root, to, 0.08, s):
		_act_end(a, s)
		return
	box.set_meta(&"delivered", true)
	FeedbackFx.sparkle(world, _mk(stall) + Vector3(0, 1.0, 0))
	_cargo += 1
	if _cargo >= CARGO_ORDER.size():
		main.say("ep01.market.vendor.gull_hint")
		main.say("ep01.market.vendor.gull_hint_b")
	main.notify_mission(&"cargo_delivered")
	if not await _wait(L * 0.4, s):
		_act_end(a, s)
		return
	_act_end(a, s)


## O ponto "empurrar" fica onde o carrinho esta agora (ele so anda com a Leme na alca).
func _update_take_cart() -> void:
	if spots.has(&"take_cart") and is_instance_valid(cart):
		(spots[&"take_cart"] as Ep01Interactable).global_position = cart.global_position


# ---------------------------------------------------------------- G19: M1 (bota na mao)

## O Rastro abaixa e pega a bota (pick_up), olha com ela nas maos e pousa de volta no mesmo lugar (pick_up ao contrario).
func _act_boot(a: MemberActor) -> void:
	var boot := _root.get_node_or_null(^"CaptainBoot") as Node3D if _root != null else null
	if a == null or boot == null:
		return
	var home := boot.global_transform
	var s := _act_begin(a)
	a.face_now(boot.global_position)
	var L := _clip(a, &"pick_up", 1.0)
	if not await _wait(L * 0.5, s):
		_act_end(a, s)
		return
	_take(a, boot, true, _box_local(boot))
	if not await _wait(L * 0.5 + 0.35, s):
		_act_end(a, s)
		return
	var L2 := _clip(a, &"pick_up", 1.2, true)
	if not await _wait(L2 * 0.5, s):
		_act_end(a, s)
		return
	if not await _put(boot, _root, home, 0.1, s):
		_act_end(a, s)
		return
	if not await _wait(L2 * 0.4, s):
		_act_end(a, s)
		return
	_act_end(a, s)


# ---------------------------------------------------------------- G19: M3 (folhas com pull_rope)

## O Pico abaixa e agarra o bolo de folhas (pick_up), da os puxoes com esforco (pull_rope) e joga para fora do chafariz:
## as folhas saem da mao num arco e caem no chao. A agua volta, a bola rola e ele desce escalando.
func _act_pull_leaves(a: MemberActor) -> void:
	var leaves := _pieces[0] if not _pieces.is_empty() else null
	if a == null or leaves == null:
		return
	var s := _act_begin(a)
	a.face_now(leaves.global_position)
	var L := _clip(a, &"pick_up", 1.0)
	if not await _wait(L * 0.5, s):
		_act_end(a, s)
		return
	_take(a, leaves, false, Transform3D(Basis(), Vector3(0, -0.04, 0)))
	if not await _wait(L * 0.5, s):
		_act_end(a, s)
		return
	FeedbackFx.splash(world, _mk(&"M3_UpperBasin") + Vector3(0, 0.3, 0))
	if not await _wait(_clip(a, &"pull_rope", 2.0), s):
		_act_end(a, s)
		return
	# arremesso: sai da mao em arco ate o chao ao pe do chafariz
	var from := leaves.global_position
	var land_at := _floor_at(points[&"FountainBase"] + Vector3(0.6, 0.0, 0.0))
	var to := rest_xf(leaves, land_at, 20.0)
	leaves.reparent(_root, true)
	leaves.remove_meta(&"in_hand")
	carried = null
	carrier = null
	a.hands = &""
	var q0 := leaves.global_basis.get_rotation_quaternion()
	if not await _over(0.45, s, func(k: float) -> void:
		if is_instance_valid(leaves):
			var p := from.lerp(to.origin, k)
			p.y += 0.6 * 4.0 * k * (1.0 - k)
			leaves.global_transform = Transform3D(Basis(q0.slerp(to.basis.get_rotation_quaternion(), k)), p)):
		_act_end(a, s)
		return
	main.say("ep01.plaza.climber.top_basin")
	main.notify_mission(&"leaves_pulled")
	main.say("ep01.lumi.lantern_2")
	_roll_ball()
	if not await _climb_chain(a, [_mk(&"M3_FountainStep_2"), _mk(&"M3_FountainStep_1"), points[&"FountainBase"]], s):
		_act_end(a, s)
		return
	_act_end(a, s)


# ---------------------------------------------------------------- G19: M2 (soltar, levar, cesto, banco, varal)

## Soltar a roupa no alto (galpao ou galho): o Pico chega perto, abaixa e pega (pick_up: a roupa vai para a mao, dobrada)
## e desce escalando com ela. No chao o controle volta: a crianca leva a roupa ate o cesto.
func _act_free_piece(a: MemberActor, piece: Node3D, down: Array) -> void:
	if a == null:
		return
	var s := _act_begin(a)
	var at := piece.global_position
	var near := Vector3(at.x, a.global_position.y, at.z)
	var away := a.global_position - near
	away.y = 0.0
	if away.length() > 0.3:
		if not await _step_walk(a, near + away.normalized() * 0.3, s):
			_act_end(a, s)
			return
	a.face_now(at)
	var L := _clip(a, &"pick_up", 1.0)
	if not await _wait(L * 0.5, s):
		_act_end(a, s)
		return
	piece.set_meta(&"freed", true)
	_take(a, piece, true, _flat_local(piece, BASKET_FOLD[maxi(0, _pieces.find(piece))]))
	FeedbackFx.sparkle(world, piece.global_position)
	if not await _wait(L * 0.5, s):
		_act_end(a, s)
		return
	if not await _climb_chain(a, down, s):
		_act_end(a, s)
		return
	_rest(a)
	_act_end(a, s)


## Juncos: o Rastro examina (inspect), abaixa e pega a meia (pick_up); leva na mao ate o cesto.
func _act_find_reeds(a: MemberActor, it: Ep01Interactable, piece: Node3D) -> void:
	if a == null:
		return
	var s := _act_begin(a)
	a.face_now(piece.global_position)
	if not await _wait(_clip(a, &"inspect", 1.8), s):
		_act_end(a, s)
		return
	var L := _clip(a, &"pick_up", 1.0)
	if not await _wait(L * 0.5, s):
		_act_end(a, s)
		return
	piece.set_meta(&"freed", true)
	_take(a, piece, true, _flat_local(piece, BASKET_FOLD[2]))
	main.say("ep01.bank.tracker.wet_paw")
	if not await _wait(L * 0.5, s):
		_act_end(a, s)
		return
	_rest(a)
	_act_end(a, s)
	if it != null:
		FeedbackFx.pulse(world, it.global_position)


## Cesto: abaixa (pick_up de tras para frente) e deixa a roupa deitada dentro, na vaga dela; a missao conta aqui.
func _act_to_basket(a: MemberActor) -> void:
	var piece := carried
	if a == null or piece == null:
		return
	var s := _act_begin(a)
	var target := basket_xf(piece)
	a.face_now(target.origin)
	var L := _clip(a, &"pick_up", 1.2, true)
	if not await _wait(L * 0.5, s):
		_act_end(a, s)
		return
	if not await _put(piece, _root, target, 0.1, s):
		_act_end(a, s)
		return
	var ev: StringName = piece.get_meta(&"event", &"piece_freed")
	main.notify_mission(ev)
	if not await _wait(L * 0.4, s):
		_act_end(a, s)
		return
	_act_end(a, s)


## Cesto, na hora de pendurar: pega a roupa de cima da pilha (pick_up) e leva dobrada nas maos.
func _act_from_basket(a: MemberActor) -> void:
	if a == null:
		return
	var piece: Node3D = null
	var best := -INF
	for p in _pieces:
		if p.get_meta(&"in_basket", false) and not p.get_meta(&"hung", false) and p.global_position.y > best:
			best = p.global_position.y
			piece = p
	if piece == null:
		return
	var s := _act_begin(a)
	a.face_now(piece.global_position)
	var L := _clip(a, &"pick_up", 1.0)
	if not await _wait(L * 0.5, s):
		_act_end(a, s)
		return
	piece.set_meta(&"in_basket", false)
	_take(a, piece, true, _flat_local(piece, BASKET_FOLD[maxi(0, _pieces.find(piece))]))
	if not await _wait(L * 0.5, s):
		_act_end(a, s)
		return
	_rest(a)
	_act_end(a, s)


## Varal: no pe do banco, sobe o degrau e o tampo (pulinhos), ergue a roupa (place_high) e prende na corda na vaga da vez;
## desce para o chao. A roupa passa da mao para a corda no alto do gesto.
func _act_hang(a: MemberActor) -> void:
	var piece := carried
	if a == null or piece == null:
		return
	# cada roupa tem a vaga dela no varal (camiseta, lenco, meia: como no G18), qualquer que seja a ordem de pegar
	var k := clampi(_pieces.find(piece), 0, 2)
	var s := _act_begin(a)
	var back := -bench_xf().basis.z
	if not await _step_walk(a, bench_point(k, BENCH_GROUND), s):
		_act_end(a, s)
		return
	if not await _hop_to(a, bench_point(k, BENCH_STEP_STAND), 0.24, 0.3, s):
		_act_end(a, s)
		return
	if not await _hop_to(a, bench_point(k, BENCH_STAND), 0.24, 0.3, s):
		_act_end(a, s)
		return
	a.face_now(a.global_position + back)
	var L := _clip(a, &"place_high", 1.3)
	if not await _wait(L * 0.5, s):
		_act_end(a, s)
		return
	if not await _put(piece, _root, line_slot(k), 0.08, s):
		_act_end(a, s)
		return
	piece.set_meta(&"hung", true)
	Ep01V3Pieces.play(piece, &"sway")
	_hung += 1
	FeedbackFx.sparkle(world, line_slot(k).origin)
	if not await _wait(L * 0.5, s):
		_act_end(a, s)
		return
	if not await _hop_to(a, bench_point(k, BENCH_STEP_STAND), 0.2, 0.12, s):
		_act_end(a, s)
		return
	if not await _hop_to(a, bench_point(k, BENCH_GROUND), 0.22, 0.12, s):
		_act_end(a, s)
		return
	main.notify_mission(&"piece_hung")
	if _hung == 3:
		main.say("ep01.bank.tracker.next_clue")
	_act_end(a, s)


# ---------------------------------------------------------------- G19b (C): troca de heroi com peca na mao

## Distancia (m) a frente do heroi onde ele pousa a peca no chao, e as direcoes tentadas (frente, lados, tras).
const SET_DOWN_REACH := 0.42
const SET_DOWN_DIRS: Array[float] = [0.0, 50.0, -50.0, 100.0, -100.0, 180.0]


## O jogo trocou o heroi em controle para `a`. No M2 e no M4, se outro heroi esta com a peca na mao, ele a pousa no chao
## a frente dele (place_low), apoiada e sem atravessar nada; quem vier depois pega de novo (ponto `pick_ground`). O M7
## continua com a entrega de mao em mao (`_give`).
func hero_changed(a: Node3D) -> void:
	if carried == null or carrier == null or not is_instance_valid(carrier) or carrier == a:
		return
	if mission_id != &"M2" and mission_id != &"M4":
		return
	_act_set_down(carrier)


## Onde a peca fica deitada/apoiada no chao junto de `a`: a primeira direcao em que ela nao encosta em nada alem do chao.
func ground_xf(piece: Node3D, a: MemberActor) -> Transform3D:
	var yaw := rad_to_deg(a.visual().global_rotation.y)
	var first := Transform3D()
	for i in SET_DOWN_DIRS.size():
		var dir := a.facing().rotated(Vector3.UP, deg_to_rad(SET_DOWN_DIRS[i]))
		dir.y = 0.0
		var at := _floor_at(a.global_position + dir.normalized() * SET_DOWN_REACH + Vector3(0, 0.2, 0))
		var xf := _ground_pose(piece, at, yaw)
		if i == 0:
			first = xf
		if _clear_at(piece, xf):
			return xf
	return first


func _ground_pose(piece: Node3D, at: Vector3, yaw: float) -> Transform3D:
	if piece.has_meta(&"stall"):
		return rest_xf(piece, at, yaw)
	return lay_flat_xf(piece, at, yaw, BASKET_FOLD[clampi(_pieces.find(piece), 0, 2)])


## A caixa da peca em `xf`, erguida 2 cm do apoio, nao toca nada da camada 1 (mundo, banco, cesto, barracas).
func _clear_at(piece: Node3D, xf: Transform3D) -> bool:
	var bx := piece_local_aabb(piece)
	var sh := BoxShape3D.new()
	sh.size = (bx.size * xf.basis.get_scale()).max(Vector3.ONE * 0.01)
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = sh
	var b := xf.basis.orthonormalized()
	q.transform = Transform3D(b, xf * bx.get_center() + Vector3(0, 0.02, 0))
	q.collision_mask = 1
	return get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()


## O heroi antigo abaixa (place_low) e deixa a peca no chao a frente dele; ela sai da mao no meio do gesto.
func _act_set_down(a: MemberActor) -> void:
	var piece := carried
	if a == null or piece == null:
		return
	var s := _act_begin(a)
	var to := ground_xf(piece, a)
	a.face_now(to.origin)
	var L := _clip(a, &"place_low", 1.3)
	if not await _wait(L * 0.5, s):
		_act_end(a, s)
		return
	if not await _put(piece, _root, to, 0.1, s):
		_act_end(a, s)
		return
	ground_piece = piece
	piece.set_meta(&"on_ground", true)
	_ground_spot(piece)
	if not await _wait(L * 0.4, s):
		_act_end(a, s)
		return
	_rest(a)
	_act_end(a, s)


func _ground_spot(piece: Node3D) -> void:
	var it := spots.get(&"pick_ground") as Ep01Interactable
	if it == null:
		it = _spot(&"pick_ground", piece.global_position, &"rope", "ui.action.pick", &"", 1.3)
	it.global_position = piece.global_position


## Pegar do chao: chega perto, abaixa (place_low de tras para frente) e a peca volta para as maos.
func _act_pick_ground(a: MemberActor) -> void:
	var piece := ground_piece
	if a == null or piece == null or not is_instance_valid(piece) or carried != null:
		return
	var s := _act_begin(a)
	var at := piece.global_position
	var away := a.global_position - at
	away.y = 0.0
	if away.length() > SET_DOWN_REACH + 0.05:
		if not await _step_walk(a, _floor_at(at + away.normalized() * SET_DOWN_REACH + Vector3(0, 0.2, 0)), s):
			_act_end(a, s)
			return
	a.face_now(at)
	var L := _clip(a, &"place_low", 1.3, true)
	if not await _wait(L * 0.5, s):
		_act_end(a, s)
		return
	if not is_instance_valid(piece) or ground_piece != piece:
		_act_end(a, s)
		return
	ground_piece = null
	piece.remove_meta(&"on_ground")
	var local := _box_local(piece) if piece.has_meta(&"stall") \
		else _flat_local(piece, BASKET_FOLD[clampi(_pieces.find(piece), 0, 2)])
	_take(a, piece, true, local)
	if not await _wait(L * 0.5, s):
		_act_end(a, s)
		return
	_rest(a)
	_act_end(a, s)


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


## Examinar no jogo: o clipe `inspect` dos 3 herois (G19; antes so havia `crouch`/`point`), acelerado para ~1 s; quem
## olha para longe (placas, cata-vento) aponta; agradecer acena. O gesto cede se a crianca voltar a andar.
func _examine(actor: Node3D, it: Ep01Interactable, prefer: Array[StringName] = [&"inspect", &"crouch", &"point"]) -> void:
	var a := actor as MemberActor
	if a != null and it != null:
		a.face_now(it.global_position)
		for anim: StringName in prefer + [&"inspect", &"point"]:
			if a.model != null and a.model.has_animation(anim):
				a.play_action(anim, 1.4 if anim == &"inspect" else 1.0)
				clip_log.append({"member": a.member, "clip": anim, "backwards": false})
				break


# ---------------------------------------------------------------- G19: acoes no jogo (gesto curto, objeto na mao)
## Cada acao comeca com UM "agir" e roda no jogo, com a camera solta: a missao toma o corpo do heroi (`scripted`), toca o
## clipe e move o objeto pela mao (BoneAttachment3D nos ossos HoldPoint/HoldPoint_L); o controle volta no fim. O mesmo
## "agir" durante a acao acelera o resto dela (SKIP_RATE). `_hop_serial` muda quando a missao e desmontada: toda acao em
## curso para, e clear() solta o heroi e o objeto (ninguem fica preso).

func _sync_busy() -> void:
	var on := _hold or _acts > 0
	if busy != on:
		busy = on
		busy_changed.emit(on)


## Segura a Land ocupada (cortes, atracacao, testes), sem heroi tomado.
func _set_busy(on: bool) -> void:
	_hold = on
	_sync_busy()


func _act_begin(a: MemberActor) -> int:
	_acts += 1
	if a != null and is_instance_valid(a):
		a.scripted = true
		a.velocity = Vector3.ZERO
		if not a in _act_actors:
			_act_actors.append(a)
	_sync_busy()
	return _hop_serial


## Fim da acao (so a da montagem atual: uma acao velha interrompida nao mexe na contagem da nova).
func _act_end(a: MemberActor, serial: int) -> void:
	if serial != _hop_serial:
		return
	_acts = maxi(0, _acts - 1)
	if a != null and is_instance_valid(a):
		a.scripted = false
		a.velocity = Vector3.ZERO
		_act_actors.erase(a)
		_anim_rate(a, 1.0)
	if _acts == 0:
		_rate = 1.0
	_sync_busy()
	refresh()


## O mesmo "agir" durante a acao: o resto dela corre SKIP_RATE vezes mais rapido. False se nao ha acao.
func skip_action() -> bool:
	if _acts <= 0:
		return false
	_rate = SKIP_RATE
	for a in _act_actors:
		if is_instance_valid(a):
			_anim_rate(a, SKIP_RATE)
	return true


func _anim_rate(a: MemberActor, k: float) -> void:
	if a != null and a.model != null and a.model.animation_player() != null:
		a.model.animation_player().speed_scale = k


## Espera `t` s de jogo (acelerado pelo pular). False se a montagem mudou no meio (a acao para).
func _wait(t: float, serial: int) -> bool:
	var e := 0.0
	while e < t:
		await get_tree().physics_frame
		if not is_inside_tree() or serial != _hop_serial:
			return false
		if get_tree().paused:
			continue   # G19b (A): na pausa a acao congela (corpo e peca parados)
		e += get_physics_process_delta_time() * _rate
	return true


## Chama `f(k)` a cada passo de fisica com k de 0 a 1 em `t` s (acelerado pelo pular); termina em k = 1.
func _over(t: float, serial: int, f: Callable) -> bool:
	var e := 0.0
	f.call(0.0)
	while e < t:
		await get_tree().physics_frame
		if not is_inside_tree() or serial != _hop_serial:
			return false
		if get_tree().paused:
			continue   # G19b (A): na pausa a acao congela (corpo e peca parados)
		e += get_physics_process_delta_time() * _rate
		f.call(clampf(e / maxf(t, 0.001), 0.0, 1.0))
	return true


## Toca um clipe do heroi (para frente ou de tras para frente) e devolve a duracao em s de jogo.
func _clip(a: MemberActor, anim: StringName, speed: float = 1.0, backwards: bool = false) -> float:
	if a == null or a.model == null or not a.model.has_animation(anim):
		return 0.0
	a.play_action(anim, speed)   # marca o tempo da acao (a selecao automatica espera o fim)
	if backwards:
		a.model.animation_player().play(anim, 0.08, -speed, true)
	_anim_rate(a, _rate)
	clip_log.append({"member": a.member, "clip": anim, "backwards": backwards})
	return a.model.animation_length(anim) / maxf(speed, 0.01)


## Pose parada das maos (vazia, carregando ou empurrando), sem crossfade longo.
func _rest(a: MemberActor) -> void:
	if a == null or a.model == null:
		return
	var want := &"idle"
	if a.hands == &"carry" and a.model.has_animation(&"carry_idle"):
		want = &"carry_idle"
	a.model.play(want, 1.0, 0.06)


## Ponto de pega: a mao direita (HoldPoint) ou o meio das duas palmas, com a base do heroi (frente = -Z).
func _grip(a: MemberActor, two: bool) -> Node3D:
	var sk := a.model.skeleton() if a.model != null else null
	var holder: Node3D = sk if sk != null else a
	var g := holder.get_node_or_null(^"G19Grip") as Node3D
	if g == null:
		g = Node3D.new()
		g.name = "G19Grip"
		holder.add_child(g)
	if sk != null:
		for bone: String in ["HoldPoint", "HoldPoint_L"]:
			if sk.get_node_or_null("G19_" + bone) == null and sk.find_bone(bone) >= 0:
				var att := BoneAttachment3D.new()
				att.name = "G19_" + bone
				att.bone_name = bone
				sk.add_child(att)
	g.set_meta(&"two", two)
	_grips[a] = g
	_update_grip(a)
	return g


func _update_grip(a: MemberActor) -> void:
	var g := _grips.get(a) as Node3D
	if g == null or not is_instance_valid(g) or not is_instance_valid(a):
		return
	var sk := a.model.skeleton() if a.model != null else null
	var p := a.global_position + Vector3(0, 0.55, 0) + a.facing() * 0.23
	if sk != null and a.model != null:
		# pose atual dos ossos (o esqueleto anda em modo manual; o BoneAttachment3D pode estar um quadro atras)
		var r := a.model.bone_position(&"HoldPoint")
		var l := a.model.bone_position(&"HoldPoint_L")
		if r != Vector3.INF:
			p = r
			if l != Vector3.INF and g.get_meta(&"two", false):
				p = (r + l) * 0.5
	g.global_transform = Transform3D(a.visual().global_basis.orthonormalized(), p)


func _process(_delta: float) -> void:
	for a: MemberActor in _grips.keys():
		_update_grip(a)
	if mission_id == &"M4" and spots.has(&"take_cart") and cart_holder == null:
		_update_take_cart()


## Pega `piece` com a mao (local = transformacao da peca em relacao ao ponto de pega). Registra a passagem pela mao.
func _take(a: MemberActor, piece: Node3D, two: bool, local: Transform3D) -> void:
	var g := _grip(a, two)
	still(piece)
	piece.reparent(g, false)
	piece.transform = local
	carried = piece
	carrier = a
	a.hands = &"carry"
	piece.set_meta(&"in_hand", a.member)
	hand_log.append({"piece": piece, "member": a.member, "two": two})


## Solta o que esta na mao em `parent`, assentando em `to` (mundo) em `t` s; a peca deixa de ser carregada.
func _put(what: Variant, parent: Node, to: Transform3D, t: float, serial: int) -> bool:
	if not is_instance_valid(what) or not what is Node3D:
		# G19b (B): a peca sumiu no meio; a mao fica livre (quem chama encerra a acao)
		if not is_instance_valid(carried):
			if carrier != null and is_instance_valid(carrier):
				carrier.hands = &""
			carried = null
			carrier = null
		return false
	var piece := what as Node3D
	piece.reparent(parent, true)
	piece.remove_meta(&"in_hand")
	if carried == piece:
		if carrier != null and is_instance_valid(carrier):
			carrier.hands = &""
		carried = null
		carrier = null
	var from := piece.global_transform
	var q0 := from.basis.get_rotation_quaternion()
	var q1 := to.basis.get_rotation_quaternion()
	var s0 := from.basis.get_scale()
	var s1 := to.basis.get_scale()
	return await _over(t, serial, func(k: float) -> void:
		if is_instance_valid(piece):
			piece.global_transform = Transform3D(Basis(q0.slerp(q1, k)).scaled(s0.lerp(s1, k)), from.origin.lerp(to.origin, k)))


## Transformacao local (no ponto de pega) de uma peca chata levada dobrada nas duas maos: deitada, centro na pega.
func _flat_local(piece: Node3D, fold: float) -> Transform3D:
	var bx := piece_local_aabb(piece)
	var b := Basis(Vector3.RIGHT, -PI / 2.0) * Basis.from_scale(Vector3.ONE * fold)
	return Transform3D(b, -(b * bx.get_center()))


## Transformacao local de uma peca com pivo no fundo (caixinha, bussola): o meio da altura na pega.
func _box_local(piece: Node3D) -> Transform3D:
	var bx := piece_local_aabb(piece)
	return Transform3D(Basis(), -Vector3(bx.get_center().x, bx.get_center().y, bx.get_center().z))


## Peca parada apoiada em `at` (ponto mais baixo encostando), girada `yaw` (graus), sem deitar.
func rest_xf(n: Node3D, at: Vector3, yaw: float, s: float = 1.0) -> Transform3D:
	var b := Basis(Vector3.UP, deg_to_rad(yaw)).scaled(Vector3.ONE * s)
	return Transform3D(b, Vector3(at.x, at.y - piece_low(n, b) + 0.002, at.z))


## Passinhos programados (andar ou carregar) ate `to`.
func _step_walk(a: MemberActor, to: Vector3, serial: int) -> bool:
	var from := a.global_position
	var d := to - from
	var flat := Vector3(d.x, 0, d.z)
	if d.length() < 0.03:
		return true
	if flat.length() > 0.03:
		a.face_now(a.global_position + flat)
	var anim := &"carry_walk" if a.hands == &"carry" and a.model != null and a.model.has_animation(&"carry_walk") else &"walk"
	if a.model != null:
		_anim_rate(a, _rate)
		a.model.play(anim, a.model.walk_speed_scale(STEP_WALK))
	var ok := await _over(d.length() / STEP_WALK, serial, func(k: float) -> void:
		if is_instance_valid(a):
			a.global_position = from.lerp(to, k))
	if ok:
		_rest(a)
	return ok


## Pulinho programado (banco do varal): arco curto com o clipe `jump`.
func _hop_to(a: MemberActor, to: Vector3, t: float, h: float, serial: int) -> bool:
	var from := a.global_position
	var flat := Vector3(to.x - from.x, 0, to.z - from.z)
	if flat.length() > 0.03:
		a.face_now(a.global_position + flat)
	if a.model != null and a.model.has_animation(&"jump"):
		_clip(a, &"jump", a.model.animation_length(&"jump") / maxf(t, 0.1))
	var ok := await _over(t, serial, func(k: float) -> void:
		if is_instance_valid(a):
			# subindo: primeiro sobe ate passar a borda, depois avanca; descendo: avanca, depois desce (o pe passa por cima)
			var top := maxf(from.y, to.y) + h
			var p: Vector3
			if to.y > from.y + 0.05:
				var kv := smoothstep(0.0, 0.55, k)
				var kh := smoothstep(0.45, 1.0, k)
				p = from.lerp(to, kh)
				p.y = lerpf(from.y, top, kv) if k < 0.75 else lerpf(top, to.y, smoothstep(0.75, 1.0, k))
			elif to.y < from.y - 0.05:
				var kh2 := smoothstep(0.0, 0.55, k)
				p = from.lerp(to, kh2)
				p.y = lerpf(from.y, top, smoothstep(0.0, 0.25, k)) if k < 0.25 else lerpf(top, to.y, smoothstep(0.25, 1.0, k))
			else:
				p = from.lerp(to, k)
				p.y += h * 4.0 * k * (1.0 - k)
			a.global_position = p)
	if ok:
		_rest(a)
	return ok


## Toca um clipe de escalada parado no lugar (sem root motion: o clipe ja leva o corpo `clip_end` para cima/frente) e corrige
## aos poucos a diferenca ate o apoio real; no fim a origem vai para o apoio e o heroi fica de pe la.
func _clip_move(a: MemberActor, anim: StringName, speed: float, clip_off: Vector3, real_end: Vector3, serial: int) -> bool:
	var start := a.global_position
	var L := _clip(a, anim, speed)
	if L <= 0.0:
		return await _hop_to(a, real_end, 0.4, 0.3, serial)
	var err := real_end - (start + clip_off)
	var ok := await _over(L, serial, func(k: float) -> void:
		if is_instance_valid(a):
			# o excesso de altura do clipe sai so no fim (pe ja no topo); antes, o pe afundaria no chao de partida
			var ky := k * k * k if err.y < 0.0 else smoothstep(0.0, 1.0, k)
			var e := Vector3(err.x, 0, err.z) * smoothstep(0.0, 1.0, k) + Vector3(0, err.y * ky, 0)
			a.global_position = start + e)
	if not ok:
		return false
	a.global_position = real_end
	if a.model != null:
		a.model.play(&"idle", 1.0, 0.0)
	return true


## Altura do chao (camada 1) logo abaixo de `p` (de p.y + 0,4 m para baixo); -INF se nao acha.
func _floor_y(p: Vector3) -> float:
	var hit := get_world_3d().direct_space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(p + Vector3(0, 0.4, 0), p - Vector3(0, 3.0, 0), 1))
	return (hit.position as Vector3).y if not hit.is_empty() else -INF


## Distancia horizontal ate a face do degrau a frente (raio na altura `h` acima dos pes); INF se nao ha face.
func _face_ahead(from: Vector3, dir: Vector3, h: float, reach: float) -> float:
	var o := from + Vector3(0, h, 0)
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(o, o + dir * reach, 1))
	return o.distance_to(hit.position) if not hit.is_empty() else INF


## Um trecho da escalada do Pico ate `to` (pes): andar se o desnivel e pequeno; subir com climb_up_low/climb_up/climb_up_high
## (0,6/0,9/1,2 m) ou parede (climb_wall + climb_top); descer de costas com climb_down (0,9 m; o resto pela parede).
func _climb_to(a: MemberActor, to: Vector3, serial: int, depth: int = 0) -> bool:
	var from := a.global_position
	var dh := to.y - from.y
	var flat := Vector3(to.x - from.x, 0, to.z - from.z)
	var dist := flat.length()
	var dir := flat / dist if dist > 0.01 else a.facing()
	if absf(dh) < 0.15:
		return await _step_walk(a, to, serial)
	var up := Vector3.UP
	if absf(dh) < STEP_UP_MAX:
		# degrau baixo (embasamento, meio-fio): um passo com impulso, nao uma escalada
		return await _hop_to(a, to, 0.3, 0.18, serial)
	if dh > 0.0:
		var face := _face_ahead(from, dir, 0.1, dist + 0.3)
		if face == INF and dh > 1.3:
			# sem parede no chao (galho da arvore): a face e a lateral do proprio apoio, logo abaixo do topo
			face = _face_ahead(from, dir, dh - 0.08, dist + 0.3)
		var start := Vector3(to.x, from.y, to.z) - dir * minf(CLIMB_FWD, dist)
		if face < INF and depth < 4:
			# degrau intermediario que o marcador nao lista (ex.: o embasamento de 0,26 m do chafariz): sobe nele antes
			var over := from + dir * (face + 0.15)
			var tier := _floor_y(Vector3(over.x, to.y + 0.2, over.z))
			if tier > from.y + 0.15 and tier < to.y - 0.15:
				if not await _climb_to(a, Vector3(over.x, tier, over.z), serial, depth + 1):
					return false
				return await _climb_to(a, to, serial, depth + 1)
		if face < INF:
			start = from + dir * (face - WALL_FACE - FACE_MARGIN)
		if not await _step_walk(a, start, serial):
			return false
		a.face_now(a.global_position + dir)
		var top := a.global_position + dir * CLIMB_FWD + up * dh
		if dh <= 1.3:
			var clip := &"climb_up_low" if dh <= 0.65 else (&"climb_up" if dh <= 0.95 else &"climb_up_high")
			var h := 0.6 if clip == &"climb_up_low" else (0.9 if clip == &"climb_up" else 1.2)
			if not await _clip_move(a, clip, CLIMB_SPEED, dir * CLIMB_FWD + up * h, top, serial):
				return false
		else:
			# sem parede achada (tronco, galho): sobe um pouco alem para as pernas passarem por cima da borda
			var rise := dh - TOP_UP + (0.0 if face < INF else NO_WALL_OVER)
			var s := a.global_position
			_clip(a, &"climb_wall", CLIMB_SPEED * WALL_BOOST)
			if not await _over(rise / (WALL_MPS * CLIMB_SPEED * WALL_BOOST), serial, func(k: float) -> void:
				if is_instance_valid(a):
					a.global_position = s + up * rise * k):
				return false
			if not await _clip_move(a, &"climb_top", CLIMB_SPEED, dir * 0.303 + up * TOP_UP, top, serial):
				return false
		return await _step_walk(a, to, serial)
	# descida: anda ate a borda, vira de costas para o vao e desce
	var edge := from
	var step := 0.05
	var kk := step
	while kk <= dist + 0.001:
		var p := from + dir * kk
		if _floor_y(p) < from.y - 0.15:
			break
		edge = p
		kk += step
	if depth < 4:
		var out := edge + dir * 0.3
		var tier := _floor_y(Vector3(out.x, from.y - 0.1, out.z))
		if tier > to.y + 0.15 and tier < from.y - 0.15:
			if not await _climb_to(a, Vector3(out.x, tier, out.z), serial, depth + 1):
				return false
			return await _climb_to(a, to, serial, depth + 1)
	if not await _step_walk(a, edge - dir * 0.04, serial):
		return false
	a.face_now(a.global_position - dir)
	var bottom := a.global_position + dir * (CLIMB_FWD + DOWN_MARGIN) + up * dh
	if dh > -CLIMB_DOWN_MIN:
		if not await _hop_to(a, bottom, 0.32, 0.12, serial):
			return false
	elif dh >= -1.3:
		if not await _clip_move(a, &"climb_down", CLIMB_SPEED, dir * CLIMB_FWD - up * 0.9, bottom, serial):
			return false
	else:
		var mid := a.global_position + dir * CLIMB_FWD - up * 0.9
		if not await _clip_move(a, &"climb_down", CLIMB_SPEED, dir * CLIMB_FWD - up * 0.9, mid, serial):
			return false
		var drop := -dh - 0.9 - 0.15   # o pe do climb_wall fica abaixo da origem: para antes do chao
		var s := a.global_position
		_clip(a, &"climb_wall", CLIMB_SPEED * WALL_BOOST)
		if not await _over(drop / (WALL_MPS * CLIMB_SPEED * WALL_BOOST), serial, func(t: float) -> void:
			if is_instance_valid(a):
				a.global_position = s - up * drop * t):
			return false
		a.global_position = bottom
		_rest(a)
	return await _step_walk(a, to, serial)


## Escalada do Pico por uma lista de apoios (um "agir"): trecho a trecho, sem salto. Dentro de uma acao ja aberta.
func _climb_chain(a: MemberActor, targets: Array, serial: int) -> bool:
	for p: Vector3 in targets:
		if not await _climb_to(a, p, serial):
			return false
		climb_log.append({"member": a.member, "to": p, "at": a.global_position})
	return true


## Uma subida/descida inteira como acao (subir no galpao, no chafariz, nos caixotes, na escada do farol).
func _act_climb(a: MemberActor, targets: Array) -> void:
	if a == null:
		return
	var s := _act_begin(a)
	await _climb_chain(a, targets, s)
	_act_end(a, s)


## G19: os 9 pontos que antes encadeavam saltos (galpao, arvore, chafariz, caixotes do M5, escada do farol; ida e volta)
## agora escalam trecho a trecho (`_climb_to`).
func _hop_chain(a: MemberActor, targets: Array) -> void:
	await _act_climb(a, targets)


# ---------------------------------------------------------------- alvo da ajuda e do bot

## O que avanca a missao agora (alvo da ajuda: gesto, seta e camera). null se o passo nao tem ponto ligado.
func help_target() -> Node3D:
	if _root == null:
		return null
	var best: Ep01Interactable = null
	if mission_id == &"M4" and carried != null and carried.has_meta(&"stall"):
		return spots.get(StringName("deliver_" + String(carried.get_meta(&"stall")))) as Node3D
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
