extends SceneTree
## Gera as cenas proprias do ambiente (RB-04-env) a partir dos GLB importados: cada ativo vira
## res://actors/environment/<id>.tscn = Node3D + `Model` (instancia do GLB) + StaticBody3D com colisao simples FORA do GLB.
## Tambem monta `dock_assembled.tscn` (area do Ep01Layout). Tudo PROVISORIO ate aprovacao.
## Uso (apos --import): ./tools/godot.ps1 --headless --path game --script res://actors/environment/gen_env_scenes.gd

const OUT := "res://actors/environment/"
const GLB := "res://assets/models/environment/"
const AABB_BOX := "aabb_box"
const AABB_CYL := "aabb_cyl"
const NONE := "none"

# id -> [nome da raiz, colisao]. Colisao custom: {"box": [size, center]} ou {"cyl": [raio, altura, center]}
const SPEC := {
	"dock_deck_2m": ["Dock_Deck_2m", AABB_BOX],
	"dock_deck_4m": ["Dock_Deck_4m", AABB_BOX],
	"dock_post": ["Dock_Post", {"cyl": [0.16, 1.0, Vector3(0, 0.5, 0)]}],
	"dock_cleat": ["Dock_Cleat", NONE],
	"dock_fender": ["Dock_Fender", NONE],
	"dock_ladder": ["Dock_Ladder", NONE],
	"dock_edge": ["Dock_Edge", AABB_BOX],
	"dock_pile": ["Dock_Pile", NONE],
	"crate_l": ["Crate_L", AABB_BOX],
	"crate_s": ["Crate_S", AABB_BOX],
	"crate_peach": ["Crate_Peach", AABB_BOX],
	"barrel": ["Barrel", AABB_CYL],
	"rope_coil": ["Rope_Coil", NONE],
	"lantern_post": ["Lantern_Post", {"cyl": [0.1, 2.1, Vector3(0, 1.05, 0)]}],
	"fishing_net": ["Fishing_Net", NONE],
	"sign_board": ["Sign_Board", {"cyl": [0.1, 1.6, Vector3(0, 0.8, 0.06)]}],
	"bucket": ["Bucket", NONE],
	"oar": ["Oar", NONE],
	"cork_buoy": ["Cork_Buoy", NONE],
	"boat_hut": ["Boat_Hut", {"box": [Vector3(3.56, 2.2, 2.96), Vector3(0, 1.1, 0)]}],
	"boot_print": ["BootPrint", NONE],
	"ground_tile_a": ["Ground_Tile_A", {"box": [Vector3(8, 0.4, 13), Vector3(0, -0.2, 0)]}],
	"ground_tile_b": ["Ground_Tile_B", {"box": [Vector3(8, 0.4, 13), Vector3(0, -0.2, 0)]}],
	"ground_tile_path": ["Ground_Tile_Path", {"box": [Vector3(4, 0.4, 13), Vector3(0, -0.2, 0)]}],
	"tree_a": ["Tree_A", {"cyl": [0.28, 2.5, Vector3(0, 1.25, 0)]}],
	"tree_b": ["Tree_B", {"cyl": [0.25, 3.0, Vector3(0, 1.5, 0)]}],
	"tree_c": ["Tree_C", {"cyl": [0.28, 2.5, Vector3(0, 1.25, 0)]}],
	"bush_round": ["Bush_Round", NONE],
	"bush_flower": ["Bush_Flower", NONE],
	"grass_tuft": ["Grass_Tuft", NONE],
	"reeds": ["Reeds", NONE],
	"rock_a": ["Rock_A", AABB_BOX],
	"rock_b": ["Rock_B", AABB_BOX],
	"rock_c": ["Rock_C", AABB_BOX],
	"boat_v2": ["BoatV2", {"box": [Vector3(2.2, 0.8, 5.0), Vector3(0, 0.1, -0.5)]}],
	# RB-R1 kit da vila Farol 7 (style-bible)
	"house_a": ["House_A", {"box": [Vector3(4.4, 6.0, 5.2), Vector3(0, 3.0, 0)]}],
	"house_b": ["House_B", {"box": [Vector3(5.2, 6.0, 5.2), Vector3(0, 3.0, 0)]}],
	"house_c": ["House_C", {"box": [Vector3(5.4, 8.7, 5.8), Vector3(0, 4.35, 0)]}],
	"house_d": ["House_D", {"box": [Vector3(4.2, 3.2, 4.6), Vector3(0, 1.6, 0)]}],
	"market_stall_red": ["Market_Stall_Red", {"box": [Vector3(2.7, 1.0, 0.7), Vector3(0, 0.5, 0.55)]}],
	"market_stall_blue": ["Market_Stall_Blue", {"box": [Vector3(2.7, 1.0, 0.7), Vector3(0, 0.5, 0.55)]}],
	"street_lamp": ["Street_Lamp", {"cyl": [0.15, 3.0, Vector3(0, 1.5, 0)]}],
	"park_bench": ["Park_Bench", AABB_BOX],
	"flower_bed": ["Flower_Bed", AABB_CYL],
	"flower_clump": ["Flower_Clump", NONE],
	"fence_2m": ["Fence_2m", {"box": [Vector3(2.0, 1.0, 0.12), Vector3(0, 0.5, 0)]}],
	"stone_stairs": ["Stone_Stairs", NONE],
	"low_wall": ["Low_Wall", AABB_BOX],
	"quay_block": ["Quay_Block", {"box": [Vector3(8, 1.6, 6), Vector3(0, -0.8, 0)]}],
	"plaza_tile": ["Plaza_Tile", {"box": [Vector3(8, 0.7, 8), Vector3(0, -0.35, 0)]}],
	"lawn_block": ["Lawn_Block", {"box": [Vector3(8, 1.6, 6), Vector3(0, -0.8, 0)]}],
	"terrace_wall": ["Terrace_Wall", {"box": [Vector3(8, 2.7, 0.9), Vector3(0, -1.3, -0.1)]}],
	"lighthouse": ["Lighthouse", {"cyl": [3.2, 19.8, Vector3(0, 9.9, 0)]}],
	"hills_near": ["Hills_Near", NONE],
	"hills_far": ["Hills_Far", NONE],
	"cloud": ["Cloud", NONE],
	"seagull": ["Seagull", NONE],
	"tree_round": ["Tree_Round", {"cyl": [0.3, 2.5, Vector3(0, 1.25, 0)]}],
	"tree_round_dark": ["Tree_Round_Dark", {"cyl": [0.3, 2.2, Vector3(0, 1.1, 0)]}],
	"tree_tall": ["Tree_Tall", {"cyl": [0.3, 2.0, Vector3(0, 1.0, 0)]}],
	"rowboat": ["Rowboat", NONE],
	"bunting": ["Bunting", NONE],
}

var _fail := false


func _initialize() -> void:
	_run.call_deferred()


func _own(n: Node, owner_node: Node) -> void:
	for c in n.get_children():
		c.owner = owner_node
		if c.scene_file_path.is_empty():
			_own(c, owner_node)


func _aabb(model: Node3D) -> AABB:
	return preload("res://tests/test_assets.gd").mesh_aabb(model)


func _make_piece(id: String) -> void:
	var spec: Array = SPEC[id]
	var ps := load(GLB + id + ".glb") as PackedScene
	if ps == null:
		printerr("GLB ausente: ", id)
		_fail = true
		return
	var root := Node3D.new()
	root.name = spec[0]
	root.set_meta("provisional", true)
	var model := ps.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node3D
	model.name = "Model"
	root.add_child(model)
	var col: Variant = spec[1]
	var shape: Shape3D = null
	var center := Vector3.ZERO
	var bb := _aabb(model)
	if col is Dictionary:
		var d := col as Dictionary
		if d.has("box"):
			var b := BoxShape3D.new()
			b.size = d["box"][0]
			shape = b
			center = d["box"][1]
		else:
			var c := CylinderShape3D.new()
			c.radius = d["cyl"][0]
			c.height = d["cyl"][1]
			shape = c
			center = d["cyl"][2]
	elif col == AABB_BOX:
		var b2 := BoxShape3D.new()
		b2.size = bb.size
		shape = b2
		center = bb.get_center()
	elif col == AABB_CYL:
		var c2 := CylinderShape3D.new()
		c2.radius = maxf(bb.size.x, bb.size.z) * 0.5
		c2.height = bb.size.y
		shape = c2
		center = bb.get_center()
	if shape != null:
		var body := StaticBody3D.new()
		body.name = "Body"
		body.collision_layer = 1
		body.collision_mask = 0
		root.add_child(body)
		var cs := CollisionShape3D.new()
		cs.name = "Collision"
		cs.shape = shape
		cs.position = center
		body.add_child(cs)
	# comportamento em cena propria
	if id == "lantern_post":
		var l := OmniLight3D.new()
		l.name = "LampLight"
		l.light_color = Color("ffd88a")
		l.light_energy = 1.2
		l.omni_range = 7.0
		l.position = Vector3(0.34, 1.7, 0)
		root.add_child(l)
	if id == "lighthouse":
		var lb := OmniLight3D.new()
		lb.name = "BeaconLight"
		lb.light_color = Color("ffd88a")
		lb.light_energy = 2.0
		lb.omni_range = 14.0
		lb.position = Vector3(0, 16.4, 0)
		root.add_child(lb)
	if id == "boat_v2":
		var l2 := OmniLight3D.new()
		l2.name = "BowLight"
		l2.light_color = Color("ffd88a")
		l2.light_energy = 0.8
		l2.omni_range = 4.0
		l2.position = Vector3(0, 1.325, -2.3)
		root.add_child(l2)
	_own(root, root)
	_save(root, OUT + id + ".tscn")


func _save(root: Node, path: String) -> void:
	var ps := PackedScene.new()
	var err := ps.pack(root)
	if err != OK:
		printerr("pack falhou: ", path, " ", err)
		_fail = true
		return
	err = ResourceSaver.save(ps, path)
	if err != OK:
		printerr("save falhou: ", path, " ", err)
		_fail = true
	else:
		print("CENA ", path)
	root.free()


func _inst(parent: Node, id: String, pos: Vector3, ry: float = 0.0, sc: float = 1.0, rx: float = 0.0, nm: String = "") -> Node3D:
	var n := (load(OUT + id + ".tscn") as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node3D
	if nm != "":
		n.name = nm
	parent.add_child(n)
	n.position = pos
	n.rotation_degrees = Vector3(rx, ry, 0)
	n.scale = Vector3.ONE * sc
	return n


func _group(root: Node3D, gname: String) -> Node3D:
	var g := Node3D.new()
	g.name = gname
	root.add_child(g)
	return g


func _assemble() -> void:
	var root := Node3D.new()
	root.name = "DockAssembled"
	root.set_meta("provisional", true)
	var dock := _group(root, "Dock")
	for i in 4:
		_inst(dock, "dock_deck_4m", Vector3(-6 + 4 * i, 0, 0), 0.0, 1.0, 0.0, "Deck%d" % i)
	for i in 4:
		_inst(dock, "dock_edge", Vector3(-6 + 4 * i, 0, -3.0), 0.0, 1.0, 0.0, "Edge%d" % i)
	var px := [-7.5, -4.5, -1.5, 1.5, 4.5, 7.5]
	for i in px.size():
		_inst(dock, "dock_pile", Vector3(px[i], 0, -2.85), 0.0, 1.0, 0.0, "Pile%d" % i)
		_inst(dock, "dock_pile", Vector3(px[i], 0, 2.85), 180.0, 1.0, 0.0, "PileS%d" % i)
	_inst(dock, "dock_post", Vector3(-7.6, 0, -2.6), 20.0, 1.0, 0.0, "PostWest")
	_inst(dock, "dock_post", Vector3(7.6, 0, -2.6), -30.0, 1.0, 0.0, "PostEast")
	_inst(dock, "dock_post", Vector3(-3.4, 0, -2.7), 70.0, 1.0, 0.0, "MoorBow")
	_inst(dock, "dock_post", Vector3(2.9, 0, -2.7), 10.0, 1.0, 0.0, "MoorStern")
	_inst(dock, "dock_cleat", Vector3(-1.0, 0, -2.78), 3.0, 1.0, 0.0, "CleatA")
	_inst(dock, "dock_cleat", Vector3(1.2, 0, -2.78), -2.0, 1.0, 0.0, "CleatB")
	for i in 3:
		_inst(dock, "dock_fender", Vector3(-1.6 + 1.7 * i, 0.0, -3.28), 0.0, 1.0, 0.0, "Fender%d" % i)
	_inst(dock, "dock_ladder", Vector3(4.8, 0, -3.1), 0.0, 1.0, 0.0, "Ladder")
	# margem
	var ground := _group(root, "Ground")
	_inst(ground, "ground_tile_a", Vector3(-6, 0, 9.5), 0.0, 1.0, 0.0, "Tile0")
	_inst(ground, "ground_tile_path", Vector3(0, 0, 9.5), 0.0, 1.0, 0.0, "Tile1")
	_inst(ground, "ground_tile_b", Vector3(6, 0, 9.5), 180.0, 1.0, 0.0, "Tile2")
	# adercos
	var props := _group(root, "Props")
	_inst(props, "crate_l", Vector3(6.4, 0, 1.7), 14.0, 1.0, 0.0, "CrateL")
	_inst(props, "crate_s", Vector3(5.5, 0, 2.2), -8.0, 1.0, 0.0, "CrateS")
	_inst(props, "crate_peach", Vector3(6.4, 0.8, 1.7), 14.0, 1.0, 0.0, "CratePeach")
	_inst(props, "barrel", Vector3(7.4, 0, 0.7), 0.0, 1.0, 0.0, "BarrelA")
	_inst(props, "barrel", Vector3(7.0, 0, -0.2), 40.0, 0.9, 0.0, "BarrelB")
	_inst(props, "rope_coil", Vector3(-6.6, 0, -1.9), 30.0, 1.0, 0.0, "RopeCoil")
	_inst(props, "lantern_post", Vector3(-5.6, 0, -2.65), 0.0, 1.0, 0.0, "LanternW")
	_inst(props, "lantern_post", Vector3(5.0, 0, -2.65), 180.0, 1.0, 0.0, "LanternE")
	_inst(props, "bucket", Vector3(-6.1, 0, 1.0), 0.0, 1.0, 0.0, "BucketA")
	_inst(props, "bucket", Vector3(3.6, 0, -2.2), 50.0, 1.0, 0.0, "BucketB")
	_inst(props, "cork_buoy", Vector3(-6.9, 0, 2.3), 10.0, 1.0, 0.0, "BuoyA")
	_inst(props, "cork_buoy", Vector3(-4.4, 0, 12.2), 80.0, 1.0, 0.0, "BuoyB")
	_inst(props, "sign_board", Vector3(2.0, 0, 4.0), -10.0, 1.0, 0.0, "Sign")
	_inst(props, "boat_hut", Vector3(-7.0, 0, 13.5), 0.0, 1.0, 0.0, "Hut")
	_inst(props, "fishing_net", Vector3(-5.22, 2.2, 13.4), 90.0, 1.0, 0.0, "Net")
	_inst(props, "oar", Vector3(-5.6, 0, 11.75), 10.0, 1.0, 11.0, "OarA")
	_inst(props, "oar", Vector3(-5.9, 0, 11.75), -4.0, 1.0, 8.0, "OarB")
	_inst(props, "boot_print", Vector3(-6.0, 0.003, 10.0), 15.0, 1.4, 0.0, "BootPrint")
	# vegetacao e rochas
	var nat := _group(root, "Nature")
	_inst(nat, "tree_a", Vector3(-9.4, 0, 13.6), 30.0, 0.85, 0.0, "TreeA1")
	_inst(nat, "tree_b", Vector3(9.5, 0, 7.6), 0.0, 1.0, 0.0, "TreeB1")
	_inst(nat, "tree_c", Vector3(9.6, 0, 15.2), 200.0, 0.9, 0.0, "TreeC1")
	_inst(nat, "tree_a", Vector3(9.2, 0, 12.6), 140.0, 0.95, 0.0, "TreeA2")
	_inst(nat, "tree_c", Vector3(-9.5, 0, 9.5), 80.0, 0.85, 0.0, "TreeC2")
	_inst(nat, "bush_round", Vector3(-9.0, 0, 15.0), 0.0, 1.2, 0.0, "BushR1")
	_inst(nat, "bush_flower", Vector3(-3.6, 0, 13.0), 20.0, 1.0, 0.0, "BushF1")
	_inst(nat, "bush_round", Vector3(3.8, 0, 13.6), 100.0, 1.0, 0.0, "BushR2")
	_inst(nat, "bush_flower", Vector3(8.8, 0, 14.6), 60.0, 1.1, 0.0, "BushF2")
	_inst(nat, "bush_flower", Vector3(-9.2, 0, 4.4), 0.0, 0.9, 0.0, "BushF3")
	_inst(nat, "rock_a", Vector3(9.0, 0, 4.3), 20.0, 1.0, 0.0, "RockA1")
	_inst(nat, "rock_b", Vector3(8.2, 0, 4.9), 70.0, 1.0, 0.0, "RockB1")
	_inst(nat, "rock_c", Vector3(-9.0, 0, 11.0), 140.0, 1.0, 0.0, "RockC1")
	_inst(nat, "rock_b", Vector3(0.3, 0, 7.4), 10.0, 1.0, 0.0, "RockB2")
	_inst(nat, "reeds", Vector3(9.4, 0, 3.4), 0.0, 1.0, 0.0, "ReedsA")
	_inst(nat, "reeds", Vector3(-9.5, 0, 3.5), 90.0, 1.2, 0.0, "ReedsB")
	var rng := RandomNumberGenerator.new()
	rng.seed = 4040
	for i in 36:
		var p := Vector3(rng.randf_range(-9.4, 9.4), 0.0, rng.randf_range(3.5, 15.6))
		if absf(p.x + 0.3) < 1.3 or (p.x < -5.2 and p.x > -8.9 and p.z > 11.8):
			continue
		_inst(nat, "grass_tuft", p, rng.randf_range(0, 360), rng.randf_range(0.8, 1.5), 0.0, "Tuft%d" % i)
	_own(root, root)
	_save(root, OUT + "dock_assembled.tscn")


func _run() -> void:
	for id in SPEC:
		_make_piece(id)
	if not _fail:
		_assemble()
	quit(1 if _fail else 0)
