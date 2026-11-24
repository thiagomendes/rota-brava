class_name ArrivalStage
extends StageBase
## Etapa 0 - Chegada: o barco encosta sozinho, a caixa desliza, Leme reage. Pular leva ao mesmo ponto de controle.
## A buzina e a reacao chegam por legenda (equivalente visual; audio entra no RB-04).

var _tween: Tween
var _crate: MeshInstance3D
var _done: bool = false
var _active: bool = false


func setup(main: Ep01Main) -> void:
	super.setup(main)
	_crate = Blocks.box(ctx.boat, "Crate", Vector3(0.8, 0.6, 0.8), _crate_start(), Color("f2a65a"))
	_crate.visible = false


func _crate_start() -> Vector3:
	return Ep01Layout.BENCH_LOCAL + Vector3(0.0, 0.0, -1.9)


func _crate_end() -> Vector3:
	return Ep01Layout.BENCH_LOCAL + Vector3(0.0, 0.0, -0.9)


func camera_view() -> Dictionary:
	return {"offset": Vector3(-4, 6.0, 12.0), "yaw": 0.0}


func refresh_world() -> void:
	if ctx.director.state != &"arrival":
		_crate.visible = true
		_crate.position = _crate_end()


func enter() -> void:
	_done = false
	_active = true
	ctx.boat.place(Ep01Layout.BOAT_ARRIVAL_START, Ep01Layout.BOAT_DOCKED_HEADING)
	var pilot: MemberActor = ctx.actors[&"pilot"]
	pilot.ride(ctx.boat, BoatActor.CREW[&"pilot"])
	pilot.face_point(Ep01Layout.BOAT_DOCKED_POS + Vector3(-20, 0, 0))
	var tracker: MemberActor = ctx.actors[&"tracker"]
	tracker.teleport(Ep01Layout.RASTRO_START)
	tracker.face_now(Ep01Layout.BOAT_ARRIVAL_START)
	var climber: MemberActor = ctx.actors[&"climber"]
	climber.teleport(Ep01Layout.RASTRO_START + Vector3(-2.5, 0, 0.5))
	climber.face_now(Ep01Layout.BOAT_DOCKED_POS)
	_crate.visible = true
	_crate.position = _crate_start()
	ctx.camera_rig.set_view(camera_view()["offset"], 0.0)
	ctx.camera_rig.follow(ctx.boat, true)
	ctx.hud.set_skip_hint(true)
	_play()


func exit() -> void:
	_active = false
	_done = true
	if _tween and _tween.is_valid():
		_tween.kill()
	ctx.hud.set_skip_hint(false)


func _play() -> void:
	var lines := Ep01Content.lines(&"arrival", "enter")
	ctx.hud.say(lines[0])
	# A buzina soa fora do quadro ANTES de o barco aparecer (SPEC secao 6: o som revela a chegada).
	ctx.audio.play_sfx("sfx_horn_boat", Vector3(80, 0.5, -5))
	(ctx.actors[&"pilot"] as MemberActor).play_action(&"react_horn")
	await get_tree().create_timer(1.4).timeout
	if _done:
		return
	_tween = create_tween()
	_tween.tween_property(ctx.boat, "global_position", Ep01Layout.BOAT_DOCKED_POS, 6.0) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await _tween.finished
	if _done:
		return
	ctx.audio.play_sfx("sfx_hull_bump", ctx.boat.global_position)
	_tween = create_tween()
	_tween.tween_property(_crate, "position", _crate_end(), 1.0).set_trans(Tween.TRANS_SINE)
	ctx.audio.play_sfx("sfx_crate_slide", ctx.boat.global_position)
	ctx.hud.say(lines[1])
	await _tween.finished
	if _done:
		return
	var rest: Array[String] = []
	for k in lines.slice(2):
		rest.append(k)
	await ctx.hud.say_all(rest)
	_finish()


func _finish() -> void:
	if _done or not _active:
		return
	_done = true
	if _tween and _tween.is_valid():
		_tween.kill()
	ctx.hud.clear_speech()
	ctx.boat.place(Ep01Layout.BOAT_DOCKED_POS, Ep01Layout.BOAT_DOCKED_HEADING)
	_crate.position = _crate_end()
	ctx.submit(&"intro_finished", &"pilot")
	var after := Ep01Content.lines(&"arrival", "intro_finished")
	if not after.is_empty():
		ctx.hud.say(after[0])


## Para testes e para o modo demo: o mesmo caminho do botao de pular.
func skip_intro() -> void:
	_finish()


func _unhandled_input(event: InputEvent) -> void:
	if _active and not _done and not event.is_echo() and event.is_action_pressed(&"interact"):
		get_viewport().set_input_as_handled()
		_finish()
