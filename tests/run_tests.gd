extends SceneTree
## Tests unitaires de la simulation pure (provisoire : GUT viendra plus tard).
## Lancer : godot --headless -s res://tests/run_tests.gd

var _failures := 0
var _count := 0


func _init() -> void:
	_test_tick_accumulator()
	_test_game_date()
	_test_iso_matches_tilemap()
	_test_planet_generation()
	_test_planet_chunks()
	_test_start_site()
	_test_territory()
	_test_exploration()
	_test_format()
	_test_building_defs()
	_test_placement()
	_test_construction()
	_test_zone_defs()
	_test_zones()
	_test_population()
	_test_labor_targets()
	_test_labor_step()
	_test_stockpile()
	_test_population_growth()
	_test_city_tier()
	_test_research()
	_test_village()
	_test_draft_animals()
	_test_inventions()
	_test_granary_upgrades()
	_test_production()
	_test_forest_cycle()
	_test_irrigation()
	_test_auto_priorities()
	_test_power_meter()
	_test_weather()
	_test_statistics()
	_test_milestones()
	_test_bourg()
	_test_rails()
	_test_steam_and_scouts()
	_test_roads()
	_test_treasury()
	_test_decrees()
	_test_city_events()


## Tests qui demandent les autoloads (GameState), prêts après la première
## image.
func _initialize() -> void:
	await process_frame
	_test_bourg_game()
	_test_economy_game()
	_test_events_game()
	_test_roads_game()
	_test_city_game()
	_test_camera_bounds()
	_test_fishing_reach()
	_test_ships()
	_test_port_links()
	_test_ports_game()
	_test_power_grid()
	_test_grid_game()
	_test_trucks()
	_test_trucks_game()
	print("%d vérifications, %d échec(s)" % [_count, _failures])
	quit(1 if _failures > 0 else 0)


## Carte plate : mer pour x < 20 et y < 40 ; territoire x < 30 et y < 20.
func _sea_map() -> Array:
	var flat := _flat_map()
	var map: WorldMap = flat[0]
	var territory: Territory = flat[1]
	for y in 40:
		for x in 20:
			map.set_terrain(Vector2i(x, y), TerrainDef.Type.SEA)
	var cells: Array[Vector2i] = []
	for y in 20:
		for x in 30:
			cells.append(Vector2i(x, y))
	territory.annex(cells)
	return flat


func _test_fishing_reach() -> void:
	var flat := _sea_map()
	var map: WorldMap = flat[0]
	var territory: Territory = flat[1]
	var zones := ZoneMap.new(map, territory, BuildingRegistry.new(map, territory))
	var fishing := ZoneDb.get_def(&"fishing")
	var far := Vector2i(5, 30)
	territory.explore([far] as Array[Vector2i])
	_check(zones.check_cell(fishing, Vector2i(19, 5)).is_empty() and "rivage" in zones.check_cell(fishing, Vector2i(18, 5)),
		"village : pêche à une tuile du rivage")
	zones.water_reach = BuildingDb.get_def(&"fishing_port").fishing_reach
	_check(zones.check_cell(fishing, Vector2i(16, 5)).is_empty() and "rivage" in zones.check_cell(fishing, Vector2i(15, 5))
		and "territoire" in zones.check_cell(fishing, far), "port de pêche : portée allongée, dans le territoire")
	zones.water_reach = ZoneMap.ALL_WATERS
	_check(zones.check_cell(fishing, Vector2i(10, 5)).is_empty() and zones.check_cell(fishing, far).is_empty()
		and "territoire" in zones.check_cell(fishing, Vector2i(5, 35)), "port : toutes les eaux découvertes, pas les autres")
	_check("territoire" in zones.check_cell(ZoneDb.get_def(&"agriculture"), Vector2i(40, 40)), "les autres zones restent dans le territoire")


func _test_ships() -> void:
	var territory: Territory = _sea_map()[1]
	var e := Exploration.new(territory)
	var from := Vector2i(25, 5)
	var target := Vector2i(5, 5)
	_check(e.plan_path(from, target).back() == Vector2i(20, 5), "sans port : arrêt devant la mer")
	e.ships = true
	_check(e.plan_path(from, target).back() == target and e.speed_at(target) > Exploration.TILES_PER_DAY[TerrainDef.Type.PLAIN],
		"avec un port : la mer se traverse, plus vite qu'à pied")
	_check(is_equal_approx(e.round_trip_days(from, target, 1.5), e.round_trip_days(from, Vector2i(20, 5), 1.5)
		+ 2.0 * 15.0 / Exploration.SHIP_TILES_PER_DAY), "les chevaux restent à quai")
	var trip := e.launch(from, target, 2, 100.0)
	e.ships = false
	for h in 24 * 3:
		e.step_hour()
	_check(trip.sailing and trip.position > 5.0 and e.days_back(trip, trip.path.size() - 1) > 0.0,
		"port perdu en route : les navires continuent")


func _test_port_links() -> void:
	var flat := _sea_map()
	var map: WorldMap = flat[0]
	var territory: Territory = flat[1]
	var cells: Array[Vector2i] = []
	for y in 12:
		for x in range(30, 50):
			cells.append(Vector2i(x, y))
	territory.annex(cells)
	for y in range(5, 8):
		for x in range(40, 43):
			map.set_terrain(Vector2i(x, y), TerrainDef.Type.LAKE)
	var registry := BuildingRegistry.new(map, territory)
	var port := BuildingDb.get_def(&"port")
	_check(not registry.check_placement(port, Vector2i(25, 5)).is_valid(), "port : au bord de l'eau seulement")
	var center := Vector2i(26, 5)
	var ports: Array[Building] = []
	for anchor: Vector2i in [Vector2i(20, 5), Vector2i(20, 19), Vector2i(43, 6)]:
		ports.append(registry.place(registry.check_placement(port, anchor)))
	var network := PortNetwork.new(map, territory)
	var walk := func(cell: Vector2i) -> int: return network.cheb(cell, center)
	network.refresh(ports, walk)
	var length: int = network.linked.get(Vector2i(20, 19), 0)
	_check(network.is_linked(Vector2i(20, 19)) and not network.is_linked(Vector2i(20, 5)) and not network.is_linked(Vector2i(43, 6)),
		"ports reliés par la mer, pas le lac séparé")
	_check(network.distances[Vector2i(20, 19)] == 6 + ceili(length / 4.0) and network.distance_via(Vector2i(22, 19)) == 6 + ceili(length / 4.0) + 2,
		"le trajet par l'eau rapproche les tuiles du port (%d tuiles d'eau)" % length)
	_check(network.distance_via(Vector2i(4, 5)) == 6 + 4, "les bateaux rapprochent les eaux de pêche")


func _test_ports_game() -> void:
	var gs: Node = root.get_node("GameState")
	gs.new_game(4242)
	gs.tier.level = 3
	var center: Vector2i = gs.display_cell(gs.home)
	gs.world_map.set_terrain(center + Vector2i(5, 5), TerrainDef.Type.LAKE)
	var fishing_port := BuildingDb.get_def(&"fishing_port")
	var port := BuildingDb.get_def(&"port")
	_check(fishing_port.tier == 3 and fishing_port.upgrade == port and port.tier == 4 and gs.build_level(fishing_port) == fishing_port,
		"bourg : port de pêche, améliorable en port")
	_check(gs.zones.water_reach == ZoneMap.SHORE_REACH, "sans port : une tuile du rivage")
	var b := _place_running(gs, fishing_port)
	gs._refresh_capacities()
	_check(b != null and gs.zones.water_reach == fishing_port.fishing_reach and not gs.exploration.ships, "port de pêche : portée allongée")
	gs.tier.level = 4
	_check(gs.build_level(fishing_port) == port, "ville : le port se construit directement")
	for good in Stockpile.COUNT:
		gs.stockpile.capacity[good] = 1000.0
		gs.stockpile.amount[good] = 1000.0
	_check(gs.upgrade(b.anchor), "port de pêche amélioré")
	gs._refresh_capacities()
	_check(gs.zones.water_reach == fishing_port.fishing_reach and not gs.exploration.ships, "pendant les travaux : toujours un port de pêche")
	b.build_progress = port.build_hours
	gs._refresh_capacities()
	_check(gs.zones.water_reach == ZoneMap.ALL_WATERS and gs.exploration.ships and gs.ports.distances.size() == 1, "port : eaux ouvertes, navires")
	gs.new_game(4242)


func _test_power_grid() -> void:
	var flat := _sea_map()
	var map: WorldMap = flat[0]
	var territory: Territory = flat[1]
	map.set_terrain(Vector2i(27, 3), TerrainDef.Type.RIVER)
	var registry := BuildingRegistry.new(map, territory)
	var grid := PowerGrid.new(map, territory, registry, Vector2i(20, 10))
	registry.lines = grid
	var plant_def := BuildingDb.get_def(&"power_plant")
	var dam_def := BuildingDb.get_def(&"dam")
	var near: Building = registry.place(registry.check_placement(plant_def, Vector2i(24, 10)))
	var far: Building = registry.place(registry.check_placement(dam_def, Vector2i(28, 3)))
	_check(near != null and far != null, "centrale, et barrage au bord d'une rivière")
	_check(not registry.check_placement(dam_def, Vector2i(24, 14)).is_valid(), "barrage : à côté d'une rivière seulement")
	var plants: Array[Building] = [near, far]
	grid.refresh(plants)
	_check(grid.connected.size() == 1 and near in grid.connected, "sans ligne : seule la centrale du village produit")
	grid.add_cells(TrackNetwork.l_path(Vector2i(28, 10), Vector2i(28, 4)))
	grid.refresh(plants)
	_check(grid.connected.size() == 1 and grid.linked.is_empty(), "ligne isolée : barrage non raccordé")
	grid.add_cells(TrackNetwork.l_path(Vector2i(25, 11), Vector2i(28, 11)))
	grid.refresh(plants)
	_check(far in grid.connected and grid.linked.has(Vector2i(28, 4)), "ligne reliée au village : barrage raccordé")
	_check("Ligne" in registry.check_placement(BuildingDb.get_def(&"house"), Vector2i(28, 8)).error, "pas de bâtiment sur une ligne")
	# 5 000 habitants : 100 kW ; barrage d'été 42 kW, centrale 40 kW.
	var burnt := grid.run_day(5000, GameDate.SUMMER, 1000.0)
	_check(is_equal_approx(grid.demand, 100000.0) and is_equal_approx(grid.hydro, 42000.0) and is_equal_approx(burnt, 40.0)
		and is_equal_approx(grid.coverage, 0.82), "barrage d'abord, puis centrale (%s)" % grid.coverage)
	burnt = grid.run_day(5000, GameDate.SUMMER, 10.0)
	_check(is_equal_approx(burnt, 10.0) and is_equal_approx(grid.supplied, 52000.0), "centrale limitée par le charbon")
	burnt = grid.run_day(1000, GameDate.SUMMER, 100.0)
	_check(burnt == 0.0 and is_equal_approx(grid.coverage, 1.0) and is_equal_approx(grid.hydro, 20000.0)
		and is_equal_approx(grid.industry_factor(), 1.25), "demande couverte par l'eau : pas de charbon brûlé")


func _test_grid_game() -> void:
	var gs: Node = root.get_node("GameState")
	gs.new_game(4242)
	var site := StartSite.territory_rect(gs.home)
	var copper_cells := 0
	for y in range(site.position.y, site.end.y):
		for x in range(site.position.x, site.end.x):
			if gs.world_map.get_deposit(Vector2i(x, y)) == WorldMap.Deposit.COPPER:
				copper_cells += 1
	var stone_cells := 0
	for y in range(gs.home.y - StartSite.STONE_DEPOSIT_RADIUS, gs.home.y + StartSite.STONE_DEPOSIT_RADIUS + 1):
		for x in range(gs.home.x - StartSite.STONE_DEPOSIT_RADIUS, gs.home.x + StartSite.STONE_DEPOSIT_RADIUS + 1):
			if gs.world_map.get_deposit(Vector2i(x, y)) == WorldMap.Deposit.STONE:
				stone_cells += 1
	_check(stone_cells >= StartSite.MIN_STONE_DEPOSIT, "pierre près du village (%d tuiles)" % stone_cells)
	_check(copper_cells >= StartSite.MIN_COPPER, "cuivre près du village (%d tuiles)" % copper_cells)
	var mine := ZoneDb.get_def(&"copper_mine")
	_check(mine.tier == 4 and mine.output == Stockpile.Good.COPPER and mine.deposit == WorldMap.Deposit.COPPER, "mine de cuivre à la ville")
	_check("palier" in gs.lines_error(), "lignes : à la ville")
	gs.tier.level = 4
	_check("Recherche" in gs.lines_error(), "lignes : recherche requise")
	gs.research._done[&"sylviculture"] = true
	gs._refresh_capacities()
	_check(is_equal_approx(gs.production.regrowth_factor, gs.SYLVICULTURE_REGROWTH), "sylviculture : effet appliqué une fois la recherche finie")
	gs.research._done.erase(&"sylviculture")
	gs._refresh_capacities()
	_test_charcoal(gs)
	gs.research._done[&"conductivity"] = true
	gs.population.count = 1000
	var stock: Stockpile = gs.stockpile
	for good in Stockpile.COUNT:
		stock.capacity[good] = 5000.0
		stock.amount[good] = 2000.0
	var plant := _place_running(gs, BuildingDb.get_def(&"power_plant"))
	gs._refresh_capacities()
	stock.amount[Stockpile.Good.COAL] = 2000.0
	stock.capacity[Stockpile.Good.COAL] = 5000.0
	gs.coal_burned_today = 0.0
	_check(plant != null and plant in gs.grid.connected, "centrale du village raccordée")
	gs._run_grid(0)
	_check(is_equal_approx(gs.grid.coverage, 1.0) and is_equal_approx(stock.amount[Stockpile.Good.COAL], 1980.0)
		and is_equal_approx(gs.coal_burned_today, 20.0), "1 000 habitants : 20 kW, 20 charbon")
	var fuel: float = stock.amount[Stockpile.Good.FUEL]
	_check(gs.light_need() == 0.0 and gs._burn_light() == 1.0 and stock.amount[Stockpile.Good.FUEL] == fuel, "le courant remplace le carburant")
	stock.amount[Stockpile.Good.COAL] = 10.0
	gs._run_grid(0)
	var need: float = gs.population.light_need()
	_check(is_equal_approx(gs.grid.coverage, 0.5) and is_equal_approx(gs.light_need(), need / 2.0)
		and is_equal_approx(gs._burn_light(), 1.0), "moitié courant, moitié carburant")
	stock.amount[Stockpile.Good.FUEL] = 0.0
	_check(is_equal_approx(gs._burn_light(), 0.5), "sans carburant : la part du courant seule")
	_check(gs.grid.base_costs()[Stockpile.Good.COPPER] == PowerGrid.COPPER_PER_TILE and gs.lines_error().is_empty(), "une ligne coûte du cuivre")
	gs.new_game(4242)


func _test_trucks() -> void:
	var flat := _flat_map()
	var map: WorldMap = flat[0]
	var territory: Territory = flat[1]
	var cells: Array[Vector2i] = []
	for y in 20:
		for x in 64:
			cells.append(Vector2i(x, y))
	territory.annex(cells)
	var registry := BuildingRegistry.new(map, territory)
	var roads := RoadNetwork.new(map, territory, registry, Vector2i(2, 10))
	registry.roads = roads
	roads.add_cells(TrackNetwork.l_path(Vector2i(3, 10), Vector2i(50, 10)))
	roads.refresh()
	var far := Vector2i(50, 12)
	var wide := Vector2i(50, 13)
	_check(roads.distance_via(far) == 21 + 2 and roads.distance_via(wide) == -1 and not roads.has_trucks() and roads.fuel_need() == 0.0,
		"sans camions : 2 tuiles de route par tuile de marche")
	var depot: Building = registry.place(registry.check_placement(BuildingDb.get_def(&"truck_depot"), Vector2i(10, 12)))
	roads.depots.append(depot)
	roads.refresh()
	_check(roads.served_depots.is_empty() and roads.fuel_need() == 0.0, "dépôt sans route : aucun camion")
	registry.remove(depot)
	var served: Building = registry.place(registry.check_placement(BuildingDb.get_def(&"truck_depot"), Vector2i(10, 11)))
	roads.depots.clear()
	roads.depots.append(served)
	roads.refresh()
	# Tuile (49, 10), 42e de la route : (42 − 30) / 6 = 2 tuiles de marche, plus 2 ou 3 de côté.
	_check(roads.has_trucks() and roads.distance_via(far) == 2 + 2 and roads.distance_via(wide) == 2 + 3, "camions : 30 tuiles libres, puis 6 par tuile de marche")
	_check(is_equal_approx(roads.fuel_need(), 2.0 + 0.05 * 48.0), "carburant : dépôt et tuiles de route")
	roads.running = false
	roads.refresh()
	_check(roads.distance_via(far) == 21 + 2 and roads.distance_via(wide) == -1, "camions arrêtés : retour aux charrettes")


func _test_trucks_game() -> void:
	var gs: Node = root.get_node("GameState")
	gs.new_game(4242)
	gs.tier.level = 4
	var depot := _place_running(gs, BuildingDb.get_def(&"truck_depot"))
	_check(depot != null, "dépôt posé")
	var road: Array[Vector2i] = []
	for cell in depot.cells:
		for o in WorldMap.NEIGHBORS_4:
			if road.is_empty() and not gs.buildings.building_at(cell + o):
				road.append(cell + o)
	gs.roads.add_cells(road)
	gs._refresh_capacities()
	_check(depot in gs.roads.served_depots and gs.roads.has_trucks(), "route du village : camions en service")
	var stock: Stockpile = gs.stockpile
	stock.capacity[Stockpile.Good.FUEL] = 100.0
	stock.amount[Stockpile.Good.FUEL] = 50.0
	var need: float = gs.roads.fuel_need()
	gs._run_trucks()
	_check(gs.roads.running and is_equal_approx(stock.amount[Stockpile.Good.FUEL], 50.0 - need), "les camions brûlent du carburant")
	stock.amount[Stockpile.Good.FUEL] = 0.0
	gs._run_trucks()
	_check(not gs.roads.running and not gs.roads.has_trucks(), "sans carburant : camions arrêtés")
	stock.amount[Stockpile.Good.FUEL] = 50.0
	gs._run_trucks()
	_check(gs.roads.running and gs.roads.has_trucks(), "carburant revenu : camions repartis")
	gs.new_game(4242)


## La caméra suit la carte connue quand les expéditions l'agrandissent.
func _test_camera_bounds() -> void:
	var gs: Node = root.get_node("GameState")
	gs.new_game(4242)
	var camera: Camera2D = load("res://scenes/world/camera_controller.gd").new()
	root.add_child(camera)
	var before: Rect2 = camera._bounds
	var far := Vector2i(gs.home.x + 40, gs.home.y)
	gs.territory.explore([gs.world_map.wrap_cell(far)] as Array[Vector2i])
	root.get_node("EventBus").territory_changed.emit()
	var tile := Iso.map_to_world(Vector2(gs.display_cell(gs.world_map.wrap_cell(far))))
	_check(not before.has_point(tile) and camera._bounds.has_point(tile), "caméra : bornes agrandies par l'exploration")
	camera.free()
	gs.new_game(4242)


func _check(condition: bool, label: String) -> void:
	_count += 1
	if not condition:
		_failures += 1
		printerr("ÉCHEC : ", label)


func _test_tick_accumulator() -> void:
	var acc := TickAccumulator.new(10.0, 16)
	_check(acc.consume(0.05, 1) == 0, "demi-tick → 0")
	_check(acc.consume(0.05, 1) == 1, "deux demi-ticks → 1")
	_check(acc.consume(1.0, 1) == 10, "1 s à ×1 → 10 ticks")
	_check(acc.consume(1.0, 0) == 0, "pause → 0 tick")
	_check(acc.consume(0.5, 4) == 16, "×4 plafonné à 16")
	_check(acc.consume(0.0, 4) == 0, "surplus abandonné après plafond")
	var total := 0
	for i in 600:
		total += acc.consume(1.0 / 60.0, 2)
	_check(absi(total - 200) <= 1, "10 s à ×2 et 60 FPS → ~200 ticks (%d)" % total)


func _test_game_date() -> void:
	_check(GameDate.format(0) == "Printemps, jour 1, an 1 — 00:00", "date initiale")
	_check(GameDate.hour_of_day(25) == 1, "heure après un jour")
	_check(GameDate.day_of_season(24 * 29) == 30, "dernier jour de saison")
	_check(GameDate.season(GameDate.HOURS_PER_SEASON) == 1, "été")
	_check(GameDate.season(GameDate.HOURS_PER_YEAR - 1) == 3, "fin d'hiver")
	_check(GameDate.year(GameDate.HOURS_PER_YEAR) == 2, "année 2")


func _test_iso_matches_tilemap() -> void:
	var layer := TileMapLayer.new()
	layer.tile_set = TerrainTileSet.build()
	var ok := true
	for cell in [Vector2i(0, 0), Vector2i(3, 0), Vector2i(0, 5), Vector2i(17, 42)]:
		ok = ok and layer.map_to_local(cell) == Iso.map_to_world(Vector2(cell))
		ok = ok and layer.local_to_map(Iso.map_to_world(Vector2(cell)) + Vector2(30, 10)) == cell
	_check(ok, "Iso identique à TileMapLayer (Diamond Down)")
	var d := Iso.footprint_diamond(Vector2i(2, 3), Vector2i(2, 2))
	var tiles := [Iso.diamond(Vector2i(2, 3)), Iso.diamond(Vector2i(3, 3)),
		Iso.diamond(Vector2i(3, 4)), Iso.diamond(Vector2i(2, 4))]
	_check(d[0] == tiles[0][0] and d[1] == tiles[1][1] and d[2] == tiles[2][2] and d[3] == tiles[3][3],
		"losange d'emprise 2×2 = coins extrêmes des tuiles")
	layer.free()


const PLANET := Vector2i(1024, 512)


## Générateur d'une planète de plaine aux attributs contrôlés.
class FlatGenerator extends MapGenerator:
	func _init(p_size: Vector2i) -> void:
		super(0, p_size)

	func generate_chunk(_coord: Vector2i) -> WorldMap.Chunk:
		var chunk := WorldMap.Chunk.new()
		chunk.terrain.fill(TerrainDef.Type.PLAIN)
		chunk.wind.fill(0.3)
		chunk.sun.fill(0.5)
		chunk.fertility.fill(0.7)
		return chunk


func _test_planet_generation() -> void:
	var a := MapGenerator.new(1234, PLANET)
	var b := MapGenerator.new(1234, PLANET)
	var c := MapGenerator.new(999, PLANET)
	var same := true
	var differs := false
	for k in 300:
		var cell := Vector2i((k * 389) % PLANET.x, (k * 157) % PLANET.y)
		same = same and a.fields(cell).terrain == b.fields(cell).terrain \
			and a.fields(cell).elevation == b.fields(cell).elevation
		differs = differs or a.fields(cell).terrain != c.fields(cell).terrain
	_check(same, "même graine → même planète")
	_check(differs, "graines différentes → planètes différentes")
	_check(a.fields(Vector2i(PLANET.x + 5, 100)).elevation == a.fields(Vector2i(5, 100)).elevation,
		"la longitude boucle")

	# Raccord est-ouest : pas plus de différence d'altitude à la couture qu'ailleurs.
	var seam := 0.0
	var inside := 0.0
	for y in range(8, PLANET.y - 8, 4):
		seam += absf(a.fields(Vector2i(PLANET.x - 1, y)).elevation - a.fields(Vector2i(0, y)).elevation)
		inside += absf(a.fields(Vector2i(511, y)).elevation - a.fields(Vector2i(512, y)).elevation)
	_check(seam < 2.0 * inside + 0.01, "pas de couture à la ligne de changement de date (%.3f / %.3f)" % [seam, inside])

	for seed_value in [1, 2, 42]:
		var gen := MapGenerator.new(seed_value, PLANET)
		var present := {}
		var polar_ice := 0
		var polar := 0
		var temperate_ice := 0
		var deserts := {tropics = 0, elsewhere = 0}
		for y in range(0, PLANET.y, 4):
			for x in range(0, PLANET.x, 4):
				var f := gen.fields(Vector2i(x, y))
				present[f.terrain] = true
				var lat := absf(f.latitude)
				if lat > 84.0:
					polar += 1
					polar_ice += 1 if f.terrain == TerrainDef.Type.ICE else 0
				elif lat < 45.0 and f.terrain == TerrainDef.Type.ICE:
					temperate_ice += 1
				if f.terrain == TerrainDef.Type.DESERT:
					deserts[&"tropics" if lat < 45.0 else &"elsewhere"] += 1
		var missing := PackedStringArray()
		for def in TerrainDb.DEFS:
			if not present.has(def.type):
				missing.append(def.display_name)
		_check(missing.is_empty(), "planète %d : tous les terrains %s" % [seed_value, missing])
		_check(polar_ice > 0.9 * polar, "planète %d : glace aux pôles (%d / %d)" % [seed_value, polar_ice, polar])
		_check(temperate_ice == 0, "planète %d : pas de glace sous 45° (%d)" % [seed_value, temperate_ice])
		_check(deserts.tropics > 3 * deserts.elsewhere, "planète %d : déserts vers les tropiques %s" % [seed_value, deserts])


func _test_planet_chunks() -> void:
	var map := WorldMap.new(PLANET, 42)
	_check(map.generated_count() == 0, "aucun bloc avant le premier accès")
	var cell := Vector2i(PLANET.x - 1, 200)
	var t := map.get_terrain(cell)
	_check(map.generated_count() == 1, "bloc généré à la demande")
	_check(map.get_terrain(cell + Vector2i(PLANET.x, 0)) == t and map.generated_count() == 1,
		"abscisse ramenée sur la planète")
	_check(map.unwrap_near(Vector2i(2, 5), PLANET.x - 3) == Vector2i(PLANET.x + 2, 5)
		and map.unwrap_near(Vector2i(PLANET.x - 2, 5), 3) == Vector2i(-2, 5), "copie la plus proche")
	_check(is_equal_approx(map.latitude(0), 90.0 - 90.0 / PLANET.y) and map.latitude(PLANET.y - 1) < -89.0,
		"latitudes : nord en haut")
	_check(map.longitude(0) < -179.0 and map.longitude(PLANET.x - 1) > 179.0, "longitudes")

	# Blocs voisins de la couture (accès à l'eau aux bords compris).
	var errors := PackedStringArray()
	var found := {}
	var chunks: Array[Vector2i] = [Vector2i(31, 6), Vector2i(0, 6)]
	for k in 120:
		chunks.append(Vector2i((k * 13) % 32, 3 + (k * 7) % 10))
	for chunk in chunks:
		for i in WorldMap.CHUNK_SIZE * WorldMap.CHUNK_SIZE:
			var c := chunk * WorldMap.CHUNK_SIZE + Vector2i(i % WorldMap.CHUNK_SIZE, i / WorldMap.CHUNK_SIZE)
			var terrain := map.get_terrain(c)
			if terrain != map.generator.fields(c).terrain:
				errors.append("terrain du bloc ≠ générateur en %s" % c)
			for v in [map.get_wind(c), map.get_sun(c), map.get_fertility(c), map.get_pasture(c)]:
				if v < 0.0 or v > 1.0:
					errors.append("attribut hors 0–1 en %s" % c)
			var touches_water := map.neighbors(c, WorldMap.NEIGHBORS_8) \
				.any(func(n: Vector2i) -> bool: return map.is_water(n))
			if map.has_water_access(c) != (touches_water and not map.is_water(c)):
				errors.append("accès à l'eau incohérent en %s" % c)
			if (terrain == TerrainDef.Type.FOREST) != (map.get_wood(c) > 0.0):
				errors.append("bois incohérent en %s" % c)
			var kind := map.get_deposit(c)
			if kind != WorldMap.Deposit.NONE:
				found[kind] = true
				if not TerrainDb.get_def(terrain).buildable or map.get_deposit_amount(c) <= 0:
					errors.append("gisement invalide en %s" % c)
		if found.size() == WorldMap.Deposit.size() - 1 and chunk.x > 0:
			break
	_check(errors.is_empty(), "blocs cohérents %s" % [errors.slice(0, 3)])
	_check(found.size() == WorldMap.Deposit.size() - 1, "les 7 gisements existent (%d)" % found.size())

	map.set_terrain(cell, TerrainDef.Type.PLAIN)
	var neighbor := cell + Vector2i(1, 0)
	map.set_terrain(neighbor, TerrainDef.Type.PLAIN)
	for n in map.neighbors(cell, WorldMap.NEIGHBORS_8):
		map.set_terrain(n, TerrainDef.Type.PLAIN)
	_check(not map.has_water_access(cell), "plus d'eau autour")
	map.set_terrain(neighbor, TerrainDef.Type.LAKE)
	_check(map.has_water_access(cell) and not map.has_water_access(neighbor),
		"un lac voisin (de l'autre côté de la couture) donne l'accès à l'eau")


func _test_start_site() -> void:
	for seed_value in [1, 2, 3, 42, 777, 123456]:
		var map := WorldMap.new(PLANET, seed_value)
		var home := StartSite.find(map.generator)
		var rect := StartSite.territory_rect(home)
		_check(rect.size == Vector2i(12, 12) and rect.has_point(home), "territoire 12×12 autour du village")
		var lat := absf(map.latitude(home.y))
		_check(lat >= StartSite.MIN_LATITUDE - 1.0 and lat <= StartSite.MAX_LATITUDE + 1.0,
			"graine %d : latitude tempérée (%.0f°)" % [seed_value, lat])
		var changed := StartSite.ensure(map, rect)
		var counts := StartSite._counts(rect, func(c: Vector2i) -> int: return map.get_terrain(c))
		var near := StartSite._counts(Rect2i(home - Vector2i.ONE * StartSite.STONE_RADIUS, Vector2i.ONE * (2 * StartSite.STONE_RADIUS + 1)),
			func(c: Vector2i) -> int: return map.get_terrain(c))
		_check(counts.forest >= StartSite.MIN_FOREST and counts.water >= StartSite.MIN_WATER
			and near.stone >= StartSite.MIN_STONE and counts.farmland > 0,
			"graine %d : forêt, plaine, eau, et collines à %d tuiles du centre %s (%d retouches)" % [
				seed_value, StartSite.STONE_RADIUS, counts, changed.size()])
		_check(_iron_near(map, home) >= StartSite.MIN_IRON, "graine %d : fer près du village (%d tuiles)" % [seed_value, _iron_near(map, home)])
	var flat := WorldMap.new(Vector2i(64, 64), 0, FlatGenerator.new(Vector2i(64, 64)))
	var rect := StartSite.territory_rect(Vector2i(20, 20))
	var changed := StartSite.ensure(flat, rect)
	var counts := StartSite._counts(rect, func(c: Vector2i) -> int: return flat.get_terrain(c))
	var hills := changed.filter(func(c: Vector2i) -> bool: return flat.get_terrain(c) == TerrainDef.Type.HILL)
	var oil_tiles := changed.filter(func(c: Vector2i) -> bool: return flat.get_deposit(c) == WorldMap.Deposit.OIL)
	_check(oil_tiles.size() == StartSite.MIN_OIL and counts.water == 1
		and counts.forest == StartSite.MIN_FOREST and counts.stone == StartSite.MIN_STONE,
		"plaine nue : forêt, lac, collines et pétrole ajoutés %s" % counts)
	_check(hills.size() == 4 and hills.all(func(c: Vector2i) -> bool:
		return maxi(absi(c.x - 20), absi(c.y - 20)) <= StartSite.STONE_RADIUS and maxi(absi(c.x - 20), absi(c.y - 20)) >= 3),
		"colline à pierre à 3–4 tuiles du centre %s" % [hills])
	var iron: Array[Vector2i] = []
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if flat.get_deposit(Vector2i(x, y)) == WorldMap.Deposit.IRON:
				iron.append(Vector2i(x, y))
	_check(iron.size() == StartSite.MIN_IRON and _iron_near(flat, Vector2i(20, 20)) == StartSite.MIN_IRON
		and maxi(absi(iron[0].x - iron[1].x), absi(iron[0].y - iron[1].y)) == 1
		and is_equal_approx(flat.get_deposit_amount(iron[0]), StartSite.IRON_AMOUNT),
		"plaine nue : un filon de fer de 2 tuiles à 3–5 tuiles du centre %s" % [iron])


## Tuiles de fer à StartSite.IRON_MIN_DISTANCE–IRON_RADIUS tuiles de [param home].
func _iron_near(map: WorldMap, home: Vector2i) -> int:
	var n := 0
	for dy in range(-StartSite.IRON_RADIUS, StartSite.IRON_RADIUS + 1):
		for dx in range(-StartSite.IRON_RADIUS, StartSite.IRON_RADIUS + 1):
			if maxi(absi(dx), absi(dy)) >= StartSite.IRON_MIN_DISTANCE \
					and map.get_deposit(home + Vector2i(dx, dy)) == WorldMap.Deposit.IRON:
				n += 1
	return n


func _test_territory() -> void:
	var map := WorldMap.new(Vector2i(64, 64), 0, FlatGenerator.new(Vector2i(64, 64)))
	var territory := Territory.new(map)
	var a := Vector2i(63, 10)
	var b := Vector2i(64, 10)  # = (0, 10)
	_check(territory.state_at(a) == Territory.State.UNKNOWN and not territory.is_known(b), "inconnue au départ")
	territory.annex([a] as Array[Vector2i])
	territory.explore([a, b, Vector2i(5, -1)] as Array[Vector2i])
	_check(territory.is_territory(a), "l'exploration ne retire pas une tuile du territoire")
	_check(territory.state_at(Vector2i(0, 10)) == Territory.State.EXPLORED, "explorée (abscisse ramenée)")
	_check(territory.count(Territory.State.EXPLORED) == 1 and territory.count(Territory.State.TERRITORY) == 1,
		"comptes par état")
	var known := territory.known_cells()
	known.sort()
	_check(known == [Vector2i(0, 10), Vector2i(63, 10)], "tuiles connues ramenées %s" % [known])
	var chunk := map._chunk(a)
	chunk.deposit[map._local(a)] = WorldMap.Deposit.IRON
	chunk.deposit_amount[map._local(a)] = 5000.0
	_check(territory.known_deposit(a) == WorldMap.Deposit.NONE, "gisement caché avant prospection")
	territory.prospect([a, Vector2i(30, 30)] as Array[Vector2i])
	_check(territory.known_deposit(a) == WorldMap.Deposit.NONE, "fer prospecté mais caché avant le village")
	territory.tier = 2
	_check(territory.known_deposit(a) == WorldMap.Deposit.IRON and territory.is_territory(a),
		"gisement révélé par la prospection au village, état conservé")
	_check(not territory.is_prospected(Vector2i(30, 30)), "pas de prospection d'une tuile inconnue")


func _test_exploration() -> void:
	var flat := _flat_map()
	var map: WorldMap = flat[0]
	var territory: Territory = flat[1]
	var exploration := Exploration.new(territory)
	var home := Vector2i(4, 4)
	var path := exploration.plan_path(home, Vector2i(24, 14))
	_check(path[0] == home and path[-1] == Vector2i(24, 14) and path.size() == 21, "trajet en ligne droite (%d tuiles)" % path.size())
	var ok := true
	for k in range(1, path.size()):
		var step := path[k] - path[k - 1]
		ok = ok and maxi(absi(step.x), absi(step.y)) == 1
	_check(ok, "trajet de proche en proche")
	# Un lac barre le chemin : arrêt devant l'eau.
	map.set_terrain(Vector2i(14, 4), TerrainDef.Type.LAKE)
	var blocked := exploration.plan_path(home, Vector2i(20, 4))
	_check(blocked[-1] == Vector2i(13, 4), "arrêt devant le lac (%s)" % blocked[-1])
	map.set_terrain(Vector2i(14, 4), TerrainDef.Type.RIVER)
	_check(exploration.plan_path(home, Vector2i(20, 4))[-1] == Vector2i(20, 4), "rivière passée à gué")
	map.set_terrain(Vector2i(14, 4), TerrainDef.Type.PLAIN)
	_check(is_equal_approx(exploration.round_trip_days(home, Vector2i(12, 4)), 4.0), "aller-retour : 8 tuiles de plaine = 4 jours")
	# Expédition : 2 explorateurs, de quoi marcher 6 jours vers une cible à 16 jours aller-retour.
	var e := exploration.launch(home, Vector2i(36, 4), 2, 12.0)
	_check(e != null and exploration.members_out() == 2 and not exploration.can_launch(), "expédition lancée, une seule à la fois")
	_check(territory.is_known(Vector2i(7, 7)) and not territory.is_known(Vector2i(16, 4)), "vue autour du départ")
	var hours := 0
	var turned := false
	var max_reach := 0
	while not exploration.expeditions.is_empty() and hours < 24 * 40:
		var report := exploration.step_hour()
		turned = turned or not report.turned.is_empty()
		max_reach = maxi(max_reach, e.cell().x)
		hours += 1
	_check(turned and e.reason == Exploration.Reason.FOOD, "demi-tour faute de vivres")
	_check(exploration.expeditions.is_empty() and e.cell() == home, "retour au village (%d h)" % hours)
	_check(max_reach >= 15 and max_reach <= 18, "assez loin pour revenir (x max %d)" % max_reach)
	_check(e.food >= 0.0 and e.food < 1.5, "vivres presque épuisés au retour (%.2f)" % e.food)
	_check(territory.is_known(Vector2i(max_reach + 3, 4)) and not territory.is_known(Vector2i(max_reach + 5, 4)),
		"tuiles révélées dans le rayon de vue")
	_check(e.revealed > 0 and territory.count(Territory.State.EXPLORED) == 0
		and territory.count(Territory.State.TERRITORY) == territory.known_cells().size(),
		"tuiles vues annexées au territoire (%d)" % e.revealed)
	_check(territory.state_at(home) == Territory.State.TERRITORY, "le territoire reste territoire")
	# Cible atteinte avec des vivres en trop.
	e = exploration.launch(home, Vector2i(10, 4), 1, 20.0)
	while not exploration.expeditions.is_empty():
		exploration.step_hour()
	_check(e.reason == Exploration.Reason.TARGET and e.food > 15.0, "objectif atteint, vivres rapportés (%.1f)" % e.food)


func _test_format() -> void:
	_check(Format.thousands(1234567) == "1\u202f234\u202f567", "milliers")
	_check(Format.thousands(-500) == "-500", "négatif court")
	_check(Format.duration_hours(48) == "2 j" and Format.duration_hours(36) == "36 h", "durées")


## Petite planète de plaine dont le carré (0, 0)–(7, 7) est le territoire.
func _flat_map() -> Array:
	var map := WorldMap.new(Vector2i(64, 64), 0, FlatGenerator.new(Vector2i(64, 64)))
	var territory := Territory.new(map)
	var cells: Array[Vector2i] = []
	for y in 8:
		for x in 8:
			cells.append(Vector2i(x, y))
	territory.annex(cells)
	return [map, territory]


func _test_building_defs() -> void:
	var ids := {}
	for def in BuildingDb.DEFS:
		_check(not ids.has(def.id), "identifiant unique %s" % def.id)
		ids[def.id] = true
		_check(def.build_hours > 0 and def.size.x > 0 and def.size.y > 0,
			"%s : durée et taille positives" % def.id)
		_check(BuildingDb.get_def(def.id) == def, "BuildingDb.get_def(%s)" % def.id)
	var def := _def(Vector2i(2, 2))
	_check(def.footprint(Vector2i(5, 5)) == [Vector2i(4, 4), Vector2i(5, 4), Vector2i(4, 5), Vector2i(5, 5)],
		"emprise 2×2 ancrée à l'avant-bas")
	def.needs_water_access = true
	_check(def.describe_constraints() == PackedStringArray(["Près de l'eau"]), "contraintes lisibles")


## Définition de test (indépendante des données du jeu).
func _def(size := Vector2i.ONE, build_hours := 10) -> BuildingDef:
	var def := BuildingDef.new()
	def.id = &"test"
	def.display_name = "Test"
	def.size = size
	def.build_hours = build_hours
	return def


func _test_placement() -> void:
	var flat := _flat_map()
	var map: WorldMap = flat[0]
	var reg := BuildingRegistry.new(map, flat[1])
	var small := _def()
	var big := _def(Vector2i(2, 2))
	var wide := _def(Vector2i(2, 1))

	_check(reg.check_placement(small, Vector2i(2, 2)).is_valid(), "plaine libre : valide")
	_check(reg.check_placement(big, Vector2i(3, 0)).error == "Hors de la carte", "emprise au-delà du pôle")
	_check(reg.check_placement(wide, Vector2i(0, 3)).error == "Hors du territoire",
		"2×1 à x=0 : déborde du territoire (de l'autre côté de la couture)")
	_check(reg.check_placement(small, Vector2i(8, 3)).error == "Hors du territoire", "hors du territoire")
	_check(reg.check_placement(wide, Vector2i(1, 0)).is_valid(), "2×1 en (0..1, 0)")

	map.set_terrain(Vector2i(3, 3), TerrainDef.Type.MOUNTAIN)
	_check(not reg.check_placement(small, Vector2i(3, 3)).is_valid(), "montagne non constructible")
	map.set_terrain(Vector2i(3, 3), TerrainDef.Type.HILL)
	_check(reg.check_placement(small, Vector2i(3, 3)).is_valid(), "colline constructible")
	var plain_only := _def()
	plain_only.allowed_terrains = [TerrainDef.Type.PLAIN]
	_check(not reg.check_placement(plain_only, Vector2i(3, 3)).is_valid(), "terrain non autorisé")

	var near_forest := _def()
	near_forest.adjacent_terrains = [TerrainDef.Type.FOREST]
	_check(not reg.check_placement(near_forest, Vector2i(5, 5)).is_valid(), "pas de forêt voisine")
	map.set_terrain(Vector2i(6, 6), TerrainDef.Type.FOREST)
	_check(reg.check_placement(near_forest, Vector2i(5, 5)).is_valid(), "forêt voisine (diagonale)")
	var on_forest := reg.check_placement(small, Vector2i(6, 6))
	_check(on_forest.is_valid() and on_forest.cleared == [Vector2i(6, 6)], "forêt à défricher")
	_check(not reg.check_placement(near_forest, Vector2i(6, 6)).is_valid(),
		"la forêt de l'emprise ne compte pas comme voisine")

	var wet := _def(Vector2i(2, 2))
	wet.needs_water_access = true
	_check(not reg.check_placement(wet, Vector2i(7, 1)).is_valid(), "sans eau")
	map.set_terrain(Vector2i(5, 0), TerrainDef.Type.LAKE)
	_check(reg.check_placement(wet, Vector2i(7, 1)).is_valid(), "une tuile près de l'eau suffit")

	var b := reg.place(reg.check_placement(big, Vector2i(7, 1)))
	_check(reg.building_at(Vector2i(6, 0)) == b and reg.building_at(Vector2i(7, 1)) == b, "occupation 2×2")
	_check(reg.building_at(Vector2i(5, 0)) == null, "tuile voisine libre")
	_check(not reg.check_placement(small, Vector2i(6, 1)).is_valid(), "tuile occupée")
	_check(not reg.check_placement(big, Vector2i(6, 2)).is_valid(), "chevauchement partiel")
	var forest_b := reg.place(on_forest)
	_check(map.get_terrain(Vector2i(6, 6)) == TerrainDef.Type.PLAIN, "défrichement à la construction")
	reg.remove(b)
	_check(reg.building_at(Vector2i(6, 0)) == null and reg.count() == 1, "démolition libère l'emprise")
	_check(reg.check_placement(small, Vector2i(6, 1)).is_valid(), "emplacement réutilisable")
	_check(reg.building_at(Vector2i(6, 6)) == forest_b, "autre bâtiment intact")


func _test_construction() -> void:
	var flat := _flat_map()
	var reg := BuildingRegistry.new(flat[0], flat[1])
	var quick := _def(Vector2i.ONE, 10)
	var slow := _def(Vector2i.ONE, 30)
	var a := reg.place(reg.check_placement(quick, Vector2i(1, 1)))
	var b := reg.place(reg.check_placement(slow, Vector2i(5, 5)))
	_check(not a.is_complete() and a.progress_ratio() == 0.0, "chantier au départ")
	_check(a.status == Building.Status.CONSTRUCTION, "statut chantier")
	var done := reg.advance(quick.build_hours - 1)
	_check(done.is_empty() and not a.is_complete(), "chantier presque fini")
	done = reg.advance(1)
	_check(done == [a] and a.is_complete(), "chantier terminé à build_hours")
	_check(a.status == Building.Status.RUNNING, "mis en service à la fin du chantier")
	_check(reg.advance(1).is_empty(), "terminé une seule fois")
	reg.advance(slow.build_hours)
	_check(b.is_complete() and b.build_progress == slow.build_hours, "progression plafonnée")


func _test_weather() -> void:
	var w := Weather.new(5)
	_check(is_equal_approx(w.wind_at(100), Weather.new(5).wind_at(100)), "météo reproductible")
	var differs := false
	for t in 48:
		differs = differs or not is_equal_approx(w.wind_at(t), Weather.new(6).wind_at(t))
	_check(differs, "météo propre à la graine")
	_check(Weather.daylight_at(2) == 0.0 and Weather.is_night(2), "nuit à 2 h")
	_check(Weather.daylight_at(13) > 0.95, "plein jour à 13 h")
	var summer := 0
	var winter := 0
	for h in 24:
		summer += 1 if Weather.daylight_at(GameDate.HOURS_PER_SEASON + h) > 0.0 else 0
		winter += 1 if Weather.daylight_at(3 * GameDate.HOURS_PER_SEASON + h) > 0.0 else 0
	_check(summer > winter, "jours plus longs en été (%d h) qu'en hiver (%d h)" % [summer, winter])
	var total := 0.0
	var in_range := true
	var smooth := true
	for t in GameDate.HOURS_PER_YEAR:
		var wind := w.wind_at(t)
		var cloud := w.cloud_at(t)
		total += wind
		in_range = in_range and wind > 0.0 and wind <= 1.4 and cloud >= 0.0 and cloud <= 1.0
		smooth = smooth and absf(w.wind_at(t + 1) - wind) < 0.4
	var mean := total / GameDate.HOURS_PER_YEAR
	_check(in_range, "vent et nuages dans leurs bornes")
	_check(smooth, "vent sans à-coups d'une heure à l'autre")
	_check(mean > 0.7 and mean < 1.05, "vent moyen proche de la normale (%.2f)" % mean)


func _test_zone_defs() -> void:
	var ids := {}
	for def in ZoneDb.DEFS:
		_check(not ids.has(def.id) and ZoneDb.get_def(def.id) == def, "zone %s unique" % def.id)
		ids[def.id] = true
		_check(def.workers_per_tile > 0 and not def.allowed_terrains.is_empty(), "zone %s : travailleurs et terrains" % def.id)
	var farm := ZoneDb.get_def(&"agriculture")
	_check(farm.workers_per_tile == 2 and TerrainDef.Type.PLAIN in farm.allowed_terrains and farm.on_banks,
		"agriculture : 2 par tuile, plaine et berges")
	_check(ZoneDb.get_def(&"forestry").allowed_terrains == [TerrainDef.Type.FOREST], "coupe du bois : forêt")
	_check(farm.describe_terrains() == "plaine, prairie, berges", "terrains lisibles (%s)" % farm.describe_terrains())


func _test_zones() -> void:
	var flat := _flat_map()
	var map: WorldMap = flat[0]
	var territory: Territory = flat[1]
	var reg := BuildingRegistry.new(map, territory)
	var zones := ZoneMap.new(map, territory, reg)
	var farm := ZoneDb.get_def(&"agriculture")
	var pasture := ZoneDb.get_def(&"pasture")
	var forestry := ZoneDb.get_def(&"forestry")

	_check(ZoneMap.rect_between(Vector2i(4, 1), Vector2i(2, 3)) == Rect2i(2, 1, 3, 3), "rectangle d'un glisser")
	var p := zones.plan(farm, Rect2i(0, 0, 3, 2))
	_check(p.cells.size() == 6 and p.changed.size() == 6 and p.refused == 0, "aperçu : 6 tuiles à peindre")
	_check(zones.apply(p).size() == 6 and zones.zone_at(Vector2i(2, 1)) == farm, "agriculture peinte")
	_check(zones.places(farm) == 12 and zones.tile_count(farm) == 6, "places : tuiles × travailleurs")
	_check(zones.plan(farm, Rect2i(0, 0, 3, 2)).changed.is_empty(), "rien à repeindre")

	p = zones.plan(forestry, Rect2i(0, 0, 1, 1))
	_check(p.changed.is_empty() and p.refused == 1 and p.error.begins_with("Terrain non valide"), "forêt seulement : %s" % p.error)
	map.set_terrain(Vector2i(5, 5), TerrainDef.Type.FOREST)
	_check(zones.apply(zones.plan(forestry, Rect2i(5, 5, 1, 1))).size() == 1, "coupe du bois sur une forêt")

	p = zones.plan(pasture, Rect2i(1, 1, 1, 1))
	_check(p.changed == [Vector2i(1, 1)], "une autre zone remplace l'ancienne")
	zones.apply(p)
	_check(zones.zone_at(Vector2i(1, 1)) == pasture and zones.tile_count(farm) == 5, "au plus une zone par tuile")

	p = zones.plan(farm, Rect2i(6, 0, 4, 1))
	_check(p.changed.size() == 2 and p.refused == 2 and p.error == "Hors du territoire", "hors du territoire ignoré")

	map.set_terrain(Vector2i(3, 6), TerrainDef.Type.DESERT)
	_check(not zones.check_cell(farm, Vector2i(3, 6)).is_empty(), "désert sec : pas d'agriculture")
	map.set_terrain(Vector2i(3, 7), TerrainDef.Type.RIVER)
	_check(zones.check_cell(farm, Vector2i(3, 6)).is_empty(), "berge du désert cultivable")
	_check(not zones.check_cell(pasture, Vector2i(3, 6)).is_empty(), "pas d'élevage au désert")

	var b := reg.place(reg.check_placement(_def(), Vector2i(7, 7)))
	_check(zones.check_cell(farm, Vector2i(7, 7)).begins_with("Bâtiment présent"), "pas de zone sous un bâtiment")
	reg.remove(b)

	# Abscisses dépliées : la même tuile vue d'un tour de planète plus loin.
	_check(zones.zone_at(Vector2i(2 + map.size.x, 1)) == farm, "zone retrouvée après un tour de planète")
	p = zones.plan(null, Rect2i(0, 0, 2, 2))
	_check(p.changed.size() == 4, "effacement : 4 tuiles zonées")
	zones.apply(p)
	_check(zones.zone_at(Vector2i(1, 1)) == null and zones.all_cells().size() == 3, "zones effacées, les autres intactes")


func _test_population() -> void:
	var pop := Population.new()
	_check(pop.count == 20 and pop.active() == 12, "hameau : 20 habitants, 12 actifs")
	pop.count = 25
	_check(pop.active() == 15, "60 % d'actifs")
	_check(is_equal_approx(pop.food_need(), 25.0), "1 nourriture par habitant et par jour")
	_check(is_equal_approx(pop.wood_need(0), 5.0) and is_equal_approx(pop.wood_need(GameDate.WINTER), 10.0) \
		and is_equal_approx(pop.wood_need(GameDate.SUMMER), 2.5),
		"bois : 0,2 par habitant, moitié en été, double en hiver")


## Zones et répartition sur une petite planète de plaine (territoire 8×8).
func _labor_setup() -> Array:
	var flat := _flat_map()
	var zones := ZoneMap.new(flat[0], flat[1], BuildingRegistry.new(flat[0], flat[1]))
	return [zones, Labor.new(zones, Vector2i(3, 3))]


func _paint(zones: ZoneMap, id: StringName, rect: Rect2i) -> void:
	zones.apply(zones.plan(ZoneDb.get_def(id), rect))


func _test_labor_targets() -> void:
	var setup := _labor_setup()
	var zones: ZoneMap = setup[0]
	var labor: Labor = setup[1]
	var farm := ZoneDb.get_def(&"agriculture")
	var pasture := ZoneDb.get_def(&"pasture")
	var forestry := ZoneDb.get_def(&"forestry")
	_check(labor.targets(12).values().all(func(n: int) -> bool: return n == 0), "aucune zone : aucune place")
	_paint(zones, &"agriculture", Rect2i(0, 0, 3, 1))  # 6 places
	_paint(zones, &"pasture", Rect2i(0, 1, 6, 1))  # 6 places
	var t := labor.targets(6)
	_check(t[farm] == 3 and t[pasture] == 3, "priorités égales : au prorata des places (%s)" % [t.values()])
	t = labor.targets(20)
	_check(t[farm] == 6 and t[pasture] == 6, "plafonné par les places, le reste au chômage")
	labor.priorities[farm] = 5
	labor.priorities[pasture] = 1
	t = labor.targets(6)
	_check(t[farm] == 5 and t[pasture] == 1, "priorité 5 contre 1 (%s)" % [t.values()])
	t = labor.targets(9)
	_check(t[farm] == 6 and t[pasture] == 3, "excédent redistribué quand une zone est pleine (%s)" % [t.values()])
	labor.priorities[pasture] = 0
	t = labor.targets(9)
	_check(t[farm] == 6 and t[pasture] == 0, "priorité 0 : personne")
	labor.priorities[farm] = Labor.AUTO
	labor.priorities[pasture] = Labor.AUTO
	for active in [1, 5, 7, 11]:
		t = labor.targets(active)
		_check(t[farm] + t[pasture] + t[forestry] == active, "%d actifs tous affectés (%s)" % [active, t.values()])


func _test_labor_step() -> void:
	var setup := _labor_setup()
	var zones: ZoneMap = setup[0]
	var labor: Labor = setup[1]
	var map := zones.map
	var farm := ZoneDb.get_def(&"agriculture")
	var pasture := ZoneDb.get_def(&"pasture")
	labor.step(0, 12)
	_check(labor.unemployed() == 12 and labor.employed() == 0, "sans zone : 12 chômeurs")
	# Deux tuiles d'agriculture : la plus fertile et la plus proche d'abord.
	var chunk := map._chunk(Vector2i(6, 6))
	chunk.fertility[map._local(Vector2i(6, 6))] = 0.9
	_paint(zones, &"agriculture", Rect2i(5, 6, 2, 1))
	labor.step(1, 2)
	_check(labor.assigned[farm] == 2 and labor.workers_at == {Vector2i(6, 6): 2},
		"les chômeurs vont tout de suite à la meilleure tuile (%s)" % [labor.workers_at])
	labor.step(2, 12)
	_check(labor.employed() == 4 and labor.unemployed() == 8, "places pleines, 8 chômeurs")

	_paint(zones, &"pasture", Rect2i(0, 0, 8, 1))
	labor.priorities[farm] = 0
	labor.step(10, 12)
	_check(labor.assigned[farm] == 0 and labor.in_transit() == 4 and labor.assigned[pasture] == 8,
		"retirés de l'agriculture : en route ; les chômeurs vont à l'élevage")
	labor.step(10 + Labor.REASSIGN_HOURS - 1, 12)
	_check(labor.in_transit() == 4, "toujours en route avant %d h" % Labor.REASSIGN_HOURS)
	labor.step(10 + Labor.REASSIGN_HOURS, 12)
	_check(labor.in_transit() == 0 and labor.unemployed() == 4, "arrivés : disponibles (pas de place)")

	zones.apply(zones.plan(null, Rect2i(0, 0, 4, 1)))
	labor.step(100, 12)
	_check(labor.assigned[pasture] == 4 and labor.in_transit() == 4, "zone effacée : travailleurs libérés")
	labor.step(200, 3)
	_check(labor.employed() + labor.in_transit() <= 3 and labor.unemployed() == 0, "moins d'actifs : effectifs réduits")

	_check(labor.distance(Vector2i(3 + 9, 3)) == 9 and labor.distance(Vector2i(63, 3)) == 4,
		"distance au village, longitude bouclée")
	_check(Labor.distance_factor(6) == 1.0 and is_equal_approx(Labor.distance_factor(10), 0.88),
		"−3 %% par tuile au-delà de 6")


func _test_stockpile() -> void:
	var stock := Stockpile.new()
	_check(stock.amount == Stockpile.START and stock.capacity == Stockpile.BASE_CAPACITY, "stocks de départ")
	stock.amount = Stockpile.zeros()
	stock.capacity = PackedFloat32Array([100.0, 50.0, 100.0, 100.0, 100.0, 100.0, 0.0, 100.0, 100.0, 100.0, 100.0])
	_check(is_equal_approx(stock.add(Stockpile.Good.WOOD, 70.0), 50.0) and is_equal_approx(stock.lost_today[1], 20.0),
		"au-delà de la capacité : perdu")
	_check(is_equal_approx(stock.take(Stockpile.Good.WOOD, 80.0), 50.0) and stock.amount[1] == 0.0, "on ne prend que le stock")
	stock.add(Stockpile.Good.FOOD, 100.0)
	_check(is_equal_approx(stock.days_of(Stockpile.Good.FOOD, 20.0), 5.0), "jours de réserve")
	stock.end_day()
	_check(is_equal_approx(stock.amount[0], 99.5), "gâchis : 1 %% de l'excédent au-delà de la moitié (%.2f)" % stock.amount[0])
	stock.take(Stockpile.Good.FOOD, 60.0)
	stock.end_day()
	_check(is_equal_approx(stock.amount[0], 39.5), "pas de gâchis sous la moitié")
	stock.amount[0] = 96.0
	stock.update_full()
	_check(stock.full[0], "plein à 95 %")
	stock.amount[0] = 80.0
	stock.update_full()
	_check(stock.full[0], "reste plein jusqu'à 75 % (hystérésis)")
	stock.amount[0] = 70.0
	stock.update_full()
	_check(not stock.full[0], "sous 75 % : de nouveau à remplir")
	_check(not stock.full[Stockpile.Good.OIL], "sans réservoir (capacité nulle) : pas plein")
	# Stockage : parc à pierre, entrepôt à outils, parcs à fer et à charbon, réservoir de pétrole.
	var stores := {&"stone_yard": [Stockpile.Good.STONE, 2], &"tool_store": [Stockpile.Good.TOOLS, 2], &"iron_yard": [Stockpile.Good.IRON, 2],
		&"coal_yard": [Stockpile.Good.COAL, 3], &"oil_tank": [Stockpile.Good.OIL, 4]}
	for id: StringName in stores:
		var def := BuildingDb.get_def(id)
		var good: int = stores[id][0]
		_check(def != null and def.capacity_of(good) > 0.0 and def.tier == stores[id][1]
			and def.category == BuildingDef.Category.STORAGE,
			"%s : stocke %s, palier %d" % [id, Stockpile.GOOD_NAMES[good].to_lower(), stores[id][1]])
	_check(Stockpile.BASE_CAPACITY[Stockpile.Good.OIL] == 0.0, "pétrole : réservoir nécessaire")


func _test_research() -> void:
	var irrigation := ResearchDb.get_def(&"irrigation")
	_check(irrigation != null and irrigation.tier == 1 and irrigation.prerequisites.is_empty(), "irrigation : recherche du hameau")
	_check(is_equal_approx(Research.points_per_day(20, 1.0), 20.0) and is_equal_approx(Research.points_per_day(20, 0.0), 10.0),
		"points : 1 par habitant, moitié à satisfaction nulle")
	var research := Research.new()
	var later := ResearchDef.new()
	later.id = &"later"
	later.tier = 2
	later.cost = 50.0
	later.prerequisites = [&"irrigation"] as Array[StringName]
	_check(research.is_available(irrigation, 1) and not research.is_available(later, 1), "palier et prérequis")
	_check(research.add_points(120.0) == null and is_equal_approx(research.bank, 120.0), "sans recherche : points mis de côté")
	_check(research.start(irrigation, 1) and is_equal_approx(research.progress_of(irrigation), 120.0) and research.bank == 0.0,
		"points mis de côté versés à la recherche lancée")
	_check(is_equal_approx(research.days_left(20.0), (irrigation.cost - 120.0) / 20.0), "jours restants")
	_check(research.add_points(irrigation.cost - 130.0) == null and research.current == irrigation, "pas encore terminée")
	var finished := research.add_points(30.0)
	_check(finished == irrigation and research.is_done(&"irrigation") and research.current == null
		and is_equal_approx(research.bank, 20.0), "terminée, surplus mis de côté")
	_check(not research.start(irrigation, 1) and not research.is_available(later, 1) and research.is_available(later, 2),
		"pas deux fois ; la suivante attend son palier")
	for d in 30:
		research.add_points(50.0)
	_check(is_equal_approx(research.bank, 50.0 * Research.MAX_BANK_DAYS),
		"points mis de côté plafonnés à %d jours" % roundi(Research.MAX_BANK_DAYS))


func _test_village() -> void:
	# Zones du village : carrière (pierre) et pêche (nourriture), palier 2.
	var quarry := ZoneDb.get_def(&"quarry")
	var fishing := ZoneDb.get_def(&"fishing")
	_check(quarry.tier == 2 and quarry.output == Stockpile.Good.STONE and TerrainDef.Type.HILL in quarry.allowed_terrains,
		"carrière : pierre sur les collines, au village")
	_check(fishing.tier == 2 and fishing.output == Stockpile.Good.FOOD and TerrainDef.Type.SEA in fishing.allowed_terrains
		and fishing.season_factors[GameDate.WINTER] > 0.0, "pêche : nourriture toute l'année, au village")
	var flat := _flat_map()
	var map: WorldMap = flat[0]
	map.set_terrain(Vector2i(2, 2), TerrainDef.Type.HILL)
	map.set_terrain(Vector2i(3, 2), TerrainDef.Type.LAKE)
	_check(quarry.terrain_error(map, Vector2i(2, 2)).is_empty() and not quarry.terrain_error(map, Vector2i(1, 1)).is_empty(),
		"carrière : colline oui, plaine non")
	_check(fishing.terrain_error(map, Vector2i(3, 2)).is_empty() and is_equal_approx(fishing.quality_at(map, Vector2i(3, 2)), 1.0),
		"pêche sur un lac, qualité uniforme")
	# Bâtiments du village.
	var well := BuildingDb.get_def(&"well")
	var stone_house := BuildingDb.get_def(&"stone_house")
	var workshop := BuildingDb.get_def(&"workshop")
	_check(well.tier == 2 and well.water_supply > 0 and well.stone_cost > 0, "puits : eau, en pierre, au village")
	_check(stone_house.housing > BuildingDb.get_def(&"house").housing and stone_house.describe_cost() == "10 bois, 20 pierre",
		"maison en pierre : plus grande (%s)" % stone_house.describe_cost())
	_check(workshop.research_multiplier == 2.0 and workshop.research_coverage == 100, "atelier : recherche ×2 pour 100 habitants")
	_check(BuildingDb.get_def(&"granary").describe_cost().ends_with("bois"), "coût en bois seul")
	# Atelier : les habitants couverts comptent double, les meilleurs bâtiments d'abord.
	var boosts: Array[Vector2] = [Vector2(2.0, 100.0)]
	_check(is_equal_approx(Research.points_per_day(150, 1.0, boosts), 250.0), "150 habitants, un atelier : 100 × 2 + 50")
	boosts.append(Vector2(5.0, 40.0))
	_check(is_equal_approx(Research.points_per_day(150, 1.0, boosts), 40.0 * 5 + 100.0 * 2 + 10.0), "le meilleur multiplicateur d'abord")
	# Eau : satisfaction réduite et croissance bloquée sans puits.
	var pop := Population.new()
	pop.end_day(1.0, 1.0, 100, 0.0)
	_check(is_equal_approx(pop.satisfaction, 1.0 - Population.WATER_WEIGHT), "sans eau : satisfaction −30 %%")
	var before := pop.count
	for k in 30:
		pop.end_day(1.0, 1.0, 100, 0.5)
	_check(pop.count == before, "eau insuffisante : pas de croissance")
	# Expéditions : plus nombreuses et plus longues au village.
	var exploration := Exploration.new(flat[1])
	_check(exploration.max_expeditions() == 1 and exploration.max_days() == 20, "hameau : 1 expédition, 20 jours")
	exploration.tier = 2
	_check(exploration.max_expeditions() == 3 and exploration.max_days() == 40, "village : 3 expéditions, 40 jours")


func _test_draft_animals() -> void:
	var stable := BuildingDb.get_def(&"stable")
	_check(stable.tier == 2 and stable.horse_capacity == 6 and stable.stone_cost > 0, "écurie : 6 chevaux, au village")
	var draft := DraftAnimals.new()
	_check(is_zero_approx(draft.breed(10.0)), "sans écurie : pas de poulain")
	draft.capacity = 6
	var foals := draft.breed(10.0)
	_check(is_equal_approx(draft.horses, 0.1) and is_equal_approx(foals, 0.1), "10 pâturages : un poulain tous les 10 jours")
	for k in 100:
		draft.breed(10.0)
	_check(is_equal_approx(draft.horses, 6.0) and draft.count() == 6, "écurie pleine : 6 chevaux au plus")
	_check(is_equal_approx(draft.fodder_need(), 18.0), "fourrage : 3 par cheval")
	draft.end_day(0.0)
	_check(draft.count() == 5 and draft.horses > 5.6, "sans fourrage : 5 %% perdus (%.2f)" % draft.horses)
	draft.horses = 2.0
	var workers: Dictionary[Vector2i, int] = {Vector2i(3, 0): 1, Vector2i(10, 0): 1, Vector2i(20, 0): 1, Vector2i(15, 0): 2}
	draft.harness(workers, func(c: Vector2i) -> int: return c.x)
	_check(draft.working() == 2 and draft.harnessed.has(Vector2i(20, 0)) and draft.harnessed.has(Vector2i(15, 0)),
		"attelés aux tuiles les plus lointaines")
	draft.away = 1
	draft.harness(workers, func(c: Vector2i) -> int: return c.x)
	_check(draft.working() == 1 and draft.harnessed.has(Vector2i(20, 0)), "cheval parti en expédition : un attelage de moins")
	draft.horses = 6.0
	draft.harness(workers, func(c: Vector2i) -> int: return c.x)
	_check(not draft.harnessed.has(Vector2i(3, 0)), "pas d'attelage sans trajet à raccourcir")
	_check(DraftAnimals.draft_distance_factor(12) == 1.0 and is_equal_approx(DraftAnimals.draft_distance_factor(20), 0.88)
		and DraftAnimals.draft_distance_factor(20) > Labor.distance_factor(20), "attelage : pénalité à partir de 12 tuiles, moitié moindre")
	# Production d'une tuile lointaine attelée.
	var setup := _labor_setup()
	var prod := Production.new(setup[0], setup[1])
	var farm := ZoneDb.get_def(&"agriculture")
	var far := Vector2i(3 + 14, 3)
	var plain := prod.tile_rate(farm, far, 2, 1)
	prod.draft = DraftAnimals.new()
	prod.draft.harnessed[far] = true
	_check(is_equal_approx(prod.tile_rate(farm, far, 2, 1), plain / Labor.distance_factor(14) * DraftAnimals.draft_distance_factor(14)),
		"tuile attelée : plus productive")


func _test_inventions() -> void:
	# Arbre du village.
	var tier2 := ResearchDb.DEFS.filter(func(d: ResearchDef) -> bool: return d.tier == 2)
	_check(tier2.size() == 8, "8 inventions au village (%d)" % tier2.size())
	var pump_pre: Array[StringName] = [&"gears"]
	_check(ResearchDb.get_def(&"water_pump").prerequisites == pump_pre, "pompe à eau après l'engrenage")
	var plough_pre: Array[StringName] = [&"harness_collar", &"tools"]
	var rotation_pre: Array[StringName] = [&"plough"]
	var windmill_pre: Array[StringName] = [&"gears"]
	_check(ResearchDb.get_def(&"plough").prerequisites == plough_pre
		and ResearchDb.get_def(&"crop_rotation").prerequisites == rotation_pre
		and ResearchDb.get_def(&"windmill").prerequisites == windmill_pre, "prérequis : charrue, assolement, moulin")
	var ok := true
	for def in ResearchDb.DEFS:
		for id in def.prerequisites:
			ok = ok and ResearchDb.get_def(id) != null and ResearchDb.get_def(id).tier <= def.tier
	_check(ok, "prérequis existants et pas d'un palier plus haut")
	_check(BuildingDb.get_def(&"forge").research == &"iron_metallurgy" and BuildingDb.get_def(&"windmill").research == &"windmill",
		"forge et moulin réservés à leur recherche")
	# Effets sur la production.
	var setup := _labor_setup()
	var prod := Production.new(setup[0], setup[1])
	prod.research = Research.new()
	var farm := ZoneDb.get_def(&"agriculture")
	var forestry := ZoneDb.get_def(&"forestry")
	var quarry := ZoneDb.get_def(&"quarry")
	var cell := Vector2i(3, 3)
	_check(prod.invention_factor(farm, cell) == 1.0 and prod.invention_factor(forestry, cell) == 1.0, "sans invention : pas de bonus")
	for id in [&"tools", &"plough", &"crop_rotation", &"gears"]:
		prod.research._done[id] = true
	_check(is_equal_approx(prod.invention_factor(forestry, cell), Production.SAW_BONUS), "scie : bois +40 %%")
	_check(is_equal_approx(prod.invention_factor(farm, cell), Production.PLOUGH_BONUS * Production.ROTATION_BONUS),
		"charrue sans attelage +10 %%, assolement +15 %%")
	prod.draft = DraftAnimals.new()
	prod.draft.harnessed[cell] = true
	prod.mill_bonus = BuildingDb.get_def(&"windmill").grain_bonus
	_check(is_equal_approx(prod.invention_factor(farm, cell), Production.PLOUGH_HARNESSED_BONUS * Production.ROTATION_BONUS * 1.2),
		"charrue attelée +30 %%, moulin +20 %%")
	_check(is_equal_approx(prod.invention_factor(quarry, cell), Production.GEARS_BONUS), "engrenage : carrière +15 %%")
	prod.tools_ok = false
	_check(is_equal_approx(prod.invention_factor(forestry, cell), 1.0)
		and is_equal_approx(prod.invention_factor(farm, cell), Production.ROTATION_BONUS * 1.2),
		"sans outils en stock : ni scie ni charrue")
	# Collier : charge et portée +50 %.
	var draft := DraftAnimals.new()
	_check(draft.free_distance() == 12 and is_equal_approx(draft.pack_factor(), 4.0), "attelage sans collier")
	draft.collar = true
	_check(draft.free_distance() == 18 and is_equal_approx(draft.pack_factor(), 6.0), "collier : portée 18 tuiles, bât ×6")
	# Outils : satisfaction réduite sans eux.
	var pop := Population.new()
	pop.end_day(1.0, 1.0, 100, 1.0, 0.0)
	_check(is_equal_approx(pop.satisfaction, 1.0 - Population.TOOLS_WEIGHT), "sans outils : satisfaction −15 %%")
	# Mine de fer : gisement prospecté, épuisement.
	var flat := _flat_map()
	var map: WorldMap = flat[0]
	var territory: Territory = flat[1]
	var zones := ZoneMap.new(map, territory, BuildingRegistry.new(map, territory))
	var mine := ZoneDb.get_def(&"iron_mine")
	var ore := Vector2i(2, 2)
	map._chunk(ore).deposit[map._local(ore)] = WorldMap.Deposit.IRON
	map._chunk(ore).deposit_amount[map._local(ore)] = 1.0
	territory.prospect([ore] as Array[Vector2i])
	_check(not zones.check_cell(mine, ore).is_empty(), "fer caché au hameau : pas de mine")
	territory.tier = 2
	_check(zones.check_cell(mine, ore).is_empty() and not zones.check_cell(mine, Vector2i(3, 3)).is_empty(),
		"mine sur un gisement de fer prospecté seulement")
	_check(Territory.DEPOSIT_TIER[WorldMap.Deposit.COAL] == 3 and territory.known_deposit(ore) == WorldMap.Deposit.IRON,
		"le charbon attend le bourg")
	map.set_deposit_amount(ore, 0.0)
	_check(map.get_deposit(ore) == WorldMap.Deposit.NONE, "gisement épuisé")
	_test_stone_deposit()


func _test_granary_upgrades() -> void:
	# Un niveau de grenier par palier, capacité croissante.
	var def := BuildingDb.get_def(&"granary")
	var tiers: Array[int] = []
	var last := 0.0
	var growing := true
	while def:
		tiers.append(def.tier)
		growing = growing and def.food_capacity > last
		last = def.food_capacity
		def = def.upgrade
	var expected: Array[int] = [1, 2, 3, 4, 5]
	_check(tiers == expected and growing, "grenier : un niveau par palier, plus grand à chaque fois %s" % [tiers])
	# Maisons : un niveau par palier, plus de logements à chaque fois.
	var house := BuildingDb.get_def(&"house")
	var house_tiers: Array[int] = []
	var housing := 0
	var more := true
	while house:
		house_tiers.append(house.tier)
		more = more and house.housing > housing and house.size == Vector2i.ONE
		housing = house.housing
		house = house.upgrade
	_check(house_tiers == expected and more, "maison : un niveau par palier, plus de logements %s" % [house_tiers])
	var camp := BuildingDb.get_def(&"woodshed")
	_check(camp.display_name == "Camp d'abattage" and camp.upgrade.id == &"sawmill" and camp.upgrade.tier == 2
		and camp.upgrade.wood_capacity > camp.wood_capacity, "camp d'abattage → scierie au village")
	var setup := _labor_setup()
	var prod := Production.new(setup[0], setup[1])
	var forestry := ZoneDb.get_def(&"forestry")
	prod.sawmill_bonus = camp.upgrade.forestry_bonus
	_check(is_equal_approx(prod.invention_factor(forestry, Vector2i(3, 3)), 1.2), "scierie : coupe du bois +20 %%")
	_check(not BuildingDb.get_def(&"stone_house").player_buildable and not BuildingDb.get_def(&"town_house").player_buildable,
		"niveaux de maison : seule la maison figure au menu, construite au niveau du palier")
	_check(not BuildingDb.get_def(&"stone_granary").player_buildable and BuildingDb.get_def(&"large_granary").iron_cost > 0,
		"niveaux supérieurs : par amélioration seulement, en fer au bourg")
	# Amélioration sur place : l'ancien niveau reste en service pendant les travaux.
	var granary := BuildingDb.get_def(&"granary")
	var b := Building.new(1, granary, Vector2i(5, 5))
	b.build_progress = granary.build_hours
	var cells := b.cells.duplicate()
	b.start_upgrade(granary.upgrade)
	_check(b.def.id == &"stone_granary" and not b.is_complete() and b.effective_def() == granary and b.cells == cells,
		"chantier d'amélioration : grenier encore en service, même emprise")
	b.build_progress = b.def.build_hours
	_check(b.effective_def().food_capacity == 1200.0, "grenier en pierre terminé : 1 200")
	var fresh := Building.new(2, granary, Vector2i(9, 9))
	_check(fresh.effective_def() == null, "chantier neuf : rien en service")


func _test_city_tier() -> void:
	var tier := CityTier.new()
	_check(tier.level == 1 and tier.name() == "Hameau" and tier.next_population() == 100, "départ : hameau, village à 100")
	_check(not tier.update(99, 1.0), "99 habitants : toujours hameau")
	_check(not tier.update(120, 0.5), "satisfaction trop basse : pas de palier")
	_check(tier.update(120, 0.9) and tier.name() == "Village", "100 habitants satisfaits : village")
	tier.update(10, 0.0)
	_check(tier.level == 2, "le palier ne redescend pas")
	tier.update(9999, 1.0)
	_check(tier.is_max() and tier.name() == "Cité-État" and tier.next_population() == -1, "dernier palier : cité-État")


func _test_population_growth() -> void:
	var pop := Population.new()
	var grown := 0
	for day in 60:
		grown += pop.end_day(1.0, 1.0, 100)
	_check(grown > 3 and pop.count == 20 + grown and pop.satisfaction == 1.0,
		"besoins couverts : croissance (+%d en 60 j)" % grown)
	pop.count = 20
	for day in 30:
		pop.end_day(1.0, 1.0, 20)
	_check(pop.count == 20, "pas de croissance sans logement libre")
	pop.end_day(1.0, 1.0, 10)
	_check(pop.count < 20, "sans logement : départs (%d)" % pop.count)
	pop = Population.new()
	pop.count = 100
	for day in 5:
		pop.end_day(0.0, 1.0, 200)
	_check(pop.count < 80 and pop.satisfaction < 0.5, "famine : déclin rapide (%d, satisfaction %d %%)" % [
		pop.count, roundi(pop.satisfaction * 100)])
	pop = Population.new()
	pop.end_day(1.0, 0.0, 100)
	_check(is_equal_approx(pop.satisfaction, Population.FOOD_WEIGHT), "satisfaction : nourriture pondérée")


func _test_production() -> void:
	var setup := _labor_setup()
	var zones: ZoneMap = setup[0]
	var labor: Labor = setup[1]
	var prod := Production.new(zones, labor)
	var farm := ZoneDb.get_def(&"agriculture")
	var cell := Vector2i(3, 3)
	var rate := prod.tile_rate(farm, cell, 2, 1)
	_check(is_equal_approx(rate, 2 * farm.base_yield * 0.7), "rendement = travailleurs × base × qualité (%.2f)" % rate)
	_check(is_equal_approx(prod.tile_rate(farm, cell, 2, 0), rate) and prod.tile_rate(farm, cell, 2, GameDate.WINTER) == 0.0,
		"champs : récolte au printemps, rien en hiver")
	_check(is_equal_approx(prod.tile_rate(farm, Vector2i(3 + 10, 3), 2, 1), rate * Labor.distance_factor(10)),
		"pénalité de distance")
	_paint(zones, &"agriculture", Rect2i(2, 2, 2, 1))
	_paint(zones, &"pasture", Rect2i(2, 4, 2, 1))
	labor.step(0, 6)
	var stock := Stockpile.new()
	stock.amount = Stockpile.zeros()
	var summer := GameDate.HOURS_PER_SEASON
	for h in 24:
		prod.step_hour(summer + h, stock)
	var expected := prod.expected_per_day(farm, 1) + prod.expected_per_day(ZoneDb.get_def(&"pasture"), 1)
	_check(is_equal_approx(stock.amount[0], expected) and is_equal_approx(prod.produced_today[0], expected),
		"une journée d'été : production prévue au grenier (%.1f)" % stock.amount[0])
	var before := zones.map.get_fertility(Vector2i(2, 2))
	prod.end_day(summer)
	_check(zones.map.get_fertility(Vector2i(2, 2)) < before, "un champ cultivé perd en fertilité")
	labor.priorities[farm] = 0
	labor.step(1000, 6)
	for d in 10:
		prod.end_day(summer)
	_check(is_equal_approx(zones.map.get_fertility(Vector2i(2, 2)), before), "au repos, la fertilité revient")


func _test_irrigation() -> void:
	var setup := _labor_setup()
	var zones: ZoneMap = setup[0]
	var labor: Labor = setup[1]
	var prod := Production.new(zones, labor)
	var farm := ZoneDb.get_def(&"agriculture")
	var pasture := ZoneDb.get_def(&"pasture")
	var near := Vector2i(3, 3)
	var far := Vector2i(20, 3)
	zones.map.set_terrain(Vector2i(6, 3), TerrainDef.Type.RIVER)
	var before := prod.tile_rate(farm, near, 2, 1)
	prod.research = Research.new()
	_check(is_equal_approx(prod.tile_rate(farm, near, 2, 1), before), "sans la recherche : pas de bonus")
	prod.research._done[&"irrigation"] = true
	_check(is_equal_approx(prod.tile_rate(farm, near, 2, 1), before * Production.IRRIGATION_BONUS), "champ à 3 tuiles d'une rivière : +30 %")
	_check(prod.irrigation_factor(farm, far) == 1.0, "champ loin de l'eau : pas de bonus")
	_check(prod.irrigation_factor(pasture, near) == 1.0, "élevage : pas concerné")
	prod.wells = [Vector2i(22, 4)] as Array[Vector2i]
	_check(prod.irrigation_factor(farm, far) == Production.IRRIGATION_BONUS, "puits à 2 tuiles : champ irrigué")
	_check(prod.irrigation_factor(farm, Vector2i(30, 3)) == 1.0, "puits à 8 tuiles : non")


func _test_forest_cycle() -> void:
	var setup := _labor_setup()
	var zones: ZoneMap = setup[0]
	var labor: Labor = setup[1]
	var map := zones.map
	var prod := Production.new(zones, labor)
	var cell := Vector2i(4, 4)
	map.set_terrain(cell, TerrainDef.Type.FOREST)
	map.set_wood(cell, 10.0)
	_paint(zones, &"forestry", Rect2i(cell, Vector2i.ONE))
	labor.step(0, 1)
	var stock := Stockpile.new()
	var wood_before := stock.amount[1]
	var clearcut: Array[Vector2i] = []
	var forestry := ZoneDb.get_def(&"forestry")
	for h in 24 * 30:
		clearcut.append_array(prod.step_hour(h, stock).clearcut)
		if not clearcut.is_empty():
			break
	_check(clearcut == [cell] and map.get_terrain(cell) == TerrainDef.Type.PLAIN and zones.zone_at(cell) == forestry,
		"coupe à blanc : plaine, zone gardée")
	_check(absf(stock.amount[1] - wood_before - 10.0) < 0.01, "tout le bois de la tuile récolté (%.3f)" % (stock.amount[1] - wood_before))
	labor.step(24 * 30, 1)
	_check(zones.places(forestry) == 0 and not labor.workers_at.has(cell), "coupe à blanc : plus de place de travail")
	var regrown: Array[Vector2i] = []
	for d in Production.CLEARCUT_REGROW_DAYS:
		regrown.append_array(prod.end_day(0))
	_check(regrown == [cell] and map.get_terrain(cell) == TerrainDef.Type.FOREST and map.get_wood(cell) > 0.0,
		"repousse après %d jours sous la zone de coupe" % Production.CLEARCUT_REGROW_DAYS)
	_check(zones.places(forestry) == forestry.workers_per_tile, "forêt revenue : la zone produit de nouveau")
	_test_sylviculture(prod, map, cell)
	var wood := map.get_wood(cell)
	prod.end_day(0)
	_check(map.get_wood(cell) > wood, "une jeune forêt se densifie")


func _test_auto_priorities() -> void:
	var labor: Labor = _labor_setup()[1]
	var farm := ZoneDb.get_def(&"agriculture")
	var pasture := ZoneDb.get_def(&"pasture")
	var forestry := ZoneDb.get_def(&"forestry")
	labor.update_auto([false, false], 1)
	_check(labor.effective_priority(farm) == Labor.AUTO_PRIORITY, "stocks suffisants : priorité normale")
	labor.update_auto([true, false], 1)
	_check(labor.effective_priority(farm) == Labor.HIGH_PRIORITY and labor.effective_priority(pasture) == Labor.HIGH_PRIORITY
		and labor.effective_priority(forestry) == Labor.AUTO_PRIORITY, "nourriture qui manque : champs et élevage d'abord")
	labor.update_auto([true, true], GameDate.WINTER)
	_check(labor.effective_priority(farm) == 0 and labor.effective_priority(forestry) == Labor.HIGH_PRIORITY,
		"hiver : personne aux champs, bois en priorité")
	labor.update_auto([false, false], 1, [true, false])
	_check(labor.effective_priority(farm) == 0 and labor.effective_priority(pasture) == 0
		and labor.effective_priority(forestry) == Labor.AUTO_PRIORITY, "grenier plein : personne aux zones nourricières")
	labor.update_auto([true, false], 1, [true, false])
	_check(labor.effective_priority(farm) == Labor.HIGH_PRIORITY, "stock plein mais qui manque : priorité haute gardée")
	labor.priorities[farm] = 4
	_check(labor.effective_priority(farm) == 4, "priorité manuelle conservée")


func _test_power_meter() -> void:
	var meter := PowerMeter.new()
	_check(meter.average() == 0.0, "aucun jour : 0 W")
	meter.push_day(PackedFloat32Array([1.0, 0.2]))
	_check(absf(meter.average(Stockpile.Good.FOOD) - 121.5) < 0.1 and absf(meter.average(Stockpile.Good.WOOD) - 347.2) < 0.1,
		"1 nourriture/j ≈ 120 W, 0,2 bois/j ≈ 350 W")
	for d in PowerMeter.WINDOW_DAYS:
		meter.push_day(PackedFloat32Array([0.0, 0.0]))
	_check(meter.average() == 0.0, "moyenne glissante sur %d jours" % PowerMeter.WINDOW_DAYS)
	meter.push_day(PackedFloat32Array([20.0, 4.0]))
	_check(is_equal_approx(meter.per_capita(20), meter.average() / 20.0), "par habitant")
	_check(PowerMeter.format(850.0) == "850 W" and PowerMeter.format(12_340.0) == "12,3 kW", "format")


func _test_statistics() -> void:
	var stats := Statistics.new()
	stats.series[&"test"] = PackedFloat32Array()
	_check(stats.last(&"test") == 0.0, "série vide : 0")
	stats.add(&"test", 2.0)
	stats.add(&"population", 10.0)
	stats.end_hour()
	stats.add(&"test", 3.0)
	stats.add(&"population", 20.0)
	stats.end_hour()
	stats.end_day()
	stats.end_day()
	_check(stats.days == 2 and stats.values(&"test") == PackedFloat32Array([5.0, 0.0]),
		"une valeur par jour clos (somme des heures)")
	_check(stats.values(&"population")[0] == 15.0, "série moyennée : moyenne horaire")
	_check(stats.total(&"test") == 5.0, "total d'une série")


func _test_milestones() -> void:
	var milestones := Milestones.new()
	milestones.defs.append(Milestones.Def.new(&"built", "Bâtisseur", "Construire un bâtiment.",
		func(f: Milestones.Facts) -> bool: return not f.buildings.is_empty()))
	var facts := Milestones.Facts.new()
	facts.stats = Statistics.new()
	_check(milestones.check(facts, 0).is_empty(), "jalon non atteint")
	facts.buildings = [Building.new(1, _def(), Vector2i.ZERO)]
	var reached := milestones.check(facts, 3)
	_check(reached.size() == 1 and milestones.reached[&"built"] == 3, "jalon atteint le jour 3")
	_check(milestones.check(facts, 4).is_empty(), "jalon atteint une seule fois")
	# Jalons de la partie.
	var standard := Milestones.new()
	standard.defs = Milestones.standard()
	var ids := standard.defs.map(func(d: Milestones.Def) -> StringName: return d.id)
	_check(ids.size() == 21 and &"village" in ids and &"bourg" in ids and &"clothes" in ids, "jalons de la partie : %d" % ids.size())
	var day_facts := Milestones.Facts.new()
	day_facts.stats = Statistics.new()
	day_facts.research = Research.new()
	day_facts.population = Population.START
	day_facts.territory = 144
	_check(standard.check(day_facts, 10).is_empty(), "départ : aucun jalon")
	day_facts.day = GameDate.DAYS_PER_SEASON * GameDate.SEASONS_PER_YEAR - 1
	day_facts.tier = 2
	var got := standard.check(day_facts, day_facts.day).map(func(d: Milestones.Def) -> StringName: return d.id)
	_check(got == [&"first_winter", &"village"], "premier hiver passé et village %s" % [got])
	day_facts.buildings = [Building.new(2, BuildingDb.get_def(&"well"), Vector2i.ZERO)]
	day_facts.buildings[0].build_progress = BuildingDb.get_def(&"well").build_hours
	day_facts.buildings[0].status = Building.Status.RUNNING
	_check(standard.check(day_facts, 200).map(func(d: Milestones.Def) -> StringName: return d.id) == [&"water"],
		"eau pour tous : un puits et tous servis")


func _test_bourg() -> void:
	# Zones du bourg : lin (fibres) et mine de charbon.
	var flax := ZoneDb.get_def(&"flax")
	var coal_mine := ZoneDb.get_def(&"coal_mine")
	_check(flax.tier == 3 and flax.output == Stockpile.Good.FIBER and flax.quality == ZoneDef.Quality.FERTILITY
		and flax.season_factors[GameDate.WINTER] == 0.0, "lin : fibres des champs, au bourg, rien en hiver")
	_check(coal_mine.tier == 3 and coal_mine.output == Stockpile.Good.COAL and coal_mine.deposit == WorldMap.Deposit.COAL,
		"mine de charbon : sur un gisement de charbon, au bourg")
	_check(Stockpile.GOOD_NAMES.size() == Stockpile.COUNT and Stockpile.ENERGY_MJ.size() == Stockpile.COUNT
		and Stockpile.BASE_CAPACITY.size() == Stockpile.COUNT and Stockpile.START.size() == Stockpile.COUNT
		and Stockpile.GOOD_AGREEMENT.size() == Stockpile.COUNT and Statistics.STOCK_KEYS.size() == Stockpile.COUNT
		and Statistics.PRODUCED_KEYS.size() == Stockpile.COUNT, "tables des marchandises complètes")
	# Bâtiments du bourg.
	var weaver := BuildingDb.get_def(&"weaver")
	var lab := BuildingDb.get_def(&"laboratory")
	var water_mill := BuildingDb.get_def(&"water_mill")
	_check(weaver.tier == 3 and weaver.clothes_per_day > 0.0 and weaver.research.is_empty(), "atelier de tissage : au bourg")
	_check(lab.research == &"scientific_method" and lab.research_multiplier == 5.0 and lab.research_coverage == 400
		and lab.costs()[Stockpile.Good.TOOLS] > 0.0, "laboratoire : recherche ×5 pour 400, demande des outils")
	_check(lab.describe_cost().contains("outils"), "coût en outils affiché (%s)" % lab.describe_cost())
	_check(water_mill.research == &"water_mill" and water_mill.grinds_grain and not water_mill.wind_powered
		and water_mill.grain_bonus > BuildingDb.get_def(&"windmill").grain_bonus and water_mill.drive_bonus > 0.0
		and TerrainDef.Type.RIVER in water_mill.adjacent_terrains, "moulin à eau : au bord d'une rivière, moud mieux, entraîne")
	var mill_pre: Array[StringName] = [&"windmill"]
	var coke_pre: Array[StringName] = [&"iron_metallurgy"]
	_check(ResearchDb.get_def(&"water_mill").prerequisites == mill_pre
		and ResearchDb.get_def(&"coke").prerequisites == coke_pre, "prérequis du bourg")
	# Moulins : le meilleur compte, sur les céréales seulement ; le moulin à eau entraîne la coupe du bois.
	var setup := _labor_setup()
	var prod := Production.new(setup[0], setup[1])
	var cell := Vector2i(3, 3)
	prod.mill_bonus = 0.3
	prod.drive_bonus = 0.2
	_check(is_equal_approx(prod.invention_factor(ZoneDb.get_def(&"agriculture"), cell), 1.3)
		and is_equal_approx(prod.invention_factor(flax, cell), 1.0), "moulin : céréales, pas le lin")
	_check(is_equal_approx(prod.invention_factor(ZoneDb.get_def(&"forestry"), cell), 1.2), "moulin à eau : coupe du bois +20 %%")
	# Vêtements : satisfaction réduite sans eux.
	var pop := Population.new()
	_check(is_equal_approx(pop.clothes_need(), Population.START / Population.CLOTHES_LIFE_DAYS), "un vêtement tous les 100 jours")
	pop.end_day(1.0, 1.0, 100, 1.0, 1.0, 0.0)
	_check(is_equal_approx(pop.satisfaction, 1.0 - Population.CLOTHES_WEIGHT), "sans vêtements : satisfaction −15 %%")



## Partie : chauffage au charbon, tissage, coke, filon de charbon près du village.
func _test_bourg_game() -> void:
	var weaver := BuildingDb.get_def(&"weaver")
	var gs: Node = root.get_node("GameState")
	gs.new_game(4242)
	# Greniers construits au niveau du palier, coût des améliorations ajouté.
	var granary := BuildingDb.get_def(&"granary")
	_check(gs.build_level(granary) == granary and gs.build_costs(granary) == granary.costs(), "hameau : grenier")
	gs.tier.level = 3
	var costs: PackedFloat32Array = gs.build_costs(granary)
	_check(gs.build_level(granary).id == &"large_granary" and costs[Stockpile.Good.WOOD] == 90.0
		and costs[Stockpile.Good.STONE] == 70.0 and costs[Stockpile.Good.IRON] == 10.0,
		"bourg : grand grenier (90 bois, 70 pierre, 10 fer)")
	var house := BuildingDb.get_def(&"house")
	var house_costs: PackedFloat32Array = gs.build_costs(house)
	_check(gs.build_level(house).id == &"town_house" and house_costs[Stockpile.Good.WOOD] == 45.0
		and house_costs[Stockpile.Good.STONE] == 50.0 and house_costs[Stockpile.Good.IRON] == 5.0,
		"bourg : maison bourgeoise directe (45 bois, 50 pierre, 5 fer)")
	var camp := BuildingDb.get_def(&"woodshed")
	var camp_costs: PackedFloat32Array = gs.build_costs(camp)
	_check(gs.build_level(camp).id == &"sawmill" and camp_costs[Stockpile.Good.WOOD] == 40.0
		and camp_costs[Stockpile.Good.STONE] == 15.0, "bourg : scierie directe (40 bois, 15 pierre)")
	_check(not BuildingDb.get_def(&"stone_house").player_buildable, "maison en pierre : plus de doublon au menu")
	for good in Stockpile.COUNT:
		gs.stockpile.amount[good] = 0.0
	var placement: BuildingRegistry.Placement
	for dx in range(-5, 6):
		placement = gs.check_placement(granary, gs.display_cell(gs.home) + Vector2i(dx, 3))
		if placement.error.contains("insuffisant"):
			break
	_check(placement.def.id == &"large_granary" and placement.error.contains("insuffisant"), "placement au niveau du palier, matériaux vérifiés (%s)" % placement.error)
	gs.tier.level = 1
	var site := StartSite.territory_rect(gs.home)
	var coal_cells := 0
	for y in range(site.position.y, site.end.y):
		for x in range(site.position.x, site.end.x):
			if gs.world_map.get_deposit(Vector2i(x, y)) == WorldMap.Deposit.COAL:
				coal_cells += 1
	_check(coal_cells >= StartSite.MIN_COAL, "filon de charbon près du village (%d tuiles)" % coal_cells)
	var stock: Stockpile = gs.stockpile
	var season := GameDate.WINTER
	_check(gs.coal_heat_need(season) == 0.0 and gs.clothes_need() == 0.0, "au hameau : ni charbon ni vêtements")
	gs.tier.level = 3
	stock.amount[Stockpile.Good.COAL] = 50.0
	var heat: float = gs.population.wood_need(season)
	_check(is_equal_approx(gs.coal_heat_need(season), heat * gs.COAL_HEAT_SHARE / gs.COAL_WOOD_EQUIVALENT)
		and is_equal_approx(gs.wood_need(season), heat * (1.0 - gs.COAL_HEAT_SHARE)), "bourg : le charbon chauffe la moitié")
	stock.amount[Stockpile.Good.WOOD] = 100.0
	gs._consume(GameDate.WINTER * GameDate.DAYS_PER_SEASON * GameDate.HOURS_PER_DAY)
	_check(is_equal_approx(stock.amount[Stockpile.Good.WOOD], 100.0 - heat / 2.0 / GameDate.HOURS_PER_DAY)
		and is_equal_approx(gs._consumed_today[Stockpile.Good.WOOD], gs._needed_today[Stockpile.Good.WOOD]),
		"chauffage de l'heure : moitié bois, moitié charbon, besoin couvert")
	stock.amount[Stockpile.Good.FIBER] = 3.0
	var b := _place_running(gs, weaver)
	gs._run_weavers()
	_check(b != null and is_equal_approx(stock.amount[Stockpile.Good.CLOTHES], 3.0) and stock.amount[Stockpile.Good.FIBER] == 0.0,
		"tissage : fibres → vêtements, dans la limite des fibres")
	_check(is_equal_approx(gs._wear_clothes(), minf(1.0, 3.0 / gs.clothes_need())), "usure des vêtements")
	# Coke : la forge brûle du charbon et fabrique 50 % de plus.
	var forge := _place_running(gs, BuildingDb.get_def(&"forge"))
	gs.research._done[&"coke"] = true
	stock.amount[Stockpile.Good.IRON] = 100.0
	stock.amount[Stockpile.Good.COAL] = 50.0
	stock.amount[Stockpile.Good.TOOLS] = 0.0
	var wood_before: float = stock.amount[Stockpile.Good.WOOD]
	gs._run_forges()
	var made: float = BuildingDb.get_def(&"forge").tools_per_day * gs.COKE_FORGE_BONUS
	_check(forge != null and is_equal_approx(stock.amount[Stockpile.Good.TOOLS], made)
		and is_equal_approx(stock.amount[Stockpile.Good.COAL], 50.0 - made * gs.FORGE_WOOD_PER_TOOL / gs.COAL_WOOD_EQUIVALENT)
		and stock.amount[Stockpile.Good.WOOD] == wood_before, "coke : deux fois moins de charbon que de bois, outils +50 %%")
	gs.new_game(4242)


func _test_treasury() -> void:
	var t := Treasury.new()
	var stock := Stockpile.new()
	_check(t.tax_level == Treasury.DEFAULT_TAX and t.mood() == 1.0, "impôt faible par défaut, sans effet sur l'humeur")
	t.tax_level = 2
	_check(is_equal_approx(t.taxes_for(100, 1.0), 10.0) and is_equal_approx(t.taxes_for(100, 0.0), 5.0)
		and t.mood() < 1.0, "impôt normal : 0,1 pièce par habitant, moitié à satisfaction nulle")
	_check(t.sell(stock, Stockpile.Good.FOOD, 10.0) == 0.0, "pas de marché : pas de commerce")
	t.trade_capacity = 30.0
	stock.amount[Stockpile.Good.IRON] = 50.0
	var sold := t.sell(stock, Stockpile.Good.IRON, 20.0)
	_check(sold == 20.0 and t.money == 20.0 * Treasury.PRICES[Stockpile.Good.IRON] and stock.amount[Stockpile.Good.IRON] == 30.0,
		"vente au prix courant")
	t.money = 1000.0
	var bought := t.buy(stock, Stockpile.Good.TOOLS, 50.0)
	_check(bought == 10.0 and is_equal_approx(t.money, 1000.0 - 10.0 * Treasury.buy_price(Stockpile.Good.TOOLS)),
		"achat limité par le volume du jour (%s)" % bought)
	_check(t.trade_left() == 0.0 and t.buy(stock, Stockpile.Good.FOOD, 1.0) == 0.0, "volume épuisé")
	t.reset_day()
	t.money = 3.0
	_check(is_equal_approx(t.buy(stock, Stockpile.Good.WOOD, 10.0), 2.0), "achat limité par les pièces")
	t.reset_day()
	t.money = 0.0
	t.trade_capacity = 1000.0
	stock.amount[Stockpile.Good.WOOD] = stock.capacity[Stockpile.Good.WOOD]
	t.auto_sell[Stockpile.Good.WOOD] = true
	t.sell_surplus(stock)
	_check(is_equal_approx(stock.amount[Stockpile.Good.WOOD], stock.capacity[Stockpile.Good.WOOD] * Treasury.AUTO_SELL_RATIO)
		and t.money > 0.0, "vente automatique des surplus")


func _test_decrees() -> void:
	var d := Decrees.new()
	_check(d.mood() == 1.0 and d.food_factor() == 1.0 and d.active_bonus() == 0.0, "sans décret : aucun effet")
	d.rationing = true
	d.corvee = true
	_check(d.food_factor() == Decrees.RATION_FOOD and is_equal_approx(d.mood(), Decrees.RATION_MOOD * Decrees.CORVEE_MOOD),
		"rationnement et corvée")
	d.rationing = false
	d.corvee = false
	d.start_feast()
	_check(d.mood() == Decrees.FEAST_MOOD and not d.can_feast(), "fête : humeur en hausse, pas de nouvelle fête")
	for k in Decrees.FEAST_DAYS:
		d.end_day()
	_check(d.mood() == 1.0 and not d.can_feast(), "fin de la fête")
	for k in Decrees.FEAST_COOLDOWN_DAYS:
		d.end_day()
	_check(d.can_feast(), "nouvelle fête possible")
	var p := Population.new()
	p.end_day(1.0, 1.0, 100, 1.0, 1.0, 1.0, 0.8)
	_check(is_equal_approx(p.satisfaction, 0.8), "humeur : satisfaction du jour réduite")
	p = Population.new()
	p.end_day(1.0, 1.0, 100, 1.0, 1.0, 1.0, 1.2)
	_check(p.satisfaction == 1.0, "humeur : satisfaction bornée à 100 %")


func _road_world() -> Array:
	var map := WorldMap.new(Vector2i(256, 128), 1)
	var territory := Territory.new(map)
	var cells: Array[Vector2i] = []
	for y in range(40, 80):
		for x in range(40, 90):
			cells.append(Vector2i(x, y))
			map.set_terrain(Vector2i(x, y), TerrainDef.Type.PLAIN)
	territory.annex(cells)
	var registry := BuildingRegistry.new(map, territory)
	var zones := ZoneMap.new(map, territory, registry)
	var roads := RoadNetwork.new(map, territory, registry, Vector2i(45, 60))
	roads.zones = zones
	registry.roads = roads
	return [map, roads, zones, Labor.new(zones, Vector2i(45, 60))]


func _test_roads() -> void:
	var world := _road_world()
	var map: WorldMap = world[0]
	var roads: RoadNetwork = world[1]
	var zones: ZoneMap = world[2]
	var labor: Labor = world[3]
	labor.roads = roads
	map.set_terrain(Vector2i(60, 60), TerrainDef.Type.RIVER)
	var plan := roads.plan(Vector2i(50, 60), Vector2i(85, 60))
	_check(plan.is_valid() and is_equal_approx(plan.costs[Stockpile.Good.STONE],
		35 * RoadNetwork.STONE_PER_TILE + RoadNetwork.STONE_PER_TILE * TrackNetwork.BRIDGE_FACTOR), "route : pavés, pont plus cher")
	roads.build(plan)
	var far := Vector2i(85, 62)
	_check(roads.distance_via(far) == -1, "route non calculée : pas d'effet")
	roads.refresh()
	_check(roads.lengths.size() == 36 and roads.lengths[Vector2i(85, 60)] == 35, "route reliée au village, longueur comptée depuis la portée du village")
	_check(roads.distance_via(far) == 17 + 2 and labor.distance(far) == 19, "2 tuiles de route = 1 de marche, 2 tuiles de portée")
	_check(roads.distance_via(Vector2i(85, 63)) == -1 and labor.distance(Vector2i(85, 63)) == 40, "au-delà de la portée : à pied")
	_check(not zones.check_cell(ZoneDb.get_def(&"pasture"), Vector2i(70, 60)).is_empty(), "pas de zone sur une route")
	_check(roads.plan(Vector2i(50, 60), Vector2i(55, 60)).error == "Route déjà posée", "route déjà posée")
	roads.remove(Vector2i(70, 60))
	roads.refresh()
	_check(roads.distance_via(far) == -1 and roads.lengths.size() == 20, "route coupée : le reste n'est plus relié")
	var loose := _road_world()[1] as RoadNetwork
	loose.add_cells([Vector2i(70, 60), Vector2i(71, 60)] as Array[Vector2i])
	loose.refresh()
	_check(loose.lengths.is_empty() and loose.distance_via(Vector2i(70, 60)) == -1, "route isolée : aucun effet")


func _test_roads_game() -> void:
	var gs: Node = root.get_node("GameState")
	gs.new_game(4242)
	var center: Vector2i = gs.display_cell(gs.home)
	var from := center + Vector2i(0, 4)
	_check(gs.plan_roads(from, from + Vector2i(2, 0)).error.contains("palier"), "route : bourg requis")
	gs.tier.level = 3
	gs.stockpile.amount[Stockpile.Good.STONE] = 0.0
	var plan: TrackNetwork.Plan
	for dy in range(2, 7):
		from = center + Vector2i(-3, dy)
		plan = gs.plan_roads(from, from + Vector2i(1, 0))
		if plan.error.contains("insuffisant"):
			break
	_check(plan.error.contains("Pierre insuffisante"), "route : pierre requise (%s)" % plan.error)
	gs.stockpile.amount[Stockpile.Good.STONE] = 100.0
	plan = gs.plan_roads(from, from + Vector2i(1, 0))
	var built: int = gs.build_roads(plan)
	_check(built == 2 and gs.roads.lengths.size() == 2 and gs.stockpile.amount[Stockpile.Good.STONE] < 100.0, "route posée au bourg")
	_check(gs.demolish(from) and not gs.roads.has_tile(from), "route démolie")
	gs.new_game(4242)


func _test_city_game() -> void:
	var gs: Node = root.get_node("GameState")
	gs.new_game(4242)
	var site := StartSite.territory_rect(gs.home)
	var oil_cells := 0
	for y in range(site.position.y, site.end.y):
		for x in range(site.position.x, site.end.x):
			if gs.world_map.get_deposit(Vector2i(x, y)) == WorldMap.Deposit.OIL:
				oil_cells += 1
	_check(oil_cells >= StartSite.MIN_OIL, "pétrole près du village (%d tuiles)" % oil_cells)
	_check(gs.light_need() == 0.0 and gs._burn_light() == 1.0, "avant la ville : pas d'éclairage")
	gs.tier.level = 4
	gs.population.count = 1000
	var stock: Stockpile = gs.stockpile
	stock.capacity[Stockpile.Good.OIL] = 1000.0
	stock.amount[Stockpile.Good.OIL] = 4.0
	var refinery := _place_running(gs, BuildingDb.get_def(&"refinery"))
	gs._run_refineries()
	_check(refinery != null and is_equal_approx(stock.amount[Stockpile.Good.FUEL], 4.0) and stock.amount[Stockpile.Good.OIL] == 0.0,
		"raffinerie : pétrole → carburant, dans la limite du pétrole")
	_check(is_equal_approx(gs.light_need(), 10.0) and is_equal_approx(gs._burn_light(), 0.4), "éclairage : part couverte")
	var p := Population.new()
	p.end_day(1.0, 1.0, 100, 1.0, 1.0, 1.0, 1.0, 0.0)
	_check(is_equal_approx(p.satisfaction, 1.0 - Population.LIGHT_WEIGHT), "sans éclairage : satisfaction réduite")
	var uni := _place_running(gs, BuildingDb.get_def(&"university"))
	var points: float = gs.research_per_day()
	gs.treasury.money = 100.0
	gs._pay_upkeep()
	_check(uni != null and gs.upkeep_paid and gs.treasury.money == 70.0 and points > 5000.0, "université : entretien payé, recherche ×10")
	gs.treasury.money = 10.0
	gs._pay_upkeep()
	_check(not gs.upkeep_paid and gs.treasury.money == 10.0 and gs.research_per_day() < points, "entretien impayé : université à l'arrêt")
	gs.new_game(4242)


func _test_city_events() -> void:
	var e := CityEvents.new(7)
	var farm := ZoneDb.get_def(&"agriculture")
	var pasture := ZoneDb.get_def(&"pasture")
	_check(e.heat_factor() == 1.0 and e.zone_factor(farm) == 1.0, "sans événement : aucun effet")
	var early := 0
	for k in CityEvents.MIN_GAP_DAYS - 1:
		if e.roll(GameDate.WINTER) >= 0:
			early += 1
	_check(early == 0, "écart minimal entre deux événements")
	var seen: Array[int] = []
	var drawn := 0
	for k in 20000:
		var kind := e.roll(1)
		if kind >= 0:
			drawn += 1
			if kind not in seen:
				seen.append(kind)
			e.active.clear()
	_check(drawn > 20 and CityEvents.Kind.HARD_WINTER not in seen and CityEvents.Kind.DROUGHT in seen
		and seen.size() == 4, "été : pas d'hiver rude (%s)" % [seen])
	e.active.clear()
	e.active[CityEvents.Kind.DROUGHT] = 2
	e.active[CityEvents.Kind.HARD_WINTER] = 1
	_check(e.zone_factor(farm) == CityEvents.DROUGHT_FACTOR and e.zone_factor(pasture) == 1.0
		and e.heat_factor() == CityEvents.HARD_WINTER_HEAT, "sécheresse et hiver rude")
	var ended := e.end_day()
	_check(ended.size() == 1 and ended[0] == CityEvents.Kind.HARD_WINTER and e.is_active(CityEvents.Kind.DROUGHT), "fin d'un événement")
	var a := CityEvents.new(5)
	var b := CityEvents.new(5)
	var same := true
	for k in 2000:
		same = same and a.roll(k / 30 % 4) == b.roll(k / 30 % 4)
	_check(same, "événements reproductibles avec la graine")


func _test_events_game() -> void:
	var gs: Node = root.get_node("GameState")
	gs.new_game(4242)
	gs.events._gap = 0
	gs.events.rng.seed = 3
	for k in 400:
		gs._run_events(1)
	_check(gs.events.active.is_empty(), "hameau : pas d'événement")
	gs.tier.level = 3
	var heat: float = gs.population.wood_need(GameDate.WINTER)
	gs.events.active[CityEvents.Kind.HARD_WINTER] = 5
	_check(is_equal_approx(gs.wood_need(GameDate.WINTER), heat * CityEvents.HARD_WINTER_HEAT), "hiver rude : plus de bois")
	gs.events.active.clear()
	gs.draft.horses = 10.0
	gs.apply_event(CityEvents.Kind.EPIZOOTIC)
	_check(is_equal_approx(gs.draft.horses, 8.0), "épizootie : chevaux perdus")
	var forests := func() -> int:
		var n := 0
		for c: Vector2i in gs.territory.territory_cells():
			if gs.world_map.get_terrain(c) == TerrainDef.Type.FOREST:
				n += 1
		return n
	var before: int = forests.call()
	var burnt: int = gs._burn_forest()
	_check(burnt > 0 and burnt <= CityEvents.FIRE_TILES and forests.call() == before - burnt, "incendie : %d tuiles" % burnt)
	gs.population.count = 100
	gs.housing = 102
	gs.apply_event(CityEvents.Kind.MIGRANTS)
	_check(gs.population.count == 102, "migrants : dans la limite des logements")
	gs.apply_event(CityEvents.Kind.MIGRANTS)
	_check(gs.population.count == 102, "migrants : sans logement, personne ne reste")
	gs.new_game(4242)


func _test_economy_game() -> void:
	var gs: Node = root.get_node("GameState")
	gs.new_game(4242)
	_check(not gs.economy_error().is_empty() and gs.mood() == 1.0, "hameau : pas d'économie")
	var money: float = gs.treasury.money
	gs._run_economy()
	_check(gs.treasury.money == money, "hameau : pas d'impôt")
	gs.tier.level = 3
	gs.population.count = 400
	gs._run_economy()
	_check(gs.treasury.money > 0.0, "bourg : impôts encaissés")
	_check(gs.trade_error().contains("marché"), "commerce : marché requis")
	var market := _place_running(gs, BuildingDb.get_def(&"market"))
	gs._refresh_capacities()
	_check(market != null and gs.trade_error().is_empty() and gs.treasury.trade_capacity == market.def.trade_per_day,
		"marché : commerce ouvert")
	gs.stockpile.amount[Stockpile.Good.STONE] = 50.0
	_check(gs.trade(Stockpile.Good.STONE, -10.0) == 10.0, "vente au marché")
	var food: float = gs.food_need()
	gs.set_rationing(true)
	_check(is_equal_approx(gs.food_need(), food * Decrees.RATION_FOOD), "rationnement : moins de nourriture")
	var active: int = gs.population.active()
	gs.set_corvee(true)
	_check(gs.population.active() > active, "corvée : plus d'actifs")
	gs.treasury.money = 0.0
	_check(gs.feast_error().contains("Pièces"), "fête : pièces requises")
	gs.treasury.money = 1000.0
	gs.stockpile.amount[Stockpile.Good.FOOD] = 1000.0
	_check(gs.hold_feast() and gs.treasury.money == 800.0 and gs.stockpile.amount[Stockpile.Good.FOOD] == 600.0,
		"fête : 400 nourriture et 200 pièces")
	gs.new_game(4242)
	_check(gs.population.active_share == Population.ACTIVE_SHARE and not gs.decrees.corvee, "nouvelle partie : décrets levés")


## Pose [param def] terminé sur la première tuile libre près du village de
## [param gs] ; null si aucune.
func _place_running(gs: Node, def: BuildingDef) -> Building:
	var center: Vector2i = gs.display_cell(gs.home)
	for r in range(1, 6):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var placement: BuildingRegistry.Placement = gs.buildings.check_placement(def, center + Vector2i(dx, dy))
				if placement.is_valid():
					var b: Building = gs.buildings.place(placement)
					b.build_progress = def.build_hours
					b.status = Building.Status.RUNNING
					return b
	return null


func _test_rails() -> void:
	var map := WorldMap.new(Vector2i(64, 64), 0, FlatGenerator.new(Vector2i(64, 64)))
	var territory := Territory.new(map)
	var cells: Array[Vector2i] = []
	for y in 10:
		for x in 40:
			cells.append(Vector2i(x, y))
	territory.annex(cells)
	var registry := BuildingRegistry.new(map, territory)
	var zones := ZoneMap.new(map, territory, registry)
	var center := Vector2i(2, 2)
	var rails := RailNetwork.new(map, territory, registry, center)
	rails.zones = zones
	registry.rails = rails
	var labor := Labor.new(zones, center)
	labor.rails = rails
	var expected: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(3, 1)]
	_check(RailNetwork.l_path(Vector2i(0, 0), Vector2i(3, 1)) == expected, "tracé en L, l'axe le plus long d'abord")
	map.set_terrain(Vector2i(10, 2), TerrainDef.Type.RIVER)
	var plan := rails.plan(Vector2i(3, 2), Vector2i(30, 2))
	_check(plan.is_valid() and plan.new_cells.size() == 28
		and is_equal_approx(plan.costs[Stockpile.Good.IRON], 27.0 + RailNetwork.BRIDGE_FACTOR), "28 tuiles, pont plus cher")
	_check(not rails.plan(Vector2i(3, 2), Vector2i(3, 20)).is_valid(), "hors du territoire : refusé")
	rails.build(plan)
	_check(rails.tile_count() == 28 and rails.has_rail(Vector2i(10, 2)), "voie posée")
	_check(not rails.plan(Vector2i(3, 2), Vector2i(8, 2)).is_valid(), "voie déjà posée")
	var station := BuildingDb.get_def(&"station")
	_check(station.station and station.research == &"locomotive" and station.tier == 3, "gare : bourg, recherche Locomotive")
	_check(not registry.check_placement(station, Vector2i(5, 2)).is_valid(), "pas de bâtiment sur la voie")
	_check(not zones.check_cell(ZoneDb.get_def(&"agriculture"), Vector2i(5, 2)).is_empty(), "pas de zone sur la voie")
	var home_station := registry.place(registry.check_placement(station, Vector2i(3, 3)))
	var far := registry.place(registry.check_placement(station, Vector2i(30, 3)))
	var lone := registry.place(registry.check_placement(station, Vector2i(30, 8)))
	var stations: Array[Building] = [home_station, far, lone]
	rails.refresh(stations)
	_check(rails.is_village_station(home_station) and rails.served.size() == 1 and rails.served.get(Vector2i(30, 3), 0) == 28,
		"gare lointaine desservie (28 tuiles de voie), gare isolée non")
	var cell := Vector2i(30, 5)
	_check(rails.distance_via(cell) == 2 + ceili(28.0 / RailNetwork.RAIL_TILES_PER_WALK_TILE) and labor.distance(cell) == 12,
		"distance par le train : 2 tuiles de la gare + 28 / 3 (à pied : 28)")
	_check(labor.distance(Vector2i(4, 4)) == 2, "près du village, la marche reste plus courte")
	_check(is_equal_approx(rails.coal_need(), RailNetwork.COAL_PER_STATION_PER_DAY + 28 * RailNetwork.COAL_PER_RAIL_TILE_PER_DAY),
		"charbon des convois")
	rails.running = false
	_check(labor.distance(cell) == 28 and rails.distance_via(cell) == -1, "trains arrêtés : retour à la marche")
	rails.running = true
	rails.remove(Vector2i(15, 2))
	rails.refresh(stations)
	_check(rails.served.is_empty() and labor.distance(cell) == 28, "voie coupée : gare plus desservie")


## Gisement de pierre : carrière hors des collines, épuisable.
func _test_stone_deposit() -> void:
	var setup := _labor_setup()
	var zones: ZoneMap = setup[0]
	var labor: Labor = setup[1]
	var map: WorldMap = zones.map
	var territory: Territory = zones.territory
	var quarry := ZoneDb.get_def(&"quarry")
	var cell := Vector2i(3, 3)
	var free := Vector2i(5, 5)
	map.set_terrain(cell, TerrainDef.Type.PLAIN)
	map.set_terrain(free, TerrainDef.Type.PLAIN)
	map._chunk(cell).deposit[map._local(cell)] = WorldMap.Deposit.STONE
	map._chunk(cell).deposit_amount[map._local(cell)] = 1.0
	territory.prospect([cell] as Array[Vector2i])
	territory.tier = 1
	_check(not zones.check_cell(quarry, cell).is_empty(), "pierre cachée au hameau")
	territory.tier = 2
	_check(zones.check_cell(quarry, cell).is_empty() and not zones.check_cell(quarry, free).is_empty(),
		"carrière sur un gisement de pierre, pas sur une plaine nue")
	_check(quarry.uses_alt_deposit(map, cell), "gisement de pierre : la carrière y puise")
	var hill := Vector2i(7, 7)
	map.set_terrain(hill, TerrainDef.Type.HILL)
	_check(zones.check_cell(quarry, hill).is_empty() and not quarry.uses_alt_deposit(map, hill), "colline : carrière sans épuisement")
	var report := Production.Report.new()
	var prod := Production.new(zones, labor)
	prod._mine(cell, 5.0, report)
	_check(report.cleared == [cell] and map.get_deposit(cell) == WorldMap.Deposit.NONE, "gisement de pierre épuisé : zone retirée")


## Recherche Charbon de bois : part du bois coupé transformée en charbon.
func _test_charcoal(gs: Node) -> void:
	var def := ResearchDb.get_def(&"charcoal")
	var pre: Array[StringName] = [&"sylviculture"]
	_check(def != null and def.tier == 3 and def.prerequisites == pre, "charbon de bois : bourg, après la sylviculture")
	var stock: Stockpile = gs.stockpile
	var wood := Stockpile.Good.WOOD
	var coal := Stockpile.Good.COAL
	var saved := [stock.amount[wood], stock.amount[coal], stock.capacity[wood], stock.capacity[coal]]
	stock.capacity[wood] = 100000.0
	stock.capacity[coal] = 100.0
	stock.amount[wood] = 50000.0
	stock.amount[coal] = 0.0
	gs.production.produced_today[wood] = 300.0
	gs._run_charcoal()
	_check(stock.amount[wood] == 50000.0 and stock.amount[coal] == 0.0, "charbon de bois : rien sans la recherche")
	gs.research._done[&"charcoal"] = true
	var produced: float = gs.production.produced_today[coal]
	gs._run_charcoal()
	_check(is_equal_approx(stock.amount[wood], 49940.0) and is_equal_approx(stock.amount[coal], 20.0)
		and is_equal_approx(gs.production.produced_today[coal] - produced, 20.0), "charbon de bois : 20 % du bois coupé, 3 bois pour 1 charbon")
	stock.amount[coal] = 99.0
	gs._run_charcoal()
	_check(is_equal_approx(stock.amount[wood], 49937.0) and is_equal_approx(stock.amount[coal], 100.0), "charbon de bois : limité par la place en stock")
	stock.amount[coal] = 0.0
	var reserve: float = gs.wood_need(GameDate.WINTER) * gs.CHARCOAL_RESERVE_DAYS
	stock.amount[wood] = reserve
	gs._run_charcoal()
	_check(reserve > 0.0 and is_equal_approx(stock.amount[wood], reserve) and stock.amount[coal] == 0.0, "charbon de bois : réserve de chauffage gardée")
	gs.research._done.erase(&"charcoal")
	gs.production.produced_today[wood] = 0.0
	gs.production.produced_today[coal] = produced
	stock.amount[wood] = saved[0]
	stock.amount[coal] = saved[1]
	stock.capacity[wood] = saved[2]
	stock.capacity[coal] = saved[3]


## Recherche Sylviculture : forêts deux fois plus rapides à repousser.
func _test_sylviculture(prod: Production, map: WorldMap, cell: Vector2i) -> void:
	var def := ResearchDb.get_def(&"sylviculture")
	var pre: Array[StringName] = [&"crop_rotation"]
	_check(def != null and def.tier == 3 and def.prerequisites == pre, "sylviculture : bourg, après l'assolement")
	prod.regrowth_factor = 2.0
	_check(prod.clearcut_days() == Production.CLEARCUT_REGROW_DAYS / 2, "sylviculture : coupe à blanc deux fois plus courte")
	var wood := map.get_wood(cell)
	prod.end_day(0)
	_check(is_equal_approx(map.get_wood(cell) - wood, Production.FOREST_REGROWTH_PER_DAY * 2.0),
		"sylviculture : densification deux fois plus rapide")
	prod.regrowth_factor = 1.0


func _test_steam_and_scouts() -> void:
	var engine := BuildingDb.get_def(&"steam_engine")
	_check(engine.research == &"steam_engine" and engine.coal_per_day > 0.0 and engine.mine_bonus > 0.0
		and engine.drive_bonus > 0.0, "machine à vapeur : charbon, mines et entraînement")
	var steam_pre: Array[StringName] = [&"coke"]
	var loco_pre: Array[StringName] = [&"steam_engine"]
	_check(ResearchDb.get_def(&"steam_engine").prerequisites == steam_pre
		and ResearchDb.get_def(&"locomotive").prerequisites == loco_pre, "vapeur après le coke, locomotive après la vapeur")
	var setup := _labor_setup()
	var prod := Production.new(setup[0], setup[1])
	prod.mine_bonus = engine.mine_bonus
	_check(is_equal_approx(prod.invention_factor(ZoneDb.get_def(&"coal_mine"), Vector2i(3, 3)), 1.5)
		and is_equal_approx(prod.invention_factor(ZoneDb.get_def(&"quarry"), Vector2i(3, 3)), 1.5)
		and is_equal_approx(prod.invention_factor(ZoneDb.get_def(&"pasture"), Vector2i(3, 3)), 1.0), "vapeur : mines et carrières")
	# Éclaireurs à cheval : au bourg, un cheval par explorateur.
	var exploration := Exploration.new(_flat_map()[1])
	exploration.tier = 2
	_check(exploration.speed_for(3, 3) == 1.0, "au village : pas d'éclaireurs à cheval")
	exploration.tier = 3
	_check(exploration.speed_for(3, 3) == Exploration.MOUNTED_SPEED and exploration.speed_for(3, 2) == 1.0,
		"au bourg : à cheval si chacun a le sien")
	var slow := exploration.round_trip_days(Vector2i(2, 2), Vector2i(20, 2))
	_check(is_equal_approx(exploration.round_trip_days(Vector2i(2, 2), Vector2i(20, 2), Exploration.MOUNTED_SPEED),
		slow / Exploration.MOUNTED_SPEED), "à cheval : aller-retour plus court")
