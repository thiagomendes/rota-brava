extends Node
## Cena de captura do HUD REAL sobre o episodio 01 (estado dock_investigation). So para o Movie Maker.
## Linha do tempo por quadros: 20 troca natural; 32 acao + legenda normal; 40 legenda longa; 48 pseudoidioma;
## 56 escolha; 64 pausa; 72 conclusao. Os textos de legenda/escolha sao injetados via API publica do Hud.

var _main: Ep01Main
var _frame: int = 0
var _prompt_text: String = ""


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
	# O episodio esconde a acao quando nao ha alvo; reaplica ao fim do quadro para a captura mostrar o painel.
	_apply_prompt.call_deferred()
	match _frame:
		26:
			hud.close_handoff()
			hud.handoff_confirmed.emit()
		32:
			_prompt_text = Loc.t("ui.action.examine")
			hud.say("study.sub.tracker.normal")
		40:
			hud.clear_speech()
			hud.say("study.sub.tracker.long")
		48:
			hud.clear_speech()
			_prompt_text = Loc.t("study.prompt.accents")
			hud.say("study.sub.pilot.accents")
		56:
			hud.clear_speech()
			_prompt_text = ""
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



func _apply_prompt() -> void:
	if _prompt_text != "" and _main.hud != null:
		_main.hud.show_prompt(_prompt_text, &"paw")
