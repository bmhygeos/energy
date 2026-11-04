class_name RoadNetwork
extends TrackNetwork
## Routes du bourg : tuiles posées au glisser (tracé en L). Une route reliée au
## village (une de ses tuiles à Labor.FREE_DISTANCE tuiles du centre ou moins)
## rapproche les tuiles à REACH tuiles ou moins d'elle : leur distance se
## compte depuis la route, plus sa longueur (TILES_PER_WALK_TILE tuiles de
## route valent une tuile de marche). Sans combustible : charrettes et
## piétons. Une route peut croiser une voie ferrée (passage à niveau). Pure
## donnée.

## Pavés par tuile.
const STONE_PER_TILE := 2.0
## Tuiles de route qui valent une tuile de marche.
const TILES_PER_WALK_TILE := 2
## Tuiles desservies de part et d'autre de la route.
const REACH := 2

## Tuiles de route reliées au village → longueur depuis le village.
var lengths: Dictionary[Vector2i, int] = {}
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
	for cell: Vector2i in lengths:
		var base := ceili(float(lengths[cell]) / TILES_PER_WALK_TILE)
		for dy in range(-REACH, REACH + 1):
			for dx in range(-REACH, REACH + 1):
				var n := map.wrap_cell(cell + Vector2i(dx, dy))
				var d := base + maxi(absi(dx), absi(dy))
				if not _reach.has(n) or d < _reach[n]:
					_reach[n] = d


## Distance de [param cell] au village par la route (-1 : non desservie).
func distance_via(cell: Vector2i) -> int:
	return _reach.get(map.wrap_cell(cell), -1)
