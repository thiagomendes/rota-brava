extends RefCounted
## RB-R1 G25: roteiro minimo do Ep01 v3 (docs/proposals/g24_roteiro.md). Confere TEXTO (falas novas e reescritas com o
## texto exato, sem marcador, ate 8 palavras e 44 caracteres, tempo de leitura pelo Hud.line_seconds_for_text, teto das
## excecoes LONG_OK), VOZ (takes obsoletos fora do catalogo v3, falas com voz nova em pending.keys, falante e radio pela
## chave) e ESTADO no jogo: a pista do M2 nos juncos e o lenco do filhote; no fim do M5 o peixe sai da mao do Pico para a
## mao da Dona Amora (place_low) e a missao conclui; recuperacao: sem a Amora o M5 conclui igual, e o M5 montado de novo
## (retomada) traz a Amora de maos vazias. Nao comprova render, voz gravada nem leitura por criancas.

const NEW := {
	"ep01.call.c1.lumi_alert": "Na escuta! O capitão chamou no rádio.",
	"ep01.call.c1.captain_radio": "Meu filhote fugiu! Vou atrás de bote!",
	"ep01.call.c1.lumi_stakes": "Sem o capitão, o farol não acende!",
	"ep01.call.c1.lumi_go": "Rastro, ache as pistas no cais!",
	"ep01.call.team_go": "Rota Brava, partiu!",
	"ep01.narrator.bridge.m1_m2b": "E o filhote, pela vila!",
	"ep01.lumi.cheer_1": "Boa! Uma pista do filhote!",
	"ep01.lumi.cheer_2": "Água de volta! Muito bem, equipe!",
	"ep01.market.vendor.gull_hint_b": "O filhote foi atrás da gaivota.",
	"ep01.call.c2.lumi_alert": "Na escuta! O bote do capitão encalhou!",
	"ep01.call.c2.lumi_go": "Leme, o barco é com você!",
	"ep01.call.c3.lumi_alert": "O farol apagou!",
	"ep01.call.c3.lumi_stakes": "Os barcos não acham a festa!",
	"ep01.call.c3.lumi_go": "Pico, suba e salve o filhote!",
	"ep01.lumi.beacon_lit": "O farol acendeu! Os barcos acham a festa!",
	"ep01.festival.captain.thanks_m8": "Obrigado! Meu filhote está em casa!",
}
const REWRITTEN := {
	"ep01.dock.tracker.boot_captain": "A bota do capitão vai até o bote!",
	"ep01.narrator.bridge.m1_m2": "O capitão foi pelo mar.",
	"ep01.dock.climber.go_line": "A gente segue o filhote!",
	"ep01.bank.tracker.next_clue": "O lenço do filhote! Ele foi à praça.",
	"ep01.market.vendor.mess": "Ai, minhas frutas da festa!",  # rodada 2: os caixotes do M4 tem frutas
	"ep01.bank.tracker.wet_paw": "Pegadinha molhada! O lenço está nos juncos.",
	"ep01.radio.v3_m2.find_third_2": "Rastro, o lenço vermelho está no capim.",
	"ep01.market.vendor.gull_hint": "Obrigada! Vocês ajudaram muito!",
	"ep01.street.climber.fish_got": "Peguei! O peixe volta para a Dona Amora.",
}
const GONE: Array[String] = ["ep01.bank.tracker.sock_fur", "ep01.arrival.climber.horn_alone", "ep01.arrival.pilot.boat_empty",
	"ep01.arrival.radio.festival", "ep01.arrival.tracker.look_dock", "ep01.plaza.radio.water_back",
	"ep01.narrator.bridge.m5_m6", "ep01.street.pilot.to_boat", "ep01.bay.pilot.lamp_dark",
	"ep01.lighthouse.radio.lights_on", "ep01.festival.captain.thanks"]
const SPEAKERS := {"ep01.call.c1.captain_radio": &"captain", "ep01.call.team_go": &"tracker",
	"ep01.narrator.bridge.m1_m2b": &"narrator", "ep01.market.vendor.gull_hint_b": &"vendor",
	"ep01.festival.captain.thanks_m8": &"captain"}
## Excecoes LONG_OK do test_ep01_v3_f2_text: texto fixado aqui e teto proprio (revisao do G21i).
const LONG_FIXED := {"ep01.narrator.intro.base": "E aqui é o Farol 7, a base da equipe!",
	"ep01.radio.intro.help": "Precisou? Aperte o botão de ajuda que eu ajudo!"}
const LONG_MAX_WORDS := 10
const LONG_MAX_CHARS := 48
const CATALOG := "res://audio/voice/v3/voice_v3_catalog.json"

var r


func run(runner) -> void:
	r = runner
	Ep01V3Main.save_path = ""
	_text()
	_voice()
	await _m2_scarf()
	await _m5_fish_to_amora()
	await _m5_without_amora()
	Ep01V3Main.start_mission = &""


func _text() -> void:
	var bad: Array[String] = []
	var long: Array[String] = []
	var secs: Array[String] = []
	var all := NEW.duplicate()
	all.merge(REWRITTEN)
	for k: String in all:
		if Loc.t(k) != all[k]:
			bad.append(k)
		var t := Loc.t(k)
		if t.length() > 44 or t.split(" ", false).size() > 8 or t.contains("{"):
			long.append(k)
		# tempo de leitura do jogo (sem voz ainda): entre o minimo de 2,4 s e 4,0 s
		var s := Hud.line_seconds_for_text(t)
		if s < 2.4 or s > 4.0:
			secs.append("%s %.2f" % [k, s])
	r.check(bad.is_empty(), "G25: %d falas novas e reescritas com o texto exato %s" % [all.size(), str(bad)])
	r.check(long.is_empty(), "G25: falas novas e reescritas ate 8 palavras e 44 caracteres, sem marcador %s" % str(long))
	r.check(secs.is_empty(), "G25: tempo de leitura (Hud.line_seconds_for_text) entre 2,4 e 4,0 s %s" % str(secs))
	var marker: Array[String] = []
	for k in Ep01V3Dialogue.all_keys():
		if Loc.t(k).contains("{"):
			marker.append(k)
	r.check(marker.is_empty(), "G25: nenhuma fala do Ep01 v3 com {...} %s" % str(marker))
	var gone: Array[String] = []
	var sheet := Ep01V3Dialogue.sheet()
	var used := JSON.stringify([sheet.get("mission_start"), sheet.get("mission_done"), sheet.get("script")])
	for k in GONE:
		if Loc.has_key(k) or not Ep01V3Dialogue.line(k).is_empty() or used.contains("\"%s\"" % k):
			gone.append(k)
	r.check(gone.is_empty(), "G25: %d falas cortadas ou trocadas fora do catalogo e da ficha %s" % [GONE.size(), str(gone)])
	r.check(Ep01V3Dialogue.start_lines(&"M0") == ["ep01.call.c1.lumi_alert", "ep01.call.c1.captain_radio",
		"ep01.call.c1.lumi_stakes", "ep01.call.c1.lumi_go", "ep01.call.team_go"], "G25: C1 abre o M0 (o capitao pede ajuda pelo radio)")
	var d5 := Ep01V3Dialogue.done_lines(&"M5")
	var d6 := Ep01V3Dialogue.done_lines(&"M6")
	r.check(d5.has("ep01.call.c2.lumi_alert") and d5.has("ep01.call.c2.lumi_go") and d6.has("ep01.call.c3.lumi_alert")
		and d6.has("ep01.call.c3.lumi_go") and Ep01V3Dialogue.done_lines(&"M2").has("ep01.lumi.cheer_1")
		and Ep01V3Dialogue.done_lines(&"M7").has("ep01.lumi.beacon_lit"), "G25: C2 no fim do M5, C3 no fim do M6, comemoracoes do Lumi no M2 e no farol no M7")
	# excecoes longas: texto fixado e teto
	var f2 := load("res://tests/test_ep01_v3_f2_text.gd") as GDScript
	var long_ok: Dictionary = f2.get_script_constant_map().get("LONG_OK", {})
	var over: Array[String] = []
	for k: String in long_ok:
		var t := Loc.t(k)
		if not LONG_FIXED.has(k) or t != LONG_FIXED[k] or t.split(" ", false).size() > LONG_MAX_WORDS or t.length() > LONG_MAX_CHARS:
			over.append(k)
	r.check(long_ok.size() == LONG_FIXED.size() and over.is_empty(),
		"G25: excecoes LONG_OK (%d) com texto fixado e teto de %d palavras e %d caracteres %s" % [long_ok.size(), LONG_MAX_WORDS, LONG_MAX_CHARS, str(over)])
	var hud := Hud.new()
	var sp_bad: Array[String] = []
	for k: String in NEW:
		var want: StringName = SPEAKERS.get(k, &"radio")
		if hud.speaker_for(k) != want or String(Ep01V3Dialogue.speaker(k)) != String(want):
			sp_bad.append("%s %s" % [k, hud.speaker_for(k)])
	hud.free()
	r.check(sp_bad.is_empty(), "G25: falante da legenda pela chave nova (Lumi = radio) %s" % str(sp_bad))
	r.check(AudioDirector.is_radio_line("ep01.call.c1.lumi_alert") and AudioDirector.is_radio_line("ep01.lumi.cheer_1")
		and AudioDirector.is_radio_line("ep01.call.c1.captain_radio") and not AudioDirector.is_radio_line("ep01.call.team_go"),
		"G25: chamados e comemoracoes do Lumi tocam como radio; o bordao da equipe nao")


func _voice() -> void:
	var cat: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CATALOG))
	var ids := {}
	for e: Dictionary in cat["lines"]:
		ids[str(e["id"])] = true
	var pending: Array = (cat["pending"] as Dictionary)["keys"]
	var stale: Array[String] = []
	var missing: Array[String] = []
	var voiced := NEW.keys() + REWRITTEN.keys()
	for k: String in voiced:
		if ids.has(k) or VoiceCatalog.has_v3(k):
			stale.append(k)
		if not pending.has(k):
			missing.append(k)
	for k in GONE:
		if ids.has(k) or pending.has(k) or FileAccess.file_exists("res://audio/voice/v3/%s.ogg" % k.replace(".", "_")):
			stale.append(k)
	r.check(stale.is_empty(), "G25: takes obsoletos fora do catalogo v3 (e sem OGG) %s" % str(stale))
	r.check(missing.is_empty(), "G25: %d falas com voz nova em pending.keys %s" % [voiced.size(), str(missing)])


func _new_main(mission: StringName) -> Ep01V3Main:
	Ep01V3Main.start_mission = mission
	var main := (load("res://episodes/ep01/v3/ep01_v3_main.tscn") as PackedScene).instantiate() as Ep01V3Main
	r.tree.root.add_child(main)
	r.tree.current_scene = main
	await r.frames(4)
	if main.hud.handoff_open:
		main.hud._handoff_since = -100.0
		main.hud._confirm_handoff()
		await r.frames(3)
	main.hud.clear_speech()
	main.guide.skip_look()
	main.set_followers_enabled(false)
	return main


func _free(main: Ep01V3Main) -> void:
	main.queue_free()
	await r.frames(2)
	r.tree.current_scene = null
	r.tree.paused = false
	Ep01V3Main.start_mission = &""


func _hero(main: Ep01V3Main, m: StringName) -> MemberActor:
	var a := main.actors[m] as MemberActor
	main.active_member = m
	main.set_controlled(a)
	if main.current != null:
		main.current.set_active_hero(m)
	return a


func _notify_all(main: Ep01V3Main, evs: Array) -> void:
	for ev: StringName in evs:
		for who: StringName in [&"tracker", &"climber", &"pilot"]:
			if main.current.notify(ev, who):
				break
	await r.frames(3)
	if main.hud.handoff_open:
		main.hud._handoff_since = -100.0
		main.hud._confirm_handoff()
		await r.frames(3)
	main.hud.clear_speech()


func _act(main: Ep01V3Main, m: StringName, id: StringName, limit: float = 25.0) -> void:
	var a := _hero(main, m)
	main.land.call("_on_spot", id, a)
	var t := 0.0
	while t < limit:
		await r.tree.physics_frame
		t += r.tree.root.get_physics_process_delta_time()
		if int(main.land.get("_acts")) == 0:
			break
	await r.frames(2)


func _m2_scarf() -> void:
	var main := await _new_main(&"M2")
	var pieces: Array = main.land.get("_pieces")
	var third := pieces[2] as Node3D if pieces.size() == 3 else null
	r.check(third != null and str(third.get_meta(&"piece_id", "")) == "cloth_pup_scarf" and not bool(third.get_meta(Ep01V3Pieces.PROVISIONAL, false)),
		"G25 M2: a peca dos juncos e o lenco do filhote (modelo final cloth_pup_scarf)")
	await _free(main)


## Leva o M5 do inicio ate o fim da acao do peixe (pegar, baixar, descer e entregar); devolve o Pico.
func _m5_to_fish(main: Ep01V3Main) -> MemberActor:
	var land := main.land
	await _notify_all(main, [&"feather_followed", &"feather_followed", &"feather_followed", &"feather_followed", &"compass_read"])
	var pico := _hero(main, &"climber")
	pico.teleport(land.points[&"CratesBase"] + Vector3(0, 0.05, 0))
	await r.frames(2)
	await _act(main, &"climber", &"crates_climb", 15.0)
	land.call("_set_busy", true)
	await _act(main, &"climber", &"fish", 30.0)
	return pico   # a Land fica ocupada (a missao seguinte nao monta) ate quem chama soltar


func _m5_fish_to_amora() -> void:
	var main := await _new_main(&"M5")
	var land := main.land as Ep01V3Late
	var amora := land.amora
	r.check(amora != null and is_instance_valid(amora) and StoryFigure.visual(amora) != null,
		"G25 M5: a Dona Amora espera na rua do M5")
	var pico := await _m5_to_fish(main)
	var fish = land.get("_fish")
	var order: Array[StringName] = []
	for e: Dictionary in land.hand_log:
		if e["piece"] == fish:
			order.append(e["member"])
	r.check(order == [&"climber", &"climber", &"vendor"],
		"G25b M5: o peixe passa pela mao do Pico (telhado; do cinto para a mao, na rua) e termina na da Amora %s" % str(order))
	var in_hand := fish != null and is_instance_valid(fish) and (fish as Node3D).get_parent() is BoneAttachment3D \
		and ((fish as Node3D).get_parent() as BoneAttachment3D).bone_name == "hand.R" and amora.is_ancestor_of(fish)
	r.check(in_hand and land.carried == null and pico.hands == &"", "G25 M5: o peixe fica na mao direita da Amora e o Pico de maos livres")
	var near := pico.global_position.distance_to(amora.global_position) if amora != null else INF
	r.check(near < 1.2, "G25 M5: o Pico entrega de perto (%.2f m da Amora)" % near)
	r.check(land.last_route.size() >= 2, "G25b M5: o Pico vai ate a Amora por um caminho livre (%d pontos)" % land.last_route.size())
	r.check(main.missions[5].is_completed(), "G25 M5: a entrega do peixe conclui a missao")
	land.call("_set_busy", false)
	await _free(main)
	# retomada: o M5 montado de novo traz a Amora de maos vazias (o estado vem da missao, nao do peixe)
	var again := await _new_main(&"M5")
	var la := again.land as Ep01V3Late
	var empty := la.amora != null and la.amora.find_child("Fish", true, false) == null
	r.check(empty and la.fish_street_gap == INF, "G25 M5 retomada: Amora de maos vazias e peixe ainda no bico da gaivota")
	await _free(again)


func _m5_without_amora() -> void:
	var main := await _new_main(&"M5")
	var land := main.land as Ep01V3Late
	land.amora.queue_free()
	land.amora = null
	await r.frames(2)
	await _m5_to_fish(main)
	r.check(absf(land.fish_street_gap) < 0.03, "G25 M5 recuperacao: sem a Amora a corda pousa o peixe no chao (folga %.1f cm)" % (land.fish_street_gap * 100.0))
	r.check(main.missions[5].is_completed() and land.carried == null,
		"G25 M5 recuperacao: sem a Amora o peixe fica na rua e a missao conclui igual")
	land.call("_set_busy", false)
	await _free(main)
