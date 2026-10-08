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
	var c := map_to_world(Vector2(cell))
	return PackedVector2Array([
		c + Vector2(0, -HALF.y), c + Vector2(HALF.x, 0),
		c + Vector2(0, HALF.y), c + Vector2(-HALF.x, 0),
	])


## Rectangle monde englobant une carte de [param size] tuiles.
static func world_bounds(size: Vector2i) -> Rect2:
	var left := map_to_world(Vector2(0, size.y - 1)).x - HALF.x
	var right := map_to_world(Vector2(size.x - 1, 0)).x + HALF.x
	var top := map_to_world(Vector2.ZERO).y - HALF.y
	var bottom := map_to_world(Vector2(size.x - 1, size.y - 1)).y + HALF.y
	return Rect2(left, top, right - left, bottom - top)
