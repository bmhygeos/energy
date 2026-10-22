class_name StartSite
extends RefCounted
## Choix du site du village : un territoire de départ de TERRITORY_SIZE ×
## TERRITORY_SIZE tuiles aux latitudes tempérées, avec forêt, terres
## cultivables et un point d'eau (garantis par ensure).

const TERRITORY_SIZE := 12
const MIN_FOREST := 10
## Plaines et prairies.
const MIN_FARMLAND := 40
## Rivière, lac ou mer.
const MIN_WATER := 1
const MIN_BUILDABLE := 100
## Latitudes (valeur absolue, degrés) explorées pour le départ.
const MIN_LATITUDE := 20.0
const MAX_LATITUDE := 55.0
const MAX_TRIES := 400

const T := TerrainDef.Type


## Tuiles du territoire de départ centré sur [param center].
static func territory_rect(center: Vector2i) -> Rect2i:
	return Rect2i(center - Vector2i.ONE * (TERRITORY_SIZE / 2), Vector2i.ONE * TERRITORY_SIZE)


## Centre du village : premier site tiré au hasard (selon la graine) qui
## remplit tous les critères, à défaut le meilleur.
static func find(generator: MapGenerator) -> Vector2i:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([generator.seed_value, "start"])
	var size := generator.size
	var best := Vector2i.ZERO
	var best_shortfall := INF
	for k in MAX_TRIES:
		var lat := rng.randf_range(MIN_LATITUDE, MAX_LATITUDE) * (1.0 if rng.randf() < 0.5 else -1.0)
		var center := Vector2i(rng.randi_range(0, size.x - 1), int((90.0 - lat) / 180.0 * size.y))
		var counts := _counts(territory_rect(center), func(c: Vector2i) -> int: return generator.fields(c).terrain)
		var shortfall := _shortfall(counts)
		if shortfall < best_shortfall:
			best = center
			best_shortfall = shortfall
		if shortfall == 0.0:
			break
	return best


## Complète le territoire [param rect] de [param map] s'il manque de forêt
## ou d'eau (après find, cas exceptionnel) ; renvoie les tuiles modifiées.
static func ensure(map: WorldMap, rect: Rect2i) -> Array[Vector2i]:
	var changed: Array[Vector2i] = []
	var counts := _counts(rect, func(c: Vector2i) -> int: return map.get_terrain(c))
	var farmland: Array[Vector2i] = []
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if map.get_terrain(Vector2i(x, y)) in [T.PLAIN, T.PRAIRIE]:
				farmland.append(Vector2i(x, y))
	if counts.water < MIN_WATER and not farmland.is_empty():
		var cell: Vector2i = farmland.pop_front()
		map.set_terrain(cell, T.LAKE)
		changed.append(cell)
	for k in maxi(0, MIN_FOREST - counts.forest):
		if farmland.is_empty():
			break
		var cell: Vector2i = farmland.pop_back()
		map.set_terrain(cell, T.FOREST)
		map.set_wood(cell, WorldMap.WOOD_PER_FOREST * 0.7)
		changed.append(cell)
	return changed


## Nombre de tuiles par catégorie dans [param rect], selon [param terrain_of].
static func _counts(rect: Rect2i, terrain_of: Callable) -> Dictionary:
	var counts := {forest = 0, farmland = 0, water = 0, buildable = 0}
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var t: int = terrain_of.call(Vector2i(x, y))
			if t == T.FOREST:
				counts.forest += 1
			elif t == T.PLAIN or t == T.PRAIRIE:
				counts.farmland += 1
			elif t in [T.RIVER, T.LAKE, T.SEA]:
				counts.water += 1
			if TerrainDb.get_def(t).buildable:
				counts.buildable += 1
	return counts


## Écart aux critères (0 : site valide).
static func _shortfall(counts: Dictionary) -> float:
	return maxf(0, MIN_FOREST - counts.forest) + maxf(0, MIN_FARMLAND - counts.farmland) \
		+ 10.0 * maxf(0, MIN_WATER - counts.water) + maxf(0, MIN_BUILDABLE - counts.buildable)
