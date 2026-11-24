class_name LookdevMaterials
extends RefCounted
## Lookdev RB-R1 (D11): troca, SO EM TEMPO DE EXECUCAO, os materiais de um modelo pelos materiais novos
## (vinil, tecido, madeira, pedra, chao, pintado, folhagem) em game/lookdev/materials/. Nao altera nenhum recurso
## do jogo: cria ShaderMaterial a partir dos presets .tres e aplica como override de superficie.
## A cor base vem do material original (albedo + cor de vertice); o papel e deduzido do nome do material
## (`mat_<personagem>_<papel>` nos herois, `mat_env_<nome>` no cenario). PROVISORIO ate a aprovacao de Thiago.

const DIR := "res://lookdev/materials/"
const PRESETS := {
	&"skin": "mat_ld_vinyl_skin.tres",
	&"toy": "mat_ld_vinyl_toy.tres",
	&"eye": "mat_ld_vinyl_eye.tres",
	&"weave": "mat_ld_fabric_weave.tres",
	&"rib": "mat_ld_fabric_rib.tres",
	&"knit": "mat_ld_fabric_knit.tres",
	&"canvas": "mat_ld_fabric_canvas.tres",
	&"wood": "mat_ld_wood.tres",
	&"stone": "mat_ld_stone.tres",
	&"cobble": "mat_ld_stone_cobble.tres",
	&"ground": "mat_ld_ground.tres",
	&"painted": "mat_ld_painted.tres",
	&"gloss_paint": "mat_ld_painted_gloss.tres",
	&"foliage": "mat_ld_foliage.tres",
}

## Papel do material nos herois -> [preset, parametros extras]. `keep` mantem o original (luz emissiva).
const CHARACTER_ROLES := {
	"pele": [&"skin", {}],
	"rubor": [&"skin", {"roughness": 0.55}],
	"boca": [&"skin", {"roughness": 0.35, "warm_amount": 0.0}],
	"olhos": [&"eye", {}],
	"iris": [&"eye", {"roughness": 0.12}],
	"vidro": [&"eye", {"roughness": 0.05}],
	"escuro": [&"toy", {"roughness": 0.28, "grad_strength": 0.0}],
	"cabelo": [&"toy", {"roughness": 0.40, "clearcoat": 0.25}],
	"botas": [&"toy", {"roughness": 0.50, "grad_top": 0.25}],
	"couro": [&"toy", {"roughness": 0.62, "clearcoat": 0.05, "micro_bump": 0.004, "micro_scale": 220.0}],
	"ouro": [&"toy", {"roughness": 0.30, "metallic": 0.55}],
	"metal": [&"toy", {"roughness": 0.28, "metallic": 0.70}],
	"emblema": [&"toy", {"roughness": 0.32}],
	"refletivo": [&"toy", {"roughness": 0.22, "specular": 0.7}],
	"uniforme": [&"weave", {}],
	"calca": [&"weave", {"scale": 95.0}],
	"creme": [&"rib", {}],
	"colete": [&"weave", {"scale": 70.0, "groove_dark": 0.75}],
	"corda": [&"rib", {"scale": 55.0, "groove_dark": 0.55}],
	"chapeu": [&"weave", {"scale": 60.0}],
	"luz": [&"keep", {}],
}
## Excecoes por personagem (ex.: capacete do Pico e plastico, nao tecido).
const CHARACTER_OVERRIDES := {
	"pico_chapeu": [&"toy", {"roughness": 0.34, "clearcoat": 0.45}],
}

## Cenario: primeira regra que casa com o nome (sem o prefixo mat_env_) decide o preset.
const ENV_RULES := [
	["glass|lamp|cloud|paw|bootprint|light", &"keep", {}],
	["awning|bunting|flag|sail|cloth", &"canvas", {}],
	["rope|net", &"rib", {"world_space": true, "scale": 45.0, "groove_dark": 0.55}],
	["foliage|bush|leaf|reed|hedge|canopy|tuft", &"foliage", {}],
	["ground|grass|lawn|soil|sand|dirt|bank|earth", &"ground", {}],
	["plaza|tile|path|pebble|cobble", &"cobble", {}],
	["rock|stone|masonry|quay|boulder|wall_stone|terrace", &"stone", {}],
	["wood|barrel|trunk|deck|bench|oar|plank|crate|ladder|pile|wheel|cork|stringer", &"wood", {}],
	["hull|boat_trim|boat_roof|boat_stripe|bucket|fender|rubber|buoy|gull|beak|white|peach", &"gloss_paint", {}],
]

static var _presets: Dictionary = {}
static var _cache: Dictionary = {}
static var unmatched: Dictionary = {}


static func preset(id: StringName) -> ShaderMaterial:
	if not _presets.has(id):
		_presets[id] = load(DIR + String(PRESETS[id])) as ShaderMaterial
	return _presets[id]


## Cria um material novo a partir de um preset, com cor base e parametros extras. Uso direto nos herois novos:
##   LookdevMaterials.make(&"weave", Color("ff8a1f"), {"scale": 110.0})
static func make(id: StringName, base_color: Color, extra: Dictionary = {}, vertex_color: bool = false) -> ShaderMaterial:
	var m := preset(id).duplicate() as ShaderMaterial
	m.set_shader_parameter("albedo", base_color)
	m.set_shader_parameter("use_vertex_color", vertex_color)
	for k: String in extra:
		m.set_shader_parameter(k, extra[k])
	return m


static func _from_source(src: Material, id: StringName, extra: Dictionary) -> Material:
	if id == &"keep" or not (src is BaseMaterial3D):
		return src
	var base := src as BaseMaterial3D
	if base.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
		return src
	var key := "%d:%s:%s" % [src.get_instance_id(), id, str(extra)]
	if _cache.has(key):
		return _cache[key]
	var col := base.albedo_color
	var m := make(id, col, extra, base.vertex_color_use_as_albedo)
	m.resource_name = "ld_" + src.resource_name
	_cache[key] = m
	return m


static func _role_of(mat_name: String) -> String:
	# mat_<personagem>_<papel>
	var parts := mat_name.split("_")
	return parts[parts.size() - 1] if parts.size() >= 3 else mat_name


static func character_material(src: Material) -> Material:
	if src == null:
		return src
	var n := src.resource_name
	var parts := n.split("_")
	var who := parts[1] if parts.size() >= 3 else ""
	var role := _role_of(n)
	var rule: Array = CHARACTER_OVERRIDES.get(who + "_" + role, CHARACTER_ROLES.get(role, [&"toy", {}]))
	if not CHARACTER_ROLES.has(role) and not CHARACTER_OVERRIDES.has(who + "_" + role):
		unmatched[n] = &"toy"
	return _from_source(src, rule[0], rule[1])


static func environment_material(src: Material) -> Material:
	if src == null:
		return src
	var n := src.resource_name.trim_prefix("mat_env_")
	for rule: Array in ENV_RULES:
		if RegEx.create_from_string("(" + String(rule[0]) + ")").search(n) != null:
			return _from_source(src, rule[1], rule[2])
	unmatched[src.resource_name] = &"painted"
	return _from_source(src, &"painted", {})


## Aplica em toda geometria sob `root`. `character` = true usa os papeis dos herois; senao, as regras do cenario.
static func apply(root: Node, character: bool) -> int:
	var count := 0
	for node in root.find_children("*", "GeometryInstance3D", true, false):
		if node is MeshInstance3D:
			var mi := node as MeshInstance3D
			if mi.mesh == null:
				continue
			for i in mi.mesh.get_surface_count():
				var src := mi.get_active_material(i)
				var dst := character_material(src) if character else environment_material(src)
				if dst != src:
					mi.set_surface_override_material(i, dst)
					count += 1
			_set_grain(mi, mi.global_transform, mi.mesh.get_aabb())
		elif node is MultiMeshInstance3D:
			var mmi := node as MultiMeshInstance3D
			if mmi.multimesh == null or mmi.multimesh.mesh == null:
				continue
			var mesh := mmi.multimesh.mesh.duplicate() as Mesh
			for i in mesh.get_surface_count():
				var src := mesh.surface_get_material(i)
				var dst := character_material(src) if character else environment_material(src)
				if dst != src:
					mesh.surface_set_material(i, dst)
					count += 1
			mmi.multimesh.mesh = mesh
			var xf := mmi.global_transform
			if mmi.multimesh.instance_count > 0:
				xf = xf * mmi.multimesh.get_instance_transform(0)
			_set_grain(mmi, xf, mesh.get_aabb())
	return count


## Veio da madeira ao longo do maior eixo da peca (no mundo).
static func _set_grain(gi: GeometryInstance3D, xf: Transform3D, aabb: AABB) -> void:
	var s := aabb.size
	var axis := Vector3.RIGHT
	if s.y > s.x * 1.5 and s.y > s.z * 1.5:
		axis = Vector3.UP
	elif s.z > s.x:
		axis = Vector3.BACK
	gi.set_instance_shader_parameter("grain_axis", (xf.basis * axis).normalized())
