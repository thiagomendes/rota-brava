class_name Atmosphere
extends RefCounted
## Luz, ceu, nevoa e pos-processamento do "diorama de brinquedo luminoso" (RB-04, guia de estilo).
## Chave quente de fim de manha com sombra fria; preenchimento do ceu; nevoa leve; tonemap filmic; bloom discreto.

const SUN_COLOR := Color("ffe6be")
const SKY_TOP := Color("5fa8dc")
const SKY_HORIZON := Color("f2e2c0")
const GROUND_BOTTOM := Color("6ba3b5")
const AMBIENT := Color("9cc8e8")


static func build(parent: Node) -> Dictionary:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = SKY_TOP
	sky_mat.sky_horizon_color = SKY_HORIZON
	sky_mat.ground_horizon_color = SKY_HORIZON
	sky_mat.ground_bottom_color = GROUND_BOTTOM
	sky_mat.sun_angle_max = 28.0
	sky_mat.sun_curve = 0.12
	var sky := Sky.new()
	sky.sky_material = sky_mat

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = AMBIENT
	env.ambient_light_energy = 0.55
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.06
	env.glow_hdr_threshold = 1.2
	env.fog_enabled = true
	env.fog_light_color = Color("cfe6f0")
	env.fog_density = 0.0035
	env.fog_sky_affect = 0.45
	env.fog_aerial_perspective = 0.35
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.06
	env.adjustment_saturation = 1.14

	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	parent.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-48.0, -38.0, 0.0)
	sun.light_color = SUN_COLOR
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	sun.shadow_opacity = 0.82
	sun.shadow_blur = 1.6
	sun.shadow_bias = 0.04
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 70.0
	parent.add_child(sun)
	return {"environment": env, "sun": sun, "world_environment": we}


## Vinheta de tela cheia, abaixo do HUD (camada 1).
static func add_vignette(parent: Node) -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.name = "Vignette"
	layer.layer = 1
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://art/vignette.gdshader")
	rect.material = mat
	layer.add_child(rect)
	parent.add_child(layer)
	return layer
