class_name CityBlockLayer
extends Node2D
## Bloc de la ville sur la carte mondiale : pavés, toits et nom du palier.
## Un clic dessus (outil de sélection) ouvre la carte de la ville.

const PAVEMENT := Color(0.62, 0.58, 0.52, 0.95)
const EDGE := Color(0.35, 0.3, 0.26, 1.0)
const WALL := Color(0.86, 0.8, 0.7, 1.0)
const ROOF := Color(0.66, 0.28, 0.22, 1.0)
const LABEL_COLOR := Color(1.0, 0.97, 0.9, 1.0)
const HOUSE_HEIGHT := 10.0


func _ready() -> void:
	for sig: Signal in [EventBus.city_changed, EventBus.tier_changed, EventBus.view_changed]:
		sig.connect(queue_redraw)
	EventBus.game_started.connect(func(_s: int) -> void: queue_redraw())


## Tuiles du bloc (repère de la vue).
static func cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if GameState.buildings == null:
		return result
	var center: Vector2i = GameState.display_cell(GameState.home)
	var r: int = GameState.buildings.block_radius
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			result.append(center + Vector2i(dx, dy))
	return result


func _draw() -> void:
	if GameState.view_city:
		return
	var block := cells()
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
		draw_colored_polygon(PackedVector2Array([foot[1], foot[2], top[2], top[1]]), WALL.darkened(0.15))
		draw_colored_polygon(PackedVector2Array([foot[2], foot[3], top[3], top[2]]), WALL)
		draw_colored_polygon(top, ROOF)
	if block.is_empty():
		return
	var center := Iso.map_to_world(Vector2(GameState.display_cell(GameState.home)))
	var font := ThemeDB.fallback_font
	var text := "%s (Tab)" % GameState.tier.name()
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	draw_string_outline(font, center + Vector2(-width / 2.0, -HOUSE_HEIGHT - 14.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 4, EDGE)
	draw_string(font, center + Vector2(-width / 2.0, -HOUSE_HEIGHT - 14.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, LABEL_COLOR)
