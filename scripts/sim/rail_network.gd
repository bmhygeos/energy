class_name RailNetwork
extends RefCounted
## Voies ferrées du bourg (section « Transport » du plan) : tuiles de voie
## posées au glisser (tracé en L), sur le territoire, hors des bâtiments et
## des zones. Une gare touchant la voie est desservie si la voie la relie à
## une gare du village (à Labor.FREE_DISTANCE tuiles du centre ou moins) :
## les tuiles autour d'elle se comptent depuis la gare, plus la longueur de
## voie (RAIL_TILES_PER_WALK_TILE tuiles de voie valent une tuile de marche,
## soit −1 % par tuile de voie au-delà de la portée). Les convois brûlent du
## charbon ; sans charbon, ils s'arrêtent. Tuiles stockées ramenées sur la
## planète. Pure donnée.

## Matériaux par tuile de voie (rails en fer, traverses en bois) ; un pont sur
## une rivière coûte BRIDGE_FACTOR fois plus.
const IRON_PER_TILE := 1.0
const WOOD_PER_TILE := 1.0
const BRIDGE_FACTOR := 5.0
const FORBIDDEN: Array[TerrainDef.Type] = [TerrainDef.Type.MOUNTAIN, TerrainDef.Type.LAKE,
	TerrainDef.Type.SEA, TerrainDef.Type.ICE]
## Tuiles de voie qui valent une tuile de marche.
const RAIL_TILES_PER_WALK_TILE := 3
## Charbon brûlé par jour : par gare desservie, et par tuile de voie jusqu'à elle.
const COAL_PER_STATION_PER_DAY := 1.0
const COAL_PER_RAIL_TILE_PER_DAY := 0.05


## Aperçu d'un tracé de voie.
class Plan:
	## Tuiles du tracé (repère de l'appelant).
	var cells: Array[Vector2i] = []
	## Tuiles sans voie à poser.
	var new_cells: Array[Vector2i] = []
	## Forêts défrichées.
	var cleared: Array[Vector2i] = []
	var costs := Stockpile.zeros()
	## Message d'erreur ; vide si le tracé est possible.
	var error := ""

	func is_valid() -> bool:
		return error.is_empty() and not new_cells.is_empty()


var map: WorldMap
var territory: Territory
var buildings: BuildingRegistry
## Zones (null : pas de vérification).
var zones: ZoneMap
## Centre du village.
var center: Vector2i
## Les convois roulent (assez de charbon la veille).
var running := true
## Gares desservies : tuile d'ancrage (ramenée) → longueur de voie depuis une
## gare du village.
var served: Dictionary[Vector2i, int] = {}
var _rails: Dictionary[Vector2i, bool] = {}


func _init(p_map: WorldMap, p_territory: Territory, p_buildings: BuildingRegistry, p_center: Vector2i) -> void:
	map = p_map
	territory = p_territory
	buildings = p_buildings
	center = p_center


func has_rail(cell: Vector2i) -> bool:
	return _rails.has(map.wrap_cell(cell))


func tile_count() -> int:
	return _rails.size()


## Tuiles de voie (ramenées sur la planète).
func cells() -> Array[Vector2i]:
	return _rails.keys()


## Tracé en L de [param from] à [param to] : l'axe le plus long d'abord.
static func l_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = [from]
	var d := to - from
	var corner := Vector2i(to.x, from.y) if absi(d.x) >= absi(d.y) else Vector2i(from.x, to.y)
	for target in [corner, to]:
		var cell: Vector2i = path[-1]
		while cell != target:
			cell += Vector2i(signi(target.x - cell.x), signi(target.y - cell.y))
			path.append(cell)
	return path


## Motif qui empêche une voie sur [param cell] (vide : possible).
func check_cell(cell: Vector2i) -> String:
	if not map.has_cell(cell) or not territory.is_territory(cell):
		return "Hors du territoire"
	var b := buildings.building_at(cell)
	if b:
		return "Bâtiment présent (%s)" % b.def.display_name
	if zones and zones.zone_at(cell):
		return "Zone présente (%s) : effacez-la d'abord" % zones.zone_at(cell).display_name
	var t := map.get_terrain(cell)
	if t in FORBIDDEN:
		return "Pas de voie sur : %s" % TerrainDb.get_def(t).display_name.to_lower()
	return ""


## Matériaux pour une voie sur [param cell].
func tile_costs(cell: Vector2i) -> PackedFloat32Array:
	var values := Stockpile.zeros()
	var factor := BRIDGE_FACTOR if map.get_terrain(cell) == TerrainDef.Type.RIVER else 1.0
	values[Stockpile.Good.IRON] = IRON_PER_TILE * factor
	values[Stockpile.Good.WOOD] = WOOD_PER_TILE * factor
	return values


## Aperçu du tracé de [param from] à [param to].
func plan(from: Vector2i, to: Vector2i) -> Plan:
	var p := Plan.new()
	p.cells = l_path(from, to)
	for cell in p.cells:
		if has_rail(cell):
			continue
		var error := check_cell(cell)
		if not error.is_empty():
			p.error = error
			p.new_cells.clear()
			return p
		p.new_cells.append(cell)
		if map.get_terrain(cell) == TerrainDef.Type.FOREST:
			p.cleared.append(cell)
		var costs := tile_costs(cell)
		for good in Stockpile.COUNT:
			p.costs[good] += costs[good]
	if p.new_cells.is_empty():
		p.error = "Voie déjà posée"
	return p


## Pose les voies d'un tracé valide (forêts défrichées) ; renvoie les tuiles
## posées.
func build(p: Plan) -> Array[Vector2i]:
	assert(p.is_valid(), "Tracé invalide : " + p.error)
	for cell in p.cleared:
		map.set_terrain(cell, TerrainDef.Type.PLAIN)
		map.set_wood(cell, 0.0)
	add_cells(p.new_cells)
	return p.new_cells


## Ajoute des voies sans coût ni vérification (tests).
func add_cells(new_cells: Array[Vector2i]) -> void:
	for cell in new_cells:
		_rails[map.wrap_cell(cell)] = true


func remove(cell: Vector2i) -> bool:
	return _rails.erase(map.wrap_cell(cell))


## Distance de Tchebychev entre deux tuiles (longitude bouclée).
func cheb(a: Vector2i, b: Vector2i) -> int:
	var w := map.size.x
	var dx := absi(posmod(a.x - b.x + w / 2, w) - w / 2)
	return maxi(dx, absi(a.y - b.y))


## Tuiles de voie touchant (4-connexité) l'emprise de [param b].
func access_rails(b: Building) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell in b.cells:
		for o in WorldMap.NEIGHBORS_4:
			var n := map.wrap_cell(cell + o)
			if _rails.has(n) and n not in result:
				result.append(n)
	return result


## Gare du village : à Labor.FREE_DISTANCE tuiles du centre ou moins.
func is_village_station(b: Building) -> bool:
	return cheb(b.anchor, center) <= Labor.FREE_DISTANCE


## Recalcule les gares desservies parmi [param stations] (terminées) : plus
## court chemin par la voie depuis les gares du village.
func refresh(stations: Array[Building]) -> void:
	served.clear()
	var dist: Dictionary[Vector2i, int] = {}
	var queue: Array[Vector2i] = []
	for b in stations:
		if is_village_station(b):
			for r in access_rails(b):
				if not dist.has(r):
					dist[r] = 1
					queue.append(r)
	var head := 0
	while head < queue.size():
		var cell := queue[head]
		head += 1
		for o in WorldMap.NEIGHBORS_4:
			var n := map.wrap_cell(cell + o)
			if _rails.has(n) and not dist.has(n):
				dist[n] = dist[cell] + 1
				queue.append(n)
	for b in stations:
		if is_village_station(b):
			continue
		var best := -1
		for r in access_rails(b):
			if dist.has(r) and (best < 0 or dist[r] < best):
				best = dist[r]
		if best > 0:
			served[map.wrap_cell(b.anchor)] = best


## Distance de [param cell] au village par le train (-1 : aucune gare
## desservie, ou convois arrêtés).
func distance_via(cell: Vector2i) -> int:
	if not running or served.is_empty():
		return -1
	var best := -1
	for station: Vector2i in served:
		var d := cheb(cell, station) + ceili(float(served[station]) / RAIL_TILES_PER_WALK_TILE)
		if best < 0 or d < best:
			best = d
	return best


## Charbon brûlé par jour par les convois.
func coal_need() -> float:
	var total := 0.0
	for station: Vector2i in served:
		total += COAL_PER_STATION_PER_DAY + COAL_PER_RAIL_TILE_PER_DAY * served[station]
	return total
