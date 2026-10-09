class_name OverlayLayer
extends Node2D
## Calque d'information coloré par tuile (relief, vent, soleil, eau, gisements).

enum Mode { NONE, RELIEF, WIND, SUN, WATER, DEPOSITS }

const MODE_NAMES: PackedStringArray = ["Aucun", "Relief", "Vent", "Soleil", "Eau", "Gisements"]
const DEPOSIT_COLORS: Array[Color] = [
	Color.TRANSPARENT, Color("1a1a1a"), Color("4be03c"), Color("c45cff"),
]
const WATER_ACCESS_COLOR := Color(0.25, 0.63, 1.0, 0.6)
const COASTAL_COLOR := Color(0.1, 0.35, 0.85, 0.7)
const NO_WATER_COLOR := Color(0.75, 0.25, 0.2, 0.35)

var mode: Mode = Mode.NONE
var map: WorldMap


func _ready() -> void:
	EventBus.overlay_changed.connect(func(m: int) -> void:
		mode = m as Mode
		visible = mode != Mode.NONE
		queue_redraw())
	EventBus.tiles_changed.connect(func(_cells: Array[Vector2i]) -> void: queue_redraw())
	visible = false


func set_map(p_map: WorldMap) -> void:
	map = p_map
	queue_redraw()


func _draw() -> void:
	if map == null or mode == Mode.NONE:
		return
	var gradient := gradient_for(mode)
	for i in map.cell_count():
		var color := _cell_color(i, gradient)
		if color.a > 0.0:
			draw_colored_polygon(Iso.diamond(map.cell_of(i)), color)


func _cell_color(i: int, gradient: Gradient) -> Color:
	var water := TerrainDb.is_water(map.terrain[i])
	match mode:
		Mode.RELIEF:
			return gradient.sample(map.elevation[i])
		Mode.WIND:
			return gradient.sample(map.wind[i])
		Mode.SUN:
			return Color.TRANSPARENT if water else gradient.sample(map.sun[i])
		Mode.WATER:
			if water:
				return Color.TRANSPARENT
			if map.coastal[i]:
				return COASTAL_COLOR
			return WATER_ACCESS_COLOR if map.water_access[i] else NO_WATER_COLOR
		Mode.DEPOSITS:
			var kind := map.deposit[i]
			if kind == WorldMap.Deposit.NONE:
				return Color(0, 0, 0, 0.25) if not water else Color.TRANSPARENT
			return DEPOSIT_COLORS[kind]
	return Color.TRANSPARENT


## Dégradé de la légende pour les modes continus (null sinon).
static func gradient_for(m: Mode) -> Gradient:
	var g := Gradient.new()
	match m:
		Mode.RELIEF:
			g.offsets = [0.0, 0.25, 0.3, 0.6, 0.85, 1.0]
			g.colors = [Color("10306acc"), Color("3f7fbfcc"), Color("4c8c3ccc"),
				Color("c9b458cc"), Color("8a5a3ccc"), Color("ffffffcc")]
		Mode.WIND:
			g.offsets = [0.0, 0.5, 1.0]
			g.colors = [Color("f0f4ff20"), Color("6fa0ffa0"), Color("1438c8e0")]
		Mode.SUN:
			g.offsets = [0.0, 0.5, 1.0]
			g.colors = [Color("30305099"), Color("e0a030b0"), Color("fff060e0")]
		_:
			return null
	return g
