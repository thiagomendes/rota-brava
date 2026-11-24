class_name AudioDirector extends Node
## Diretor de audio (SPEC secao 6; RB-04). Adicione como filho de Ep01Main. Nao acessa nos do jogo: so o que
## recebe por parametro. Buses: Voz, Musica, Efeitos, Ambiente (res://audio/default_bus_layout.tres).
## Falas: uma por vez; fala ausente devolve 0.0 e NAO quebra (o chamador mantem a legenda).
## Equivalente visual de efeitos essenciais: `caption_key` no sfx_catalog.json (chave de Loc).

signal voice_finished(id: String)
signal voice_cancelled(id: String)
signal music_finished(music_name: String)
signal line_started(id: String, info: Dictionary)

const CATALOG_PATH := "res://audio/sfx_catalog.json"
const BUS_VOICE := &"Voz"
const BUS_MUSIC := &"Musica"
const BUS_SFX := &"Efeitos"
const BUS_AMBIENCE := &"Ambiente"
const AMBIENCE_NAMES: Array[String] = ["amb_dock_water", "amb_wind_light", "amb_dock_creaks", "amb_gulls_far"]
const STEP_NAMES: Array[String] = ["sfx_step_wood_01", "sfx_step_wood_02", "sfx_step_wood_03", "sfx_step_wood_04", "sfx_step_wood_05", "sfx_step_wood_06"]
const SURFACES: Array[StringName] = [&"wood", &"stone", &"sand", &"grass"]
## Zonas de ambiente (RB-R1): camadas em loop por lugar do mapa.
const AMBIENCE_ZONES: Dictionary = {
	&"dock": ["amb_dock_water", "amb_wind_light", "amb_dock_creaks", "amb_gulls_far"],
	&"village": ["amb_beach_waves", "amb_village_market", "amb_gulls_far", "amb_wind_light"],
	&"river": ["amb_river", "amb_birds", "amb_wind_light"],
	&"island": ["amb_beach_waves", "amb_birds", "amb_gulls_far", "amb_wind_light"],
}
## Nomes curtos de musica (secoes) -> entradas do catalogo. Vinhetas tocam por cima do loop e devolvem a secao.
const MUSIC_ALIASES: Dictionary = {
	&"explore": "theme_explore", &"explore_low": "theme_explore_low", &"crossing": "theme_crossing",
	&"return": "theme_return", &"discovery": "theme_discovery", &"victory": "theme_victory", &"team_call": "theme_team_call",
}
const UI_SOUNDS: Dictionary = {
	&"move": "sfx_ui_move", &"confirm": "sfx_ui_confirm", &"back": "sfx_ui_back", &"open": "sfx_ui_open",
	&"swap": "sfx_ui_swap", &"hero_swap": "sfx_ui_swap", &"clue": "sfx_clue_found", &"clue_found": "sfx_clue_found",
	&"star": "sfx_ui_star",
}
const STING_DIP_DB := -10.0
const POOL_START := 8
const POOL_MAX := 24
const ENGINE_PITCH_MIN := 0.8
const ENGINE_PITCH_MAX := 2.4
const DUCK_DB := -6.0
const DUCK_IN := 0.3
const DUCK_OUT := 0.8
const VOICE_CANCEL_FADE := 0.08
const SILENT_DB := -60.0

var engine_player: AudioStreamPlayer
var current_voice_id: String = ""
var current_music: String = ""
var last_step_name: String = ""
var step_history: Array[String] = []
var rng := RandomNumberGenerator.new()
var ducked: bool = false
var ambience_zone: StringName = &"dock"
var current_sting: String = ""
var current_line: Dictionary = {}
var last_step_by_surface: Dictionary = {}

var _entries: Dictionary = {}
var _streams: Dictionary = {}
var _pool2d: Array[AudioStreamPlayer] = []
var _pool3d: Array[AudioStreamPlayer3D] = []
var _voice_players: Array[AudioStreamPlayer] = []
var _voice_cur: int = 0
var _voice_token: int = 0
var _music_players: Array[AudioStreamPlayer] = []
var _music_cur: int = 0
var _amb_players: Dictionary = {}
var _amb_tween: Tween
var _duck_tween: Tween
var _music_base_db: float = 0.0
var _music_bus_base_db: float = NAN
var _sting_player: AudioStreamPlayer
var _visemes_cache: Dictionary = {}
var _line_started_ms: int = 0
var _line_duck: bool = false


func _ready() -> void:
	_ensure_catalog()
	rng.randomize()
	for i in 2:
		_voice_players.append(_make_player(BUS_VOICE))
		_music_players.append(_make_player(BUS_MUSIC))
	voice_finished.connect(_on_line_end)
	voice_cancelled.connect(_on_line_end)
	_sting_player = _make_player(BUS_MUSIC)
	for i in POOL_START:
		_pool2d.append(_make_player(BUS_SFX))
		_pool3d.append(_make_player3d())


func _ensure_catalog() -> void:
	if not _entries.is_empty():
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH)) if FileAccess.file_exists(CATALOG_PATH) else null
	if parsed is Dictionary and (parsed as Dictionary).get("entries") is Array:
		for e in (parsed as Dictionary)["entries"]:
			_entries[str((e as Dictionary)["name"])] = e
	else:
		push_warning("AudioDirector: catalogo ausente ou invalido: " + CATALOG_PATH)


func has_sound(sound_name: String) -> bool:
	_ensure_catalog()
	return _entries.has(sound_name)


## Chave de Loc com a descricao visual/legenda do efeito ("" se nao ha).
func caption_key(sound_name: String) -> String:
	_ensure_catalog()
	if not _entries.has(sound_name) or _entries[sound_name].get("caption_key") == null:
		return ""
	return str(_entries[sound_name]["caption_key"])


func _make_player(bus: StringName) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	add_child(p)
	return p


func _make_player3d() -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.bus = BUS_SFX
	p.unit_size = 12.0
	p.max_distance = 160.0
	p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	add_child(p)
	return p


func _stream(sound_name: String) -> AudioStream:
	_ensure_catalog()
	if _streams.has(sound_name):
		return _streams[sound_name]
	if not _entries.has(sound_name):
		push_warning("AudioDirector: som desconhecido: " + sound_name)
		return null
	var path := str(_entries[sound_name]["file"])
	if not ResourceLoader.exists(path):
		push_warning("AudioDirector: arquivo ausente: " + path)
		return null
	var s := load(path) as AudioStream
	if s != null and bool(_entries[sound_name].get("loop", false)):
		s = _looped(s)
	_streams[sound_name] = s
	return s


static func _looped(s: AudioStream) -> AudioStream:
	var ogg := s as AudioStreamOggVorbis
	if ogg != null:
		var o := ogg.duplicate() as AudioStreamOggVorbis
		o.loop = true
		o.loop_offset = 0.0
		return o
	var w := s as AudioStreamWAV
	if w == null:
		return s
	var d := w.duplicate() as AudioStreamWAV
	var bytes_per_frame := (2 if w.format == AudioStreamWAV.FORMAT_16_BITS else 1) * (2 if w.stereo else 1)
	d.loop_mode = AudioStreamWAV.LOOP_FORWARD
	d.loop_begin = 0
	d.loop_end = w.data.size() / bytes_per_frame
	return d


func _gain(sound_name: String) -> float:
	return float(_entries[sound_name].get("gain_db", 0.0)) if _entries.has(sound_name) else 0.0


func _free_2d() -> AudioStreamPlayer:
	for p in _pool2d:
		if not p.playing:
			return p
	if _pool2d.size() < POOL_MAX:
		var n := _make_player(BUS_SFX)
		_pool2d.append(n)
		return n
	return null  # nunca corta um som em andamento: descarta o novo


func _free_3d() -> AudioStreamPlayer3D:
	for p in _pool3d:
		if not p.playing:
			return p
	if _pool3d.size() < POOL_MAX:
		var n := _make_player3d()
		_pool3d.append(n)
		return n
	return null


## Efeito: 3D posicional (AudioStreamPlayer3D) se `position` != ZERO; 2D caso contrario. Devolve o player usado
## (ou null se o som nao existe ou o pool esta cheio). `pitch_scale` opcional para variacao.
func play_sfx(sound_name: String, position: Vector3 = Vector3.ZERO, volume_db: float = 0.0, pitch_scale: float = 1.0) -> Node:
	var s := _stream(sound_name)
	if s == null:
		return null
	var db := volume_db + _gain(sound_name)
	if position != Vector3.ZERO:
		var p3 := _free_3d()
		if p3 == null:
			return null
		p3.stream = s
		p3.volume_db = db
		p3.pitch_scale = pitch_scale
		p3.position = position
		p3.play()
		return p3
	var p := _free_2d()
	if p == null:
		return null
	p.stream = s
	p.volume_db = db
	p.pitch_scale = pitch_scale
	p.play()
	return p


## Nomes das variacoes de passo de uma superficie (wood, stone, sand, grass); desconhecida cai em madeira.
func step_names(surface: StringName) -> Array[String]:
	var s := surface if SURFACES.has(surface) else &"wood"
	var names: Array[String] = []
	for i in 6:
		var n := "sfx_step_%s_%02d" % [s, i + 1]
		if has_sound(n):
			names.append(n)
	return names if not names.is_empty() else STEP_NAMES


## Passo: escolhe uma das 6 variacoes da superficie sem repetir a anterior; volume e pitch variam levemente com a
## velocidade (m/s; ~0..4). Devolve o nome tocado ("" se speed <= 0).
func play_footstep(speed: float, surface: StringName = &"wood", position: Vector3 = Vector3.ZERO) -> String:
	if speed <= 0.0:
		return ""
	var names := step_names(surface)
	var prev: String = last_step_by_surface.get(surface, last_step_name)
	var pick := names[rng.randi_range(0, names.size() - 1)]
	if names.size() > 1:
		while pick == prev:
			pick = names[rng.randi_range(0, names.size() - 1)]
	last_step_name = pick
	last_step_by_surface[surface] = pick
	step_history.append(pick)
	if step_history.size() > 200:
		step_history.pop_front()
	var k := clampf(speed / 4.0, 0.0, 1.0)
	var vol := lerpf(-8.0, -1.0, k) + rng.randf_range(-1.2, 1.2)
	var pit := lerpf(0.94, 1.06, k) * rng.randf_range(0.96, 1.04)
	play_sfx(pick, position, vol, pit)
	return pick


## Fala: uma por vez. Nova fala cancela a anterior com fade curto (voice_cancelled). Devolve a duracao em
## segundos; 0.0 se a fala ou o arquivo nao existe (sem erro; o chamador mantem a legenda e libera a sequencia).
func play_voice(id: String) -> float:
	var s := VoiceCatalog.stream_for(id, Loc.language)
	if s == null:
		return 0.0
	_ensure_voice_players()
	if current_voice_id != "":
		_cancel_voice()
	_voice_cur = (_voice_cur + 1) % _voice_players.size()
	var p := _voice_players[_voice_cur]
	p.stop()  # se ainda estava no fade de uma fala anterior
	p.stream = s
	p.volume_db = 0.0
	_voice_token += 1
	current_voice_id = id
	p.play()
	_wait_voice_end(p, id, _voice_token, s.get_length())
	return s.get_length()


func _ensure_voice_players() -> void:
	if _voice_players.is_empty():
		for i in 2:
			_voice_players.append(_make_player(BUS_VOICE))


func _wait_voice_end(p: AudioStreamPlayer, id: String, token: int, _length: float) -> void:
	await p.finished
	if token == _voice_token and current_voice_id == id:
		current_voice_id = ""
		voice_finished.emit(id)


func _cancel_voice() -> void:
	var old_id := current_voice_id
	var old := _voice_players[_voice_cur]
	current_voice_id = ""
	_voice_token += 1  # invalida o fim da fala antiga
	voice_cancelled.emit(old_id)
	# sem checar old.playing: logo apos play() a Godot pode ainda reportar playing=false e a fala tocaria inteira
	if is_inside_tree():
		var tw := create_tween()
		tw.tween_property(old, "volume_db", SILENT_DB, VOICE_CANCEL_FADE)
		tw.tween_callback(old.stop)
	else:
		old.stop()


## Interrompe a fala atual (ex.: a crianca avancou a legenda).
func stop_voice() -> void:
	_cancel_voice()


func is_voice_playing() -> bool:
	return current_voice_id != ""


## Fala com dados para a boca e a legenda (RB-R1). Devolve sempre um Dictionary:
##   id, duration (s; 0.0 se a fala/arquivo nao existe -> o chamador mantem a legenda e libera a sequencia),
##   type ("babble" | "radio" | ""), character, intent, emotes (Array), subtitle (chave de Loc),
##   frame_s (s por quadro de visema) e visemes (Array[float] 0..1, abertura da boca).
## Abaixa a musica (duck_music) enquanto a fala toca; volta ao terminar ou ser cancelada.
func play_line(id: String) -> Dictionary:
	var e := VoiceCatalog.lookup(id, Loc.language)
	var info := {"id": id, "duration": 0.0, "type": str(e.get("type", "")), "character": str(e.get("character", "")),
		"intent": str(e.get("intent", "")), "emotes": e.get("emotes", []), "subtitle": str(e.get("subtitle", id)),
		"frame_s": 0.03, "visemes": []}
	var dur := play_voice(id) if not e.is_empty() else 0.0
	if dur <= 0.0:
		current_line = {}
		return info
	var vis := _load_visemes(str(e.get("visemes", "")))
	info["duration"] = dur
	info["frame_s"] = float(vis.get("frame_s", 0.03))
	info["visemes"] = vis.get("open", [])
	current_line = info
	_line_started_ms = Time.get_ticks_msec()
	if not ducked:
		duck_music(true)
		_line_duck = true
	line_started.emit(id, info)
	return info


func _load_visemes(path: String) -> Dictionary:
	if path == "":
		return {}
	if _visemes_cache.has(path):
		return _visemes_cache[path]
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	var d: Dictionary = parsed if parsed is Dictionary else {}
	_visemes_cache[path] = d
	return d


## Abertura da boca (0..1) da fala atual no instante t (s desde o inicio da fala). 0.0 sem fala ou fora dela.
## Interpola linearmente entre quadros de ~30 ms.
func viseme_at(t: float) -> float:
	var v: Array = current_line.get("visemes", [])
	if v.is_empty() or t < 0.0:
		return 0.0
	var f := t / float(current_line.get("frame_s", 0.03))
	var i := int(floor(f))
	if i >= v.size() - 1:
		return float(v[v.size() - 1]) if i == v.size() - 1 else 0.0
	return lerpf(float(v[i]), float(v[i + 1]), f - float(i))


## Abertura da boca agora (usa a posicao de reproducao da fala atual; 0.0 se nenhuma fala toca).
func current_viseme() -> float:
	if current_voice_id == "" or current_line.is_empty() or str(current_line.get("id", "")) != current_voice_id:
		return 0.0
	var p := _voice_players[_voice_cur]
	var t := p.get_playback_position() if p.playing else float(Time.get_ticks_msec() - _line_started_ms) / 1000.0
	return viseme_at(t)


func _on_line_end(_id: String) -> void:
	current_line = {}
	if _line_duck:
		_line_duck = false
		duck_music(false)


## Som de interface (2D, bus Efeitos): move, confirm, back, open, swap/hero_swap, clue/clue_found, star.
## Devolve o player ou null se o nome nao existe.
func play_ui(ui_name: StringName) -> Node:
	var n: String = UI_SOUNDS.get(ui_name, "")
	if n == "":
		push_warning("AudioDirector: som de UI desconhecido: " + String(ui_name))
		return null
	return play_sfx(n)


## Troca as camadas de ambiente pela zona (dock, village, river, island) com crossfade de `fade` s.
func set_ambience_zone(zone: StringName, fade: float = 2.0) -> void:
	if not AMBIENCE_ZONES.has(zone):
		push_warning("AudioDirector: zona de ambiente desconhecida: " + String(zone))
		return
	ambience_zone = zone
	var wanted: Array = AMBIENCE_ZONES[zone]
	for n in _amb_players:
		if not wanted.has(n):
			var p: AudioStreamPlayer = _amb_players[n]
			if p.playing:
				if is_inside_tree() and fade > 0.0:
					var tw := create_tween()
					tw.tween_property(p, "volume_db", SILENT_DB, fade)
					tw.tween_callback(p.stop)
				else:
					p.stop()
	start_ambience(fade)


func ambience_layers_playing() -> Array[String]:
	var out: Array[String] = []
	for n in _amb_players:
		var p: AudioStreamPlayer = _amb_players[n]
		if p.playing and (AMBIENCE_ZONES[ambience_zone] as Array).has(n):
			out.append(n)
	return out


## Ambiente: camadas em loop da zona atual (padrao dock: agua, vento, rangidos, gaivotas), cada uma com nivel proprio
## (gain_db do catalogo); entram com fade a partir de pontos aleatorios para nao alinhar as emendas.
func start_ambience(fade: float = 2.0) -> void:
	for n in AMBIENCE_ZONES[ambience_zone]:
		var s := _stream(n)
		if s == null:
			continue
		var p: AudioStreamPlayer = _amb_players.get(n)
		if p == null:
			p = _make_player(BUS_AMBIENCE)
			_amb_players[n] = p
		if p.playing:
			continue
		p.stream = s
		p.volume_db = SILENT_DB
		p.play(rng.randf() * s.get_length())
		if is_inside_tree() and fade > 0.0:
			create_tween().tween_property(p, "volume_db", _gain(n), fade)
		else:
			p.volume_db = _gain(n)


func stop_ambience(fade: float = 2.0) -> void:
	for n in _amb_players:
		var p: AudioStreamPlayer = _amb_players[n]
		if not p.playing:
			continue
		if is_inside_tree() and fade > 0.0:
			var tw := create_tween()
			tw.tween_property(p, "volume_db", SILENT_DB, fade)
			tw.tween_callback(p.stop)
		else:
			p.stop()


func is_ambience_playing() -> bool:
	for n in _amb_players:
		if (_amb_players[n] as AudioStreamPlayer).playing:
			return true
	return false


## Passa-baixas opcional do bus Ambiente (ex.: dentro de uma cabine ou durante uma fala importante).
func set_ambience_lowpass(on: bool) -> void:
	var idx := AudioServer.get_bus_index(BUS_AMBIENCE)
	if idx >= 0 and AudioServer.get_bus_effect_count(idx) > 0:
		AudioServer.set_bus_effect_enabled(idx, 0, on)


## Motor: t em 0..1 (parado .. velocidade maxima) muda o pitch do loop (~800 rpm equivalente a pitch 0,8).
## Inicia o loop na primeira chamada; set_engine_rpm(-1.0) para (desliga).
func set_engine_rpm(t: float) -> void:
	if t < 0.0:
		if engine_player != null:
			engine_player.stop()
		return
	var k := clampf(t, 0.0, 1.0)
	if engine_player == null:
		engine_player = _make_player(BUS_SFX)
		engine_player.stream = _stream("sfx_engine_loop")
	engine_player.pitch_scale = lerpf(ENGINE_PITCH_MIN, ENGINE_PITCH_MAX, k)
	engine_player.volume_db = _gain("sfx_engine_loop") + lerpf(-5.0, 3.0, k)
	if engine_player.stream != null and not engine_player.playing:
		engine_player.play()


## Musica: crossfade de `fade` s entre a faixa atual e `music_name` (theme_explore, theme_explore_low,
## theme_discovery). Faixas sem loop emitem music_finished ao terminar.
func play_music(music_name: String, fade: float = 1.0) -> void:
	music_name = resolve_music(music_name)
	if music_name == current_music and _music_players.size() > 0 and _music_players[_music_cur].playing:
		return
	var s := _stream(music_name)
	if s == null:
		return
	# Vinheta (sem loop) sobre um loop tocando: toca por cima, abaixa o loop e devolve a secao ao terminar.
	if not bool(_entries[music_name].get("loop", true)) and current_music != "" and _music_players.size() > 0 \
			and _music_players[_music_cur].playing and bool(_entries.get(current_music, {}).get("loop", false)):
		_play_sting(music_name, s)
		return
	if _music_players.is_empty():
		for i in 2:
			_music_players.append(_make_player(BUS_MUSIC))
	var old := _music_players[_music_cur]
	_music_cur = (_music_cur + 1) % _music_players.size()
	var p := _music_players[_music_cur]
	p.stop()
	p.stream = s
	current_music = music_name
	_music_base_db = _gain(music_name)
	p.volume_db = SILENT_DB if fade > 0.0 else _music_base_db
	p.play()
	if is_inside_tree() and fade > 0.0:
		var tw := create_tween().set_parallel(true)
		tw.tween_property(p, "volume_db", _music_base_db, fade)
		if old.playing:
			tw.tween_property(old, "volume_db", SILENT_DB, fade)
			tw.chain().tween_callback(old.stop)
	elif old.playing:
		old.stop()
	if not bool(_entries[music_name].get("loop", true)):
		_wait_music_end(p, music_name)


## Nome do catalogo para um nome curto de secao (explore, explore_low, crossing, return, discovery, victory,
## team_call) ou o proprio nome se ja for do catalogo.
func resolve_music(music_name: String) -> String:
	return str(MUSIC_ALIASES.get(StringName(music_name), music_name))


func _play_sting(sting: String, s: AudioStream) -> void:
	if _sting_player == null:
		_sting_player = _make_player(BUS_MUSIC)
	var loop_p := _music_players[_music_cur]
	_sting_player.stop()
	_sting_player.stream = s
	_sting_player.volume_db = _gain(sting)
	current_sting = sting
	_sting_player.play()
	if is_inside_tree():
		create_tween().tween_property(loop_p, "volume_db", _music_base_db + STING_DIP_DB, 0.15)
	else:
		loop_p.volume_db = _music_base_db + STING_DIP_DB
	_wait_sting_end(sting, loop_p)


func _wait_sting_end(sting: String, loop_p: AudioStreamPlayer) -> void:
	await _sting_player.finished
	if current_sting != sting:
		return
	current_sting = ""
	if loop_p.playing and loop_p == _music_players[_music_cur]:
		if is_inside_tree():
			create_tween().tween_property(loop_p, "volume_db", _music_base_db, 1.2)
		else:
			loop_p.volume_db = _music_base_db
	music_finished.emit(sting)


func is_sting_playing() -> bool:
	return current_sting != "" and _sting_player != null and _sting_player.playing


func _wait_music_end(p: AudioStreamPlayer, music_name: String) -> void:
	await p.finished
	if current_music == music_name and p == _music_players[_music_cur]:
		current_music = ""
		music_finished.emit(music_name)


func stop_music(fade: float = 1.0) -> void:
	current_music = ""
	for p in _music_players:
		if not p.playing:
			continue
		if is_inside_tree() and fade > 0.0:
			var tw := create_tween()
			tw.tween_property(p, "volume_db", SILENT_DB, fade)
			tw.tween_callback(p.stop)
		else:
			p.stop()


## Ducking manual alem do sidechain: Musica -6 dB (0,3 s) / volta (0,8 s). Atua no bus Musica.
func duck_music(on: bool) -> void:
	var idx := AudioServer.get_bus_index(BUS_MUSIC)
	if idx < 0:
		ducked = on
		return
	if is_nan(_music_bus_base_db):
		_music_bus_base_db = AudioServer.get_bus_volume_db(idx) if not ducked else AudioServer.get_bus_volume_db(idx) - DUCK_DB
	ducked = on
	var target := _music_bus_base_db + (DUCK_DB if on else 0.0)
	if _duck_tween != null and _duck_tween.is_valid():
		_duck_tween.kill()
	if is_inside_tree():
		_duck_tween = create_tween()
		_duck_tween.tween_method(func(v: float) -> void: AudioServer.set_bus_volume_db(idx, v), AudioServer.get_bus_volume_db(idx), target, DUCK_IN if on else DUCK_OUT)
	else:
		AudioServer.set_bus_volume_db(idx, target)


## Alvo em dB do bus Musica para o estado de ducking atual (NAN antes da primeira chamada).
func music_bus_target_db() -> float:
	return _music_bus_base_db + (DUCK_DB if ducked else 0.0)


func stop_all() -> void:
	if current_voice_id != "":
		var old_id := current_voice_id
		current_voice_id = ""
		_voice_token += 1
		voice_cancelled.emit(old_id)
	for p in _voice_players:
		p.stop()
	for p in _pool2d:
		p.stop()
	for p in _pool3d:
		p.stop()
	if engine_player != null:
		engine_player.stop()
	stop_music(0.0)
	stop_ambience(0.0)
	current_music = ""
	current_sting = ""
	current_line = {}
	_line_duck = false
	if _sting_player != null:
		_sting_player.stop()
	if ducked:
		duck_music(false)


func _exit_tree() -> void:
	# restaura o bus Musica se o diretor sair com ducking ativo
	if not is_nan(_music_bus_base_db):
		var idx := AudioServer.get_bus_index(BUS_MUSIC)
		if idx >= 0:
			AudioServer.set_bus_volume_db(idx, _music_bus_base_db)
