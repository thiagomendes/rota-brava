extends Node3D
## VITRINE (lookdev) de luz, material e camera para aprovacao de Thiago (RB-R1 D11/D12). NAO e jogo e nao esta ligada
## ao Ep01. PROVISORIO. Monta o trecho real do porto (harbor_slice), o barco e os herois atuais (Rastro, Pico, Leme em idle).
##   --lookdev=before  visual atual do jogo (Atmosphere + Stylize + contorno); rodar com --rendering-method mobile
##   --lookdev=after   luz/ambiente novos (abaixo) + materiais novos (LookdevMaterials), renderizador Forward+
##   --lookdev-cam=low | close | high   camera baixa da referencia (padrao), close do heroi, camera alta antiga
## Imprime "LOOKDEV PERF ..." com chamadas de desenho e primitivas no quadro 15.
## Uso (nuvem): xvfb-run -a -s "-screen 0 1600x900x24" bash tools/godot.sh --path game --rendering-driver vulkan \
##   res://lookdev/lookdev_dock.tscn --write-movie /ABS/f.png --fixed-fps 10 --quit-after 20 -- --lookdev=after

const SLICE := "res://episodes/ep01/world/harbor_slice.tscn"
const BOAT := "res://actors/environment/boat_v2.tscn"
const SKY_SHADER := "res://art/sky.gdshader"
## Heroi principal no cais, de frente para a camera em 3/4.
const HERO_POS := Vector3(-2.0, 0.0, 1.0)
const HEROES := [
	["res://actors/characters/rastro_model.tscn", Vector3(0.0, 0.0, 0.0), 160.0, 0.0],
	["res://actors/characters/pico_model.tscn", Vector3(-1.55, 0.0, -1.35), 195.0, 0.37],
	["res://actors/characters/leme_model.tscn", Vector3(1.45, 0.0, -1.7), 140.0, 0.71],
]
## Camera baixa da referencia: ~2 m de altura, 12 graus para baixo, heroi a ~4 m (25 a 30% da altura da tela, FOV 50).
const LOW_OFFSET := Vector3(1.05, 1.95, 3.85)
const LOW_PITCH := 12.0
const LOW_FOV := 50.0
const CLOSE_OFFSET := Vector3(0.55, 1.25, 1.9)
const CLOSE_PITCH := 6.0
## Camera alta antiga do cais (CameraRig): ~35 graus, FOV 55.
const HIGH_OFFSET := Vector3(0.0, 4.6, 6.2)

var mode := "after"
var cam_name := "low"
var cam: Camera3D
var heroes: Array[CharacterVisual] = []
var frame := 0


func _ready() -> void:
	mode = _arg("--lookdev", "after")
	cam_name = _arg("--lookdev-cam", "low")
	var after := mode != "before"
	if after:
		_build_light()
	else:
		Atmosphere.build(self)
		Atmosphere.add_vignette(self)
	add_child(WaterSurface.new())
	var slice := (load(SLICE) as PackedScene).instantiate()
	add_child(slice)
	var boat := (load(BOAT) as PackedScene).instantiate() as Node3D
	boat.name = "Boat"
	add_child(boat)
	boat.position = Ep01Layout.BOAT_DOCKED_POS
	boat.rotation.y = Ep01Layout.BOAT_DOCKED_HEADING
	if after:
		LookdevMaterials.apply(slice, false)
		LookdevMaterials.apply(boat, false)
		_local_lights(slice)
	else:
		Stylize.apply(slice)
		Stylize.trim_small_shadows(slice)
		Stylize.apply(boat)
	_place_camera()
	for h: Array in HEROES:
		var inst := (load(String(h[0])) as PackedScene).instantiate() as Node3D
		add_child(inst)
		inst.position = HERO_POS + (h[1] as Vector3)
		inst.rotation_degrees.y = float(h[2])
		var vis := inst.get_node("Model") as CharacterVisual
		if after:
			LookdevMaterials.apply(vis, true)
			_contact_shadow(inst)
		else:
			Stylize.apply(vis)
			Stylize.add_outline(vis, 0.008)
		vis.play(&"idle")
		# Fase do idle diferente por heroi (nao ficam sincronizados).
		var player := vis.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if player != null:
			player.seek(float(h[3]) * player.current_animation_length, true)
		heroes.append(vis)
	if not LookdevMaterials.unmatched.is_empty():
		print("LOOKDEV materiais sem regra (usaram o padrao): ", LookdevMaterials.unmatched)


func _arg(flag: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if a.begins_with(flag + "="):
			return a.trim_prefix(flag + "=")
	return fallback


# ---------- luz e ambiente novos (D11) ----------

func _build_light() -> void:
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = load(SKY_SHADER) as Shader
	sky_mat.set_shader_parameter("horizon_color", Color("f6e7cf"))
	sky_mat.set_shader_parameter("cloud_coverage", 0.36)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	# Preenchimento frio vindo do proprio ceu (ambiente + reflexos), nao de uma cor fixa.
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 1.0
	env.ambient_light_energy = 0.85
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 0.95
	# Oclusao de cantos e contato.
	env.ssao_enabled = true
	env.ssao_radius = 0.9
	env.ssao_intensity = 1.9
	env.ssao_power = 1.6
	env.ssao_detail = 0.6
	env.ssao_horizon = 0.06
	env.ssao_light_affect = 0.18
	# Luz rebatida (madeira quente do cais nas pernas, verde do gramado).
	env.ssil_enabled = true
	env.ssil_radius = 3.0
	env.ssil_intensity = 0.8
	# Nevoa de profundidade com perspectiva aerea (o fundo azula e clareia em camadas).
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = Color("c9dbe8")
	env.fog_light_energy = 1.0
	env.fog_sun_scatter = 0.12
	env.fog_density = 0.0038
	env.fog_aerial_perspective = 0.45
	env.fog_sky_affect = 0.12
	# Brilho discreto (sol na agua, vidro, lampadas).
	env.glow_enabled = true
	env.glow_intensity = 0.45
	env.glow_bloom = 0.02
	env.glow_hdr_threshold = 1.15
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.25
	env.adjustment_contrast = 1.10
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	add_child(we)

	# Sol quente de fim de manha, pela frente-direita da camera e alto (~40 graus): modela o rosto em 3/4.
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = Color("ffe1b4")
	sun.light_energy = 2.3
	sun.light_angular_distance = 1.4
	sun.shadow_enabled = true
	sun.shadow_bias = 0.03
	sun.shadow_normal_bias = 1.2
	sun.shadow_blur = 1.2
	sun.shadow_opacity = 1.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 60.0
	sun.directional_shadow_blend_splits = true
	add_child(sun)
	sun.basis = Basis.looking_at(-Vector3(0.62, 0.66, 0.42).normalized(), Vector3.UP)
	# Contraluz quente-claro por tras dos herois (borda de luz no cabelo e nos ombros), sem sombra.
	var back := DirectionalLight3D.new()
	back.name = "BackLight"
	back.light_color = Color("fff0d8")
	back.light_energy = 0.55
	back.light_specular = 0.6
	add_child(back)
	back.basis = Basis.looking_at(-Vector3(-0.35, 0.45, -1.0).normalized(), Vector3.UP)
	# Preenchimento frio bem fraco do lado oposto ao sol (so difuso).
	var fill := DirectionalLight3D.new()
	fill.name = "SkyFill"
	fill.light_color = Color("b9d3ff")
	fill.light_energy = 0.22
	fill.light_specular = 0.0
	add_child(fill)
	fill.basis = Basis.looking_at(-Vector3(-0.8, 0.35, 0.3).normalized(), Vector3.UP)
	# Rebatido quente do cais por baixo dos herois (luz local, sem sombra).
	var bounce := OmniLight3D.new()
	bounce.name = "DeckBounce"
	bounce.light_color = Color("ffc58c")
	bounce.light_energy = 0.45
	bounce.light_specular = 0.0
	bounce.omni_range = 3.2
	bounce.position = HERO_POS + Vector3(0.4, 0.25, 1.2)
	add_child(bounce)
	get_viewport().msaa_3d = Viewport.MSAA_2X


## Luzes quentes locais: lampioes da rua e baixo dos toldos do mercado (sem sombra: custo baixo no Forward+ agrupado).
func _local_lights(slice: Node) -> void:
	for n in slice.find_children("street_lamp*", "Node3D", true, false):
		var l := OmniLight3D.new()
		l.light_color = Color("ffb35c")
		l.light_energy = 1.6
		l.omni_range = 4.5
		l.omni_attenuation = 1.4
		(n as Node3D).add_child(l)
		l.position = Vector3(0, 2.7, 0)
	for n in slice.find_children("market_stall*", "Node3D", true, false):
		var l := OmniLight3D.new()
		l.light_color = Color("ffc47a")
		l.light_energy = 0.9
		l.omni_range = 3.5
		l.light_specular = 0.2
		(n as Node3D).add_child(l)
		l.position = Vector3(0, 1.6, 0)


## Sombra de contato macia sob o personagem (decal radial; complementa a sombra do sol e o SSAO).
func _contact_shadow(parent: Node3D) -> void:
	var g := Gradient.new()
	g.set_color(0, Color(0.12, 0.10, 0.14, 0.75))
	g.set_color(1, Color(0.12, 0.10, 0.14, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 128
	tex.height = 128
	var d := Decal.new()
	d.name = "ContactShadow"
	d.texture_albedo = tex
	d.size = Vector3(0.95, 0.5, 0.95)
	d.modulate = Color(1, 1, 1, 0.8)
	d.upper_fade = 0.2
	d.lower_fade = 0.6
	d.cull_mask = 1
	parent.add_child(d)
	d.position = Vector3(0, 0.15, 0)


# ---------- camera ----------

func _place_camera() -> void:
	cam = Camera3D.new()
	cam.name = "LookdevCamera"
	cam.near = 0.05
	cam.far = 900.0
	add_child(cam)
	cam.current = true
	match cam_name:
		"high":
			cam.fov = 55.0
			cam.global_position = HERO_POS + HIGH_OFFSET
			cam.look_at(HERO_POS + Vector3(0, 1.0, 0), Vector3.UP)
		"close":
			_aim(CLOSE_OFFSET, CLOSE_PITCH, 40.0, 0.85)
		_:
			_aim(LOW_OFFSET, LOW_PITCH, LOW_FOV, 0.0)


## Camera em `HERO_POS + offset`, olhando na direcao horizontal do heroi com `pitch` graus para baixo.
func _aim(offset: Vector3, pitch: float, fov: float, aim_y: float) -> void:
	cam.fov = fov
	cam.global_position = HERO_POS + offset
	var flat := HERO_POS + Vector3(0, aim_y, 0) - cam.global_position
	flat.y = 0.0
	flat = flat.normalized()
	var dir := Vector3(flat.x * cos(deg_to_rad(pitch)), -sin(deg_to_rad(pitch)), flat.z * cos(deg_to_rad(pitch)))
	cam.look_at(cam.global_position + dir, Vector3.UP)


func _process(_dt: float) -> void:
	frame += 1
	if frame == 2 and not heroes.is_empty():
		heroes[0].look_at_point(cam.global_position)
	if frame == 15:
		var hero_px := _hero_screen_fraction()
		print("LOOKDEV PERF mode=%s cam=%s draw_calls=%d primitives=%d objects=%d hero_height_frac=%.3f" % [mode, cam_name,
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME), hero_px])


## Fracao da altura da tela ocupada pelo heroi principal (pes a topo da cabeca, 1,14 m).
func _hero_screen_fraction() -> float:
	var feet := cam.unproject_position(HERO_POS)
	var head := cam.unproject_position(HERO_POS + Vector3(0, 1.14, 0))
	return absf(feet.y - head.y) / get_viewport().get_visible_rect().size.y
