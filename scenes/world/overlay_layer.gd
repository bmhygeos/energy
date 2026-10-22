class_name OverlayLayer
extends Node2D
## Calque d'information coloré par tuile connue (relief, fertilité, pâturage,
## eau, gisements prospectés, vent, soleil).

enum Mode { NONE, RELIEF, FERTILITY, PASTURE, WATER, DEPOSITS, WIND, SUN }

const MODE_NAMES: PackedStringArray = [
	"Aucun", "Relief", "Fertilité", "Pâturage", "Eau", "Gisements", "Vent", "Soleil",
]
## Par WorldMap.Deposit.
const DEPOSIT_COLORS: Array[Color] = [
	Color.TRANSPARENT, Color("1a1a1a"), Color("b0503a"), Color("2b2b55"),
	Color("d9822b"), Color("4be03c"), Color("c45cff"),
]
## Altitude du niveau de la mer dans le dégradé du relief.
const RELIEF_SEA := 0.3
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
	for c in GameState.territory.known_cells():
		var cell := GameState.display_cell(c)
		var color := _cell_color(cell, gradient)
		if color.a > 0.0:
			draw_colored_polygon(Iso.diamond(cell), color)


func _cell_color(cell: Vector2i, gradient: Gradient) -> Color:
	var water := map.is_water(cell)
	match mode:
		Mode.RELIEF:
			return gradient.sample(_relief(map.get_elevation(cell)))
		Mode.FERTILITY:
			return Color.TRANSPARENT if water else gradient.sample(map.get_fertility(cell))
		Mode.PASTURE:
			return Color.TRANSPARENT if water else gradient.sample(map.get_pasture(cell))
		Mode.WIND:
			return gradient.sample(map.get_wind(cell))
		Mode.SUN:
			return Color.TRANSPARENT if water else gradient.sample(map.get_sun(cell))
		Mode.WATER:
			if water:
				return Color.TRANSPARENT
			if map.is_coastal(cell):
				return COASTAL_COLOR
			return WATER_ACCESS_COLOR if map.has_water_access(cell) else NO_WATER_COLOR
		Mode.DEPOSITS:
			if water or not GameState.territory.is_prospected(cell):
				return Color.TRANSPARENT
			var kind := GameState.territory.known_deposit(cell)
			return Color(0, 0, 0, 0.25) if kind == WorldMap.Deposit.NONE else DEPOSIT_COLORS[kind]
	return Color.TRANSPARENT


## Altitude ramenée au dégradé du relief : niveau de la mer en RELIEF_SEA.
func _relief(elevation: float) -> float:
	var sea := map.generator.sea_level
	if elevation < sea:
		return RELIEF_SEA * elevation / sea
	return RELIEF_SEA + (1.0 - RELIEF_SEA) * (elevation - sea) / (1.0 - sea)


## Dégradé de la légende pour les modes continus (null sinon).
static func gradient_for(m: Mode) -> Gradient:
	var g := Gradient.new()
	match m:
		Mode.RELIEF:
			g.offsets = [0.0, 0.25, 0.3, 0.6, 0.85, 1.0]
			g.colors = [Color("10306acc"), Color("3f7fbfcc"), Color("4c8c3ccc"),
				Color("c9b458cc"), Color("8a5a3ccc"), Color("ffffffcc")]
		Mode.FERTILITY:
			g.offsets = [0.0, 0.5, 1.0]
			g.colors = [Color("8a5a3cb0"), Color("d8c058b0"), Color("2f9e3ae0")]
		Mode.PASTURE:
			g.offsets = [0.0, 0.5, 1.0]
			g.colors = [Color("f0f0e020"), Color("c8d870b0"), Color("6aa82ae0")]
		Mode.WIND:
			g.offsets = [0.0, 0.5, 1.0]
			g.colors = [Color("f0f4ff20"), Color("6fa0ffa0"), Color("1438c8e0")]
		Mode.SUN:
			g.offsets = [0.0, 0.5, 1.0]
			g.colors = [Color("30305099"), Color("e0a030b0"), Color("fff060e0")]
		_:
			return null
	return g
