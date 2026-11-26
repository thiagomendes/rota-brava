extends RefCounted
## Procedencia (RB-R1 D3): todo WAV/OGG em res://audio tem linha em source_audio/PROVENANCE.md com licenca
## CC0-1.0 ou "original"; nenhuma outra licenca aparece nas linhas de arquivo.

const PROVENANCE := "../source_audio/PROVENANCE.md"
## "gerado (Lyria)": trilha gerada pela Gemini API, aprovada por Thiago (D20/D20a); termos de uso a confirmar.
const ALLOWED: Array[String] = ["CC0-1.0", "original", "original (TTS)", "gerado (Lyria)", "gerado (Gemini TTS)"]


func _audio_files(dir: String, out: Array[String]) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f in d.get_files():
		if f.get_extension() in ["wav", "ogg"]:
			out.append(dir.path_join(f))
	for sub in d.get_directories():
		_audio_files(dir.path_join(sub), out)


func run(r) -> void:
	var path := ProjectSettings.globalize_path("res://").path_join(PROVENANCE).simplify_path()
	r.check(FileAccess.file_exists(path), "procedencia: PROVENANCE.md existe (%s)" % path)
	var rows: Dictionary = {}
	var bad_license: Array[String] = []
	for line in FileAccess.get_file_as_string(path).split("\n"):
		if not line.begins_with("| `res://audio/"):
			continue
		var cells := line.split("|")
		if cells.size() < 5:
			continue
		var file := cells[1].strip_edges().trim_prefix("`").trim_suffix("`")
		var lic := cells[2].strip_edges()
		rows[file] = lic
		if not ALLOWED.has(lic):
			bad_license.append(file + " (" + lic + ")")
	var files: Array[String] = []
	_audio_files("res://audio", files)
	var missing: Array[String] = []
	for f in files:
		if not rows.has(f):
			missing.append(f)
	r.check(files.size() >= 100, "procedencia: varre os arquivos de audio do jogo (%d)" % files.size())
	r.check(missing.is_empty(), "procedencia: todo WAV/OGG tem entrada (faltam %d: %s)" % [missing.size(), ", ".join(missing.slice(0, 5))])
	r.check(bad_license.is_empty() and rows.size() > 0, "procedencia: licencas so CC0-1.0 ou original (%s)" % ", ".join(bad_license))
