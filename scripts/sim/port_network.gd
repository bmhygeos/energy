class_name PortNetwork
extends RefCounted
## Ports de la ville : deux ports reliés par des eaux découvertes échangent
## leurs marchandises par bateau. Dans chaque bassin, le port le plus proche
## du village sert de tête de ligne ; les tuiles autour des autres se comptent
## depuis eux, plus le trajet par l'eau (SHIP_TILES_PER_WALK_TILE tuiles d'eau
## valent une tuile de marche). Les bateaux rapprochent aussi les eaux de
## pêche. Tuiles stockées ramenées sur la planète. Pure donnée.

## Tuiles d'eau qui valent une tuile de marche.
const SHIP_TILES_PER_WALK_TILE := 4

var map: WorldMap
var territory: Territory
## Ports : tuile d'ancrage (ramenée) → distance au village, en tuiles de marche.
var distances: Dictionary[Vector2i, int] = {}
## Ports reliés par l'eau à une tête de ligne : tuile d'ancrage (ramenée) →
## tuiles d'eau parcourues.
var linked: Dictionary[Vector2i, int] = {}


func _init(p_map: WorldMap, p_territory: Territory) -> void:
	map = p_map
	territory = p_territory


## Recalcule les liaisons entre [param ports] (terminés) ; [param walk] donne
## la distance au village d'une tuile sans passer par les ports.
func refresh(ports: Array[Building], walk: Callable) -> void:
	distances.clear()
	linked.clear()
	var ordered := ports.duplicate()
	var walked: Dictionary[Building, int] = {}
	for b: Building in ordered:
		walked[b] = walk.call(b.anchor)
	ordered.sort_custom(func(a: Building, b: Building) -> bool:
		return walked[a] < walked[b] or walked[a] == walked[b] and _before(a.anchor, b.anchor))
	for hub: Building in ordered:
		var anchor := map.wrap_cell(hub.anchor)
		if distances.has(anchor):
			continue
		distances[anchor] = walked[hub]
		if ordered.size() < 2:
			continue
		var water := _flood(hub)
		for other: Building in ordered:
			var key := map.wrap_cell(other.anchor)
			if distances.has(key):
				continue
			var length := _nearest_water(other, water)
			if length >= 0:
				linked[key] = length
				distances[key] = mini(walked[other], walked[hub] + ceili(float(length) / SHIP_TILES_PER_WALK_TILE))


## Distance de [param cell] au village en passant par un port (-1 : aucun
## port) ; sur l'eau, le trajet depuis le port se fait en bateau.
func distance_via(cell: Vector2i) -> int:
	var best := -1
	var at_sea := map.is_water(cell)
	for port: Vector2i in distances:
		var tiles := cheb(cell, port)
		if at_sea:
			tiles = ceili(float(tiles) / SHIP_TILES_PER_WALK_TILE)
		var d := distances[port] + tiles
		if best < 0 or d < best:
			best = d
	return best


## Le port d'ancrage [param anchor] est relié par l'eau à une tête de ligne.
func is_linked(anchor: Vector2i) -> bool:
	return linked.has(map.wrap_cell(anchor))


func cheb(a: Vector2i, b: Vector2i) -> int:
	var w := map.size.x
	var dx := absi(posmod(a.x - b.x + w / 2, w) - w / 2)
	return maxi(dx, absi(a.y - b.y))


## Tuiles d'eau découvertes touchant l'emprise de [param b] (ramenées).
func _quays(b: Building) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell in b.cells:
		for n in map.neighbors(cell, WorldMap.NEIGHBORS_8):
			var w := map.wrap_cell(n)
			if map.is_water(w) and territory.is_known(w) and w not in result:
				result.append(w)
	return result


## Eaux découvertes accessibles depuis [param b] : tuile (ramenée) → tuiles
## parcourues.
func _flood(b: Building) -> Dictionary[Vector2i, int]:
	var dist: Dictionary[Vector2i, int] = {}
	var queue := _quays(b)
	for cell in queue:
		dist[cell] = 1
	var head := 0
	while head < queue.size():
		var cell := queue[head]
		head += 1
		for n in map.neighbors(cell, WorldMap.NEIGHBORS_8):
			var w := map.wrap_cell(n)
			if not dist.has(w) and map.is_water(w) and territory.is_known(w):
				dist[w] = dist[cell] + 1
				queue.append(w)
	return dist


## Plus court trajet de [param water] jusqu'à un quai de [param b] (-1 : aucun).
func _nearest_water(b: Building, water: Dictionary[Vector2i, int]) -> int:
	var best := -1
	for cell in _quays(b):
		if water.has(cell) and (best < 0 or water[cell] < best):
			best = water[cell]
	return best


static func _before(a: Vector2i, b: Vector2i) -> bool:
	return a.y < b.y or a.y == b.y and a.x < b.x
