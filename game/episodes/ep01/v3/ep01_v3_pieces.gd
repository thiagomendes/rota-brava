class_name Ep01V3Pieces
extends RefCounted
## Pecas das missoes do Ep01 v3 (RB-R1 E4/E5): UM ponto de troca por peca. Hoje sao blocos PROVISORIOS; quando o art3d
## entregar os modelos finais (game/assets/models/props_v3/), basta trocar o corpo da funcao da peca (ou instanciar a cena
## dela) mantendo a assinatura: quem chama so usa o Node3D devolvido (posicao, rotacao, visibilidade).
## Todas as pecas saem com metadata `provisional` enquanto forem blocos.

const PROVISIONAL := &"provisional"
## Modelos finais do art3d (feature/rb-r1-props-v3): se a cena existe, ela entra; senao, o bloco provisorio.
const PROPS_DIR := "res://assets/models/props_v3/%s.tscn"
const CLOTHS: Array[String] = ["cloth_tshirt", "cloth_scarf", "cloth_sock"]
const CRATES := {&"M4_Stall_Apple": "crate_apple", &"M4_Stall_Lemon": "crate_lemon", &"M4_Stall_Grapes": "crate_grapes"}
const EMBLEMS := {&"tracker": "emblem_paw", &"climber": "emblem_carabiner", &"pilot": "emblem_helm"}


## Instancia o modelo final `id` (ou null se ainda nao existe na base).
static func final(parent: Node, id: String, n: String = "") -> Node3D:
	var path := PROPS_DIR % id
	if not ResourceLoader.exists(path):
		return null
	var s := (load(path) as PackedScene).instantiate() as Node3D
	if s == null:
		return null
	s.name = n if n != "" else id
	parent.add_child(s)
	return s


static func play(n: Node, anim: StringName) -> void:
	var ap := n.find_child("AnimationPlayer", true, false) as AnimationPlayer if n != null else null
	if ap != null and ap.has_animation(anim):
		ap.play(anim)


static func _done(n: Node3D) -> Node3D:
	n.set_meta(PROVISIONAL, true)
	return n


## M2: peca de roupa do varal.
static func cloth(parent: Node, n: String, color: Color, index: int = -1) -> Node3D:
	if index >= 0 and index < CLOTHS.size():
		var f := final(parent, CLOTHS[index], n)
		if f != null:
			return f
	return _done(Blocks.box(parent, n, Vector3(0.42, 0.34, 0.04), Vector3.ZERO, color))


## M3: folhas que entopem a bacia.
static func leaves(parent: Node, n: String = "Leaves") -> Node3D:
	var f := final(parent, "fountain_leaves", n)
	if f != null:
		return f
	return _done(Blocks.box(parent, n, Vector3(0.5, 0.08, 0.5), Vector3.ZERO, Color("5c8a2e")))


## M3: bola do filhote (raio 0,16 m; origem no centro).
static func ball(parent: Node, n: String = "Ball") -> Node3D:
	var f := final(parent, "ball", n)
	if f != null:
		return f
	return _done(Blocks.sphere(parent, n, 0.16, Vector3.ZERO, Color("e8452c")))


## M4: caixote de fruta (origem na base).
static func crate(parent: Node, n: String, color: Color, stall: StringName = &"") -> Node3D:
	if CRATES.has(stall):
		var f := final(parent, CRATES[stall], n)
		if f != null:
			return f
	var root := Node3D.new()
	root.name = n
	parent.add_child(root)
	Blocks.box(root, "Mesh", Vector3(0.42, 0.26, 0.32), Vector3(0, 0.13, 0), color, 0.15)
	return _done(root)


## G19 (M4): caixinha de feira da barraca (pega com as duas maos; origem no fundo). As caixas grandes ficam no carrinho.
const FRUIT_BOXES := {&"M4_Stall_Apple": "fruit_box_apple", &"M4_Stall_Lemon": "fruit_box_lemon",
	&"M4_Stall_Grapes": "fruit_box_grapes"}


static func fruit_box(parent: Node, n: String, color: Color, stall: StringName = &"") -> Node3D:
	if FRUIT_BOXES.has(stall):
		var f := final(parent, FRUIT_BOXES[stall], n)
		if f != null:
			return f
	var root := Node3D.new()
	root.name = n
	parent.add_child(root)
	Blocks.box(root, "Mesh", Vector3(0.16, 0.09, 0.13), Vector3(0, 0.045, 0), color, 0.1)
	return _done(root)


## M4: placa de cor da barraca.
static func stall_sign(parent: Node, n: String, color: Color) -> Node3D:
	var s := Blocks.cylinder(parent, n, 0.22, 0.04, Vector3.ZERO, color, 0.6)
	s.rotation.x = PI / 2.0
	return _done(s)


## Emblema (moeda que gira), origem no chao.
static func emblem(parent: Node, member: StringName = &"") -> Node3D:
	var f := final(parent, EMBLEMS.get(member, "emblem_star"), "Coin")
	if f != null:
		f.position = Vector3(0, 0.75, 0)
		play(f, &"spin")
		return f
	var coin := Blocks.cylinder(parent, "Coin", 0.26, 0.06, Vector3(0, 0.75, 0), Color("ffc93c"), 0.9)
	coin.rotation.x = PI / 2.0
	var tw := coin.create_tween().set_loops()
	tw.tween_property(coin, "rotation:y", TAU, 2.4).from(0.0)
	return _done(coin)


## Seta de ajuda (ponta para baixo, origem na ponta).
static func help_arrow(parent: Node) -> Node3D:
	var f := final(parent, "help_arrow", "HelpArrow")
	if f != null:
		return f
	var arrow := Node3D.new()
	arrow.name = "HelpArrow"
	parent.add_child(arrow)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("ffd23f")
	mat.emission_enabled = true
	mat.emission = Color("ffb000")
	mat.emission_energy_multiplier = 1.2
	var cone := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.28
	cm.bottom_radius = 0.0
	cm.height = 0.5
	cone.mesh = cm
	cone.material_override = mat
	arrow.add_child(cone)
	var stem := MeshInstance3D.new()
	var sm := CylinderMesh.new()
	sm.top_radius = 0.1
	sm.bottom_radius = 0.1
	sm.height = 0.4
	stem.mesh = sm
	stem.material_override = mat
	stem.position.y = 0.45
	arrow.add_child(stem)
	return _done(arrow)


## M5: gaivota com o peixe no bico (origem nos pes). O peixe e o filho "Fish" (soltar = reparent).
static func gull_with_fish(parent: Node) -> Node3D:
	var f := final(parent, "gull", "Gull")
	if f != null:
		play(f, &"perch_idle")
		var fish_node := fish(f)
		fish_node.visible = false
		if "carrying_fish" in f:
			f.set("carrying_fish", true)
		return f
	var root := Node3D.new()
	root.name = "Gull"
	parent.add_child(root)
	Blocks.sphere(root, "Body", 0.16, Vector3(0, 0.22, 0), Color("f4f6f8"))
	Blocks.sphere(root, "Head", 0.09, Vector3(0, 0.38, -0.12), Color("f4f6f8"))
	Blocks.box(root, "WingL", Vector3(0.32, 0.03, 0.14), Vector3(-0.22, 0.27, 0.02), Color("9aa7b4"))
	Blocks.box(root, "WingR", Vector3(0.32, 0.03, 0.14), Vector3(0.22, 0.27, 0.02), Color("9aa7b4"))
	Blocks.box(root, "Beak", Vector3(0.04, 0.03, 0.08), Vector3(0, 0.37, -0.22), Color("f2a51d"))
	var fi := fish(root)
	fi.position = Vector3(0, 0.33, -0.3)
	return _done(root)


## M5: peixe roubado.
static func fish(parent: Node) -> Node3D:
	var f := final(parent, "fish", "Fish")
	if f != null:
		return f
	var root := Node3D.new()
	root.name = "Fish"
	parent.add_child(root)
	Blocks.box(root, "Body", Vector3(0.06, 0.1, 0.28), Vector3.ZERO, Color("7fb3c9"), 0.1)
	Blocks.box(root, "Tail", Vector3(0.04, 0.12, 0.06), Vector3(0, 0, 0.16), Color("5d93ad"))
	return _done(root)


## M5/M6/M7: corda esticada entre dois pontos (cilindro fino; refeito a cada chamada de `aim_rope`).
static func rope(parent: Node, n: String = "Rope") -> Node3D:
	var f := final(parent, "tow_rope", n)
	if f != null:
		f.set_meta(&"final_rope", true)
		return f
	var root := Node3D.new()
	root.name = n
	parent.add_child(root)
	var m := Blocks.cylinder(root, "Line", 0.025, 1.0, Vector3.ZERO, Color("d9b779"))
	m.rotation.x = PI / 2.0
	return _done(root)


## Estica a corda de `a` a `b` (coordenadas do mundo).
static func aim_rope(r: Node3D, a: Vector3, b: Vector3) -> void:
	var d := b - a
	if r.get_meta(&"final_rope", false):
		# PropsV3TowRope: trecho de 1 m para +Z a partir da origem; `length` estica.
		r.global_position = a
		if d.length() > 0.01:
			r.look_at(b, Vector3.UP if absf(d.normalized().y) < 0.99 else Vector3.RIGHT)
			r.rotate_object_local(Vector3.UP, PI)
		r.set("length", d.length())
		return
	r.global_position = a.lerp(b, 0.5)
	r.scale = Vector3(1, 1, maxf(d.length(), 0.01))
	if d.length() > 0.01:
		r.look_at(b, Vector3.UP if absf(d.normalized().y) < 0.99 else Vector3.RIGHT)


## M7/M8: icones dos 4 barquinhos da festa (proposta v3: estrela, lua, peixe, flor; SVG da marca, RB-R1 E7).
const FESTA_BOAT_ICONS: Array[StringName] = [&"star", &"moon", &"fish", &"flower"]


## M7/M8: placa com icone sobre um barquinho da festa (Sprite3D sempre de frente). `lit` acende.
static func boat_icon(parent: Node, n: String, icon: StringName) -> Sprite3D:
	var s := Sprite3D.new()
	s.name = n
	s.texture = IconView.texture_for(icon)
	s.pixel_size = 0.0035
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.modulate = Color(0.55, 0.6, 0.7)
	parent.add_child(s)
	_done(s)
	return s


static func light_boat_icon(s: Sprite3D, lit: bool) -> void:
	s.modulate = Color(1.0, 0.92, 0.55) if lit else Color(0.55, 0.6, 0.7)
	s.set_meta(&"lit", lit)


## M7: bussola da Leme (rosa dos ventos no chao, origem no chao).
static func compass(parent: Node) -> Node3D:
	var root := Node3D.new()
	root.name = "Compass"
	parent.add_child(root)
	Blocks.cylinder(root, "Disc", 0.45, 0.06, Vector3(0, 0.03, 0), Color("e8dcc0"))
	var needle := Blocks.box(root, "Needle", Vector3(0.08, 0.04, 0.7), Vector3(0, 0.08, 0), Color("d23c2c"), 0.3)
	needle.set_meta(&"needle", true)
	return _done(root)
