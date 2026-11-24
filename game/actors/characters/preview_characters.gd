extends Node3D
## Previa dos personagens na CAMERA DO JOGO (offset do dock (0, 4.6, 6.2), fov 55) para capturas com o Movie Maker (RB-04-chars).
## Nao e jogo nem teste. Argumentos (em qualquer posicao da linha de comando): --facing=camera|away, --zoom=1.0 (1 = camera real;
## < 1 aproxima ao longo do mesmo eixo), --old (inclui o Rastro de blocos do RB-03 para comparar), --clip=idle|walk|pose.
## ./tools/godot.ps1 --path game res://actors/characters/preview_characters.tscn --write-movie C:\tmp\f.png --fixed-fps 10 --resolution 1280x720 --quit-after 20

const CAM_OFFSET := Vector3(0.0, 4.6, 6.2)
const SPACING := 1.35

var _facing: String = "camera"
var _zoom: float = 1.0
var _old: bool = false
var _clip: String = "idle"
var _visuals: Array = []


func _arg(prefix: String, default: String) -> String:
	for a in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if a.begins_with(prefix):
			return a.trim_prefix(prefix)
	return default


func _flag(name: String) -> bool:
	return name in OS.get_cmdline_user_args() or name in OS.get_cmdline_args()


func _ready() -> void:
	_facing = _arg("--facing=", "camera")
	_zoom = float(_arg("--zoom=", "1.0"))
	_clip = _arg("--clip=", "idle")
	_old = _flag("--old")
	_build_world()
	var ids := ["rastro_model", "leme_model", "pico_model", "extra_a", "extra_b", "extra_c"]
	var count := ids.size() + (1 if _old else 0)
	var x0 := -SPACING * (count - 1) * 0.5
	var slot := 0
	if _old:
		var oldm := MemberActor.new()
		add_child(oldm)
		oldm.setup(&"tracker")
		oldm.position = Vector3(x0, 0.0, 0.0)
		oldm.set_physics_process(false)
		slot = 1
	for id in ids:
		var root := (load("res://actors/characters/%s.tscn" % id) as PackedScene).instantiate() as Node3D
		add_child(root)
		root.position = Vector3(x0 + SPACING * slot, 0.0, 0.0)
		var vis := root.find_child("Model", false, false) as CharacterVisual
		if _facing == "camera":
			vis.rotation.y = PI
		_visuals.append(vis)
		slot += 1
		var clip := StringName("idle")
		if id == "leme_model" and _clip != "walk":
			clip = &"idle_wheel"
		if _clip == "walk":
			clip = &"walk"
		if id == "rastro_model" and _clip == "pose":
			clip = &"inspect_touch"
		vis.play(clip, vis.walk_speed_scale(0.69) if clip == &"walk" else 1.0)
		if _clip == "pose" and id == "rastro_model":
			vis.set_expression(&"atenta")
		if _clip == "pose" and id == "leme_model":
			vis.play(&"react_horn")
			vis.set_expression(&"alegre")
	var cam := Camera3D.new()
	cam.fov = 55.0
	add_child(cam)
	var target := Vector3(0.0, 0.65, 0.0)
	cam.position = target + CAM_OFFSET * _zoom
	cam.look_at(target, Vector3.UP)
	cam.current = true


func _build_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("9cc8e8")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("b8d4ea")
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color("ffe9c4")
	sun.light_energy = 1.1
	sun.rotation_degrees = Vector3(-50.0, 35.0, 0.0)
	sun.shadow_enabled = true
	add_child(sun)
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(30.0, 30.0)
	floor_mi.mesh = pm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("c9a57a")
	m.roughness = 0.9
	floor_mi.material_override = m
	add_child(floor_mi)


