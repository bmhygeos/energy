class_name MapGenerator
extends RefCounted
## Génération procédurale déterministe de la planète, tuile par tuile.
##
## Chaque tuile est un point de la sphère (longitude, latitude) : les bruits
## 3D y sont échantillonnés, sans raccord à la ligne de changement de date et
## cohérents avec un futur globe. Le terrain d'une tuile ne dépend que de la
## graine et de sa position, ce qui permet de générer les blocs à la demande
## (generate_chunk) dans n'importe quel ordre.
##
## Étapes : altitude (continents + relief) → mer, collines, montagnes →
## température (latitude, altitude) → glace, toundra → lacs et rivières →
## humidité (bandes sèches subtropicales, équateur humide) → forêt, plaine,
## prairie, désert → fertilité, pâturage, bois, vent, soleil → gisements.
## Les seuils sont des quantiles mesurés à la création sur un échantillon de
## la sphère : chaque planète a les mêmes proportions de terrains.

const T := TerrainDef.Type

## Proportions de la planète (quantiles d'altitude).
const SEA_FRACTION := 0.6
const MOUNTAIN_FRACTION := 0.035
const HILL_FRACTION := 0.07
## Proportions des terres (quantiles d'humidité) : forêts, prairies, déserts.
const FOREST_FRACTION := 0.32
const PRAIRIE_FRACTION := 0.3
const DESERT_FRACTION := 0.12
## Part des terres en rivière et en lac.
const RIVER_FRACTION := 0.035
const LAKE_FRACTION := 0.02
## Températures (0 : pôle, 1 : équateur) de la banquise, de la glace et de la
## toundra ; refroidissement au sommet des montagnes ; désert seulement au chaud.
const SEA_ICE_TEMPERATURE := 0.08
const ICE_TEMPERATURE := 0.12
const TUNDRA_TEMPERATURE := 0.26
const ALTITUDE_COOLING := 0.35
const DESERT_MIN_TEMPERATURE := 0.45
## Périodes des bruits (tuiles).
const CONTINENT_PERIOD := 380.0
const RELIEF_PERIOD := 70.0
const MOISTURE_PERIOD := 45.0
const RIVER_PERIOD := 90.0
const LAKE_PERIOD := 30.0
const DETAIL_PERIOD := 12.0
const DEPOSIT_PERIOD := 9.0
## Taille de l'échantillon de calibrage des seuils.
const CALIBRATION_SAMPLES := 4096

## [type, terrains éligibles, part de la planète, quantité min, max (t)] ;
## en cas de chevauchement, la première règle l'emporte.
const DEPOSIT_RULES := [
	[WorldMap.Deposit.LITHIUM, [T.DESERT, T.HILL], 0.004, 300, 1000],
	[WorldMap.Deposit.URANIUM, [T.HILL, T.DESERT, T.PLAIN, T.TUNDRA], 0.004, 500, 1500],
	[WorldMap.Deposit.COPPER, [T.HILL, T.DESERT, T.PRAIRIE], 0.008, 10000, 30000],
	[WorldMap.Deposit.OIL, [T.DESERT, T.PLAIN, T.PRAIRIE, T.TUNDRA], 0.008, 3000, 10000],
	[WorldMap.Deposit.IRON, [T.HILL, T.PLAIN, T.FOREST, T.PRAIRIE, T.TUNDRA], 0.012, 15000, 45000],
	[WorldMap.Deposit.COAL, [T.PLAIN, T.HILL, T.FOREST, T.PRAIRIE], 0.016, 20000, 60000],
	[WorldMap.Deposit.STONE, [T.PLAIN, T.PRAIRIE, T.FOREST, T.TUNDRA, T.DESERT], 0.02, 20000, 60000],
]


## Champs d'une tuile calculés sans ses voisines.
class Fields:
	var terrain := 0
	var elevation := 0.0
	var temperature := 0.0
	var moisture := 0.0
	var latitude := 0.0


var size: Vector2i
var seed_value: int
## Seuils mesurés (altitude 0–1, humidité, bruits).
var sea_level := 0.0
var hill_level := 0.0
var mountain_level := 0.0
var forest_level := 0.0
var prairie_level := 0.0
var desert_level := 0.0
var river_level := 0.0
var lake_level := 0.0
var _deposit_levels := PackedFloat32Array()
var _radius := 1.0
var _elevation_lo := 0.0
var _elevation_hi := 1.0
var _continent: FastNoiseLite
var _relief: FastNoiseLite
var _moisture: FastNoiseLite
var _river: FastNoiseLite
var _lake: FastNoiseLite
var _detail: FastNoiseLite
var _deposits: Array[FastNoiseLite] = []


func _init(p_seed: int, p_size: Vector2i) -> void:
	seed_value = p_seed
	size = p_size
	_radius = size.x / TAU
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, "planet"])
	_continent = _make_noise(rng, CONTINENT_PERIOD, 3)
	_relief = _make_noise(rng, RELIEF_PERIOD, 5)
	_moisture = _make_noise(rng, MOISTURE_PERIOD, 4)
	_river = _make_noise(rng, RIVER_PERIOD, 2)
	_lake = _make_noise(rng, LAKE_PERIOD, 2)
	_detail = _make_noise(rng, DETAIL_PERIOD, 2)
	# La pierre a son propre tirage : le reste de la carte d'une graine ne change pas.
	var stone_rng := RandomNumberGenerator.new()
	stone_rng.seed = p_seed + 1
	for rule: Array in DEPOSIT_RULES:
		_deposits.append(_make_noise(stone_rng if rule[0] == WorldMap.Deposit.STONE else rng, DEPOSIT_PERIOD, 2))
	_calibrate(rng)


static func _make_noise(rng: RandomNumberGenerator, period: float, octaves: int) -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.seed = rng.randi()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = octaves
	noise.frequency = 1.0 / period
	return noise


## Point de la sphère (rayon : une unité par tuile à l'équateur) au centre de
## la tuile.
func _point(cell: Vector2i) -> Vector3:
	var lon := (cell.x + 0.5) / size.x * TAU
	var lat := (0.5 - (cell.y + 0.5) / size.y) * PI
	return Vector3(cos(lat) * cos(lon), cos(lat) * sin(lon), sin(lat)) * _radius


func _noise(n: FastNoiseLite, p: Vector3) -> float:
	return n.get_noise_3d(p.x, p.y, p.z)


func _raw_elevation(p: Vector3) -> float:
	return _noise(_continent, p) + 0.4 * _noise(_relief, p)


## Humidité brute : bruit, bande sèche vers 25° de latitude, équateur humide.
func _raw_moisture(p: Vector3, latitude: float) -> float:
	var lat := absf(latitude)
	return 0.5 + 0.5 * _noise(_moisture, p) - 0.25 * exp(-pow((lat - 25.0) / 10.0, 2)) \
		+ 0.12 * exp(-pow(lat / 10.0, 2))


## Mesure les seuils sur des points tirés uniformément sur la sphère.
func _calibrate(rng: RandomNumberGenerator) -> void:
	var cells: Array[Vector2i] = []
	var raw := PackedFloat32Array()
	for k in CALIBRATION_SAMPLES:
		var lat := asin(rng.randf_range(-1.0, 1.0))
		var y := clampi(int((0.5 - lat / PI) * size.y), 0, size.y - 1)
		var cell := Vector2i(rng.randi_range(0, size.x - 1), y)
		cells.append(cell)
		raw.append(_raw_elevation(_point(cell)))
	_elevation_lo = _quantile(raw, 0.0)
	_elevation_hi = _quantile(raw, 1.0)
	var elevation := PackedFloat32Array()
	for v in raw:
		elevation.append(_normalized_elevation(v))
	sea_level = _quantile(elevation, SEA_FRACTION)
	hill_level = _quantile(elevation, 1.0 - MOUNTAIN_FRACTION - HILL_FRACTION)
	mountain_level = _quantile(elevation, 1.0 - MOUNTAIN_FRACTION)
	var moisture := PackedFloat32Array()
	var river := PackedFloat32Array()
	var lake := PackedFloat32Array()
	for k in cells.size():
		if elevation[k] < sea_level:
			continue
		var p := _point(cells[k])
		moisture.append(_raw_moisture(p, 90.0 - (cells[k].y + 0.5) * 180.0 / size.y))
		river.append(absf(_noise(_river, p)))
		lake.append(_noise(_lake, p))
	forest_level = _quantile(moisture, 1.0 - FOREST_FRACTION)
	prairie_level = _quantile(moisture, PRAIRIE_FRACTION + DESERT_FRACTION)
	desert_level = _quantile(moisture, DESERT_FRACTION)
	river_level = _quantile(river, RIVER_FRACTION)
	lake_level = _quantile(lake, 1.0 - LAKE_FRACTION)
	for k in DEPOSIT_RULES.size():
		var values := PackedFloat32Array()
		for cell in cells:
			values.append(_noise(_deposits[k], _point(cell)))
		_deposit_levels.append(_quantile(values, 1.0 - float(DEPOSIT_RULES[k][2])))


func _normalized_elevation(raw: float) -> float:
	return clampf((raw - _elevation_lo) / maxf(_elevation_hi - _elevation_lo, 0.0001), 0.0, 1.0)


## Valeur au quantile [param q] (0–1) de [param values].
static func _quantile(values: PackedFloat32Array, q: float) -> float:
	if values.is_empty():
		return INF
	var sorted := values.duplicate()
	sorted.sort()
	return sorted[clampi(int(q * sorted.size()), 0, sorted.size() - 1)]


## Terrain, altitude, température et humidité de [param cell] (abscisse
## quelconque, ramenée sur la planète).
func fields(cell: Vector2i) -> Fields:
	cell.x = posmod(cell.x, size.x)
	var f := Fields.new()
	var p := _point(cell)
	f.latitude = 90.0 - (cell.y + 0.5) * 180.0 / size.y
	f.elevation = _normalized_elevation(_raw_elevation(p))
	var above_sea := maxf(0.0, f.elevation - sea_level) / maxf(1.0 - sea_level, 0.0001)
	f.temperature = clampf(1.0 - absf(f.latitude) / 90.0 - ALTITUDE_COOLING * above_sea
		+ 0.04 * _noise(_detail, p), 0.0, 1.0)
	f.moisture = _raw_moisture(p, f.latitude)
	var t := f.temperature
	if f.elevation < sea_level:
		f.terrain = T.ICE if t < SEA_ICE_TEMPERATURE else T.SEA
	elif t < ICE_TEMPERATURE:
		f.terrain = T.ICE
	elif f.elevation >= mountain_level:
		f.terrain = T.MOUNTAIN
	elif f.elevation < hill_level and _noise(_lake, p) > lake_level:
		f.terrain = T.LAKE
	elif absf(_noise(_river, p)) < river_level:
		f.terrain = T.RIVER
	elif f.elevation >= hill_level:
		f.terrain = T.HILL
	elif t < TUNDRA_TEMPERATURE:
		f.terrain = T.TUNDRA
	elif f.moisture >= forest_level:
		f.terrain = T.FOREST
	elif f.moisture < desert_level and t >= DESERT_MIN_TEMPERATURE:
		f.terrain = T.DESERT
	elif f.moisture < prairie_level:
		f.terrain = T.PRAIRIE
	else:
		f.terrain = T.PLAIN
	return f


## Génère le bloc [param coord] (en blocs) de la planète.
func generate_chunk(coord: Vector2i) -> WorldMap.Chunk:
	var n := WorldMap.CHUNK_SIZE
	var origin := coord * n
	# Terrains du bloc et d'une bordure d'une tuile, pour l'accès à l'eau.
	var border := PackedByteArray()
	border.resize((n + 2) * (n + 2))
	var inner: Array[Fields] = []
	inner.resize(n * n)
	for y in range(-1, n + 1):
		for x in range(-1, n + 1):
			var cell := origin + Vector2i(x, y)
			if cell.y < 0 or cell.y >= size.y:
				border[(y + 1) * (n + 2) + x + 1] = T.ICE
				continue
			var f := fields(cell)
			border[(y + 1) * (n + 2) + x + 1] = f.terrain
			if x >= 0 and y >= 0 and x < n and y < n:
				inner[y * n + x] = f
	var chunk := WorldMap.Chunk.new()
	for y in n:
		for x in n:
			var i := y * n + x
			var cell := origin + Vector2i(x, y)
			var f := inner[i]
			var def := TerrainDb.get_def(f.terrain)
			chunk.terrain[i] = f.terrain
			chunk.elevation[i] = f.elevation
			chunk.temperature[i] = f.temperature
			chunk.variant[i] = posmod(hash(Vector3i(cell.x, cell.y, seed_value)), 4)
			if not def.is_water:
				for o in WorldMap.NEIGHBORS_8:
					var t := border[(y + 1 + o.y) * (n + 2) + x + 1 + o.x]
					if TerrainDb.is_water(t):
						chunk.water_access[i] = 1
					if t == T.SEA:
						chunk.coastal[i] = 1
			_fill_attributes(chunk, i, cell, f, def)
			_place_deposit(chunk, i, cell)
	return chunk


## Fertilité, pâturage, bois, vent et soleil d'une tuile.
func _fill_attributes(chunk: WorldMap.Chunk, i: int, cell: Vector2i, f: Fields, def: TerrainDef) -> void:
	var p := _point(cell)
	var detail := _noise(_detail, p)
	var t := f.temperature
	if not def.is_water:
		var fertility := def.fertility * clampf((t - 0.2) / 0.35, 0.0, 1.0) + 0.1 * detail
		if chunk.water_access[i] and def.fertility > 0.0:
			fertility += 0.15  # berges
		chunk.fertility[i] = clampf(fertility, 0.0, 1.0) if def.fertility > 0.0 else 0.0
		var pasture := def.pasture * clampf((t - 0.12) / 0.3, 0.0, 1.0) + 0.1 * detail
		chunk.pasture[i] = clampf(pasture, 0.0, 1.0) if def.pasture > 0.0 else 0.0
	if f.terrain == T.FOREST:
		var density := 0.45 + 0.55 * (f.moisture - forest_level) / maxf(1.0 - forest_level, 0.01) + 0.1 * detail
		chunk.wood[i] = roundf(WorldMap.WOOD_PER_FOREST * clampf(density, 0.3, 1.0))
	var lat := absf(f.latitude)
	var above_sea := maxf(0.0, f.elevation - sea_level) / maxf(1.0 - sea_level, 0.0001)
	var westerlies := 0.15 * exp(-pow((lat - 50.0) / 15.0, 2))
	var w := 0.2 + 0.5 * above_sea + 0.15 * detail + westerlies
	if f.terrain == T.SEA:
		w = 0.7 + 0.15 * detail + westerlies
	elif chunk.coastal[i]:
		w += 0.2
	if f.terrain == T.FOREST:
		w -= 0.1
	chunk.wind[i] = clampf(w, 0.0, 1.0)
	var s := 0.2 + 0.6 * cos(deg_to_rad(lat)) + 0.25 * (0.5 - f.moisture)
	if f.terrain == T.DESERT:
		s += 0.1
	chunk.sun[i] = clampf(s, 0.0, 1.0)


func _place_deposit(chunk: WorldMap.Chunk, i: int, cell: Vector2i) -> void:
	var p := _point(cell)
	for k in DEPOSIT_RULES.size():
		var rule: Array = DEPOSIT_RULES[k]
		if chunk.terrain[i] not in rule[1]:
			continue
		var v := _noise(_deposits[k], p)
		if v < _deposit_levels[k]:
			continue
		var richness := clampf((v - _deposit_levels[k]) / 0.2, 0.0, 1.0)
		chunk.deposit[i] = rule[0]
		chunk.deposit_amount[i] = roundi(lerpf(float(rule[3]), float(rule[4]), richness) / 100.0) * 100
		return
