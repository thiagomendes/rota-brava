extends RefCounted
## G13 (RB-R1): 3 espacos de jogo. Caminhos por espaco, migracao do salvo antigo para o espaco 1 (uma vez, sem perder
## nada), resumo do cartao (missao, emblemas, heroi), jogo novo, apagar e cenas vistas por espaco. Arquivos de teste
## com prefixo proprio; os espacos do jogador nunca sao tocados. Nao comprova render nem UX.

const PREFIX := "user://test_slots_"
const LEGACY_SAVE := "user://test_slots_legacy_missions.save.json"
const LEGACY_SEEN := "user://test_slots_legacy_cutscenes.seen.json"

var r


func run(runner) -> void:
	r = runner
	var keep_prefix := SaveSlots.prefix
	SaveSlots.prefix = PREFIX
	_clean()
	_paths()
	_migration()
	_summary_and_new()
	_seen_per_slot()
	_clean()
	SaveSlots.prefix = keep_prefix
	SaveSlots.active = 0
	Ep01V3Main.save_path = ""
	Ep01V3Cutscene.seen_path = ""
	Ep01V3Cutscene.reset_seen()


func _clean() -> void:
	for i in SaveSlots.COUNT:
		SaveSlots.erase(i + 1)
	for p: String in [LEGACY_SAVE, LEGACY_SEEN]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


func _write(path: String, data: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()


## Salvo no formato do MissionSave: M0 e M1 concluidas (emblema do M1), M2 com um dos 2 emblemas.
func _legacy_data() -> Dictionary:
	return {"version": MissionSave.VERSION, "episode": "ep01", "current": "M2", "missions": [
		{"id": "M0", "state": Mission.State.COMPLETED, "emblems": []},
		{"id": "M1", "state": Mission.State.COMPLETED, "emblems": ["emb_m1_mooring"]},
		{"id": "M2", "state": Mission.State.INACTIVE, "emblems": ["emb_m2_shed"]}]}


func _paths() -> void:
	SaveSlots.prefix = "user://"
	r.check(SaveSlots.COUNT == 3, "slots: 3 espacos de jogo")
	r.check(SaveSlots.save_path(1) == "user://slot_1.save.json" and SaveSlots.save_path(3) == "user://slot_3.save.json",
		"slots: salvo em user://slot_1.save.json ate slot_3")
	r.check(SaveSlots.seen_path(2) == "user://slot_2.cutscenes.seen.json", "slots: cenas vistas por espaco (slot_2)")
	r.check(MissionSave.DEFAULT_PATH == SaveSlots.save_path(1) and Ep01V3Cutscene.DEFAULT_SEEN_PATH == SaveSlots.seen_path(1),
		"slots: o padrao do jogo e o espaco 1 (salvo e vistas)")
	r.check(SaveSlots.LEGACY_SAVE == "user://missions.save.json" and SaveSlots.LEGACY_SEEN == "user://cutscenes.seen.json",
		"slots: migracao le os arquivos antigos de verdade")
	SaveSlots.prefix = PREFIX


func _migration() -> void:
	_clean()
	_write(LEGACY_SAVE, _legacy_data())
	_write(LEGACY_SEEN, {"version": Ep01V3Cutscene.SEEN_VERSION, "seen": ["game_intro", "m1_intro"]})
	var before := FileAccess.get_file_as_string(LEGACY_SAVE)
	r.check(SaveSlots.migrate(LEGACY_SAVE, LEGACY_SEEN), "migracao: o salvo antigo vira o espaco 1")
	r.check(FileAccess.get_file_as_string(SaveSlots.save_path(1)) == before, "migracao: o espaco 1 tem o salvo antigo inteiro (byte a byte)")
	r.check(FileAccess.file_exists(SaveSlots.seen_path(1)), "migracao: as cenas vistas antigas vao para o espaco 1")
	r.check(not FileAccess.file_exists(LEGACY_SAVE) and not FileAccess.file_exists(LEGACY_SEEN), "migracao: os arquivos antigos saem (movidos)")
	r.check(not SaveSlots.has_save(2) and not SaveSlots.has_save(3), "migracao: espacos 2 e 3 continuam vazios")
	var s := SaveSlots.summary(1)
	r.check(not s["empty"] and s["mission"] == &"M2" and s["emblems_found"] == 2,
		"migracao: nada perdido, o espaco 1 continua no M2 com 2 emblemas (%s)" % str(s))
	# uma unica vez: outra chamada nao faz nada (e um antigo que reapareca nao sobrescreve o espaco 1)
	r.check(not SaveSlots.migrate(LEGACY_SAVE, LEGACY_SEEN), "migracao: segunda chamada nao faz nada")
	_write(LEGACY_SAVE, {"version": MissionSave.VERSION, "episode": "ep01", "current": "M0", "missions": []})
	r.check(not SaveSlots.migrate(LEGACY_SAVE, LEGACY_SEEN) and FileAccess.get_file_as_string(SaveSlots.save_path(1)) == before,
		"migracao: com o espaco 1 ocupado, o antigo nao sobrescreve nada")
	r.check(FileAccess.file_exists(LEGACY_SAVE), "migracao: e o antigo fica onde estava (nada apagado)")
	# so as cenas vistas antigas: o espaco 1 nasce no comeco, com as vistas
	_clean()
	_write(LEGACY_SEEN, {"version": Ep01V3Cutscene.SEEN_VERSION, "seen": ["game_intro"]})
	r.check(SaveSlots.migrate(LEGACY_SAVE, LEGACY_SEEN) and SaveSlots.summary(1).get("mission") == &"M0"
		and FileAccess.file_exists(SaveSlots.seen_path(1)), "migracao: so vistas antigas -> espaco 1 no M0 com as vistas")
	_clean()
	r.check(not SaveSlots.migrate(LEGACY_SAVE, LEGACY_SEEN), "migracao: sem arquivo antigo nao faz nada")


func _summary_and_new() -> void:
	_clean()
	var e := SaveSlots.summary(2)
	r.check(e["empty"] and e["emblems_total"] == 10, "resumo: espaco sem arquivo e vazio (total de emblemas 10)")
	_write(SaveSlots.save_path(2), _legacy_data())
	var s := SaveSlots.summary(2)
	r.check(not s["empty"] and s["mission"] == &"M2" and s["title_key"] == "ep01v3.mission.M2.title" and s["icon"] == &"rope",
		"resumo: missao atual M2 com nome e icone dos dados do Ep01 v3")
	r.check(Loc.has_key(str(s["title_key"])), "resumo: nome da missao existe no i18n")
	r.check(s["emblems_found"] == 2 and s["emblems_total"] == 10, "resumo: emblemas 2/10")
	r.check(s["hero"] == &"climber" and str(s["portrait"]) == "res://ui/portraits/pico_neutra.png"
		and ResourceLoader.exists(str(s["portrait"])), "resumo: retrato do heroi que comeca a missao (Pico no M2), do HUD")
	# corrompido conta como vazio (nao trava o cartao)
	_write(SaveSlots.save_path(3), {"version": 999})
	r.check(SaveSlots.summary(3)["empty"], "resumo: salvo de outra versao conta como vazio")
	# tudo concluido: festa completa
	var all: Array = []
	for m in Mission.load_list(SaveSlots.MISSIONS_PATH):
		all.append({"id": String(m.id), "state": Mission.State.COMPLETED, "emblems": Array(m.emblems).map(func(x: StringName) -> String: return String(x))})
	_write(SaveSlots.save_path(3), {"version": MissionSave.VERSION, "episode": "ep01", "current": "", "missions": all})
	var c := SaveSlots.summary(3)
	r.check(not c["empty"] and c["complete"] and c["emblems_found"] == 10, "resumo: episodio completo com 10/10")
	# jogo novo: apaga o que havia e comeca no M0, ja aparecendo no cartao
	SaveSlots.start_new(2)
	var n := SaveSlots.summary(2)
	r.check(not n["empty"] and n["mission"] == &"M0" and n["emblems_found"] == 0, "novo jogo: espaco comeca no M0 com 0 emblemas")
	r.check(SaveSlots.active == 2 and Ep01V3Main.save_path == SaveSlots.save_path(2) and Ep01V3Cutscene.seen_path == SaveSlots.seen_path(2),
		"novo jogo: o Ep01 grava no espaco escolhido (salvo e vistas)")
	SaveSlots.select(3)
	r.check(Ep01V3Main.save_path == SaveSlots.save_path(3), "continuar: selecionar aponta o Ep01 para o espaco 3")
	SaveSlots.erase(3)
	r.check(not SaveSlots.has_save(3) and SaveSlots.summary(3)["empty"], "apagar: o espaco volta a ser vazio")
	r.check(SaveSlots.has_save(2), "apagar: os outros espacos ficam")


func _seen_per_slot() -> void:
	_clean()
	Ep01V3Cutscene.enabled = true
	SaveSlots.start_new(1)
	r.check(GameIntroScene.play_target() == GameIntroScene.SELF_SCENE, "vistas: espaco novo abre a abertura")
	Ep01V3Cutscene.mark_seen(&"game_intro")
	Ep01V3Cutscene.mark_seen(&"m1_intro")
	r.check(GameIntroScene.play_target() == GameIntroScene.EP01_SCENE and FileAccess.file_exists(SaveSlots.seen_path(1)),
		"vistas: depois de vista no espaco 1, Jogar vai direto ao Ep01 (gravado no espaco 1)")
	SaveSlots.start_new(2)
	r.check(GameIntroScene.play_target() == GameIntroScene.SELF_SCENE and not Ep01V3Cutscene.is_seen(&"m1_intro"),
		"vistas: o espaco 2 (jogo novo) ve a abertura e as cenas de novo")
	SaveSlots.select(1)
	r.check(Ep01V3Cutscene.is_seen(&"game_intro") and Ep01V3Cutscene.is_seen(&"m1_intro"), "vistas: voltar ao espaco 1 lembra as dele")
	SaveSlots.start_new(1)
	r.check(not Ep01V3Cutscene.is_seen(&"game_intro"), "vistas: novo jogo por cima do espaco 1 esquece as vistas dele")
	Ep01V3Cutscene.enabled = false
