class_name Chart
extends Control
## Graphique journalier : courbes, ou aires empilées (avec courbes
## superposées), axe des valeurs gradué, légende ; le survol affiche le jour
## et les valeurs.

## Une série tracée.
class Series:
	var label := ""
	var values: PackedFloat32Array
	var color := Color.WHITE
	## Dans l'empilement (aire), sinon courbe par-dessus.
	var stacked := false

	func _init(p_label: String, p_values: PackedFloat32Array, p_color: Color, p_stacked := false) -> void:
		label = p_label
		values = p_values
		color = p_color
		stacked = p_stacked


const PAD_LEFT := 64.0
const PAD_RIGHT := 12.0
const PAD_TOP := 30.0
const PAD_BOTTOM := 22.0
const GRID_LINES := 4
const FONT_SIZE := 13
const AXIS_COLOR := Color(0.75, 0.78, 0.85, 0.35)
const TEXT_COLOR := Color(0.85, 0.87, 0.9)
const HOVER_BG := Color(0.08, 0.09, 0.11, 0.92)

var title := ""
var unit := ""
## Plafond fixe de l'axe (0 : automatique), pour les pourcentages.
var fixed_max := 0.0
## Premier jour affiché (index dans les séries).
var first_day := 0
var _series: Array[Series] = []
var _hover := -1


func _init() -> void:
	custom_minimum_size = Vector2(300, 160)
	mouse_filter = Control.MOUSE_FILTER_PASS


func set_series(series: Array[Series], p_first_day: int = 0) -> void:
	_series = series
	first_day = p_first_day
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var index := _index_at(event.position.x)
		if index != _hover:
			_hover = index
			queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and _hover != -1:
		_hover = -1
		queue_redraw()


func _count() -> int:
	var n := 0
	for s in _series:
		n = maxi(n, s.values.size())
	return maxi(0, n - first_day)


func _plot_rect() -> Rect2:
	return Rect2(PAD_LEFT, PAD_TOP, size.x - PAD_LEFT - PAD_RIGHT, size.y - PAD_TOP - PAD_BOTTOM)


func _index_at(x: float) -> int:
	var n := _count()
	var r := _plot_rect()
	if n == 0 or x < r.position.x or x > r.end.x:
		return -1
	return clampi(roundi((x - r.position.x) / r.size.x * maxf(1.0, n - 1)), 0, n - 1)


func _value(s: Series, i: int) -> float:
	var k := first_day + i
	return s.values[k] if k < s.values.size() else 0.0


func _x(i: int, n: int, r: Rect2) -> float:
	return r.position.x + (r.size.x * i / float(n - 1) if n > 1 else r.size.x / 2.0)


func _draw() -> void:
	var font := get_theme_default_font()
	var r := _plot_rect()
	draw_string(font, Vector2(4, 18), title, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE + 2, TEXT_COLOR)
	_draw_legend(font)
	var n := _count()
	if n == 0:
		draw_string(font, r.get_center() - Vector2(90, 0), "Pas encore de données (1 point par jour)",
			HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, AXIS_COLOR)
		return
	# Échelle.
	var low := 0.0
	var high := 0.0
	for i in n:
		var stack := 0.0
		for s in _series:
			var v := _value(s, i)
			if s.stacked:
				stack += v
			else:
				high = maxf(high, v)
				low = minf(low, v)
		high = maxf(high, stack)
	if fixed_max > 0.0:
		high = fixed_max
	var top := _nice(high)
	var bottom := -_nice(-low) if low < 0.0 else 0.0
	if top <= bottom:
		top = bottom + 1.0
	var y_of := func(v: float) -> float:
		return clampf(r.end.y - (v - bottom) / (top - bottom) * r.size.y, r.position.y, r.end.y)
	for g in GRID_LINES + 1:
		var v := lerpf(bottom, top, g / float(GRID_LINES))
		var y: float = y_of.call(v)
		draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), AXIS_COLOR)
		draw_string(font, Vector2(2, y + 4), _short(v), HORIZONTAL_ALIGNMENT_RIGHT, PAD_LEFT - 8, FONT_SIZE - 1, TEXT_COLOR)
	if bottom < 0.0:
		var y0: float = y_of.call(0.0)
		draw_line(Vector2(r.position.x, y0), Vector2(r.end.x, y0), TEXT_COLOR, 1.5)
	# Jours.
	draw_string(font, Vector2(r.position.x, size.y - 5), _day_label(first_day), HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE - 1, TEXT_COLOR)
	draw_string(font, Vector2(r.end.x - 160, size.y - 5), _day_label(first_day + n - 1), HORIZONTAL_ALIGNMENT_RIGHT, 160, FONT_SIZE - 1, TEXT_COLOR)
	# Aires empilées.
	var base := PackedFloat32Array()
	base.resize(n)
	for s in _series:
		if not s.stacked:
			continue
		var upper := PackedVector2Array()
		var lower := PackedVector2Array()
		for i in n:
			var x := _x(i, n, r)
			lower.append(Vector2(x, y_of.call(base[i])))
			base[i] += _value(s, i)
			upper.append(Vector2(x, y_of.call(base[i])))
		if n == 1:
			draw_line(lower[0], upper[0], s.color, 6.0)
			continue
		var fill := s.color
		fill.a = 0.75
		var colors := PackedColorArray([fill, fill, fill, fill])
		for i in n - 1:
			if upper[i].y < lower[i].y or upper[i + 1].y < lower[i + 1].y:
				draw_primitive(PackedVector2Array([upper[i], upper[i + 1], lower[i + 1], lower[i]]), colors, PackedVector2Array())
		draw_polyline(upper, s.color.lightened(0.2), 1.5)
	# Courbes.
	for s in _series:
		if s.stacked:
			continue
		var points := PackedVector2Array()
		for i in n:
			points.append(Vector2(_x(i, n, r), y_of.call(_value(s, i))))
		if n == 1:
			draw_circle(points[0], 3.0, s.color)
		else:
			draw_polyline(points, s.color, 2.0, true)
	if _hover >= 0 and _hover < n:
		_draw_hover(font, r, n)


func _draw_legend(font: Font) -> void:
	var x := 4.0 + font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE + 2).x + 28.0
	for s in _series:
		var w := font.get_string_size(s.label, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
		if x + w + 24 > size.x:
			break
		draw_rect(Rect2(x, 8, 10, 10), s.color)
		draw_string(font, Vector2(x + 14, 18), s.label, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, TEXT_COLOR)
		x += w + 28


func _draw_hover(font: Font, r: Rect2, n: int) -> void:
	var x := _x(_hover, n, r)
	draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), TEXT_COLOR, 1.0)
	var lines := PackedStringArray([_day_label(first_day + _hover)])
	var colors: Array[Color] = [TEXT_COLOR]
	var total := 0.0
	var stacked := 0
	for s in _series:
		var v := _value(s, _hover)
		if s.stacked:
			total += v
			stacked += 1
			if v == 0.0:
				continue
		lines.append("%s : %s %s" % [s.label, Format.decimal(v), unit])
		colors.append(s.color.lightened(0.25))
	if stacked > 1:
		lines.append("Total : %s %s" % [Format.decimal(total), unit])
		colors.append(TEXT_COLOR)
	var width := 0.0
	for line in lines:
		width = maxf(width, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x)
	var box := Rect2(x + 10, r.position.y + 4, width + 16, lines.size() * 17 + 8)
	if box.end.x > size.x:
		box.position.x = x - 10 - box.size.x
	draw_rect(box, HOVER_BG)
	for i in lines.size():
		draw_string(font, box.position + Vector2(8, 18 + i * 17), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, colors[i])


static func _day_label(day: int) -> String:
	var tick := (day + 1) * GameDate.HOURS_PER_DAY - 1
	return "%s %d, an %d" % [GameDate.SEASON_NAMES[GameDate.season(tick)], GameDate.day_of_season(tick), GameDate.year(tick)]


## Arrondi supérieur « rond » (1, 2, 2,5, 5 × 10ⁿ).
static func _nice(v: float) -> float:
	if v <= 0.0:
		return 0.0
	var p := pow(10.0, floorf(log(v) / log(10.0)))
	for m in [1.0, 2.0, 2.5, 5.0, 10.0]:
		if v <= m * p:
			return m * p
	return 10.0 * p


static func _short(v: float) -> String:
	var a := absf(v)
	if a >= 1_000_000.0:
		return Format.decimal(v / 1_000_000.0) + " M"
	if a >= 10_000.0:
		return Format.decimal(v / 1000.0, 0) + " k"
	return Format.decimal(v, 0 if a >= 100.0 or is_equal_approx(v, roundf(v)) else 1)
