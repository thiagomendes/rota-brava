class_name KeyArtStage
extends Node3D
## Arte-chave 3D da tela inicial e da capa (RB-R1 G8). PROPOSTA: nada aqui esta ligado ao menu ainda; Thiago escolhe.
## Uma cena por proposta (keyart_a/b/c.tscn) monta a vila v3 jogavel, o barco amarelo e o trio com clipes que ja
## existem (pose segurada num quadro escolhido), com luz, ceu, agua e camera proprios da proposta.
## Enquadramentos (`framing`): &"wide" (16:9 capa), &"portrait" (3:4 loja), &"capsule" (~2,14:1 loja),
## &"menu" (fundo do menu: o grupo vai para o terco esquerdo, o lado direito fica calmo para os botoes).
## Movimento leve (`animate`): agua e nuvens, barco balancando, camera respirando, lanternas e feixe do farol.
## Com Options.reduced_motion() a camera e o barco ficam parados.

const VILLAGE := "res://worlds/village_v3/village_world.tscn"
const BOAT := "res://worlds/village_v3/boat_wv2.tscn"
const HEROES := {
	&"rastro": "res://actors/characters/rastro_model.tscn",
	&"pico": "res://actors/characters/pico_model.tscn",
	&"leme": "res://actors/characters/leme_model.tscn",
}

@export var proposal: StringName = &"a"
@export var framing: StringName = &"wide"
@export var animate := true

var world: VillageWorld
var boat: Node3D
var cam: Camera3D
var heroes: Dictionary = {}       # id -> CharacterVisual
var holders: Dictionary = {}      # id -> Node3D (onde o visual esta montado)
var preset: Dictionary = {}
var extra_lights: Array[Light3D] = []
var ready_to_shoot := false
var _t := 0.0
var _boat_base := Transform3D.IDENTITY
var _cam_base := {}


func _ready() -> void:
	# roda depois dos visuais (prioridade 0): o rosto e ajustado depois de o clipe ser avaliado no quadro
	process_priority = 10
	preset = KeyArtPresets.get_preset(proposal)
	world = (load(VILLAGE) as PackedScene).instantiate() as VillageWorld
	add_child(world)
	cam = Camera3D.new()
	cam.name = "KeyCamera"
	cam.far = 900.0
	cam.near = 0.05
	add_child(cam)
	cam.current = true
	_apply_light()
	boat = (load(BOAT) as PackedScene).instantiate() as Node3D
	boat.name = "HeroBoat"
	add_child(boat)
	var bp: Array = preset["boat"]
	boat.global_position = bp[0]
	boat.rotation = Vector3(deg_to_rad(float(bp[2])), deg_to_rad(float(bp[1])), deg_to_rad(float(bp[3])))
	_boat_base = boat.transform
	# trio montado na hora (quem usa a cena ja encontra `heroes` cheio); a altura do chao vem depois
	_mount_heroes()
	# chao vem da colisao da vila: espera a fisica registrar as formas
	await get_tree().physics_frame
	await get_tree().physics_frame
	_ground_heroes()
	# o ceu so pega os parametros novos depois que a vila desenhou o primeiro quadro: aplica de novo e troca o
	# material do ceu (forca o mapa de radiancia/ambiente a refazer com as cores da proposta)
	await get_tree().process_frame
	_apply_sky()
	set_framing(framing)
	get_viewport().size_changed.connect(_update_camera)
	ready_to_shoot = true


# ---------------------------------------------------------------- luz e ceu

func _apply_light() -> void:
	var L: Dictionary = preset["light"]
	if bool(L.get("festival", false)):
		world.set_festival(true)
	elif bool(L.get("night", false)):
		world.set_night(true)
	var env := world.env
	_apply_sky()
	var sun := world.sun
	sun.light_color = Color(L["sun_color"])
	sun.light_energy = float(L["sun_energy"])
	var el := deg_to_rad(float(L["sun_elev"]))
	var az := deg_to_rad(float(L["sun_az"]))   # 0 = vem de +Z, 90 = vem de +X
	var to_sun := Vector3(sin(az) * cos(el), sin(el), cos(az) * cos(el))
	sun.basis = Basis.looking_at(-to_sun, Vector3.UP)
	world.fill.light_color = Color(L.get("fill_color", "b9d3ff"))
	world.fill.light_energy = float(L.get("fill_energy", 0.25))
	env.ambient_light_energy = float(L.get("ambient", env.ambient_light_energy))
	env.fog_light_color = Color(L.get("fog_color", env.fog_light_color.to_html()))
	env.fog_density = float(L.get("fog_density", env.fog_density))
	env.fog_sun_scatter = float(L.get("fog_sun_scatter", env.fog_sun_scatter))
	env.tonemap_exposure = float(L.get("exposure", env.tonemap_exposure))
	env.glow_intensity = float(L.get("glow", env.glow_intensity))
	env.glow_bloom = float(L.get("glow_bloom", env.glow_bloom))
	env.adjustment_saturation = float(L.get("saturation", env.adjustment_saturation))
	env.adjustment_contrast = float(L.get("contrast", env.adjustment_contrast))
	var water := world.get_node_or_null("Water") as MeshInstance3D
	if water != null and water.material_override is ShaderMaterial:
		var wm := water.material_override as ShaderMaterial
		for k in ["shallow_color", "deep_color", "sky_color"]:
			if L.has("water_" + k):
				wm.set_shader_parameter(k, Color(L["water_" + k]))
	# luzes de retrato (chave/recorte) so para o trio: camada propria nao existe nos modelos, entao sao luzes
	# locais de alcance curto perto do grupo (nao mudam a vila ao longe).
	for spec: Dictionary in preset.get("lights", []):
		var l: Light3D
		if String(spec.get("type", "omni")) == "spot":
			var s := SpotLight3D.new()
			s.spot_range = float(spec.get("range", 8.0))
			s.spot_angle = float(spec.get("angle", 30.0))
			l = s
		else:
			var o := OmniLight3D.new()
			o.omni_range = float(spec.get("range", 4.0))
			o.omni_attenuation = 1.0
			l = o
		l.light_color = Color(spec["color"])
		l.light_energy = float(spec["energy"])
		l.light_specular = float(spec.get("specular", 0.4))
		l.shadow_enabled = bool(spec.get("shadow", false))
		add_child(l)
		l.global_position = spec["pos"]
		if spec.has("look"):
			l.look_at(spec["look"], Vector3.UP)
		l.set_meta("base_energy", l.light_energy)
		l.set_meta("flicker", bool(spec.get("flicker", false)))
		extra_lights.append(l)


func _apply_sky() -> void:
	var L: Dictionary = preset["light"]
	var sky := world.sky_mat
	for k in ["top_color", "horizon_color", "ground_color", "cloud_light", "cloud_shadow"]:
		if L.has(k):
			sky.set_shader_parameter(k, Color(L[k]))
	for k in ["cloud_coverage", "sun_size", "sun_glow", "cloud_softness"]:
		if L.has(k):
			sky.set_shader_parameter(k, float(L[k]))
	var mat := sky.duplicate() as ShaderMaterial
	world.sky_mat = mat
	world.env.sky.sky_material = mat


# ---------------------------------------------------------------- herois

func _mount_heroes() -> void:
	for id: StringName in preset["heroes"]:
		var h: Dictionary = preset["heroes"][id]
		var inst := (load(HEROES[id]) as PackedScene).instantiate()
		var visual := inst.get_node_or_null("Model") as CharacterVisual
		inst.remove_child(visual)
		visual.owner = null
		inst.free()
		var holder := Node3D.new()
		holder.name = "Hero_%s" % id
		var on_boat := String(h.get("on", "world")) == "boat"
		if on_boat:
			boat.add_child(holder)
			holder.position = h["pos"]
		else:
			add_child(holder)
			var p: Vector3 = h["pos"]
			holder.global_position = Vector3(p.x, p.y + float(h.get("lift", 0.0)), p.z)
		# frente dos modelos em -Z; yaw em graus no espaco do pai (barco ou mundo)
		holder.rotation.y = deg_to_rad(float(h.get("yaw", 0.0)))
		holder.add_child(visual)
		CharacterVisual.stylize_if_toon(visual, 0.006)
		# pose segurada: toca o clipe com velocidade 0 no quadro escolhido (seek_clip pausa e o AnimationPlayer
		# volta ao repouso no quadro seguinte; tocando parado o quadro fica)
		var ap := visual.animation_player()
		ap.play(StringName(h.get("anim", "idle")), 0.0, 0.0)
		ap.seek(float(h.get("t", 0.0)), true)
		_open_eyes(visual)
		visual.set_expression(StringName(h.get("expr", "atenta")), float(h.get("expr_w", 0.5)))
		heroes[id] = visual
		holders[id] = holder
	# olhar: depois de todos montados (alguns olham para a camera, que so existe enquadrada depois)


## Poe no chao (colisao da vila) os herois "world" sem altura fixa (`abs_y`).
func _ground_heroes() -> void:
	for id: StringName in holders:
		var h: Dictionary = preset["heroes"][id]
		if String(h.get("on", "world")) == "boat" or bool(h.get("abs_y", false)):
			continue
		var n := holders[id] as Node3D
		var p := n.global_position
		n.global_position = Vector3(p.x, _ground(p.x, p.z) + float(h.get("lift", 0.0)), p.z)


## Alguns clipes fecham os olhos (sorriso) no quadro segurado; zera piscar/alegre do rosto para olhar a crianca.
## (Rastro e Leme ainda fecham os olhos fora das formas do rosto em alguns quadros: correcao do G1, outro agente.)
func _open_eyes(v: CharacterVisual) -> void:
	var f := v.face_mesh()
	if f == null:
		return
	for s in [&"alegre", &"blink"]:
		var i := f.find_blend_shape_by_name(s)
		if i >= 0:
			f.set_blend_shape_value(i, 0.0)


func _aim_eyes() -> void:
	for id: StringName in heroes:
		var h: Dictionary = preset["heroes"][id]
		var v := heroes[id] as CharacterVisual
		var look: Variant = h.get("look", "camera")
		if look is Vector3:
			v.look_at_point(look)
		elif String(look) == "camera":
			v.look_at_point(cam.global_position)


## Altura do chao (colisao da vila) em x,z; 0 se nada for atingido.
func _ground(x: float, z: float) -> float:
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, 60.0, z), Vector3(x, -5.0, z), 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return float((hit.position as Vector3).y) if not hit.is_empty() else 0.0


# ---------------------------------------------------------------- camera

func set_framing(f: StringName) -> void:
	framing = f
	var cams: Dictionary = preset["cameras"]
	var key := f if cams.has(f) else &"wide"
	if f == &"menu" and not cams.has(&"menu"):
		key = &"wide"
	_cam_base = (cams[key] as Dictionary).duplicate()
	if _cam_base.has("ground_cam"):
		# camera rente ao chao: altura = chao + ground_cam
		var p: Vector3 = _cam_base["pos"]
		_cam_base["pos"] = Vector3(p.x, _ground(p.x, p.z) + float(_cam_base["ground_cam"]), p.z)
	_update_camera()
	_aim_eyes()


func _update_camera() -> void:
	if _cam_base.is_empty():
		return
	var c := _cam_base
	cam.fov = float(c.get("fov", 40.0))
	cam.keep_aspect = Camera3D.KEEP_WIDTH if bool(c.get("keep_width", false)) else Camera3D.KEEP_HEIGHT
	var pos: Vector3 = c["pos"]
	var look: Vector3 = c["look"]
	if animate and not Options.reduced_motion():
		# respiracao da camera: orbita minima (+-0,35 grau) e sobe/desce 1,5 cm em ciclos lentos
		var off := pos - look
		off = off.rotated(Vector3.UP, sin(_t * 0.21) * 0.006)
		pos = look + off + Vector3(0, sin(_t * 0.33) * 0.015, 0)
	cam.global_position = pos
	cam.look_at(look, Vector3.UP)
	cam.rotate_object_local(Vector3.FORWARD, deg_to_rad(float(c.get("roll", 0.0))))
	cam.h_offset = 0.0
	# `subject_x`: fracao da largura onde o centro do trio deve ficar (menu: terco esquerdo, longe dos botoes).
	# Desloca a camera de lado (h_offset) na profundidade do trio, entao vale em 16:9, 20:9 e 4:3.
	var want := float(c.get("subject_x", 0.30 if framing == &"menu" else -1.0))
	if want >= 0.0 and not heroes.is_empty():
		var center := Vector3.ZERO
		for id: StringName in holders:
			center += (holders[id] as Node3D).global_position + Vector3(0, 0.6, 0)
		center /= float(holders.size())
		var local := cam.global_transform.affine_inverse() * center
		var depth := maxf(-local.z, 0.5)
		var vp := get_viewport().get_visible_rect().size
		var aspect := vp.x / maxf(vp.y, 1.0)
		var half_w := depth * tan(deg_to_rad(cam.fov) * 0.5) * aspect
		cam.h_offset = local.x - (want - 0.5) * 2.0 * half_w
		# telas estreitas (4:3): ninguem do trio encosta na borda esquerda (margem de 5% da largura)
		var worst := 0.0
		for id: StringName in holders:
			var hl := cam.global_transform.affine_inverse() * ((holders[id] as Node3D).global_position + Vector3(0, 0.6, 0))
			var hw := maxf(-hl.z, 0.5) * tan(deg_to_rad(cam.fov) * 0.5) * aspect
			var left := 0.5 + (hl.x - 0.4 - cam.h_offset) / (2.0 * hw)
			worst = minf(worst, (left - 0.05) * 2.0 * hw)
		cam.h_offset += worst


# ---------------------------------------------------------------- movimento leve

func _process(delta: float) -> void:
	if not ready_to_shoot:
		return
	var calm := Options.reduced_motion()
	if animate:
		_t += delta
	for id: StringName in heroes:
		var v := heroes[id] as CharacterVisual
		if animate and not calm:
			# respiracao da pose: o quadro segurado oscila +-0,04 s (vida sem perder o gesto)
			var h: Dictionary = preset["heroes"][id]
			var phase := float(String(id).length())
			v.animation_player().seek(maxf(float(h.get("t", 0.0)) + sin(_t * 1.4 + phase) * 0.04, 0.0), true)
		_open_eyes(v)
	if not animate:
		return
	if not calm and boat != null:
		var b := _boat_base
		var bob := Basis(Vector3.RIGHT, sin(_t * 0.9) * 0.012) * Basis(Vector3.FORWARD, sin(_t * 0.7 + 1.0) * 0.02)
		boat.transform = Transform3D(b.basis * bob, b.origin + Vector3(0, sin(_t * 1.1) * 0.05, 0))
		_update_camera()
	if world.lantern != null and world.festival:
		world.lantern.rotation.y = fmod(_t * 0.6, TAU)
	for l in extra_lights:
		if bool(l.get_meta("flicker")):
			l.light_energy = float(l.get_meta("base_energy")) * (1.0 + 0.06 * sin(_t * 7.3 + l.position.x) * sin(_t * 3.1))
