class_name Iso
extends RefCounted
## Conversions grille ↔ monde pour la vue isométrique (losange 2:1).
## Provisoire jusqu'à M1, où TileMapLayer.map_to_local / local_to_map
## prendront le relais.

const TILE_SIZE := Vector2i(128, 64)
const HALF := Vector2(TILE_SIZE) / 2.0


## Centre de la tuile [param cell] en coordonnées monde.
static func map_to_world(cell: Vector2) -> Vector2:
	return Vector2((cell.x - cell.y) * HALF.x, (cell.x + cell.y) * HALF.y)


static func world_to_map(pos: Vector2) -> Vector2i:
	var fx := (pos.x / HALF.x + pos.y / HALF.y) / 2.0
	var fy := (pos.y / HALF.y - pos.x / HALF.x) / 2.0
	return Vector2i(roundi(fx), roundi(fy))


## Rectangle monde englobant une carte de [param size] tuiles.
static func world_bounds(size: Vector2i) -> Rect2:
	var left := map_to_world(Vector2(0, size.y - 1)).x - HALF.x
	var right := map_to_world(Vector2(size.x - 1, 0)).x + HALF.x
	var top := -HALF.y
	var bottom := map_to_world(Vector2(size.x - 1, size.y - 1)).y + HALF.y
	return Rect2(left, top, right - left, bottom - top)
