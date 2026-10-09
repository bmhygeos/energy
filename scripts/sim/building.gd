class_name Building
extends RefCounted
## Bâtiment posé sur la carte (chantier ou terminé). Pure donnée.

enum Status { CONSTRUCTION, RUNNING, NO_INPUT, OUTPUT_FULL, DEPLETED, IDLE }

const STATUS_NAMES: PackedStringArray = [
	"En chantier", "En service", "À l'arrêt : manque d'approvisionnement",
	"À l'arrêt : stock de sortie plein", "À l'arrêt : ressource épuisée", "Inactif",
]

var id: int
var def: BuildingDef
## Tuile d'ancrage (avant-bas de l'emprise).
var anchor: Vector2i
var cells: Array[Vector2i]
## Heures de chantier écoulées ; le bâtiment est terminé à def.build_hours.
var build_progress := 0
var status: Status = Status.CONSTRUCTION
## Tampons (tonnes) : marchandise d'entrée reçue, de sortie à expédier.
var input_stock := 0.0
var output_stock := 0.0
## Taux de fonctionnement (0–1) et puissance électrique de la dernière heure.
var activity := 0.0
var power_mw := 0.0


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
