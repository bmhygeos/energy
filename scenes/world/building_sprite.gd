class_name BuildingSprite
extends Node2D
## Dessin provisoire d'un bâtiment (volume isométrique, éolienne ou panneaux),
## positionné au centre de sa tuile d'ancrage pour le tri en Y avec les décors.

## Réduction du volume par rapport à l'emprise, pour aérer entre voisins.
const INSET := 0.8
const SCAFFOLD_COLOR := Color("e8c547")
const BAR_SIZE := Vector2(44, 6)
const BLADE_SPEED := 2.0  ## Radians par seconde.
## Couleur de la pastille d'alerte par statut (absent : pas d'alerte).
const BADGE_COLORS := {
	Building.Status.NO_INPUT: Color("e5484d"),
	Building.Status.OUTPUT_FULL: Color("f0a020"),
	Building.Status.DEPLETED: Color("8b8d98"),
}
const DISCONNECTED_COLOR := Color("3b82f6")
const SMOKE_COLOR := Color(0.85, 0.85, 0.85, 0.45)

var def: BuildingDef
var anchor: Vector2i
## Avancement du chantier, 0–1 (1 : terminé).
var progress := 1.0:
	set(value):
		progress = value
		_update_process()
		queue_redraw()
## Building.Status ; RUNNING par défaut (fantôme).
var status := Building.Status.RUNNING:
	set(value):
		status = value
		_update_process()
		queue_redraw()

## Bâtiment logistique sans route : pastille bleue prioritaire.
var disconnected := false:
	set(value):
		if value != disconnected:
			disconnected = value
			queue_redraw()

var _blade_angle := 0.0


func setup(p_def: BuildingDef, p_anchor: Vector2i, p_progress: float = 1.0) -> void:
	def = p_def
	anchor = p_anchor
	position = Iso.map_to_world(Vector2(anchor))
	_blade_angle = float(hash(anchor) % 628) / 100.0
	progress = p_progress


## Animation (rotor, fumée) seulement pour un bâtiment en service.
func _update_process() -> void:
	if def:
		set_process(status == Building.Status.RUNNING and progress >= 1.0
			and (def.style == BuildingDef.Style.TURBINE or def.has_chimney))


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
				if built and status == Building.Status.RUNNING:
					_draw_smoke(foot + Vector2(0, -h))
	var badge_pos := Vector2(center.x, inner[0].y - def.height - 14.0)
	if built and disconnected:
		_draw_road_badge(badge_pos)
	elif built and BADGE_COLORS.has(status):
		_draw_badge(badge_pos)
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


## Panaches de fumée montant de [param top], animés par l'angle du rotor.
func _draw_smoke(top: Vector2) -> void:
	for k in 3:
		var t := fmod(_blade_angle / TAU + k / 3.0, 1.0)
		var r := 4.0 + 7.0 * t
		draw_circle(top + Vector2(6.0 * t, -6.0 - 30.0 * t), r, SMOKE_COLOR * Color(1, 1, 1, 1.0 - t))


## Pastille dessinée en formes simples : « ! » (manque), barre pleine
## (sortie pleine), « × » (épuisé).
func _draw_badge(pos: Vector2) -> void:
	draw_circle(pos, 10.0, Color(0, 0, 0, 0.5))
	draw_circle(pos, 8.5, BADGE_COLORS[status])
	match status:
		Building.Status.NO_INPUT:
			draw_line(pos + Vector2(0, -5), pos + Vector2(0, 1.5), Color.WHITE, 2.5)
			draw_circle(pos + Vector2(0, 4.5), 1.4, Color.WHITE)
		Building.Status.OUTPUT_FULL:
			draw_rect(Rect2(pos - Vector2(4.5, 4.5), Vector2(9, 9)), Color.WHITE, false, 1.5)
			draw_rect(Rect2(pos + Vector2(-4.5, -1), Vector2(9, 5.5)), Color.WHITE)
		_:
			draw_line(pos + Vector2(-4, -4), pos + Vector2(4, 4), Color.WHITE, 2.0)
			draw_line(pos + Vector2(4, -4), pos + Vector2(-4, 4), Color.WHITE, 2.0)


## Pastille « non relié à une route » : deux bords de route barrés.
func _draw_road_badge(pos: Vector2) -> void:
	draw_circle(pos, 10.0, Color(0, 0, 0, 0.5))
	draw_circle(pos, 8.5, DISCONNECTED_COLOR)
	draw_line(pos + Vector2(-3, -5), pos + Vector2(-4, 5), Color.WHITE, 1.5)
	draw_line(pos + Vector2(3, -5), pos + Vector2(4, 5), Color.WHITE, 1.5)
	draw_line(pos + Vector2(-6, 4), pos + Vector2(6, -4), Color.WHITE, 2.0)
