class_name CanalLayer
extends Node2D
## Dessin des canaux d'irrigation (eau entre les tuiles voisines), dans le
## repère de la vue. Un canal à sec (pas relié à l'eau) est terne.

const WATER_COLOR := Color(0.3, 0.6, 0.95, 0.9)
const DRY_COLOR := Color(0.55, 0.45, 0.32, 0.9)
const WIDTH := 6.0


func _ready() -> void:
	EventBus.cities_changed.connect(queue_redraw)
	EventBus.canals_changed.connect(func(_cells: Array[Vector2i]) -> void: queue_redraw())
	EventBus.game_started.connect(func(_seed: int) -> void: queue_redraw())


func _draw() -> void:
	for c in GameState.cities:
		_draw_city(c)


## Tracé de la ville [param town] (toutes les villes sont dessinées).
func _draw_city(town: City) -> void:
	var canals := town.canals
	if canals == null or canals.tile_count() == 0:
		return
	for c in canals.cells():
		var cell := GameState.display_cell(c)
		var center := Iso.map_to_world(Vector2(cell))
		var color := WATER_COLOR if canals.linked.has(c) else DRY_COLOR
		var alone := true
		for dir: Vector2i in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]:
			if canals.has_tile(cell + dir):
				alone = false
				draw_line(center, Iso.map_to_world(Vector2(cell + dir)), color, WIDTH)
		draw_circle(center, WIDTH / 2.0 + (2.0 if alone else 0.0), color)
