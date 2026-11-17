class_name CityBlockLayer
extends Node2D
## Blocs des villes sur la carte mondiale : pavés, toits, nom de la ville et
## palier. Un clic dessus (outil de sélection) choisit la ville et ouvre sa
## carte.

const PAVEMENT := Color(0.62, 0.58, 0.52, 0.95)
const EDGE := Color(0.35, 0.3, 0.26, 1.0)
const WALL := Color(0.86, 0.8, 0.7, 1.0)
const ROOF := Color(0.66, 0.28, 0.22, 1.0)
const LABEL_COLOR := Color(1.0, 0.97, 0.9, 1.0)
const HOUSE_HEIGHT := 10.0


func _ready() -> void:
	for sig: Signal in [EventBus.city_changed, EventBus.tier_changed, EventBus.view_changed, EventBus.cities_changed,
			EventBus.city_selected]:
		sig.connect(queue_redraw)
	EventBus.game_started.connect(func(_s: int) -> void: queue_redraw())


## Tuiles du bloc de la ville [param c] (repère de la vue).
static func cells(c: City) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if c == null or c.buildings == null:
		return result
	var center: Vector2i = GameState.display_cell(c.home)
	var r: int = c.buildings.block_radius
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			result.append(center + Vector2i(dx, dy))
	return result


func _draw() -> void:
	if GameState.view_city:
		return
	for c in GameState.cities:
		_draw_city(c)


func _draw_city(c: City) -> void:
	var block := cells(c)
	for cell in block:
		draw_colored_polygon(Iso.diamond(cell), PAVEMENT)
	for cell in block:
		# Une maison par tuile : murs et toit en losange surélevé.
		var base := Iso.map_to_world(Vector2(cell))
		var foot := PackedVector2Array()
		for p in Iso.diamond(cell):
			foot.append(base + (p - base) * 0.45)
		var top := PackedVector2Array()
		for p in foot:
			top.append(p + Vector2(0, -HOUSE_HEIGHT))
		# Murs en deux triangles chacun (la triangulation des quadrilatères
		# échoue parfois).
		_quad(foot[1], foot[2], top[2], top[1], WALL.darkened(0.15))
		_quad(foot[2], foot[3], top[3], top[2], WALL)
		draw_colored_polygon(top, ROOF)
	if block.is_empty():
		return
	var center := Iso.map_to_world(Vector2(GameState.display_cell(c.home)))
	var font := ThemeDB.fallback_font
	var text := "%s — %s%s" % [c.name, GameState.tier_name(c), " (Tab)" if c == GameState.selected else ""]
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	draw_string_outline(font, center + Vector2(-width / 2.0, -HOUSE_HEIGHT - 14.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 4, EDGE)
	draw_string(font, center + Vector2(-width / 2.0, -HOUSE_HEIGHT - 14.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, LABEL_COLOR)


func _quad(a: Vector2, b: Vector2, c: Vector2, d: Vector2, color: Color) -> void:
	draw_primitive(PackedVector2Array([a, b, c]), PackedColorArray([color, color, color]), PackedVector2Array())
	draw_primitive(PackedVector2Array([a, c, d]), PackedColorArray([color, color, color]), PackedVector2Array())
