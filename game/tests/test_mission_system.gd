extends RefCounted
## Sistema de missao curta (RB-R1 E2): carga do JSON, estados e sinais, heroi exigido e pedido de troca, emblemas,
## ponto seguro, ajuda em 3 degraus com tempo simulado (sem esperar), movimento reduzido, salvamento/carga versionado.
## Deterministico: nada depende de relogio real nem de cena.

const SAMPLE := "res://systems/mission/sample_missions.json"
const SAVE := "user://test_missions.save.json"

var r


func run(runner) -> void:
	r = runner
	_test_load()
	_test_flow()
	_test_hero_switch()
	_test_emblems_and_safe_point()
	_test_help()
	_test_help_custom_and_reduced()
	_test_save_load()
	_test_i18n()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))


func _load() -> Array[Mission]:
	return Mission.load_list(SAMPLE)


func _rec(m: Mission) -> Array:
	var log: Array = []
	m.started.connect(func(id: StringName) -> void: log.append(["started", id]))
	m.step_done.connect(func(id: StringName, i: int, s: StringName) -> void: log.append(["step_done", i, s]))
	m.completed.connect(func(id: StringName) -> void: log.append(["completed", id]))
	m.emblem_found.connect(func(id: StringName, e: StringName, f: int, t: int) -> void: log.append(["emblem", e, f, t]))
	m.hero_switch_requested.connect(func(id: StringName, h: StringName, icon: StringName) -> void: log.append(["switch", h, icon]))
	m.returned_to_safe_point.connect(func(id: StringName, p: StringName, k: StringName) -> void: log.append(["safe", p, k]))
	return log


func _test_load() -> void:
	var ms := _load()
	r.check(ms.size() == 2, "mission: JSON de exemplo carrega 2 missoes (%d)" % ms.size())
	r.check(ms[0].id == &"arrival" and ms[1].id == &"clothesline", "mission: missoes ordenadas por `order`")
	var c := ms[1]
	r.check(Array(c.heroes) == [&"climber", &"tracker"], "mission: herois necessarios lidos")
	r.check(c.steps.size() == 3 and c.steps[0]["icon"] == &"climb" and int(c.steps[0]["count"]) == 2, "mission: passos com icone e contagem")
	r.check(c.emblems.size() == 2 and c.state == Mission.State.INACTIVE, "mission: emblemas lidos, comeca inativa")


func _test_flow() -> void:
	var m := _load()[1]
	var log := _rec(m)
	r.check(not m.notify(&"piece_freed", &"climber"), "mission: inativa ignora eventos")
	m.start(&"climber")
	r.check(m.is_active() and log[0] == ["started", &"clothesline"], "mission: start ativa e emite started")
	r.check(not m.notify(&"piece_hung", &"climber"), "mission: evento de outro passo nao conta")
	r.check(m.notify(&"piece_freed", &"climber") and m.step_index == 0 and m.step_progress == 1, "mission: contagem parcial (1 de 2)")
	m.notify(&"piece_freed", &"climber")
	r.check(m.step_index == 1 and log.has(["step_done", 0, &"free_pieces"]), "mission: passo concluido emite step_done")
	m.set_active_hero(&"tracker")
	m.notify(&"piece_found")
	for i in 3:
		m.notify(&"piece_hung", &"climber")
	r.check(m.is_completed() and log.back() == ["completed", &"clothesline"], "mission: ultimo passo conclui e emite completed")
	r.check(not m.notify(&"piece_hung"), "mission: concluida ignora eventos")


func _test_hero_switch() -> void:
	var m := _load()[1]
	var log := _rec(m)
	m.start(&"tracker")
	r.check(log.has(["switch", &"climber", &"hero_climber"]), "mission: passo que exige Pico pede a troca ao comecar com Rastro")
	r.check(m.active_hero == &"tracker", "mission: pedido de troca nao forca o heroi")
	var n := log.size()
	m.set_active_hero(&"tracker")
	r.check(log.size() == n, "mission: pedido nao repete no mesmo passo sem nova tentativa")
	r.check(not m.notify(&"piece_freed", &"tracker"), "mission: heroi errado nao avanca o passo")
	r.check(log.back() == ["switch", &"climber", &"hero_climber"], "mission: tentativa com heroi errado pede a troca de novo")
	m.set_active_hero(&"climber")
	r.check(m.notify(&"piece_freed") and m.notify(&"piece_freed"), "mission: depois da troca o heroi certo avanca")
	r.check(log.back() == ["switch", &"tracker", &"hero_tracker"], "mission: passo seguinte (Rastro) pede a troca de volta")
	m.set_active_hero(&"tracker")
	m.notify(&"piece_found")
	n = log.size()
	m.set_active_hero(&"climber")
	r.check(log.size() == n and m.required_hero() == &"", "mission: passo sem heroi exigido aceita qualquer um, sem pedido")


func _test_emblems_and_safe_point() -> void:
	var m := _load()[1]
	var log := _rec(m)
	r.check(not m.find_emblem(&"emb_reeds"), "mission: emblema nao conta com a missao inativa")
	m.start(&"climber")
	r.check(m.find_emblem(&"emb_reeds") and log.back() == ["emblem", &"emb_reeds", 1, 2], "mission: emblema achado emite emblem_found (1 de 2)")
	r.check(not m.find_emblem(&"emb_reeds"), "mission: mesmo emblema nao conta duas vezes")
	r.check(not m.find_emblem(&"emb_outro"), "mission: emblema de fora da missao e ignorado")
	m.notify(&"piece_freed")
	r.check(m.return_to_safe_point(), "mission: passo com ponto seguro aceita voltar")
	r.check(log.back() == ["safe", &"shed_base", &"mission.sample.clothesline.obs_fall"], "mission: volta ao ponto seguro com chave de observacao")
	r.check(m.step_index == 0 and m.step_progress == 1 and m.is_active(), "mission: voltar ao ponto seguro nao perde progresso nem falha")
	m.notify(&"piece_freed")
	r.check(not m.return_to_safe_point(), "mission: passo sem ponto seguro nao volta")


func _help_log(h: MissionHelp) -> Array:
	var log: Array = []
	h.gesture_hint.connect(func(t: StringName, k: StringName) -> void: log.append(["gesture", t, k]))
	h.radio_hint.connect(func(k: StringName) -> void: log.append(["radio", k]))
	h.pointer_hint.connect(func(t: StringName, cam: bool) -> void: log.append(["pointer", t, cam]))
	h.cleared.connect(func() -> void: log.append(["cleared"]))
	return log


func _sim(h: MissionHelp, seconds: float, dt: float = 0.1) -> void:
	for i in int(round(seconds / dt)):
		h.tick(dt)


func _test_help() -> void:
	var m := _load()[1]
	var h := MissionHelp.new()
	var log := _help_log(h)
	h.attach(m)
	_sim(h, 50.0)
	r.check(log.is_empty(), "help: missao inativa nao recebe ajuda")
	m.start(&"climber")
	_sim(h, 9.9)
	r.check(log.is_empty(), "help: nada antes de 10 s")
	_sim(h, 0.2)
	r.check(log == [["gesture", &"shed_roof", &"mission.sample.clothesline.hint_gesture"]], "help: 10 s gesto + brilho no alvo")
	_sim(h, 10.0)
	r.check(log.back() == ["radio", &"mission.sample.clothesline.hint_spoken"], "help: 20 s fala do Farol 7 no radio (chave)")
	_sim(h, 15.0)
	r.check(log.back() == ["pointer", &"shed_roof", true] and h.tier == 3, "help: 35 s seta e camera apontando")
	_sim(h, 100.0)
	r.check(log.size() == 3, "help: cada degrau dispara uma vez")
	m.notify(&"piece_freed")
	r.check(h.tier == 0 and h.idle_time == 0.0 and log.back() == ["cleared"], "help: progresso zera a contagem e apaga a ajuda")
	_sim(h, 12.0)
	r.check(log.back()[0] == "gesture", "help: contagem recomeca do zero depois do progresso")
	m.find_emblem(&"emb_shed_roof")
	r.check(h.tier == 0, "help: emblema tambem conta como progresso")
	_sim(h, 9.0)
	m.notify(&"piece_freed")
	_sim(h, 10.2)
	r.check(log.back() == ["gesture", &"reeds", &"mission.sample.clothesline.hint_gesture_find"], "help: passo novo usa alvo e chaves do passo")
	var big := MissionHelp.new()
	var blog := _help_log(big)
	var m2 := _load()[0]
	big.attach(m2)
	m2.start(&"tracker")
	big.tick(40.0)
	r.check(blog.size() == 3, "help: um tick grande dispara os 3 degraus em ordem")


func _test_help_custom_and_reduced() -> void:
	var m := _load()[0]
	var h := MissionHelp.new(PackedFloat32Array([2.0, 4.0, 6.0]))
	h.reduced_motion = true
	var log := _help_log(h)
	h.attach(m)
	m.start(&"tracker")
	_sim(h, 6.1)
	r.check(log.size() == 3, "help: tempos configuraveis (2/4/6 s)")
	r.check(log.back() == ["pointer", &"boat", false], "help: movimento reduzido mostra a seta sem mover a camera")
	var bad := MissionHelp.new(PackedFloat32Array([5.0, 3.0, 1.0]))
	r.check(bad.tier_times == PackedFloat32Array([10.0, 20.0, 35.0]), "help: tempos fora de ordem caem no padrao 10/20/35")


func _test_save_load() -> void:
	var ms := _load()
	ms[0].start(&"tracker")
	ms[0].notify(&"boat_seen")
	ms[1].start(&"climber")
	ms[1].notify(&"piece_freed")
	ms[1].notify(&"piece_freed")
	ms[1].find_emblem(&"emb_reeds")
	r.check(MissionSave.save(SAVE, &"sample", ms), "save: grava em user://")
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	r.check(raw is Dictionary and int(raw["version"]) == MissionSave.VERSION and raw["current"] == "clothesline", "save: formato versionado com missao atual")
	var fresh := _load()
	var cur := MissionSave.load_into(SAVE, &"sample", fresh)
	r.check(cur == &"clothesline", "save: carga devolve a missao atual")
	r.check(fresh[0].is_completed(), "save: missao concluida volta concluida")
	r.check(fresh[1].state == Mission.State.INACTIVE and fresh[1].step_index == 0, "save: missao atual retoma do inicio (nao do meio)")
	r.check(Array(fresh[1].found_emblems) == [&"emb_reeds"], "save: emblemas achados sao mantidos")
	fresh[1].start(&"climber")
	r.check(fresh[1].step_index == 0 and fresh[1].found_emblems.size() == 1, "save: start depois da carga recomeca o passo 1 e guarda emblemas")
	r.check(MissionSave.load_into(SAVE, &"outro_ep", _load()) == &"", "save: salvo de outro episodio e ignorado")
	var f := FileAccess.open(SAVE, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 99, "episode": "sample", "current": "clothesline", "missions": []}))
	f.close()
	var untouched := _load()
	r.check(MissionSave.load_into(SAVE, &"sample", untouched) == &"" and not untouched[0].is_completed(), "save: versao desconhecida e ignorada sem mudar nada")
	f = FileAccess.open(SAVE, FileAccess.WRITE)
	f.store_string("{quebrado")
	f.close()
	r.check(MissionSave.load_into(SAVE, &"sample", _load()) == &"", "save: arquivo corrompido e ignorado")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	r.check(MissionSave.load_into(SAVE, &"sample", _load()) == &"", "save: sem arquivo nao ha missao a retomar")
	var all := _load()
	for m in all:
		m.restore({"state": Mission.State.COMPLETED})
	r.check(MissionSave.current_id(all) == &"", "save: tudo concluido nao tem missao atual")


func _test_i18n() -> void:
	var miss: Array = []
	for m in _load():
		for k in m.text_keys():
			if not Loc.has_key(k):
				miss.append(k)
	r.check(miss.is_empty(), "mission: toda chave de texto existe no catalogo %s" % [miss])
	var txt := FileAccess.get_file_as_string("res://systems/mission/mission.gd") + FileAccess.get_file_as_string("res://systems/mission/mission_help.gd")
	r.check(not txt.contains("Loc.t("), "mission: o sistema so passa chaves (quem exibe traduz)")
