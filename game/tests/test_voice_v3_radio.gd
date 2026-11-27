extends RefCounted
## G20: radio do Farol 7 (walkie-talkie). Bus Radio filho de Voz com filtros/saturacao/compressor; fala de radio
## toca clique de abrir, voz no bus Radio com chiado e clique de fechar; outras falas ficam na Voz; fala de radio
## sem voz toca so os cliques; Hud.line_seconds soma os cliques. NAO comprova audicao (so estados e roteamento).


func _first_v3(radio: bool) -> String:
	for k in VoiceCatalog.v3_lines():
		var e: Dictionary = VoiceCatalog.v3_lines()[k]
		if (str(e.get("speaker", "")) == "radio") == radio and ResourceLoader.exists(str(e.get("file", ""))):
			return str(k)
	return ""


func run(r) -> void:
	VoiceCatalog.reload()
	var d := AudioDirector.new()
	r.tree.root.add_child(d)
	await r.frames(2)

	# bus
	var idx := AudioServer.get_bus_index(&"Radio")
	r.check(idx >= 0 and AudioServer.get_bus_send(idx) == &"Voz", "radio: bus Radio existe e manda para Voz")
	var kinds: Array[String] = []
	for i in AudioServer.get_bus_effect_count(idx):
		kinds.append(AudioServer.get_bus_effect(idx, i).get_class())
	r.check(kinds == ["AudioEffectHighPassFilter", "AudioEffectLowPassFilter", "AudioEffectDistortion", "AudioEffectCompressor"], "radio: cadeia passa-altas, passa-baixas, distorcao, compressor (%s)" % ", ".join(kinds))
	var hp := AudioServer.get_bus_effect(idx, 0) as AudioEffectHighPassFilter
	var lp := AudioServer.get_bus_effect(idx, 1) as AudioEffectLowPassFilter
	var dist := AudioServer.get_bus_effect(idx, 2) as AudioEffectDistortion
	r.check(hp.cutoff_hz == 300.0 and lp.cutoff_hz == 3400.0 and dist.mode == AudioEffectDistortion.MODE_ATAN and dist.drive <= 0.3, "radio: banda 300-3400 Hz e saturacao suave e leve")
	r.check(RadioBus.ensure() == idx and AudioServer.get_bus_index(&"Radio") == idx, "radio: ensure() e idempotente (nao duplica o bus)")
	for f in [AudioDirector.RADIO_OPEN, AudioDirector.RADIO_CLOSE, AudioDirector.RADIO_HISS]:
		r.check(ResourceLoader.exists(f) and load(f) is AudioStream, "radio: som sintetizado existe (%s)" % f)

	# volume de voz controla o radio (Radio -> Voz)
	var voz := AudioServer.get_bus_index(&"Voz")
	var old_db := AudioServer.get_bus_volume_db(voz)
	var old_mute := AudioServer.is_bus_mute(voz)
	Options.apply_bus("Voz", 0.0)
	r.check(AudioServer.is_bus_mute(voz) and AudioServer.get_bus_send(idx) == &"Voz" and AudioServer.get_bus_volume_db(idx) == 0.0, "radio: voz em 0 nas Opcoes silencia o radio (bus Radio passa pela Voz)")
	AudioServer.set_bus_volume_db(voz, old_db)
	AudioServer.set_bus_mute(voz, old_mute)

	# fala de radio com voz
	var rk := _first_v3(true)
	r.check(rk != "", "radio: ha take v3 do Farol 7 (%s)" % rk)
	d.radio_clicks.clear()
	var info := d.play_line(VoiceCatalog.V3_PREFIX + rk)
	var vp: AudioStreamPlayer = d._voice_players[d._voice_cur]
	r.check(bool(info.get("radio", false)) and vp.bus == &"Radio", "radio: fala do Farol 7 vai para o bus Radio")
	r.check(absf(float(info["duration"]) - float(info["voice_s"]) - AudioDirector.RADIO_EXTRA_S) < 0.001, "radio: duracao devolvida inclui os cliques (%.2f s = voz %.2f + %.2f)" % [float(info["duration"]), float(info["voice_s"]), AudioDirector.RADIO_EXTRA_S])
	r.check(d.radio_clicks == [&"open"] and not vp.playing and d.is_radio_hiss_playing(), "radio: clique de abrir antes da voz, chiado junto")
	await r.tree.create_timer(AudioDirector.RADIO_OPEN_S + 0.1).timeout
	r.check(vp.playing and vp.bus == &"Radio", "radio: a voz entra depois do clique de abrir")
	d.stop_voice()
	await r.frames(2)
	r.check(d.radio_clicks == [&"open", &"close"] and not d.is_radio_hiss_playing(), "radio: clique de fechar no fim e chiado para (%s)" % str(d.radio_clicks))

	# fim natural tambem fecha
	d.radio_clicks.clear()
	d.play_line(VoiceCatalog.V3_PREFIX + rk)
	d.voice_finished.emit(VoiceCatalog.V3_PREFIX + rk)  # simula o fim do take
	r.check(d.radio_clicks == [&"open", &"close"], "radio: fim da fala toca o clique de fechar")
	d.stop_voice()
	await r.frames(2)

	# fala comum
	var nk := _first_v3(false)
	d.radio_clicks.clear()
	var ninfo := d.play_line(VoiceCatalog.V3_PREFIX + nk)
	vp = d._voice_players[d._voice_cur]
	r.check(not bool(ninfo.get("radio", true)) and vp.bus == &"Voz" and vp.playing and d.radio_clicks.is_empty() and not d.is_radio_hiss_playing(), "radio: fala comum (%s) fica no bus Voz, sem cliques" % nk)
	d.stop_voice()
	await r.frames(2)

	# radio sem voz: so os cliques, sem erro
	d.radio_clicks.clear()
	var silent := d.play_line("ep01.radio.g20.sem_take")
	r.check(float(silent["duration"]) == 0.0 and not d.is_voice_playing() and d.radio_clicks == [&"open"], "radio: fala de radio sem voz devolve 0 e toca o clique de abrir")
	await r.tree.create_timer(AudioDirector.RADIO_OPEN_S + 0.1).timeout
	r.check(d.radio_clicks == [&"open", &"close"] and not d.is_radio_hiss_playing(), "radio: sem voz, depois so o clique de fechar (sem chiado)")

	# tempo de legenda para cutscenes
	var key := "ep01.radio.intro.hello"
	var base := Hud.line_seconds_for_text(Loc.t(key), 3.0)
	r.check(absf(Hud.line_seconds(key, 3.0) - base - AudioDirector.RADIO_EXTRA_S) < 0.001 and Hud.radio_extra_seconds(key) == AudioDirector.RADIO_EXTRA_S, "radio: Hud.line_seconds soma os cliques numa fala de radio com voz")
	r.check(Hud.radio_extra_seconds("ep01.narrator.intro.village") == 0.0 and Hud.line_seconds("ep01.narrator.intro.village", 3.0) == Hud.line_seconds_for_text(Loc.t("ep01.narrator.intro.village"), 3.0), "radio: fala comum nao ganha tempo extra")
	d.queue_free()
	await r.frames(1)
