class_name RoadNetwork
extends TrackNetwork
## Routes du bourg : tuiles posées au glisser (tracé en L). Une route reliée au
## village (une de ses tuiles à Labor.FREE_DISTANCE tuiles du centre ou moins)
## rapproche les tuiles à REACH tuiles ou moins d'elle : leur distance se
## compte depuis la route, plus sa longueur (TILES_PER_WALK_TILE tuiles de
## route valent une tuile de marche). Sans combustible : charrettes et
## piétons. Un dépôt de camions touchant une route reliée porte la route plus
## loin : TRUCK_FREE_TILES tuiles sans pénalité, puis TRUCK_TILES_PER_WALK_TILE
## tuiles de route par tuile de marche, contre du carburant. Une route peut
## croiser une voie ferrée (passage à niveau). Pure donnée.

## Pavés par tuile.
const STONE_PER_TILE := 2.0
## Tuiles de route qui valent une tuile de marche.
const TILES_PER_WALK_TILE := 2
## Tuiles desservies de part et d'autre de la route.
const REACH := 2
## Camions : tuiles de route sans pénalité, tuiles de route qui valent une tuile
## de marche ensuite (−0,5 % par tuile), et tuiles desservies de part et d'autre.
const TRUCK_FREE_TILES := 30
const TRUCK_TILES_PER_WALK_TILE := 6
const TRUCK_REACH := 3
## Carburant brûlé par jour : par dépôt, et par tuile de route reliée.
const FUEL_PER_DEPOT_PER_DAY := 2.0
const FUEL_PER_TILE_PER_DAY := 0.05

## Tuiles de route reliées au village → longueur depuis le village.
var lengths: Dictionary[Vector2i, int] = {}
## Dépôts terminés (posés par GameState avant refresh).
var depots: Array[Building] = []
## Les camions roulent (assez de carburant la veille).
var running := true
## Dépôts qui touchent une route reliée.
var served_depots: Array[Building] = []
## Tuiles desservies → distance au village par la route.
var _reach: Dictionary[Vector2i, int] = {}


func track_name() -> String:
	return "route"


func base_costs() -> PackedFloat32Array:
	var values := Stockpile.zeros()
	values[Stockpile.Good.STONE] = STONE_PER_TILE
	return values


## Recalcule les tuiles reliées au village et celles qu'elles desservent.
func refresh() -> void:
	lengths.clear()
	_reach.clear()
	var queue: Array[Vector2i] = []
	for cell: Vector2i in _tiles:
		if cheb(cell, center) <= Labor.FREE_DISTANCE:
			lengths[cell] = 1
			queue.append(cell)
	var head := 0
	while head < queue.size():
		var cell := queue[head]
		head += 1
		for o in WorldMap.NEIGHBORS_4:
			var n := map.wrap_cell(cell + o)
			if _tiles.has(n) and not lengths.has(n):
				lengths[n] = lengths[cell] + 1
				queue.append(n)
	served_depots = depots.filter(_touches_road)
	var reach := TRUCK_REACH if has_trucks() else REACH
	for cell: Vector2i in lengths:
		var base := _walk_tiles(lengths[cell])
		for dy in range(-reach, reach + 1):
			for dx in range(-reach, reach + 1):
				var n := map.wrap_cell(cell + Vector2i(dx, dy))
				var d := base + maxi(absi(dx), absi(dy))
				if not _reach.has(n) or d < _reach[n]:
					_reach[n] = d


## Des camions roulent sur les routes reliées.
func has_trucks() -> bool:
	return running and not served_depots.is_empty()


## Carburant brûlé par jour par les camions (0 : aucun dépôt desservi).
func fuel_need() -> float:
	if served_depots.is_empty():
		return 0.0
	return FUEL_PER_DEPOT_PER_DAY * served_depots.size() + FUEL_PER_TILE_PER_DAY * lengths.size()


## Tuiles de marche équivalentes à [param length] tuiles de route.
func _walk_tiles(length: int) -> int:
	if has_trucks():
		return ceili(float(maxi(0, length - TRUCK_FREE_TILES)) / TRUCK_TILES_PER_WALK_TILE)
	return ceili(float(length) / TILES_PER_WALK_TILE)


func _touches_road(b: Building) -> bool:
	for cell in b.cells:
		for o in WorldMap.NEIGHBORS_4:
			if lengths.has(map.wrap_cell(cell + o)):
				return true
	return false


## Distance de [param cell] au village par la route (-1 : non desservie).
func distance_via(cell: Vector2i) -> int:
	return _reach.get(map.wrap_cell(cell), -1)
