class_name WV2Materials
extends RefCounted
## Mundo v2 (RB-R1 W1): biblioteca de materiais da vitrine "vila e cais v2". Cada material do Blender (`wv2_*`, nome
## no GLB) vira aqui um ShaderMaterial com as texturas procedurais assadas (game/assets/textures/environment_v2/).
## So a vitrine usa: o jogo nao muda. PROVISORIO ate aprovacao de Thiago.

const TEX := "res://assets/textures/environment_v2/%s_%s"
const SURFACE := preload("res://lookdev/world_v2/wv2_surface.gdshader")
const TRIPLANAR := preload("res://lookdev/world_v2/wv2_triplanar.gdshader")
const GRASS := preload("res://lookdev/world_v2/wv2_grass.gdshader")
const TERRAIN := preload("res://lookdev/world_v2/wv2_terrain.gdshader")

## nome -> [textura, metros, parametros]. Tamanho em metros igual ao de wv2_textures.SPECS.
const SURF := {
	"wv2_deck": ["deck", 2.0, {"normal_depth": 1.2, "macro_amount": 0.06}],
	"wv2_wood": ["wood", 1.0, {"normal_depth": 1.0}],
	"wv2_paint": ["paint", 1.0, {"normal_depth": 1.0, "rough_mul": 0.9, "specular_amount": 0.45}],
	"wv2_slats": ["slats", 0.5, {"normal_depth": 1.0, "rough_mul": 0.9}],
	"wv2_plaster": ["plaster", 2.0, {"normal_depth": 1.0, "grime_amount": 0.35, "grime_height": 0.9, "macro_amount": 0.06}],
	"wv2_stone": ["stone", 2.0, {"normal_depth": 1.3, "macro_amount": 0.08}],
	"wv2_cobble": ["cobble", 1.5, {"normal_depth": 1.3, "macro_amount": 0.1}],
	"wv2_roof": ["roof", 1.0, {"normal_depth": 1.2, "macro_amount": 0.1, "specular_amount": 0.45}],
	"wv2_canvas": ["canvas", 1.0, {"normal_depth": 0.8, "macro_amount": 0.03}],
	"wv2_metal": ["metal", 0.5, {"metallic_amount": 0.35, "specular_amount": 0.6, "macro_amount": 0.03}],
	"wv2_rope": ["rope", 0.25, {"normal_depth": 1.2, "macro_amount": 0.04}],
	"wv2_net": ["net", 0.5, {"normal_depth": 1.0}],
	"wv2_bark": ["bark", 1.0, {"normal_depth": 1.3}],
	"wv2_glossy": ["plaster", 2.0, {"normal_depth": 0.25, "rough_mul": 0.35, "specular_amount": 0.6, "clearcoat_amount": 0.4,
		"macro_amount": 0.03}],
}
const TRI := {
	"wv2_leaf": ["leaf", 1.5, {"normal_depth": 1.0, "backlight_color": Color(0.32, 0.42, 0.12), "wind": 1.0,
		"specular_amount": 0.3, "macro_amount": 0.12}],
	"wv2_rock": ["rock", 2.0, {"normal_depth": 1.2, "macro_amount": 0.1}],
}

static var _cache: Dictionary = {}
static var unknown: Dictionary = {}


static func tex(name: String, kind: String) -> Texture2D:
	var ext := "jpg" if kind == "albedo" else "png"
	return load(TEX % [name, kind + "." + ext]) as Texture2D


static func get_material(mat_name: String) -> Material:
	if _cache.has(mat_name):
		return _cache[mat_name]
	var m: Material = _build(mat_name)
	_cache[mat_name] = m
	return m


static func _build(mat_name: String) -> Material:
	if SURF.has(mat_name):
		var spec: Array = SURF[mat_name]
		return _shader(SURFACE, String(spec[0]), float(spec[1]), spec[2])
	if TRI.has(mat_name):
		var spec2: Array = TRI[mat_name]
		return _shader(TRIPLANAR, String(spec2[0]), float(spec2[1]), spec2[2])
	match mat_name:
		"wv2_grass":
			var g := ShaderMaterial.new()
			g.shader = GRASS
			return g
		"wv2_terrain":
			var t := ShaderMaterial.new()
			t.shader = TERRAIN
			for n: String in ["grass", "dirt", "rock"]:
				t.set_shader_parameter(n + "_albedo", tex(n, "albedo"))
				t.set_shader_parameter(n + "_data", tex(n, "data"))
			return t
		"wv2_glass":
			var gl := StandardMaterial3D.new()
			gl.albedo_color = Color("2c4a66")
			gl.roughness = 0.06
			gl.metallic_specular = 0.9
			gl.rim_enabled = true
			gl.rim = 0.25
			return gl
		"wv2_glass_lit":
			var gw := StandardMaterial3D.new()
			gw.albedo_color = Color("2e3640")
			gw.roughness = 0.06
			gw.metallic_specular = 0.9
			gw.rim_enabled = true
			gw.rim = 0.2
			gw.emission_enabled = true
			gw.emission = Color("ff9a45")
			gw.emission_energy_multiplier = 0.18
			return gw
		"wv2_lamp":
			var l := StandardMaterial3D.new()
			l.albedo_color = Color("ffe6b0")
			l.emission_enabled = true
			l.emission = Color("ffcf7a")
			l.emission_energy_multiplier = 2.6
			l.roughness = 0.2
			return l
	unknown[mat_name] = true
	var d := StandardMaterial3D.new()
	d.vertex_color_use_as_albedo = true
	return d


static func _shader(sh: Shader, tex_name: String, meters: float, params: Dictionary) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("albedo_tex", tex(tex_name, "albedo"))
	m.set_shader_parameter("data_tex", tex(tex_name, "data"))
	m.set_shader_parameter("tex_meters", meters)
	for k: String in params:
		m.set_shader_parameter(k, params[k])
	return m


## Troca os materiais de toda malha sob `root` pelo material da biblioteca com o mesmo nome. Devolve quantas superficies.
static func apply(root: Node) -> int:
	var count := 0
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(i)
			if src == null:
				continue
			mi.set_surface_override_material(i, get_material(src.resource_name))
			count += 1
	return count


## Malha com os materiais da biblioteca embutidos (para MultiMesh, que nao tem override por superficie).
static func baked_mesh(src: Mesh) -> Mesh:
	var mesh := src.duplicate() as Mesh
	for i in mesh.get_surface_count():
		var m := mesh.surface_get_material(i)
		if m != null:
			mesh.surface_set_material(i, get_material(m.resource_name))
	return mesh
