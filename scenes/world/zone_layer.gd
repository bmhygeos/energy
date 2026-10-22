class_name ZoneLayer
extends Node2D
## Calque des zones peintes : couleur de la zone en surimpression et liseré
## intérieur, sous les décors (arbres) et les bâtiments.

const FILL_ALPHA := 0.35
const BORDER_ALPHA := 0.9
## Réduction du liseré par rapport au losange de la tuile.
const INSET := 0.82


func _ready() -> void:
	EventBus.game_started.connect(func(_s: int) -> void: queue_redraw())
	EventBus.zones_changed.connect(func(_c: Array[Vector2i]) -> void: queue_redraw())


func _draw() -> void:
	var zones := GameState.zones
	if zones == null:
		return
	for c in zones.all_cells():
		var cell := GameState.display_cell(c)
		var def := zones.zone_at(cell)
		var d := Iso.diamond(cell)
		draw_colored_polygon(d, def.color * Color(1, 1, 1, FILL_ALPHA))
		var center := (d[0] + d[2]) / 2.0
		var inner := PackedVector2Array()
		for p in d:
			inner.append(center + (p - center) * INSET)
		inner.append(inner[0])
		draw_polyline(inner, def.color * Color(1, 1, 1, BORDER_ALPHA), 2.0, true)
