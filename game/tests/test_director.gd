extends RefCounted
## Testes do EpisodeDirector (RB-02, criterio 1).

var _log: Array = []


func _d() -> EpisodeDirector:
	return EpisodeDirector.new()


func _go(d: EpisodeDirector, to: StringName) -> void:
	var steps: Array = [
		[&"intro_finished", &"x", {}, &"dock_investigation"],
		[&"clue_examined", &"tracker", {"clue_id": &"paw_print_bench"}, &""],
		[&"clue_examined", &"tracker", {"clue_id": &"boot_print_bank"}, &""],
		[&"destination_chosen", &"tracker", {"destination": &"bank"}, &"river_search"],
		[&"buoy_rounded", &"pilot", {}, &""],
		[&"cove_reached", &"pilot", {}, &"island_crossing"],
		[&"foothold_reached", &"climber", {"index": 1}, &""],
		[&"foothold_reached", &"climber", {"index": 2}, &""],
		[&"foothold_reached", &"climber", {"index": 3}, &""],
		[&"line_fixed", &"climber", {}, &"docking"],
		[&"boat_docked", &"pilot", {"aligned": true}, &"return_trip"],
		[&"departure_confirmed", &"pilot", {}, &"complete"],
	]
	for s in steps:
		if d.state == to:
			return
		d.submit(s[0], s[1], s[2])


func _rej(r, d: EpisodeDirector, ev: StringName, src: StringName, p: Dictionary, reason: StringName, label: String) -> void:
	var before := d.snapshot()
	var res := d.submit(ev, src, p)
	r.check(not res["accepted"] and res["reason"] == reason and not res["state_changed"], label + " rejeitado: " + String(reason))
	r.check(d.snapshot() == before, label + " nao altera estado")


func run(r) -> void:
	var d := _d()
	r.check(d.state == &"arrival" and d.active_member == &"", "inicio em arrival sem ativo")

	# Pular abertura = mesmo evento, qualquer fonte.
	for src in [&"", &"skip", &"timer"]:
		var d0 := _d()
		var res := d0.submit(&"intro_finished", src)
		r.check(res["accepted"] and d0.state == &"dock_investigation" and d0.active_member == &"tracker", "intro_finished fonte '%s' -> dock" % src)

	# Pistas em ambas as ordens.
	var orders: Array = [[&"paw_print_bench", &"boot_print_bank"], [&"boot_print_bank", &"paw_print_bench"]]
	for o in orders:
		var da := _d()
		_go(da, &"dock_investigation")
		for c in o:
			var res := da.submit(&"clue_examined", &"tracker", {"clue_id": c})
			r.check(res["accepted"] and not res["state_changed"], "pista %s aceita" % c)
		r.check(da.clues_found.size() == 2 and da.clues_found.has(&"paw_print_bench") and da.clues_found.has(&"boot_print_bank"), "duas pistas guardadas")
		var rb := da.submit(&"destination_chosen", &"tracker", {"destination": &"bank"})
		r.check(rb["accepted"] and da.state == &"river_search" and da.active_member == &"pilot", "margem com 2 pistas (%s primeiro) avanca" % o[0])

	# Margem com 0 e 1 pista.
	d = _d()
	_go(d, &"dock_investigation")
	_rej(r, d, &"destination_chosen", &"tracker", {"destination": &"bank"}, &"missing_prerequisite", "margem com 0 pistas")
	d.submit(&"clue_examined", &"tracker", {"clue_id": &"paw_print_bench"})
	_rej(r, d, &"destination_chosen", &"tracker", {"destination": &"bank"}, &"missing_prerequisite", "margem com 1 pista")
	_rej(r, d, &"destination_chosen", &"tracker", {"destination": &"harbor"}, &"wrong_destination", "harbor com 1 pista")
	d.submit(&"clue_examined", &"tracker", {"clue_id": &"boot_print_bank"})
	_rej(r, d, &"destination_chosen", &"tracker", {"destination": &"harbor"}, &"wrong_destination", "harbor com 2 pistas")
	_rej(r, d, &"destination_chosen", &"tracker", {"destination": &"mars"}, &"invalid_payload", "destino desconhecido")
	_rej(r, d, &"destination_chosen", &"tracker", {}, &"invalid_payload", "destino ausente")

	# Duplicado: sem progresso nem sinal event_accepted.
	d = _d()
	_go(d, &"dock_investigation")
	d.submit(&"clue_examined", &"tracker", {"clue_id": &"paw_print_bench"})
	_log = []
	d.event_accepted.connect(func(e, _p): _log.append(e))
	_rej(r, d, &"clue_examined", &"tracker", {"clue_id": &"paw_print_bench"}, &"duplicate", "pista duplicada")
	r.check(_log.is_empty() and d.clues_found.size() == 1, "duplicado sem event_accepted nem progresso")
	var rej_log: Array = []
	d.event_rejected.connect(func(e, why): rej_log.append([e, why]))
	d.submit(&"clue_examined", &"tracker", {"clue_id": &"paw_print_bench"})
	r.check(rej_log == [[&"clue_examined", &"duplicate"]], "event_rejected emitido com motivo")

	# Membro inativo, estado errado, payload invalido.
	_rej(r, d, &"clue_examined", &"pilot", {"clue_id": &"boot_print_bank"}, &"wrong_member", "pista pelo piloto")
	_rej(r, d, &"clue_examined", &"climber", {"clue_id": &"boot_print_bank"}, &"wrong_member", "pista pelo escalador")
	_rej(r, d, &"buoy_rounded", &"pilot", {}, &"wrong_state", "boia no dock")
	_rej(r, d, &"intro_finished", &"x", {}, &"wrong_state", "intro repetida")
	_rej(r, d, &"departure_confirmed", &"pilot", {}, &"wrong_state", "partida no dock")
	_rej(r, d, &"clue_examined", &"tracker", {"clue_id": &"nada"}, &"invalid_payload", "pista desconhecida")
	_rej(r, d, &"clue_examined", &"tracker", {}, &"invalid_payload", "pista sem payload")
	_rej(r, d, &"clue_examined", &"tracker", {"clue_id": 3}, &"invalid_payload", "pista com tipo errado")
	_rej(r, d, &"evento_que_nao_existe", &"tracker", {}, &"invalid_payload", "evento desconhecido")
	var da2 := _d()
	_rej(r, da2, &"clue_examined", &"tracker", {"clue_id": &"paw_print_bench"}, &"wrong_state", "pista em arrival")

	# Rio.
	d = _d()
	_go(d, &"river_search")
	_rej(r, d, &"cove_reached", &"pilot", {}, &"missing_prerequisite", "enseada sem boia")
	_rej(r, d, &"buoy_rounded", &"tracker", {}, &"wrong_member", "boia pelo Rastro")
	var rbuoy := d.submit(&"buoy_rounded", &"pilot")
	r.check(rbuoy["accepted"] and d.buoy_rounded and d.state == &"river_search", "boia marcada sem mudar estado")
	_rej(r, d, &"buoy_rounded", &"pilot", {}, &"duplicate", "boia duplicada")
	var rc := d.submit(&"cove_reached", &"pilot")
	r.check(rc["accepted"] and rc["state_changed"] and d.state == &"island_crossing" and d.active_member == &"climber", "enseada com boia -> ilha, ativo climber")

	# Ilha.
	_rej(r, d, &"foothold_reached", &"climber", {"index": 2}, &"out_of_order", "apoio 2 antes do 1")
	_rej(r, d, &"foothold_reached", &"climber", {"index": 3}, &"out_of_order", "apoio 3 antes do 1")
	_rej(r, d, &"foothold_reached", &"climber", {"index": 0}, &"invalid_payload", "apoio 0")
	_rej(r, d, &"foothold_reached", &"climber", {"index": 4}, &"invalid_payload", "apoio 4")
	_rej(r, d, &"foothold_reached", &"climber", {}, &"invalid_payload", "apoio sem indice")
	_rej(r, d, &"foothold_reached", &"pilot", {"index": 1}, &"wrong_member", "apoio pelo piloto")
	var m0 := d.submit(&"foothold_missed", &"climber")
	r.check(m0["accepted"] and m0["respawn_foothold"] == 0 and d.state == &"island_crossing" and d.last_safe_foothold == 0, "queda antes do 1: respawn 0")
	d.submit(&"foothold_reached", &"climber", {"index": 1})
	d.submit(&"foothold_reached", &"climber", {"index": 2})
	r.check(d.last_safe_foothold == 2, "ultimo seguro = 2")
	var m2 := d.submit(&"foothold_missed", &"climber")
	r.check(m2["accepted"] and m2["respawn_foothold"] == 2 and d.last_safe_foothold == 2 and not m2["state_changed"], "queda: respawn = ultimo seguro (2), sem avancar")
	_rej(r, d, &"foothold_reached", &"climber", {"index": 2}, &"duplicate", "apoio 2 duplicado")
	_rej(r, d, &"line_fixed", &"climber", {}, &"missing_prerequisite", "linha sem apoio 3")
	r.check(not d.line_fixed, "line_fixed segue falso")
	d.submit(&"foothold_reached", &"climber", {"index": 3})
	var lf := d.submit(&"line_fixed", &"climber")
	r.check(lf["accepted"] and d.line_fixed and d.state == &"docking" and d.active_member == &"pilot", "linha com apoio 3 -> docking, ativo pilot")

	# Atracar.
	_rej(r, d, &"boat_docked", &"pilot", {"aligned": false}, &"missing_prerequisite", "atracar desalinhado")
	_rej(r, d, &"boat_docked", &"pilot", {}, &"invalid_payload", "atracar sem aligned")
	_rej(r, d, &"boat_docked", &"pilot", {"aligned": "sim"}, &"invalid_payload", "aligned nao-bool")
	_rej(r, d, &"boat_docked", &"climber", {"aligned": true}, &"wrong_member", "atracar pelo escalador")
	var dk := d.submit(&"boat_docked", &"pilot", {"aligned": true})
	r.check(dk["accepted"] and d.state == &"return_trip" and d.active_member == &"pilot", "atracar alinhado -> return_trip")
	# Sem linha (estado forcado via restore consistente nao existe; usa snapshot adulterado rejeitado).
	var bad := d.snapshot()
	bad["state"] = "docking"
	bad["line_fixed"] = false
	var d_nl := _d()
	r.check(not d_nl.restore(bad), "restore docking sem linha e rejeitado (atracar sem linha inalcancavel)")

	# Percurso completo com sinais.
	d = _d()
	var sc: Array = []
	var am: Array = []
	var done: Array = [0]
	d.state_changed.connect(func(o, n): sc.append([o, n]))
	d.active_member_changed.connect(func(m): am.append(m))
	d.episode_completed.connect(func(): done[0] += 1)
	var expected_member := {
		&"arrival": &"", &"dock_investigation": &"tracker", &"river_search": &"pilot",
		&"island_crossing": &"climber", &"docking": &"pilot", &"return_trip": &"pilot", &"complete": &"",
	}
	var visited: Array = []
	for st in EpisodeDirector.STATES:
		_go(d, st)
		visited.append(d.state)
		r.check(d.state == st and d.active_member == expected_member[st], "estado %s com ativo '%s'" % [st, expected_member[st]])
	r.check(visited == EpisodeDirector.STATES, "percurso passa por todos os estados em ordem")
	r.check(sc.size() == 6 and sc[0] == [&"arrival", &"dock_investigation"] and sc[5] == [&"return_trip", &"complete"], "6 sinais state_changed em ordem")
	r.check(am == [&"tracker", &"pilot", &"climber", &"pilot", &""], "active_member_changed so quando muda (pilot->pilot nao emite)")
	r.check(done[0] == 1 and d.completed_episodes == [&"ep01"], "episode_completed 1x e ep01 registrado")
	_rej(r, d, &"departure_confirmed", &"pilot", {}, &"wrong_state", "partida repetida em complete")

	# start_new_run preserva conclusoes; segundo percurso nao duplica.
	d.start_new_run()
	r.check(d.state == &"arrival" and d.active_member == &"" and d.clues_found.is_empty() and not d.line_fixed and not d.buoy_rounded and d.last_safe_foothold == 0, "start_new_run zera execucao")
	r.check(d.completed_episodes == [&"ep01"], "start_new_run preserva completed_episodes")
	_go(d, &"complete")
	r.check(d.state == &"complete" and d.completed_episodes == [&"ep01"] and d.completed_episodes.size() == 1, "segundo percurso nao duplica registro")
	d.start_new_run()
	var fresh := _d()
	fresh.start_new_run()
	r.check(fresh.completed_episodes.is_empty(), "start_new_run sem conclusao nao registra nada")

	# Snapshot/restore em cada estado (ciclo fechado).
	for st in EpisodeDirector.STATES:
		var src := _d()
		_go(src, st)
		if st == &"island_crossing":
			src.submit(&"foothold_reached", &"climber", {"index": 1})
		var snap := src.snapshot()
		r.check(snap.get("schema_version") != null and snap["state"] == String(st), "snapshot de %s traz schema_version e state" % st)
		var dst := _d()
		var ok := dst.restore(snap)
		r.check(ok and dst.state == st and dst.active_member == expected_member[st], "restore %s ok, ativo correto" % st)
		r.check(dst.snapshot() == snap, "ciclo snapshot->restore->snapshot igual em %s" % st)
		# JSON ida e volta (floats).
		var viajado: Dictionary = JSON.parse_string(JSON.stringify(snap))
		var dj := _d()
		r.check(dj.restore(viajado) and dj.snapshot() == snap, "restore via JSON em %s" % st)
	var sn_mid := _d()
	_go(sn_mid, &"island_crossing")
	sn_mid.submit(&"foothold_reached", &"climber", {"index": 1})
	sn_mid.submit(&"foothold_reached", &"climber", {"index": 2})
	var rs := _d()
	rs.restore(sn_mid.snapshot())
	r.check(rs.last_safe_foothold == 2 and rs.buoy_rounded and rs.clues_found.size() == 2, "restore mantem apoio, boia e pistas")
	r.check(rs.submit(&"foothold_reached", &"climber", {"index": 3})["accepted"], "jogo continua apos restore")
	# Restore preserva conclusoes anteriores.
	var comp := _d()
	_go(comp, &"complete")
	comp.start_new_run()
	var s_new := comp.snapshot()
	var rn := _d()
	r.check(rn.restore(s_new) and rn.completed_episodes == [&"ep01"] and rn.state == &"arrival", "restore de nova execucao com ep01 concluido")

	# Restore invalido mantem estado.
	var base := _d()
	_go(base, &"island_crossing")
	base.submit(&"foothold_reached", &"climber", {"index": 1})
	var keep := base.snapshot()
	var good := keep.duplicate(true)
	var cases: Dictionary = {}
	var c1 := good.duplicate(true); c1["schema_version"] = 99; cases["versao desconhecida"] = c1
	var c2 := good.duplicate(true); c2.erase("schema_version"); cases["sem versao"] = c2
	var c3 := good.duplicate(true); c3["state"] = "voando"; cases["estado desconhecido"] = c3
	var c4 := good.duplicate(true); c4["state"] = 5; cases["estado tipo errado"] = c4
	var c5 := good.duplicate(true); c5["clues_found"] = ["paw_print_bench", "fantasma"]; cases["pista desconhecida"] = c5
	var c6 := good.duplicate(true); c6["clues_found"] = "paw"; cases["pistas nao lista"] = c6
	var c7 := good.duplicate(true); c7["last_safe_foothold"] = 7; cases["apoio fora do intervalo"] = c7
	var c8 := good.duplicate(true); c8["line_fixed"] = "yes"; cases["line_fixed nao bool"] = c8
	var c9 := good.duplicate(true); c9["state"] = "docking"; c9["last_safe_foothold"] = 1; cases["docking incoerente"] = c9
	var c10 := good.duplicate(true); c10["clues_found"] = ["paw_print_bench"]; cases["ilha com 1 pista"] = c10
	var c11 := good.duplicate(true); c11["completed_episodes"] = ["ep99"]; cases["episodio desconhecido"] = c11
	var c12 := good.duplicate(true); c12["clues_found"] = ["paw_print_bench", "paw_print_bench"]; cases["pista repetida"] = c12
	var c13 := good.duplicate(true); c13.erase("buoy_rounded"); cases["sem boia"] = c13
	var c14 := good.duplicate(true); c14["state"] = "complete"; c14["completed_episodes"] = []; cases["complete sem registro"] = c14
	for k in cases:
		var t := _d()
		_go(t, &"island_crossing")
		t.submit(&"foothold_reached", &"climber", {"index": 1})
		var res := t.restore(cases[k])
		r.check(not res, "restore invalido (%s) devolve false" % k)
		r.check(t.snapshot() == keep and t.active_member == &"climber", "restore invalido (%s) mantem estado" % k)
	r.check(not _d().restore({}), "restore de dicionario vazio devolve false")
