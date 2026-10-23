class_name BuildingDef
extends Resource
## Définition d'un type de bâtiment de la ville : emprise, chantier,
## contraintes de placement et apparence provisoire. Équilibrage dans
## data/buildings/*.tres.

enum Category { HOUSING, STORAGE, OTHER }

const CATEGORY_NAMES: PackedStringArray = ["Logement", "Stockage", "Divers"]

@export var id: StringName
@export var display_name := ""
@export_multiline var description := ""
@export var category: Category = Category.OTHER
## Proposé dans le menu de construction.
@export var player_buildable := true
## Emprise en tuiles (x, y) ; ancrée sur la tuile avant-bas (x et y maximaux).
@export var size := Vector2i.ONE

@export_group("Chantier")
## Durée du chantier, en heures de jeu (ticks).
@export var build_hours := 24
## Bois pris sur les stocks au lancement du chantier.
@export var wood_cost := 0

@export_group("Effets")
## Habitants logés (maisons).
@export var housing := 0
## Capacité de stockage ajoutée (grenier, réserve de bois).
@export var food_capacity := 0.0
@export var wood_capacity := 0.0

@export_group("Placement")
## Terrains autorisés pour chaque tuile de l'emprise (vide : tout terrain
## constructible). Construire sur une forêt la défriche.
@export var allowed_terrains: Array[TerrainDef.Type] = []
## Au moins une tuile de l'emprise doit avoir accès à l'eau.
@export var needs_water_access := false
## Au moins une tuile autour de l'emprise doit être de l'un de ces terrains.
@export var adjacent_terrains: Array[TerrainDef.Type] = []

@export_group("Apparence")
@export var color := Color.GRAY
@export var roof_color := Color.DIM_GRAY
## Hauteur du volume dessiné, en pixels.
@export var height := 24.0


func footprint_origin(anchor: Vector2i) -> Vector2i:
	return anchor - size + Vector2i.ONE


## Tuiles occupées si le bâtiment est ancré en [param anchor].
func footprint(anchor: Vector2i) -> Array[Vector2i]:
	var origin := footprint_origin(anchor)
	var cells: Array[Vector2i] = []
	for y in size.y:
		for x in size.x:
			cells.append(origin + Vector2i(x, y))
	return cells


## Effets lisibles, un par ligne (vide : aucun).
func describe_effects() -> PackedStringArray:
	var lines := PackedStringArray()
	if housing > 0:
		lines.append("Loge %d habitants" % housing)
	if food_capacity > 0.0:
		lines.append("Stocke %d de nourriture" % roundi(food_capacity))
	if wood_capacity > 0.0:
		lines.append("Stocke %d de bois" % roundi(wood_capacity))
	return lines


## Contraintes de placement lisibles, une par ligne (vide : aucune).
func describe_constraints() -> PackedStringArray:
	var lines := PackedStringArray()
	if not allowed_terrains.is_empty():
		lines.append("Sur : " + _terrain_names(allowed_terrains))
	if needs_water_access:
		lines.append("Près de l'eau")
	if not adjacent_terrains.is_empty():
		lines.append("À côté de : " + _terrain_names(adjacent_terrains))
	return lines


static func _terrain_names(terrains: Array[TerrainDef.Type]) -> String:
	var names := PackedStringArray()
	for t in terrains:
		names.append(TerrainDb.get_def(t).display_name.to_lower())
	return ", ".join(names)
