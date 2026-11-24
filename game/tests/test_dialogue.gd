extends RefCounted
## Dialogos (RB-R1): balbucio com emotes e legenda, e instrucoes faladas de Farol 7 no radio.

const DIALOGUE := "res://episodes/ep01/ep01_dialogue.json"
const RADIO := "res://i18n/pt_BR.radio.json"
const CATALOG := "res://i18n/pt_BR.json"
const CONTENT := "res://episodes/ep01/ep01_content.json"
const INTENTS: Array[String] = ["normal", "urgencia", "descoberta", "pergunta", "alegria", "dica", "narracao"]
const MAX_WORDS := 14


func _load(path: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func _words(text: String) -> int:
	return text.strip_edges().split(" ", false).size()


## Chaves de fala de ep01_content.json: listas de `lines` e chaves de `hints`.
func _content_keys(con: Dictionary) -> Array[String]:
	var keys: Array[String] = []
	var lines: Dictionary = con.get("lines", {})
	for state in lines:
		var events: Dictionary = lines[state]
		for event in events:
			for key in events[event]:
				keys.append(str(key))
	var hints: Dictionary = con.get("hints", {})
	for state in hints:
		for hint in hints[state]:
			keys.append(str(hint.get("key")))
	return keys


func run(r) -> void:
	Loc.reload()
	var dial_v: Variant = _load(DIALOGUE)
	var radio_v: Variant = _load(RADIO)
	r.check(dial_v is Dictionary, "ep01_dialogue.json carrega como Dictionary")
	r.check(radio_v is Dictionary, "pt_BR.radio.json carrega como Dictionary")
	if not (dial_v is Dictionary and radio_v is Dictionary):
		return
	var dial: Dictionary = dial_v
	var radio: Dictionary = radio_v
	var lines: Dictionary = dial.get("lines", {})
	var speakers: Dictionary = dial.get("speakers", {})
	var emotes: Array = dial.get("emotes", [])
	r.check(lines.size() > 0, "ep01_dialogue.json tem linhas (%d)" % lines.size())
	r.check(radio.size() > 0, "pt_BR.radio.json tem chaves (%d)" % radio.size())

	var con_v: Variant = _load(CONTENT)
	r.check(con_v is Dictionary, "ep01_content.json carrega")
	if not (con_v is Dictionary):
		return
	var con: Dictionary = con_v

	# 2. Toda fala e toda dica do conteudo tem entrada no dialogo.
	var wanted := _content_keys(con)
	var absent: Array[String] = []
	for key in wanted:
		if not lines.has(key):
			absent.append(key)
	r.check(wanted.size() >= 40, "conteudo lista falas e dicas (%d)" % wanted.size())
	r.check(absent.is_empty(), "toda fala e dica do conteudo tem entrada no dialogo, ausentes %s" % str(absent))

	# 3. Falante = terceiro segmento da chave (exceto ep01.complete.* = team) e existe em speakers.
	var bad_speaker: Array[String] = []
	var bad_segment: Array[String] = []
	for key in lines:
		var entry: Dictionary = lines[key]
		var speaker := str(entry.get("speaker", ""))
		var parts := str(key).split(".")
		var expected := "team" if str(key).begins_with("ep01.complete.") else (parts[2] if parts.size() > 2 else "")
		if speaker != expected:
			bad_segment.append("%s=%s (esperado %s)" % [key, speaker, expected])
		if not speakers.has(speaker):
			bad_speaker.append("%s=%s" % [key, speaker])
	r.check(bad_segment.is_empty(), "falante e o terceiro segmento da chave %s" % str(bad_segment))
	r.check(bad_speaker.is_empty(), "todo falante existe em speakers %s" % str(bad_speaker))

	# 4. Intent valido e emotes de 1 a 3 itens, todos da lista.
	var bad_intent: Array[String] = []
	var bad_emotes: Array[String] = []
	for key in lines:
		var entry: Dictionary = lines[key]
		var intent := str(entry.get("intent", ""))
		if not INTENTS.has(intent):
			bad_intent.append("%s=%s" % [key, intent])
		var list: Variant = entry.get("emotes", null)
		if not (list is Array):
			bad_emotes.append("%s sem lista de emotes" % key)
			continue
		var arr: Array = list
		if arr.is_empty() or arr.size() > 3:
			bad_emotes.append("%s com %d emotes" % [key, arr.size()])
		for item in arr:
			if not emotes.has(item):
				bad_emotes.append("%s com emote desconhecido %s" % [key, str(item)])
	r.check(bad_intent.is_empty(), "intent valido %s" % str(bad_intent))
	r.check(bad_emotes.is_empty(), "emotes de 1 a 3 itens da lista %s" % str(bad_emotes))

	# 5. radio_key nao nulo existe no catalogo, esta no arquivo do radio e cabe em 14 palavras.
	var bad_radio: Array[String] = []
	var long_radio: Array[String] = []
	var used_radio: Array[String] = []
	for key in lines:
		var entry: Dictionary = lines[key]
		if not entry.has("radio_key"):
			bad_radio.append("%s sem campo radio_key" % key)
			continue
		var radio_key: Variant = entry["radio_key"]
		if radio_key == null:
			continue
		var rk := str(radio_key)
		used_radio.append(rk)
		if not Loc.has_key(rk):
			bad_radio.append("%s usa %s (nao existe)" % [key, rk])
		elif not radio.has(rk):
			bad_radio.append("%s usa %s (fora de pt_BR.radio.json)" % [key, rk])
		elif _words(str(radio[rk])) > MAX_WORDS:
			long_radio.append("%s tem %d palavras" % [rk, _words(str(radio[rk]))])
	r.check(used_radio.size() >= 10, "dialogo usa falas do radio (%d usos)" % used_radio.size())
	r.check(bad_radio.is_empty(), "todo radio_key nao nulo existe no catalogo %s" % str(bad_radio))
	r.check(long_radio.is_empty(), "texto de radio tem no maximo %d palavras %s" % [MAX_WORDS, str(long_radio)])

	# 6. Dica de personagem que balbucia tem fala correspondente no radio.
	var missing_radio: Array[String] = []
	for key in lines:
		var entry: Dictionary = lines[key]
		var speaker := str(entry.get("speaker", ""))
		var voice := str(speakers.get(speaker, {}).get("voice", ""))
		if voice == "babble" and str(entry.get("intent", "")) == "dica" and entry.get("radio_key", null) == null:
			missing_radio.append(str(key))
	r.check(missing_radio.is_empty(), "dica de balbucio tem radio_key %s" % str(missing_radio))

	# 7. Cada estado jogavel tem objetivo falado por Farol 7.
	var playable: Array[String] = []
	for s in con.get("states", []):
		if str(s) != "complete":
			playable.append(str(s))
	var missing_objective: Array[String] = []
	var long_objective: Array[String] = []
	for state in playable:
		var key := "ep01.radio.objective." + state
		if not Loc.has_key(key):
			missing_objective.append(key)
		elif _words(Loc.t(key)) > MAX_WORDS:
			long_objective.append("%s tem %d palavras" % [key, _words(Loc.t(key))])
	r.check(playable.size() == 6, "conteudo tem 6 estados jogaveis (%d)" % playable.size())
	r.check(missing_objective.is_empty(), "todo estado jogavel tem objetivo falado %s" % str(missing_objective))
	r.check(long_objective.is_empty(), "objetivo falado tem no maximo %d palavras %s" % [MAX_WORDS, str(long_objective)])

	# 8. Nenhuma chave do radio repete o catalogo base.
	var base_v: Variant = _load(CATALOG)
	r.check(base_v is Dictionary, "pt_BR.json carrega")
	var duplicate: Array[String] = []
	if base_v is Dictionary:
		var base: Dictionary = base_v
		for k in radio:
			if base.has(k):
				duplicate.append(str(k))
	r.check(duplicate.is_empty(), "nenhuma chave do radio existe em pt_BR.json %s" % str(duplicate))
	var off_pattern: Array[String] = []
	for k in radio:
		var parts := str(k).split(".")
		if parts.size() != 4 or parts[0] != "ep01" or parts[1] != "radio":
			off_pattern.append(str(k))
	r.check(off_pattern.is_empty(), "chave do radio segue ep01.radio.<local>.<id> %s" % str(off_pattern))

	Loc.reload()
