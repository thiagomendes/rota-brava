extends SceneTree
## Capturas da arte das cenas (RB-R1, art3d): filhote andando/correndo em quadros-chave, gestos de apontar do trio,
## Dona Amora (frente, 3/4, costas, clipes e na barraca na camera baixa) e os elementos de mundo citados nas falas
## (poste da amarra vazia, arbusto da lente, pedras perto do bote, lanternas de papel da praca), no mundo jogavel
## village_world.tscn com a luz do jogo e a camera baixa do jogo (offset 0/1,95/4,1, olha +1,08 m, FOV 50).
## Uso (Linux, Vulkan por software):
##   xvfb-run -a -s "-screen 0 1920x1080x24" bash tools/godot.sh --path game --rendering-driver vulkan \
##     --script res://../tools/capture_arte_cenas.gd -- --out=/abs/dir [--part=world|pup|point|amora]
## Nao e teste: so produz imagens para olhar (montagem das pranchas com ImageMagick, ver PROVENANCE).

const LOW_OFFSET := Vector3(0, 1.95, 4.1)
const LOW_LOOK_Y := 1.08
const LOW_FOV := 50.0

var out_dir := ""
var part := ""
var world: VillageWorld
var cam: Camera3D


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.trim_prefix("--out=")
		if a.begins_with("--part="):
			part = a.trim_prefix("--part=")
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()


func _wait(s: float) -> void:
	await create_timer(s).timeout


func _size(s: Vector2i) -> void:
	DisplayServer.window_set_size(s)
	root.size = s
	await _wait(0.3)


func _shot(n: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(out_dir.path_join(n + ".png"))
	print("[RB] shot ", n, " ", img.get_size())


func _mk(n: StringName) -> Vector3:
	var m := world.marker(n)
	if m == null:
		push_error("marcador ausente: " + String(n))
		return Vector3.ZERO
	return m.global_position


## Camera baixa do jogo atras do alvo, girada `yaw` (rad) em Y; `look` = ponto olhado (padrao: alvo + 1,08 m).
func _low(target: Vector3, yaw: float, look: Variant = null, scale_off: float = 1.0) -> void:
	cam.fov = LOW_FOV
	cam.global_position = target + LOW_OFFSET.rotated(Vector3.UP, yaw) * scale_off
	var lk: Vector3 = target + Vector3(0, LOW_LOOK_Y, 0) if look == null else look
	cam.look_at(lk, Vector3.UP)


func _cam(pos: Vector3, look: Vector3, fov: float = 40.0) -> void:
	cam.fov = fov
	cam.global_position = pos
	cam.look_at(look, Vector3.UP)


func _yaw_from(target: Vector3, from: Vector3) -> float:
	var d := from - target
	return atan2(d.x, d.z)


func _spawn(scene: String, pos: Vector3, yaw: float) -> Node3D:
	var n := (load(scene) as PackedScene).instantiate() as Node3D
	world.add_child(n)
	n.global_position = pos
	n.rotation.y = yaw
	if n is CharacterBody3D:
		(n as CharacterBody3D).set_physics_process(false)
	# o CharacterVisual avanca o AnimationPlayer no _process mesmo depois do seek_clip (pause): parado, a foto mostra
	# exatamente o quadro pedido (corpo e rosto no mesmo instante)
	var v := n.find_child("Model", false, false)
	if v != null:
		v.set_process(false)
	return n


func _vis(n: Node3D) -> CharacterVisual:
	return n.find_child("Model", false, false) as CharacterVisual


func _run() -> void:
	world = (load("res://worlds/village_v3/village_world.tscn") as PackedScene).instantiate() as VillageWorld
	root.add_child(world)
	cam = Camera3D.new()
	world.add_child(cam)
	cam.current = true
	await _wait(1.5)
	if part == "" or part == "world":
		await _world()
	if part == "" or part == "pup":
		await _pup()
	if part == "" or part == "point":
		await _point()
	if part == "" or part == "amora":
		await _amora()
	if part == "" or part == "emblem":
		await _emblem()
	print("[RB] capturas ok")
	quit(0)


func _world() -> void:
	await _size(Vector2i(1280, 720))
	# poste da amarra vazia: visto do cais (de terra) e de lado
	var moor := _mk(&"M1_EmptyMooring")
	_low(moor, _yaw_from(moor, _mk(&"M1_BenchClue")))
	await _shot("mundo_amarra_cais")
	_low(moor, _yaw_from(moor, moor + Vector3(0, 0, 6)))
	await _shot("mundo_amarra_frente")
	_cam(moor + Vector3(2.2, 1.0, 2.2), moor + Vector3(0, 0.5, 0), 45.0)
	await _shot("mundo_amarra_perto")
	# arbusto ao lado da lente do farol
	var lens := _mk(&"M7_Lens")
	_low(lens, _yaw_from(lens, _mk(&"M7_StairBase")) + PI)
	await _shot("mundo_lente_arbusto")
	_low(lens, _yaw_from(lens, lens + Vector3(-3, 0, 3)))
	await _shot("mundo_lente_arbusto_b")
	# bote encalhado perto das pedras do farol (da aproximacao do barco)
	var dinghy := _mk(&"M6_Dinghy")
	var appr := _mk(&"M6_DinghyApproach")
	_cam(appr + Vector3(0, 2.2, 0) + (appr - dinghy).normalized() * 2.0, dinghy + Vector3(0, 0.6, 0), 50.0)
	await _shot("mundo_bote_pedras")
	_cam(dinghy + Vector3(-1.5, 3.5, 7.0), dinghy + Vector3(0, 0.5, -2.0), 50.0)
	await _shot("mundo_bote_pedras_b")
	# marcadores de planos amplos (opcional 5), se existirem
	for n: StringName in [&"Cut_VillageWide", &"Cut_LighthouseView"]:
		var m := world.marker(n)
		if m != null:
			var look_at_n := StringName(String(m.get_meta("look_at", "M8_FestaPlaza")))
			_cam(m.global_position, _mk(look_at_n), 50.0)
			await _shot("mundo_" + String(n).to_lower())
	# lanternas de papel na praca: dia e noite de festa
	var plaza := _mk(&"M8_FestaPlaza")
	_low(plaza, PI * 0.25, plaza + Vector3(0, 2.0, 0))
	await _shot("mundo_praca_lanternas_dia")
	world.set_festival(true)
	await _wait(0.6)
	await _shot("mundo_praca_lanternas_festa")
	world.set_festival(false)
	world.set_night(false)
	await _wait(1.0)


func _pup() -> void:
	await _size(Vector2i(640, 420))
	var base := _mk(&"M1_BenchClue") + Vector3(1.5, 0, 0)
	var pup := _spawn("res://actors/characters/pup_model.tscn", base, PI * 0.5)   # anda para -X, visto do lado (camera em -Z)
	var vis := _vis(pup)
	await _wait(0.3)
	for clip: StringName in [&"walk", &"run"]:
		var n := 8
		var len := vis.animation_length(clip)
		for i in n:
			vis.seek_clip(clip, len * float(i) / n * 0.5)   # meio clipe = um ciclo
			_cam(base + Vector3(0, 0.30, -1.25), base + Vector3(0, 0.24, 0), 34.0)
			await _shot("pup_%s_%d" % [clip, i])
		vis.seek_clip(clip, len * 0.125)
		_low(base, -PI * 0.25, base + Vector3(0, 0.3, 0), 0.6)
		await _shot("pup_%s_baixa" % clip)
	pup.queue_free()
	await _wait(0.2)


func _point() -> void:
	await _size(Vector2i(560, 640))
	var base := _mk(&"M0_RastroStart")
	var chars := [["pico", "res://actors/characters/pico_model.tscn"], ["rastro", "res://actors/characters/rastro_model.tscn"],
		["leme", "res://actors/characters/leme_model.tscn"]]
	for c: Array in chars:
		var a := _spawn(String(c[1]), base, 0.0)
		var vis := _vis(a)
		await _wait(0.3)
		var len := vis.animation_length(&"point")
		for t: float in [0.0, 0.3, 0.5, 0.8, 1.05, len]:
			vis.seek_clip(&"point", minf(t, len - 0.001))
			_cam(base + Vector3(2.9, 0.95, -0.9), base + Vector3(0.25, 0.62, -0.2), 40.0)   # pela direita do heroi, quase de lado
			await _shot("point_%s_%02d" % [c[0], int(round(t * 10))])
		a.queue_free()
		await _wait(0.2)


func _amora() -> void:
	# atras da barraca azul (uvas): barraca em (-19,2; -6,4) virada para -X; cliente em M4_Stall_Grapes (-20,6; -6,4)
	var spot := Vector3(-18.1, 0.0, -6.4)
	var m := world.marker(&"M4_Vendor")
	if m != null:
		spot = m.global_position
	var a := _spawn("res://actors/characters/amora_model.tscn", spot, PI * 0.5)
	var vis := _vis(a)
	await _wait(0.4)
	vis.play(&"idle")
	vis.seek_clip(&"idle", 0.5)
	# camera baixa do jogo vinda do cliente (frente) e de 3/4
	await _size(Vector2i(1280, 720))
	var cust := _mk(&"M4_Stall_Grapes")
	_low(spot, _yaw_from(spot, cust), spot + Vector3(0, 1.08, 0), 1.0)
	await _shot("amora_barraca_baixa")
	_low(spot, _yaw_from(spot, cust) - 0.6, spot + Vector3(0, 1.08, 0), 1.0)
	await _shot("amora_barraca_baixa_34")
	vis.seek_clip(&"wave", 0.75)
	_low(spot, _yaw_from(spot, cust), spot + Vector3(0, 1.08, 0), 1.0)
	await _shot("amora_barraca_wave")
	# turnaround fora da barraca (no meio da rua, sem o balcao na frente)
	a.global_position = _mk(&"M1_BenchClue") + Vector3(2.5, 0, 0.4)
	var kit := world.get_node_or_null(^"Kit") as Node3D
	if kit != null:
		kit.visible = false   # sem caixotes e barris do cais na frente do turnaround
	a.rotation.y = 0.0
	vis.seek_clip(&"idle", 0.5)
	await _size(Vector2i(560, 760))
	var p := a.global_position
	for v: Array in [["frente", 0.0], ["34", -0.66], ["costas", PI]]:
		_cam(p + Vector3(0, 0.95, -3.4).rotated(Vector3.UP, float(v[1])), p + Vector3(0, 0.82, 0), 36.0)   # frente = -Z
		await _shot("amora_%s" % v[0])
	for c: Array in [[&"wave", 0.75], [&"thanks", 1.0], [&"point", 0.6], [&"talk", 0.7], [&"talk", 1.6]]:
		vis.seek_clip(c[0], float(c[1]))
		_cam(p + Vector3(0, 0.95, -3.4).rotated(Vector3.UP, 0.5), p + Vector3(0, 0.82, 0), 36.0)
		await _shot("amora_clip_%s_%02d" % [c[0], int(float(c[1]) * 10)])
	if kit != null:
		kit.visible = true
	a.queue_free()


## Emblema 3D do mosquetao (opcional 5) ao lado do emblema da pegada, na camera baixa e de perto.
func _emblem() -> void:
	await _size(Vector2i(960, 540))
	var base := _mk(&"M0_RastroStart") + Vector3(0, 0.9, 0)
	var e1 := _spawn("res://assets/models/props_v3/emblem_carabiner.tscn", base + Vector3(-0.25, 0, 0), 0.0)
	var e2 := _spawn("res://assets/models/props_v3/emblem_paw.tscn", base + Vector3(0.25, 0, 0), 0.0)
	for n: Node3D in [e1, e2]:
		n.set_process(false)
	var ap1 := e1.get_node_or_null(^"AnimationPlayer") as AnimationPlayer
	var ap2 := e2.get_node_or_null(^"AnimationPlayer") as AnimationPlayer
	for ap: AnimationPlayer in [ap1, ap2]:
		if ap != null:
			ap.stop()
	for n: Node3D in [e1, e2]:
		var coin := n.get_node_or_null(^"Coin") as Node3D
		if coin != null:
			coin.position = Vector3.ZERO
			coin.rotation = Vector3.ZERO
	for v: Array in [["frente", Vector3(0, 0.03, 0.75)], ["frente_tras", Vector3(0, 0.03, -0.75)]]:
		_cam(base + (v[1] as Vector3), base, 40.0)
		await _shot("emblema_mosquetao_%s" % v[0])
	e1.queue_free()
	e2.queue_free()
