extends "res://tests/capture_g19.gd"
## Capturas do G25 (roteiro minimo): o lenco do filhote nos juncos do M2 e a entrega do peixe a Dona Amora no fim do M5.
## Mesmo motor do capture_g19 (acoes pelos pontos da Land, camera de lado com --g19-cam=side). So prova visual; NAO e jogo.
## Uso: xvfb-run -a -s "-screen 0 1280x720x24" bash tools/godot.sh --path game --rendering-driver vulkan \
##   res://tests/capture_g25.tscn -- --g19-out=/ABS/captures/g25 --g19-act=m2 --g19-cam=side --g19-step=0.5
## Atos (substituem os do G19): m2 (Rastro examina e pega o lenco nos juncos), m5 (penas e bussola por evento; Pico sobe, pega o peixe,
## baixa na corda, desce, leva e entrega a Amora).


func _act_m2() -> void:
	var land := main.land
	var scarf: Node3D = (land.get("_pieces") as Array)[2]
	var tracker := main.actors[&"tracker"] as MemberActor
	await _go(&"tracker", land._mk(&"M2_ReedsPiece") + Vector3(0.9, 0, 0.6))
	tracker.face_now(scarf.global_position)
	# camera parada, de cima e de lado, olhando o lenco (o capim alto tapa a camera que segue o heroi)
	var fixed := Camera3D.new()
	fixed.fov = 45.0
	fixed.near = 0.03
	add_child(fixed)
	fixed.current = true
	var at := scarf.global_position
	var side := (tracker.global_position - at)
	side.y = 0.0
	side = Vector3(-side.z, 0, side.x).normalized()
	fixed.global_position = at + side * 1.3 + Vector3(0, 1.5, 0) + (tracker.global_position - at) * 0.3
	fixed.look_at(at + Vector3(0, 0.25, 0), Vector3.UP)
	await _wait(0.4)
	await _save("g25_m2_a_lenco_nos_juncos.png")
	main.land.call("_on_spot", &"reeds", _hero(&"tracker"))
	await _wait(1.6)
	await _save("g25_m2_b_rastro_examina.png")
	while main.land.busy:
		await get_tree().process_frame
	await _wait(0.3)
	await _save("g25_m2_c_lenco_na_mao.png")
	await _done()


func _act_m5() -> void:
	var land := main.land
	for ev: StringName in [&"feather_followed", &"feather_followed", &"feather_followed", &"feather_followed", &"compass_read"]:
		for who: StringName in [&"tracker", &"pilot", &"climber"]:
			if main.current.notify(ev, who):
				break
	await _wait(1.0)
	if main.hud.handoff_open:
		main.hud._handoff_since = -100.0
		main.hud._confirm_handoff()
	await _wait(1.5)
	(main.actors[&"climber"] as MemberActor).teleport(land.points[&"CratesBase"] + Vector3(0, 0.05, 0))   # como o teste (o raio do _go pega o caixote)
	await _wait(0.3)
	await _until_free(&"climber", &"crates_climb", "g25_m5_a_sobe", 6.0)
	land.call("_set_busy", true)   # segura a montagem do M6 depois da entrega
	# G25b: camera do jogo (sem --g19-cam), seguindo o Pico: quadros a cada 1 s e no instante da entrega
	var pico := _hero(&"climber")
	land.call("_on_spot", &"fish", pico)
	var t := 0.0
	var next := 0.0
	var n := 0
	var caught := false
	while int(land.get("_acts")) > 0 and t < 120.0:
		var fish = land.get("_fish")
		if not caught and fish != null and is_instance_valid(fish) and (fish as Node).has_meta(&"returned_to"):
			caught = true
			await _save("g25b_m5_entrega.png")
		elif t >= next:
			await _save("g25b_m5_%02d.png" % n)
			n += 1
			next += 1.0
		await get_tree().process_frame
		t += get_process_delta_time()
	await _wait(0.5)
	await _save("g25b_m5_fim.png")
	await _done()


## Como _do, mas espera a acao terminar de verdade (Land sem acoes), com um quadro a cada `every` s de jogo.
func _until_free(m: StringName, id: StringName, tag: String, every: float) -> void:
	var a := _hero(m)
	_subject = a
	main.land.call("_on_spot", id, a)
	var t := 0.0
	var next := 0.0
	var n := 0
	await get_tree().process_frame
	while int(main.land.get("_acts")) > 0 and t < 120.0:
		if t >= next:
			await _save("%s_%02d.png" % [tag, n])
			n += 1
			next += every
		await get_tree().process_frame
		t += get_process_delta_time()
	await _wait(0.5)
	await _save("%s_%02d.png" % [tag, n])
