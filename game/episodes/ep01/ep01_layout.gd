class_name Ep01Layout
extends RefCounted
## Geografia compartilhada do Episodio 01 (metros; +X leste, +Z sul, +Y cima; agua em y = WATER_Y).
## Cada estagio constroi a sua regiao a partir destas constantes. Alterar um valor aqui afeta todos.
##
## Cais (oeste) -> rio sobe para leste -> enseada -> braco de rio -> ilha.
##   Cais (convés de madeira): x -8..8, z -3..3, topo em y = 0. Margem de terra: x -10..10, z 3..16.
##   Rio: x 30..182 (152 m), corredor de z -14..14. Banco de areia ao sul do canal; enseada em ENSEADA_POS.
##   Braco de rio entre margem oeste (x 182) e ilha (x 190): norte-sul. Mapa adotado: world/LAYOUT_PROPOSTO.md.

const WATER_Y := -0.4
const FLOW_BOAT_SPEED_LIMIT := 7.0

# Etapa 0/1 - cais e margem
const DOCK_CENTER := Vector3(0, 0, 0)
const DOCK_SIZE := Vector3(16, 0.4, 6)
const BOAT_DOCKED_POS := Vector3(0, 0, -5.0)
const BOAT_DOCKED_HEADING := PI / 2.0
const BOAT_ARRIVAL_START := Vector3(34, 0, -5.0)
const BENCH_LOCAL := Vector3(0.0, 0.5, 0.6)            # no referencial do barco
const BENCH_INTERACT_POS := Vector3(0.0, 0.0, -2.4)    # na borda do cais, junto ao banco
## RB-R1: onde o Rastro pisa NO BARCO (referencial do barco, sobre o conves y = 0,41) para tocar a marca da pata: de frente para
## o banco (+Z do barco), 0,44 m antes do centro da PawMark e 0,08 m a esquerda dela (a pata fica a direita do Rastro).
const PAW_INSPECT_STAND_LOCAL := Vector3(0.08, 0.41, 0.16)
const RASTRO_START := Vector3(-3.0, 0.0, 1.5)
const BANK_PRINT_POS := Vector3(-6.0, 0.0, 10.0)       # pegada de bota na margem

# Etapa 2 - rio
const RIVER_X_MIN := 30.0
const RIVER_X_MAX := 182.0
const RIVER_Z_HALF := 14.0
const RIVER_CURRENT := Vector3(-1.5, 0, 0)             # corrente desce para o oeste (subir o rio exige motor)
const BUOY_POS := Vector3(90.0, 0, -3.0)
const BUOY_RADIUS := 5.0
const ENSEADA_POS := Vector3(166.0, 0, 21.0)
const ENSEADA_RADIUS := 8.0
## Banco de areia (x,z) no meio do rio: o barco passa ao norte (canal) ou pela rota opcional ao sul (canal de tras).
const SANDBAR_RECT := Rect2(112.0, 3.0, 14.0, 6.0)

## Deslocamento das etapas 3 a 5 em relacao ao mapa antigo (rio de 78 m -> 152 m).
const STAGE3_SHIFT := 90.0

# Etapa 3 - ilha e travessia
const LANDING_POS := Vector3(180.5, 0.0, 10.0)          # Pico desembarca na margem oeste do braco
const ANCHOR_A := Vector3(182.0, 1.2, 4.0)              # ponto da margem (Pico)
const ANCHOR_B := Vector3(190.0, 1.2, 4.0)             # ponto da ilha
const ROCK_FOOTHOLDS := [Vector3(183.5, 0.3, 6.5), Vector3(186.0, 0.5, 5.0), Vector3(188.5, 0.3, 4.2)]
const ISLAND_POS := Vector3(198.0, 0, 0)               # centro da ilha
const PILOT_CAPTAIN_POS := Vector3(195.0, 0, 3.0)      # piloto resgatado e filhote

# Etapa 4/5 - atracar e voltar
const PIER_POS := Vector3(190.5, 0.0, -2.0)            # atracadouro do lado protegido
const DOCKING_TARGET_POS := Vector3(187.0, 0, -2.0)
const DOCKING_TARGET_HEADING := 0.0                    # proa para o norte (-Z)
const DOCKING_POS_TOLERANCE := 1.5
const DOCKING_HEADING_TOLERANCE := 0.35
const DOCKING_SPEED_TOLERANCE := 1.2
const BOAT_ARM_START := Vector3(186.0, 0, 13.0)         # onde o barco entra no braco ao atracar
