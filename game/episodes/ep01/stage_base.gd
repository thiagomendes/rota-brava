class_name StageBase
extends Node3D
## Base de um estagio do Episodio 01. Contrato:
##  - `setup(main)`: chamado UMA vez ao carregar o episodio; construa aqui a cenografia da sua regiao
##    (blocos PROVISORIOS via Blocks), colisoes e Ep01Interactable. Todos os estagios existem desde o inicio.
##  - `refresh_world()`: chamado depois de toda transicao e ao iniciar; deixe o mundo coerente com
##    `ctx.director` (linha fixada visivel, barco no lugar etc.). Deve ser idempotente.
##  - `enter()` / `exit()`: o diretor entrou/saiu do estado deste estagio. `enter()` posiciona atores e
##    liga interacoes; NAO entrega controle (o Ep01Main faz a troca de integrante e chama `controlled_node`).
##  - Eventos de jogo SEMPRE por `ctx.submit(evento, fonte, payload)`; o diretor decide o progresso.
##  - Texto so por Loc (chaves do catalogo); falas por `ctx.hud.say(chave)`.

var ctx: Ep01Main
var state_id: StringName = &""


func setup(main: Ep01Main) -> void:
	ctx = main


func refresh_world() -> void:
	pass


func enter() -> void:
	pass


func exit() -> void:
	pass


## Depois da troca de integrante confirmada (o controle acabou de passar a `member`):
## bom momento para a fala de abertura do estagio (ex.: Ep01Content.lines(state, "enter")).
func control_started(_member: StringName) -> void:
	pass


## Dica graduada de GESTO (antes da fala): destaque visualmente o alvo (pulso, olhar do ativo). `key` e a chave da dica.
func gesture_hint(_key: String) -> void:
	pass


func process_stage(_delta: float) -> void:
	pass


## No que o integrante controla (padrao: o proprio ator; barco para pilotagem).
func controlled_node(member: StringName) -> Node3D:
	return ctx.actors.get(member)


## No para onde a camera olha na troca de integrante.
func focus_node(member: StringName) -> Node3D:
	return controlled_node(member)


## Posicao/giro da camera enquanto este estagio controla (offset relativo ao alvo, yaw em radianos).
func camera_view() -> Dictionary:
	return {"offset": Vector3(0, 7.5, 9.5), "yaw": 0.0}
