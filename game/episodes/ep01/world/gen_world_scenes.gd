extends SceneTree
## Gera river_world.tscn, island_world.tscn e horizon.tscn (RB-R1, PROVISORIO) a partir de *_layout.json
## (source_art/environment/world_layout.py, via tools/export-environment.ps1). Coordenadas do MUNDO: instancie na origem.
## - Pecas unicas: instancias das cenas proprias (res://actors/environment/<id>.tscn, colisao simples fora do GLB).
## - Vegetacao, rochas, conchas, nuvens e morros: EnvMultiMesh (uma malha mesclada por tipo); "col" -> cilindro.
## - Pisos: caixas do JSON (topo em y = 0).
## Uso (apos --import e gen_env_scenes): ./tools/godot.ps1 --headless --path game --script res://episodes/ep01/world/gen_world_scenes.gd

const ENV := "res://actors/environment/"
const WORLD := "res://episodes/ep01/world/"
const GEN := preload("res://actors/environment/gen_env_scenes.gd")
const NO_SHADOW := ["cloud", "hills_far", "hills_near", "far_water", "shell", "grass_tuft", "flower_clump", "reeds",
	"bush_round", "bush_flower", "rock_a", "rock_b", "rock_c"]
const CHUNK := 40.0   # MultiMesh em blocos de 40 x 40 m: o recorte por frustum funciona
const COL_R := {"palm_tree": 0.3, "tree_round": 0.35, "tree_round_dark": 0.35, "boulder": 1.4}

var _fail := false
var _merged := {}


func _initialize() -> void:
	_run.call_deferred()


func _own(n: Node, owner_node: Node) -> void:
	for c in n.get_children():
		c.owner = owner_node
		if c.scene_file_path.is_empty():
			_own(c, owner_node)


func _xform(d: Dictionary) -> Transform3D:
	var p: Array = d["pos"]
	var s: Array = d.get("s", [1, 1, 1])
	var b := Basis(Vector3.UP, deg_to_rad(float(d.get("ry", 0.0)))).scaled_local(Vector3(s[0], s[1], s[2]))
	return Transform3D(b, Vector3(p[0], p[1], p[2]))


func _mesh(id: String) -> ArrayMesh:
	if not _merged.has(id):
		_merged[id] = GEN.merged_mesh(id)
	return _merged[id]


func _build(json_name: String, out_name: String) -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(WORLD + json_name))
	if not (data is Dictionary):
		printerr("layout ilegivel: ", json_name)
		_fail = true
		return
	var d := data as Dictionary
	var root := Node3D.new()
	root.name = String(d["root"])
	root.set_meta("provisional", true)
	var mm_ids: Array = d.get("multimesh", [])
	var pieces_node := Node3D.new()
	pieces_node.name = "Pieces"
	root.add_child(pieces_node)
	var veg := Node3D.new()
	veg.name = "Instanced"
	root.add_child(veg)
	var body := StaticBody3D.new()
	body.name = "Floors"
	body.collision_mask = 0
	root.add_child(body)
	var groups := {}
	var count := 0
	for pd in d["pieces"]:
		var p := pd as Dictionary
		var id := String(p["id"])
		var xf := _xform(p)
		if id in mm_ids:
			var key := "%s@%d_%d" % [id, floori(xf.origin.x / CHUNK), floori(xf.origin.z / CHUNK)]
			if id in ["cloud", "hills_far", "hills_near"]:
				key = id
			if not groups.has(key):
				groups[key] = [] as Array[Transform3D]
			(groups[key] as Array[Transform3D]).append(xf)
			if p.get("col", false) and COL_R.has(id):
				var cs := CollisionShape3D.new()
				cs.name = "%s_col_%d" % [id, count]
				var cy := CylinderShape3D.new()
				cy.radius = float(COL_R[id]) * xf.basis.get_scale().x
				cy.height = 2.5
				cs.shape = cy
				cs.position = xf.origin + Vector3(0, 1.25, 0)
				body.add_child(cs)
			count += 1
			continue
		var ps := load(ENV + id + ".tscn") as PackedScene
		if ps == null:
			printerr("cena ausente: ", id)
			_fail = true
			continue
		var n := ps.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node3D
		n.name = String(p.get("name", "%s_%d" % [id, count]))
		pieces_node.add_child(n)
		n.transform = xf
		count += 1
	for key in groups:
		var id := String(key).get_slice("@", 0)
		var mmi := EnvMultiMesh.new()
		mmi.name = "MM_" + String(key).replace("@", "_").replace("-", "m")
		mmi.source_mesh = _mesh(id)
		mmi.xforms = groups[key]
		if id in NO_SHADOW:
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		veg.add_child(mmi)
	for bd in d.get("boxes", []):
		var b := bd as Dictionary
		var cs2 := CollisionShape3D.new()
		cs2.name = String(b["name"])
		var bx := BoxShape3D.new()
		var sz: Array = b["size"]
		var ps2: Array = b["pos"]
		bx.size = Vector3(sz[0], sz[1], sz[2])
		cs2.shape = bx
		cs2.position = Vector3(ps2[0], ps2[1], ps2[2])
		body.add_child(cs2)
	_own(root, root)
	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err == OK:
		err = ResourceSaver.save(packed, WORLD + out_name)
	print("CENA ", WORLD, out_name, " pecas=", count, " multimesh=", groups.size(), " err=", err)
	if err != OK:
		_fail = true
	root.free()


func _run() -> void:
	_build("river_layout.json", "river_world.tscn")
	_build("island_layout.json", "island_world.tscn")
	_build("horizon_layout.json", "horizon.tscn")
	quit(1 if _fail else 0)
