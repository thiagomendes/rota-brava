class_name Stylize
extends RefCounted
## Converte materiais comuns (GLB importado, blocos) para o sombreador estilizado do projeto,
## para personagens, adereços e cenario formarem uma familia visual.

const SHADER := preload("res://art/stylized.gdshader")

static var _cache: Dictionary = {}


static func material_for(src: Material) -> Material:
	if src == null or src is ShaderMaterial:
		return src
	if not (src is BaseMaterial3D):
		return src
	var base := src as BaseMaterial3D
	if base.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
		return src
	var key := src.get_instance_id()
	if _cache.has(key):
		return _cache[key]
	var m := ShaderMaterial.new()
	m.resource_name = src.resource_name
	m.shader = SHADER
	m.set_shader_parameter("albedo", base.albedo_color)
	m.set_shader_parameter("use_vertex_color", base.vertex_color_use_as_albedo)
	m.set_shader_parameter("roughness_value", clampf(base.roughness, 0.4, 1.0))
	if base.albedo_texture != null:
		m.set_shader_parameter("albedo_tex", base.albedo_texture)
		m.set_shader_parameter("use_tex", true)
	if base.emission_enabled:
		m.set_shader_parameter("emission_color", base.emission)
		m.set_shader_parameter("emission_energy", base.emission_energy_multiplier)
	_cache[key] = m
	return m


## Pecas pequenas (tufos, juncos, baldes) quase nao contribuem para a sombra e custam chamadas de desenho: nao projetam sombra.
static func trim_small_shadows(root: Node, max_extent: float = 0.7) -> int:
	var trimmed := 0
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		var size := mi.get_aabb().size * mi.global_transform.basis.get_scale()
		if maxf(size.x, maxf(size.y, size.z)) < max_extent:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			trimmed += 1
	return trimmed


## Aplica o sombreador estilizado a toda MeshInstance3D sob `root` (sem alterar os recursos importados).
static func apply(root: Node) -> void:
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		if mi.material_override != null:
			mi.material_override = material_for(mi.material_override)
			continue
		for i in mi.mesh.get_surface_count():
			var src := mi.get_active_material(i)
			var out := material_for(src)
			if out != src:
				mi.set_surface_override_material(i, out)
