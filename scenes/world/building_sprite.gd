class_name BuildingSprite
extends Node2D
## Dessin provisoire d'un bâtiment (volume isométrique, éolienne ou panneaux),
## positionné au centre de sa tuile d'ancrage pour le tri en Y avec les décors.

## Réduction du volume par rapport à l'emprise, pour aérer entre voisins.
const INSET := 0.8
const SCAFFOLD_COLOR := Color("e8c547")
const BAR_SIZE := Vector2(44, 6)
const BLADE_SPEED := 2.0  ## Radians par seconde.

var def: BuildingDef
var anchor: Vector2i
## Avancement du chantier, 0–1 (1 : terminé).
var progress := 1.0:
	set(value):
		progress = value
		set_process(def.style == BuildingDef.Style.TURBINE and progress >= 1.0)
		queue_redraw()

var _blade_angle := 0.0


func setup(p_def: BuildingDef, p_anchor: Vector2i, p_progress: float = 1.0) -> void:
	def = p_def
	anchor = p_anchor
	position = Iso.map_to_world(Vector2(anchor))
	_blade_angle = float(hash(anchor) % 628) / 100.0
	progress = p_progress


func _process(delta: float) -> void:
	_blade_angle = fmod(_blade_angle + BLADE_SPEED * delta, TAU)
	queue_redraw()


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
	var built := progress >= 1.0
	match def.style:
		BuildingDef.Style.TURBINE:
			_draw_turbine(center, def.height * progress)
		BuildingDef.Style.PANELS:
			_draw_panels(inner, def.height * maxf(progress, 0.3))
		_:
			_draw_box(inner, def.height * progress, def.color, def.roof_color)
			if def.has_chimney and progress > 0.6:
				var foot := center.lerp(inner[0], 0.45) + Vector2(0, -def.height * progress)
				var half := Vector2(5, 2.5) * def.size.x
				var c := PackedVector2Array([foot + Vector2(0, -half.y), foot + Vector2(half.x, 0),
					foot + Vector2(0, half.y), foot + Vector2(-half.x, 0)])
				var h := def.height * 0.7 * clampf((progress - 0.6) / 0.4, 0.0, 1.0)
				_draw_box(c, h, def.roof_color.lightened(0.15), def.roof_color.darkened(0.4))
	if not built:
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


func _draw_turbine(center: Vector2, h: float) -> void:
	var top := center + Vector2(0, -h)
	draw_line(center + Vector2(-3, 0), top + Vector2(-1, 0), def.roof_color, 3.0)
	draw_line(center + Vector2(3, 0), top + Vector2(1, 0), def.color, 3.0)
	if progress < 1.0:
		return
	draw_circle(top, 4.0, def.color)
	var blade := def.height * 0.38
	for k in 3:
		var a := _blade_angle + k * TAU / 3.0
		# Rotor vu de trois quarts : ellipse aplatie horizontalement.
		var tip := top + Vector2(cos(a) * blade * 0.55, sin(a) * blade)
		draw_line(top, tip, def.color, 3.0, true)


func _draw_panels(d: PackedVector2Array, h: float) -> void:
	_draw_box(d, h, def.roof_color.darkened(0.2), def.color)
	var up := Vector2(0, -h)
	var rows := 3 * def.size.y
	var cols := 3 * def.size.x
	for i in range(1, rows):
		var t := float(i) / rows
		draw_line(d[0].lerp(d[3], t) + up, d[1].lerp(d[2], t) + up, def.roof_color, 1.0)
	for j in range(1, cols):
		var t := float(j) / cols
		draw_line(d[0].lerp(d[1], t) + up, d[3].lerp(d[2], t) + up, def.roof_color, 1.0)
