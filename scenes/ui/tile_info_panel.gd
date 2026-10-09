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
	EventBus.production_stepped.connect(func(_r: Production.Report) -> void:
		if _panel.visible:
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
	if map.terrain[i] == TerrainDef.Type.FOREST:
		lines.append("Bois sur pied : %s t" % Format.thousands(roundi(map.wood[i])))
	var kind := map.deposit[i]
	if kind != WorldMap.Deposit.NONE:
		lines.append("Gisement : %s, %s t" % [
			WorldMap.DEPOSIT_NAMES[kind], Format.thousands(roundi(map.deposit_amount[i]))])
	var b := _shown_building()
	if b:
		_title.text = "%s  (%d, %d)" % [b.def.display_name, cell.x, cell.y]
		var head := _building_lines(b)
		head.append("Sur : " + def.display_name.to_lower())
		head.append("")
		head.append_array(lines)
		lines = head
	_body.text = "\n".join(lines)


func _building_lines(b: Building) -> PackedStringArray:
	var def := b.def
	var lines := PackedStringArray()
	if not b.is_complete():
		lines.append("Chantier : %d %%" % roundi(b.progress_ratio() * 100.0))
		lines.append("Entretien : %s €/jour" % Format.thousands(def.upkeep_per_day))
		return lines
	var state := Building.STATUS_NAMES[b.status]
	if b.status == Building.Status.RUNNING and def.input_good != Goods.Type.NONE and b.activity < 0.999:
		state += " (%d %%)" % roundi(b.activity * 100.0)
	lines.append(state)
	if def.power_mw > 0.0:
		lines.append("Électricité : %s MW" % Format.decimal(b.power_mw))
	if def.input_good != Goods.Type.NONE:
		lines.append("Entrée : %s / %s t de %s" % [Format.decimal(b.input_stock),
			Format.thousands(roundi(def.buffer_capacity)), Goods.display_name(def.input_good).to_lower()])
		var n := GameState.production.suppliers_of(b).size()
		lines.append("Fournisseurs à portée : %d" % n)
	if def.output_good != Goods.Type.NONE:
		lines.append("Sortie : %s / %s t de %s" % [Format.decimal(b.output_stock),
			Format.thousands(roundi(def.buffer_capacity)), Goods.display_name(def.output_good).to_lower()])
		lines.append("Clients à portée : %d" % GameState.production.customers_of(b).size())
	var available := Production.resource_available(GameState.world_map, def, b.anchor)
	if available >= 0.0:
		lines.append("Ressource à portée : %s t" % Format.thousands(roundi(available)))
	lines.append("Entretien : %s €/jour" % Format.thousands(def.upkeep_per_day))
	return lines
