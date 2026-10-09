class_name BuildingDef
extends Resource
## Définition d'un type de bâtiment : coûts, emprise, contraintes de placement
## et apparence provisoire. Équilibrage dans data/buildings/*.tres.

enum Category { RESOURCES, ENERGY, LOGISTICS, OTHER }
## Forme du dessin provisoire (scenes/world/building_sprite.gd).
enum Style { BOX, TURBINE, PANELS }

const CATEGORY_NAMES: PackedStringArray = ["Ressources", "Énergie", "Logistique", "Divers"]

@export var id: StringName
@export var display_name := ""
@export_multiline var description := ""
@export var category: Category = Category.OTHER
## Emprise en tuiles (x, y) ; ancrée sur la tuile avant-bas (x et y maximaux).
@export var size := Vector2i.ONE

@export_group("Coûts")
@export var cost := 1000
## Durée du chantier, en heures de jeu (ticks).
@export var build_hours := 24
@export var upkeep_per_day := 10
## Durée de vie en années de jeu (0 : illimitée). Pas encore simulée.
@export var lifetime_years := 0
## Technologie requise (vide : disponible dès le départ). Appliquée en M5.
@export var required_tech: StringName

@export_group("Placement")
## Terrains autorisés pour chaque tuile de l'emprise (vide : tout terrain
## constructible). Construire sur une forêt la défriche.
@export var allowed_terrains: Array[TerrainDef.Type] = []
## Gisement requis sous au moins une tuile de l'emprise.
@export var required_deposit: WorldMap.Deposit = WorldMap.Deposit.NONE
## Au moins une tuile de l'emprise doit avoir accès à l'eau.
@export var needs_water_access := false
## Au moins une tuile de l'emprise doit toucher la mer.
@export var needs_coast := false
## Au moins une tuile autour de l'emprise doit être de l'un de ces terrains.
@export var adjacent_terrains: Array[TerrainDef.Type] = []
## Moyennes minimales de vent / d'ensoleillement sur l'emprise (0 : aucune).
@export_range(0.0, 1.0) var min_wind := 0.0
@export_range(0.0, 1.0) var min_sun := 0.0

@export_group("Apparence")
@export var style: Style = Style.BOX
@export var color := Color.GRAY
@export var roof_color := Color.DIM_GRAY
## Hauteur du volume dessiné, en pixels.
@export var height := 24.0
@export var has_chimney := false


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


## Contraintes de placement lisibles, une par ligne (vide : aucune).
func describe_constraints() -> PackedStringArray:
	var lines := PackedStringArray()
	if not allowed_terrains.is_empty():
		var names := PackedStringArray()
		for t in allowed_terrains:
			names.append(TerrainDb.get_def(t).display_name.to_lower())
		lines.append("Sur : " + ", ".join(names))
	if required_deposit != WorldMap.Deposit.NONE:
		lines.append("Sur un gisement de " + WorldMap.DEPOSIT_NAMES[required_deposit].to_lower())
	if needs_water_access:
		lines.append("Près de l'eau")
	if needs_coast:
		lines.append("Sur la côte")
	if not adjacent_terrains.is_empty():
		var names := PackedStringArray()
		for t in adjacent_terrains:
			names.append(TerrainDb.get_def(t).display_name.to_lower())
		lines.append("À côté de : " + ", ".join(names))
	if min_wind > 0.0:
		lines.append("Vent ≥ %d %%" % roundi(min_wind * 100.0))
	if min_sun > 0.0:
		lines.append("Ensoleillement ≥ %d %%" % roundi(min_sun * 100.0))
	return lines
