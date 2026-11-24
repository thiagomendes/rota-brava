extends RefCounted
## AudioDirector (RB-04): pool de efeitos 2D/3D, passos sem repeticao, fala unica com cancelamento, fala ausente,
## motor por RPM, ducking manual, musica e ambiente. NAO comprova audicao (so estados e sinais).


func run(r) -> void:
	var d := AudioDirector.new()
	r.tree.root.add_child(d)
	await r.frames(2)
	d.rng.seed = 4242

	r.check(d.has_sound("sfx_horn_boat") and d.has_sound("theme_explore") and not d.has_sound("nao_existe"), "director: catalogo de sons carrega")
	r.check(d.caption_key("sfx_horn_boat") != "" and Loc.has_key(d.caption_key("sfx_horn_boat")) and d.caption_key("sfx_ui_move") == "", "director: efeito essencial tem legenda visual (chave de Loc)")

	# efeitos 2D / 3D
	var p2: Node = d.play_sfx("sfx_ui_confirm")
	r.check(p2 is AudioStreamPlayer and not (p2 is AudioStreamPlayer3D) and (p2 as AudioStreamPlayer).playing and (p2 as AudioStreamPlayer).bus == &"Efeitos", "director: play_sfx sem posicao usa AudioStreamPlayer 2D no bus Efeitos")
	var pos := Vector3(30.0, 0.0, -40.0)
	var p3: Node = d.play_sfx("sfx_horn_boat", pos, -3.0)
	r.check(p3 is AudioStreamPlayer3D and (p3 as AudioStreamPlayer3D).playing and (p3 as AudioStreamPlayer3D).position.is_equal_approx(pos), "director: play_sfx com posicao cria AudioStreamPlayer3D na posicao")
	var p3b: Node = d.play_sfx("sfx_horn_boat", pos)
	r.check(p3b != null and p3b != p3 and (p3 as AudioStreamPlayer3D).playing and (p3b as AudioStreamPlayer3D).playing, "director: mesmo som duas vezes nao corta o primeiro (pool)")
	r.check(d.play_sfx("nao_existe") == null, "director: som desconhecido devolve null sem erro")

	# passos
	var names: Dictionary = {}
	var prev := ""
	var repeated := false
	for i in 50:
		var n := d.play_footstep(randf_range(0.5, 4.0))
		if n == prev:
			repeated = true
		prev = n
		names[n] = true
	r.check(not repeated, "director: 50 passos nunca repetem a variacao anterior")
	r.check(names.size() == 6, "director: os 6 passos aparecem em 50 chamadas (%d)" % names.size())
	r.check(d.play_footstep(0.0) == "", "director: passo com velocidade 0 nao toca")
	d.stop_all()

	# fala
	var cancelled: Array[String] = []
	var finished: Array[String] = []
	d.voice_cancelled.connect(func(id: String) -> void: cancelled.append(id))
	d.voice_finished.connect(func(id: String) -> void: finished.append(id))
	var warn_before := VoiceCatalog.missing.size()
	var none := d.play_voice("nao.existe.fala.director")
	r.check(none == 0.0 and cancelled.is_empty() and not d.is_voice_playing(), "director: fala inexistente devolve 0.0, sem erro nem cancelamento")
	r.check(VoiceCatalog.missing.size() == warn_before + 1, "director: fala ausente fica registrada (legenda segue com o chamador)")
	var dur_a := d.play_voice("ep01.dock.tracker.deduction")
	r.check(dur_a > 1.0 and d.is_voice_playing() and d.current_voice_id == "ep01.dock.tracker.deduction", "director: play_voice devolve a duracao (%.2f s)" % dur_a)
	var dur_b := d.play_voice("ep01.dock.tracker.ask_destination")
	r.check(dur_b > 0.5 and cancelled == ["ep01.dock.tracker.deduction"] and d.current_voice_id == "ep01.dock.tracker.ask_destination", "director: nova fala cancela a anterior (voice_cancelled)")
	var playing_voices := 0
	await r.frames(1)
	for c in d.get_children():
		if c is AudioStreamPlayer and (c as AudioStreamPlayer).bus == &"Voz" and (c as AudioStreamPlayer).playing and (c as AudioStreamPlayer).volume_db > -20.0:
			playing_voices += 1
	r.check(playing_voices == 1, "director: so uma fala audivel por vez (%d)" % playing_voices)
	# fim natural da fala (tempo real; falha se o sinal nunca vier)
	var waited := 0.0
	while finished.is_empty() and waited < dur_b + 3.0:
		await r.tree.create_timer(0.25).timeout
		waited += 0.25
	r.check(finished == ["ep01.dock.tracker.ask_destination"] and not d.is_voice_playing(), "director: voice_finished ao terminar (%.2f s esperados, %.2f s)" % [dur_b, waited])
	r.check(cancelled.size() == 1, "director: fala terminada normalmente nao emite voice_cancelled")

	# motor
	d.set_engine_rpm(0.0)
	var p_lo := d.engine_player.pitch_scale
	d.set_engine_rpm(1.0)
	var p_hi := d.engine_player.pitch_scale
	r.check(p_hi > p_lo + 0.5 and absf(p_lo - AudioDirector.ENGINE_PITCH_MIN) < 0.001 and d.engine_player.playing, "director: set_engine_rpm muda pitch_scale (%.2f -> %.2f) e toca o loop" % [p_lo, p_hi])
	var eng := d.engine_player.stream as AudioStreamWAV
	r.check(eng != null and eng.loop_mode == AudioStreamWAV.LOOP_FORWARD and eng.loop_end > 0, "director: loop do motor configurado em codigo")
	d.set_engine_rpm(-1.0)
	r.check(not d.engine_player.playing, "director: motor para com rpm < 0")

	# musica, ambiente, ducking
	d.play_music("theme_explore", 0.0)
	r.check(d.current_music == "theme_explore", "director: play_music inicia o tema")
	d.play_music("theme_explore_low", 0.2)
	r.check(d.current_music == "theme_explore_low", "director: play_music troca de tema com crossfade")
	d.start_ambience(0.0)
	r.check(d.is_ambience_playing(), "director: start_ambience toca as camadas")
	var idx := AudioServer.get_bus_index(&"Musica")
	var base := AudioServer.get_bus_volume_db(idx)
	d.duck_music(true)
	r.check(d.ducked and is_equal_approx(d.music_bus_target_db(), base + AudioDirector.DUCK_DB), "director: duck_music(true) fixa o alvo em -6 dB")
	await r.tree.create_timer(0.6).timeout
	r.check(is_equal_approx(AudioServer.get_bus_volume_db(idx), base + AudioDirector.DUCK_DB), "director: bus Musica chega ao alvo (%.2f dB)" % AudioServer.get_bus_volume_db(idx))
	d.duck_music(false)
	await r.tree.create_timer(1.0).timeout
	r.check(is_equal_approx(AudioServer.get_bus_volume_db(idx), base), "director: bus Musica volta ao nivel (%.2f dB)" % AudioServer.get_bus_volume_db(idx))
	d.stop_all()
	r.check(not d.is_ambience_playing() and d.current_music == "" and not d.is_voice_playing(), "director: stop_all silencia tudo")
	d.queue_free()
	await r.frames(2)
