class_name Vehicle
extends RefCounted
## Véhicule routier rattaché à un dépôt, et sa mission en cours. Pure donnée.

enum State { IDLE, TO_SOURCE, LOADING, TO_DESTINATION, UNLOADING, RETURNING }

const STATE_NAMES: PackedStringArray = [
	"Au dépôt", "Vers le chargement", "Chargement", "En livraison", "Déchargement", "Retour au dépôt",
]

var id: int
var def: VehicleDef
var depot: Building
var state: State = State.IDLE
## Chemin courant (tuiles de route) et avancement le long de celui-ci, en
## tuiles depuis le début.
var path: Array[Vector2i] = []
var progress := 0.0
## Position continue en coordonnées de grille, avant et après le dernier tick
## (interpolée par le rendu).
var grid_pos := Vector2.ZERO
var prev_grid_pos := Vector2.ZERO
## Heures restantes de chargement / déchargement.
var wait_hours := 0
## Mission : marchandise, quantité promise, source, destination, chargement.
var good: Goods.Type = Goods.Type.NONE
var amount := 0.0
var source: Building
var destination: Building
var cargo := 0.0
## Vendu dès son retour au dépôt ; ne prend plus de mission.
var retiring := false


func _init(p_id: int, p_def: VehicleDef, p_depot: Building) -> void:
	id = p_id
	def = p_def
	depot = p_depot


func is_available() -> bool:
	return not retiring and (state == State.IDLE or state == State.RETURNING)


## Tuile de route où se trouve le véhicule (sur la route).
func current_cell() -> Vector2i:
	if path.is_empty():
		return Vector2i(-1, -1)
	return path[clampi(roundi(progress), 0, path.size() - 1)]


func set_path(cells: Array[Vector2i]) -> void:
	path = cells
	progress = 0.0
	if not path.is_empty():
		grid_pos = Vector2(path[0])


## Avance de [param distance] tuiles ; renvoie la distance réellement
## parcourue. Arrivé quand progress atteint la dernière tuile.
func move(distance: float) -> float:
	prev_grid_pos = grid_pos
	if path.size() < 2:
		return 0.0
	var before := progress
	progress = minf(progress + distance, path.size() - 1.0)
	var i := mini(floori(progress), path.size() - 2)
	grid_pos = Vector2(path[i]).lerp(Vector2(path[i + 1]), progress - i)
	return progress - before


func has_arrived() -> bool:
	return progress >= path.size() - 1.0
