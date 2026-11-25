extends Node3D
## VITRINE "vila e cais v2" (RB-R1 W1, D11/D12). NAO e jogo e nao esta ligada ao Ep01: monta o recorte do porto refeito
## (source_art/environment_v2/build_world_v2.py -> wv2_static.glb + wv2_kit.glb + world_v2_layout.json), o trio v2 em
## idle no cais, ceu de sol, sol com sombra macia, luzes quentes locais, SSAO/SSIL e nevoa de profundidade.
## PROVISORIO ate aprovacao de Thiago.
##
## Teclas (Windows: ./tools/godot.ps1 --path game res://lookdev/world_v2/world_v2.tscn):
##   1 2 3 4   camera baixa do jogo: cais com o trio, rua, praca, margem  ·  5 barco  ·  6 janelas (close)
##   N         dia / noite (janelas acesas, vitrines e lanternas brilham mais a noite)
##   F         camera livre (continua de onde esta)  ·  P  percurso fixo (recomeca)  ·  H  mostra/esconde a ajuda
##   camera livre: W A S D move · Q E desce/sobe · botao direito do mouse segurado gira · Shift rapido · roda: velocidade
##   Esc       solta o mouse; Esc de novo fecha
## Linha de comando (provas): -- --wv2-cam=low|free|path  --wv2-view=dock|street|plaza|bank|boat|windows  --wv2-perf
##   --wv2-tour  --wv2-night  --wv2-boat=old  --wv2-pos=x,y,z --wv2-look=x,y,z (tomada livre)
##   (--wv2-tour: as 6 vistas em sequencia, 14 quadros cada; o penultimo quadro de cada bloco e a prova)
## Imprime "WV2 PERF ..." com chamadas de desenho, primitivas e objetos (vistas baixas e pior quadro do percurso).

const STATIC_GLB := "res://assets/models/environment_v2/wv2_static.glb"
const KIT_GLB := "res://assets/models/environment_v2/wv2_kit.glb"
const PROPS_GLB := "res://assets/models/environment_v2/wv3_props.glb"
const LAYOUT := "res://lookdev/world_v2/world_v2_layout.json"
const SKY_SHADER := "res://art/sky.gdshader"
const BOAT_OLD := "res://actors/environment/boat_v2.tscn"
## Barco v2 (W4): mesmas medidas e pontos de encaixe do boat_v2; --wv2-boat=old volta o antigo (comparacao).
const BOAT_GLB := "res://assets/models/environment_v2/wv2_boat.glb"
const HERO_MODEL := "res://lookdev/%s_v2_model.tscn"
## Camera baixa da referencia (igual a vitrine lookdev_dock): ~1,95 m, 12 graus para baixo, FOV 50.
const LOW_PITCH := 12.0
const LOW_FOV := 50.0
const VIEW_KEYS := ["dock", "street", "plaza", "bank", "boat", "windows"]
## Sem sombra: pecas pequenas e numerosas (custo de sombra alto, contribuicao baixa; o SSAO assenta no chao).
const NO_SHADOW := ["grass_tuft", "grass_tall", "flowers_a", "flowers_b", "reeds", "float_buoy", "bucket", "pot_a", "pot_b",
	"pot_c", "rope_coil", "fender", "life_ring", "sack", "bollard"]
## Distancia maxima de desenho por peca (m); o resto usa o padrao.
const RANGE := {"grass_tuft": 45.0, "grass_tall": 50.0, "flowers_a": 45.0, "flowers_b": 45.0, "reeds": 70.0, "float_buoy": 60.0,
	"bucket": 50.0, "rope_coil": 50.0, "sack": 60.0, "pot_a": 70.0, "pot_b": 70.0, "pot_c": 70.0}
const LIGHTS := {
	"window": [Color("ffb867"), 0.7, 2.6],
	"wall_lamp": [Color("ffc47a"), 1.6, 3.6],
	"shop": [Color("ffc98a"), 1.0, 3.2],
	"awning": [Color("ffc47a"), 1.1, 3.0],
	"lighthouse": [Color("ffe2a8"), 3.0, 7.0],
	"lamp_post": [Color("ffb35c"), 1.8, 5.0],
}

var layout: Dictionary = {}
var cam: Camera3D
var mode := "low"
var view := "dock"
var perf := false
var tour := false
const TOUR_FRAMES := 14
var frame := 0
var path_t := 0.0
var path_points: Array = []
var path_max := {"draw_calls": 0, "primitives": 0, "objects": 0, "t": 0.0}
var free_speed := 6.0
var yaw := 0.0
var pitch := 0.0
var looking := false
var help: Label
var heroes: Array[Node3D] = []
var night := false
var env: Environment
var sun: DirectionalLight3D
var fill: DirectionalLight3D
var sky_mat: ShaderMaterial
var local_lights: Array[OmniLight3D] = []
var stats := {"kits": 0, "instances": 0, "lights": 0, "surfaces": 0}


func _ready() -> void:
	mode = _arg("--wv2-cam", "low")
	view = _arg("--wv2-view", "dock")
	perf = _arg("--wv2-perf", "") != "" or OS.get_cmdline_user_args().has("--wv2-perf")
	tour = OS.get_cmdline_user_args().has("--wv2-tour")
	if tour:
		view = VIEW_KEYS[0]
	layout = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT)) as Dictionary
	path_points = layout["percurso"] as Array
	_register_input()
	_build_environment()
	var water := WaterSurface.new()
	add_child(water)
	_tune_water(water)
	var st := (load(STATIC_GLB) as PackedScene).instantiate() as Node3D
	st.name = "Static"
	add_child(st)
	stats.surfaces = WV2Materials.apply(st)
	_build_kit()
	# pecas soltas do Ep01 v3 (E3): lanterna do farol (saiu do cenario fixo), bote, boias, barquinhos, lanternas de festa
	var props := (load(PROPS_GLB) as PackedScene).instantiate() as Node3D
	props.name = "Props"
	add_child(props)
	stats.surfaces += WV2Materials.apply(props)
	var beam := props.find_child("wv3_lantern_beam", true, false) as Node3D
	if beam != null:
		beam.visible = false
	_build_lights()
	_build_boat()
	_build_trio()
	_build_camera()
	_build_help()
	if OS.get_cmdline_user_args().has("--wv2-night"):
		_set_night(true)
	if not WV2Materials.unknown.is_empty():
		push_warning("WV2 materiais sem regra: %s" % str(WV2Materials.unknown.keys()))
	print("WV2 READY kits=%d instances=%d lights=%d surfaces=%d mode=%s view=%s" % [stats.kits, stats.instances, stats.lights,
		stats.surfaces, mode, view])


## Agua do jogo (art/water.gdshader) com cor mais funda e menos reflexo lavado, so nesta vitrine.
func _tune_water(water: WaterSurface) -> void:
	var m := water.material_override as ShaderMaterial
	if m == null:
		return
	m.set_shader_parameter("shallow_color", Color("3cc2b4"))
	m.set_shader_parameter("deep_color", Color("0f6680"))
	m.set_shader_parameter("sky_color", Color("8cc6e6"))
	m.set_shader_parameter("depth_range", 2.2)
	m.set_shader_parameter("fresnel_strength", 0.28)
	m.set_shader_parameter("normal_strength", 0.6)


func _arg(flag: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if a.begins_with(flag + "="):
			return a.trim_prefix(flag + "=")
	return fallback


# ---------------------------------------------------------------- entrada (intencoes registradas so nesta vitrine)

func _register_input() -> void:
	var keys := {
		"wv2_forward": [KEY_W, KEY_UP], "wv2_back": [KEY_S, KEY_DOWN], "wv2_left": [KEY_A, KEY_LEFT],
		"wv2_right": [KEY_D, KEY_RIGHT], "wv2_down": [KEY_Q], "wv2_up": [KEY_E], "wv2_fast": [KEY_SHIFT],
		"wv2_view_1": [KEY_1], "wv2_view_2": [KEY_2], "wv2_view_3": [KEY_3], "wv2_view_4": [KEY_4],
		"wv2_view_5": [KEY_5], "wv2_view_6": [KEY_6], "wv2_night": [KEY_N],
		"wv2_free": [KEY_F], "wv2_path": [KEY_P], "wv2_help": [KEY_H], "wv2_escape": [KEY_ESCAPE],
	}
	for action: String in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for k: Key in keys[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)


# ---------------------------------------------------------------- luz, ceu, ambiente

func _build_environment() -> void:
	sky_mat = ShaderMaterial.new()
	sky_mat.shader = load(SKY_SHADER) as Shader
	sky_mat.set_shader_parameter("top_color", Color("2f7fdc"))
	sky_mat.set_shader_parameter("horizon_color", Color("bfe0f6"))
	sky_mat.set_shader_parameter("ground_color", Color("5f9fb4"))
	sky_mat.set_shader_parameter("cloud_light", Color("ffffff"))
	sky_mat.set_shader_parameter("cloud_shadow", Color("b9c4e6"))
	sky_mat.set_shader_parameter("cloud_coverage", 0.42)
	sky_mat.set_shader_parameter("cloud_softness", 0.08)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL

	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 1.0
	env.ambient_light_energy = 0.75
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.tonemap_white = 6.0
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 2.2
	env.ssao_power = 1.6
	env.ssao_detail = 0.6
	env.ssao_horizon = 0.06
	env.ssao_light_affect = 0.25
	env.ssil_enabled = true
	env.ssil_radius = 4.0
	env.ssil_intensity = 0.9
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = Color("a9cdea")
	env.fog_light_energy = 1.0
	env.fog_sun_scatter = 0.15
	env.fog_density = 0.0042
	env.fog_aerial_perspective = 0.35
	env.fog_sky_affect = 0.0
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.03
	env.glow_hdr_threshold = 1.2
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.06
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	add_child(we)

	# Sol de fim de manha a leste-sudeste, ~42 graus: fachadas (viradas ao sul) com luz rasante que mostra os vaos.
	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = Color("ffe3b8")
	sun.light_energy = 2.4
	sun.light_angular_distance = 1.2
	sun.shadow_enabled = true
	sun.shadow_bias = 0.03
	sun.shadow_normal_bias = 1.0
	sun.shadow_blur = 1.3
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 80.0
	sun.directional_shadow_split_1 = 0.08
	sun.directional_shadow_split_2 = 0.22
	sun.directional_shadow_split_3 = 0.5
	sun.directional_shadow_blend_splits = true
	add_child(sun)
	sun.basis = Basis.looking_at(-Vector3(0.72, 0.68, 0.38).normalized(), Vector3.UP)
	fill = DirectionalLight3D.new()
	fill.name = "SkyFill"
	fill.light_color = Color("b9d3ff")
	fill.light_energy = 0.25
	fill.light_specular = 0.0
	add_child(fill)
	fill.basis = Basis.looking_at(-Vector3(-0.7, 0.45, -0.4).normalized(), Vector3.UP)
	get_viewport().msaa_3d = Viewport.MSAA_4X
	get_viewport().anisotropic_filtering_level = Viewport.ANISOTROPY_16X


# ---------------------------------------------------------------- kit (MultiMesh)

func _build_kit() -> void:
	var kit_scene := (load(KIT_GLB) as PackedScene).instantiate()
	var meshes: Dictionary = {}
	for node in kit_scene.find_children("kit_*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		meshes[String(mi.name).trim_prefix("kit_")] = mi.mesh
	var root := Node3D.new()
	root.name = "Kit"
	add_child(root)
	var kit: Dictionary = layout["kit"]
	for kind: String in kit:
		if not meshes.has(kind):
			push_warning("WV2 kit sem malha: " + kind)
			continue
		var rows: Array = kit[kind]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = WV2Materials.baked_mesh(meshes[kind])
		mm.instance_count = rows.size()
		for i in rows.size():
			var r: Array = rows[i]
			var b := Basis(Vector3.UP, deg_to_rad(float(r[3]))).scaled(Vector3.ONE * float(r[4]))
			mm.set_instance_transform(i, Transform3D(b, Vector3(float(r[0]), float(r[1]), float(r[2]))))
		var mmi := MultiMeshInstance3D.new()
		mmi.name = kind
		mmi.multimesh = mm
		if kind in NO_SHADOW:
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if RANGE.has(kind):
			mmi.visibility_range_end = float(RANGE[kind])
			mmi.visibility_range_end_margin = 5.0
			mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		root.add_child(mmi)
		stats.kits += 1
		stats.instances += rows.size()
	kit_scene.free()


func _add_light(pos: Vector3, kind: String) -> void:
	var spec: Array = LIGHTS.get(kind, LIGHTS["window"])
	var l := OmniLight3D.new()
	l.light_color = spec[0]
	l.light_energy = float(spec[1])
	l.omni_range = float(spec[2])
	l.omni_attenuation = 1.3
	l.light_specular = 0.25
	l.shadow_enabled = false
	l.distance_fade_enabled = true
	l.distance_fade_begin = 45.0
	l.distance_fade_length = 15.0
	add_child(l)
	l.position = pos
	l.set_meta("day_energy", l.light_energy)
	local_lights.append(l)
	stats.lights += 1


func _build_lights() -> void:
	for l: Dictionary in layout["luzes"]:
		var p: Array = l["pos"]
		_add_light(Vector3(float(p[0]), float(p[1]), float(p[2])), String(l["tipo"]))
	for r: Array in (layout["kit"] as Dictionary).get("lamp_post", []):
		_add_light(Vector3(float(r[0]), float(r[1]) + 3.12, float(r[2])), "lamp_post")


func _build_boat() -> void:
	var old := _arg("--wv2-boat", "v2") == "old"
	var boat: Node3D
	boat = (load(BOAT_OLD if old else BOAT_GLB) as PackedScene).instantiate() as Node3D
	boat.name = "Boat"
	add_child(boat)
	boat.position = Ep01Layout.BOAT_DOCKED_POS
	boat.rotation.y = Ep01Layout.BOAT_DOCKED_HEADING
	if old:
		LookdevMaterials.apply(boat, false)
	else:
		stats.surfaces += WV2Materials.apply(boat)
	# lampiao de proa e luminaria da cabine (pontos do proprio modelo)
	_add_light(boat.to_global(Vector3(0.0, 1.32, -2.35)), "wall_lamp")
	if not old:
		_add_light(boat.to_global(Vector3(0.0, 1.2, 1.45)), "window")


## Noite: lua fria fraca, ceu azul-escuro, nevoa escura; janelas acesas, vitrines, postes e lanternas mais fortes.
func _set_night(on: bool) -> void:
	night = on
	WV2Materials.set_night(on)
	sun.light_energy = 0.32 if on else 2.4
	sun.light_color = Color("9fb6ff") if on else Color("ffe3b8")
	fill.light_energy = 0.08 if on else 0.25
	env.ambient_light_energy = 0.22 if on else 0.75
	env.fog_light_color = Color("1d2a4a") if on else Color("a9cdea")
	env.tonemap_exposure = 1.1 if on else 1.0
	env.glow_intensity = 0.9 if on else 0.5
	env.ssil_intensity = 1.4 if on else 0.9
	sky_mat.set_shader_parameter("top_color", Color("0c1838") if on else Color("2f7fdc"))
	sky_mat.set_shader_parameter("horizon_color", Color("2c3f6e") if on else Color("bfe0f6"))
	sky_mat.set_shader_parameter("ground_color", Color("0f2030") if on else Color("5f9fb4"))
	sky_mat.set_shader_parameter("cloud_light", Color("5d6c99") if on else Color("ffffff"))
	sky_mat.set_shader_parameter("cloud_shadow", Color("2a3152") if on else Color("b9c4e6"))
	for l in local_lights:
		l.light_energy = float(l.get_meta("day_energy")) * (2.0 if on else 1.0)
		l.distance_fade_begin = 80.0 if on else 45.0


func _build_trio() -> void:
	for h: Dictionary in layout["trio"]:
		var path := HERO_MODEL % String(h["id"])
		if not ResourceLoader.exists(path):
			continue
		var inst := (load(path) as PackedScene).instantiate() as Node3D
		add_child(inst)
		var p: Array = h["pos"]
		inst.position = Vector3(float(p[0]), float(p[1]), float(p[2]))
		inst.rotation_degrees.y = float(h["ry"])
		var vis := inst.get_node("Model") as CharacterVisual
		vis.play(&"idle")
		var player := vis.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if player != null:
			player.seek(float(h["phase"]) * player.current_animation_length, true)
		_contact_shadow(inst)
		heroes.append(inst)


func _contact_shadow(parent: Node3D) -> void:
	var g := Gradient.new()
	g.set_color(0, Color(0.12, 0.10, 0.14, 0.7))
	g.set_color(1, Color(0.12, 0.10, 0.14, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	var d := Decal.new()
	d.name = "ContactShadow"
	d.texture_albedo = tex
	d.size = Vector3(0.95, 0.5, 0.95)
	d.upper_fade = 0.2
	d.lower_fade = 0.6
	parent.add_child(d)
	d.position = Vector3(0, 0.15, 0)


# ---------------------------------------------------------------- cameras

func _build_camera() -> void:
	cam = Camera3D.new()
	cam.name = "Camera"
	cam.near = 0.05
	cam.far = 600.0
	cam.fov = LOW_FOV
	add_child(cam)
	cam.current = true
	match mode:
		"free":
			_set_view(view)
			mode = "free"
		"path":
			_start_path()
		_:
			_set_view(view)
	# tomada livre para provas: --wv2-pos=x,y,z --wv2-look=x,y,z
	var ps := _arg("--wv2-pos", "")
	if ps != "":
		var a := ps.split_floats(",")
		var b := _arg("--wv2-look", "0,0,0").split_floats(",")
		cam.global_position = Vector3(a[0], a[1], a[2])
		cam.look_at(Vector3(b[0], b[1], b[2]), Vector3.UP)


## Camera baixa do jogo num ponto de vista do layout: posicao e direcao horizontal, 12 graus para baixo.
func _set_view(v: String) -> void:
	var vd: Dictionary = (layout["vistas"] as Dictionary).get(v, (layout["vistas"] as Dictionary)["dock"])
	view = v
	mode = "low"
	var p: Array = vd["pos"]
	var l: Array = vd["look"]
	var pos := Vector3(float(p[0]), float(p[1]), float(p[2]))
	var flat := Vector3(float(l[0]), 0.0, float(l[2])) - Vector3(pos.x, 0.0, pos.z)
	flat = flat.normalized()
	# vistas de detalhe (barco, janelas) podem trazer inclinacao e FOV proprios; as do jogo usam a camera baixa
	var pitch_deg := float(vd.get("pitch", LOW_PITCH))
	cam.fov = float(vd.get("fov", LOW_FOV))
	cam.global_position = pos
	var dir := Vector3(flat.x * cos(deg_to_rad(pitch_deg)), -sin(deg_to_rad(pitch_deg)), flat.z * cos(deg_to_rad(pitch_deg)))
	cam.look_at(pos + dir, Vector3.UP)
	frame = 0
	_sync_free_angles()


func _sync_free_angles() -> void:
	var f := -cam.global_basis.z
	yaw = atan2(-f.x, -f.z)
	pitch = asin(clampf(f.y, -1.0, 1.0))


func _start_path() -> void:
	mode = "path"
	path_t = 0.0
	cam.fov = LOW_FOV
	_apply_path(0.0)


func _path_duration() -> float:
	return float((path_points[path_points.size() - 1] as Array)[0])


func _catmull(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)


func _v(a: Array) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))


func _path_sample(t: float, idx: int) -> Vector3:
	var n := path_points.size()
	var k := 0
	while k < n - 2 and t > float((path_points[k + 1] as Array)[0]):
		k += 1
	var t0 := float((path_points[k] as Array)[0])
	var t1 := float((path_points[k + 1] as Array)[0])
	var u := clampf((t - t0) / maxf(t1 - t0, 0.001), 0.0, 1.0)
	u = u * u * (3.0 - 2.0 * u) * 0.35 + u * 0.65
	var p0 := _v((path_points[maxi(k - 1, 0)] as Array)[idx])
	var p1 := _v((path_points[k] as Array)[idx])
	var p2 := _v((path_points[k + 1] as Array)[idx])
	var p3 := _v((path_points[mini(k + 2, n - 1)] as Array)[idx])
	return _catmull(p0, p1, p2, p3, u)


func _apply_path(t: float) -> void:
	var pos := _path_sample(t, 1)
	var look := _path_sample(t, 2)
	cam.global_position = pos
	cam.look_at(look, Vector3.UP)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			looking = mb.pressed
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if looking else Input.MOUSE_MODE_VISIBLE
			if looking and mode != "free":
				_sync_free_angles()
				mode = "free"
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			free_speed = minf(free_speed * 1.2, 40.0)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			free_speed = maxf(free_speed / 1.2, 0.5)
	elif event is InputEventMouseMotion and looking:
		var mm := event as InputEventMouseMotion
		yaw -= mm.relative.x * 0.0035
		pitch = clampf(pitch - mm.relative.y * 0.0035, -1.45, 1.45)
	for i in VIEW_KEYS.size():
		if event.is_action_pressed("wv2_view_%d" % (i + 1)):
			_set_view(VIEW_KEYS[i])
	if event.is_action_pressed("wv2_free"):
		_sync_free_angles()
		mode = "free"
	elif event.is_action_pressed("wv2_path"):
		_start_path()
	elif event.is_action_pressed("wv2_night"):
		_set_night(not night)
	elif event.is_action_pressed("wv2_help") and help != null:
		help.visible = not help.visible
	elif event.is_action_pressed("wv2_escape"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			looking = false
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			get_tree().quit()


func _process(dt: float) -> void:
	frame += 1
	if frame == 3:
		for h in heroes:
			var vis := h.get_node("Model") as CharacterVisual
			vis.look_at_point(cam.global_position)
	match mode:
		"free":
			cam.basis = Basis.from_euler(Vector3(pitch, yaw, 0.0))
			var mv := Vector3(Input.get_axis("wv2_left", "wv2_right"), Input.get_axis("wv2_down", "wv2_up"),
				Input.get_axis("wv2_forward", "wv2_back"))
			var sp := free_speed * (3.0 if Input.is_action_pressed("wv2_fast") else 1.0)
			cam.global_position += cam.basis * mv * sp * dt
		"path":
			path_t += dt
			if path_t > _path_duration():
				_print_path_perf()
				path_t = 0.0
			_apply_path(path_t)
			_track_path_perf()
	if perf and mode == "low" and frame == TOUR_FRAMES - 2:
		print("WV2 PERF view=%s draw_calls=%d primitives=%d objects=%d hero_height_frac=%.3f" % [view,
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME), _hero_fraction()])
	# --wv2-tour: as 4 vistas baixas em sequencia (provas: um quadro final por vista a cada TOUR_FRAMES)
	if tour and mode == "low" and frame >= TOUR_FRAMES:
		var i := VIEW_KEYS.find(view)
		if i < VIEW_KEYS.size() - 1:
			_set_view(VIEW_KEYS[i + 1])


func _track_path_perf() -> void:
	if not perf or path_t < 0.3:
		return
	var dc := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	if dc > int(path_max.draw_calls):
		path_max = {"draw_calls": dc, "primitives": int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
			"objects": int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)), "t": path_t}


func _print_path_perf() -> void:
	if perf:
		print("WV2 PERF path_max draw_calls=%d primitives=%d objects=%d at_t=%.1f" % [path_max.draw_calls, path_max.primitives,
			path_max.objects, path_max.t])


func _exit_tree() -> void:
	if mode == "path":
		_print_path_perf()


## Fracao da altura da tela ocupada pelo heroi principal (vista do cais).
func _hero_fraction() -> float:
	if heroes.is_empty() or view != "dock":
		return 0.0
	var p := heroes[0].global_position
	var feet := cam.unproject_position(p)
	var head := cam.unproject_position(p + Vector3(0, 1.14, 0))
	return absf(feet.y - head.y) / get_viewport().get_visible_rect().size.y


# ---------------------------------------------------------------- ajuda na tela

func _build_help() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var layer := CanvasLayer.new()
	add_child(layer)
	help = Label.new()
	help.text = Loc.t("wv2.help")
	help.position = Vector2(16, 12)
	help.add_theme_font_size_override("font_size", 15)
	help.add_theme_color_override("font_color", Color(1, 1, 1, 0.92))
	help.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	help.add_theme_constant_override("shadow_offset_x", 1)
	help.add_theme_constant_override("shadow_offset_y", 1)
	layer.add_child(help)
	# nas provas (Movie Maker) a ajuda fica escondida
	help.visible = Engine.get_write_movie_path().is_empty()
