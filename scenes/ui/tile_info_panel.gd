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
	for sig: Signal in [EventBus.building_placed, EventBus.building_completed,
			EventBus.building_removed]:
		sig.connect(func(_b: Building) -> void: _refresh())
	EventBus.tiles_changed.connect(func(_cells: Array[Vector2i]) -> void: _refresh())
	EventBus.tick_advanced.connect(func(_t: int) -> void:
		var b := _shown_building()
		if b and not b.is_complete():
			_refresh())
	_refresh()


func _shown_cell() -> Vector2i:
	return _selected if _selected.x >= 0 else _hovered


func _shown_building() -> Building:
	var cell := _shown_cell()
	return GameState.buildings.building_at(cell) if cell.x >= 0 and GameState.buildings else null


func _refresh() -> void:
	var cell := _shown_cell()
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
	var b := _shown_building()
	if b:
		_title.text = "%s  (%d, %d)" % [b.def.display_name, cell.x, cell.y]
		var state := "en service" if b.is_complete() else "chantier %d %%" % roundi(b.progress_ratio() * 100.0)
		lines.insert(0, "Sur : %s · %s" % [def.display_name.to_lower(), state])
		lines.insert(1, "Entretien : %s €/jour" % Format.thousands(b.def.upkeep_per_day))
		lines.insert(2, "")
	_body.text = "\n".join(lines)
