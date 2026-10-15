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
	Building.Status.NO_GRID: Color("e0b400"),
	Building.Status.NO_POWER: Color("e0b400"),
	Building.Status.REPAIR: Color("e5484d"),
	Building.Status.STRIKE: Color("f0a020"),
}
const DISCONNECTED_COLOR := Color("3b82f6")
const SMOKE_COLOR := Color(0.85, 0.85, 0.85, 0.45)
## Pièce de transition (jaune) des éoliennes en mer.
const FOUNDATION_COLOR := Color("e8b828")

var def: BuildingDef
var anchor: Vector2i
## Ville représentée (style CITY), pour la taille, l'éclairage et le nom.
var city: City
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
			and (def.style in [BuildingDef.Style.TURBINE, BuildingDef.Style.REACTOR] or def.has_chimney))


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
		BuildingDef.Style.CITY:
			_draw_city()
			return
		BuildingDef.Style.TURBINE:
			if def.on_sea:
				_draw_ellipse(center + Vector2(0, 1), Vector2(9, 4.5), FOUNDATION_COLOR.darkened(0.4))
				_draw_box(PackedVector2Array([center + Vector2(0, -3), center + Vector2(6, 0),
					center + Vector2(0, 3), center + Vector2(-6, 0)]), 8.0, FOUNDATION_COLOR, FOUNDATION_COLOR.lightened(0.2))
			_draw_turbine(center, def.height * progress)
		BuildingDef.Style.PANELS:
			_draw_panels(inner, def.height * maxf(progress, 0.3))
		BuildingDef.Style.REACTOR:
			_draw_reactor(inner, center)
		BuildingDef.Style.SOLAR_TOWER:
			_draw_solar_tower(inner, center)
		BuildingDef.Style.BASIN:
			_draw_basin(inner, center)
		BuildingDef.Style.PORT:
			_draw_port(inner, center)
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


## Solaire thermique : champ d'héliostats autour d'une tour, récepteur
## éclatant quand la centrale produit.
func _draw_solar_tower(d: PackedVector2Array, center: Vector2) -> void:
	var n := 4 * def.size.x
	var mirror := (d[1] - d[0]) / n * 0.35
	var across := (d[3] - d[0]) / n * 0.35
	for i in n:
		for j in n:
			var u := (i + 0.5) / n
			var v := (j + 0.5) / n
			if absf(u - 0.5) < 0.2 and absf(v - 0.5) < 0.2:
				continue
			if (i * n + j) / float(n * n) > progress:
				continue
			var p := d[0].lerp(d[1], u) + (d[3] - d[0]) * v + Vector2(0, -2)
			draw_colored_polygon(PackedVector2Array([p - mirror, p - across, p + mirror, p + across]),
				def.roof_color.lightened(0.15 if (i + j) % 2 == 0 else 0.0))
	var h := def.height * progress
	var base := PackedVector2Array([center + Vector2(0, -4), center + Vector2(7, 0),
		center + Vector2(0, 4), center + Vector2(-7, 0)])
	_draw_box(base, h, def.color, def.color.lightened(0.2))
	if progress >= 1.0:
		var top := center + Vector2(0, -h)
		var hot := status == Building.Status.RUNNING
		draw_circle(top + Vector2(0, -3), 6.0, Color("ffd76a") if hot else def.color.darkened(0.2))
		if hot:
			draw_circle(top + Vector2(0, -3), 11.0, Color(1.0, 0.85, 0.4, 0.3))


## Port : quai, grue portuaire côté eau et hangar côté terre.
func _draw_port(d: PackedVector2Array, center: Vector2) -> void:
	_draw_box(d, 4.0, def.color.darkened(0.2), def.color)
	var quay := Vector2(0, -4)
	var toward_water := _water_direction() * 0.3
	var shed_center := center - toward_water + quay
	var shed := PackedVector2Array()
	for p in d:
		shed.append(shed_center + (p - center) * 0.45)
	_draw_box(shed, def.height * progress, def.roof_color.lightened(0.3), def.roof_color)
	if progress < 1.0:
		return
	var foot := center + toward_water + quay
	var top := foot + Vector2(0, -def.height * 2.2)
	var crane := Color("e8a33a")
	var jib := toward_water.normalized() * 22.0 + Vector2(0, -6)
	draw_line(foot + Vector2(-4, 0), top, crane, 2.0)
	draw_line(foot + Vector2(4, 0), top, crane, 2.0)
	draw_line(top - jib * 0.4, top + jib, crane, 2.5)
	draw_line(top + jib * 0.9, top + jib * 0.9 + Vector2(0, 18), Color(0.2, 0.2, 0.2), 1.0)


## Décalage (pixels) du centre de l'emprise vers le bord donnant sur l'eau
## navigable (vers le bas de l'écran à défaut, pour le fantôme).
func _water_direction() -> Vector2:
	var dir := Vector2.ZERO
	var waters: WaterNetwork = GameState.waters
	var cells := def.footprint(anchor)
	if waters:
		for c in cells:
			for o in WorldMap.NEIGHBORS_4:
				if c + o not in cells and waters.is_navigable(c + o):
					dir += Vector2(o)
	if dir == Vector2.ZERO:
		dir = Vector2(1, 1)
	return (Iso.map_to_world(dir.normalized() * def.size.x) - Iso.map_to_world(Vector2.ZERO))


## STEP : bassin en hauteur (digue et plan d'eau).
func _draw_basin(d: PackedVector2Array, center: Vector2) -> void:
	var h := def.height * progress
	_draw_box(d, h, def.color, def.color.lightened(0.1))
	var up := Vector2(0, -h)
	var water := PackedVector2Array()
	for p in d:
		water.append(center + up + (p - center) * 0.8)
	draw_colored_polygon(water, def.roof_color if progress >= 1.0 else def.color.darkened(0.2))


## Centrale nucléaire : bâtiment réacteur à gauche, tour de refroidissement
## (hyperboloïde) à droite, panache de vapeur en service.
func _draw_reactor(d: PackedVector2Array, center: Vector2) -> void:
	var back := PackedVector2Array()
	for p in d:
		back.append(d[3].lerp(p, 0.5))
	_draw_box(back, def.height * progress, def.color, def.roof_color)
	var dome := (back[0] + back[2]) / 2.0 + Vector2(0, -def.height * progress)
	if progress > 0.5:
		draw_circle(dome, 9.0 * def.size.x * clampf((progress - 0.5) * 2.0, 0.0, 1.0), def.roof_color.lightened(0.2))
	var foot := center.lerp(d[1], 0.45) + Vector2(0, 6)
	var radius := 15.0 * def.size.x
	var h := 2.4 * radius * progress
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	const STEPS := 8
	for k in STEPS + 1:
		var t := float(k) / STEPS
		var r := radius * (0.72 + 0.28 * absf(t - 0.7) / 0.7)  # col vers 70 % de la hauteur
		left.append(foot + Vector2(-r, -h * t))
		right.append(foot + Vector2(r, -h * t))
	var shell := left.duplicate()
	right.reverse()
	shell.append_array(right)
	draw_colored_polygon(shell, def.color.darkened(0.12))
	# Ombre sur la moitié gauche, puis ouverture au sommet.
	var shade := PackedVector2Array()
	for k in left.size():
		shade.append(left[k])
	for k in range(left.size() - 1, -1, -1):
		shade.append(left[k].lerp(foot + Vector2(0, -h * float(k) / STEPS), 0.55))
	draw_colored_polygon(shade, def.color.darkened(0.3))
	var top_r := right[0].x - foot.x
	_draw_ellipse(foot + Vector2(0, -h), Vector2(top_r, top_r * 0.35), def.roof_color.darkened(0.3))
	if progress >= 1.0 and status == Building.Status.RUNNING:
		for k in 4:
			var t := fmod(_blade_angle / TAU + k / 4.0, 1.0)
			var r := top_r * (0.7 + 0.8 * t)
			draw_circle(foot + Vector2(10.0 * t, -h - 8.0 - 50.0 * t), r, Color(1, 1, 1, 0.35 * (1.0 - t)))


func _draw_ellipse(c: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for k in 16:
		var a := TAU * k / 16.0
		points.append(c + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	draw_colored_polygon(points, color)


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
		Building.Status.NO_GRID, Building.Status.NO_POWER:
			draw_polyline(PackedVector2Array([pos + Vector2(2, -6), pos + Vector2(-3, 1),
				pos + Vector2(2, 0), pos + Vector2(-2, 6)]), Color.WHITE, 2.0)
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


const CITY_WALLS: Array[Color] = [Color("d9cfc0"), Color("c9b8a0"), Color("e3dccf"), Color("b9b2a8"), Color("a7b4c2")]
const LIT_WINDOW := Color("ffd970")
const DARK_WINDOW := Color(0.15, 0.17, 0.22)


## Ville : un immeuble par tuile, plus haut au centre et quand la ville
## grandit ; fenêtres éclairées la nuit si elle est alimentée ; nom au-dessus.
func _draw_city() -> void:
	var size := def.size
	var origin := def.footprint_origin(anchor)
	var cells: Array[Vector2i] = def.footprint(anchor)
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x + a.y < b.x + b.y)
	var demand := city.base_demand if city else 10.0
	var hour := GameDate.hour_of_day(GameClock.tick)
	var night := hour < 7 or hour >= 19
	var powered := city != null and city.supply == City.Supply.SERVED
	var center_cell := Vector2(origin) + Vector2(size - Vector2i.ONE) / 2.0
	var half := Iso.HALF * 0.62
	var top_y := 0.0
	for cell in cells:
		var seed_value := hash([anchor, cell])
		var c := Iso.map_to_world(Vector2(cell)) - position
		var centrality := 1.0 - (Vector2(cell) - center_cell).length() / 2.0
		var h := 10.0 + (6.0 + (seed_value % 10)) * clampf(demand / 6.0, 0.6, 4.0) * (0.6 + 0.6 * centrality)
		var d := PackedVector2Array([c + Vector2(0, -half.y), c + Vector2(half.x, 0),
			c + Vector2(0, half.y), c + Vector2(-half.x, 0)])
		var wall: Color = CITY_WALLS[seed_value % CITY_WALLS.size()]
		var roof := def.roof_color if h < 30.0 else wall.darkened(0.25)
		_draw_box(d, h, wall, roof)
		top_y = minf(top_y, d[0].y - h)
		# Fenêtres sur la façade droite.
		var window := LIT_WINDOW if night and powered else DARK_WINDOW
		if not night:
			window = Color(0.45, 0.6, 0.75, 0.8)
		var floors := maxi(1, int(h / 9.0))
		for f in floors:
			for k in 2:
				var t := 0.3 + 0.4 * k
				var p := d[2].lerp(d[1], t) + Vector2(0, -6.0 - f * 9.0)
				draw_line(p, p + Vector2(0, -3.5), window, 3.0)
	var font := ThemeDB.fallback_font
	var label := city.name if city else def.display_name
	var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18)
	var pos := Vector2(Iso.map_to_world(center_cell).x - position.x - text_size.x / 2.0, top_y - 10.0)
	draw_string_outline(font, pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 5, Color(0, 0, 0, 0.8))
	var color := Color.WHITE
	if city and city.supply == City.Supply.SHED:
		color = Color("ff7a6e")
	elif powered:
		color = Color("ffe08a")
	draw_string(font, pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, color)
