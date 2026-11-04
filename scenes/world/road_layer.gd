extends Node2D
## Dessin des routes (bande pavée reliant les tuiles voisines ; pont en bois
## sur les rivières), dans le repère de la vue, au-dessus des zones et sous
## les voies ferrées. Une route non reliée au village est plus terne.

const HALF_WIDTH := 0.22
const ROAD_COLOR := Color("b5a58a")
const LOOSE_COLOR := Color("8d8574")
const BRIDGE_COLOR := Color("6e5236")


func _ready() -> void:
	EventBus.roads_changed.connect(func(_cells: Array[Vector2i]) -> void: queue_redraw())
	EventBus.game_started.connect(func(_seed: int) -> void: queue_redraw())


func _draw() -> void:
	var roads := GameState.roads
	if roads == null or roads.tile_count() == 0:
		return
	for c in roads.cells():
		var cell := GameState.display_cell(c)
		var color := ROAD_COLOR if roads.lengths.has(c) else LOOSE_COLOR
		if roads.map.get_terrain(cell) == TerrainDef.Type.RIVER:
			color = BRIDGE_COLOR
		var dirs := WorldMap.NEIGHBORS_4.filter(func(d: Vector2i) -> bool: return roads.has_tile(cell + d))
		if dirs.is_empty():
			dirs = [Vector2i(1, 0), Vector2i(-1, 0)]  # tronçon isolé
		for dir: Vector2i in dirs:
			var d := Vector2(dir)
			var n := Vector2(-d.y, d.x) * HALF_WIDTH
			var back := d * HALF_WIDTH
			draw_colored_polygon(PackedVector2Array([_w(cell, n - back), _w(cell, n + d * 0.5),
				_w(cell, -n + d * 0.5), _w(cell, -n - back)]), color)


func _w(cell: Vector2i, offset: Vector2) -> Vector2:
	return Iso.map_to_world(Vector2(cell) + offset)
