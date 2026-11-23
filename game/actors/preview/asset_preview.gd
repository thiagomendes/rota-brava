extends Node3D
## Cena de captura dos ativos 3D (RB-03-art, PROVISORIO). Camera igual a do jogo: offset (0, 7.5, 9.5), fov 55.
## Uso: ./tools/godot.ps1 --path game res://actors/preview/asset_preview.tscn --write-movie out/f.png --fixed-fps 10 --resolution 1280x720 --quit-after 5 -- --asset=rastro|boat|dock|study [--zoom=0.4]

const GAME_OFFSET := Vector3(0.0, 7.5, 9.5)
const GAME_LOOK := Vector3(0.0, 1.0, 0.0)
const GAME_FOV := 55.0

var _mode := "dock"
var _zoom := 1.0


func _arg(key: String, default: String) -> String:
	for a in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if a.begins_with("--%s=" % key):
			return a.get_slice("=", 1)
	return default


func _box(parent: Node3D, node_name: String, size: Vector3, pos: Vector3, color: Color, rough: float = 0.9) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	mi.material_override = m
	mi.position = pos
	mi.set_meta("provisional", true)
	parent.add_child(mi)
	return mi


func _ready() -> void:
	_mode = _arg("asset", "dock")
	_zoom = float(_arg("zoom", "1.0"))
	_environment()
	var target := Vector3.ZERO
	var cam_pos := Vector3.ZERO
	var look := Vector3.ZERO
	var fov := GAME_FOV
	match _mode:
		"rastro":
			_ground(Color("a8a58f"))
			var rs := (load("res://actors/rastro/rastro.tscn") as PackedScene).instantiate() as Node3D
			add_child(rs)
			target = Vector3.ZERO
		"boat":
			_water()
			var bt := (load("res://actors/boat_model/boat_model.tscn") as PackedScene).instantiate() as Node3D
			add_child(bt)
			target = Vector3.ZERO
		"dock":
			target = _dock_scene(false)
		"study":
			_dock_scene(true)
			# estudo: camera baixa pela proa; o casco amarelo conduz o olhar ate a marca no banco
			cam_pos = Vector3(2.2, 3.1, -6.4)
			look = Vector3(-0.6, 0.3, 0.2)
			fov = 48.0
	var cam := Camera3D.new()
	cam.name = "Camera3D"
	cam.fov = fov
	add_child(cam)
	if _mode == "study":
		cam.position = cam_pos
		cam.look_at(look)
	else:
		cam.position = target + GAME_OFFSET * _zoom
		cam.look_at(target + GAME_LOOK)
	cam.current = true


func _environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("bfe0e6")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("e8f0f0")
	env.ambient_light_energy = 0.6
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -35, 0)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	if _mode == "study":
		sun.rotation_degrees = Vector3(-38, 150, 0)   # luz do lado da camera: casco amarelo iluminado
	add_child(sun)


func _ground(color: Color) -> void:
	_box(self, "Ground", Vector3(400, 0.2, 400), Vector3(0, -0.1, 0), color)


func _water() -> void:
	_box(self, "Water", Vector3(400, 0.2, 400), Vector3(0, -0.12, 0), Color("3f8f8f"), 0.35)


func _dock_scene(study: bool) -> Vector3:
	_water()
	var wood := Color("b39a76") if study else Color("a98f6b")
	var dark := Color("6e5a42")
	# cais ao longo de Z, a esquerda (x < -1.6); tabuas e estacas em blocos PROPRIOS provisorios
	var dock := Node3D.new()
	dock.name = "Dock"
	add_child(dock)
	for i in 16:
		var shade := wood.lerp(dark, 0.12 * float(i % 3))
		_box(dock, "Plank%d" % i, Vector3(3.2, 0.12, 0.42), Vector3(-3.4, 0.42, -4.2 + 0.54 * i), shade)
	for i in 4:
		for s in [-1.0, 1.0]:
			_box(dock, "Pile%d_%d" % [i, int(s)], Vector3(0.28, 1.5, 0.28), Vector3(-3.4 + s * 1.45, -0.1, -4.0 + 2.6 * i), dark)
	var boat := (load("res://actors/boat_model/boat_model.tscn") as PackedScene).instantiate() as Node3D
	boat.position = Vector3(0.0, 0.05, 0.0)
	add_child(boat)
	var rastro := (load("res://actors/rastro/rastro.tscn") as PackedScene).instantiate() as Node3D
	rastro.position = Vector3(-2.7, 0.48, -0.6)
	rastro.rotation_degrees.y = -70.0
	add_child(rastro)
	if study:
		_paw(boat.find_child("BenchMark", true, false) as Node3D)
	return Vector3(-1.4, 0.0, 0.0)


func _paw(mark: Node3D) -> void:
	# marca da pata (pista): almofada + 4 dedos, cor clara emissiva sobre o banco
	var holder := Node3D.new()
	holder.name = "PawMark"
	mark.add_child(holder)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("fff3c4")
	mat.emission_enabled = true
	mat.emission = Color("ffe08a")
	mat.emission_energy_multiplier = 1.6
	var parts := [[Vector3(0, 0, 0.03), 0.11], [Vector3(-0.15, 0, -0.1), 0.05], [Vector3(-0.05, 0, -0.16), 0.055], [Vector3(0.05, 0, -0.16), 0.055], [Vector3(0.15, 0, -0.1), 0.05]]
	for p in parts:
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = p[1]
		cm.bottom_radius = p[1]
		cm.height = 0.012
		mi.mesh = cm
		mi.material_override = mat
		mi.position = p[0] + Vector3(0, 0.006, 0)
		holder.add_child(mi)
	holder.scale = Vector3(1.9, 1.0, 1.9)
	holder.set_meta("provisional", true)


