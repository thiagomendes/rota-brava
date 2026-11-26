class_name PropsV3Piece
extends Node3D
## Peca de missao do Ep01 v3 (RB-R1, art3d): raiz de cada cena em game/assets/models/props_v3/*.tscn.
## Troca os materiais do GLB pelo acabamento da vila v2.1 (nome `wv2_*` -> WV2Materials) ou pelos 5 materiais proprios
## das pecas (`pv3_*`, abaixo; `pv3_beam` e o pilar de luz das pistas F2, source_art/clues_v3/) e toca a animacao inicial. Geometria: source_art/props_v3/build_props_v3.py.
##
## Contrato para o jogo (metadados na raiz de cada cena): `piece_id`, `mission`, `interactive` (bool), `interaction`
## (verbo: pick, hang, pull, carry, examine, throw...), `member` (heroi que age, ou vazio), `tris` e `tris_budget`.
## Animacoes: AnimationPlayer "AnimationPlayer" na raiz (pecas simples) ou dentro do GLB (gaivota); use play(nome).

const SURFACE := preload("res://lookdev/world_v2/wv2_surface.gdshader")
## Materiais proprios: tecido fosco, vinil (brinquedo, mesmo brilho largo do trio v2), brilho da seta e anel do pulso.
const OWN := {
	"pv3_cloth": ["plaster", 2.0, {"normal_depth": 0.5, "rough_mul": 1.0, "specular_amount": 0.3, "macro_amount": 0.03}],
	"pv3_vinyl": ["plaster", 2.0, {"normal_depth": 0.2, "rough_mul": 0.5, "specular_amount": 0.55, "clearcoat_amount": 0.35,
		"macro_amount": 0.02}],
}

static var _own: Dictionary = {}

## Animacao tocada ao entrar na arvore (vazio = nenhuma).
@export var autoplay_anim: StringName = &""


func _ready() -> void:
	apply_materials(self)
	if autoplay_anim != &"":
		play(autoplay_anim)


## AnimationPlayer da peca: o da raiz ou, se nao houver, o primeiro dentro do modelo (GLB com acoes).
func animation_player() -> AnimationPlayer:
	var own := get_node_or_null(^"AnimationPlayer") as AnimationPlayer
	if own != null:
		return own
	var found := find_children("*", "AnimationPlayer", true, false)
	return found[0] as AnimationPlayer if not found.is_empty() else null


func animation_names() -> PackedStringArray:
	var ap := animation_player()
	return ap.get_animation_list() if ap != null else PackedStringArray()


func play(anim: StringName) -> bool:
	var ap := animation_player()
	if ap == null or not ap.has_animation(anim):
		push_warning("PropsV3Piece %s: sem animacao %s" % [name, anim])
		return false
	ap.play(anim)
	return true


## Triangulos de todas as malhas da peca (LOD 0).
func triangle_count() -> int:
	var n := 0
	for node in find_children("*", "MeshInstance3D", true, false):
		var mesh := (node as MeshInstance3D).mesh
		if mesh == null:
			continue
		for i in mesh.get_surface_count():
			var arr := mesh.surface_get_arrays(i)
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			n += idx.size() / 3 if idx.size() > 0 else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return n


## Troca cada superficie pelo material da biblioteca com o mesmo nome. Devolve quantas superficies foram trocadas.
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
			var m := material_for(src.resource_name)
			if m != null:
				mi.set_surface_override_material(i, m)
				count += 1
				if src.resource_name == "pv3_beam":
					mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF   # pilar de luz nao faz sombra
	return count


static func material_for(mat_name: String) -> Material:
	if mat_name.begins_with("wv2_"):
		return WV2Materials.get_material(mat_name)
	if _own.has(mat_name):
		return _own[mat_name]
	var m: Material = _build(mat_name)
	if m != null:
		_own[mat_name] = m
	return m


static func _build(mat_name: String) -> Material:
	if OWN.has(mat_name):
		var spec: Array = OWN[mat_name]
		var sm := ShaderMaterial.new()
		sm.shader = SURFACE
		sm.set_shader_parameter("albedo_tex", WV2Materials.tex(String(spec[0]), "albedo"))
		sm.set_shader_parameter("data_tex", WV2Materials.tex(String(spec[0]), "data"))
		sm.set_shader_parameter("tex_meters", float(spec[1]))
		var params: Dictionary = spec[2]
		for k: String in params:
			sm.set_shader_parameter(k, params[k])
		sm.resource_name = mat_name
		return sm
	match mat_name:
		"pv3_glow":
			# ouro da "acao do momento" (bible: unica cor que pulsa), com brilho proprio
			var g := StandardMaterial3D.new()
			g.albedo_color = Color("ffd23f")
			g.emission_enabled = true
			g.emission = Color("ffb000")
			g.emission_energy_multiplier = 0.9
			g.roughness = 0.3
			g.clearcoat_enabled = true
			g.clearcoat = 0.5
			g.resource_name = mat_name
			return g
		"pv3_glow_rim":
			var w := StandardMaterial3D.new()
			w.albedo_color = Color("fffaf0")
			w.emission_enabled = true
			w.emission = Color("ffffff")
			w.emission_energy_multiplier = 0.35
			w.roughness = 0.4
			w.resource_name = mat_name
			return w
		"pv3_ring":
			# anel do pulso: sem luz, transparente, cor da malha; a cena anima `transparency` por instancia
			var r := StandardMaterial3D.new()
			r.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			r.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			r.vertex_color_use_as_albedo = true
			r.cull_mode = BaseMaterial3D.CULL_DISABLED
			r.albedo_color = Color(1.0, 1.0, 1.0, 0.95)
			r.resource_name = mat_name
			return r
		"pv3_beam":
			# pilar de luz do anel de alvo (F2): aditivo, sem luz, alfa da cor de vertice (some para cima)
			var b := StandardMaterial3D.new()
			b.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			b.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			b.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			b.vertex_color_use_as_albedo = true
			b.cull_mode = BaseMaterial3D.CULL_DISABLED
			b.albedo_color = Color(1.0, 0.93, 0.62, 1.0)
			b.resource_name = mat_name
			return b
	push_warning("PropsV3Piece: material sem regra %s" % mat_name)
	return null
