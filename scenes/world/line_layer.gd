extends Node2D
## Dessin des lignes électriques (fil entre les tuiles voisines, poteau au
## centre de chaque tuile), dans le repère de la vue. Une ligne non reliée au
## village est plus terne.

const LINE_COLOR := Color("e0a23c")
const LOOSE_COLOR := Color("8a7a5c")
const POLE_COLOR := Color("4a3a2a")
const POLE_HEIGHT := 18.0


func _ready() -> void:
	EventBus.grid_changed.connect(func(_cells: Array[Vector2i]) -> void: queue_redraw())
	EventBus.game_started.connect(func(_seed: int) -> void: queue_redraw())


func _draw() -> void:
	var grid := GameState.grid
	if grid == null or grid.tile_count() == 0:
		return
	var top := Vector2(0.0, -POLE_HEIGHT)
	for c in grid.cells():
		var cell := GameState.display_cell(c)
		var center := Iso.map_to_world(Vector2(cell))
		var color := LINE_COLOR if grid.linked.has(c) else LOOSE_COLOR
		for dir: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
			if grid.has_tile(cell + dir):
				draw_line(center + top, Iso.map_to_world(Vector2(cell + dir)) + top, color, 2.0)
		draw_line(center, center + top, POLE_COLOR, 3.0)
		draw_circle(center + top, 3.0, color)
