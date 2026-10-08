extends CanvasLayer
## Panneau d'information de la tuile sélectionnée (à défaut, survolée).

var _hovered := Vector2i(-1, -1)
var _selected := Vector2i(-1, -1)

@onready var _panel: PanelContainer = $Panel
@onready var _title: Label = %Title
@onready var _body: Label = %Body


func _ready() -> void:
	EventBus.tile_hovered.connect(func(c: Vector2i) -> void:
		_hovered = c
		_refresh())
	EventBus.tile_selected.connect(func(c: Vector2i) -> void:
		_selected = c
		_refresh())
	_refresh()


func _refresh() -> void:
	var cell := _selected if _selected.x >= 0 else _hovered
	var map := GameState.world_map
	if cell.x < 0 or map == null or not map.has_cell(cell):
		_panel.hide()
		return
	_panel.show()
	_panel.modulate.a = 1.0 if cell == _selected else 0.8
	var i := map.index_of(cell)
	var def := TerrainDb.get_def(map.terrain[i])
	_title.text = "%s  (%d, %d)" % [def.display_name, cell.x, cell.y]
	var lines := PackedStringArray([
		"Altitude : %d m" % roundi(map.elevation[i] * 2000.0),
		"Vent : %d %%" % roundi(map.wind[i] * 100.0),
		"Ensoleillement : %d %%" % roundi(map.sun[i] * 100.0),
	])
	if not def.is_water:
		var water := "non"
		if map.coastal[i]:
			water = "oui (côte)"
		elif map.water_access[i]:
			water = "oui"
		lines.append("Accès à l'eau : " + water)
		lines.append("Constructible : " + ("oui" if def.buildable else "non"))
	var kind := map.deposit[i]
	if kind != WorldMap.Deposit.NONE:
		lines.append("Gisement : %s, %s t" % [
			WorldMap.DEPOSIT_NAMES[kind], Format.thousands(map.deposit_amount[i])])
	_body.text = "\n".join(lines)
