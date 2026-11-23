extends Node
## Cena de captura do HUD REAL sobre o episodio 01 (estado dock_investigation). So para o Movie Maker.
## Linha do tempo por quadros: 20 troca natural; 32 acao + legenda normal; 40 legenda longa; 48 pseudoidioma;
## 56 escolha; 64 pausa; 72 conclusao. Os textos de legenda/escolha sao injetados via API publica do Hud.

var _main: Ep01Main
var _frame: int = 0


func _ready() -> void:
	Ep01Main.start_state = &"dock_investigation"
	Ep01Main.carry_completed = []
	_main = (load("res://episodes/ep01/ep01_main.tscn") as PackedScene).instantiate() as Ep01Main
	add_child(_main)


func _process(_delta: float) -> void:
	_frame += 1
	var hud := _main.hud
	if hud == null:
		return
	match _frame:
		26:
			hud.close_handoff()
			hud.handoff_confirmed.emit()
		32:
			hud.show_prompt(Loc.t("ui.action.examine"), &"paw")
			hud.say("study.sub.tracker.normal")
		40:
			hud.clear_speech()
			hud.say("study.sub.tracker.long")
		48:
			hud.clear_speech()
			hud.show_prompt(Loc.t("study.prompt.accents"), &"paw")
			hud.say("study.sub.pilot.accents")
		56:
			hud.clear_speech()
			hud.hide_prompt()
			var opts: Array[Dictionary] = [
				{"id": &"bank", "label": Loc.t("study.choice.bank"), "icon": &"bank"},
				{"id": &"harbor", "label": Loc.t("study.choice.harbor"), "icon": &"harbor"}]
			hud.open_choice(Loc.t("study.choice.title"), opts)
		64:
			hud.close_choice()
			hud.open_pause()
		72:
			hud.close_pause()
			hud.open_complete()

