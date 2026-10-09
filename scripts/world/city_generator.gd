class_name CityGenerator
extends RefCounted
## Place les villes d'une nouvelle partie : terrain dégagé, sans gisement,
## espacées, de préférence près de l'eau.

const CITY_DEF: BuildingDef = preload("res://data/buildings/city.tres")
const NAMES: PackedStringArray = [
	"Valbrune", "Montclar", "Rivenoire", "Clairfont", "Beaulac", "Pierrelune",
	"Hautemarne", "Sablière", "Verdival", "Fontcalme", "Roccasel", "Aubrelieu",
]
const MIN_SPACING := 12
const EDGE_MARGIN := 3
## Tuiles de carte par ville.
const CELLS_PER_CITY := 800
const MIN_DEMAND := 3.0
const MAX_DEMAND := 10.0
const OPEN_TERRAINS: Array[int] = [TerrainDef.Type.PLAIN, TerrainDef.Type.HILL, TerrainDef.Type.DESERT]


## Place les villes dans [param registry] ; renvoie leurs bâtiments.
static func populate(registry: BuildingRegistry, rng: RandomNumberGenerator) -> Array[Building]:
	var map := registry.map
	var wanted := maxi(3, map.cell_count() / CELLS_PER_CITY)
	var candidates: Array = []
	for y in range(EDGE_MARGIN + CITY_DEF.size.y - 1, map.size.y - EDGE_MARGIN):
		for x in range(EDGE_MARGIN + CITY_DEF.size.x - 1, map.size.x - EDGE_MARGIN):
			var anchor := Vector2i(x, y)
			if _is_open(map, anchor):
				var score := rng.randf()
				for cell in CITY_DEF.footprint(anchor):
					score += 0.15 * map.water_access[map.index_of(cell)]
				candidates.append([score, anchor])
	candidates.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	# Copie explicite : Array(NAMES) partagerait les données de la constante.
	var names: Array[String] = []
	for n in NAMES:
		names.append(n)
	_shuffle(names, rng)
	var cities: Array[Building] = []
	for c: Array in candidates:
		if cities.size() >= wanted:
			break
		var anchor: Vector2i = c[1]
		if cities.any(func(b: Building) -> bool: return (b.anchor - anchor).length() < MIN_SPACING):
			continue
		var placement := registry.check_placement(CITY_DEF, anchor)
		if not placement.is_valid():
			continue
		var b := registry.place(placement)
		b.city = City.new(names[cities.size() % names.size()],
			snappedf(rng.randf_range(MIN_DEMAND, MAX_DEMAND), 0.5))
		cities.append(b)
	return cities


static func _is_open(map: WorldMap, anchor: Vector2i) -> bool:
	for cell in CITY_DEF.footprint(anchor):
		var i := map.index_of(cell)
		if map.terrain[i] not in OPEN_TERRAINS or map.deposit[i] != WorldMap.Deposit.NONE:
			return false
	return true


static func _shuffle(values: Array, rng: RandomNumberGenerator) -> void:
	for i in range(values.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Variant = values[i]
		values[i] = values[j]
		values[j] = tmp
