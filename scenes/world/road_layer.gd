extends Node2D
## Dessin des routes (bandes isométriques reliant les tuiles voisines) et
## des ponts sur les rivières.

## Demi-largeur de la chaussée, en tuiles.
const HALF_WIDTH := 0.2
const BORDER := 0.05
const ROAD_COLOR := Color("6b665e")
const BORDER_COLOR := Color("3f3b36")
const BRIDGE_COLOR := Color("8f6a40")
const RAIL_COLOR := Color("4a3520")
const LINE_COLOR := Color(1, 1, 1, 0.35)
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


func _ready() -> void:
	EventBus.roads_changed.connect(func(_cells: Array[Vector2i]) -> void: queue_redraw())
	EventBus.game_started.connect(func(_seed: int) -> void: queue_redraw())


func _draw() -> void:
	var roads := GameState.roads
	if roads == null:
		return
	var map := roads.map
	# Deux passes : bordures puis chaussées, pour des jonctions propres.
	for pass_index in 2:
		var w := HALF_WIDTH + (BORDER if pass_index == 0 else 0.0)
		for i in map.cell_count():
			var cell := map.cell_of(i)
			if not roads.has_road(cell):
				continue
			var bridge := map.terrain[i] == TerrainDef.Type.RIVER
			var color := BORDER_COLOR if pass_index == 0 else (BRIDGE_COLOR if bridge else ROAD_COLOR)
			_quad(cell, [Vector2(-w, -w), Vector2(w, -w), Vector2(w, w), Vector2(-w, w)], color)
			for dir in DIRS:
				if not roads.has_road(cell + dir):
					continue
				var d := Vector2(dir)
				var p := Vector2(-d.y, d.x) * w
				_quad(cell, [p, p + d * 0.5, -p + d * 0.5, -p], color)
				if pass_index == 1:
					if bridge:
						for side: float in [1.0, -1.0]:
							var e := Vector2(-d.y, d.x) * HALF_WIDTH * side
							draw_line(_w(cell, e), _w(cell, e + d * 0.5), RAIL_COLOR, 2.0)
					else:
						draw_line(_w(cell, d * 0.12), _w(cell, d * 0.38), LINE_COLOR, 1.5)


func _w(cell: Vector2i, offset: Vector2) -> Vector2:
	return Iso.map_to_world(Vector2(cell) + offset)


func _quad(cell: Vector2i, offsets: Array, color: Color) -> void:
	var points := PackedVector2Array()
	for o: Vector2 in offsets:
		points.append(_w(cell, o))
	draw_colored_polygon(points, color)
