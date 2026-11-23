extends RefCounted
## Ponta a ponta (RB-02): o bot joga o episodio inteiro com entrada real, em tempo acelerado, e o diretor chega a `complete`.
## Nao comprova render, som, UX nem desempenho; prova que o caminho completo e jogavel pelas intencoes da Input Map.

const TIME_SCALE := 8.0
const MAX_FRAMES := 60000

var r


func run(runner) -> void:
	r = runner
	Ep01Main.carry_completed = []
	Ep01Main.start_state = &""
	var main := (load("res://episodes/ep01/ep01_main.tscn") as PackedScene).instantiate() as Ep01Main
	r.tree.root.add_child(main)
	r.tree.current_scene = main
	await r.frames(3)

	var visited: Array[StringName] = []
	main.director.state_changed.connect(func(_old: StringName, new: StringName) -> void: visited.append(new))
	var bot := Ep01DemoBot.new()
	bot.main = main
	bot.timeout_seconds = 500.0
	bot.log_steps = true
	main.add_child(bot)
	var result := {"done": false, "ok": false}
	bot.finished.connect(func(ok: bool) -> void:
		result["done"] = true
		result["ok"] = ok)

	Engine.time_scale = TIME_SCALE
	var frames := 0
	while not result["done"] and frames < MAX_FRAMES:
		await r.tree.process_frame
		frames += 1
	Engine.time_scale = 1.0

	r.check(result["done"], "o bot terminou dentro do limite (estado final %s, %d quadros)" % [main.director.state, frames])
	r.check(bool(result["ok"]), "o bot concluiu o episodio com entrada real")
	r.check(main.director.state == &"complete", "o diretor chegou a complete")
	r.check(visited == [&"dock_investigation", &"river_search", &"island_crossing", &"docking", &"return_trip", &"complete"],
		"todas as etapas foram percorridas em ordem %s" % str(visited))
	r.check(main.director.completed_episodes == [&"ep01"], "a conclusao foi registrada uma vez")
	r.check(main.director.line_fixed, "a linha ficou fixada")
	r.check(main.hud.complete_open, "a tela de conclusao foi exibida")

	main.queue_free()
	await r.frames(2)
	r.tree.current_scene = null
	r.tree.paused = false
