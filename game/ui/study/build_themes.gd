extends SceneTree
## Gera os temas candidatos. Uso: ./tools/godot.ps1 --headless --path game --script res://ui/study/build_themes.gd


func _initialize() -> void:
	for o in UiTheme.OPTIONS:
		var th := UiTheme.build(o)
		var path := "res://ui/study/theme_%s.tres" % o
		var err := ResourceSaver.save(th, path)
		print("salvo ", path, " erro=", err)
	quit()
