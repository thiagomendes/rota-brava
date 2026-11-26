extends Node
## Captura G12/G13 (RB-R1): menu novo (Jogar, Opcoes, Sair) e tela dos 3 espacos de jogo. So prova visual.
##   --g13-shot=menu|options|empty|one|hold|confirm   o que mostrar
##   --g13-out=/ABS/arquivo.png                       onde salvar (caminho absoluto)
## Os espacos usam arquivos proprios (user://capture_g13_slot_<n>...), nunca os do jogador.
## Uso: xvfb-run -a -s "-screen 0 1920x1080x24" bash tools/godot.sh --path game --rendering-driver vulkan \
##   --resolution 1920x1080 res://tests/capture_g13.tscn -- --g13-shot=one --g13-out=/ABS/one.png

const PREFIX := "user://capture_g13_"


static func _arg(key: String, def: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(key + "="):
			return a.substr(key.length() + 1)
	return def


func _ready() -> void:
	Ep01V3Cutscene.enabled = false
	SaveSlots.prefix = PREFIX
	for i in SaveSlots.COUNT:
		SaveSlots.erase(i + 1)
	var shot := _arg("--g13-shot", "one")
	var out := _arg("--g13-out", "")
	if shot in ["one", "hold", "confirm"]:
		_write_progress(1, "M3", 3)
	if shot == "hold":
		_write_progress(3, "M6", 7)
	var root: Control
	if shot in ["menu", "options"]:
		var menu := (load("res://ui/main_menu.tscn") as PackedScene).instantiate() as MainMenu
		add_child(menu)
		root = menu
		var t0 := Time.get_ticks_msec()
		while menu.loading_hold() and Time.get_ticks_msec() - t0 < 120000:
			await get_tree().process_frame
		print("G13 menu pronto em %d ms" % (Time.get_ticks_msec() - t0))
		for i in 30:
			await get_tree().process_frame
		if shot == "options":
			menu._open_options()
			for i in 20:
				await get_tree().process_frame
	else:
		var scr := SlotScreen.new()
		add_child(scr)
		root = scr
		await get_tree().process_frame
		scr.open()
		for i in 20:
			await get_tree().process_frame
		if shot == "hold" or shot == "confirm":
			var del := scr.delete_buttons[0]
			del.grab_focus()
			await get_tree().process_frame
			del.set_process(false)
			del._press(&"action")
			del.progress = 0.62
			del.queue_redraw()
			scr._show_hint(1, -1.0)
			if shot == "confirm":
				del.set_process(true)
				del.advance(1.0)
		for i in 20:
			await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if out != "":
		DirAccess.make_dir_recursive_absolute(out.get_base_dir())
		print("G13 salvo %s %s err=%d" % [out, str(img.get_size()), img.save_png(out)])
	for i in SaveSlots.COUNT:
		SaveSlots.erase(i + 1)
	get_tree().quit(0)


## Espaco com missoes concluidas ate `current` (sem incluir) e `emblems` emblemas achados nelas.
func _write_progress(slot: int, current: String, emblems: int) -> void:
	var list: Array = []
	var left := emblems
	for m in Mission.load_list(SaveSlots.MISSIONS_PATH):
		var done := String(m.id) < current
		var em: Array[String] = []
		if done:
			for e in m.emblems:
				if left > 0:
					em.append(String(e))
					left -= 1
		list.append({"id": String(m.id), "state": Mission.State.COMPLETED if done else Mission.State.INACTIVE, "emblems": em})
	var f := FileAccess.open(SaveSlots.save_path(slot), FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": MissionSave.VERSION, "episode": "ep01", "current": current, "missions": list}))
	f.close()
