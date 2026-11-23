class_name PlaceholderStage
extends StageBase
## Estagio vazio usado enquanto o estagio real nao existe. So registra a entrada.


func enter() -> void:
	print("[RB] stage_placeholder %s" % state_id)
