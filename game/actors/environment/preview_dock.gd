extends Node3D
## Cena de PREVIEW (so para capturas; nao e jogo): cais montado + barco v2 + Rastro, vistos pela CameraRig real do Ep01.
## Para 20:9 o projeto fixa a janela em 1280x720 (window_*_override) e ignora --resolution: use um game/override.cfg temporario (nao versionado) com a janela 1600x720. `--flat` (apos --): troca o cenario pelas caixas planas antigas, para comparar. `--cam=x,y,z` e `--look=x,y,z` movem a camera.
## PROVISORIO.

const DOCK := "res://actors/environment/dock_assembled.tscn"
const BOAT := "res://actors/environment/boat_v2.tscn"
const RASTRO := "res://actors/rastro/rastro.tscn"

var rig: CameraRig


func _args() -> Array:
	return OS.get_cmdline_user_args() + OS.get_cmdline_args()


func _arg(prefix: String) -> String:
	for a in _args():
		if String(a).begins_with(prefix):
			return String(a).trim_prefix(prefix)
	return ""


func _vec(s: String) -> Vector3:
	var p := s.split(",")
	return Vector3(float(p[0]), float(p[1]), float(p[2]))


func _ready() -> void:
	_build_world()
	var flat := "--flat" in _args()
	if flat:
		_build_flat()
	else:
		add_child((load(DOCK) as PackedScene).instantiate())
	var boat := (load(BOAT) as PackedScene).instantiate() as Node3D
	boat.name = "Boat"
	add_child(boat)
	boat.position = Ep01Layout.BOAT_DOCKED_POS
	boat.rotation.y = Ep01Layout.BOAT_DOCKED_HEADING
	var rastro := (load(RASTRO) as PackedScene).instantiate() as Node3D
	rastro.name = "Rastro"
	add_child(rastro)
	rastro.position = Ep01Layout.BENCH_INTERACT_POS
	rastro.rotation.y = 0.0
	rig = CameraRig.new()
	add_child(rig)
	var focus: Node3D = rastro
	if _arg("--look=") != "":
		focus = Node3D.new()
		add_child(focus)
		focus.position = _vec(_arg("--look="))
	rig.reduced_motion = true
	rig.follow(focus, true)
	if _arg("--cam=") != "":
		rig.camera.global_position = _vec(_arg("--cam="))
		rig.camera.look_at(focus.global_position + rig.look_offset, Vector3.UP)
		rig.set_process(false)
		rig.set_physics_process(false)


func _build_world() -> void:
	var env := Environment.new()
	var sky := Sky.new()
	var psm := ProceduralSkyMaterial.new()
	psm.sky_top_color = Color("5f9fcf")
	psm.sky_horizon_color = Color("cfe6ea")
	psm.ground_horizon_color = Color("a9c9c8")
	psm.ground_bottom_color = Color("5f8f90")
	sky.sky_material = psm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.fog_enabled = true
	env.fog_light_color = Color("cfe6ea")
	env.fog_density = 0.002
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -40, 0)
	sun.light_energy = 1.0
	sun.light_color = Color("fff1d6")
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0
	add_child(sun)
	var water := MeshInstance3D.new()
	water.name = "Water"
	var pm := PlaneMesh.new()
	pm.size = Vector2(400, 400)
	water.mesh = pm
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color("2f8a86")
	wm.roughness = 0.12
	wm.metallic = 0.1
	wm.metallic_specular = 0.8
	water.material_override = wm
	water.position = Vector3(0, Ep01Layout.WATER_Y, 0)
	add_child(water)


func _build_flat() -> void:
	var wood := Color("b58a5a")
	var dark_wood := Color("7a5636")
	Blocks.solid_box(self, "DockDeck", Vector3(16, 0.4, 6), Vector3(0, -0.2, 0), wood)
	Blocks.solid_box(self, "BankGround", Vector3(20, 0.4, 13), Vector3(0, -0.2, 9.5), Color("7d9a54"))
	for i in range(-7, 8, 2):
		Blocks.box(self, "Plank%d" % i, Vector3(0.06, 0.02, 5.9), Vector3(i, 0.01, 0), dark_wood)
	Blocks.solid_box(self, "Crate1", Vector3(0.9, 0.8, 0.9), Vector3(6.2, 0.4, 1.8), Color("d9a05b"))
	Blocks.solid_box(self, "HutBody", Vector3(3.4, 2.2, 2.8), Vector3(-7.0, 1.1, 13.5), Color("e3cfa5"))
	Blocks.box(self, "HutRoof", Vector3(3.9, 0.35, 3.3), Vector3(-7.0, 2.4, 13.5), Color("a8503c"))
