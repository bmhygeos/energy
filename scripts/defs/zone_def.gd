class_name ZoneDef
extends Resource
## Définition d'un type de zone peinte par le joueur (agriculture, élevage,
## coupe du bois) : terrains valides, travailleurs par tuile et couleur du
## calque. Équilibrage dans data/zones/*.tres.

## Qualité d'une tuile pour la zone : fertilité, pâturage ou densité de forêt.
enum Quality { FERTILITY, PASTURE, WOOD }

@export var id: StringName
@export var display_name := ""
@export_multiline var description := ""
## Terrains valides.
@export var allowed_terrains: Array[TerrainDef.Type] = []
## Accepte aussi toute tuile constructible au bord de l'eau (berges).
@export var on_banks := false
## Fertilité minimale de la tuile (0 : aucune).
@export_range(0.0, 1.0) var min_fertility := 0.0
## Places de travail par tuile (section 6 du plan).
@export var workers_per_tile := 1
## Ce qui fait une bonne tuile pour cette zone.
@export var quality: Quality = Quality.FERTILITY
## Couleur de la zone sur la carte.
@export var color := Color.WHITE


## Motif qui empêche la zone sur [param cell] de [param map] (vide : valide).
## Le territoire et les bâtiments sont vérifiés par ZoneMap.
func terrain_error(map: WorldMap, cell: Vector2i) -> String:
	var t := map.get_terrain(cell)
	var terrain := TerrainDb.get_def(t)
	var banks := on_banks and terrain.buildable and map.has_water_access(cell)
	if t not in allowed_terrains and not banks:
		return "Terrain non valide pour %s (%s)" % [display_name.to_lower(), terrain.display_name.to_lower()]
	if min_fertility > 0.0 and map.get_fertility(cell) < min_fertility:
		return "Terre trop peu fertile"
	return ""


## Qualité de [param cell] pour cette zone, 0–1.
func quality_at(map: WorldMap, cell: Vector2i) -> float:
	match quality:
		Quality.PASTURE:
			return map.get_pasture(cell)
		Quality.WOOD:
			return clampf(map.get_wood(cell) / WorldMap.WOOD_PER_FOREST, 0.0, 1.0)
	return map.get_fertility(cell)


## Terrains valides, lisibles.
func describe_terrains() -> String:
	var names := PackedStringArray()
	for t in allowed_terrains:
		names.append(TerrainDb.get_def(t).display_name.to_lower())
	if on_banks:
		names.append("berges")
	return ", ".join(names)
