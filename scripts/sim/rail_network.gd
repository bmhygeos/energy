class_name RailNetwork
extends TrackNetwork
## Voies ferrées du bourg (section « Transport » du plan) : tuiles de voie
## posées au glisser (tracé en L), sur le territoire, hors des bâtiments et
## des zones. Une gare touchant la voie est desservie si la voie la relie à
## une gare du village (à Labor.FREE_DISTANCE tuiles du centre ou moins) :
## les tuiles autour d'elle se comptent depuis la gare, plus la longueur de
## voie (RAIL_TILES_PER_WALK_TILE tuiles de voie valent une tuile de marche,
## soit −1 % par tuile de voie au-delà de la portée). Les convois brûlent du
## charbon ; sans charbon, ils s'arrêtent. Tuiles stockées ramenées sur la
## planète. Pure donnée.

## Matériaux par tuile de voie (rails en fer, traverses en bois).
const IRON_PER_TILE := 1.0
const WOOD_PER_TILE := 1.0
## Tuiles de voie qui valent une tuile de marche.
const RAIL_TILES_PER_WALK_TILE := 3
## Charbon brûlé par jour : par gare desservie, et par tuile de voie jusqu'à elle.
const COAL_PER_STATION_PER_DAY := 1.0
const COAL_PER_RAIL_TILE_PER_DAY := 0.05


## Les convois roulent (assez de charbon la veille).
var running := true
## Gares desservies : tuile d'ancrage (ramenée) → longueur de voie depuis une
## gare du village.
var served: Dictionary[Vector2i, int] = {}


func has_rail(cell: Vector2i) -> bool:
	return has_tile(cell)


func base_costs() -> PackedFloat32Array:
	var values := Stockpile.zeros()
	values[Stockpile.Good.IRON] = IRON_PER_TILE
	values[Stockpile.Good.WOOD] = WOOD_PER_TILE
	return values


## Tuiles de voie touchant (4-connexité) l'emprise de [param b].
func access_tiles(b: Building) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell in b.cells:
		for o in WorldMap.NEIGHBORS_4:
			var n := map.wrap_cell(cell + o)
			if _tiles.has(n) and n not in result:
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
			for r in access_tiles(b):
				if not dist.has(r):
					dist[r] = 1
					queue.append(r)
	var head := 0
	while head < queue.size():
		var cell := queue[head]
		head += 1
		for o in WorldMap.NEIGHBORS_4:
			var n := map.wrap_cell(cell + o)
			if _tiles.has(n) and not dist.has(n):
				dist[n] = dist[cell] + 1
				queue.append(n)
	for b in stations:
		if is_village_station(b):
			continue
		var best := -1
		for r in access_tiles(b):
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
