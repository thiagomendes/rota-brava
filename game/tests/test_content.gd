extends RefCounted
## Conteudo (RB-02): catalogo pt-BR, dados do episodio e chaves usadas no codigo.

const CATALOG := "res://i18n/pt_BR.json"
const CONTENT := "res://episodes/ep01/ep01_content.json"
const ACTIVE_STATES: Array[String] = ["dock_investigation", "river_search", "island_crossing", "docking", "return_trip"]


func _load(path: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


## Coleta chaves de texto: valores de campos "key"/"*_key" e textos em listas que parecem chave.
func _collect_keys(node: Variant, out: Array[String]) -> void:
	if node is Dictionary:
		for k in node:
			var v: Variant = node[k]
			if v is String and (str(k) == "key" or str(k).ends_with("_key")):
				out.append(v)
			else:
				_collect_keys(v, out)
	elif node is Array:
		for item in node:
			if item is String:
				if str(item).begins_with("ep01.") or str(item).begins_with("ui."):
					out.append(item)
			else:
				_collect_keys(item, out)


func _scan(dir: String, out: Array[String]) -> void:
	for sub in DirAccess.get_directories_at(dir):
		if sub == ".godot" or (dir == "res://" and sub == "tests"):
			continue
		_scan(dir.path_join(sub), out)
	var rx := RegEx.create_from_string("Loc\\.t\\(\\s*\"([^\"]+)\"")
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			var src := FileAccess.get_file_as_string(dir.path_join(f))
			for m in rx.search_all(src):
				out.append(m.get_string(1))


func run(r) -> void:
	Loc.reload()
	var cat_v: Variant = _load(CATALOG)
	var con_v: Variant = _load(CONTENT)
	r.check(cat_v is Dictionary, "catalogo pt_BR.json carrega")
	r.check(con_v is Dictionary, "ep01_content.json carrega")
	if not (cat_v is Dictionary and con_v is Dictionary):
		return
	var cat: Dictionary = cat_v
	var con: Dictionary = con_v

	var keys: Array[String] = []
	_collect_keys(con, keys)
	r.check(keys.size() >= 30, "conteudo referencia chaves (%d)" % keys.size())
	var absent: Array[String] = []
	for k in keys:
		if not cat.has(k):
			absent.append(k)
	r.check(absent.is_empty(), "toda chave do conteudo existe no catalogo %s" % str(absent))

	var code_keys: Array[String] = []
	_scan("res://", code_keys)
	var code_absent: Array[String] = []
	for k in code_keys:
		if not cat.has(k):
			code_absent.append(k)
	r.check(code_absent.is_empty(), "todo Loc.t literal existe no catalogo (%d achados) %s" % [code_keys.size(), str(code_absent)])

	var empty: Array[String] = []
	var bad_params: Array[String] = []
	var rx := RegEx.create_from_string("\\{([a-z_]+)\\}")
	for k in cat:
		var text := str(cat[k])
		if text.strip_edges().is_empty():
			empty.append(k)
		var params := {}
		for m in rx.search_all(text):
			params[m.get_string(1)] = "X"
		if Loc.t(k, params).contains("{"):
			bad_params.append(k)
	r.check(empty.is_empty(), "nenhuma chave do catalogo vazia %s" % str(empty))
	r.check(bad_params.is_empty(), "parametros {x} sao substituiveis %s" % str(bad_params))
	r.check(Loc.t("ui.swap.look", {"name": "Rastro", "other": "Leme"}) == "Rastro olha para Leme.", "Loc.t substitui parametros nomeados")
	r.check(Loc.t("ep01.dock.tracker.small_print") == "Essa pegada cabe na palma da minha mão.", "fala de exemplo da SPEC com acentos")

	Loc.reload()
	r.check(Loc.t("nao.existe") == "nao.existe", "chave ausente devolve a propria chave")
	Loc.t("nao.existe")
	r.check(Loc.missing.count("nao.existe") == 1, "chave ausente registrada uma vez")
	r.check(not Loc.has_key("nao.existe") and Loc.has_key("ui.menu.play"), "has_key")
	Loc.language = "xx_XX"
	r.check(Loc.t("ui.menu.play") == "Jogar", "idioma sem catalogo cai em pt_BR")
	Loc.language = "pt_BR"
	Loc.reload()

	var states: Array = con.get("states", [])
	r.check(states.size() == 7, "7 estados no conteudo")
	for s in states:
		var obj: Dictionary = con.get("objectives", {}).get(s, {})
		r.check(obj.has("objective_key") and obj.has("icon"), "estado %s tem objetivo e icone" % s)
		r.check(con.get("active_member", {}).has(s), "estado %s define integrante ativo" % s)
	for s in ACTIVE_STATES:
		var kinds: Array[String] = []
		for h in con.get("hints", {}).get(s, []):
			kinds.append(str(h.get("kind")))
		r.check(kinds.has("gesture") and kinds.has("spoken"), "estado %s tem dica de gesto e falada" % s)

	var voices := 0
	for k in cat:
		if str(k).begins_with("ep01.") and (".pilot." in k or ".tracker." in k or ".climber." in k):
			voices += 1
	r.check(voices >= 6, "ao menos 6 falas de Leme/Rastro/Pico (%d)" % voices)

	var clue_ids: Array[String] = []
	for c in con.get("clues", []):
		clue_ids.append(str(c.get("id")))
		r.check(c.get("resolves_deduction_alone") == false, "pista %s nao resolve sozinha" % c.get("id"))
	r.check(clue_ids.has("paw_print_bench") and clue_ids.has("boot_print_bank"), "pistas pata e bota")
	r.check(con.get("footholds", []).size() == 3, "3 apoios")
