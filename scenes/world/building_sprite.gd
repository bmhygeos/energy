class_name BuildingSprite
extends Node2D
## Dessin provisoire d'un bâtiment (volume isométrique), positionné au centre
## de sa tuile d'ancrage pour le tri en Y avec les décors.

## Réduction du volume par rapport à l'emprise, pour aérer entre voisins.
const INSET := 0.8
const SCAFFOLD_COLOR := Color("e8c547")
const BAR_SIZE := Vector2(44, 6)

var def: BuildingDef
var anchor: Vector2i
## Avancement du chantier, 0–1 (1 : terminé).
var progress := 1.0:
	set(value):
		progress = value
		queue_redraw()


func setup(p_def: BuildingDef, p_anchor: Vector2i, p_progress: float = 1.0) -> void:
	def = p_def
	anchor = p_anchor
	position = Iso.map_to_world(Vector2(anchor))
	progress = p_progress


func _draw() -> void:
	if def == null:
		return
	var base := Iso.footprint_diamond(def.footprint_origin(anchor), def.size)
	for i in base.size():
		base[i] -= position
	var center := (base[0] + base[2]) / 2.0
	var inner := PackedVector2Array()
	for p in base:
		inner.append(center + (p - center) * INSET)
	# Dalle de fondation.
	draw_colored_polygon(inner, def.roof_color.darkened(0.45) * Color(1, 1, 1, 0.55))
	_draw_box(inner, def.height * progress, def.color, def.roof_color)
	if progress < 1.0:
		_draw_scaffold(inner, def.height)
		var bar_pos := Vector2(center.x - BAR_SIZE.x / 2.0, inner[0].y - def.height - 16.0)
		draw_rect(Rect2(bar_pos, BAR_SIZE), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(bar_pos, Vector2(BAR_SIZE.x * progress, BAR_SIZE.y)), SCAFFOLD_COLOR)


## Prisme de hauteur [param h] sur le losange [param d] (nord, est, sud, ouest).
func _draw_box(d: PackedVector2Array, h: float, wall: Color, roof: Color) -> void:
	var up := Vector2(0, -h)
	if h > 0.5:
		draw_colored_polygon(PackedVector2Array([d[3], d[2], d[2] + up, d[3] + up]), wall.darkened(0.3))
		draw_colored_polygon(PackedVector2Array([d[2], d[1], d[1] + up, d[2] + up]), wall.darkened(0.1))
	draw_colored_polygon(PackedVector2Array([d[0] + up, d[1] + up, d[2] + up, d[3] + up]), roof)


func _draw_scaffold(d: PackedVector2Array, h: float) -> void:
	var up := Vector2(0, -h)
	var color := SCAFFOLD_COLOR * Color(1, 1, 1, 0.8)
	for i in 4:
		draw_line(d[i], d[i] + up, color, 1.5)
	var top := PackedVector2Array([d[0] + up, d[1] + up, d[2] + up, d[3] + up, d[0] + up])
	draw_polyline(top, color, 1.5)
