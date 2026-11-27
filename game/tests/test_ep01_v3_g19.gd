extends RefCounted
## RB-R1 G19: as acoes do Ep01 v3 acontecem no jogo, com o heroi fazendo. Para cada acao, jogada pelos proprios pontos da
## Land (o "agir" da crianca), mede ESTADO: o objeto passa pela mao (fica preso ao ponto de pega ligado aos ossos
## HoldPoint/HoldPoint_L) e termina apoiado (PropOverlap: sem flutuar nem atravessar); no M4 so a caixinha daquela barraca
## sai do carrinho e as outras pecas ficam no mesmo no e no mesmo lugar; o Pico escala (clipes climb_*) sem salto, nenhum
## osso do pe entra no degrau e ele termina no apoio; nenhuma acao deixa o heroi preso (desmontar no meio solta tudo);
## o mesmo "agir" acelera o gesto; a retomada pelo salvo com M2 e M4 concluidos remonta varal, cesto, banco e caixinhas.
## Nao comprova render nem a leitura do gesto (capturas em captures/g19-acoes/).

const FEET: Array[StringName] = [&"toe.R", &"toe.L", &"heel.R", &"heel.L", &"toe_tip.R", &"toe_tip.L"]
## Folga de um osso do pe abaixo da superficie logo acima/abaixo dele (m): mais que isto = dentro do degrau.
const FOOT_TOL := 0.04
## Distancia maxima (m) entre o objeto na mao e o ponto de pega dos ossos.
const HAND_TOL := 0.08

var r
var _feet_worst := 0.0
var _feet_where := ""
var _hand_worst := 0.0
var _hand_seen := 0
var _hand_where := ""
var _last_anim: StringName = &""
var _airborne := false
var _monitor := false


func run(runner) -> void:
	r = runner
	Ep01V3Main.save_path = ""
	await _m2()
	await _m4()
	await _climb_m3()
	await _no_stuck()
	await _resume_after_m2_m4()
	await _m1_boot()
	await _m5_fish()
	await _m7_lens_pup_compass()
	await _g19b_pause()
	await _g19b_exit_frees()
	await _g19b_swap_m2()
	await _g19b_swap_m4()
	await _g19b_save_mid_action()
	Ep01V3Main.start_mission = &""


func _new_main(mission: StringName) -> Ep01V3Main:
	Ep01V3Main.start_mission = mission
	var main := (load("res://episodes/ep01/v3/ep01_v3_main.tscn") as PackedScene).instantiate() as Ep01V3Main
	r.tree.root.add_child(main)
	r.tree.current_scene = main
	await r.frames(4)
	if main.hud.handoff_open:
		main.hud._handoff_since = -100.0
		main.hud._confirm_handoff()
		await r.frames(3)
	main.hud.clear_speech()
	main.guide.skip_look()
	main.set_followers_enabled(false)
	return main


func _free(main: Ep01V3Main) -> void:
	main.queue_free()
	await r.frames(2)
	r.tree.current_scene = null
	r.tree.paused = false


func _hero(main: Ep01V3Main, m: StringName) -> MemberActor:
	var a := main.actors[m] as MemberActor
	main.active_member = m
	main.set_controlled(a)
	if main.current != null:
		main.current.set_active_hero(m)
	return a


## Dispara o ponto `id` com o heroi `m` (o mesmo que o "agir") e espera a Land ficar livre, medindo a cada passo de fisica
## o pe (dentro do degrau?) e o objeto na mao (preso a pega?). Devolve a duracao da acao (s de jogo).
func _act(main: Ep01V3Main, m: StringName, id: StringName, limit: float = 12.0) -> float:
	var a := _hero(main, m)
	var land := main.land
	if not land.spots.has(id):
		r.check(false, "G19: ponto %s existe na missao %s" % [id, land.mission_id])
		return 0.0
	_monitor = true
	land.call("_on_spot", id, a)
	var t := 0.0
	while t < limit:
		await r.tree.physics_frame
		t += r.tree.root.get_physics_process_delta_time()
		_measure(main, a)
		if int(land.get("_acts")) == 0:
			break
	_monitor = false
	await r.frames(2)
	return t


func _measure(main: Ep01V3Main, a: MemberActor) -> void:
	if a.airborne:
		_airborne = true
	var land := main.land
	var held = land.get("carried")
	if held != null and is_instance_valid(held) and a.model != null:
		var g := (held as Node3D).get_parent() as Node3D
		var vis := a.model
		var hp := vis.bone_position(&"HoldPoint")
		var hl := vis.bone_position(&"HoldPoint_L")
		var want := (hp + hl) * 0.5 if g != null and g.get_meta(&"two", false) else hp
		if g != null and g.name == &"G19Grip":
			_hand_seen += 1
			var dd := g.global_position.distance_to(want)
			if dd > _hand_worst:
				_hand_worst = dd
				_hand_where = "%s %s %s g=%s want=%s a=%s" % [a.member, a.model.current_animation(), (held as Node).name, g.global_position, want, a.global_position]
		else:
			_hand_worst = INF
	if a.model == null or not a.scripted:
		return
	# quadro da troca de clipe/apoio (origem ja no apoio novo, pose ainda do quadro anterior): nao mede
	var anim := a.model.current_animation()
	if anim != _last_anim:
		_last_anim = anim
		return
	var space := main.world.get_world_3d().direct_space_state
	for b: StringName in FEET:
		var p := a.model.bone_position(b)
		if p == Vector3.INF:
			continue
		# superficie logo acima do osso (ate 0,5 m): se ha chao/degrau por cima do pe, o pe esta dentro dele
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3(0, 0.2, 0), p - Vector3(0, 0.6, 0), 1))
		if not hit.is_empty():
			var depth: float = (hit.position as Vector3).y - p.y
			if depth > _feet_worst:
				_feet_worst = depth
				_feet_where = "%s %s em %s (origem %s, %s)" % [a.member, b, p, a.global_position, a.model.current_animation()]


func _reset_measures() -> void:
	_feet_worst = 0.0
	_feet_where = ""
	_hand_worst = 0.0
	_hand_seen = 0
	_airborne = false


func _passed_hand(land: Node, piece, member: StringName) -> bool:
	var log = land.get("hand_log")
	if log == null or piece == null or not is_instance_valid(piece):
		return false
	for e: Dictionary in log:
		if e["piece"] == piece and e["member"] == member:
			return true
	return false


func _free_actor(a: MemberActor) -> bool:
	return not a.scripted and not a.airborne


# ------------------------------------------------------------------ M2: soltar, levar, cesto, banco, varal

func _m2() -> void:
	var main := await _new_main(&"M2")
	var land := main.land
	var pieces: Array = land.get("_pieces")
	var climber := main.actors[&"climber"] as MemberActor
	r.check(int(land.get("grass_cleared")) > 0, "G19 (pendencia G18): o capim do kit sai de baixo do cesto (%d tufos)" % int(land.get("grass_cleared")))
	var tracker := main.actors[&"tracker"] as MemberActor
	_reset_measures()
	climber.teleport(land.points[&"ShedBase"] + Vector3(0, 0.05, 0))
	await r.frames(2)
	var t_up := await _act(main, &"climber", &"shed_climb")
	r.check(land.call("_on_shed"), "G19 M2: o Pico chega ao alto do galpao escalando (%.1f s)" % t_up)
	var t_free := await _act(main, &"climber", &"shed_free")
	r.check(_passed_hand(land, pieces[0], &"climber"), "G19 M2: a camiseta passa pela mao do Pico (soltar no telhado)")
	r.check(land.get("carried") == pieces[0] and climber.hands == &"carry" and climber.global_position.y < 0.3,
		"G19 M2: o Pico desce escalando com a camiseta na mao e o controle volta no chao (%.1f s, y %.2f)" % [t_free,
		climber.global_position.y])
	r.check(main.current.step_progress == 0, "G19 M2: soltar ainda nao conta: conta ao por no cesto")
	climber.teleport(main.floor_at(land.points[&"Basket"] + Vector3(0, 0, 0.55)) + Vector3(0, 0.05, 0))
	await r.frames(2)
	await _act(main, &"climber", &"basket")
	r.check(land.get("carried") == null and pieces[0].get_meta(&"in_basket", false) and main.current.step_progress == 1,
		"G19 M2: a camiseta sai da mao para o cesto e conta (%d)" % main.current.step_progress)
	climber.teleport(land.points[&"TreeBase"] + Vector3(0, 0.05, 0))
	await r.frames(2)
	await _act(main, &"climber", &"tree_climb")
	r.check(land.call("_on_tree"), "G19 M2: o Pico chega ao galho escalando")
	await _act(main, &"climber", &"tree_free")
	r.check(_passed_hand(land, pieces[1], &"climber") and land.get("carried") == pieces[1] and climber.global_position.y < 0.3,
		"G19 M2: o lenco passa pela mao e o Pico desce da arvore com ele")
	climber.teleport(main.floor_at(land.points[&"Basket"] + Vector3(0, 0, 0.55)) + Vector3(0, 0.05, 0))
	await r.frames(2)
	await _act(main, &"climber", &"basket")
	tracker.teleport(main.floor_at(land._mk(&"M2_ReedsPiece") + Vector3(0.5, 0, 0.3)) + Vector3(0, 0.05, 0))
	await r.frames(2)
	await _act(main, &"tracker", &"reeds")
	r.check(_passed_hand(land, pieces[2], &"tracker") and land.get("carried") == pieces[2],
		"G19 M2: o Rastro acha a meia nos juncos e fica com ela na mao")
	tracker.teleport(main.floor_at(land.points[&"Basket"] + Vector3(0, 0, 0.55)) + Vector3(0, 0.05, 0))
	await r.frames(2)
	await _act(main, &"tracker", &"basket")
	r.check(main.current.current_step().get("id", &"") == &"hang", "G19 M2: com as 3 roupas no cesto o passo e pendurar")
	var po := PropOverlap.new()
	po.collect(main)
	for i in 3:
		await r.tree.physics_frame
	var ov := po.overlaps(po.ids_with_prefix("mission:"))
	r.check(ov.is_empty(), "G19 M2: 3 roupas no cesto (vindas da mao) sem atravessar nada (%s)" % [ov])
	po.free_probes()
	# pendurar as 3: pega do cesto, sobe no banco, prende na corda
	land.call("_set_busy", false)
	var reach_worst := 0.0
	var t_hang := 0.0
	for i in 3:
		await _act(main, &"tracker", &"basket")
		var piece = land.get("carried")
		r.check(piece != null, "G19 M2: pega a roupa %d do cesto" % (i + 1))
		var a := tracker
		if i == 2:
			land.call("_set_busy", true)   # segura a montagem do M3 para medir com o M2 concluido
		# mede o alcance: no instante em que a roupa sai da mao para a corda, a pega esta na corda
		var slot: Transform3D = land.line_slot(clampi((land.get("_pieces") as Array).find(piece), 0, 2))
		land.call("_on_spot", &"hang", a)
		var t := 0.0
		var last_grip := Vector3.INF
		while t < 6.0 and land.get("_acts") > 0:
			await r.tree.physics_frame
			t += r.tree.root.get_physics_process_delta_time()
			if land.get("carried") != null:
				last_grip = ((land.get("carried") as Node3D).get_parent() as Node3D).global_position
			_measure(main, a)
		t_hang = maxf(t_hang, t)
		await r.frames(2)
		reach_worst = maxf(reach_worst, last_grip.distance_to(slot.origin))
		r.check(piece != null and (piece as Node3D).get_meta(&"hung", false) and _free_actor(a) and a.global_position.y < 0.3,
			"G19 M2: roupa %d pendurada do alto do banco e o heroi desce (%.2f s)" % [i + 1, t])
	r.check(reach_worst < 0.12, "G19 M2: a mao chega na corda do alto do banco (pega a %.1f cm da vaga no instante de prender)"
		% (reach_worst * 100.0))
	r.check(t_hang <= 3.0, "G19 M2: pendurar (com os passos ate o banco) dura ate 3,0 s (pior %.2f s)" % t_hang)
	r.check(_hand_seen > 0 and _hand_worst < HAND_TOL, "G19 M2: o que esta na mao fica no ponto de pega dos ossos (%d quadros, pior %.1f cm %s)"
		% [_hand_seen, _hand_worst * 100.0, _hand_where])
	po = PropOverlap.new()
	po.collect(main)
	for i in 3:
		await r.tree.physics_frame
	var cl := po.clothesline(main.world, pieces)
	r.check((cl["gaps"] as Array).size() == 6 and (cl["floating"] as Array).is_empty() and (cl["overlaps"] as Array).is_empty(),
		"G19 M2: as 3 roupas penduradas pela mao encostam na corda sem entrar em nada (%d metades, %d no ar, %s)" % [
		(cl["gaps"] as Array).size(), (cl["floating"] as Array).size(), cl["overlaps"]])
	var bench_ids := []
	for p in po.props:
		if "ClothesBench" in String(p["id"]) or "Basket" in String(p["id"]):
			bench_ids.append(p["id"])
	var fl := po.floating(main.world.get_world_3d().direct_space_state, bench_ids)
	var ov2 := po.overlaps(bench_ids)
	ov2.append_array(po.structure_hits(bench_ids))
	r.check(bench_ids.size() >= 2 and fl.is_empty() and ov2.is_empty(),
		"G19 M2: banco e cesto apoiados no chao sem atravessar nada (%s; %d no ar, %d pares)" % [bench_ids, fl.size(), ov2.size()])
	po.free_probes()
	r.check(_feet_worst < FOOT_TOL, "G19 M2: nenhum pe entra no degrau ao escalar/subir no banco (pior %.1f cm %s)" % [
		_feet_worst * 100.0, _feet_where])
	r.check(not _airborne, "G19 M2: nenhuma subida ou descida usa salto programado (jump_to)")
	land.call("_set_busy", false)
	await _free(main)


# ------------------------------------------------------------------ M4: a caixinha certa

func _cargo_state(land: Node) -> Dictionary:
	var out := {}
	var box: Node3D = land.get("_cargo_box")
	if box == null:
		return out
	for c in box.get_children():
		out[c.get_instance_id()] = (c as Node3D).position
	return out


func _m4() -> void:
	var main := await _new_main(&"M4")
	var land := main.land
	main.current.notify(&"icons_read", &"tracker")
	await r.frames(3)
	if main.hud.handoff_open:
		main.hud._handoff_since = -100.0
		main.hud._confirm_handoff()
		await r.frames(3)
	var leme := _hero(main, &"pilot")
	_reset_measures()
	land.call("_on_spot", &"take_cart", leme)
	r.check(leme.hands == &"push", "G19 M4: a Leme pega o carrinho com as maos na alca (push_cart)")
	var cargo := _cargo_state(land)
	r.check(cargo.size() == 6, "G19 M4: carrinho com 3 caixas grandes e 3 caixinhas (%d)" % cargo.size())
	# barraca errada: nada se mexe
	leme.teleport(main.floor_at(land._mk(&"M4_Stall_Lemon") + Vector3(1.2, 0, 0)) + Vector3(0, 0.05, 0))
	await r.frames(2)
	await _act(main, &"pilot", &"deliver_M4_Stall_Lemon", 2.0)
	var same := _cargo_state(land)
	var moved := 0
	for k in cargo:
		if not same.has(k) or (same[k] as Vector3).distance_to(cargo[k]) > 0.001:
			moved += 1
	r.check(moved == 0 and land.get("carried") == null, "G19 M4: barraca errada nao tira nada do carrinho (%d mexeram)" % moved)
	var delivered: Array = []
	land.call("_set_busy", true)   # segura a montagem do M5 para medir com o M4 concluido
	for st: StringName in Ep01V3Land.CARGO_ORDER:
		land.call("_attach_cart", leme)
		var m := land._mk(st)
		leme.teleport(main.floor_at(m + (land.cart.global_position - m).normalized() * 1.5) + Vector3(0, 0.05, 0))
		await r.frames(40)
		var before := _cargo_state(land)
		var want: Node3D = land.call("cargo_box", st)
		var t_lift := await _act(main, &"pilot", StringName("deliver_" + String(st)))
		var held = land.get("carried")
		var after := _cargo_state(land)
		var others_still := true
		for k in before:
			if want != null and k == want.get_instance_id():
				continue
			if not after.has(k) or (after[k] as Vector3).distance_to(before[k]) > 0.001:
				others_still = false
		r.check(want != null and held == want and _passed_hand(land, want, &"pilot"),
			"G19 M4 %s: sai do carrinho a caixinha desta barraca, para a mao da Leme (%.2f s)" % [st, t_lift])
		r.check(others_still and after.size() == before.size() - 1,
			"G19 M4 %s: as outras pecas do carrinho ficam no mesmo no e no mesmo lugar (%d -> %d)" % [st, before.size(), after.size()])
		var t_drop := await _act(main, &"pilot", StringName("deliver_" + String(st)))
		r.check(want != null and want.get_meta(&"delivered", false) and land.get("carried") == null and _free_actor(leme),
			"G19 M4 %s: pousa a caixinha na frente da barraca (%.2f s)" % [st, t_drop])
		r.check(t_lift <= 2.6 and t_drop <= 2.6, "G19 M4 %s: cada gesto (com os passos) ate 2,6 s (%.2f / %.2f)" % [st, t_lift, t_drop])
		if want != null:
			delivered.append(want)
	r.check(_hand_seen > 0 and _hand_worst < HAND_TOL, "G19 M4: a caixinha fica no ponto de pega das duas palmas (pior %.1f cm)"
		% (_hand_worst * 100.0))
	var po := PropOverlap.new()
	po.collect(main)
	for i in 3:
		await r.tree.physics_frame
	var ids := []
	var root: Node = land.get("_root")
	for c in delivered:
		ids.append("mission:" + String(root.get_path_to(c)))
	var fl := po.floating(main.world.get_world_3d().direct_space_state, ids)
	var ov := po.overlaps(ids)
	ov.append_array(po.structure_hits(ids))
	r.check(ids.size() == 3 and fl.is_empty() and ov.is_empty(), "G19 M4: 3 caixinhas entregues apoiadas no chao, sem atravessar nada (%s %s)"
		% [fl, ov])
	var crates := []
	for c in (land.get("_cargo_box") as Node).get_children():
		if String(c.name).begins_with("Crate"):
			crates.append(c)
	r.check(crates.size() == 3, "G19 M4: as 3 caixas grandes continuam no carrinho (%d)" % crates.size())
	po.free_probes()
	await _free(main)


# ------------------------------------------------------------------ Escalada (M3) e folhas

func _climb_m3() -> void:
	var main := await _new_main(&"M3")
	var land := main.land
	main.current.notify(&"stream_followed", &"tracker")
	main.current.notify(&"stream_followed", &"tracker")
	await r.frames(3)
	if main.hud.handoff_open:
		main.hud._handoff_since = -100.0
		main.hud._confirm_handoff()
		await r.frames(3)
	var pico := _hero(main, &"climber")
	pico.teleport(land.points[&"FountainBase"] + Vector3(0, 0.05, 0))
	await r.frames(2)
	_reset_measures()
	var t_up := await _act(main, &"climber", &"fountain_climb")
	var floor_y: float = land.call("_floor_y", pico.global_position)
	r.check(land.call("_on_fountain") and absf(floor_y - pico.global_position.y) < 0.05 and _free_actor(pico),
		"G19 M3: o Pico sobe o chafariz escalando e termina apoiado na bacia (%.1f s, %.1f cm do apoio)" % [t_up,
		(pico.global_position.y - floor_y) * 100.0])
	var log: Array = land.get("clip_log")
	var climbs := 0
	for e: Dictionary in log:
		if String(e["clip"]).begins_with("climb_"):
			climbs += 1
	r.check(climbs >= 2, "G19 M3: a subida usa os clipes de escalar (%d climb_*)" % climbs)
	var leaves: Node3D = (land.get("_pieces") as Array)[0]
	land.call("_set_busy", true)   # segura a montagem do M4
	await _act(main, &"climber", &"leaves")
	r.check(_passed_hand(land, leaves, &"climber"), "G19 M3: as folhas passam pela mao do Pico (puxar)")
	floor_y = land.call("_floor_y", pico.global_position)
	r.check(pico.global_position.y < 0.3 and absf(floor_y - pico.global_position.y) < 0.05 and _free_actor(pico),
		"G19 M3: o Pico desce do chafariz escalando e termina no chao (y %.2f)" % pico.global_position.y)
	r.check(_feet_worst < FOOT_TOL, "G19 M3: nenhum pe atravessa o degrau na subida e na descida (pior %.1f cm %s)" % [
		_feet_worst * 100.0, _feet_where])
	r.check(not _airborne, "G19 M3: subida e descida sem salto programado")
	var po := PropOverlap.new()
	po.collect(main)
	for i in 3:
		await r.tree.physics_frame
	var lid := ["mission:" + String((land.get("_root") as Node).get_path_to(leaves))]
	var fl := po.floating(main.world.get_world_3d().direct_space_state, lid)
	r.check(fl.is_empty(), "G19 M3: as folhas jogadas ficam no chao (%s)" % [fl])
	po.free_probes()
	await _free(main)


# ------------------------------------------------------------------ ninguem fica preso; pular o gesto

func _no_stuck() -> void:
	var main := await _new_main(&"M2")
	var land := main.land
	var pico := _hero(main, &"climber")
	pico.teleport(land.points[&"ShedBase"] + Vector3(0, 0.05, 0))
	await r.frames(2)
	land.call("_on_spot", &"shed_climb", pico)
	for i in 20:
		await r.tree.physics_frame
	r.check(land.busy and pico.scripted, "G19: durante a escalada a Land fica ocupada e o Pico tomado")
	land.build(&"M2")   # desmonta no meio (troca de missao, retomada)
	await r.frames(3)
	r.check(not land.busy and _free_actor(pico) and pico.hands == &"", "G19: desmontar no meio da acao solta o heroi (busy %s, scripted %s)"
		% [land.busy, pico.scripted])
	# pular: o mesmo agir acelera a escalada
	pico.teleport(land.points[&"ShedBase"] + Vector3(0, 0.05, 0))
	await r.frames(2)
	var t_normal := await _act(main, &"climber", &"shed_climb")
	pico.teleport(land.points[&"ShedBase"] + Vector3(0, 0.05, 0))
	land.build(&"M2")
	await r.frames(3)
	land.call("_on_spot", &"shed_climb", pico)
	await r.tree.physics_frame
	var skipped: bool = land.call("skip_action")
	var t := 0.0
	while land.busy and t < 12.0:
		await r.tree.physics_frame
		t += r.tree.root.get_physics_process_delta_time()
	r.check(skipped and t < t_normal * 0.5 and land.call("_on_shed"),
		"G19: o mesmo agir acelera o gesto ate o fim (%.2f s em vez de %.2f s) e o Pico termina no alto" % [t, t_normal])
	r.check(not land.call("skip_action"), "G19: sem acao em curso o agir nao e engolido pelo pular")
	await _free(main)


# ------------------------------------------------------------------ retomada com M2 e M4 concluidos (pendencia G18)

func _resume_after_m2_m4() -> void:
	var path := "user://test_ep01_v3_g19.save.json"
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	Ep01V3Main.save_path = path
	var main := await _new_main(&"")
	var evs := {&"M0": [&"marker_reached"], &"M1": [&"paw_examined", &"boot_examined", &"paw_followed", &"paw_followed",
		&"paw_followed", &"paw_followed"], &"M2": [&"piece_freed", &"piece_freed", &"piece_found", &"piece_hung", &"piece_hung",
		&"piece_hung"], &"M3": [&"stream_followed", &"stream_followed", &"leaves_pulled"], &"M4": [&"icons_read",
		&"cargo_delivered", &"cargo_delivered", &"cargo_delivered"]}
	for mid: StringName in [&"M0", &"M1", &"M2", &"M3", &"M4"]:
		for ev: StringName in evs[mid]:
			if main.current != null and main.current.id == mid:
				for who: StringName in [&"tracker", &"climber", &"pilot"]:
					if main.current.notify(ev, who):
						break
		await r.frames(2)
	r.check(main.current != null and main.current.id == &"M5", "G19 retomada: M0-M4 concluidas pelo evento (%s)" % (main.current.id if main.current else &"-"))
	await _free(main)
	var again := await _new_main(&"")
	r.check(again.current != null and again.current.id == &"M5", "G19 retomada: recarregar o salvo retoma no M5")
	var after: Node = again.land.get("_after")
	var cloths: Array = []
	var boxes: Array = []
	var bench := 0
	var basket := 0
	if after != null:
		for c in after.get_children():
			var n := String(c.name)
			if n.begins_with("ClothesBench"):
				bench += 1
			elif n.begins_with("Cloth"):
				cloths.append(c)
			elif n.begins_with("Box_"):
				boxes.append(c)
			elif n.begins_with("Basket"):
				basket += 1
	r.check(cloths.size() == 3 and boxes.size() == 3 and bench == 1 and basket == 1,
		"G19 retomada: o mundo volta com 3 roupas no varal, cesto, banco e 3 caixinhas nas barracas (%d, %d, %d, %d)" % [
		cloths.size(), basket, bench, boxes.size()])
	var po := PropOverlap.new()
	po.collect(again)
	for i in 3:
		await r.tree.physics_frame
	var cl := po.clothesline(again.world, cloths)
	var ids := po.ids_with_prefix("mission:")
	var keep_ids := []
	for k in po.props:
		var id := String(k["id"])
		if id.begins_with("mission:Box_") or id.begins_with("mission:ClothesBench") or id.begins_with("mission:Basket"):
			keep_ids.append(id)
	var fl := po.floating(again.world.get_world_3d().direct_space_state, keep_ids)
	r.check((cl["floating"] as Array).is_empty() and (cl["gaps"] as Array).size() == 6,
		"G19 retomada: as roupas remontadas encostam na corda (%d metades)" % (cl["gaps"] as Array).size())
	r.check(keep_ids.size() == 5 and fl.is_empty(), "G19 retomada: caixinhas, banco e cesto remontados apoiados (%d; %s)" % [keep_ids.size(), fl])
	po.free_probes()
	if ids.is_empty():
		pass
	await _free(again)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	Ep01V3Main.save_path = ""


# ------------------------------------------------------------------ M1, M5, M7 (bota, peixe, lente, filhote, bussola)

func _notify_all(main: Ep01V3Main, evs: Array) -> void:
	for ev: StringName in evs:
		for who: StringName in [&"tracker", &"climber", &"pilot"]:
			if main.current.notify(ev, who):
				break
	await r.frames(3)
	if main.hud.handoff_open:
		main.hud._handoff_since = -100.0
		main.hud._confirm_handoff()
		await r.frames(3)
	main.hud.clear_speech()


func _m1_boot() -> void:
	var main := await _new_main(&"M1")
	var land := main.land
	await _notify_all(main, [&"paw_examined"])
	var boot := (land.get("_root") as Node).get_node_or_null("CaptainBoot") as Node3D
	var home := boot.global_transform
	var rastro := main.actors[&"tracker"] as MemberActor
	rastro.teleport(main.floor_at(boot.global_position + Vector3(0.5, 0, 0.3)) + Vector3(0, 0.05, 0))
	await r.frames(2)
	var t := await _act(main, &"tracker", &"boot")
	r.check(_passed_hand(land, boot, &"tracker") and boot.global_transform.origin.distance_to(home.origin) < 0.01
		and _free_actor(rastro) and t <= 2.2, "G19 M1: o Rastro pega a bota, olha e pousa de volta no lugar (%.2f s)" % t)
	await _free(main)


func _m5_fish() -> void:
	var main := await _new_main(&"M5")
	var land := main.land
	await _notify_all(main, [&"feather_followed", &"feather_followed", &"feather_followed", &"feather_followed", &"compass_read"])
	var pico := _hero(main, &"climber")
	pico.teleport(land.points[&"CratesBase"] + Vector3(0, 0.05, 0))
	await r.frames(2)
	_reset_measures()
	await _act(main, &"climber", &"crates_climb", 15.0)
	r.check(land.call("_on_roof"), "G19 M5: o Pico sobe caixotes, toldo e telhado escalando")
	land.call("_set_busy", true)
	var t := await _act(main, &"climber", &"fish", 20.0)
	var fish = land.get("_fish")
	r.check(_passed_hand(land, fish, &"climber"), "G19 M5: o peixe passa pela mao do Pico (pega na telha)")
	r.check(pico.global_position.y < 0.3 and _free_actor(pico), "G19 M5: o Pico desce escalando e fica livre (%.1f s, y %.2f)" % [t, pico.global_position.y])
	r.check(not _airborne, "G19 M5: sem salto programado")
	var po := PropOverlap.new()
	po.collect(main)
	for i in 3:
		await r.tree.physics_frame
	var ids := []
	if fish != null and is_instance_valid(fish):
		ids.append("mission:" + String((land.get("_root") as Node).get_path_to(fish)))
	# o PropOverlap nao mede o peixe (prefixo "Fish" = pendurado): mede aqui o ponto mais baixo contra o chao
	var gap := INF
	if fish != null and is_instance_valid(fish):
		var f := fish as Node3D
		gap = f.global_position.y + Ep01V3Land.piece_low(f, f.global_basis) - float(land.call("_floor_y", f.global_position))
	r.check(ids.size() == 1 and absf(gap) < 0.03, "G19 M5: o peixe baixado na corda termina apoiado na rua (folga %.1f cm)" % (gap * 100.0))
	po.free_probes()
	land.call("_set_busy", false)
	await _free(main)


func _m7_lens_pup_compass() -> void:
	var main := await _new_main(&"M7")
	var land := main.land
	await r.frames(3)
	var rastro := _hero(main, &"tracker")
	var src := main.world.props.get("wv3_lens") as Node3D
	rastro.teleport(main.floor_at(src.global_position + Vector3(0.6, 0, 0.4)) + Vector3(0, 0.05, 0))
	await r.frames(2)
	await _act(main, &"tracker", &"lens")
	var lens = land.get("carried")
	r.check(lens != null and _passed_hand(land, lens, &"tracker") and not src.visible,
		"G19 M7: o Rastro pega a lente com as duas maos e fica com ela (a do mundo nao some sem ninguem)")
	await r.frames(3)
	if main.hud.handoff_open:
		main.hud._handoff_since = -100.0
		main.hud._confirm_handoff()
		await r.frames(3)
	var pico := _hero(main, &"climber")
	pico.teleport(land.points[&"StairFoot"] + Vector3(0, 0.05, 0))
	rastro.teleport(land.points[&"StairFoot"] + Vector3(1.0, 0.05, 0.5))
	await r.frames(2)
	_reset_measures()
	await _act(main, &"climber", &"stair_climb", 20.0)
	r.check(_passed_hand(land, lens, &"climber") and land.call("_on_gallery"),
		"G19 M7: a lente passa da mao do Rastro para a do Pico e ele sobe ate a galeria escalando")
	land.call("_set_busy", true)
	await _act(main, &"climber", &"pup", 25.0)
	var mxf: Transform3D = land.call("lens_mount_xf")
	r.check(lens != null and is_instance_valid(lens) and (lens as Node3D).get_meta(&"mounted", false)
		and (lens as Node3D).global_position.distance_to(mxf.origin) < 0.3,
		"G19 M7: a lente fica montada no encaixe da torre (nao some)")
	var foot: Vector3 = land.points[&"StairFoot"]
	r.check(land.pup.global_position.distance_to(foot) < 1.5 and absf(land.pup.global_position.y - main.floor_at(land.pup.global_position).y) < 0.05,
		"G19 M7: o filhote desce na corda e termina no chao ao pe da escada")
	r.check(pico.global_position.distance_to(foot) < 0.5 and _free_actor(pico), "G19 M7: o Pico desce a escada escalando e fica livre")
	r.check(not _airborne, "G19 M7: subida e descida sem salto programado")
	land.call("_set_busy", false)
	await r.frames(3)
	if main.hud.handoff_open:
		main.hud._handoff_since = -100.0
		main.hud._confirm_handoff()
		await r.frames(3)
	var leme := _hero(main, &"pilot")
	leme.teleport(land.points[&"Compass"] + Vector3(0.6, 0.05, 0.3))
	await r.frames(2)
	var hc = land.get("_hand_compass")
	land.call("_set_busy", true)
	for i in 4:
		await _act(main, &"pilot", &"aim")
	r.check(hc != null and _passed_hand(land, hc, &"pilot") and land.call("lit_count") == 4 and land.get("carried") == null,
		"G19 M7: a Leme segura a bussola de mao nas 4 miras e devolve a rosa (%d acesos)" % land.call("lit_count"))
	var po := PropOverlap.new()
	po.collect(main)
	for i in 3:
		await r.tree.physics_frame
	var ids := []
	for k in po.props:
		var id := String(k["id"])
		if "HandCompass" in id or "RopeDinghyLine" in id:
			ids.append(id)
	var fl := po.floating(main.world.get_world_3d().direct_space_state, ids.filter(func(x): return "HandCompass" in x))
	# a corda (DinghyLine) entra nas voltas da propria amarra de proposito: o par corda x amarra nao conta
	var ov := po.overlaps(ids)
	ov.append_array(po.structure_hits(ids))
	r.check(ids.size() == 2 and fl.is_empty() and ov.is_empty(), "G19 M7: bussola apoiada na rosa e corda do bote amarrada na estaca sem atravessar nada (%s %s %s)" % [ids, fl, ov])
	po.free_probes()
	land.call("_set_busy", false)
	await _free(main)


# ------------------------------------------------------------------ G19b: ressalvas da revisao (A-D)

## Espera a Land sem acoes (ou `limit` s). Devolve o tempo.
func _until_free(land: Node, limit: float = 12.0) -> float:
	var t := 0.0
	while t < limit and int(land.get("_acts")) > 0:
		await r.tree.physics_frame
		t += r.tree.root.get_physics_process_delta_time()
	await r.frames(2)
	return t


## M2 ate o passo de pendurar, com as 3 roupas no cesto (pelo evento; o cesto so recebe as pecas).
func _m2_at_hang(main: Ep01V3Main) -> void:
	var land := main.land
	await _notify_all(main, [&"piece_freed", &"piece_freed", &"piece_found"])
	for p: Node3D in land.get("_pieces"):
		p.set_meta(&"freed", true)
		p.reparent(land.get("_root"), true)
		p.global_transform = land.basket_xf(p)
		p.set_meta(&"in_basket", true)
	land.refresh()


## A: na pausa a acao congela (escalada e pendurar); ao despausar termina normalmente.
func _g19b_pause() -> void:
	var main := await _new_main(&"M2")
	var land := main.land
	var pico := _hero(main, &"climber")
	pico.teleport(land.points[&"ShedBase"] + Vector3(0, 0.05, 0))
	await r.frames(2)
	land.call("_on_spot", &"shed_climb", pico)
	for i in 12:
		await r.tree.physics_frame
	r.tree.paused = true
	var p0 := pico.global_position
	for i in 40:
		await r.tree.physics_frame
	var moved := pico.global_position.distance_to(p0)
	r.tree.paused = false
	await _until_free(land)
	r.check(moved < 0.001, "G19b A: pausado no meio da escalada o Pico nao se move (%.1f cm)" % (moved * 100.0))
	r.check(land.call("_on_shed") and _free_actor(pico) and not land.busy, "G19b A: despausado, a escalada termina no alto e solta o Pico")
	await _free(main)
	main = await _new_main(&"M2")
	land = main.land
	await _m2_at_hang(main)
	var rastro := _hero(main, &"tracker")
	rastro.teleport(main.floor_at(land.points[&"Basket"] + Vector3(0, 0, 0.55)) + Vector3(0, 0.05, 0))
	await r.frames(2)
	await _act(main, &"tracker", &"basket")
	var piece: Node3D = land.get("carried")
	land.call("_set_busy", true)
	land.call("_on_spot", &"hang", rastro)
	for i in 25:
		await r.tree.physics_frame
	r.tree.paused = true
	var a0 := rastro.global_position
	var c0 := piece.global_position if piece != null else Vector3.ZERO
	for i in 40:
		await r.tree.physics_frame
	var da := rastro.global_position.distance_to(a0)
	var dc := piece.global_position.distance_to(c0) if piece != null else INF
	r.tree.paused = false
	await _until_free(land)
	r.check(piece != null and da < 0.001 and dc < 0.001,
		"G19b A: pausado no meio do pendurar heroi e roupa ficam parados (%.1f / %.1f cm)" % [da * 100.0, dc * 100.0])
	r.check(piece != null and piece.get_meta(&"hung", false) and _free_actor(rastro),
		"G19b A: despausado, a roupa termina pendurada e o Rastro livre")
	land.call("_set_busy", false)
	await _free(main)


## B: a peca some no meio da acao (_put falha): a acao sai e solta busy e scripted.
func _g19b_exit_frees() -> void:
	var main := await _new_main(&"M2")
	var land := main.land
	await _m2_at_hang(main)
	var rastro := _hero(main, &"tracker")
	rastro.teleport(main.floor_at(land.points[&"Basket"] + Vector3(0, 0, 0.55)) + Vector3(0, 0.05, 0))
	await r.frames(2)
	await _act(main, &"tracker", &"basket")
	var piece: Node3D = land.get("carried")
	land.call("_on_spot", &"hang", rastro)
	for i in 3:
		await r.tree.physics_frame
	var had := piece != null
	if had:
		piece.free()   # peca invalida no meio da acao
	await _until_free(land, 6.0)
	r.check(had and int(land.get("_acts")) == 0 and not land.busy and not rastro.scripted,
		"G19b B: peca invalida no meio do pendurar: busy %s, scripted %s, acoes %d" % [land.busy, rastro.scripted, int(land.get("_acts"))])
	await _free(main)


func _ground_ok(main: Ep01V3Main, piece: Node3D, label: String) -> void:
	var po := PropOverlap.new()
	po.collect(main)
	for i in 3:
		await r.tree.physics_frame
	var id := "mission:" + String((main.land.get("_root") as Node).get_path_to(piece))
	var fl := po.floating(main.world.get_world_3d().direct_space_state, [id])
	var ov := po.overlaps([id])
	ov.append_array(po.structure_hits([id]))
	var found := false
	for p in po.props:
		if String(p["id"]) == id:
			found = true
	r.check(found and fl.is_empty() and ov.is_empty(), "%s: apoiada no chao sem atravessar nada (%s; %s %s)" % [label, id, fl, ov])
	po.free_probes()


## C (M2): so quem carrega poe no cesto; trocar de heroi faz o antigo pousar a roupa no chao; outro heroi a pega.
func _g19b_swap_m2() -> void:
	var main := await _new_main(&"M2")
	var land := main.land
	var pieces: Array = land.get("_pieces")
	var pico := main.actors[&"climber"] as MemberActor
	var rastro := main.actors[&"tracker"] as MemberActor
	pico.teleport(land.points[&"ShedBase"] + Vector3(0, 0.05, 0))
	await r.frames(2)
	await _act(main, &"climber", &"shed_climb")
	await _act(main, &"climber", &"shed_free")
	var shirt: Node3D = pieces[0]
	pico.teleport(main.floor_at(land.points[&"Basket"] + Vector3(0, 0, 1.3)) + Vector3(0, 0.05, 0))
	rastro.teleport(main.floor_at(land.points[&"Basket"] + Vector3(0, 0, 0.55)) + Vector3(0.4, 0.05, 0))
	await r.frames(2)
	r.check(land.get("carried") == shirt and land.get("carrier") == pico, "G19b C M2: o Pico esta com a camiseta na mao")
	land.call("_on_spot", &"basket", rastro)   # outro heroi age no cesto
	await _until_free(land, 3.0)
	r.check(land.get("carried") == shirt and not shirt.get_meta(&"in_basket", false) and main.current.step_progress == 0,
		"G19b C M2: outro heroi agindo no cesto nao tira a roupa da mao do Pico")
	var clips_before := (land.get("clip_log") as Array).size()
	_hero(main, &"tracker")   # troca de heroi com a roupa na mao do Pico
	await r.frames(2)
	await _until_free(land, 4.0)
	var laid := false
	for e: Dictionary in (land.get("clip_log") as Array).slice(clips_before):
		if e["member"] == &"climber" and e["clip"] == &"place_low":
			laid = true
	r.check(land.get("carried") == null and land.get("ground_piece") == shirt and laid and pico.hands == &"" and _free_actor(pico),
		"G19b C M2: na troca o Pico pousa a camiseta no chao com place_low (pousou %s)" % laid)
	r.check(shirt.get_parent() == land.get("_root") and shirt.global_position.distance_to(pico.global_position) < 0.9,
		"G19b C M2: a camiseta fica junto do Pico (%.2f m)" % shirt.global_position.distance_to(pico.global_position))
	await _ground_ok(main, shirt, "G19b C M2: camiseta pousada")
	await _act(main, &"tracker", &"pick_ground")
	r.check(land.get("carried") == shirt and land.get("carrier") == rastro and _passed_hand(land, shirt, &"tracker"),
		"G19b C M2: o Rastro pega a camiseta do chao")
	# de volta ao Pico (o passo e dele): o Rastro pousa de novo e o Pico pega e leva ao cesto
	_hero(main, &"climber")
	await r.frames(2)
	await _until_free(land, 4.0)
	r.check(land.get("ground_piece") == shirt and rastro.hands == &"", "G19b C M2: na volta o Rastro pousa a camiseta no chao")
	await _act(main, &"climber", &"pick_ground")
	pico.teleport(main.floor_at(land.points[&"Basket"] + Vector3(0, 0, 0.55)) + Vector3(0, 0.05, 0))
	await r.frames(2)
	await _act(main, &"climber", &"basket")
	r.check(shirt.get_meta(&"in_basket", false) and main.current.step_progress == 1,
		"G19b C M2: e quem carrega poe no cesto, e conta (%d)" % main.current.step_progress)
	await _free(main)


## C (M4): a caixinha erguida pela Leme vai ao chao na troca, apoiada; a Leme volta, pega e entrega.
func _g19b_swap_m4() -> void:
	var main := await _new_main(&"M4")
	var land := main.land
	main.current.notify(&"icons_read", &"tracker")
	await r.frames(3)
	if main.hud.handoff_open:
		main.hud._handoff_since = -100.0
		main.hud._confirm_handoff()
		await r.frames(3)
	var leme := _hero(main, &"pilot")
	var st: StringName = Ep01V3Land.CARGO_ORDER[0]
	land.call("_attach_cart", leme)
	var m := land._mk(st)
	leme.teleport(main.floor_at(m + (land.cart.global_position - m).normalized() * 1.5) + Vector3(0, 0.05, 0))
	await r.frames(40)
	var box: Node3D = land.call("cargo_box", st)
	await _act(main, &"pilot", StringName("deliver_" + String(st)))
	r.check(box != null and land.get("carried") == box, "G19b C M4: a Leme ergue a caixinha")
	var cargo := _cargo_state(land)
	_hero(main, &"tracker")
	await r.frames(2)
	await _until_free(land, 4.0)
	r.check(box != null and land.get("carried") == null and land.get("ground_piece") == box and leme.hands == &""
		and _free_actor(leme) and box.get_parent() == land.get("_root") and box.global_position.distance_to(leme.global_position) < 0.9,
		"G19b C M4: na troca a Leme pousa a caixinha no chao junto dela")
	var same := _cargo_state(land)
	r.check(same.size() == cargo.size(), "G19b C M4: o resto do carrinho fica (%d -> %d)" % [cargo.size(), same.size()])
	if box == null:
		await _free(main)
		return
	await _ground_ok(main, box, "G19b C M4: caixinha pousada")
	land.call("_on_spot", StringName("deliver_" + String(st)), main.actors[&"tracker"])
	await _until_free(land, 3.0)
	r.check(not box.get_meta(&"delivered", false), "G19b C M4: a entrega nao acontece sem a caixinha na mao")
	await _act(main, &"pilot", &"pick_ground")
	r.check(land.get("carried") == box and land.get("carrier") == leme, "G19b C M4: a Leme pega a caixinha do chao")
	land.call("_set_busy", true)
	await _act(main, &"pilot", StringName("deliver_" + String(st)))
	r.check(box.get_meta(&"delivered", false) and land.get("carried") == null and _free_actor(leme),
		"G19b C M4: e entrega na barraca")
	land.call("_set_busy", false)
	await _free(main)


## D: salvar e sair (pausado) no meio de uma acao com peca na mao; recarregar retoma a missao sem travar.
func _g19b_save_mid_action() -> void:
	var path := "user://test_ep01_v3_g19b.save.json"
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	Ep01V3Main.save_path = path
	var main := await _new_main(&"")
	var evs := {&"M0": [&"marker_reached"], &"M1": [&"paw_examined", &"boot_examined", &"paw_followed", &"paw_followed",
		&"paw_followed", &"paw_followed"]}
	for mid: StringName in [&"M0", &"M1"]:
		for ev: StringName in evs[mid]:
			if main.current != null and main.current.id == mid:
				for who: StringName in [&"tracker", &"climber", &"pilot"]:
					if main.current.notify(ev, who):
						break
		await r.frames(2)
	while main.land.busy:
		await r.tree.physics_frame
	await r.frames(3)
	if main.hud.handoff_open:
		main.hud._handoff_since = -100.0
		main.hud._confirm_handoff()
		await r.frames(3)
	main.hud.clear_speech()
	r.check(main.current != null and main.current.id == &"M2", "G19b D: chega ao M2 pelo jogo")
	var land := main.land
	var pico := main.actors[&"climber"] as MemberActor
	pico.teleport(land.points[&"ShedBase"] + Vector3(0, 0.05, 0))
	await r.frames(2)
	await _act(main, &"climber", &"shed_climb")
	await _act(main, &"climber", &"shed_free")
	pico.teleport(main.floor_at(land.points[&"Basket"] + Vector3(0, 0, 0.55)) + Vector3(0, 0.05, 0))
	await r.frames(2)
	land.call("_on_spot", &"basket", pico)
	for i in 6:
		await r.tree.physics_frame
	r.check(land.busy and land.get("carried") != null, "G19b D: no meio de por no cesto, com a roupa na mao")
	r.tree.paused = true
	r.check(MissionSave.save(path, Ep01V3Main.EPISODE_ID, main.missions), "G19b D: salva no meio da acao")
	await _free(main)
	var again := await _new_main(&"")
	land = again.land
	r.check(again.current != null and again.current.id == &"M2" and not land.busy and land.get("carried") == null,
		"G19b D: recarregar retoma no M2, sem acao presa nem peca na mao (%s, busy %s)" % [
		again.current.id if again.current else &"-", land.busy])
	var shirt: Node3D = (land.get("_pieces") as Array)[0]
	r.check(not shirt.get_meta(&"freed", false) and shirt.global_position.y > 1.2,
		"G19b D: a camiseta volta ao lugar de origem (telhado, y %.2f)" % shirt.global_position.y)
	pico = _hero(again, &"climber")
	pico.teleport(land.points[&"ShedBase"] + Vector3(0, 0.05, 0))
	await r.frames(2)
	await _act(again, &"climber", &"shed_climb")
	await _act(again, &"climber", &"shed_free")
	r.check(land.get("carried") == shirt and _free_actor(pico), "G19b D: depois de recarregar a missao segue (solta e leva a camiseta)")
	await _free(again)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	Ep01V3Main.save_path = ""
