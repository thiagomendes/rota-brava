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
const PAPER := preload("res://lookdev/world_v2/wv2_paper.gdshader")
const BEAM := preload("res://lookdev/world_v2/wv2_beam.gdshader")

## nome -> [textura, metros, parametros]. Tamanho em metros igual ao de wv2_textures.SPECS.
const SURF := {
	"wv2_deck": ["deck", 2.0, {"normal_depth": 1.2, "macro_amount": 0.06}],
	"wv2_wood": ["wood", 1.0, {"normal_depth": 1.0}],
	"wv2_paint": ["paint", 1.0, {"normal_depth": 1.0, "rough_mul": 0.9, "specular_amount": 0.45}],
	"wv2_slats": ["slats", 0.5, {"normal_depth": 1.0, "rough_mul": 0.9}],
	"wv2_plaster": ["plaster", 2.0, {"normal_depth": 1.0, "grime_amount": 0.35, "grime_height": 0.9, "macro_amount": 0.06}],
	"wv2_stone": ["stone", 2.0, {"normal_depth": 1.3, "macro_amount": 0.08}],
	"wv2_cobble": ["cobble", 1.5, {"normal_depth": 1.0, "macro_amount": 0.06}],
	"wv2_roof": ["roof", 1.0, {"normal_depth": 1.2, "macro_amount": 0.1, "specular_amount": 0.45}],
	"wv2_canvas": ["canvas", 1.0, {"normal_depth": 0.8, "macro_amount": 0.03}],
	"wv2_metal": ["metal", 0.5, {"metallic_amount": 0.35, "specular_amount": 0.6, "macro_amount": 0.03}],
	"wv2_rope": ["rope", 0.25, {"normal_depth": 1.2, "macro_amount": 0.04}],
	"wv2_net": ["net", 0.5, {"normal_depth": 1.0}],
	"wv2_bark": ["bark", 1.0, {"normal_depth": 1.3}],
	"wv2_burlap": ["burlap", 0.5, {"normal_depth": 1.2, "macro_amount": 0.05}],
	"wv2_interior": ["plaster", 2.0, {"normal_depth": 0.4, "tint": Color(0.62, 0.58, 0.55), "macro_amount": 0.04}],
	"wv2_interior_lit": ["plaster", 2.0, {"normal_depth": 0.4, "tint": Color(0.85, 0.72, 0.55), "emission_albedo": 1.0,
		"emission_energy": 0.35, "macro_amount": 0.04}],
	"wv2_paw": ["paint", 1.0, {"normal_depth": 0.3, "tint": Color(0.36, 0.23, 0.16), "rough_mul": 0.6}],
	"wv2_glossy": ["plaster", 2.0, {"normal_depth": 0.25, "rough_mul": 0.35, "specular_amount": 0.6, "clearcoat_amount": 0.4,
		"macro_amount": 0.03}],
}
const TRI := {
	"wv2_leaf": ["leaf", 1.5, {"normal_depth": 1.0, "backlight_color": Color(0.32, 0.42, 0.12), "wind": 1.0,
		"specular_amount": 0.3, "macro_amount": 0.12}],
	"wv2_rock": ["rock", 2.0, {"normal_depth": 1.2, "macro_amount": 0.1}],
}

static var _cache: Dictionary = {}
## Brilho dos interiores acesos e das lanternas: dia (discreto) e noite (forte). Ver set_night().
const LIT_DAY := 0.35
const LIT_NIGHT := 2.4
const LAMP_DAY := 2.6
const LAMP_NIGHT := 7.0
## Lanternas de papel da festa (E3, M8): apagadas (so papel colorido) ou acesas.
const PAPER_OFF := 0.0
const PAPER_ON := 3.2
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
			# vidro transparente: reflete o ceu e deixa ver o comodo raso atras (interior modelado no Blender)
			var gl := StandardMaterial3D.new()
			gl.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			gl.albedo_color = Color(0.14, 0.24, 0.32, 0.3)
			gl.roughness = 0.04
			gl.metallic_specular = 1.0
			gl.metallic = 0.1
			gl.rim_enabled = true
			gl.rim = 0.2
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
		"wv2_paper":
			var pp := ShaderMaterial.new()
			pp.shader = PAPER
			pp.set_shader_parameter("glow", PAPER_OFF)
			return pp
		"wv2_beam":
			# feixe da lanterna do farol: cone aditivo, some ao longe e nas bordas (liga/desliga pelo no)
			var bm := ShaderMaterial.new()
			bm.shader = BEAM
			return bm
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


## Dia/noite: so muda o brilho das janelas acesas, vitrines e lanternas (os materiais sao compartilhados).
static func set_night(night: bool) -> void:
	var lit := get_material("wv2_interior_lit") as ShaderMaterial
	lit.set_shader_parameter("emission_energy", LIT_NIGHT if night else LIT_DAY)
	var lamp := get_material("wv2_lamp") as StandardMaterial3D
	lamp.emission_energy_multiplier = LAMP_NIGHT if night else LAMP_DAY


## Noite de festa (E3, M8): acende as lanternas de papel penduradas e dos barquinhos (material compartilhado).
static func set_festival(on: bool) -> void:
	var paper := get_material("wv2_paper") as ShaderMaterial
	paper.set_shader_parameter("glow", PAPER_ON if on else PAPER_OFF)


## RB-R1 G24a2: variante pontilhada de um material da biblioteca (mesmos parametros, shader com
## wv2_occlusion.gdshaderinc). So a peca que tapa o heroi usa a variante, e so enquanto o fade dura (CameraOcclusion).
## Material que nao e ShaderMaterial com `void fragment() {` volta sem variante (a peca nao pontilha).
const OCCL_INC := "res://lookdev/world_v2/wv2_occlusion.gdshaderinc"
static var _occl_shaders: Dictionary = {}
static var _occl_mats: Dictionary = {}
static var _occl_meshes: Dictionary = {}


static func occl_variant(m: Material) -> Material:
	if m is BaseMaterial3D:
		return _occl_base(m as BaseMaterial3D)
	var sm := m as ShaderMaterial
	if sm == null or sm.shader == null or not sm.shader.code.contains("void fragment() {"):
		return m
	if _occl_mats.has(sm):
		return _occl_mats[sm]
	var sh: Shader = _occl_shaders.get(sm.shader)
	if sh == null:
		var code := sm.shader.code
		var nl := code.find("\n")
		code = code.substr(0, nl + 1) + "#include \"%s\"\n" % OCCL_INC + code.substr(nl + 1)
		code = code.replace("void fragment() {", "void fragment() {\n\tocc" + "l_discard((INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz, FRAGCOORD.xy, PROJECTION_MATRIX);")
		sh = Shader.new()
		sh.code = code
		_occl_shaders[sm.shader] = sh
	var v := sm.duplicate() as ShaderMaterial
	v.shader = sh
	_occl_mats[sm] = v
	return v


## Peca de missao com StandardMaterial3D: o codigo que a Godot gerou para o material vira ShaderMaterial com o
## pontilhado, com os mesmos parametros. Sem servidor de render (headless) nao ha codigo: volta o proprio material.
static func _occl_base(m: BaseMaterial3D) -> Material:
	if _occl_mats.has(m):
		return _occl_mats[m]
	var code := RenderingServer.shader_get_code(RenderingServer.material_get_shader(m.get_rid()))
	if not code.contains("void fragment() {"):
		return m
	var sh := Shader.new()
	var nl := code.find("\n")
	sh.code = code.substr(0, nl + 1) + "#include \"%s\"\n" % OCCL_INC + code.substr(nl + 1).replace("void fragment() {",
		"void fragment() {\n\tocc" + "l_discard((INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz, FRAGCOORD.xy, PROJECTION_MATRIX);")
	var v := ShaderMaterial.new()
	v.shader = sh
	for u: Dictionary in sh.get_shader_uniform_list():
		var val: Variant = RenderingServer.material_get_param(m.get_rid(), StringName(u["name"]))
		if val != null:
			v.set_shader_parameter(StringName(u["name"]), val)
	_occl_mats[m] = v
	return v


## Variantes ja criadas (aquecimento na carga).
static func occl_variants() -> Array:
	return _occl_mats.values()


## Malha com cada material trocado pela variante pontilhada (cache por malha; a peca do kit vira um MeshInstance3D).
static func occl_mesh(src: Mesh) -> Mesh:
	if _occl_meshes.has(src):
		return _occl_meshes[src]
	var mesh := src.duplicate() as Mesh
	for i in mesh.get_surface_count():
		var m := mesh.surface_get_material(i)
		if m != null:
			mesh.surface_set_material(i, occl_variant(m))
	_occl_meshes[src] = mesh
	return mesh


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
