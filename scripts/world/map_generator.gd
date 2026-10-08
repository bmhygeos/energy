class_name MapGenerator
extends RefCounted
## Génération procédurale déterministe de la carte à partir d'une graine.
##
## Étapes : altitude (bruit + pente vers la mer) → mer / lacs / collines /
## montagnes → rivières → forêts et déserts → vent, soleil, accès à l'eau →
## gisements. Les seuils sont des quantiles, de sorte que chaque carte
## contient toujours tous les terrains et tous les gisements.

const T := TerrainDef.Type

## Proportions de la carte (quantiles d'altitude).
const SEA_FRACTION := 0.22
const MOUNTAIN_FRACTION := 0.07
const HILL_FRACTION := 0.14
## Proportions des terres plates.
const FOREST_FRACTION := 0.30
const DESERT_FRACTION := 0.12
## Une rivière pour ~1 200 tuiles, au moins 2.
const TILES_PER_RIVER := 1200
const MIN_RIVER_SOURCE_SPACING := 10

## [type, terrains éligibles, proportion des terres, quantité min, max].
const DEPOSIT_RULES := [
	[WorldMap.Deposit.LITHIUM, [T.DESERT, T.HILL], 0.010, 300, 1000],
	[WorldMap.Deposit.URANIUM, [T.HILL, T.DESERT, T.PLAIN], 0.012, 500, 1500],
	[WorldMap.Deposit.COAL, [T.PLAIN, T.HILL, T.FOREST], 0.05, 4000, 12000],
]


static func generate(size: Vector2i, seed_value: int) -> WorldMap:
	var map := WorldMap.new(size, seed_value)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, "map"])
	_generate_elevation(map, rng)
	_classify_relief(map)
	_carve_rivers(map, rng)
	_place_biomes(map, rng)
	_compute_water_access(map)
	_compute_climate(map, rng)
	_place_deposits(map, rng)
	for i in map.cell_count():
		map.variant[i] = rng.randi_range(0, 3)
	return map


static func _make_noise(rng: RandomNumberGenerator, size: Vector2i, scale: float) -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.seed = rng.randi()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 4
	noise.frequency = scale / maxf(size.x, size.y)
	return noise


## Remplit [param values] (une valeur par tuile) puis la normalise en 0–1.
static func _normalize(values: PackedFloat32Array) -> void:
	var lo := INF
	var hi := -INF
	for v in values:
		lo = minf(lo, v)
		hi = maxf(hi, v)
	var span := maxf(hi - lo, 0.0001)
	for i in values.size():
		values[i] = (values[i] - lo) / span


## Valeur au quantile [param q] (0–1) de [param values].
static func _quantile(values: PackedFloat32Array, q: float) -> float:
	if values.is_empty():
		return INF
	var sorted := values.duplicate()
	sorted.sort()
	return sorted[clampi(int(q * sorted.size()), 0, sorted.size() - 1)]


static func _generate_elevation(map: WorldMap, rng: RandomNumberGenerator) -> void:
	var noise := _make_noise(rng, map.size, 3.0)
	# La mer borde la carte d'un côté tiré au hasard.
	var sea_dir := Vector2.from_angle(rng.randf() * TAU)
	for i in map.cell_count():
		var c := map.cell_of(i)
		var uv := (Vector2(c) + Vector2(0.5, 0.5)) / Vector2(map.size) - Vector2(0.5, 0.5)
		map.elevation[i] = noise.get_noise_2d(c.x, c.y) - 0.9 * uv.dot(sea_dir)
	_normalize(map.elevation)


static func _classify_relief(map: WorldMap) -> void:
	var sea_level := _quantile(map.elevation, SEA_FRACTION)
	var hill_level := _quantile(map.elevation, 1.0 - MOUNTAIN_FRACTION - HILL_FRACTION)
	var mountain_level := _quantile(map.elevation, 1.0 - MOUNTAIN_FRACTION)
	for i in map.cell_count():
		var e := map.elevation[i]
		if e < sea_level:
			map.terrain[i] = T.SEA
		elif e >= mountain_level:
			map.terrain[i] = T.MOUNTAIN
		elif e >= hill_level:
			map.terrain[i] = T.HILL
		else:
			map.terrain[i] = T.PLAIN
	# Les étendues d'eau qui ne touchent pas le bord de la carte sont des lacs.
	var seen := PackedByteArray()
	seen.resize(map.cell_count())
	for i in map.cell_count():
		if map.terrain[i] != T.SEA or seen[i]:
			continue
		var region := _flood(map, map.cell_of(i), seen)
		var touches_border := false
		for c in region:
			if c.x == 0 or c.y == 0 or c.x == map.size.x - 1 or c.y == map.size.y - 1:
				touches_border = true
				break
		if not touches_border:
			for c in region:
				map.terrain[map.index_of(c)] = T.LAKE


## Composante connexe (4-voisinage) de même terrain que [param start].
static func _flood(map: WorldMap, start: Vector2i, seen: PackedByteArray) -> Array[Vector2i]:
	var type := map.get_terrain(start)
	var region: Array[Vector2i] = [start]
	seen[map.index_of(start)] = 1
	var head := 0
	while head < region.size():
		var c := region[head]
		head += 1
		for n in map.neighbors(c):
			var ni := map.index_of(n)
			if not seen[ni] and map.terrain[ni] == type:
				seen[ni] = 1
				region.append(n)
	return region


static func _carve_rivers(map: WorldMap, rng: RandomNumberGenerator) -> void:
	var count := maxi(2, map.cell_count() / TILES_PER_RIVER)
	var candidates: Array[Vector2i] = []
	for i in map.cell_count():
		if map.terrain[i] == T.MOUNTAIN or map.terrain[i] == T.HILL:
			candidates.append(map.cell_of(i))
	# Sources : les plus hautes d'abord, avec un peu de hasard, bien espacées.
	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return map.elevation[map.index_of(a)] > map.elevation[map.index_of(b)])
	var sources: Array[Vector2i] = []
	var start := rng.randi_range(0, mini(5, candidates.size() - 1)) if candidates else 0
	for i in range(start, candidates.size()):
		if sources.size() >= count:
			break
		var c := candidates[i]
		if sources.all(func(s: Vector2i) -> bool: return s.distance_to(c) >= MIN_RIVER_SOURCE_SPACING):
			sources.append(c)
	for s in sources:
		_carve_river(map, s, rng)


## Descend la pente depuis [param source] jusqu'à une étendue d'eau ; une
## cuvette sans issue devient un lac.
static func _carve_river(map: WorldMap, source: Vector2i, rng: RandomNumberGenerator) -> void:
	var path: Array[Vector2i] = [source]
	var on_path := {source: true}
	var current := source
	for step in map.cell_count():
		var reached_water := false
		for n in map.neighbors(current):
			if not on_path.has(n) and map.is_water(n):
				reached_water = true
		if reached_water:
			break
		var best := Vector2i(-1, -1)
		var best_e := INF
		for n in map.neighbors(current):
			if on_path.has(n):
				continue
			var e := map.elevation[map.index_of(n)] + rng.randf() * 0.01
			if e < best_e:
				best_e = e
				best = n
		if best.x < 0:
			break
		if best_e > map.elevation[map.index_of(current)] + 0.01:
			# Cuvette : la rivière s'y jette dans un petit lac.
			map.terrain[map.index_of(current)] = T.LAKE
			path.pop_back()
			break
		path.append(best)
		on_path[best] = true
		current = best
	for c in path:
		map.terrain[map.index_of(c)] = T.RIVER


static func _place_biomes(map: WorldMap, rng: RandomNumberGenerator) -> void:
	var moisture_noise := _make_noise(rng, map.size, 4.0)
	var heat_noise := _make_noise(rng, map.size, 2.5)
	var moisture := PackedFloat32Array()
	var aridity := PackedFloat32Array()
	moisture.resize(map.cell_count())
	aridity.resize(map.cell_count())
	for i in map.cell_count():
		var c := map.cell_of(i)
		moisture[i] = moisture_noise.get_noise_2d(c.x, c.y)
		aridity[i] = heat_noise.get_noise_2d(c.x, c.y) - 0.6 * moisture[i]
	_normalize(moisture)
	_normalize(aridity)
	var flat := PackedInt32Array()
	for i in map.cell_count():
		if map.terrain[i] == T.PLAIN or map.terrain[i] == T.HILL:
			flat.append(i)
	# Déserts sur les plaines les plus arides, forêts sur les plus humides.
	var arid_values := PackedFloat32Array()
	for i in flat:
		arid_values.append(aridity[i])
	var desert_level := _quantile(arid_values, 1.0 - DESERT_FRACTION)
	for i in flat:
		if map.terrain[i] == T.PLAIN and aridity[i] >= desert_level:
			map.terrain[i] = T.DESERT
	var wet_values := PackedFloat32Array()
	for i in flat:
		if map.terrain[i] != T.DESERT:
			wet_values.append(moisture[i])
	var forest_level := _quantile(wet_values, 1.0 - FOREST_FRACTION)
	for i in flat:
		if map.terrain[i] != T.DESERT and moisture[i] >= forest_level:
			map.terrain[i] = T.FOREST
	# L'ensoleillement suit l'aridité (calculé ici pour réutiliser le bruit).
	for i in map.cell_count():
		map.sun[i] = aridity[i]


static func _compute_water_access(map: WorldMap) -> void:
	for i in map.cell_count():
		var c := map.cell_of(i)
		if map.is_water(c):
			continue
		for n in map.neighbors(c, WorldMap.NEIGHBORS_8):
			var t := map.get_terrain(n)
			if TerrainDb.is_water(t):
				map.water_access[i] = 1
			if t == T.SEA:
				map.coastal[i] = 1


static func _compute_climate(map: WorldMap, rng: RandomNumberGenerator) -> void:
	var gust_noise := _make_noise(rng, map.size, 6.0)
	for i in map.cell_count():
		var c := map.cell_of(i)
		var t := map.terrain[i]
		var e := map.elevation[i]
		var w := 0.15 + 0.6 * e + 0.15 * gust_noise.get_noise_2d(c.x, c.y)
		if t == T.SEA:
			w = 0.75 + 0.15 * gust_noise.get_noise_2d(c.x, c.y)
		elif map.coastal[i]:
			w += 0.2
		if t == T.FOREST:
			w -= 0.1
		map.wind[i] = clampf(w, 0.0, 1.0)
		var s := 0.25 + 0.6 * map.sun[i]
		if t == T.DESERT:
			s += 0.15
		elif t == T.MOUNTAIN:
			s += 0.05
		map.sun[i] = clampf(s, 0.0, 1.0)


static func _place_deposits(map: WorldMap, rng: RandomNumberGenerator) -> void:
	var land := 0
	for i in map.cell_count():
		if not map.is_water(map.cell_of(i)):
			land += 1
	for rule: Array in DEPOSIT_RULES:
		var kind: int = rule[0]
		var eligible: Array = rule[1]
		var noise := _make_noise(rng, map.size, 9.0)
		var cells := PackedInt32Array()
		var scores := PackedFloat32Array()
		for i in map.cell_count():
			if map.deposit[i] == WorldMap.Deposit.NONE and map.terrain[i] in eligible:
				var c := map.cell_of(i)
				cells.append(i)
				scores.append(noise.get_noise_2d(c.x, c.y))
		if cells.is_empty():
			continue
		var wanted := maxi(3, roundi(land * float(rule[2])))
		var level := _quantile(scores, 1.0 - float(wanted) / cells.size())
		var top := scores[0]
		for s in scores:
			top = maxf(top, s)
		for k in cells.size():
			if scores[k] < level:
				continue
			var richness := inverse_lerp(level, top, scores[k]) if top > level else 1.0
			var amount := lerpf(float(rule[3]), float(rule[4]), richness)
			map.deposit[cells[k]] = kind
			map.deposit_amount[cells[k]] = roundi(amount / 100.0) * 100
