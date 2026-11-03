extends Node2D
## Dessin des voies ferrées (ballast, traverses et deux rails reliant les
## tuiles voisines ; pont en bois sur les rivières), dans le repère de la vue,
## au-dessus des zones.

## Demi-écartement des rails et demi-longueur des traverses, en tuiles.
const GAUGE := 0.09
const SLEEPER_HALF := 0.16
const SLEEPERS_PER_HALF_TILE := 3
const BALLAST_HALF_WIDTH := 0.2
const BALLAST_COLOR := Color("8a8478")
const BRIDGE_COLOR := Color("6e5236")
const SLEEPER_COLOR := Color("5a4030")
const RAIL_COLOR := Color("c9ccd1")
## Rails ternis quand les convois sont arrêtés (plus de charbon).
const IDLE_RAIL_COLOR := Color("8a8d92")


func _ready() -> void:
	EventBus.rails_changed.connect(func(_cells: Array[Vector2i]) -> void: queue_redraw())
	EventBus.game_started.connect(func(_seed: int) -> void: queue_redraw())


func _draw() -> void:
	var rails := GameState.rails
	if rails == null or rails.tile_count() == 0:
		return
	var map := rails.map
	var cells: Array[Vector2i] = []
	for c in rails.cells():
		cells.append(GameState.display_cell(c))
	var rail_color := RAIL_COLOR if rails.running else IDLE_RAIL_COLOR
	# Trois passes : ballast, traverses, rails.
	for pass_index in 3:
		for cell in cells:
			var dirs := WorldMap.NEIGHBORS_4.filter(func(d: Vector2i) -> bool: return rails.has_rail(cell + d))
			if dirs.is_empty():
				dirs = [Vector2i(1, 0), Vector2i(-1, 0)]  # tronçon isolé
			for dir: Vector2i in dirs:
				var d := Vector2(dir)
				var n := Vector2(-d.y, d.x)
				match pass_index:
					0:
						var bridge := map.get_terrain(cell) == TerrainDef.Type.RIVER
						var w := n * BALLAST_HALF_WIDTH
						_quad(cell, [w - d * BALLAST_HALF_WIDTH, w + d * 0.5, -w + d * 0.5, -w - d * BALLAST_HALF_WIDTH],
							BRIDGE_COLOR if bridge else BALLAST_COLOR)
					1:
						for k in SLEEPERS_PER_HALF_TILE:
							var along := d * (k + 0.5) / SLEEPERS_PER_HALF_TILE * 0.5
							draw_line(_w(cell, along + n * SLEEPER_HALF), _w(cell, along - n * SLEEPER_HALF),
								SLEEPER_COLOR, 3.0)
					2:
						for side: float in [1.0, -1.0]:
							var e := n * GAUGE * side
							draw_line(_w(cell, e - d * GAUGE), _w(cell, e + d * 0.5), rail_color, 1.5)


func _w(cell: Vector2i, offset: Vector2) -> Vector2:
	return Iso.map_to_world(Vector2(cell) + offset)


func _quad(cell: Vector2i, offsets: Array, color: Color) -> void:
	var points := PackedVector2Array()
	for o: Vector2 in offsets:
		points.append(_w(cell, o))
	draw_colored_polygon(points, color)
