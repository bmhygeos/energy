class_name Iso
extends RefCounted
## Géométrie isométrique (losange 2:1, layout Diamond Down), identique à
## TileMapLayer.map_to_local pour le TileSet de la carte (vérifié par les tests).

const TILE_SIZE := Vector2i(128, 64)
const HALF := Vector2(TILE_SIZE) / 2.0


## Centre de la tuile [param cell] en coordonnées monde.
static func map_to_world(cell: Vector2) -> Vector2:
	return Vector2((cell.x - cell.y + 1.0) * HALF.x, (cell.x + cell.y + 1.0) * HALF.y)


## Sommets du losange de la tuile [param cell] (nord, est, sud, ouest).
static func diamond(cell: Vector2i) -> PackedVector2Array:
	return footprint_diamond(cell, Vector2i.ONE)


## Sommets (nord, est, sud, ouest) du losange couvrant [param size] tuiles à
## partir de [param origin] (tuile de x et y minimaux).
static func footprint_diamond(origin: Vector2i, size: Vector2i) -> PackedVector2Array:
	var o := Vector2(origin) - Vector2(0.5, 0.5)
	var e := o + Vector2(size)
	return PackedVector2Array([
		map_to_world(o), map_to_world(Vector2(e.x, o.y)),
		map_to_world(e), map_to_world(Vector2(o.x, e.y)),
	])


## Rectangle monde englobant une carte de [param size] tuiles.
static func world_bounds(size: Vector2i) -> Rect2:
	var left := map_to_world(Vector2(0, size.y - 1)).x - HALF.x
	var right := map_to_world(Vector2(size.x - 1, 0)).x + HALF.x
	var top := map_to_world(Vector2.ZERO).y - HALF.y
	var bottom := map_to_world(Vector2(size.x - 1, size.y - 1)).y + HALF.y
	return Rect2(left, top, right - left, bottom - top)
