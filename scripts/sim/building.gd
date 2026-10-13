class_name Building
extends RefCounted
## Bâtiment posé sur la carte (chantier ou terminé). Pure donnée.

enum Status { CONSTRUCTION, RUNNING, NO_INPUT, OUTPUT_FULL, DEPLETED, IDLE, NO_GRID, STANDBY, NO_POWER, NO_WIND, NIGHT }

const STATUS_NAMES: PackedStringArray = [
	"En chantier", "En service", "À l'arrêt : manque d'approvisionnement",
	"À l'arrêt : stock de sortie plein", "À l'arrêt : ressource épuisée", "Inactif",
	"À l'arrêt : non relié au réseau électrique", "En veille : pas de demande",
	"À l'arrêt : pas d'électricité", "À l'arrêt : pas de vent", "À l'arrêt : nuit",
]

var id: int
var def: BuildingDef
## Tuile d'ancrage (avant-bas de l'emprise).
var anchor: Vector2i
var cells: Array[Vector2i]
## Ville représentée par ce bâtiment (null pour les bâtiments du joueur).
var city: City
## Heures de chantier écoulées ; le bâtiment est terminé à def.build_hours.
var build_progress := 0
var status: Status = Status.CONSTRUCTION
## Tampons (tonnes) : marchandise d'entrée reçue, de sortie à expédier.
var input_stock := 0.0
var output_stock := 0.0
## Quantités promises par des missions en cours : à livrer ici (entrée ou
## entrepôt), à enlever d'ici (sortie ; par marchandise pour un entrepôt).
var reserved_in := 0.0
var reserved_out := 0.0
var store_reserved_out: Dictionary[int, float] = {}
## Entrepôt : stock par marchandise (Goods.Type → t).
var store: Dictionary[int, float] = {}
## Taux de fonctionnement (0–1) et puissance électrique de la dernière heure.
var activity := 0.0
var power_mw := 0.0
## Réseau électrique : identifiant du réseau raccordé (0 : aucun) et consigne
## de puissance (0–1) fixée par le réseau pour l'heure suivante.
var grid_id := 0
var power_setpoint := 0.0
## Consommateur d'électricité alimenté pendant la dernière heure.
var powered := false
## Énergie stockée (MWh : batterie, STEP, chaleur du solaire thermique) et,
## pour un stockage du réseau, flux de la dernière heure (MW, > 0 : charge).
var stored_mwh := 0.0
var storage_flow_mw := 0.0


func _init(p_id: int, p_def: BuildingDef, p_anchor: Vector2i) -> void:
	id = p_id
	def = p_def
	anchor = p_anchor
	cells = def.footprint(anchor)


func is_complete() -> bool:
	return build_progress >= def.build_hours


## Avancement du chantier, 0–1.
func progress_ratio() -> float:
	return 1.0 if def.build_hours <= 0 else clampf(float(build_progress) / def.build_hours, 0.0, 1.0)


## Entrepôt : stock total, toutes marchandises.
func stored_total() -> float:
	var total := 0.0
	for good in store:
		total += store[good]
	return total
