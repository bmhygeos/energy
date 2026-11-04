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
	for sig: Signal in [EventBus.tiles_changed, EventBus.zones_changed]:
		sig.connect(func(_cells: Array[Vector2i]) -> void: _refresh())
	EventBus.labor_changed.connect(_refresh)
	EventBus.day_changed.connect(func(_d: int) -> void: _refresh())
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
	# Les tuiles inconnues (visées par l'outil Expédition) restent secrètes.
	if cell.x < 0 or map == null or not GameState.territory.is_known(cell):
		_panel.hide()
		return
	_panel.show()
	_panel.modulate.a = 1.0 if cell == _selected else 0.8
	var def := TerrainDb.get_def(map.get_terrain(cell))
	var territory := GameState.territory
	_title.text = "%s  (%s)" % [def.display_name, territory.STATE_NAMES[territory.state_at(cell)].to_lower()]
	var lines := PackedStringArray()
	var zone := GameState.zones.zone_at(cell)
	if zone:
		var workers: int = GameState.labor.workers_at.get(map.wrap_cell(cell), 0)
		var season := GameDate.season(GameClock.tick)
		lines.append("Zone : %s, %d / %d travailleur%s" % [zone.display_name, workers, zone.workers_per_tile,
			"s" if zone.workers_per_tile > 1 else ""])
		lines.append("Production : %s %s /j (%s par travailleur)" % [
			Format.decimal(GameState.production.tile_rate(zone, cell, workers, season)),
			Stockpile.GOOD_NAMES[zone.output].to_lower(),
			Format.decimal(GameState.production.tile_rate(zone, cell, 1, season))])
		var via := GameState.rails.distance_via(cell)
		if via >= 0 and via < _walk_distance(cell):
			lines.append("Par le train : à %d tuiles du village (à pied : %d)" % [via, _walk_distance(cell)])
		var by_road := GameState.roads.distance_via(cell)
		if by_road >= 0 and by_road < _walk_distance(cell):
			lines.append("Par la route : à %d tuiles du village (à pied : %d)" % [by_road, _walk_distance(cell)])
		var by_sea := GameState.ports.distance_via(cell)
		if by_sea >= 0 and by_sea < _walk_distance(cell):
			lines.append("Par bateau : à %d tuiles du village (à pied : %d)" % [by_sea, _walk_distance(cell)])
		if GameState.draft.harnessed.has(map.wrap_cell(cell)):
			lines.append("Attelage : trajets plus courts (pénalité à partir de %d tuiles)" % GameState.draft.free_distance())
		var inventions := GameState.production.invention_factor(zone, cell)
		if not is_equal_approx(inventions, 1.0):
			lines.append("Inventions : +%d %%" % roundi((inventions - 1.0) * 100.0))
		if GameState.production.irrigation_factor(zone, cell) > 1.0:
			lines.append("Irriguée : +%d %%" % roundi((Production.IRRIGATION_BONUS - 1.0) * 100.0))
	if GameState.rails.has_rail(cell):
		lines.append("Voie ferrée%s" % ("" if GameState.rails.running else " (trains arrêtés : plus de charbon)"))
	if GameState.roads.has_tile(cell):
		lines.append("Route%s" % ("" if GameState.roads.lengths.has(map.wrap_cell(cell)) else " (pas reliée au village)"))
	var regrowth := GameState.production.regrowth_days_left(cell)
	if regrowth >= 0:
		lines.append("Coupe à blanc : redevient forêt dans %d j (sans bâtiment ni autre zone que la coupe)" % regrowth)
	lines.append_array([
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
		lines.append("Bois sur pied : %s (densité %d %%)" % [Format.thousands(roundi(map.get_wood(cell))),
			roundi(map.get_wood(cell) / WorldMap.WOOD_PER_FOREST * 100.0)])
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
	if not b.is_complete() and b.previous_def:
		lines.append("Amélioration : %s reste en service pendant les travaux" % b.previous_def.display_name)
	if not b.def.description.is_empty():
		lines.append(b.def.description)
	if b.is_complete() and b.def.station:
		var rails := GameState.rails
		var length: int = rails.served.get(GameState.world_map.wrap_cell(b.anchor), -1)
		if rails.is_village_station(b):
			lines.append("Gare du village : départ des lignes")
		elif length > 0:
			lines.append("Desservie : %d tuiles de voie jusqu'au village%s" % [length,
				"" if rails.running else " (trains arrêtés : plus de charbon)"])
		else:
			lines.append("Non desservie : reliez-la par la voie à une gare du village")
	if b.is_complete() and b.def.harbor:
		var ports := GameState.ports
		if ports.is_linked(b.anchor):
			lines.append("Relié par l'eau : %d tuiles jusqu'à la tête de ligne" % ports.linked[GameState.world_map.wrap_cell(b.anchor)])
		else:
			lines.append("Tête de ligne : les ports reliés par l'eau découverte passent par lui")
	if b.is_complete() and b.def.coal_per_day > 0.0:
		lines.append("En marche" if GameState.steam_running else "À l'arrêt : plus de charbon")
	if b.is_complete() and b.def.upgrade:
		lines.append("Améliorable en %s (palier %s)" % [b.def.upgrade.display_name, CityTier.NAMES[b.def.upgrade.tier - 1]])
	return lines


## Distance à pied de [param cell] au centre du village.
func _walk_distance(cell: Vector2i) -> int:
	return GameState.rails.cheb(cell, GameState.home)
