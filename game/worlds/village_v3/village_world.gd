class_name VillageWorld
extends Node3D
## MUNDO JOGAVEL da vila v2.1 para o Ep01 v3 (RB-R1 E3). PROVISORIO ate aprovacao de Thiago.
## Monta o visual aprovado na vitrine (D14) sem a logica da vitrine (sem camera, sem teclas):
## cenario fixo (wv2_static.glb), aderecos em MultiMesh (layout gerado pelo Blender), pecas soltas das missoes
## (wv3_props.glb: lanterna giratoria do farol, bote do capitao, boias de rota, barquinhos da festa, lanternas de papel,
## lente), agua, ceu, sol, luzes quentes locais e ambiente. A colisao, os limites e os marcadores M0-M8 ja estao na cena
## (village_world.tscn, gerada por source_art/environment_v2/wv3_collision.py).
## Uso no episodio: instanciar village_world.tscn; ler marcadores com marker(&"M3_Grate") ou markers_for("M3");
## set_night(), set_festival() (noite de festa), lantern (Node3D: gire em Y), set_beam(); set_access_ramps() (E3b).

const STATIC_GLB := "res://assets/models/environment_v2/wv2_static.glb"
const KIT_GLB := "res://assets/models/environment_v2/wv2_kit.glb"
const PROPS_GLB := "res://assets/models/environment_v2/wv3_props.glb"
const LAYOUT := "res://lookdev/world_v2/world_v2_layout.json"
const SKY_SHADER := "res://art/sky.gdshader"
## Sem sombra: pecas pequenas e numerosas (mesma regra da vitrine).
const NO_SHADOW := ["grass_tuft", "grass_tall", "flowers_a", "flowers_b", "reeds", "float_buoy", "bucket", "pot_a", "pot_b",
	"pot_c", "rope_coil", "fender", "life_ring", "sack", "bollard"]
const RANGE := {"grass_tuft": 45.0, "grass_tall": 50.0, "flowers_a": 45.0, "flowers_b": 45.0, "reeds": 70.0, "float_buoy": 60.0,
	"bucket": 50.0, "rope_coil": 50.0, "sack": 60.0, "pot_a": 70.0, "pot_b": 70.0, "pot_c": 70.0}
const LIGHTS := {
	"window": [Color("ffb867"), 0.7, 2.6],
	"wall_lamp": [Color("ffc47a"), 1.6, 3.6],
	"shop": [Color("ffc98a"), 1.0, 3.2],
	"awning": [Color("ffc47a"), 1.1, 3.0],
	"lighthouse": [Color("ffe2a8"), 3.0, 7.0],
	"lamp_post": [Color("ffb35c"), 1.8, 5.0],
	"festa": [Color("ffb060"), 1.3, 3.4],
}
## Luzes de festa: uma a cada N lanternas de papel (custo: cada OmniLight a mais pesa no celular).
const FESTA_LIGHT_EVERY := 4

@export var build_on_ready := true
@export var with_water := true

var layout: Dictionary = {}
var env: Environment
var sun: DirectionalLight3D
var fill: DirectionalLight3D
var sky_mat: ShaderMaterial
var local_lights: Array[OmniLight3D] = []
var festa_lights: Array[OmniLight3D] = []
var props: Dictionary = {}          # nome do GLB (wv3_*) -> Node3D
var lantern: Node3D                  # lanterna do farol (girar em Y; frente = -Z local)
var lantern_beam: Node3D
var lantern_light: SpotLight3D
var night := false
var festival := false
var stats := {"kits": 0, "instances": 0, "lights": 0, "surfaces": 0}


func _ready() -> void:
	if build_on_ready:
		build()


func build() -> void:
	layout = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT)) as Dictionary
	_build_environment()
	if with_water:
		var water := WaterSurface.new()
		add_child(water)
		_tune_water(water)
	var st := (load(STATIC_GLB) as PackedScene).instantiate() as Node3D
	st.name = "Static"
	add_child(st)
	stats.surfaces = WV2Materials.apply(st)
	_build_kit()
	_build_lights()
	_build_props()
	set_beam(false)


# ---------------------------------------------------------------- marcadores

func marker(marker_name: StringName) -> Marker3D:
	return get_node_or_null(NodePath("Markers/" + String(marker_name))) as Marker3D


func markers_for(mission: String) -> Array[Marker3D]:
	var out: Array[Marker3D] = []
	var root := get_node_or_null("Markers")
	if root == null:
		return out
	for n in root.get_children():
		if n is Marker3D and String(n.get_meta("mission", "")) == mission:
			out.append(n as Marker3D)
	return out


# ---------------------------------------------------------------- rampas de acesso (E3b)

## Camada da fisica (valor de bit) das rampas invisiveis sobre degraus de missao (Collision/AccessRamps).
const ACCESS_RAMPS_LAYER := 16


## Rampas invisiveis sobre os degraus que um heroi sem step-up nao sobe (farol, chafariz). Desligadas
## por padrao: ficam so na camada 5 (fora da mascara 1 do heroi). Ligadas, entram tambem na camada 1 (mundo).
## Alternativa sem chamar isto: por a camada 5 na mascara do heroi. Cada forma tem metadata mission/covers/to_marker.
func set_access_ramps(on: bool) -> void:
	var body := get_node_or_null("Collision/AccessRamps") as StaticBody3D
	if body != null:
		body.collision_layer = ACCESS_RAMPS_LAYER | (1 if on else 0)


func access_ramps_enabled() -> bool:
	var body := get_node_or_null("Collision/AccessRamps") as StaticBody3D
	return body != null and (body.collision_layer & 1) != 0


# ---------------------------------------------------------------- estados

## Noite: lua fria fraca, ceu azul-escuro; janelas, vitrines, postes e lanternas mais fortes (igual a vitrine).
func set_night(on: bool) -> void:
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


## Noite de festa (M8): noite + lanternas de papel acesas (penduradas e nos barquinhos) com luzes quentes + feixe do farol.
func set_festival(on: bool) -> void:
	festival = on
	if on and not night:
		set_night(true)
	WV2Materials.set_festival(on)
	for l in festa_lights:
		l.visible = on
	set_beam(on)


## Feixe da lanterna do farol (cone + SpotLight). A lanterna gira por fora: lantern.rotation.y.
func set_beam(on: bool) -> void:
	if lantern_beam != null:
		lantern_beam.visible = on
	if lantern_light != null:
		lantern_light.visible = on


# ---------------------------------------------------------------- montagem

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
			push_warning("VillageWorld: kit sem malha: " + kind)
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


func _add_light(pos: Vector3, kind: String, parent: Node = self) -> OmniLight3D:
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
	parent.add_child(l)
	l.position = pos
	l.set_meta("day_energy", l.light_energy)
	stats.lights += 1
	return l


func _build_lights() -> void:
	var root := Node3D.new()
	root.name = "Lights"
	add_child(root)
	for l: Dictionary in layout["luzes"]:
		var p: Array = l["pos"]
		local_lights.append(_add_light(Vector3(float(p[0]), float(p[1]), float(p[2])), String(l["tipo"]), root))
	for r: Array in (layout["kit"] as Dictionary).get("lamp_post", []):
		local_lights.append(_add_light(Vector3(float(r[0]), float(r[1]) + 3.12, float(r[2])), "lamp_post", root))
	var festa := Node3D.new()
	festa.name = "FestaLights"
	add_child(festa)
	var pts: Array = layout.get("festa_lanternas", [])
	for i in range(0, pts.size(), FESTA_LIGHT_EVERY):
		var p: Array = pts[i]
		festa_lights.append(_add_light(Vector3(float(p[0]), float(p[1]), float(p[2])), "festa", festa))
	for p: Array in layout.get("festa_barcos_lanternas", []):
		festa_lights.append(_add_light(Vector3(float(p[0]), float(p[1]), float(p[2])), "festa", festa))
	for l in festa_lights:
		l.distance_fade_begin = 80.0
		l.visible = false


func _build_props() -> void:
	var scene := (load(PROPS_GLB) as PackedScene).instantiate() as Node3D
	scene.name = "Props"
	add_child(scene)
	stats.surfaces += WV2Materials.apply(scene)
	for n in scene.find_children("wv3_*", "Node3D", true, false):
		props[String(n.name)] = n
		(n as Node3D).set_meta(Blocks.PROVISIONAL, true)
	lantern = props.get("wv3_lantern") as Node3D
	lantern_beam = props.get("wv3_lantern_beam") as Node3D
	if lantern_beam != null:
		for mi in lantern_beam.find_children("*", "MeshInstance3D", true, false) + [lantern_beam]:
			if mi is GeometryInstance3D:
				(mi as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if lantern != null:
		lantern_light = SpotLight3D.new()
		lantern_light.name = "BeamLight"
		lantern_light.light_color = Color("ffe6b0")
		lantern_light.light_energy = 6.0
		lantern_light.spot_range = 45.0
		lantern_light.spot_angle = 9.0
		lantern_light.shadow_enabled = false
		lantern.add_child(lantern_light)
		lantern_light.position = Vector3(0, 0.65, -0.5)
		# aponta para -Z local e um pouco para baixo (o mar em volta do promontorio)
		lantern_light.rotation = Vector3(deg_to_rad(-7.0), 0, 0)
	# lanternas dos barquinhos da festa e luz das boias de rota: brilho proprio vem do material
	for n: Node3D in [props.get("wv3_buoy_a"), props.get("wv3_buoy_b")]:
		if n != null:
			for mi in n.find_children("*", "MeshInstance3D", true, false) + [n]:
				if mi is GeometryInstance3D:
					(mi as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
