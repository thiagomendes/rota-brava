class_name Farol7Base
extends Node3D
## Palco da base Farol 7 (RB-R1 G21, art3d, PROVISORIO): a sala do radio, a cadeira giratoria, a luz giratoria amarela da
## base (na claraboia e no topo da casa-torre), o exterior da casa-torre na ponta das pedras e o mar com a Vila Mare ao
## longe pela escotilha. Fica fora da vila: e um palco de cutscene. Geometria: source_art/farol7_base/build_farol7_base.py.
##
## Contrato para o jogo:
##   marker(&"Base_Chair")       pivo da cadeira (no chao); o no `Chair` gira em Y (`set_chair_yaw`)
##   marker(&"Base_Seat")        onde fica o Lumi sentado (reserva: os clipes sentados nao existem ainda)
##   marker(&"Base_LumiStand")   Lumi de pe no console do radio, de frente para a camera
##   marker(&"Base_CamWide"), marker(&"Base_CamFront"), marker(&"Base_CamMic")   cameras dos planos 9a/9b/9c (olham para -Z local)
##   marker(&"Base_Exterior"), marker(&"Base_CamExterior")                        casa-torre por fora (plano 9a)
##   set_on_air(true/false)      luz "no ar" do console pisca enquanto o Lumi fala
## O no `StageEnvironment` (ceu, luz ambiente e sol) pode ser removido por quem ja tem ambiente (`use_own_environment`).

const PIN_PORTRAITS := {
	"f7_pin_rastro": ["res://ui/portraits/rastro_alegre.png", Color("ff8a1f")],
	"f7_pin_pico": ["res://ui/portraits/pico_alegre.png", Color("3dbe5a")],
	"f7_pin_leme": ["res://ui/portraits/leme_alegre.png", Color("2f8cff")],
}
const PIN_SHADER := preload("res://worlds/farol7_base/f7_pin.gdshader")

## Graus por segundo da luz giratoria (gira sempre, mesmo de dia).
@export var beacon_speed_deg: float = 80.0
@export var use_own_environment: bool = true

static var _own: Dictionary = {}
var _spins: Array[Node3D] = []
var _led: StandardMaterial3D
var _on_air := false
var _t := 0.0


func _ready() -> void:
	var stage_env := get_node_or_null(^"StageEnvironment")
	if stage_env != null:
		if use_own_environment:
			_build_environment(stage_env)
		else:
			stage_env.queue_free()
	apply_materials(self)
	for n in find_children("BeaconSpin", "", true, false):
		_spins.append(n as Node3D)
	_led = material_for("f7_led") as StandardMaterial3D


func _process(delta: float) -> void:
	_t += delta
	for s in _spins:
		s.rotate_y(deg_to_rad(beacon_speed_deg) * delta)
	if _led != null:
		_led.emission_energy_multiplier = (2.4 if fmod(_t, 0.5) < 0.3 else 0.4) if _on_air else 0.5


## Ceu e sol iguais aos da vila v3 (village_world.gd), com mais luz ambiente para dentro da sala; o sol vem do norte
## (entra pela escotilha e pela claraboia).
func _build_environment(parent: Node) -> void:
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = load("res://art/sky.gdshader") as Shader
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
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 1.0
	env.ambient_light_energy = 0.55
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 6.0
	env.ssao_enabled = true
	env.ssao_radius = 0.8
	env.ssao_intensity = 1.8
	env.ssao_light_affect = 0.2
	env.ssil_enabled = true
	env.ssil_radius = 2.0
	env.ssil_intensity = 0.8
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = Color("a9cdea")
	env.fog_density = 0.0042
	env.fog_aerial_perspective = 0.35
	env.fog_sky_affect = 0.0
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.03
	env.glow_hdr_threshold = 1.2
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.10
	env.adjustment_contrast = 1.05
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	parent.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = Color("ffe3b8")
	sun.light_energy = 2.2
	sun.light_angular_distance = 0.5
	sun.shadow_enabled = true
	sun.shadow_bias = 0.03
	sun.shadow_normal_bias = 1.0
	sun.shadow_blur = 0.5
	sun.directional_shadow_max_distance = 60.0
	sun.rotation_degrees = Vector3(-42.0, 160.0, 0.0)
	parent.add_child(sun)


func marker(id: StringName) -> Node3D:
	return find_child(String(id), true, false) as Node3D


func set_on_air(on: bool) -> void:
	_on_air = on


## Gira a cadeira em torno do pe (0 = assento virado para a camera / sul; 180 = virado para a mesa).
func set_chair_yaw(deg: float) -> void:
	var ch := get_node_or_null(^"Chair") as Node3D
	if ch != null:
		ch.rotation.y = deg_to_rad(deg)


## Troca cada superficie pelo material da biblioteca: `wv2_*`/`pv3_*` (vila v2.1) ou `f7_*` (desta base).
static func apply_materials(root: Node) -> int:
	var count := 0
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(i)
			if src == null:
				continue
			var n := src.resource_name
			var m: Material = material_for(n) if n.begins_with("f7_") else PropsV3Piece.material_for(n)
			if m != null:
				mi.set_surface_override_material(i, m)
				count += 1
				if n == "f7_beam" or n == "f7_glass":
					mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return count


static func material_for(mat_name: String) -> Material:
	if _own.has(mat_name):
		return _own[mat_name]
	var m: Material = _build(mat_name)
	if m != null:
		m.resource_name = mat_name
		_own[mat_name] = m
	return m


static func _build(mat_name: String) -> Material:
	if PIN_PORTRAITS.has(mat_name):
		var spec: Array = PIN_PORTRAITS[mat_name]
		var sm := ShaderMaterial.new()
		sm.shader = PIN_SHADER
		sm.set_shader_parameter("portrait", load(String(spec[0])) as Texture2D)
		sm.set_shader_parameter("bg", spec[1])
		return sm
	var s := StandardMaterial3D.new()
	match mat_name:
		"f7_sea":
			s.vertex_color_use_as_albedo = true
			s.roughness = 0.12
			s.metallic_specular = 0.7
			s.clearcoat_enabled = true
			s.clearcoat = 0.6
		"f7_beam":
			s.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			s.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			s.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			s.vertex_color_use_as_albedo = true
			s.cull_mode = BaseMaterial3D.CULL_DISABLED
			s.albedo_color = Color(1.0, 0.92, 0.55, 0.55)
		"f7_lamp":
			s.albedo_color = Color("fff1b0")
			s.emission_enabled = true
			s.emission = Color("ffd23a")
			s.emission_energy_multiplier = 3.0
		"f7_glass":
			s.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			s.albedo_color = Color(0.86, 0.94, 1.0, 0.16)
			s.roughness = 0.04
			s.metallic_specular = 0.9
		"f7_led":
			s.albedo_color = Color("e2453a")
			s.emission_enabled = true
			s.emission = Color("ff5a40")
			s.emission_energy_multiplier = 0.5
		"f7_screen":
			s.albedo_color = Color("bff2da")
			s.emission_enabled = true
			s.emission = Color("9fe3c8")
			s.emission_energy_multiplier = 0.8
		_:
			return null
	return s
