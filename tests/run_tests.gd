extends SceneTree
## Tests unitaires de la simulation pure (provisoire : GUT viendra plus tard).
## Lancer : godot --headless -s res://tests/run_tests.gd

var _failures := 0
var _count := 0


func _init() -> void:
	_test_tick_accumulator()
	_test_game_date()
	_test_iso_matches_tilemap()
	_test_map_generation()
	_test_format()
	_test_building_defs()
	_test_placement()
	_test_construction()
	_test_production()
	_test_roads()
	_test_logistics()
	_test_transport_throughput()
	_test_vehicle_sale()
	_test_rail()
	_test_nuclear()
	_test_weather()
	_test_renewables()
	_test_storage()
	_test_ports()
	_test_pollution()
	_test_economy()
	_test_cities()
	_test_grid()
	_test_tech_data()
	_test_research()
	_test_laboratory()
	print("%d vérifications, %d échec(s)" % [_count, _failures])
	quit(1 if _failures > 0 else 0)


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


func _test_map_generation() -> void:
	var size := Vector2i(64, 64)
	var a := MapGenerator.generate(size, 1234)
	var b := MapGenerator.generate(size, 1234)
	var c := MapGenerator.generate(size, 999)
	_check(a.terrain == b.terrain and a.wind == b.wind and a.deposit_amount == b.deposit_amount,
		"même graine → même carte")
	_check(a.terrain != c.terrain, "graines différentes → cartes différentes")

	for seed_value in [1, 2, 3, 42, 777]:
		var map := MapGenerator.generate(size, seed_value)
		var present := {}
		var deposits := {}
		var errors := PackedStringArray()
		for i in map.cell_count():
			var cell := map.cell_of(i)
			var t := map.terrain[i]
			present[t] = true
			if map.wind[i] < 0.0 or map.wind[i] > 1.0 or map.sun[i] < 0.0 or map.sun[i] > 1.0:
				errors.append("attribut hors 0–1 en %s" % cell)
			var touches_water := map.neighbors(cell, WorldMap.NEIGHBORS_8) \
				.any(func(n: Vector2i) -> bool: return map.is_water(n))
			if bool(map.water_access[i]) != (touches_water and not map.is_water(cell)):
				errors.append("accès à l'eau incohérent en %s" % cell)
			var kind := map.deposit[i]
			if kind != WorldMap.Deposit.NONE:
				deposits[kind] = true
				if not TerrainDb.get_def(t).buildable or map.deposit_amount[i] <= 0:
					errors.append("gisement invalide en %s" % cell)
		_check(errors.is_empty(), "carte %d cohérente %s" % [seed_value, errors.slice(0, 3)])
		for t in [TerrainDef.Type.PLAIN, TerrainDef.Type.FOREST, TerrainDef.Type.HILL,
				TerrainDef.Type.MOUNTAIN, TerrainDef.Type.RIVER, TerrainDef.Type.SEA,
				TerrainDef.Type.DESERT]:
			_check(present.has(t), "carte %d contient %s" % [seed_value, TerrainDb.get_def(t).display_name])
		_check(deposits.size() == 3, "carte %d contient les 3 gisements" % seed_value)


func _test_format() -> void:
	_check(Format.thousands(1234567) == "1\u202f234\u202f567", "milliers")
	_check(Format.thousands(-500) == "-500", "négatif court")
	_check(Format.duration_hours(48) == "2 j" and Format.duration_hours(36) == "36 h", "durées")


## Petite carte de plaine aux attributs contrôlés.
func _flat_map(size := Vector2i(8, 8)) -> WorldMap:
	var map := WorldMap.new(size)
	map.terrain.fill(TerrainDef.Type.PLAIN)
	map.wind.fill(0.3)
	map.sun.fill(0.5)
	return map


func _test_building_defs() -> void:
	var ids := {}
	for def in BuildingDb.DEFS:
		_check(not ids.has(def.id), "identifiant unique %s" % def.id)
		ids[def.id] = true
		_check(def.cost > 0 and def.build_hours > 0 and def.size.x > 0 and def.size.y > 0,
			"%s : coût, durée et taille positifs" % def.id)
		_check(BuildingDb.get_def(def.id) == def, "BuildingDb.get_def(%s)" % def.id)
	var plant := BuildingDb.get_def(&"coal_plant")
	_check(plant.footprint(Vector2i(5, 5)) == [Vector2i(4, 4), Vector2i(5, 4), Vector2i(4, 5), Vector2i(5, 5)],
		"emprise 2×2 ancrée à l'avant-bas")
	_check(plant.describe_constraints() == PackedStringArray(["Près de l'eau"]), "contraintes lisibles")


func _test_placement() -> void:
	var map := _flat_map()
	var reg := BuildingRegistry.new(map)
	var lab := BuildingDb.get_def(&"laboratory")
	var lumberjack := BuildingDb.get_def(&"lumberjack")
	var mine := BuildingDb.get_def(&"coal_mine")
	var plant := BuildingDb.get_def(&"coal_plant")
	var turbine := BuildingDb.get_def(&"wind_turbine")
	var nursery := BuildingDb.get_def(&"nursery")
	var warehouse := BuildingDb.get_def(&"warehouse")

	_check(reg.check_placement(lab, Vector2i(2, 2)).is_valid(), "plaine libre : valide")
	_check(not reg.check_placement(lab, Vector2i(2, 2), lab.cost - 1).is_valid(), "fonds insuffisants")
	_check(reg.check_placement(lab, Vector2i(2, 2), lab.cost).is_valid(), "fonds tout juste suffisants")
	_check(not reg.check_placement(plant, Vector2i(0, 3)).is_valid(), "emprise hors carte")
	_check(not reg.check_placement(warehouse, Vector2i(0, 3)).is_valid(), "entrepôt 2×1 hors carte à x=0")
	_check(reg.check_placement(warehouse, Vector2i(1, 0)).error == "Doit être relié à une route",
		"entrepôt sans route")
	reg.roads.add_cells([Vector2i(0, 1)])
	_check(reg.check_placement(warehouse, Vector2i(1, 0)).is_valid(), "entrepôt 2×1 en (0..1, 0) relié")
	_check(reg.check_placement(lab, Vector2i(0, 1)).error == "Route présente", "pas de bâtiment sur une route")
	reg.roads.remove(Vector2i(0, 1))

	map.terrain[map.index_of(Vector2i(3, 3))] = TerrainDef.Type.MOUNTAIN
	_check(not reg.check_placement(lab, Vector2i(3, 3)).is_valid(), "montagne non constructible")
	_check(not reg.check_placement(nursery, Vector2i(3, 3)).is_valid(), "terrain non autorisé")
	map.terrain[map.index_of(Vector2i(3, 3))] = TerrainDef.Type.HILL
	_check(not reg.check_placement(nursery, Vector2i(3, 3)).is_valid(), "pépinière : plaine seulement")
	_check(reg.check_placement(lab, Vector2i(3, 3)).is_valid(), "colline constructible")

	_check(not reg.check_placement(lumberjack, Vector2i(5, 5)).is_valid(), "bûcheron sans forêt")
	map.terrain[map.index_of(Vector2i(6, 6))] = TerrainDef.Type.FOREST
	_check(reg.check_placement(lumberjack, Vector2i(5, 5)).is_valid(), "bûcheron près d'une forêt (diagonale)")
	var on_forest := reg.check_placement(lab, Vector2i(6, 6))
	_check(on_forest.is_valid() and on_forest.cleared == [Vector2i(6, 6)], "forêt à défricher")
	_check(not reg.check_placement(lumberjack, Vector2i(6, 6)).is_valid(),
		"la forêt de l'emprise ne compte pas comme voisine")

	_check(not reg.check_placement(mine, Vector2i(1, 6)).is_valid(), "mine sans gisement")
	map.deposit[map.index_of(Vector2i(1, 6))] = WorldMap.Deposit.URANIUM
	_check(not reg.check_placement(mine, Vector2i(1, 6)).is_valid(), "mine de charbon sur uranium")
	map.deposit[map.index_of(Vector2i(1, 6))] = WorldMap.Deposit.COAL
	_check(reg.check_placement(mine, Vector2i(1, 6)).is_valid(), "mine sur charbon")

	_check(not reg.check_placement(plant, Vector2i(7, 1)).is_valid(), "centrale sans eau")
	map.water_access[map.index_of(Vector2i(6, 0))] = 1
	_check(reg.check_placement(plant, Vector2i(7, 1)).is_valid(), "centrale : une tuile près de l'eau suffit")

	_check(not reg.check_placement(turbine, Vector2i(4, 0)).is_valid(), "vent insuffisant")
	map.wind[map.index_of(Vector2i(4, 0))] = 0.9
	_check(reg.check_placement(turbine, Vector2i(4, 0)).is_valid(), "vent suffisant")

	var b := reg.place(reg.check_placement(plant, Vector2i(7, 1)))
	_check(reg.building_at(Vector2i(6, 0)) == b and reg.building_at(Vector2i(7, 1)) == b, "occupation 2×2")
	_check(reg.building_at(Vector2i(5, 0)) == null, "tuile voisine libre")
	_check(not reg.check_placement(lab, Vector2i(6, 1)).is_valid(), "tuile occupée")
	_check(not reg.check_placement(plant, Vector2i(6, 2)).is_valid(), "chevauchement partiel")
	var forest_b := reg.place(on_forest)
	_check(map.get_terrain(Vector2i(6, 6)) == TerrainDef.Type.PLAIN, "défrichement à la construction")
	reg.remove(b)
	_check(reg.building_at(Vector2i(6, 0)) == null and reg.count() == 1, "démolition libère l'emprise")
	_check(reg.check_placement(lab, Vector2i(6, 1)).is_valid(), "emplacement réutilisable")
	_check(reg.building_at(Vector2i(6, 6)) == forest_b, "autre bâtiment intact")


func _test_construction() -> void:
	var reg := BuildingRegistry.new(_flat_map())
	var lab := BuildingDb.get_def(&"laboratory")
	var plant := BuildingDb.get_def(&"biomass_plant")
	var a := reg.place(reg.check_placement(lab, Vector2i(1, 1)))
	var b := reg.place(reg.check_placement(plant, Vector2i(5, 5)))
	_check(not a.is_complete() and a.progress_ratio() == 0.0, "chantier au départ")
	_check(reg.daily_upkeep() == 0, "pas d'entretien pendant le chantier")
	_check(BuildingRegistry.refund_for(a) == floori(lab.cost * BuildingRegistry.REFUND_UNDER_CONSTRUCTION),
		"remboursement d'un chantier annulé")
	var done := reg.advance(lab.build_hours - 1)
	_check(done.is_empty() and not a.is_complete(), "chantier presque fini")
	done = reg.advance(1)
	_check(done == [a] and a.is_complete(), "chantier terminé à build_hours")
	_check(reg.advance(1).is_empty(), "terminé une seule fois")
	_check(reg.daily_upkeep() == lab.upkeep_per_day, "entretien des bâtiments terminés")
	_check(BuildingRegistry.refund_for(a) == floori(lab.cost * BuildingRegistry.REFUND_COMPLETE),
		"remboursement d'un bâtiment terminé")
	reg.advance(plant.build_hours)
	_check(b.is_complete() and b.build_progress == plant.build_hours, "progression plafonnée")
	_check(reg.daily_upkeep() == lab.upkeep_per_day + plant.upkeep_per_day, "entretien cumulé")


## Pose et termine immédiatement un bâtiment (placement supposé valide).
func _built(reg: BuildingRegistry, id: StringName, anchor: Vector2i) -> Building:
	var p := reg.check_placement(BuildingDb.get_def(id), anchor)
	_check(p.is_valid(), "placement de %s en %s : %s" % [id, anchor, p.error])
	var b := reg.place(p)
	b.build_progress = b.def.build_hours
	# Hors des tests du réseau, les centrales sont réputées raccordées et
	# appelées à pleine puissance.
	b.grid_id = -1
	b.power_setpoint = 1.0
	return b


func _test_production() -> void:
	var map := _flat_map(Vector2i(32, 32))
	var reg := BuildingRegistry.new(map)
	var prod := Production.new(reg)
	var tick := 0

	# Chaîne bois : deux forêts, un bûcheron, une centrale biomasse (le
	# transport est simulé ici à la main, cf. _test_logistics).
	for c in [Vector2i(2, 1), Vector2i(3, 1)]:
		map.terrain[map.index_of(c)] = TerrainDef.Type.FOREST
		map.wood[map.index_of(c)] = 30.0
	var lumberjack := _built(reg, &"lumberjack", Vector2i(2, 2))
	var rate := lumberjack.def.output_per_hour
	var plant := _built(reg, &"biomass_plant", Vector2i(6, 6))
	var burn := plant.def.input_per_hour
	var site := reg.place(reg.check_placement(BuildingDb.get_def(&"laboratory"), Vector2i(10, 10)))
	tick += 1
	var r := prod.step(tick)
	_check(lumberjack.status == Building.Status.RUNNING and is_equal_approx(lumberjack.output_stock, rate),
		"bûcheron : une heure de production")
	_check(plant.status == Building.Status.NO_INPUT and r.power_mw == 0.0, "centrale sans bois à l'arrêt")
	_check(site.status == Building.Status.CONSTRUCTION, "chantier signalé")
	_check(is_equal_approx(map.wood[map.index_of(Vector2i(2, 1))], 30.0 - rate), "forêt la plus proche coupée d'abord")
	plant.input_stock = burn / 2.0
	tick += 1
	r = prod.step(tick)
	_check(is_equal_approx(plant.input_stock, 0.0) and plant.status == Building.Status.RUNNING
		and is_equal_approx(plant.activity, 0.5), "combustion partielle")
	_check(is_equal_approx(r.power_mw, plant.def.power_mw * 0.5), "puissance proportionnelle au combustible")
	var depleted := false
	for i in ceili(60.0 / rate) + 5:
		tick += 1
		r = prod.step(tick)
		plant.input_stock += lumberjack.output_stock
		lumberjack.output_stock = 0.0
		depleted = depleted or Vector2i(2, 1) in r.changed_cells
	_check(depleted and map.get_terrain(Vector2i(2, 1)) == TerrainDef.Type.PLAIN, "forêt épuisée → plaine")
	_check(lumberjack.status == Building.Status.DEPLETED, "bûcheron sans forêt : ressource épuisée")
	_check(map.wood[map.index_of(Vector2i(3, 1))] == 0.0, "les deux forêts coupées")
	_check(plant.status == Building.Status.NO_INPUT and plant.input_stock == 0.0, "centrale à court de bois")

	# Stock de sortie plein faute d'enlèvement.
	map.terrain[map.index_of(Vector2i(25, 1))] = TerrainDef.Type.FOREST
	map.wood[map.index_of(Vector2i(25, 1))] = WorldMap.WOOD_PER_FOREST
	var lonely := _built(reg, &"lumberjack", Vector2i(25, 2))
	for i in ceili(lonely.def.buffer_capacity / rate) + 2:
		tick += 1
		prod.step(tick)
	_check(lonely.status == Building.Status.OUTPUT_FULL
		and is_equal_approx(lonely.output_stock, lonely.def.buffer_capacity), "sortie pleine → arrêt")

	# Gisements : la mine vide sa tuile puis la voisine.
	var coal := Vector2i(20, 20)
	map.deposit[map.index_of(coal)] = WorldMap.Deposit.COAL
	map.deposit_amount[map.index_of(coal)] = 2.0
	map.deposit[map.index_of(Vector2i(21, 20))] = WorldMap.Deposit.COAL
	map.deposit_amount[map.index_of(Vector2i(21, 20))] = 1.0
	var mine := _built(reg, &"coal_mine", coal)
	var gone := false
	for i in ceili(3.0 / mine.def.output_per_hour) + 2:
		tick += 1
		r = prod.step(tick)
		gone = gone or coal in r.changed_cells
	_check(gone and map.deposit[map.index_of(coal)] == WorldMap.Deposit.NONE, "gisement épuisé")
	_check(map.deposit[map.index_of(Vector2i(21, 20))] == WorldMap.Deposit.NONE, "gisement voisin exploité")
	_check(mine.status == Building.Status.DEPLETED and is_equal_approx(mine.output_stock, 3.0), "mine épuisée")

	# Éolienne : puissance × potentiel de la tuile × vent du moment.
	map.wind[map.index_of(Vector2i(15, 28))] = 0.8
	var turbine := _built(reg, &"wind_turbine", Vector2i(15, 28))
	tick += 1
	prod.step(tick)
	_check(is_equal_approx(turbine.power_mw,
		turbine.def.power_mw * clampf(0.8 * prod.weather.wind_at(tick), 0.0, 1.0)), "éolienne × vent")

	# Pépinière : repousse et plantation quotidienne.
	map.terrain[map.index_of(Vector2i(5, 25))] = TerrainDef.Type.FOREST
	map.wood[map.index_of(Vector2i(5, 25))] = 50.0
	var nursery := _built(reg, &"nursery", Vector2i(5, 27))
	var forests_before := 0
	for i in map.cell_count():
		forests_before += 1 if map.terrain[i] == TerrainDef.Type.FOREST else 0
	for i in Production.PLANT_INTERVAL_HOURS:
		tick += 1
		prod.step(tick)
	var forests_after := 0
	for i in map.cell_count():
		forests_after += 1 if map.terrain[i] == TerrainDef.Type.FOREST else 0
	_check(forests_after == forests_before + 1, "une plantation par jour")
	_check(map.wood[map.index_of(Vector2i(5, 25))] > 50.0, "repousse des forêts")
	_check(nursery.status == Building.Status.RUNNING, "pépinière en service")


func _road_line(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	return RoadNetwork.l_path(from, to)


func _test_roads() -> void:
	_check(RoadNetwork.l_path(Vector2i(0, 0), Vector2i(3, 1))
		== [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(3, 1)], "tracé en L, x d'abord")
	_check(RoadNetwork.l_path(Vector2i(2, 2), Vector2i(1, 5))
		== [Vector2i(2, 2), Vector2i(2, 3), Vector2i(2, 4), Vector2i(2, 5), Vector2i(1, 5)], "tracé en L, y d'abord")
	_check(RoadNetwork.l_path(Vector2i(4, 4), Vector2i(4, 4)) == [Vector2i(4, 4)], "tracé d'une tuile")

	var map := _flat_map(Vector2i(16, 16))
	var reg := BuildingRegistry.new(map)
	var roads := reg.roads
	map.terrain[map.index_of(Vector2i(2, 0))] = TerrainDef.Type.HILL
	map.terrain[map.index_of(Vector2i(3, 0))] = TerrainDef.Type.FOREST
	map.wood[map.index_of(Vector2i(3, 0))] = 50.0
	map.terrain[map.index_of(Vector2i(4, 0))] = TerrainDef.Type.RIVER
	var p := roads.plan(_road_line(Vector2i(0, 0), Vector2i(5, 0)), reg)
	var expected := 3 * RoadNetwork.COST_PER_TILE + roundi(RoadNetwork.COST_PER_TILE * RoadNetwork.HILL_COST_FACTOR) \
		+ RoadNetwork.COST_PER_TILE + RoadNetwork.FOREST_EXTRA_COST + RoadNetwork.BRIDGE_COST
	_check(p.is_valid() and p.cost == expected, "coûts : plaine, colline, forêt, pont (%d)" % p.cost)
	_check(p.cleared == [Vector2i(3, 0)], "forêt à défricher")
	_check(not roads.plan(_road_line(Vector2i(0, 0), Vector2i(5, 0)), reg, p.cost - 1).is_valid(), "fonds insuffisants")
	roads.build(p)
	_check(roads.has_road(Vector2i(4, 0)) and roads.tile_count() == 6, "route construite")
	_check(map.get_terrain(Vector2i(3, 0)) == TerrainDef.Type.PLAIN and map.wood[map.index_of(Vector2i(3, 0))] == 0.0,
		"défrichement")
	var again := roads.plan(_road_line(Vector2i(0, 0), Vector2i(6, 0)), reg)
	_check(again.new_cells == [Vector2i(6, 0)] and again.cost == RoadNetwork.COST_PER_TILE, "routes existantes gratuites")
	_check(roads.plan(_road_line(Vector2i(0, 0), Vector2i(3, 0)), reg).error == "Déjà construit", "rien à construire")
	map.terrain[map.index_of(Vector2i(8, 8))] = TerrainDef.Type.SEA
	_check(not roads.plan(_road_line(Vector2i(7, 8), Vector2i(9, 8)), reg).is_valid(), "mer infranchissable")
	var lab := reg.place(reg.check_placement(BuildingDb.get_def(&"laboratory"), Vector2i(10, 2)))
	_check(not roads.plan(_road_line(Vector2i(9, 2), Vector2i(11, 2)), reg).is_valid(), "bâtiment sur le tracé")

	roads.add_cells(_road_line(Vector2i(0, 5), Vector2i(5, 5)))
	_check(roads.component_of(Vector2i(0, 0)) != roads.component_of(Vector2i(0, 5)), "deux réseaux séparés")
	_check(roads.path_between([Vector2i(0, 0)], [Vector2i(5, 5)]).is_empty(), "pas de chemin entre réseaux")
	roads.add_cells(_road_line(Vector2i(5, 1), Vector2i(5, 4)))
	_check(roads.component_of(Vector2i(0, 0)) == roads.component_of(Vector2i(0, 5)), "réseaux reliés")
	var path := roads.path_between([Vector2i(0, 0)], [Vector2i(0, 5)])
	_check(path.size() == 16 and path[0] == Vector2i(0, 0) and path[-1] == Vector2i(0, 5), "plus court chemin (%d)" % path.size())
	roads.remove(Vector2i(5, 3))
	_check(roads.component_of(Vector2i(0, 0)) != roads.component_of(Vector2i(0, 5)), "suppression → coupure")
	_check(roads.access_cells(lab).is_empty() and not roads.is_connected_building(lab), "labo non relié")
	roads.add_cells([Vector2i(10, 3)])
	_check(roads.access_cells(lab) == [Vector2i(10, 3)], "accès du labo")


## Petite région : forêts, bûcheron, centrale biomasse et dépôt le long
## d'une route (y = 4).
func _logistics_setup(map: WorldMap, reg: BuildingRegistry) -> Dictionary:
	reg.roads.add_cells(_road_line(Vector2i(0, 4), Vector2i(20, 4)))
	for x in range(0, 5):
		map.terrain[map.index_of(Vector2i(x, 2))] = TerrainDef.Type.FOREST
		map.wood[map.index_of(Vector2i(x, 2))] = WorldMap.WOOD_PER_FOREST
	return {
		lumberjack = _built(reg, &"lumberjack", Vector2i(2, 3)),
		plant = _built(reg, &"biomass_plant", Vector2i(14, 3)),
		depot = _built(reg, &"depot", Vector2i(8, 6)),
	}


func _test_logistics() -> void:
	var map := _flat_map(Vector2i(32, 32))
	var reg := BuildingRegistry.new(map)
	var prod := Production.new(reg)
	var lg := Logistics.new(reg)
	var s := _logistics_setup(map, reg)
	var lumberjack: Building = s.lumberjack
	var plant: Building = s.plant
	var depot: Building = s.depot
	var cart := VehicleDb.get_def(&"cart")
	var truck := VehicleDb.get_def(&"truck")
	_check(lg.distance(lumberjack, plant) == 11, "distance routière (%d)" % lg.distance(lumberjack, plant))
	_check(lg.buy_error(depot, cart).is_empty(), "achat possible")
	var v1 := lg.add_vehicle(depot, cart)
	var v2 := lg.add_vehicle(depot, truck)

	var tick := 0
	var delivered := 0.0
	var cost := 0.0
	var ran := false
	var seen_states := {}
	var consistent := true
	for i in 600:
		tick += 1
		prod.step(tick)
		var r := lg.step()
		delivered += r.delivered
		cost += r.travel_cost
		ran = ran or plant.status == Building.Status.RUNNING
		for v in lg.vehicles:
			seen_states[v.state] = true
		consistent = consistent and lumberjack.output_stock >= -0.0001 \
			and lumberjack.reserved_out <= lumberjack.output_stock + 0.0001 \
			and plant.input_stock + plant.reserved_in <= plant.def.buffer_capacity + 0.0001
	_check(delivered > 0.0 and ran, "bois livré, centrale en service (%s t)" % delivered)
	_check(cost > 0.0, "coût d'usage des véhicules")
	_check(seen_states.size() == Vehicle.State.size(), "toutes les étapes de mission parcourues")
	_check(consistent, "réservations cohérentes")
	_check(lg.daily_upkeep() == cart.upkeep_per_day + truck.upkeep_per_day, "entretien des véhicules")

	# Coupure de la route entre le bûcheron et la centrale.
	reg.roads.remove(Vector2i(10, 4))
	lg.on_networks_changed()
	_check(lg.distance(lumberjack, plant) == -1, "route coupée : injoignable")
	for i in 60:
		tick += 1
		prod.step(tick)
		lg.step()
	var before := plant.input_stock + plant.reserved_in
	var received := 0.0
	for i in 100:
		tick += 1
		prod.step(tick)
		received += lg.step().delivered
	_check(received == 0.0 and plant.reserved_in == 0.0, "plus de livraison vers la centrale isolée")
	_check(lumberjack.reserved_out == 0.0, "réservations libérées (%s)" % lumberjack.reserved_out)

	# Surplus vers l'entrepôt.
	var warehouse := _built(reg, &"warehouse", Vector2i(4, 5))
	var stored := 0.0
	for i in 200:
		tick += 1
		prod.step(tick)
		lg.step()
		stored = maxf(stored, warehouse.stored_total())
	_check(stored > 0.0 and warehouse.store.has(Goods.Type.WOOD), "surplus stocké en entrepôt")

	# L'entrepôt approvisionne une centrale.
	var plant2 := _built(reg, &"biomass_plant", Vector2i(7, 3))
	var fed := false
	for i in 200:
		tick += 1
		prod.step(tick)
		lg.step()
		fed = fed or plant2.input_stock > 0.0
	_check(fed, "centrale approvisionnée")

	# Revente et démolition du dépôt.
	var idle := lg.vehicles.filter(func(v: Vehicle) -> bool: return v.state == Vehicle.State.IDLE)
	if not idle.is_empty():
		_check(lg.sell(idle[0]) == floori(idle[0].def.cost * Logistics.SELL_REFUND), "revente")
	var busy := lg.vehicles.filter(func(v: Vehicle) -> bool: return v.state != Vehicle.State.IDLE)
	if not busy.is_empty():
		var v: Vehicle = busy[0]
		_check(lg.sell(v) == -1 and v.retiring and not v.is_available(), "en mission : vente différée")
		var sold := false
		for i in 200:
			tick += 1
			prod.step(tick)
			sold = sold or v in lg.step().sold
		_check(sold and v not in lg.vehicles, "vendu à son retour au dépôt")
	reg.remove(depot)
	lg.on_building_removed(depot)
	_check(lg.vehicles.is_empty(), "véhicules du dépôt démoli supprimés")
	_check(is_zero_approx(plant2.reserved_in) and is_zero_approx(warehouse.reserved_in)
		and is_zero_approx(lumberjack.reserved_out), "réservations libérées à la démolition")
	_check(v1 != v2, "deux véhicules distincts")


func _test_cities() -> void:
	var map := MapGenerator.generate(Vector2i(64, 64), 42)
	var reg := BuildingRegistry.new(map)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var cities := CityGenerator.populate(reg, rng)
	_check(cities.size() == 5, "5 villes sur 64×64 (%d)" % cities.size())
	var ok := true
	for b in cities:
		ok = ok and b.city != null and b.is_complete() and reg.building_at(b.anchor) == b
		ok = ok and b.city.base_demand >= CityGenerator.MIN_DEMAND and b.city.base_demand <= CityGenerator.MAX_DEMAND
		for o in cities:
			ok = ok and (o == b or (o.anchor - b.anchor).length() >= CityGenerator.MIN_SPACING)
		for cell in b.cells:
			ok = ok and map.get_terrain(cell) in CityGenerator.OPEN_TERRAINS
	_check(ok, "villes valides et espacées")
	var names := cities.map(func(b: Building) -> String: return b.city.name)
	_check(names.size() == 5 and not names.has(""), "villes nommées")
	var reg2 := BuildingRegistry.new(MapGenerator.generate(Vector2i(64, 64), 42))
	rng.seed = 7
	var again := CityGenerator.populate(reg2, rng)
	_check(again.map(func(b: Building) -> Vector2i: return b.anchor) == cities.map(func(b: Building) -> Vector2i: return b.anchor),
		"placement des villes reproductible")
	_check(again.map(func(b: Building) -> String: return b.city.name) == names, "noms des villes reproductibles")

	var city := City.new("Test", 10.0)
	var night := 3
	var evening_winter := GameDate.HOURS_PER_SEASON * 3 + 19
	_check(city.demand_at(evening_winter) > city.demand_at(night) * 2.0, "pic d'hiver en soirée")
	_check(is_equal_approx(city.demand_at(19), 13.0), "pic de printemps : 1,3 × base")
	city.served_hours_today = 24
	city.end_day()
	var served_growth := city.base_demand / 10.0 - 1.0
	var other := City.new("Autre", 10.0)
	other.end_day()
	_check(served_growth > 0.0 and other.base_demand / 10.0 - 1.0 < served_growth, "croissance plus forte si alimentée")
	_check(is_equal_approx(served_growth, City.GROWTH_SERVED / 120.0), "croissance annuelle répartie par jour")


func _add_city(reg: BuildingRegistry, anchor: Vector2i, demand: float) -> Building:
	var p := reg.check_placement(CityGenerator.CITY_DEF, anchor)
	_check(p.is_valid(), "ville en %s : %s" % [anchor, p.error])
	var b := reg.place(p)
	b.city = City.new("V%d" % b.id, demand)
	return b


func _test_grid() -> void:
	var map := _flat_map(Vector2i(32, 32))
	var reg := BuildingRegistry.new(map)
	var grid := reg.grid
	var prod := Production.new(reg)
	var a := _add_city(reg, Vector2i(12, 6), 5.0)
	var b := _add_city(reg, Vector2i(20, 6), 20.0)
	var plant := _built(reg, &"biomass_plant", Vector2i(5, 6))
	plant.input_stock = plant.def.buffer_capacity
	var tick := 10  # 10 h : facteur horaire 1,0
	grid.refresh_topology(reg)
	_check(plant.grid_id == 0 and a.city.supply == City.Supply.NOT_CONNECTED, "rien de raccordé")
	prod.step(tick)
	_check(plant.status == Building.Status.NO_GRID and plant.power_mw == 0.0, "centrale hors réseau à l'arrêt")
	_check(is_equal_approx(plant.input_stock, plant.def.buffer_capacity), "pas de combustible brûlé hors réseau")
	_check(reg.check_placement(BuildingDb.get_def(&"laboratory"), Vector2i(6, 7)).is_valid(), "case libre avant la ligne")

	# Ligne centrale → ville A.
	grid.add_cells(TilePlan.l_path(Vector2i(5, 7), Vector2i(12, 7)))
	_check(reg.check_placement(BuildingDb.get_def(&"laboratory"), Vector2i(6, 7)).error == "Ligne électrique présente",
		"pas de bâtiment sur une ligne")
	grid.refresh_topology(reg)
	_check(plant.grid_id != 0 and plant.grid_id == a.grid_id and b.grid_id == 0, "centrale et ville A raccordées")
	var net := grid.networks[plant.grid_id]
	_check(net.tiles == 8 and is_equal_approx(net.loss_ratio, 8 * PowerGrid.LOSS_PER_TILE), "pertes selon la longueur")
	grid.plan_setpoints(tick)
	var need := a.city.demand_at(tick) * (1.0 + PowerGrid.MARGIN) / (1.0 - net.loss_ratio)
	_check(is_equal_approx(plant.power_setpoint, need / plant.def.power_mw), "consigne = demande + pertes + marge")
	prod.step(tick)
	_check(is_equal_approx(plant.power_mw, need), "centrale modulée sur la demande")
	var r := grid.step(tick, reg)
	_check(a.city.supply == City.Supply.SERVED and is_equal_approx(r.delivered_mw, a.city.demand_at(tick)),
		"ville A alimentée")
	_check(is_equal_approx(r.price, grid.economy.price_at(tick))
		and is_equal_approx(r.revenue, r.delivered_mw * r.price * Economy.tariff(a.city.satisfaction))
		and r.penalty == 0.0, "vente au prix du marché")
	_check(r.renewable_sold_mw == 0.0, "rien de renouvelable")
	_check(a.city.served_hours_today == 1, "heure alimentée comptée")

	# Extension vers la ville B (trop gourmande) : délestage.
	grid.add_cells(TilePlan.l_path(Vector2i(13, 7), Vector2i(18, 7)))
	grid.refresh_topology(reg)
	_check(b.grid_id == plant.grid_id, "ville B raccordée")
	grid.plan_setpoints(tick + 1)
	_check(is_equal_approx(plant.power_setpoint, 1.0), "consigne plafonnée à pleine puissance")
	prod.step(tick + 1)
	r = grid.step(tick + 1, reg)
	_check(a.city.supply == City.Supply.SERVED and b.city.supply == City.Supply.SHED, "la petite ville servie, la grande délestée")
	_check(r.shed_cities == 1 and is_equal_approx(r.penalty, b.city.demand_at(tick + 1) * PowerGrid.PENALTY_PER_MWH),
		"pénalité de délestage")

	# Deux lignes reliées par un même bâtiment forment un seul réseau.
	grid.add_cells(TilePlan.l_path(Vector2i(3, 5), Vector2i(3, 2)))
	grid.refresh_topology(reg)
	_check(grid.network_at(Vector2i(3, 2)) == grid.network_at(Vector2i(10, 7)), "réseaux unis par la centrale")

	# Réseau isolé sans centrale.
	var c := _add_city(reg, Vector2i(26, 20), 6.0)
	grid.add_cells(TilePlan.l_path(Vector2i(24, 21), Vector2i(28, 21)))
	r = grid.step(tick + 2, reg)
	_check(c.city.supply == City.Supply.NO_SUPPLY and c.grid_id != plant.grid_id, "ville raccordée sans centrale")
	_check(r.shed_cities == 1 and is_equal_approx(r.penalty, b.city.demand_at(tick + 2) * PowerGrid.PENALTY_PER_MWH),
		"pas de pénalité sans centrale (seule la ville B est pénalisée)")

	# Éolienne : les renouvelables passent d'abord.
	map.wind[map.index_of(Vector2i(24, 22))] = 1.0
	var turbine := _built(reg, &"wind_turbine", Vector2i(24, 22))
	grid.refresh_topology(reg)
	_check(turbine.grid_id == c.grid_id, "éolienne raccordée")
	prod.step(tick + 3)
	r = grid.step(tick + 3, reg)
	_check(turbine.power_mw > 0.0 and r.produced_mw > plant.power_mw, "production éolienne comptée")

	# Sans ville, la centrale passe en veille.
	var lonely := _built(reg, &"biomass_plant", Vector2i(28, 28))
	lonely.input_stock = 10.0
	grid.add_cells([Vector2i(29, 28)])
	grid.refresh_topology(reg)
	grid.plan_setpoints(tick + 4)
	prod.step(tick + 4)
	_check(lonely.status == Building.Status.STANDBY and is_equal_approx(lonely.input_stock, 10.0), "veille sans demande")


## Cas d'usage de base : deux bûcherons, une centrale biomasse à une dizaine
## de tuiles et un dépôt avec ses véhicules de départ doivent suffire.
func _test_transport_throughput() -> void:
	var map := _flat_map(Vector2i(32, 32))
	var reg := BuildingRegistry.new(map)
	var prod := Production.new(reg)
	var lg := Logistics.new(reg)
	reg.roads.add_cells(_road_line(Vector2i(0, 4), Vector2i(20, 4)))
	for x in range(0, 8):
		map.terrain[map.index_of(Vector2i(x, 2))] = TerrainDef.Type.FOREST
		map.wood[map.index_of(Vector2i(x, 2))] = WorldMap.WOOD_PER_FOREST
	var j1 := _built(reg, &"lumberjack", Vector2i(2, 3))
	var j2 := _built(reg, &"lumberjack", Vector2i(5, 3))
	var plant := _built(reg, &"biomass_plant", Vector2i(16, 3))
	_check(lg.diagnose(j1).contains("dépôt"), "diagnostic : pas de dépôt (%s)" % lg.diagnose(j1))
	_check(lg.diagnose(plant).contains("dépôt"), "diagnostic côté centrale")
	var depot := _built(reg, &"depot", Vector2i(10, 6))
	for id in depot.def.starting_vehicles:
		lg.add_vehicle(depot, VehicleDb.get_def(id))
	_check(lg.diagnose(j1).is_empty(), "diagnostic : rien à signaler (%s)" % lg.diagnose(j1))
	var running := 0
	for t in 600:
		prod.step(t)
		lg.step()
		if t >= 200 and plant.status == Building.Status.RUNNING and plant.activity > 0.99:
			running += 1
	_check(running >= 360, "centrale approvisionnée en continu (%d / 400 h)" % running)
	_check(j1.output_stock < j1.def.buffer_capacity and j2.output_stock < j2.def.buffer_capacity,
		"le bois ne s'entasse pas chez les bûcherons")
	map.terrain[map.index_of(Vector2i(25, 19))] = TerrainDef.Type.FOREST
	var isolated := _built(reg, &"lumberjack", Vector2i(25, 20))
	reg.roads.add_cells([Vector2i(26, 20)])
	_check(lg.diagnose(isolated).contains("joignable"), "diagnostic : route isolée (%s)" % lg.diagnose(isolated))


func _test_tech_data() -> void:
	var ids := {}
	var errors := PackedStringArray()
	for def in TechDb.DEFS:
		if ids.has(def.id):
			errors.append("doublon " + def.id)
		ids[def.id] = def
		if TechDb.get_def(def.id) != def:
			errors.append("get_def " + def.id)
		if def.start_known != (def.cost == 0):
			errors.append("coût / départ incohérents " + def.id)
		for key in def.modifiers:
			if not TechDef.MODIFIER_NAMES.has(key):
				errors.append("modificateur inconnu %s (%s)" % [key, def.id])
	for def in TechDb.DEFS:
		for p in def.prerequisites:
			if not ids.has(p):
				errors.append("prérequis inconnu %s → %s" % [def.id, p])
			elif ids[p].era > def.era:
				errors.append("prérequis d'une ère postérieure %s → %s" % [def.id, p])
			elif TechDb.DEFS.find(ids[p]) > TechDb.DEFS.find(def):
				errors.append("ordre : %s avant son prérequis %s" % [def.id, p])
	for def in BuildingDb.DEFS:
		if def.required_tech != &"" and not ids.has(def.required_tech):
			errors.append("bâtiment %s : technologie inconnue %s" % [def.id, def.required_tech])
	for def in VehicleDb.DEFS:
		if def.required_tech != &"" and not ids.has(def.required_tech):
			errors.append("véhicule %s : technologie inconnue %s" % [def.id, def.required_tech])
	_check(errors.is_empty(), "arbre technologique cohérent %s" % errors)
	_check(TechDb.DEFS.size() >= 25 and TechDb.DEFS.any(func(d: TechDef) -> bool: return d.era == 7),
		"arbre complet jusqu'à la fusion")
	_check(Research.unlocks_of(&"coal_plant") == PackedStringArray(["Centrale à charbon"]), "déblocages listés")


func _test_research() -> void:
	var r := Research.new(TechDb.DEFS)
	_check(r.is_known(&"woodcutting") and r.is_known(&"biomass") and r.is_known(&""), "technologies de départ")
	_check(not r.is_known(&"mining") and r.is_available(&"prospecting") and not r.is_available(&"mining"),
		"disponibilité selon les prérequis")
	var done := r.add_points(100.0)
	_check(done.is_empty() and is_equal_approx(r.bank, 100.0), "points en banque sans recherche")
	r.enqueue(&"steam")
	_check(r.queue == [&"prospecting", &"mining", &"steam"], "prérequis mis en file (%s)" % [r.queue])
	_check(is_equal_approx(r.progress, 100.0) and r.bank == 0.0, "banque versée à la tête de file")
	done = r.add_points(500.0 + 900.0 + 50.0)
	_check(done.map(func(d: TechDef) -> StringName: return d.id) == [&"prospecting", &"mining"], "deux technologies achevées")
	_check(is_equal_approx(r.progress, 50.0) and r.current().id == &"steam", "reliquat sur la suivante")
	_check(is_equal_approx(r.modifier(&"extraction"), 1.1) and r.modifier(&"fuel_use") == 1.0, "modificateurs acquis")
	r.enqueue(&"coal_plant")
	r.dequeue(&"steam")
	_check(r.queue.is_empty() and is_equal_approx(r.bank, 50.0), "retrait : dépendants retirés, points rendus")
	r.enqueue(&"trucks")
	_check(r.current().id == &"trucks" and is_equal_approx(r.progress, 50.0), "file reprise avec la banque")
	r.add_points(10000.0)
	_check(r.is_known(&"trucks") and r.queue.is_empty() and r.bank > 0.0, "file vidée, surplus en banque")
	var r2 := Research.new(TechDb.DEFS)
	for id in [&"hv_lines", &"transformers"]:
		r2.known[id] = true
	_check(is_equal_approx(r2.modifier(&"grid_loss"), 0.36), "modificateurs cumulés")


func _test_laboratory() -> void:
	var map := _flat_map(Vector2i(24, 24))
	var reg := BuildingRegistry.new(map)
	var grid := reg.grid
	var prod := Production.new(reg)
	var lab := _built(reg, &"laboratory", Vector2i(10, 10))
	var r := prod.step(1)
	_check(lab.status == Building.Status.NO_POWER and r.research == 0.0, "labo sans électricité")
	var plant := _built(reg, &"biomass_plant", Vector2i(10, 13))
	plant.input_stock = plant.def.buffer_capacity
	grid.add_cells([Vector2i(10, 11)])
	grid.refresh_topology(reg)
	_check(lab.grid_id == plant.grid_id and grid.networks[lab.grid_id].loads == [lab], "labo raccordé comme charge")
	grid.plan_setpoints(2)
	_check(plant.power_setpoint > 0.0, "la centrale alimente le labo")
	prod.step(2)
	var g := grid.step(2, reg)
	_check(lab.powered and g.revenue == 0.0 and is_equal_approx(g.delivered_mw, lab.def.power_demand_mw),
		"labo alimenté, consommation propre non vendue")
	prod.research_factor = 1.5
	r = prod.step(3)
	_check(lab.status == Building.Status.RUNNING and is_equal_approx(r.research, lab.def.research_per_hour * 1.5),
		"labo : points de recherche × modificateur")
	prod.fuel_factor = 0.5
	plant.power_setpoint = 1.0
	var before := plant.input_stock
	prod.step(4)
	_check(is_equal_approx(before - plant.input_stock, plant.def.input_per_hour * 0.5), "vapeur : moins de combustible")


## Revente de véhicules en mission (remplacement de la flotte).
func _test_vehicle_sale() -> void:
	var map := _flat_map(Vector2i(32, 32))
	var reg := BuildingRegistry.new(map)
	var prod := Production.new(reg)
	var lg := Logistics.new(reg)
	var s := _logistics_setup(map, reg)
	var lumberjack: Building = s.lumberjack
	var plant: Building = s.plant
	var depot: Building = s.depot
	var cart := VehicleDb.get_def(&"cart")
	for i in depot.def.vehicle_slots:
		lg.add_vehicle(depot, cart)
	_check(not lg.buy_error(depot, cart).is_empty(), "dépôt complet")
	lumberjack.output_stock = lumberjack.def.buffer_capacity
	var tick := 0
	# Un véhicule part livrer ; on avance jusqu'à ce qu'il soit chargé.
	var loaded_v: Vehicle = lg.vehicles[0]
	_check(lg._start(loaded_v, lumberjack, plant, Goods.Type.WOOD, 5.0), "mission lancée")
	for i in 100:
		tick += 1
		lg.step()
		if loaded_v.state == Vehicle.State.TO_DESTINATION:
			break
	# Un autre part tout juste, à vide.
	var empty_v: Vehicle = null
	for v in lg.vehicles:
		if empty_v == null and v.is_available():
			empty_v = v
	lumberjack.output_stock = lumberjack.def.buffer_capacity
	_check(empty_v != null and lg._start(empty_v, lumberjack, plant, Goods.Type.WOOD, 5.0), "seconde mission lancée")
	_check(empty_v != null and loaded_v != null, "un véhicule vide et un chargé en mission")
	var reserved := lumberjack.reserved_out
	_check(lg.sell(empty_v) == -1 and empty_v.state == Vehicle.State.RETURNING and empty_v.source == null,
		"vide : mission abandonnée, retour au dépôt")
	_check(lumberjack.reserved_out < reserved, "réservation libérée")
	_check(lg.buy_error(depot, cart).is_empty(), "la place du véhicule à vendre est libérée")
	var cargo := loaded_v.cargo
	_check(lg.sell(loaded_v) == -1 and loaded_v.state == Vehicle.State.TO_DESTINATION, "chargé : il livre d'abord")
	var before := plant.input_stock
	var sold: Array[Vehicle] = []
	var delivered := 0.0
	for i in 300:
		tick += 1
		var r := lg.step()
		delivered += r.delivered
		sold.append_array(r.sold)
	_check(empty_v in sold and loaded_v in sold, "les deux vendus à leur retour")
	_check(delivered >= cargo and plant.input_stock > before, "chargement livré avant la vente")
	_check(lg.vehicles.size() == depot.def.vehicle_slots - 2, "flotte réduite de deux")


func _test_rail() -> void:
	var map := _flat_map(Vector2i(48, 16))
	map.terrain[map.index_of(Vector2i(20, 12))] = TerrainDef.Type.RIVER
	map.terrain[map.index_of(Vector2i(21, 12))] = TerrainDef.Type.SEA
	var reg := BuildingRegistry.new(map)
	var rails := reg.rails
	_check(rails.tile_cost(Vector2i(0, 0)) == RailNetwork.RAIL_COST_PER_TILE, "voie : coût en plaine")
	_check(rails.tile_cost(Vector2i(20, 12)) == RailNetwork.RAIL_BRIDGE_COST, "voie : pont")
	_check(rails.tile_cost(Vector2i(21, 12)) < 0, "voie : mer infranchissable")
	reg.roads.add_cells(_road_line(Vector2i(0, 4), Vector2i(12, 4)))
	reg.roads.add_cells(_road_line(Vector2i(30, 4), Vector2i(46, 4)))
	var crossing := rails.plan(TilePlan.l_path(Vector2i(14, 3), Vector2i(14, 5)), reg)
	_check(crossing.is_valid(), "voie : passage à niveau possible (%s)" % crossing.error)
	var station_def := BuildingDb.get_def(&"station")
	_check(reg.check_placement(station_def, Vector2i(12, 6)).error.contains("voie ferrée"),
		"gare : voie ferrée requise")
	rails.add_cells(RoadNetwork.l_path(Vector2i(11, 7), Vector2i(36, 7)))
	_check(rails.tile_count() == 26 and rails.daily_upkeep() == 26 * RailNetwork.RAIL_UPKEEP_PER_TILE_PER_DAY,
		"voie : tuiles et entretien")
	_check(reg.check_placement(BuildingDb.get_def(&"warehouse"), Vector2i(20, 7)).error == "Voie ferrée présente",
		"pas de bâtiment sur une voie")

	# Ouest : bûcherons → gare A ; est : gare B → centrale ; pas de route entre les deux.
	var prod := Production.new(reg)
	var lg := Logistics.new(reg)
	for y in [1, 2]:
		for x in range(0, 8):
			map.terrain[map.index_of(Vector2i(x, y))] = TerrainDef.Type.FOREST
			map.wood[map.index_of(Vector2i(x, y))] = WorldMap.WOOD_PER_FOREST
	_built(reg, &"lumberjack", Vector2i(2, 3))
	_built(reg, &"lumberjack", Vector2i(5, 3))
	var depot_w := _built(reg, &"depot", Vector2i(10, 6))
	var station_a := _built(reg, &"station", Vector2i(12, 6))
	var station_b := _built(reg, &"station", Vector2i(36, 6))
	var depot_e := _built(reg, &"depot", Vector2i(40, 6))
	var plant := _built(reg, &"biomass_plant", Vector2i(44, 3))
	for depot: Building in [depot_w, depot_e]:
		for id in depot.def.starting_vehicles:
			lg.add_vehicle(depot, VehicleDb.get_def(id))
	var train_def := VehicleDb.get_def(&"train")
	_check(not lg.buy_error(station_a, VehicleDb.get_def(&"cart")).is_empty(), "pas de charrette en gare")
	_check(not lg.buy_error(depot_w, train_def).is_empty(), "pas de train au dépôt")
	_check(lg.buy_error(station_a, train_def).is_empty(), "train achetable en gare")
	_check(lg.diagnose(station_b).contains("aucun train"), "diagnostic : aucun train (%s)" % lg.diagnose(station_b))
	_check(lg.distance(station_a, plant) < 0 and lg.distance(station_a, station_b, rails) > 0,
		"gares reliées par le rail seulement")
	var train := lg.add_vehicle(station_a, train_def)
	_check(lg.diagnose(station_b).is_empty(), "diagnostic gare : rien à signaler (%s)" % lg.diagnose(station_b))
	var off_track := 0
	var train_deliveries := 0
	var running := 0
	var max_load := 0.0
	for t in 1500:
		prod.step(t)
		var was_unloading := train.state == Vehicle.State.UNLOADING
		lg.step()
		if train.state in [Vehicle.State.TO_SOURCE, Vehicle.State.TO_DESTINATION, Vehicle.State.RETURNING] \
				and not rails.has_rail(train.current_cell()):
			off_track += 1
		if was_unloading and train.state != Vehicle.State.UNLOADING:
			train_deliveries += 1
		max_load = maxf(max_load, train.cargo)
		if t >= 900 and plant.status == Building.Status.RUNNING:
			running += 1
	_check(off_track == 0, "le train reste sur la voie (%d)" % off_track)
	_check(train_deliveries >= 2, "le train livre la gare B (%d fois)" % train_deliveries)
	_check(max_load >= train_def.capacity * Logistics.FULL_LOAD_RATIO, "chargements groupés (%.1f t)" % max_load)
	_check(running >= 300, "centrale approvisionnée par le rail (%d / 600 h)" % running)
	_check(station_a.store_reserved_out.get(Goods.Type.WOOD, 0.0) >= 0.0 and station_b.reserved_in >= 0.0,
		"réservations cohérentes")
	# Voie coupée en route : le train ne la quitte pas.
	rails.remove(Vector2i(24, 7))
	lg.on_networks_changed()
	_check(lg.distance(station_a, station_b, rails) < 0, "voie coupée : gares séparées")
	for t in 50:
		lg.step()
		if train.state != Vehicle.State.IDLE and not train.path.is_empty() \
				and not rails.has_rail(train.current_cell()):
			off_track += 1
	_check(off_track == 0, "voie coupée : le train reste sur la voie")


func _test_nuclear() -> void:
	_check(Goods.is_hazardous(Goods.Type.NUCLEAR_FUEL) and Goods.is_hazardous(Goods.Type.NUCLEAR_WASTE)
		and not Goods.is_hazardous(Goods.Type.URANIUM_ORE), "matières dangereuses")
	var map := _flat_map(Vector2i(40, 12))
	map.water_access.fill(1)
	map.deposit[map.index_of(Vector2i(3, 3))] = WorldMap.Deposit.URANIUM
	map.deposit_amount[map.index_of(Vector2i(3, 3))] = 5000.0
	var reg := BuildingRegistry.new(map)
	var prod := Production.new(reg)
	var lg := Logistics.new(reg)
	reg.roads.add_cells(_road_line(Vector2i(0, 4), Vector2i(38, 4)))
	var mine := _built(reg, &"uranium_mine", Vector2i(3, 3))
	var enrich := _built(reg, &"enrichment_plant", Vector2i(8, 3))
	enrich.powered = true
	var warehouse := _built(reg, &"warehouse", Vector2i(12, 3))
	var plant := _built(reg, &"nuclear_plant", Vector2i(18, 3))
	var depot := _built(reg, &"depot", Vector2i(14, 6))
	var cart := VehicleDb.get_def(&"cart")
	var armored := VehicleDb.get_def(&"armored_truck")
	lg.add_vehicle(depot, cart)
	lg.add_vehicle(depot, cart)
	var probe := Vehicle.new(0, armored, depot)
	_check(Logistics.can_carry(probe, Goods.Type.NUCLEAR_WASTE) and not Logistics.can_carry(probe, Goods.Type.COAL),
		"camion blindé : matières dangereuses seulement")
	_check(not Logistics.can_carry(lg.vehicles[0], Goods.Type.NUCLEAR_FUEL), "charrette : pas de combustible")
	_check(lg.diagnose(plant).contains("site de stockage"), "diagnostic : pas de site de déchets (%s)" % lg.diagnose(plant))
	var site := _built(reg, &"waste_site", Vector2i(24, 3))
	_check(lg.diagnose(enrich).contains("blindé"), "diagnostic : pas de camion blindé (%s)" % lg.diagnose(enrich))
	lg.add_vehicle(depot, armored)
	lg.add_vehicle(depot, armored)
	_check(lg.diagnose(enrich).is_empty(), "diagnostic : rien à signaler (%s)" % lg.diagnose(enrich))
	var misrouted := 0
	var stored_hazard := 0.0
	var powered_hours := 0
	for t in 1500:
		prod.step(t)
		lg.step()
		for v in lg.vehicles:
			if v.cargo > 0.0 and Goods.is_hazardous(v.good) != v.def.armored:
				misrouted += 1
		stored_hazard = maxf(stored_hazard, warehouse.store.get(Goods.Type.NUCLEAR_FUEL, 0.0)
			+ warehouse.store.get(Goods.Type.NUCLEAR_WASTE, 0.0))
		if plant.power_mw > 0.0:
			powered_hours += 1
	_check(misrouted == 0, "chaque véhicule ne porte que ce qu'il peut (%d)" % misrouted)
	_check(stored_hazard == 0.0, "pas de matière dangereuse en entrepôt")
	_check(warehouse.store.get(Goods.Type.URANIUM_ORE, 0.0) >= 0.0 and mine.status != Building.Status.DEPLETED,
		"mine en service")
	_check(powered_hours >= 800, "centrale nucléaire alimentée (%d / 1500 h)" % powered_hours)
	_check(site.input_stock > 10.0, "déchets évacués vers le site (%.1f t)" % site.input_stock)

	# Stock de déchets plein : centrale à l'arrêt, consigne nulle.
	plant.output_stock = plant.def.buffer_capacity
	plant.input_stock = plant.def.buffer_capacity
	prod.step(2000)
	_check(plant.status == Building.Status.OUTPUT_FULL and plant.power_mw == 0.0, "déchets pleins : arrêt")
	_check(PowerGrid._fuel_fraction(plant, 1.0) == 0.0, "déchets pleins : aucune puissance planifiée")
	plant.output_stock = 0.0
	prod.waste_factor = 0.5
	prod.step(2001)
	_check(is_equal_approx(plant.output_stock, plant.def.output_per_hour * 0.5), "Gestion des déchets : moitié moins")


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


## Déroule [param hours] heures de production et de réseau à partir de
## [param from] ; renvoie les heures de délestage et l'énergie stockée/restituée.
func _run_hours(reg: BuildingRegistry, prod: Production, from: int, hours: int) -> Dictionary:
	var result := {"shed": 0, "charged": 0.0, "discharged": 0.0}
	for t in range(from, from + hours):
		prod.step(t)
		var r := reg.grid.step(t, reg)
		result.shed += r.shed_cities
		result.charged += r.charged_mwh
		result.discharged += r.discharged_mwh
	return result


func _test_renewables() -> void:
	var map := _flat_map(Vector2i(32, 32))
	map.sun.fill(0.9)
	var reg := BuildingRegistry.new(map)
	var prod := Production.new(reg)
	var grid := reg.grid

	# Solaire PV : rien la nuit, produit le jour.
	var farm := _built(reg, &"solar_farm", Vector2i(5, 5))
	prod.step(2)
	_check(farm.status == Building.Status.NIGHT and farm.power_mw == 0.0, "ferme solaire à l'arrêt la nuit")
	prod.step(13)
	_check(farm.status == Building.Status.RUNNING and farm.power_mw > 0.0
		and is_equal_approx(farm.power_mw, farm.def.power_mw * 0.9 * prod.weather.sun_at(13)), "ferme solaire le jour")

	# Prévision : la centrale pilotable s'efface devant le soleil de midi.
	var city := _add_city(reg, Vector2i(20, 5), 8.0)
	var plant := _built(reg, &"biomass_plant", Vector2i(12, 5))
	plant.input_stock = plant.def.buffer_capacity
	grid.add_cells(TilePlan.l_path(Vector2i(6, 5), Vector2i(19, 5)))
	grid.refresh_topology(reg)
	_check(farm.grid_id != 0 and farm.grid_id == city.grid_id and plant.grid_id == city.grid_id, "réseau solaire raccordé")
	grid.plan_setpoints(2)
	var night_setpoint := plant.power_setpoint
	grid.plan_setpoints(12)
	_check(plant.power_setpoint < night_setpoint, "consigne réduite quand le soleil est prévu")

	# Solaire thermique : produit aussi la nuit avec la chaleur stockée.
	var map2 := _flat_map(Vector2i(32, 32))
	map2.sun.fill(0.9)
	var reg2 := BuildingRegistry.new(map2)
	var prod2 := Production.new(reg2)
	var csp := _built(reg2, &"solar_thermal_plant", Vector2i(6, 6))
	var town := _add_city(reg2, Vector2i(14, 6), 6.0)
	reg2.grid.add_cells(TilePlan.l_path(Vector2i(7, 5), Vector2i(13, 5)))
	reg2.grid.refresh_topology(reg2)
	_check(csp.grid_id != 0 and csp.grid_id == town.grid_id, "solaire thermique raccordé")
	var night_power := 0.0
	var capped := true
	for t in 72:
		prod2.step(t)
		reg2.grid.step(t, reg2)
		capped = capped and csp.stored_mwh <= csp.def.storage_mwh + 0.001
		if t >= 24 and Weather.is_night(t):
			night_power += csp.power_mw
	_check(night_power > 0.0, "solaire thermique produit la nuit (%.1f MWh)" % night_power)
	_check(capped, "chaleur stockée plafonnée")

	# Offshore : en mer, au contact de la côte, raccordée depuis la terre.
	var sea := _flat_map(Vector2i(32, 16))
	for y in 16:
		for x in range(20, 32):
			sea.terrain[sea.index_of(Vector2i(x, y))] = TerrainDef.Type.SEA
			sea.wind[sea.index_of(Vector2i(x, y))] = 0.85
	var reg3 := BuildingRegistry.new(sea)
	var offshore := BuildingDb.get_def(&"offshore_wind")
	_check(reg3.check_placement(offshore, Vector2i(10, 8)).error == "Doit être construit en mer", "offshore : pas sur terre")
	_check(reg3.check_placement(offshore, Vector2i(25, 8)).error.begins_with("Doit toucher la côte"), "offshore : au contact de la côte")
	_check(reg3.check_placement(offshore, Vector2i(20, 8)).error.begins_with("Nécessite un port"), "offshore : port requis")
	reg3.roads.add_cells(_road_line(Vector2i(14, 2), Vector2i(19, 2)))
	_built(reg3, &"port", Vector2i(19, 4))
	_check(not reg3.check_placement(offshore, Vector2i(20, 15 + 5)).is_valid(), "offshore : port trop loin")
	var mill := _built(reg3, &"offshore_wind", Vector2i(20, 8))
	var port_town := _add_city(reg3, Vector2i(12, 8), 3.0)
	reg3.grid.add_cells(TilePlan.l_path(Vector2i(13, 8), Vector2i(19, 8)))
	reg3.grid.refresh_topology(reg3)
	_check(mill.grid_id != 0 and mill.grid_id == port_town.grid_id, "éolienne offshore raccordée par la côte")
	var prod3 := Production.new(reg3)
	var energy := 0.0
	for t in 24:
		prod3.step(t)
		energy += mill.power_mw
	_check(energy > 0.0, "éolienne offshore produit")

	# STEP : près de l'eau et du relief.
	var hills := _flat_map(Vector2i(16, 16))
	hills.water_access[hills.index_of(Vector2i(5, 5))] = 1
	var reg4 := BuildingRegistry.new(hills)
	var step_def := BuildingDb.get_def(&"pumped_storage")
	_check(not reg4.check_placement(step_def, Vector2i(5, 5)).is_valid(), "STEP : relief requis")
	hills.terrain[hills.index_of(Vector2i(6, 5))] = TerrainDef.Type.HILL
	_check(reg4.check_placement(step_def, Vector2i(5, 5)).is_valid(), "STEP : eau et colline")
	_check(not reg4.check_placement(step_def, Vector2i(10, 10)).is_valid(), "STEP : eau requise")


## Batteries : chargent le surplus solaire du jour et évitent les coupures
## du soir.
func _test_storage() -> void:
	var results := []
	for with_battery in [false, true]:
		var map := _flat_map(Vector2i(32, 32))
		map.sun.fill(0.9)
		var reg := BuildingRegistry.new(map)
		var prod := Production.new(reg)
		_built(reg, &"solar_farm", Vector2i(5, 5))
		var city := _add_city(reg, Vector2i(20, 5), 1.5)
		reg.grid.add_cells(TilePlan.l_path(Vector2i(6, 5), Vector2i(19, 5)))
		var battery: Building = null
		if with_battery:
			battery = _built(reg, &"battery", Vector2i(10, 6))
		reg.grid.refresh_topology(reg)
		if battery:
			_check(battery.grid_id == city.grid_id, "batterie raccordée")
		var r := _run_hours(reg, prod, 0, 72)
		if battery:
			_check(battery.stored_mwh <= battery.def.storage_mwh + 0.001, "batterie plafonnée")
			_check(r.charged > 0.0 and r.discharged > 0.0, "batterie chargée le jour, déchargée ensuite")
			_check(r.discharged <= r.charged * battery.def.storage_efficiency + 0.001, "rendement de la batterie respecté")
		results.append(r)
	_check(results[1].shed < results[0].shed, "moins de coupures avec la batterie (%d < %d h)" % [results[1].shed, results[0].shed])


## Barges : bûcherons à l'ouest d'un lac, centrale à l'est, reliés seulement
## par l'eau entre deux ports.
func _test_ports() -> void:
	var map := _flat_map(Vector2i(48, 16))
	for y in 16:
		for x in range(17, 30):
			map.terrain[map.index_of(Vector2i(x, y))] = TerrainDef.Type.LAKE
	var reg := BuildingRegistry.new(map)
	var waters := reg.waters
	_check(waters.is_navigable(Vector2i(20, 3)) and not waters.is_navigable(Vector2i(10, 3)), "lac navigable, terre non")
	_check(waters.tile_count() == 13 * 16 and waters.daily_upkeep() == 0, "voies navigables gratuites")
	reg.roads.add_cells(_road_line(Vector2i(0, 4), Vector2i(16, 4)))
	reg.roads.add_cells(_road_line(Vector2i(30, 4), Vector2i(46, 4)))
	var port_def := BuildingDb.get_def(&"port")
	_check(reg.check_placement(port_def, Vector2i(12, 6)).error.contains("eau navigable"), "port : au bord de l'eau")
	var prod := Production.new(reg)
	var lg := Logistics.new(reg)
	for y in [1, 2]:
		for x in range(0, 8):
			map.terrain[map.index_of(Vector2i(x, y))] = TerrainDef.Type.FOREST
			map.wood[map.index_of(Vector2i(x, y))] = WorldMap.WOOD_PER_FOREST
	_built(reg, &"lumberjack", Vector2i(2, 3))
	_built(reg, &"lumberjack", Vector2i(5, 3))
	var depot_w := _built(reg, &"depot", Vector2i(10, 6))
	var port_a := _built(reg, &"port", Vector2i(16, 6))
	var port_b := _built(reg, &"port", Vector2i(31, 6))
	var depot_e := _built(reg, &"depot", Vector2i(40, 6))
	var plant := _built(reg, &"biomass_plant", Vector2i(44, 3))
	for depot: Building in [depot_w, depot_e]:
		for id in depot.def.starting_vehicles:
			lg.add_vehicle(depot, VehicleDb.get_def(id))
	var barge_def := VehicleDb.get_def(&"barge")
	_check(lg.buy_error(depot_w, barge_def) == "Les barges s'achètent au port", "pas de barge au dépôt")
	_check(not lg.buy_error(port_a, VehicleDb.get_def(&"train")).is_empty(), "pas de train au port")
	_check(lg.buy_error(port_a, barge_def).is_empty(), "barge achetable au port")
	_check(lg.diagnose(port_b).contains("aucune barge"), "diagnostic : aucune barge (%s)" % lg.diagnose(port_b))
	_check(lg.distance(port_a, plant) < 0 and lg.distance(port_a, port_b, waters) > 0,
		"ports reliés par l'eau seulement")
	var barge := lg.add_vehicle(port_a, barge_def)
	_check(lg.diagnose(port_b).is_empty(), "diagnostic port : rien à signaler (%s)" % lg.diagnose(port_b))
	var on_land := 0
	var deliveries := 0
	var running := 0
	for t in 1500:
		prod.step(t)
		var was_unloading := barge.state == Vehicle.State.UNLOADING
		lg.step()
		if barge.state in [Vehicle.State.TO_SOURCE, Vehicle.State.TO_DESTINATION, Vehicle.State.RETURNING] \
				and not waters.is_navigable(barge.current_cell()):
			on_land += 1
		if was_unloading and barge.state != Vehicle.State.UNLOADING:
			deliveries += 1
		if t >= 900 and plant.status == Building.Status.RUNNING:
			running += 1
	_check(on_land == 0, "la barge reste sur l'eau (%d)" % on_land)
	_check(deliveries >= 2, "la barge livre le port B (%d fois)" % deliveries)
	_check(running >= 300, "centrale approvisionnée par barge (%d / 600 h)" % running)
	_check(lg.diagnose(port_a).is_empty(), "diagnostic port A : rien à signaler (%s)" % lg.diagnose(port_a))


func _test_pollution() -> void:
	var map := _flat_map(Vector2i(48, 48))
	var reg := BuildingRegistry.new(map)
	var pol := Pollution.new(reg)
	map.water_access.fill(1)
	map.deposit[map.index_of(Vector2i(30, 30))] = WorldMap.Deposit.COAL
	map.deposit_amount[map.index_of(Vector2i(30, 30))] = 100.0
	var plant := _built(reg, &"coal_plant", Vector2i(10, 10))
	var mine := _built(reg, &"coal_mine", Vector2i(30, 30))
	plant.status = Building.Status.RUNNING
	plant.activity = 0.5
	mine.status = Building.Status.RUNNING
	mine.activity = 1.0
	_check(is_equal_approx(pol.emission_of(plant), plant.def.emission_per_hour * 0.5), "émission selon l'activité")
	pol.filter_factor = 0.5
	_check(is_equal_approx(pol.emission_of(plant), plant.def.emission_per_hour * 0.25)
		and is_equal_approx(pol.emission_of(mine), mine.def.emission_per_hour), "filtres CO₂ : centrales seulement")
	pol.filter_factor = 1.0
	plant.status = Building.Status.STANDBY
	_check(pol.emission_of(plant) == 0.0, "pas d'émission en veille")
	plant.status = Building.Status.RUNNING
	plant.activity = 1.0
	var e := pol.step()
	_check(is_equal_approx(e, plant.def.emission_per_hour + mine.def.emission_per_hour), "émissions de l'heure")
	_check(is_equal_approx(pol.level_at(Vector2i(10, 10)), plant.def.emission_per_hour), "pleine valeur sur l'emprise")
	_check(pol.level_at(Vector2i(10 + 4, 10)) < pol.level_at(Vector2i(10 + 1, 10))
		and pol.level_at(Vector2i(10 + Pollution.RADIUS + 1, 10)) == 0.0, "dispersion décroissante et bornée")
	for i in 300:
		pol.step()
	var steady := plant.def.emission_per_hour / (1.0 - Pollution.RETENTION)
	_check(absf(pol.level_at(Vector2i(10, 10)) - steady) < steady * 0.01, "équilibre émission / dissipation")
	var near := pol.air_quality([Vector2i(14, 10)] as Array[Vector2i])
	var far := pol.air_quality([Vector2i(10, 40)] as Array[Vector2i])
	_check(near < 0.5 and is_equal_approx(far, 1.0), "air pollué près de la centrale (%.2f), pur au loin" % near)
	plant.status = Building.Status.STANDBY
	mine.status = Building.Status.IDLE
	var before := pol.level_at(Vector2i(10, 10))
	pol.step()
	_check(is_equal_approx(pol.level_at(Vector2i(10, 10)), before * Pollution.RETENTION), "dissipation sans émission")

	# Villes : la pollution freine la croissance et pèse sur la satisfaction.
	var clean := City.new("Propre", 10.0)
	var dirty := City.new("Polluée", 10.0)
	for c: City in [clean, dirty]:
		for d in 20:
			c.served_hours_today = 24
			c.end_day(1.0 if c == clean else 0.0)
	_check(dirty.base_demand < clean.base_demand, "croissance freinée par la pollution")
	_check(clean.satisfaction > 0.95 and absf(dirty.satisfaction - City.SATISFACTION_SUPPLY_WEIGHT) < 0.05,
		"satisfaction : alimentation et air (%.2f / %.2f)" % [clean.satisfaction, dirty.satisfaction])
	var dark := City.new("Sans courant", 10.0)
	dark.end_day(1.0)
	_check(dark.satisfaction < 0.5, "satisfaction en baisse sans courant")


func _test_economy() -> void:
	var eco := Economy.new(42)
	var total := 0.0
	var low := INF
	var high := 0.0
	for tick in GameDate.HOURS_PER_YEAR:
		var p := eco.price_at(tick)
		total += p
		low = minf(low, p)
		high = maxf(high, p)
	var mean := total / GameDate.HOURS_PER_YEAR
	_check(absf(mean - Economy.BASE_PRICE) < Economy.BASE_PRICE * 0.05, "prix moyen ≈ prix de base (%.2f)" % mean)
	_check(low < Economy.BASE_PRICE * 0.75 and high > Economy.BASE_PRICE * 1.3, "prix entre %.1f et %.1f" % [low, high])
	_check(eco.price_at(19) > eco.price_at(3), "pointe du soir plus chère que la nuit")
	_check(Economy.new(42).price_at(1234) == eco.price_at(1234), "prix déterministe")
	var y := GameDate.HOURS_PER_YEAR
	_check(Economy.carbon_tax_at(0) == 0.0 and Economy.carbon_tax_at(y) == Economy.CARBON_TAX_STEP
		and Economy.carbon_tax_at(30 * y) == Economy.CARBON_TAX_MAX, "taxe carbone croissante et plafonnée")
	_check(Economy.subsidy_at(0) == Economy.SUBSIDY_START and Economy.subsidy_at(y) < Economy.SUBSIDY_START
		and Economy.subsidy_at(30 * y) == Economy.SUBSIDY_MIN, "subvention décroissante et plancher")
	_check(is_equal_approx(Economy.tariff(0.5), 1.0) and Economy.tariff(1.0) == Economy.TARIFF_MAX
		and Economy.tariff(0.0) == Economy.TARIFF_MIN, "tarif selon la satisfaction")

	# Comptes : subvention sur la part renouvelable, taxe sur les émissions.
	var report := PowerGrid.Report.new()
	report.revenue = 100.0
	report.penalty = 5.0
	report.renewable_sold_mw = 10.0
	var tick := 2 * y
	var net := eco.settle_hour(tick, report, 20.0, 3.0)
	var expected := 100.0 + 10.0 * Economy.subsidy_at(tick) - 5.0 - 20.0 * Economy.carbon_tax_at(tick) - 3.0
	_check(is_equal_approx(net, expected), "solde de l'heure")
	eco.end_day(50.0)
	_check(is_equal_approx(eco.yesterday.net(), expected - 50.0) and eco.today.sales == 0.0, "clôture du jour")

	# Réseau mixte : la part vendue renouvelable suit la part produite.
	var map := _flat_map(Vector2i(32, 32))
	var reg := BuildingRegistry.new(map)
	var grid := reg.grid
	var prod := Production.new(reg)
	map.wind.fill(1.0)
	var city := _add_city(reg, Vector2i(16, 6), 5.0)
	var plant := _built(reg, &"biomass_plant", Vector2i(5, 6))
	plant.input_stock = plant.def.buffer_capacity
	var turbine := _built(reg, &"wind_turbine", Vector2i(5, 9))
	grid.add_cells(TilePlan.l_path(Vector2i(5, 7), Vector2i(16, 7)))
	grid.add_cells([Vector2i(5, 8)])
	grid.refresh_topology(reg)
	_check(turbine.grid_id == city.grid_id and plant.grid_id == city.grid_id, "réseau mixte raccordé")
	tick = 10
	grid.plan_setpoints(tick)
	prod.step(tick)
	var r := grid.step(tick, reg)
	var share := turbine.power_mw / (turbine.power_mw + plant.power_mw)
	_check(turbine.power_mw > 0.0 and is_equal_approx(r.renewable_sold_mw, r.sold_mw * share),
		"part renouvelable vendue (%.0f %%)" % (share * 100.0))
	city.city.satisfaction = 1.0
	grid.plan_setpoints(tick)
	prod.step(tick)
	var happy := grid.step(tick, reg)
	_check(is_equal_approx(happy.revenue, happy.sold_mw * happy.price * Economy.TARIFF_MAX), "ville comblée : tarif majoré")
