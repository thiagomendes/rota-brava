extends RefCounted
## D20a: trilha Lyria do Ep01 v3. Arquivos existem e batem com o catalogo (sha256), loops configurados,
## cada missao toca a secao certa, vinhetas por cima da secao e ducking da fala continua.
## NAO comprova audicao (so estados, arquivos e medidas do gerador).

const SCENES: Array[String] = ["music_v3_village", "music_v3_mystery", "music_v3_boat", "music_v3_lighthouse", "music_v3_festival"]
const STINGS: Array[String] = ["sting_v3_mission_win", "sting_v3_badge", "sting_v3_hero_switch"]
const EXPECT: Dictionary = {
	&"M0": "music_v3_village", &"M1": "music_v3_mystery", &"M2": "music_v3_mystery", &"M3": "music_v3_mystery",
	&"M4": "music_v3_village", &"M5": "music_v3_mystery", &"M6": "music_v3_boat", &"M7": "music_v3_lighthouse",
	&"M8": "music_v3_festival",
}


class FakeEpisode extends Node:
	signal mission_started(mission_id: StringName)
	signal mission_completed(mission_id: StringName)


func _sha256(path: String) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(FileAccess.get_file_as_bytes(path))
	return ctx.finish().hex_encode()


func run(r) -> void:
	var cat: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://audio/sfx_catalog.json"))
	var by_name: Dictionary = {}
	for e in cat["entries"]:
		by_name[str(e["name"])] = e
	var files_ok := true
	var sha_ok := true
	var loop_ok := true
	for n in SCENES + STINGS:
		var e: Dictionary = by_name.get(n, {})
		var f := str(e.get("file", ""))
		if f == "" or not ResourceLoader.exists(f):
			files_ok = false
			printerr("faixa ausente: " + n)
			continue
		if _sha256(f) != str(e.get("sha256", "")):
			sha_ok = false
			printerr("sha256 diverge do catalogo: " + n)
		if bool(e["loop"]) != (n in SCENES) or (n in SCENES and float(e.get("seam_jump", 1.0)) > 0.02):
			loop_ok = false
	r.check(files_ok, "musica v3: 5 cenas + 3 vinhetas no catalogo e importaveis")
	r.check(sha_ok, "musica v3: sha256 dos OGG bate com o catalogo (manifesto)")
	r.check(loop_ok, "musica v3: cenas em loop (emenda <= 0,02) e vinhetas sem loop")

	var d := AudioDirector.new()
	r.tree.root.add_child(d)
	var ep := FakeEpisode.new()
	r.tree.root.add_child(ep)
	d.bind_episode_music(ep)
	await r.frames(2)
	var map_ok := true
	for m: StringName in EXPECT:
		ep.mission_started.emit(m)
		if d.current_music != EXPECT[m]:
			map_ok = false
			printerr("missao %s tocou %s" % [m, d.current_music])
	r.check(map_ok, "musica v3: cada missao toca a secao certa (vila, misterio nas pistas, barco M6, farol M7, festa M8)")
	var p := d._music_players[d._music_cur]
	var s := p.stream as AudioStreamOggVorbis
	r.check(s != null and s.loop and p.bus == &"Musica", "musica v3: loop OGG configurado e no bus Musica")

	ep.mission_started.emit(&"M0")
	await r.tree.create_timer(0.1).timeout
	ep.mission_completed.emit(&"M0")
	r.check(d.current_sting == "sting_v3_mission_win" and d.current_music == "music_v3_village", "musica v3: vitoria de missao toca por cima da vila")
	d.play_badge_sting()
	r.check(d.current_sting == "sting_v3_badge", "musica v3: vinheta do emblema")
	d.play_hero_switch_sting()
	r.check(d.current_sting == "sting_v3_hero_switch" and d.current_music == "music_v3_village", "musica v3: vinheta da troca de heroi mantem a secao")

	d.duck_music(true)
	r.check(d.ducked, "musica v3: ducking da fala continua ligado com a trilha nova")
	d.duck_music(false)
	d.stop_all()
	ep.queue_free()
	d.queue_free()
	await r.frames(1)
