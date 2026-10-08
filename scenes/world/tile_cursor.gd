extends Node2D
## Contours de la tuile survolée et de la tuile sélectionnée.

const HOVER_COLOR := Color(1, 1, 1, 0.8)
const SELECT_COLOR := Color("ffd23f")

var hovered := Vector2i(-1, -1)
var selected := Vector2i(-1, -1)


func _ready() -> void:
	EventBus.tile_hovered.connect(func(c: Vector2i) -> void:
		hovered = c
		queue_redraw())
	EventBus.tile_selected.connect(func(c: Vector2i) -> void:
		selected = c
		queue_redraw())


func _draw() -> void:
	if hovered.x >= 0 and hovered != selected:
		_outline(hovered, HOVER_COLOR, 2.0)
	if selected.x >= 0:
		_outline(selected, SELECT_COLOR, 4.0)


func _outline(cell: Vector2i, color: Color, width: float) -> void:
	var points := Iso.diamond(cell)
	points.append(points[0])
	draw_polyline(points, color, width, true)
