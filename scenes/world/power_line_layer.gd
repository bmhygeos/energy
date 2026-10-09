extends Node2D
## Dessin des lignes haute tension : un pylône par tuile, câbles entre
## pylônes voisins (au-dessus des bâtiments, comme un calque).

const PYLON_HEIGHT := 28.0
const PYLON_COLOR := Color("4b4f57")
const WIRE_COLOR := Color(0.12, 0.12, 0.14, 0.85)
const SAG := 5.0


func _ready() -> void:
	EventBus.lines_changed.connect(func(_cells: Array[Vector2i]) -> void: queue_redraw())
	EventBus.game_started.connect(func(_seed: int) -> void: queue_redraw())


func _draw() -> void:
	var grid := GameState.grid
	if grid == null:
		return
	var map := grid.map
	var top := Vector2(0, -PYLON_HEIGHT)
	for i in map.cell_count():
		var cell := map.cell_of(i)
		if not grid.has_line(cell):
			continue
		var c := Iso.map_to_world(Vector2(cell))
		# Pylône en treillis : deux pieds, deux traverses, une console.
		draw_line(c + Vector2(-6, 0), c + top + Vector2(-1, 0), PYLON_COLOR, 2.0)
		draw_line(c + Vector2(6, 0), c + top + Vector2(1, 0), PYLON_COLOR, 2.0)
		draw_line(c + Vector2(-4, -9), c + Vector2(4, -9), PYLON_COLOR, 1.5)
		draw_line(c + Vector2(-3, -18), c + Vector2(3, -18), PYLON_COLOR, 1.5)
		draw_line(c + top + Vector2(-9, 3), c + top + Vector2(9, 3), PYLON_COLOR, 2.0)
		for dir in [Vector2i(1, 0), Vector2i(0, 1)]:
			var n: Vector2i = cell + dir
			if not grid.has_line(n):
				continue
			var to := Iso.map_to_world(Vector2(n)) + top + Vector2(0, 3)
			var from := c + top + Vector2(0, 3)
			var mid := (from + to) / 2.0 + Vector2(0, SAG)
			for side: float in [-1.0, 1.0]:
				var o := Vector2(8.0 * side, 0)
				draw_polyline(PackedVector2Array([from + o, mid + o, to + o]), WIRE_COLOR, 1.0, true)
