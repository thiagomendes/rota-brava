extends Node3D
## Previa dos ciclos de andar/correr dos herois v2 NA ESCALA DO JOGO (RB-R1, ciclos v2). Nao e jogo nem teste.
## Os tres herois andam em linha reta na velocidade do jogo (andar 1,4 m/s, correr 3,2 m/s) com a escala de animacao que o
## jogo usa (CharacterVisual.walk_speed_scale / run_speed_scale), sobre um chao listrado a cada 0,5 m (patinada aparece).
## Argumentos: --gait=walk|run, --view=side|tq (lado ou tres-quartos com a camera baixa do jogo, LOW_OFFSET do camera_rig).
## xvfb-run -a -s "-screen 0 1600x900x24" bash tools/godot.sh --path game --rendering-driver vulkan \
##     res://lookdev/gait_preview.tscn --gait=run --view=side --write-movie /abs/f.png --fixed-fps 30 --quit-after 90

const SPEEDS := {"walk": 1.4, "run": 3.2}
const IDS := ["rastro", "pico", "leme"]
const NAMES := {"rastro": "Rastro", "pico": "Pico", "leme": "Leme"}
## camera baixa do jogo (game/episodes/ep01/camera_rig.gd: LOW_OFFSET, LOW_LOOK_Y, LOW_FOV)
const GAME_OFFSET := Vector3(0, 1.95, 4.1)
const GAME_LOOK_Y := 1.08
const GAME_FOV := 50.0

var _gait: String = "walk"
var _view: String = "side"
var _roots: Array[Node3D] = []
var _cam: Camera3D
var _speed: float = 1.4
var _x: float = 0.0


func _arg(prefix: String, default: String) -> String:
	for a in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if a.begins_with(prefix):
			return a.trim_prefix(prefix)
	return default


func _ready() -> void:
	_gait = _arg("--gait=", "walk")
	_view = _arg("--view=", "side")
	_speed = float(SPEEDS.get(_gait, 1.4))
	_build_world()
	if _view == "board":
		_build_board(_arg("--hero=", "rastro"))
		return
	for i in IDS.size():
		var id: String = IDS[i]
		var root := (load("res://actors/characters/%s_model.tscn" % id) as PackedScene).instantiate() as Node3D
		add_child(root)
		# lado: os tres na mesma linha, espacados em x; tres-quartos: em diagonal para nao se cobrirem
		root.position = Vector3(-1.6 * i, 0.0, 0.0) if _view == "side" else _perp() * (1.25 * (i - 1))
		root.rotation.y = -PI / 2.0            # frente do modelo (-Z) vira +X
		var vis := root.find_child("Model", false, false) as CharacterVisual
		var k := vis.walk_speed_scale(_speed) if _gait == "walk" else vis.run_speed_scale(_speed)
		vis.play(StringName(_gait), k, 0.0)
		var steps := 2.0 * k / vis.animation_length(StringName(_gait))
		var lab := Label3D.new()
		lab.text = "%s\nx%.2f · %.1f passos/s" % [NAMES[id], k, steps]
		lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lab.font_size = 28
		lab.pixel_size = 0.004
		lab.outline_size = 10
		lab.position = Vector3(0, 1.38, 0)
		root.add_child(lab)
		_roots.append(root)
	var hud := Label.new()
	hud.text = "%s %.1f m/s · %s · %s" % ["andar" if _gait == "walk" else "correr", _speed, "lado" if _view == "side" else "tres-quartos (camera do jogo)", _arg("--tag=", "")]
	hud.position = Vector2(24, 16)
	hud.add_theme_font_size_override("font_size", 30)
	hud.add_theme_color_override("font_color", Color("1d2a3a"))
	add_child(hud)
	_cam = Camera3D.new()
	add_child(_cam)
	_cam.current = true
	_place_camera()


## Quadros-chave de um passo (meio ciclo) de um heroi: 5 poses igualmente espacadas no tempo do clipe, lado a lado
## (afastadas 0,8 m entre si so para leitura; nao e a posicao no jogo).
func _build_board(id: String) -> void:
	const N := 5
	var k := 1.0
	var len := 1.0
	for i in N:
		var root := (load("res://actors/characters/%s_model.tscn" % id) as PackedScene).instantiate() as Node3D
		add_child(root)
		root.rotation.y = -PI / 2.0
		var vis := root.find_child("Model", false, false) as CharacterVisual
		k = vis.walk_speed_scale(_speed) if _gait == "walk" else vis.run_speed_scale(_speed)
		len = vis.animation_length(StringName(_gait))
		var tc := len * 0.5 * float(i) / float(N - 1)
		vis.seek_clip(StringName(_gait), tc)
		root.position = Vector3(0.8 * i, 0.0, 0.0)
		_roots.append(root)
	var step := len * 0.5 / k * _speed
	var hud := Label.new()
	hud.text = "%s · %s %.1f m/s · x%.2f · %.1f passos/s · passo %.2f m · %s" % [NAMES[id], "andar" if _gait == "walk" else "correr", _speed, k, 2.0 * k / len, step, _arg("--tag=", "")]
	hud.position = Vector2(24, 16)
	hud.add_theme_font_size_override("font_size", 30)
	hud.add_theme_color_override("font_color", Color("1d2a3a"))
	add_child(hud)
	_cam = Camera3D.new()
	add_child(_cam)
	_cam.current = true
	_cam.fov = 20.0
	var c := Vector3(1.6, 0.0, 0.0)
	_cam.position = c + Vector3(0.0, 0.75, 8.0)
	_cam.look_at(c + Vector3(0.0, 0.58, 0.0), Vector3.UP)
	set_physics_process(false)


func _physics_process(delta: float) -> void:
	_x += _speed * delta
	for r in _roots:
		r.position.x += _speed * delta
	_place_camera()


func _place_camera() -> void:
	var c := Vector3(_x - (1.6 if _view == "side" else 0.0), 0.0, 0.0)
	if _view == "side":
		_cam.fov = 22.0
		_cam.position = c + Vector3(0.0, 0.8, 8.5)
		_cam.look_at(c + Vector3(0.0, 0.62, 0.0), Vector3.UP)
	else:
		# camera baixa do jogo atras do heroi, girada 55 graus para o lado: tres-quartos de costas/lado
		_cam.fov = GAME_FOV
		_cam.position = c + _tq_offset()
		_cam.look_at(c + Vector3(0.0, GAME_LOOK_Y * 0.7, 0.0), Vector3.UP)


func _tq_offset() -> Vector3:
	return Basis(Vector3.UP, deg_to_rad(-90.0 + 55.0)) * GAME_OFFSET * 1.15


## direcao horizontal perpendicular ao olhar da camera de tres-quartos (os herois ficam lado a lado na tela)
func _perp() -> Vector3:
	var o := _tq_offset()
	return Vector3(o.z, 0.0, -o.x).normalized()


func _build_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("9cc8e8")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("b8d4ea")
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color("ffe9c4")
	sun.light_energy = 1.2
	sun.rotation_degrees = Vector3(-48.0, 30.0, 0.0)
	sun.shadow_enabled = true
	add_child(sun)
	# chao listrado: faixa escura a cada 0,5 m em x (referencia para ver se o pe patina)
	var img := Image.create(64, 8, false, Image.FORMAT_RGB8)
	img.fill(Color("d8b88e"))
	for y in 8:
		for x in 4:
			img.set_pixel(x, y, Color("8f6e4a"))
	var tex := ImageTexture.create_from_image(img)
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(200.0, 60.0)
	floor_mi.mesh = pm
	floor_mi.position = Vector3(80.0, 0.0, 0.0)
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.uv1_scale = Vector3(400.0, 1.0, 1.0)   # 200 m / 400 = 0,5 m por faixa
	m.roughness = 0.9
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	floor_mi.material_override = m
	add_child(floor_mi)
