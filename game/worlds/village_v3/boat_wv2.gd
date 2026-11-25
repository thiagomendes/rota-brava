extends Node3D
## Barco v2 jogavel (RB-R1 E3): modelo wv2_boat.glb com os materiais do mundo v2, colisao do casco e luz de proa.
## Mesmos nos de encaixe do boat_v2 (WheelPoint, HornPoint, DeckPoint, BenchMark, PivotMark, PawMark) + pontos de corda
## (RopeBow, RopeSternL, RopeSternR), todos vindos do GLB. Pronto para substituir actors/environment/boat_v2.tscn.
## PROVISORIO ate aprovacao de Thiago.


func _ready() -> void:
	var model := get_node_or_null("Model")
	if model != null:
		WV2Materials.apply(model)
