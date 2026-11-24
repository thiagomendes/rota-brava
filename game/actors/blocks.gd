class_name Blocks
extends RefCounted
## Primitivas proprias e PROVISORIAS (SPEC secao 4): blocos matematicos ate a aprovacao artistica.
## Toda peca criada aqui recebe o metadado `provisional = true`.

const PROVISIONAL := &"provisional"
const STYLIZED := preload("res://art/stylized.gdshader")

static var _materials: Dictionary = {}


static func material(color: Color, emission: float = 0.0) -> ShaderMaterial:
	var key := "%s|%s" % [color.to_html(), emission]
	if _materials.has(key):
		return _materials[key]
	var m := ShaderMaterial.new()
	m.shader = STYLIZED
	m.set_shader_parameter("albedo", color)
	m.set_shader_parameter("use_vertex_color", false)
	if emission > 0.0:
		m.set_shader_parameter("emission_color", color)
		m.set_shader_parameter("emission_energy", emission)
	_materials[key] = m
	return m


static func _mark(node: Node) -> void:
	node.set_meta(PROVISIONAL, true)


static func _mesh(parent: Node, name: String, mesh: Mesh, pos: Vector3, color: Color, emission: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	mi.mesh = mesh
	mi.material_override = material(color, emission)
	mi.position = pos
	_mark(mi)
	parent.add_child(mi)
	return mi


static func box(parent: Node, name: String, size: Vector3, pos: Vector3, color: Color, emission: float = 0.0) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = size
	return _mesh(parent, name, m, pos, color, emission)


static func cylinder(parent: Node, name: String, radius: float, height: float, pos: Vector3, color: Color, emission: float = 0.0) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = radius
	m.bottom_radius = radius
	m.height = height
	return _mesh(parent, name, m, pos, color, emission)


static func sphere(parent: Node, name: String, radius: float, pos: Vector3, color: Color, emission: float = 0.0) -> MeshInstance3D:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	return _mesh(parent, name, m, pos, color, emission)


## Bloco solido (visual + colisao) na camada 1, para chao e obstaculos pisaveis.
static func solid_box(parent: Node, name: String, size: Vector3, pos: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = name
	body.position = pos
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	shape.shape = bs
	body.add_child(shape)
	_mark(body)
	parent.add_child(body)
	box(body, name + "Mesh", size, Vector3.ZERO, color)
	return body
