class_name Building
extends RefCounted
## Bâtiment posé sur la carte (chantier ou terminé). Pure donnée.

enum Status { CONSTRUCTION, RUNNING }

const STATUS_NAMES: PackedStringArray = ["En chantier", "En service"]

var id: int
var def: BuildingDef
## Tuile d'ancrage (avant-bas de l'emprise).
var anchor: Vector2i
var cells: Array[Vector2i]
## Heures de chantier écoulées ; le bâtiment est terminé à def.build_hours.
var build_progress := 0
var status: Status = Status.CONSTRUCTION
## Pendant une amélioration : le niveau précédent, toujours en service.
var previous_def: BuildingDef


func _init(p_id: int, p_def: BuildingDef, p_anchor: Vector2i) -> void:
	id = p_id
	def = p_def
	anchor = p_anchor
	cells = def.footprint(anchor)


func is_complete() -> bool:
	return build_progress >= def.build_hours


## Définition en service : la sienne une fois terminé, l'ancienne pendant une
## amélioration (null pour un chantier neuf).
func effective_def() -> BuildingDef:
	return def if is_complete() else previous_def


## Lance l'amélioration vers [param next] : chantier sur place, l'ancien
## niveau reste en service jusqu'à la fin.
func start_upgrade(next: BuildingDef) -> void:
	previous_def = def
	def = next
	build_progress = 0
	status = Status.CONSTRUCTION


## Avancement du chantier, 0–1.
func progress_ratio() -> float:
	return 1.0 if def.build_hours <= 0 else clampf(float(build_progress) / def.build_hours, 0.0, 1.0)
