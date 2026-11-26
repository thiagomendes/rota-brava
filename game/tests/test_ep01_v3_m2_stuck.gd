extends RefCounted
## RB-R1 (instabilidade do `cutscene`): trava no M2 `free_pieces`. Depois de soltar a peca do galpao, o salto de volta
## ao chao pode ser interrompido (hop_aborted, "oops"). A cadeia chama `refresh()` com o Pico ainda no alto (y > 1,2,
## perto do topo), entao `tree_climb` fica desligado; ao cair no chao nada mais chamava `refresh()` e nenhum ponto
## ficava ligado: sem "Examinar", sem alvo de ajuda. Uma crianca ficaria presa do mesmo jeito.
## Mede estado (pontos ligados, alvo da ajuda); nao comprova render.

var r


func run(runner) -> void:
	r = runner
	Ep01V3Main.start_mission = &"M2"
	Ep01V3Main.save_path = ""
	var main := (load("res://episodes/ep01/v3/ep01_v3_main.tscn") as PackedScene).instantiate() as Ep01V3Main
	r.tree.root.add_child(main)
	r.tree.current_scene = main
	await r.frames(3)
	if main.hud.handoff_open:
		main.hud._handoff_since = -100.0
		main.hud._confirm_handoff()
		await r.frames(3)
	main.hud.clear_speech()
	main.guide.skip_look()
	var land := main.land
	var climber := main.actors[&"climber"] as MemberActor
	r.check(main.current.id == &"M2" and main.current.current_step().get("id", &"") == &"free_pieces", "m2: passo free_pieces")
	r.check(main.controlled_node == climber, "m2: Pico em controle")
	# Peca do galpao ja solta; o Pico ainda no alto quando a cadeia de saltos termina (salto abortado).
	land._pieces[0].set_meta(&"freed", true)
	climber.set_physics_process(false)
	climber.global_position = land._mk(&"M2_ShedTop") + Vector3(0, 0.05, 0)
	land.refresh()
	r.check(main.help_target() == null, "m2: no alto do galpao com a peca solta nenhum ponto liga (esperado)")
	# Cai no chao: o passo precisa religar o caminho da arvore sozinho.
	climber.global_position = land.points[&"ShedBase"] + Vector3(0, 0.04, 0)
	climber.set_physics_process(true)
	await r.frames(10)
	var t := main.help_target()
	r.check(t != null and t == land.spots.get(&"tree_climb"),
		"m2: de volta ao chao sem refresh externo, 'subir na arvore' religa (alvo %s)" % (t.name if t else "-"))
	main.queue_free()
	await r.frames(2)
	r.tree.current_scene = null
	Ep01V3Main.start_mission = &""
