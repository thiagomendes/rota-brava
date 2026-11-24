extends RefCounted
## RB-R1 tarefa 6: as opcoes do jogador valem dentro do episodio (volumes por bus, legenda, movimento reduzido,
## assistencia de pilotagem) e podem ser abertas na pausa. Nao grava user://options.cfg (save = false) e restaura tudo.

var r


func _start(state: StringName) -> Ep01Main:
	Ep01Main.carry_completed = []
	Ep01Main.start_state = state
	var m := (load("res://episodes/ep01/ep01_main.tscn") as PackedScene).instantiate() as Ep01Main
	r.tree.root.add_child(m)
	r.tree.current_scene = m
	await r.frames(3)
	Ep01Main.start_state = &""
	return m


func _stop(m: Ep01Main) -> void:
	m.queue_free()
	await r.frames(2)
	r.tree.current_scene = null


func run(runner) -> void:
	r = runner
	var saved := {}
	for b in Options.BUSES:
		saved[b] = Options.get_value("audio", b)
	for k in ["subtitle_size", "reduced_motion", "steering_assist"]:
		saved[k] = Options.get_value("access", k)
	var old_override := Options.motion_override
	Options.motion_override = -1

	# Volume salvo vale ao abrir o episodio direto (sem tela-titulo).
	Options.set_value("audio", "Musica", 0.25, false)
	var m := await _start(&"docking")
	var idx := AudioServer.get_bus_index("Musica")
	var duck := AudioDirector.DUCK_DB if (m.audio != null and m.audio.ducked) else 0.0
	await r.tree.create_timer(1.0).timeout   # deixa o ducking (0,3 s) terminar
	duck = AudioDirector.DUCK_DB if (m.audio != null and m.audio.ducked) else 0.0
	r.check(absf(AudioServer.get_bus_volume_db(idx) - (linear_to_db(0.25) + duck)) < 0.2,
		"volume da musica salvo vale no episodio (%.1f dB, ducking %.0f)" % [AudioServer.get_bus_volume_db(idx), duck])
	# Mudar o volume no meio de uma fala nao se perde quando a fala acaba (bug corrigido no ducking).
	if m.audio != null:
		m.audio.duck_music(true)
		Options.set_value("audio", "Musica", 0.5, false)
		m.audio.duck_music(false)
		await r.tree.create_timer(1.2).timeout
		r.check(absf(AudioServer.get_bus_volume_db(idx) - linear_to_db(0.5)) < 0.2,
			"volume novo da musica sobrevive ao fim do ducking (%.1f dB)" % AudioServer.get_bus_volume_db(idx))

	# Movimento reduzido muda a camera na hora.
	Options.set_value("access", "reduced_motion", true, false)
	r.check(m.camera_rig.reduced_motion, "movimento reduzido liga na camera na hora")
	Options.set_value("access", "reduced_motion", false, false)
	r.check(not m.camera_rig.reduced_motion, "e desliga na hora")

	# Assistencia de pilotagem: perto do alvo ajuda; desligada, o barco nao se alinha sozinho.
	var st := m.stages[&"docking"] as DockingStage
	var near := Ep01Layout.DOCKING_TARGET_POS + Vector3(0, 0, -3.0)
	Options.set_value("access", "steering_assist", true, false)
	r.check(st.assist_for(near) > 0.3, "com assistencia ligada o barco recebe ajuda perto do alvo")
	Options.set_value("access", "steering_assist", false, false)
	r.check(st.assist_for(near) == 0.0, "com assistencia desligada nao ha ajuda")

	# Legenda grande na fala seguinte.
	Options.set_value("access", "subtitle_size", 2, false)
	r.check(is_equal_approx(Options.subtitle_scale(), 1.25), "tamanho de legenda grande = 1,25x")

	# Opcoes na pausa: abre, foca, volta.
	m.hud.open_pause()
	await r.frames(1)
	var btn := m.hud.find_child("PauseOptions", true, false) as Button
	r.check(btn != null and btn.visible, "pausa tem o botao Opcoes")
	btn.pressed.emit()
	await r.frames(2)
	r.check(m.hud.options_open and m.hud.options_panel.is_visible_in_tree(), "Opcoes abre o painel dentro do jogo")
	r.check(m.hud.options_panel.back_button.has_focus(), "foco inicial no Voltar do painel")
	m.hud.options_panel.back_requested.emit()
	await r.frames(1)
	r.check(not m.hud.options_open and btn.has_focus(), "Voltar fecha o painel e devolve o foco a pausa")
	m.hud.close_pause()
	await _stop(m)

	# Restaura (sem gravar arquivo).
	for b in Options.BUSES:
		Options.set_value("audio", b, saved[b], false)
	for k in ["subtitle_size", "reduced_motion", "steering_assist"]:
		Options.set_value("access", k, saved[k], false)
	Options.motion_override = old_override
