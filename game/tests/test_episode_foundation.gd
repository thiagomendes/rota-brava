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
	r.check(not main.hud.handoff_open and main.controlled_node == main.actors[&"tracker"],
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

	# Pausa
	await _press(&"pause")
	r.check(r.tree.paused and main.hud.pause_open, "Esc pausa o jogo")
	await _press(&"pause")
	r.check(not r.tree.paused and not main.hud.pause_open, "Esc de novo retoma")

	r.tree.paused = false
	main.queue_free()
	await r.frames(2)
	r.tree.current_scene = null
