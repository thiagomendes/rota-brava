class_name PropsV3Gull
extends PropsV3Piece
## Gaivota do M5 (RB-R1, art3d). Animacoes do GLB: `perch_idle` (pousada, olha em volta; loop), `fly` (batida; loop),
## `glide` (planando; loop), `land` (pousar, 1,2 s: desce 0,9 m e avanca 0,7 m ate o pivo) e `flee` (fugir, 1,0 s:
## agacha, salta, sobe 1,1 m e avanca 0,8 m para +Z). O deslocamento de land/flee esta no osso `root`; o caminho no mapa
## e do jogo (encadeie `flee` -> `fly`). Frente = +Z. O peixe fica no bico (BeakSocket/FishHold) enquanto
## `carrying_fish` for verdadeiro.

const LOOPING: Array[StringName] = [&"perch_idle", &"fly", &"glide"]
## Ponto do bico no repouso (espaco do esqueleto, metros): onde o peixe e seguro.
const BEAK_HOLD := Vector3(0.0, 0.365, 0.345)

@export var carrying_fish: bool = true:
	set(v):
		carrying_fish = v
		var f := get_node_or_null(^"Model/gull_rig/Skeleton3D/BeakSocket/FishHold/Fish") as Node3D
		if f != null:
			f.visible = v


## O AnimationPlayer da gaivota e o do GLB (o peixe no bico tem o dele).
func animation_player() -> AnimationPlayer:
	return get_node_or_null(^"Model/AnimationPlayer") as AnimationPlayer


func _ready() -> void:
	var ap := animation_player()
	if ap != null:
		for a in ap.get_animation_list():
			ap.get_animation(a).loop_mode = Animation.LOOP_LINEAR if StringName(a) in LOOPING else Animation.LOOP_NONE
	var sk := get_node_or_null(^"Model/gull_rig/Skeleton3D") as Skeleton3D
	var hold := get_node_or_null(^"Model/gull_rig/Skeleton3D/BeakSocket/FishHold") as Node3D
	if sk != null and hold != null:
		var head := sk.find_bone("head")
		if head >= 0:
			# o encaixe segue o osso da cabeca; a pega fica no bico (convertida do repouso para o espaco do osso)
			var rest := sk.get_bone_global_rest(head)
			hold.transform = rest.affine_inverse() * Transform3D(Basis(), BEAK_HOLD)
	var fish := get_node_or_null(^"Model/gull_rig/Skeleton3D/BeakSocket/FishHold/Fish") as Node3D
	if fish != null:
		fish.rotation = Vector3(PI / 2.0, 0.0, 0.0)   # atravessado no bico e deitado: de frente nao tapa os olhos
	carrying_fish = carrying_fish
	super._ready()
