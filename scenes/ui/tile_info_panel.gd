extends CanvasLayer
## Panneau d'information de la tuile sélectionnée (à défaut, survolée). Taille
## fixe : le texte est renvoyé à la ligne.

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
		if _panel.visible and _shown_building():
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
	var def := TerrainDb.get_def(map.get_terrain(cell))
	var territory := GameState.territory
	_title.text = "%s  (%s)" % [def.display_name, territory.STATE_NAMES[territory.state_at(cell)].to_lower()]
	var lines := PackedStringArray([
		Format.coordinates(map.latitude(cell.y), map.longitude(cell.x)),
		"Altitude : %d m" % roundi((map.get_elevation(cell) - map.generator.sea_level) * 8000.0),
		"Température : %d %%" % roundi(map.get_temperature(cell) * 100.0),
	])
	if not def.is_water:
		lines.append("Fertilité : %d %%" % roundi(map.get_fertility(cell) * 100.0))
		lines.append("Pâturage : %d %%" % roundi(map.get_pasture(cell) * 100.0))
		var water := "non"
		if map.is_coastal(cell):
			water = "oui (côte)"
		elif map.has_water_access(cell):
			water = "oui"
		lines.append("Accès à l'eau : " + water)
		lines.append("Constructible : " + ("oui" if def.buildable and territory.is_territory(cell) else "non"))
	if map.get_terrain(cell) == TerrainDef.Type.FOREST:
		lines.append("Bois sur pied : %s t" % Format.thousands(roundi(map.get_wood(cell))))
	lines.append("Vent : %d %%  ·  soleil : %d %%" % [roundi(map.get_wind(cell) * 100.0), roundi(map.get_sun(cell) * 100.0)])
	if territory.is_prospected(cell):
		var kind := territory.known_deposit(cell)
		lines.append("Gisement : " + ("aucun" if kind == WorldMap.Deposit.NONE else "%s, %s t" % [
			WorldMap.DEPOSIT_NAMES[kind], Format.thousands(roundi(map.get_deposit_amount(cell)))]))
	else:
		lines.append("Gisements : non prospecté")
	var b := _shown_building()
	if b:
		_title.text = b.def.display_name
		var head := _building_lines(b)
		head.append("Sur : " + def.display_name.to_lower())
		head.append("")
		head.append_array(lines)
		lines = head
	_body.text = "\n".join(lines)


func _building_lines(b: Building) -> PackedStringArray:
	var lines := PackedStringArray()
	if not b.is_complete():
		lines.append("Chantier : %d %% (reste %s)" % [roundi(b.progress_ratio() * 100.0),
			Format.duration_hours(b.def.build_hours - b.build_progress)])
	else:
		lines.append(Building.STATUS_NAMES[b.status])
	if not b.def.description.is_empty():
		lines.append(b.def.description)
	return lines
