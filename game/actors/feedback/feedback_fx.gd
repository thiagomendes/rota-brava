class_name FeedbackFx
extends RefCounted
## Retorno visual curto das interacoes (RB-R1): estrelinhas ao examinar, anel de luz ao fixar a linha, respingo ao
## atracar/errar, poeirinha ao pousar e pulso quando uma acao fica disponivel. Particulas proprias (CPU, disco macio
## de `art/soft_particle.gdshader`). Cada efeito se apaga sozinho. Nao bloqueia nada e nao altera estado de jogo.

const GROUP := &"rb_feedback"
const SOFT := preload("res://art/soft_particle.gdshader")

## Contagem por tipo desde o inicio da execucao (para testes e diagnostico).
static var spawned: Dictionary = {}


static func _root(parent: Node, kind: StringName, pos: Vector3, life: float) -> Node3D:
	var n := Node3D.new()
	n.name = "Fx_" + String(kind)
	n.add_to_group(GROUP)
	n.set_meta(&"fx_kind", kind)
	parent.add_child(n)
	n.global_position = pos
	spawned[kind] = int(spawned.get(kind, 0)) + 1
	n.get_tree().create_timer(life, false).timeout.connect(func() -> void:
		if is_instance_valid(n):
			n.queue_free())
	return n


static func _soft_material(color: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SOFT
	m.set_shader_parameter(&"color", color)
	return m


static func _burst(parent: Node3D, amount: int, life: float, color: Color, size: float, speed: float,
		gravity: Vector3, spread: float = 180.0) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "Particles"
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = amount
	p.lifetime = life
	p.direction = Vector3.UP
	p.spread = spread
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.gravity = gravity
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.0
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	p.scale_amount_curve = curve
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	q.material = _soft_material(color)
	p.mesh = q
	parent.add_child(p)
	p.emitting = true
	return p


## Estrelinhas douradas subindo do alvo examinado.
static func sparkle(parent: Node, pos: Vector3) -> Node3D:
	var n := _root(parent, &"sparkle", pos, 1.6)
	_burst(n, 18, 1.1, Color(1.0, 0.88, 0.35, 0.95), 0.22, 2.6, Vector3(0, -1.5, 0), 60.0)
	_burst(n, 8, 1.4, Color(1.0, 1.0, 0.9, 1.0), 0.12, 1.6, Vector3(0, -0.5, 0), 90.0)
	return n


## Anel de luz que abre e some (linha fixada, boia contornada).
static func ring(parent: Node, pos: Vector3, color: Color = Color("ffe14d")) -> Node3D:
	var n := _root(parent, &"ring", pos, 1.3)
	var mi := MeshInstance3D.new()
	mi.name = "Ring"
	var t := TorusMesh.new()
	t.inner_radius = 0.42
	t.outer_radius = 0.5
	mi.mesh = t
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = color
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(mi)
	var tw := n.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * 4.0, 1.1).from(Vector3.ONE * 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(m, "albedo_color:a", 0.0, 1.1).from(1.0)
	_burst(n, 10, 0.9, color.lightened(0.3), 0.18, 1.8, Vector3.ZERO, 90.0)
	return n


## Respingo de agua (atracar, cair na agua).
static func splash(parent: Node, pos: Vector3) -> Node3D:
	var n := _root(parent, &"splash", pos, 1.5)
	_burst(n, 26, 0.9, Color(0.92, 0.97, 1.0, 0.9), 0.3, 3.4, Vector3(0, -9.0, 0), 35.0)
	_burst(n, 10, 1.2, Color(0.75, 0.9, 1.0, 0.6), 0.5, 1.2, Vector3(0, -2.0, 0), 80.0)
	return n


## Poeirinha ao pousar de um salto.
static func dust(parent: Node, pos: Vector3) -> Node3D:
	var n := _root(parent, &"dust", pos + Vector3(0, 0.05, 0), 1.0)
	_burst(n, 10, 0.6, Color(0.95, 0.9, 0.78, 0.7), 0.25, 1.4, Vector3(0, -1.0, 0), 85.0)
	return n


## Pulso no alvo quando a acao fica disponivel: anel pequeno, rapido.
static func pulse(parent: Node, pos: Vector3) -> Node3D:
	var n := _root(parent, &"pulse", pos + Vector3(0, 0.08, 0), 0.8)
	var mi := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.46
	t.outer_radius = 0.5
	mi.mesh = t
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(1.0, 0.95, 0.6, 0.9)
	mi.material_override = m
	n.add_child(mi)
	var tw := n.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * 2.2, 0.6).from(Vector3.ONE * 0.8)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.6).from(0.9)
	return n


static func count(kind: StringName) -> int:
	return int(spawned.get(kind, 0))
