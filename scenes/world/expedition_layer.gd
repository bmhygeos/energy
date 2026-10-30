class_name ExpeditionLayer
extends Node2D
## Expéditions sur la carte (trajet, position, rayon de vue), aperçu du
## trajet de l'outil Expédition (au-dessus de la brume).

const PATH_COLOR := Color(1.0, 0.9, 0.55, 0.85)
const PREVIEW_COLOR := Color(1.0, 1.0, 1.0, 0.55)
const BLOCKED_COLOR := Color(1.0, 0.48, 0.43, 0.9)
const MARKER_COLOR := Color(0.95, 0.75, 0.25, 1.0)
const MARKER_OUTLINE := Color(0.15, 0.1, 0.05, 1.0)
const SIGHT_COLOR := Color(1.0, 0.9, 0.55, 0.35)

## Trajet prévu sous la souris (outil Expédition) et cible demandée.
var _preview: Array[Vector2i] = []
var _preview_target := Vector2i(-1, -1)


func _ready() -> void:
	EventBus.expeditions_changed.connect(queue_redraw)
	EventBus.game_started.connect(func(_s: int) -> void:
		clear_previews())


func show_path(path: Array[Vector2i], target: Vector2i) -> void:
	_preview = path
	_preview_target = target
	queue_redraw()


func clear_previews() -> void:
	_preview = []
	_preview_target = Vector2i(-1, -1)
	queue_redraw()


func _draw() -> void:
	if _preview.size() >= 2:
		_draw_path(_preview, PREVIEW_COLOR)
	if _preview_target.x >= 0 and (_preview.is_empty() or _preview[-1] != _preview_target):
		# Trajet arrêté avant la cible : de l'eau barre le chemin.
		var from := _preview[-1] if not _preview.is_empty() else _preview_target
		draw_dashed_line(Iso.map_to_world(from), Iso.map_to_world(_preview_target), BLOCKED_COLOR, 2.0, 10.0)
	var exploration := GameState.exploration
	if exploration == null:
		return
	for e in exploration.expeditions:
		_draw_path(e.path, PATH_COLOR)
		var k := clampi(floori(e.position), 0, e.path.size() - 1)
		var next := e.path[mini(k + 1, e.path.size() - 1)]
		var at := Iso.map_to_world(Vector2(e.path[k]).lerp(Vector2(next), e.position - k))
		var r := Exploration.SIGHT_RADIUS * Iso.HALF.x
		draw_set_transform(at, 0.0, Vector2(1.0, 0.5))
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, SIGHT_COLOR, 2.0, true)
		draw_set_transform(Vector2.ZERO)
		draw_circle(at, 9.0, MARKER_OUTLINE)
		draw_circle(at, 7.0, MARKER_COLOR)


func _draw_path(path: Array[Vector2i], color: Color) -> void:
	var points := PackedVector2Array()
	for cell in path:
		points.append(Iso.map_to_world(Vector2(cell)))
	draw_polyline(points, color, 2.0, true)
