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
	_test_cities()
	_test_grid()
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

	# Éolienne : puissance × vent.
	map.wind[map.index_of(Vector2i(15, 28))] = 0.8
	var turbine := _built(reg, &"wind_turbine", Vector2i(15, 28))
	tick += 1
	prod.step(tick)
	_check(is_equal_approx(turbine.power_mw, turbine.def.power_mw * 0.8), "éolienne × vent")

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
	lg.on_roads_changed()
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
		_check(lg.sell(busy[0]) == -1, "pas de revente en mission")
	reg.remove(depot)
	var removed := lg.on_building_removed(depot)
	_check(lg.vehicles.is_empty() and not removed.is_empty(), "véhicules du dépôt démoli supprimés")
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
	_check(is_equal_approx(r.revenue, r.delivered_mw * PowerGrid.PRICE_PER_MWH) and r.penalty == 0.0, "vente")
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
