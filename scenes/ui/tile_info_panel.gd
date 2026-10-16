extends CanvasLayer
## Panneau d'information de la tuile sélectionnée (à défaut, survolée). Taille
## fixe : le texte est renvoyé à la ligne et les boutons restent en bas.

var _hovered := Vector2i(-1, -1)
var _selected := Vector2i(-1, -1)

@onready var _panel: PanelContainer = $Panel
@onready var _title: Label = %Title
@onready var _body: Label = %Body
@onready var _actions: VBoxContainer = %Actions

## Dépôt dont les boutons d'achat sont affichés.
var _actions_for: Building
## Lignes d'achat/revente par type de véhicule : [libellé, acheter, vendre].
var _vehicle_rows: Dictionary[VehicleDef, Array] = {}


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
	for sig: Signal in [EventBus.roads_changed, EventBus.rails_changed, EventBus.lines_changed]:
		sig.connect(func(_cells: Array[Vector2i]) -> void: _refresh())
	EventBus.grid_changed.connect(_refresh)
	EventBus.money_changed.connect(func(_m: int) -> void:
		if _actions_for:
			_refresh())
	for sig: Signal in [EventBus.vehicle_added, EventBus.vehicle_removed]:
		sig.connect(func(_v: Vehicle) -> void: _refresh())
	EventBus.vehicles_changed.connect(_refresh)
	EventBus.grid_stepped.connect(func(_r: PowerGrid.Report) -> void:
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
	if GameState.pollution and GameState.pollution.level[i] >= 1.0:
		lines.append("Pollution : %d" % roundi(GameState.pollution.level[i]))
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
	if kind != WorldMap.Deposit.NONE and GameState.deposits_revealed():
		lines.append("Gisement : %s, %s t" % [
			WorldMap.DEPOSIT_NAMES[kind], Format.thousands(roundi(map.deposit_amount[i]))])
	if GameState.roads.has_road(cell):
		var bridge := map.terrain[i] == TerrainDef.Type.RIVER
		_title.text = "%s  (%d, %d)" % ["Pont" if bridge else "Route", cell.x, cell.y]
		var head := PackedStringArray([
			"Sur : " + def.display_name.to_lower(),
			"Entretien : %d €/jour" % RoadNetwork.UPKEEP_PER_TILE_PER_DAY, ""])
		head.append_array(lines)
		lines = head
	if GameState.rails.has_rail(cell):
		var crossing := GameState.roads.has_road(cell)
		_title.text = "%s  (%d, %d)" % ["Passage à niveau" if crossing else "Voie ferrée", cell.x, cell.y]
		var head := PackedStringArray([
			"Entretien : %d €/jour" % RailNetwork.RAIL_UPKEEP_PER_TILE_PER_DAY, ""])
		head.append_array(lines)
		lines = head
	if GameState.grid.has_line(cell):
		var head := _line_lines(cell)
		head.append("")
		head.append_array(lines)
		lines = head
		_title.text = "Ligne haute tension  (%d, %d)" % [cell.x, cell.y]
	var b := _shown_building()
	_update_actions(b if b and cell == _selected else null)
	if b:
		_title.text = "%s  (%d, %d)" % [b.city.name if b.city else b.def.display_name, cell.x, cell.y]
		var head := _city_lines(b.city) if b.city else _building_lines(b)
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
	var diagnosis := GameState.logistics.diagnose(b)
	if not diagnosis.is_empty():
		lines.append("Transport : " + diagnosis)
	var state := Building.STATUS_NAMES[b.status]
	if b.status == Building.Status.RUNNING and def.input_good != Goods.Type.NONE and b.activity < 0.999:
		state += " (%d %%)" % roundi(b.activity * 100.0)
	if b.is_out(GameClock.tick):
		state += " — reprise dans %s" % Format.duration_hours(b.outage_until - GameClock.tick)
	elif b.status == Building.Status.RUNNING and def.needs_water_access and GameState.events.cooling_factor() < 1.0:
		state += " — sécheresse : %d %% max" % roundi(GameState.events.cooling_factor() * 100.0)
	lines.append(state)
	if def.power_mw > 0.0:
		lines.append("Électricité : %s / %s MW" % [Format.decimal(b.power_mw), Format.decimal(def.power_mw)])
		if b.grid_id == 0:
			lines.append("Réseau électrique : non raccordé !")
		elif def.is_dispatchable():
			lines.append("Réseau électrique : consigne %d %%" % roundi(b.power_setpoint * 100.0))
		else:
			lines.append("Réseau électrique : raccordé")
		var tick := GameClock.tick
		match def.power_source:
			BuildingDef.PowerSource.WIND:
				lines.append("Vent : %d %% (site %d %% × météo %d %%)" % [
					roundi(Production.renewable_factor(GameState.world_map, GameState.weather, b, tick) * 100.0),
					roundi(Production.site_average(GameState.world_map, b, GameState.world_map.wind) * 100.0),
					roundi(GameState.weather.wind_at(tick) * 100.0)])
			BuildingDef.PowerSource.SUN:
				lines.append("Soleil : %d %% (site %d %% × ciel %d %%)" % [
					roundi(Production.renewable_factor(GameState.world_map, GameState.weather, b, tick) * 100.0),
					roundi(Production.site_average(GameState.world_map, b, GameState.world_map.sun) * 100.0),
					roundi(GameState.weather.sun_at(tick) * 100.0)])
			BuildingDef.PowerSource.SOLAR_THERMAL:
				lines.append("Chaleur stockée : %s / %s MWh" % [Format.decimal(b.stored_mwh),
					Format.thousands(roundi(def.storage_mwh))])
	if def.is_grid_storage():
		lines.append("Stockage : %s / %s MWh" % [Format.decimal(b.stored_mwh), Format.thousands(roundi(def.storage_mwh))])
		if b.grid_id == 0:
			lines.append("Réseau électrique : non raccordé !")
		elif b.storage_flow_mw > 0.001:
			lines.append("En charge : %s MW" % Format.decimal(b.storage_flow_mw))
		elif b.storage_flow_mw < -0.001:
			lines.append("En décharge : %s MW" % Format.decimal(-b.storage_flow_mw))
		else:
			lines.append("En attente (ni surplus ni manque)")
	if def.input_good != Goods.Type.NONE:
		lines.append("Entrée : %s / %s t de %s" % [Format.decimal(b.input_stock),
			Format.thousands(roundi(def.buffer_capacity)), Goods.display_name(def.input_good).to_lower()])
	if def.input2_good != Goods.Type.NONE:
		lines.append("Entrée : %s / %s t de %s" % [Format.decimal(b.input2_stock),
			Format.thousands(roundi(def.buffer_capacity)), Goods.display_name(def.input2_good).to_lower()])
	if def.ramp_up_hours > 0 and b.is_complete():
		lines.append("Montée en puissance : %d %%" % roundi(Production.ramp_limit(b) * 100.0))
	if b.def.id == &"tokamak" and b.is_complete():
		lines.append("Fonctionnement cumulé : %s" % Format.duration_hours(GameState.research.operation_hours.get(&"tokamak", 0)))
		if b.reserved_in > 0.0:
			lines.append("En route : %s t" % Format.decimal(b.reserved_in))
	if def.output_good != Goods.Type.NONE:
		lines.append("Sortie : %s / %s t de %s" % [Format.decimal(b.output_stock),
			Format.thousands(roundi(def.buffer_capacity)), Goods.display_name(def.output_good).to_lower()])
		if b.reserved_out > 0.0:
			lines.append("Promis aux véhicules : %s t" % Format.decimal(b.reserved_out))
	if def.emission_per_hour > 0.0:
		lines.append("Émissions : %s t/h de CO₂" % Format.decimal(GameState.pollution.emission_of(b)))
	if def.research_per_hour > 0.0:
		var labs := GameState.buildings.all().filter(func(o: Building) -> bool:
			return o.def.research_per_hour > 0.0 and o.status == Building.Status.RUNNING).size()
		var efficiency := Production.research_efficiency(labs)
		lines.append("Recherche : %s RP/h" % Format.decimal(def.research_per_hour * GameState.production.research_factor
			* efficiency if b.status == Building.Status.RUNNING else 0.0))
		if labs > 1:
			lines.append("Rendement : %d %% (%d laboratoires en service)" % [roundi(efficiency * 100.0), labs])
	if def.power_demand_mw > 0.0:
		lines.append("Électricité : %s MW %s" % [Format.decimal(def.power_demand_mw),
			"(alimenté)" if b.powered else "(non alimenté)"])
	if def.storage_capacity > 0.0:
		lines.append("Stock : %s / %s t" % [Format.decimal(b.stored_total()),
			Format.thousands(roundi(def.storage_capacity))])
		for good: int in b.store:
			lines.append("  %s : %s t" % [Goods.display_name(good), Format.decimal(b.store[good])])
		if b.reserved_in > 0.0:
			lines.append("En route : %s t" % Format.decimal(b.reserved_in))
	if def.vehicle_slots > 0:
		var station := def.is_station()
		var port := def.is_port()
		var fleet := GameState.logistics.vehicles_of(b)
		var busy := fleet.filter(func(v: Vehicle) -> bool: return v.state != Vehicle.State.IDLE).size()
		var for_sale := fleet.filter(func(v: Vehicle) -> bool: return v.retiring).size()
		lines.append("%s : %d / %d (%d en mission)" % ["Trains" if station else "Barges" if port else "Véhicules",
			fleet.size() - for_sale, def.vehicle_slots, busy])
		if for_sale > 0:
			lines.append("À vendre au retour : %d" % for_sale)
		if busy < fleet.size():
			lines.append("%s : %d, rien à transporter pour l'instant" % [
				"En gare" if station else "Au port" if port else "Au dépôt", fleet.size() - busy])
			lines.append("  (départ quand une source a ≥ %d %% d'un chargement)" % roundi(Logistics.FULL_LOAD_RATIO * 100.0))
		if b != _actions_for:
			lines.append("Cliquez sur la gare pour acheter des trains" if station
				else "Cliquez sur le port pour acheter des barges" if port
				else "Cliquez sur le dépôt pour acheter des véhicules")
	var available := Production.resource_available(GameState.world_map, def, b.anchor)
	if available >= 0.0:
		lines.append("Ressource à portée : %s t" % Format.thousands(roundi(available)))
	lines.append("Entretien : %s €/jour" % Format.thousands(def.upkeep_per_day))
	return lines


## Boutons d'achat/revente de véhicules pour le dépôt sélectionné.
func _update_actions(b: Building) -> void:
	var depot := b if b and b.def.vehicle_slots > 0 and b.is_complete() else null
	if depot != _actions_for:
		_actions_for = depot
		for child in _actions.get_children():
			child.queue_free()
		_vehicle_rows.clear()
		if depot:
			_build_vehicle_rows(depot)
	_actions.visible = depot != null
	if depot == null:
		return
	var fleet := GameState.logistics.vehicles_of(depot)
	for def: VehicleDef in _vehicle_rows:
		var row := _vehicle_rows[def]
		var mine := fleet.filter(func(v: Vehicle) -> bool: return v.def == def)
		var for_sale := mine.filter(func(v: Vehicle) -> bool: return v.retiring).size()
		var sellable := mine.size() - for_sale
		var idle := mine.filter(func(v: Vehicle) -> bool: return v.state == Vehicle.State.IDLE and not v.retiring)
		(row[0] as Label).text = "%s : %d" % [def.display_name, sellable]
		if for_sale > 0:
			(row[0] as Label).text += " (%d à vendre)" % for_sale
		var buy: Button = row[1]
		var error := GameState.vehicle_error(depot, def)
		buy.disabled = not error.is_empty()
		buy.tooltip_text = error if not error.is_empty() else _vehicle_tooltip(def)
		var sell: Button = row[2]
		sell.disabled = sellable == 0
		var refund := Format.thousands(floori(def.cost * Logistics.SELL_REFUND))
		if sellable == 0:
			sell.tooltip_text = "Aucun véhicule de ce type à vendre"
		elif not idle.is_empty():
			sell.tooltip_text = "Revendre un véhicule au dépôt : +%s €" % refund
		else:
			sell.tooltip_text = "Tous en mission : un véhicule sera vendu à son retour au dépôt (+%s €).\nVide, il abandonne sa mission ; chargé, il livre d'abord." % refund


func _build_vehicle_rows(depot: Building) -> void:
	_actions.add_child(HSeparator.new())
	for def in VehicleDb.DEFS:
		if def.network != depot.def.vehicle_network:
			continue
		var row := HBoxContainer.new()
		var label := Label.new()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.clip_text = true
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.add_child(label)
		var buy := Button.new()
		buy.text = "+ %s €" % Format.thousands(def.cost)
		buy.focus_mode = Control.FOCUS_NONE
		buy.pressed.connect(func() -> void: GameState.buy_vehicle(depot, def))
		row.add_child(buy)
		var sell := Button.new()
		sell.text = "Vendre"
		sell.focus_mode = Control.FOCUS_NONE
		sell.pressed.connect(func() -> void: GameState.sell_vehicle(depot, def))
		row.add_child(sell)
		_actions.add_child(row)
		_vehicle_rows[def] = [label, buy, sell]


func _vehicle_tooltip(def: VehicleDef) -> String:
	return "\n".join(PackedStringArray([
		def.display_name,
		"Charge : %s t" % Format.decimal(def.capacity, 0),
		"Vitesse : %s tuile/h" % Format.decimal(def.speed),
		"Entretien : %d €/jour" % def.upkeep_per_day,
		"Usage : %s €/tuile" % Format.decimal(def.cost_per_tile),
	]))


func _city_lines(city: City) -> PackedStringArray:
	var tick := GameClock.tick
	var lines := PackedStringArray([
		City.SUPPLY_NAMES[city.supply],
		"Population : %s" % Format.thousands(city.population()),
		"Demande : %s MW (pic %s MW)" % [Format.decimal(city.demand_at(tick)), Format.decimal(city.peak_demand(tick))],
		"Aujourd'hui : %d h alimentée, %d h coupée" % [city.served_hours_today, city.shed_hours_today],
	])
	if GameDate.day_index(tick) > 0:
		lines.append("Alimentée hier : %d %%" % roundi(city.served_ratio_yesterday * 100.0))
	lines.append("Satisfaction : %d %% (alimentation et air)" % roundi(city.satisfaction * 100.0))
	lines.append("Tarif accepté : %d %% du prix du marché" % roundi(Economy.tariff(city.satisfaction) * 100.0))
	lines.append("Qualité de l'air : %d %%" % roundi(city.air_quality * 100.0))
	return lines


func _line_lines(cell: Vector2i) -> PackedStringArray:
	var net: PowerGrid.Network = GameState.grid.networks.get(GameState.grid.network_at(cell))
	if net == null:
		return PackedStringArray(["Réseau : —"])
	return PackedStringArray([
		"Réseau : %d tuiles, %d centrale%s, %d ville%s" % [net.tiles, net.producers.size(),
			"s" if net.producers.size() > 1 else "", net.cities.size(), "s" if net.cities.size() > 1 else ""],
		"Production : %s MW · pertes %d %%" % [Format.decimal(net.supply_mw), roundi(net.loss_ratio * 100.0)],
		"Demande : %s MW · livré %s MW" % [Format.decimal(net.demand_mw), Format.decimal(net.delivered_mw)],
		"Villes délestées : %d" % net.shed if net.shed > 0 else "Aucun délestage",
		"Entretien : %d €/jour" % PowerGrid.UPKEEP_PER_TILE_PER_DAY,
	])
