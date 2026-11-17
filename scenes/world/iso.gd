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


## Rectangle monde englobant les tuiles de [param cells].
static func world_bounds(cells: Rect2i) -> Rect2:
	var o := Vector2(cells.position)
	var e := Vector2(cells.end - Vector2i.ONE)
	var left := map_to_world(Vector2(o.x, e.y)).x - HALF.x
	var right := map_to_world(Vector2(e.x, o.y)).x + HALF.x
	var top := map_to_world(o).y - HALF.y
	var bottom := map_to_world(e).y + HALF.y
	return Rect2(left, top, right - left, bottom - top)


## Tuiles couvrant l'écran de [param viewport], élargies de [param margin]
## tuiles (les calques dessinés tuile à tuile se limitent à l'écran).
static func visible_cells(viewport: Viewport, margin := 2) -> Rect2i:
	var inverse := viewport.get_canvas_transform().affine_inverse()
	var size := viewport.get_visible_rect().size
	var lo := Vector2i(1 << 30, 1 << 30)
	var hi := Vector2i(-(1 << 30), -(1 << 30))
	for corner in [Vector2.ZERO, Vector2(size.x, 0), Vector2(0, size.y), size]:
		var world: Vector2 = inverse * corner
		# Inverse de map_to_world : x − y et x + y depuis l'écran.
		var a := world.x / HALF.x - 1.0
		var b := world.y / HALF.y - 1.0
		var cell := Vector2i(floori((a + b) / 2.0), floori((b - a) / 2.0))
		lo = Vector2i(mini(lo.x, cell.x), mini(lo.y, cell.y))
		hi = Vector2i(maxi(hi.x, cell.x), maxi(hi.y, cell.y))
	return Rect2i(lo - Vector2i.ONE * margin, hi - lo + Vector2i.ONE * (2 * margin + 1))
