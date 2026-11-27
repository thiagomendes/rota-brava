extends SceneTree
## G22b: renderiza com a PROPRIA Godot (driver Dummy do --headless, tempo real) falas de radio e falas comuns,
## capturando a saida do Master (AudioEffectCapture), e grava WAV + JSON com LUFS em captures/g22b/<tag>/.
## Uso: tools/godot.sh --headless --path game --script res://tests/capture_g22b.gd -- --tag=antes --bus-db=0 --comp-gain=2
## Sem --bus-db/--comp-gain: usa as constantes atuais de RadioBus. Nada e ouvido: so medidas.

const RADIO_IDS := ["ep01.radio.intro.hello", "ep01.radio.v3_m1.trail", "ep01.radio.v3_m5.fish"]
const COMMON_IDS := ["ep01.intro.pilot.hello", "ep01.narrator.intro.call", "ep01.street.pilot.see_vane"]
const MUSIC := "music_v3_village"

var _d: AudioDirector
var _out := ""
var _rep := {}


func _arg(name: String, def: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + name + "="):
			return a.get_slice("=", 1)
	return def


func _init() -> void:
	_go.call_deferred()


func _go() -> void:
	var tag := _arg("tag", "atual")
	_out = ProjectSettings.globalize_path("res://").path_join("../captures/g22b").simplify_path().path_join(tag)
	DirAccess.make_dir_recursive_absolute(_out)
	VoiceCatalog.reload()
	_d = AudioDirector.new()
	root.add_child(_d)
	await process_frame
	if _arg("hiss-db", "") != "":
		_d._ensure_radio_players()
		_d._hiss_player.volume_db = float(_arg("hiss-db", "0"))
		_d._radio_player.volume_db = float(_arg("click-db", "0"))
		_d._radio_close_player.volume_db = float(_arg("click-db", "0"))
	var bus_db := float(_arg("bus-db", str(RadioBus.BUS_GAIN_DB)))
	var comp_gain := float(_arg("comp-gain", str(RadioBus.COMP_GAIN_DB)))
	RadioBus.apply(bus_db, comp_gain)
	_rep = {"tag": tag, "radio_bus_db": bus_db, "radio_comp_gain_db": comp_gain, "mix_rate": AudioServer.get_mix_rate(),
		"metodo": "Godot 4.7.2 headless, driver Dummy, AudioEffectCapture no fim do bus Master (apos o limitador)",
		"nota": "medidas apenas; nada foi ouvido", "lines": {}}
	var master := LoudnessProbe.attach(&"Master")
	# 1. fala de radio pelo caminho do jogo (clique, voz no bus Radio, chiado, clique)
	var radio_l: Array[float] = []
	for id in RADIO_IDS:
		radio_l.append(await _line(master, id, "radio"))
	# 2. o mesmo take do Farol 7 tocado direto no bus Voz (sem radio): isola o efeito da cadeia
	var same_l: Array[float] = []
	for id in RADIO_IDS:
		same_l.append(await _raw(master, id, &"Voz", "mesmo_take_na_voz"))
	# 3. falas comuns de outras personagens (play_line, bus Voz)
	var common_l: Array[float] = []
	for id in COMMON_IDS:
		common_l.append(await _line(master, id, "comum"))
	# 4. chiado sozinho e cliques sozinhos
	_d._ensure_radio_players()
	LoudnessProbe.drain(master)
	_d._radio_hiss(true)
	var hiss: PackedVector2Array = (await LoudnessProbe.collect(self, [master], 2.0))[0]
	_d._radio_hiss(false)
	_save("chiado_sozinho", hiss, {})
	LoudnessProbe.drain(master)
	_d.play_radio_click(&"open")
	var clk: PackedVector2Array = (await LoudnessProbe.collect(self, [master], 0.4))[0]
	_save("clique_abrir_sozinho", clk, {})
	# 5. com musica: 2 s de musica, depois a fala; mede a musica no bus Musica antes e durante
	var mus := LoudnessProbe.attach(&"Musica")
	var voz := LoudnessProbe.attach(&"Voz")
	_rep["com_musica"] = {}
	for id in [RADIO_IDS[0], COMMON_IDS[0]]:
		_d.play_music(MUSIC, 0.0)
		await create_timer(1.0).timeout
		for c in [master, mus, voz]:
			LoudnessProbe.drain(c)
		var pre: Array = await LoudnessProbe.collect(self, [master, mus, voz], 2.0)
		var bus_pre := AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"Musica"))
		var info := _d.play_line(VoiceCatalog.V3_PREFIX + id)
		await create_timer(0.35).timeout
		var bus_during := AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"Musica"))
		var dur: Array = await LoudnessProbe.collect(self, [master, mus, voz], float(info.get("duration", 3.0)) - 0.35)
		_d.stop_voice()
		_d.stop_music(0.0)
		await create_timer(0.8).timeout
		var all := PackedVector2Array(pre[0])
		all.append_array(dur[0])
		_save("com_musica_" + id.replace(".", "_"), all, {})
		_rep["com_musica"][id] = {
			"radio": bool(info.get("radio", false)),
			"musica_bus_antes_lufs": _r(LoudnessProbe.lufs(pre[1])), "musica_bus_durante_lufs": _r(LoudnessProbe.lufs(dur[1])),
			"musica_sidechain_db": _r(LoudnessProbe.rms_dbfs(dur[1]) - LoudnessProbe.rms_dbfs(pre[1])),
			"musica_volume_bus_antes_db": _r(bus_pre), "musica_volume_bus_durante_db": _r(bus_during),
			"voz_bus_durante_lufs": _r(LoudnessProbe.lufs(dur[2])),
			"master_antes_lufs": _r(LoudnessProbe.lufs(pre[0])), "master_durante_lufs": _r(LoudnessProbe.lufs(dur[0]))}
	LoudnessProbe.detach(&"Musica", mus)
	LoudnessProbe.detach(&"Voz", voz)
	_rep["resumo"] = {"radio_lufs_media": _r(_avg(radio_l)), "mesmo_take_na_voz_lufs_media": _r(_avg(same_l)),
		"comuns_lufs_media": _r(_avg(common_l)), "radio_menos_mesmo_take_lu": _r(_avg(radio_l) - _avg(same_l)),
		"radio_menos_comuns_lu": _r(_avg(radio_l) - _avg(common_l)),
		"chiado_lufs": _r(LoudnessProbe.lufs(hiss)), "chiado_rms_dbfs": _r(LoudnessProbe.rms_dbfs(hiss)),
		"clique_abrir_pico_dbfs": _r(LoudnessProbe.peak_dbfs(clk)),
		"clique_abrir_lufs_400ms": _r(LoudnessProbe.lufs(clk)), "voz_radio_pico_dbfs": _rep["lines"]["radio_" + RADIO_IDS[0].replace(".", "_")]["peak_dbfs"]}
	var f := FileAccess.open(_out.path_join("report.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(_rep, "  ") + "\n")
	f.close()
	print(JSON.stringify(_rep["resumo"], "  "))
	print(JSON.stringify(_rep["com_musica"], "  "))
	quit()


func _line(cap: AudioEffectCapture, id: String, kind: String) -> float:
	LoudnessProbe.drain(cap)
	var info := _d.play_line(VoiceCatalog.V3_PREFIX + id)
	var fr: PackedVector2Array = (await LoudnessProbe.collect(self, [cap], float(info.get("duration", 0.0)) + 0.2))[0]
	_d.stop_voice()
	await create_timer(0.4).timeout
	return _save(kind + "_" + id.replace(".", "_"), fr, {"radio": bool(info.get("radio", false))})


func _raw(cap: AudioEffectCapture, id: String, bus: StringName, kind: String) -> float:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	p.stream = VoiceCatalog.stream_for(VoiceCatalog.V3_PREFIX + id)
	root.add_child(p)
	await process_frame
	LoudnessProbe.drain(cap)
	p.play()
	var fr: PackedVector2Array = (await LoudnessProbe.collect(self, [cap], p.stream.get_length() + 0.2))[0]
	p.queue_free()
	await create_timer(0.3).timeout
	return _save(kind + "_" + id.replace(".", "_"), fr, {})


func _save(name: String, fr: PackedVector2Array, extra: Dictionary) -> float:
	LoudnessProbe.write_wav(_out.path_join(name + ".wav"), fr)
	var l := LoudnessProbe.lufs(fr)
	var e := {"lufs_i": _r(l), "peak_dbfs": _r(LoudnessProbe.peak_dbfs(fr)), "duration_s": _r(fr.size() / AudioServer.get_mix_rate())}
	e.merge(extra)
	_rep["lines"][name] = e
	return l


func _avg(a: Array[float]) -> float:
	var s := 0.0
	for v in a:
		s += v
	return s / maxf(a.size(), 1)


func _r(v: float) -> float:
	return snappedf(v, 0.01)
