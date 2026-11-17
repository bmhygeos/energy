class_name CanalNetwork
extends TrackNetwork
## Réseau d'irrigation (recherche Irrigation) : canaux creusés au glisser
## (tracé en L), sur les champs comme hors des zones. Un canal relié de proche
## en proche à une rivière, un lac ou un puits porte l'eau : les champs à
## Production.IRRIGATION_RANGE tuiles ou moins de lui sont irrigués. Pure
## donnée.

## Bois par tuile de canal (vannes, étais).
const WOOD_PER_TILE := 1.0
## Terrains interdits aux canaux : l'eau, la montagne et la glace.
const CANAL_FORBIDDEN: Array[TerrainDef.Type] = [TerrainDef.Type.MOUNTAIN, TerrainDef.Type.LAKE,
	TerrainDef.Type.SEA, TerrainDef.Type.ICE, TerrainDef.Type.RIVER]

## Tuiles de canal reliées à l'eau (ramenées sur la planète).
var linked: Dictionary[Vector2i, bool] = {}
## Tuiles irriguées par les canaux reliés.
var irrigated: Dictionary[Vector2i, bool] = {}


func track_name() -> String:
	return "canal"


func laid_text() -> String:
	return "Canal déjà creusé"


func base_costs() -> PackedFloat32Array:
	var values := Stockpile.zeros()
	values[Stockpile.Good.WOOD] = WOOD_PER_TILE
	return values


## Motif qui empêche un canal sur [param cell] : comme une voie, mais les
## champs (zones cultivées) l'acceptent.
func check_cell(cell: Vector2i) -> String:
	if not map.has_cell(cell) or not territory.is_territory(cell):
		return "Hors du territoire"
	if buildings.in_block(cell):
		return "Ville"
	var b := buildings.building_at(cell)
	if b:
		return "Bâtiment présent (%s)" % b.def.display_name
	var zone := zones.zone_at(cell) if zones else null
	if zone and zone.quality != ZoneDef.Quality.FERTILITY:
		return "Zone présente (%s) : seuls les champs acceptent un canal" % zone.display_name
	var t := map.get_terrain(cell)
	if t in CANAL_FORBIDDEN:
		return "Pas de canal sur : %s" % TerrainDb.get_def(t).display_name.to_lower()
	return ""


## Recalcule les canaux reliés à l'eau (rivière, lac, ou puits de
## [param wells], tuiles ramenées sur la planète) et les tuiles qu'ils
## irriguent.
func refresh(wells: Array[Vector2i]) -> void:
	linked.clear()
	irrigated.clear()
	var queue: Array[Vector2i] = []
	for cell: Vector2i in _tiles:
		if _touches_water(cell, wells):
			linked[cell] = true
			queue.append(cell)
	var head := 0
	while head < queue.size():
		var cell := queue[head]
		head += 1
		for o in WorldMap.NEIGHBORS_4:
			var n := map.wrap_cell(cell + o)
			if _tiles.has(n) and not linked.has(n):
				linked[n] = true
				queue.append(n)
	var r := Production.IRRIGATION_RANGE
	for cell: Vector2i in linked:
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var n := map.wrap_cell(cell + Vector2i(dx, dy))
				if map.has_cell(n):
					irrigated[n] = true


## La tuile irriguée par un canal relié ?
func irrigates(cell: Vector2i) -> bool:
	return irrigated.has(map.wrap_cell(cell))


func _touches_water(cell: Vector2i, wells: Array[Vector2i]) -> bool:
	for o in WorldMap.NEIGHBORS_4:
		var n := map.wrap_cell(cell + o)
		if map.has_cell(n) and map.get_terrain(n) in Production.FRESH_WATER or n in wells:
			return true
	return false
