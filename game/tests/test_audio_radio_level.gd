extends RefCounted
## G22b: a fala de radio (Farol 7) sai da Godot com a mesma loudness das outras vozes (+-1 LU). Renderiza de verdade
## (driver Dummy do --headless, AudioEffectCapture no Master) o mesmo take pelo caminho de radio do jogo (play_line:
## cliques, bus Radio, chiado) e direto no bus Voz, e uma fala comum de outra personagem. Com os parametros
## anteriores ao G22b (bus 0 dB, make-up +2 dB) a diferenca passa de 1 LU: o teste prova que eles falham.
## Mede nivel; NAO comprova audicao.

const RADIO_ID := "ep01.radio.v3_m6.board"
const COMMON_ID := "ep01.bay.pilot.call_climber"
const TOL_LU := 1.0


func _render_line(r, d: AudioDirector, cap: AudioEffectCapture, id: String) -> PackedVector2Array:
	LoudnessProbe.drain(cap)
	var info := d.play_line(VoiceCatalog.V3_PREFIX + id)
	var fr: PackedVector2Array = (await LoudnessProbe.collect(r.tree, [cap], float(info.get("duration", 0.0)) + 0.1))[0]
	d.stop_voice()
	await r.tree.create_timer(0.3).timeout
	return fr


func run(r) -> void:
	VoiceCatalog.reload()
	var d := AudioDirector.new()
	r.tree.root.add_child(d)
	await r.frames(2)
	r.check(RadioBus.BUS_GAIN_DB == 10.0 and RadioBus.COMP_GAIN_DB == 14.0, "radio nivel: bus Radio +10 dB e make-up +14 dB (G22b)")
	r.check(VoiceCatalog.v3_lines().has(RADIO_ID) and VoiceCatalog.v3_lines().has(COMMON_ID), "radio nivel: takes de medida existem")
	var cap := LoudnessProbe.attach(&"Master")

	# referencia: o mesmo take direto no bus Voz
	var p := AudioStreamPlayer.new()
	p.bus = &"Voz"
	p.stream = VoiceCatalog.stream_for(VoiceCatalog.V3_PREFIX + RADIO_ID)
	r.tree.root.add_child(p)
	await r.frames(1)
	LoudnessProbe.drain(cap)
	p.play()
	var ref: PackedVector2Array = (await LoudnessProbe.collect(r.tree, [cap], p.stream.get_length() + 0.1))[0]
	p.queue_free()
	await r.tree.create_timer(0.3).timeout
	var ref_l := LoudnessProbe.lufs(ref)
	var common_l := LoudnessProbe.lufs(await _render_line(r, d, cap, COMMON_ID))
	r.check(ref_l > -40.0 and common_l > -40.0, "radio nivel: a Godot mixou audio no headless (voz %.1f LUFS, comum %.1f LUFS)" % [ref_l, common_l])

	# parametros atuais
	RadioBus.apply(RadioBus.BUS_GAIN_DB, RadioBus.COMP_GAIN_DB)
	var now_l := LoudnessProbe.lufs(await _render_line(r, d, cap, RADIO_ID))
	r.check(absf(now_l - ref_l) <= TOL_LU, "radio nivel: radio %.1f LUFS x mesmo take na Voz %.1f (dif %.2f LU, tol %.0f)" % [now_l, ref_l, now_l - ref_l, TOL_LU])
	r.check(absf(now_l - common_l) <= TOL_LU + 0.5, "radio nivel: radio x fala comum %s %.1f LUFS (dif %.2f LU; takes diferentes, folga 0,5)" % [COMMON_ID, common_l, now_l - common_l])

	# chiado abaixo da voz
	LoudnessProbe.drain(cap)
	d._radio_hiss(true)
	var hiss_l := LoudnessProbe.lufs((await LoudnessProbe.collect(r.tree, [cap], 1.0))[0])
	d._radio_hiss(false)
	r.check(hiss_l < now_l - 20.0, "radio nivel: chiado %.1f LUFS, mais de 20 LU abaixo da voz" % hiss_l)

	# parametros anteriores (G20): fora da tolerancia
	RadioBus.apply(RadioBus.OLD_BUS_GAIN_DB, RadioBus.OLD_COMP_GAIN_DB)
	var old_l := LoudnessProbe.lufs(await _render_line(r, d, cap, RADIO_ID))
	RadioBus.apply(RadioBus.BUS_GAIN_DB, RadioBus.COMP_GAIN_DB)
	r.check(old_l < ref_l - TOL_LU, "radio nivel: parametros antigos (bus 0, make-up +2) ficam fora: %.1f LUFS, dif %.2f LU" % [old_l, old_l - ref_l])

	LoudnessProbe.detach(&"Master", cap)
	d.queue_free()
	await r.frames(2)
