extends RefCounted
## Fundacao do episodio (RB-02): abertura, troca de integrante com confirmacao, acao contextual e pausa.

var r
var _hits: int = 0


func _press(action: StringName) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	await r.frames()
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)
	await r.frames()


func run(runner) -> void:
	r = runner
	Ep01Main.carry_completed = []
	var main := (load("res://episodes/ep01/ep01_main.tscn") as PackedScene).instantiate() as Ep01Main
	r.tree.root.add_child(main)
	r.tree.current_scene = main
	await r.frames(3)

	r.check(main.director.state == &"arrival", "o episodio comeca em arrival")
	r.check(main.controlled_node == null, "ninguem controla durante a abertura")
	r.check(main.hud.is_speaking(), "a buzina aparece como legenda (equivalente visual)")
	r.check(main.boat.get_meta(Blocks.PROVISIONAL, false) == true, "o barco esta marcado como provisorio")

	(main.stages[&"arrival"] as ArrivalStage).skip_intro()
	r.check(main.director.state == &"dock_investigation", "pular a abertura leva a dock_investigation")
	r.check(main.director.active_member == &"tracker", "Rastro fica ativo")
	await r.tree.create_timer(1.2).timeout
	r.check(main.hud.handoff_open, "a troca abre o painel de confirmacao")
	r.check(main.controlled_node == null, "o controle espera a confirmacao")

	await _press(&"interact")
	r.check(main.hud.handoff_open and main.controlled_node == null,
		"uma pressao imediata nao confirma (protecao contra pressao mantida)")
	await r.tree.create_timer(0.6).timeout
	await _press(&"interact")
	r.check(not main.hud.handoff_open and main.posing and main.controlled_node == null,
		"confirmar abre a pose de equipe; o controle ainda nao voltou")
	await r.tree.create_timer(Ep01Main.TEAM_POSE_SECONDS + 0.2).timeout
	r.check(not main.posing and main.controlled_node == main.actors[&"tracker"],
		"confirmar passa o controle a Rastro")
	r.check((main.actors[&"tracker"] as MemberActor).controlled, "Rastro responde a entrada")
	r.check(not (main.actors[&"pilot"] as MemberActor).controlled, "os outros integrantes nao respondem")

	# Acao contextual: aparece perto, some ao afastar, uma pressao gera uma interacao.
	var tracker := main.actors[&"tracker"] as MemberActor
	tracker.teleport(Vector3(0, 0, 0))
	var it := Ep01Interactable.new()
	it.action_id = &"test"
	it.label_key = "ui.action.examine"
	it.icon = &"paw"
	it.member = &"tracker"
	it.radius = 2.0
	it.triggered.connect(func(_a: Node3D) -> void: _hits += 1)
	main.world.add_child(it)
	it.global_position = Vector3(1, 0, 0)
	await r.frames(2)
	r.check(main.hud.prompt_visible() and main.hud.prompt_text() == Loc.t("ui.action.examine"),
		"perto do alvo aparece 'Examinar'")
	await _press(&"interact")
	r.check(_hits == 1, "uma pressao gera exatamente uma interacao")
	it.global_position = Vector3(30, 0, 0)
	await r.frames(2)
	r.check(not main.hud.prompt_visible(), "ao afastar, a acao some")
	await _press(&"interact")
	r.check(_hits == 1, "longe do alvo, a pressao nao interage")
	it.global_position = Vector3(1, 0, 0)
	it.member = &"pilot"
	await r.frames(2)
	r.check(not main.hud.prompt_visible(), "alvo de outro integrante nao aparece para o ativo")
	it.queue_free()

	# Pausa durante a troca de integrante: interact nao pode confirmar com o jogo pausado (defeito D1 da revisao).
	var swap := (load("res://episodes/ep01/ep01_main.tscn") as PackedScene).instantiate() as Ep01Main
	main.queue_free()
	await r.frames(2)
	Ep01Main.start_state = &""
	r.tree.root.add_child(swap)
	r.tree.current_scene = swap
	await r.frames(3)
	(swap.stages[&"arrival"] as ArrivalStage).skip_intro()
	await r.tree.create_timer(1.2).timeout
	r.check(swap.hud.handoff_open, "D1: a troca esta aberta antes de pausar")
	await _press(&"pause")
	r.check(swap.hud.pause_open and swap.hud.handoff_open, "D1: pausa abre por cima da troca")
	await r.tree.create_timer(0.6).timeout
	await _press(&"interact")
	r.check(swap.hud.handoff_open and swap.controlled_node == null and r.tree.paused,
		"D1: interact com a pausa aberta nao confirma a troca")
	await _press(&"pause")
	r.check(not r.tree.paused and swap.hud.handoff_open, "D1: retomar mantem a troca pendente")
	await r.tree.create_timer(0.6).timeout
	await _press(&"interact")
	await r.tree.create_timer(Ep01Main.TEAM_POSE_SECONDS + 0.2).timeout
	r.check(swap.controlled_node == swap.actors[&"tracker"], "D1: depois de retomar, interact confirma")
	r.tree.paused = false
	swap.queue_free()
	await r.frames(2)
	r.tree.current_scene = null

	# Pausa
	main = (load("res://episodes/ep01/ep01_main.tscn") as PackedScene).instantiate() as Ep01Main
	r.tree.root.add_child(main)
	r.tree.current_scene = main
	await r.frames(3)
	await _press(&"pause")
	r.check(r.tree.paused and main.hud.pause_open, "Esc pausa o jogo")
	await _press(&"pause")
	r.check(not r.tree.paused and not main.hud.pause_open, "Esc de novo retoma")

	r.tree.paused = false
	main.queue_free()
	await r.frames(2)
	r.tree.current_scene = null

	# Inicio direto em cada estado (atalho usado por testes e demos dos estagios).
	for state: StringName in [&"dock_investigation", &"river_search", &"island_crossing", &"docking", &"return_trip"]:
		Ep01Main.start_state = state
		var m := (load("res://episodes/ep01/ep01_main.tscn") as PackedScene).instantiate() as Ep01Main
		r.tree.root.add_child(m)
		r.tree.current_scene = m
		await r.frames(3)
		var expected: StringName = m.director.ACTIVE_BY_STATE[state]
		r.check(m.director.state == state, "start_at: diretor em %s" % state)
		r.check(m.controlled_node != null and m.director.active_member == expected,
			"start_at: %s controla em %s" % [expected, state])
		m.queue_free()
		await r.frames(2)
		r.tree.current_scene = null
	Ep01Main.start_state = &""