extends Node2D
## Damier isométrique provisoire (M0) pour visualiser la caméra.
## Sera remplacé par la vraie carte TileMapLayer en M1.

const COLOR_A := Color("4f7a3a")
const COLOR_B := Color("5b8a43")
const COLOR_LINE := Color(0, 0, 0, 0.15)
const COLOR_HOVER := Color(1, 1, 1, 0.35)

var _hover := Vector2i(-1, -1)


func _ready() -> void:
	EventBus.game_started.connect(func(_seed: int) -> void: queue_redraw())


func _process(_delta: float) -> void:
	var cell := Iso.world_to_map(get_global_mouse_position())
	if not _in_map(cell):
		cell = Vector2i(-1, -1)
	if cell != _hover:
		_hover = cell
		queue_redraw()


func _draw() -> void:
	var size := GameState.map_size
	for y in size.y:
		for x in size.x:
			var color := COLOR_A if (x + y) % 2 == 0 else COLOR_B
			draw_colored_polygon(_diamond(Vector2i(x, y)), color)
	for i in size.x + 1:
		draw_line(_corner(i, 0), _corner(i, size.y), COLOR_LINE)
	for j in size.y + 1:
		draw_line(_corner(0, j), _corner(size.x, j), COLOR_LINE)
	if _in_map(_hover):
		draw_colored_polygon(_diamond(_hover), COLOR_HOVER)


func _in_map(cell: Vector2i) -> bool:
	return Rect2i(Vector2i.ZERO, GameState.map_size).has_point(cell)


## Coin nord de la tuile (x, y), i.e. sommet du losange.
func _corner(x: int, y: int) -> Vector2:
	return Iso.map_to_world(Vector2(x - 0.5, y - 0.5))


func _diamond(cell: Vector2i) -> PackedVector2Array:
	var c := Iso.map_to_world(Vector2(cell))
	return PackedVector2Array([
		c + Vector2(0, -Iso.HALF.y), c + Vector2(Iso.HALF.x, 0),
		c + Vector2(0, Iso.HALF.y), c + Vector2(-Iso.HALF.x, 0),
	])
