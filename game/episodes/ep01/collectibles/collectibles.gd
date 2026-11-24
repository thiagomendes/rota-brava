class_name Ep01Collectibles
extends Node3D
## 10 "emblemas da Rota Brava" opcionais (RB-R1): moedas-emblema que giram e brilham, escondidas pela vila (cais e
## margem), pelo rio (pegas de barco, uma delas na rota opcional atras do banco de areia) e pela ilha.
## Coletados ao encostar com o no controlado (a pe ou de barco). Contagem em memoria por execucao (sobrevive a
## recarga da cena, nao ao fechar o jogo). Nunca bloqueiam progresso nem mexem no diretor.
## Visual PROVISORIO em primitivas.

signal found(count: int, total: int)

const WALK_RADIUS := 0.9
const BOAT_RADIUS := 2.2
const HOVER := 0.7
## Posicao (pes/agua) e por onde se pega: &"foot" ou &"boat".
const SPOTS := [
	[Vector3(-7.0, 0.0, 2.2), &"foot"],      # ponta oeste do cais, atras da multidao
	[Vector3(5.6, 0.0, -2.1), &"foot"],      # perto da ponta leste do cais, na beira da agua
	[Vector3(-8.0, 0.0, 7.5), &"foot"],      # canto oeste da margem
	[Vector3(4.0, 0.0, 14.6), &"foot"],      # fundo da margem, junto a cerca sul
	[Vector3(60.0, 0.0, -12.0), &"boat"],    # rente a margem norte do rio
	[Vector3(119.0, 0.0, 11.5), &"boat"],    # rota opcional atras do banco de areia
	[Vector3(170.0, 0.0, 25.0), &"boat"],    # fundo da enseada
	[Vector3(180.6, 0.0, 15.0), &"foot"],    # ponta sul da margem do braco (Pico)
	[Vector3(197.0, 0.0, 8.0), &"foot"],     # beira sul da ilha
	[Vector3(205.0, 0.0, -8.5), &"foot"],    # canto nordeste da ilha
]

## Indices ja coletados nesta execucao.
static var collected: Array[int] = []

var main: Ep01Main
var emblems: Array[Node3D] = []
var _clock: float = 0.0


func setup(m: Ep01Main) -> void:
	main = m
	name = "Collectibles"
	for i in SPOTS.size():
		var spot: Array = SPOTS[i]
		var e := _build_emblem(i, spot[0] as Vector3, spot[1] as StringName)
		e.visible = not collected.has(i)
		emblems.append(e)


static func total() -> int:
	return SPOTS.size()


static func count() -> int:
	return collected.size()


static func reset_run() -> void:
	collected.clear()


func _build_emblem(i: int, pos: Vector3, kind: StringName) -> Node3D:
	var root := Node3D.new()
	root.name = "Emblem%d" % (i + 1)
	root.set_meta(Blocks.PROVISIONAL, true)
	root.set_meta(&"pickup", kind)
	add_child(root)
	var base_y := (Ep01Layout.WATER_Y + 0.9) if kind == &"boat" else HOVER
	root.position = pos + Vector3(0, base_y, 0)
	var spin := Node3D.new()
	spin.name = "Spin"
	root.add_child(spin)
	var coin := Blocks.cylinder(spin, "Coin", 0.32, 0.07, Vector3.ZERO, Color("ffc93c"), 0.9)
	coin.rotation.x = PI / 2.0
	var rim := Blocks.cylinder(spin, "Face", 0.22, 0.09, Vector3.ZERO, Color("e0262b"), 0.6)
	rim.rotation.x = PI / 2.0
	var star := Blocks.box(spin, "Star", Vector3(0.12, 0.12, 0.11), Vector3.ZERO, Color("fff4c2"), 1.4)
	star.rotation.z = PI / 4.0
	return root


func _process(delta: float) -> void:
	_clock += delta
	for i in emblems.size():
		var e := emblems[i]
		if not e.visible:
			continue
		var spin := e.get_node("Spin") as Node3D
		spin.rotation.y = _clock * 2.4 + float(i)
		spin.position.y = 0.08 * sin(_clock * 2.0 + float(i))
	if main == null or main.controlled_node == null:
		return
	check_pickup(main.controlled_node.global_position, main.controlled_node == main.boat)


## Coleta o que estiver ao alcance de `pos`. Devolve quantos foram coletados agora.
func check_pickup(pos: Vector3, on_boat: bool) -> int:
	var got := 0
	for i in emblems.size():
		if collected.has(i):
			continue
		var spot: Array = SPOTS[i]
		var p: Vector3 = spot[0]
		var kind: StringName = spot[1]
		var r := BOAT_RADIUS if on_boat else WALK_RADIUS
		if (kind == &"boat") != on_boat:
			continue
		if Vector2(pos.x - p.x, pos.z - p.z).length() > r:
			continue
		if collect(i):
			got += 1
	return got


## Marca o emblema `i` (uma vez). Devolve false se ja estava coletado.
func collect(i: int) -> bool:
	if i < 0 or i >= SPOTS.size() or collected.has(i):
		return false
	collected.append(i)
	var e := emblems[i]
	FeedbackFx.sparkle(self, e.global_position)
	e.visible = false
	print("[RB] emblema %d (%d/%d)" % [i + 1, collected.size(), SPOTS.size()])
	if main != null and main.audio != null:
		main.audio.play_sfx("sfx_clue_found", e.global_position, -4.0)
	found.emit(collected.size(), SPOTS.size())
	return true
