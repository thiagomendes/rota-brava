class_name BoatVfx
extends Node3D
## Esteira de espuma e respingo de proa do barco; a intensidade acompanha a velocidade (SPEC secao 4: espuma junto ao casco).

const SOFT := preload("res://art/soft_particle.gdshader")

var boat: BoatActor
var wake: GPUParticles3D
var spray: GPUParticles3D


static func attach(target: BoatActor) -> BoatVfx:
	var v := BoatVfx.new()
	v.boat = target
	target.add_child(v)
	return v


func _ready() -> void:
	name = "BoatVfx"
	wake = _make_wake()
	spray = _make_spray()
	add_child(wake)
	add_child(spray)


func _soft_quad(color: Color, soft: float) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	var m := ShaderMaterial.new()
	m.shader = SOFT
	m.set_shader_parameter("color", color)
	m.set_shader_parameter("softness", soft)
	q.material = m
	return q


func _ramp(a: float, b: float) -> GradientTexture1D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, a))
	g.set_color(1, Color(1, 1, 1, b))
	var t := GradientTexture1D.new()
	t.gradient = g
	return t


func _curve(a: float, b: float) -> CurveTexture:
	var c := Curve.new()
	c.add_point(Vector2(0, a))
	c.add_point(Vector2(1, b))
	var t := CurveTexture.new()
	t.curve = c
	return t


func _make_wake() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "Wake"
	p.amount = 70
	p.lifetime = 2.6
	p.local_coords = false
	p.explosiveness = 0.0
	p.position = Vector3(0, -0.38, 2.3)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := ParticleProcessMaterial.new()
	m.direction = Vector3(0, 0, 1)
	m.spread = 24.0
	m.initial_velocity_min = 0.5
	m.initial_velocity_max = 1.3
	m.gravity = Vector3.ZERO
	m.damping_min = 0.35
	m.damping_max = 0.6
	m.scale_min = 0.9
	m.scale_max = 1.8
	m.scale_curve = _curve(0.5, 2.4)
	m.color_ramp = _ramp(0.5, 0.0)
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = Vector3(0.9, 0.0, 0.3)
	p.process_material = m
	p.draw_pass_1 = _soft_quad(Color(0.97, 1.0, 1.0, 0.55), 1.1)
	p.emitting = false
	return p


func _make_spray() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "BowSpray"
	p.amount = 36
	p.lifetime = 0.9
	p.local_coords = false
	p.position = Vector3(0, -0.2, -2.5)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := ParticleProcessMaterial.new()
	m.direction = Vector3(0, 1, -0.2)
	m.spread = 38.0
	m.initial_velocity_min = 1.0
	m.initial_velocity_max = 2.2
	m.gravity = Vector3(0, -6.0, 0)
	m.scale_min = 0.12
	m.scale_max = 0.3
	m.scale_curve = _curve(1.0, 0.4)
	m.color_ramp = _ramp(0.85, 0.0)
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = Vector3(0.7, 0.0, 0.2)
	p.process_material = m
	p.draw_pass_1 = _soft_quad(Color(1, 1, 1, 0.9), 0.9)
	p.emitting = false
	return p


func _process(_delta: float) -> void:
	if boat == null:
		return
	var s := absf(boat.speed)
	wake.emitting = s > 0.35
	wake.amount_ratio = clampf(s / BoatActor.MAX_SPEED, 0.15, 1.0)
	spray.emitting = s > 2.2
	spray.amount_ratio = clampf((s - 2.0) / 5.0, 0.1, 1.0)
