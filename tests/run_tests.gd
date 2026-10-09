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
	_check(reg.check_placement(warehouse, Vector2i(1, 0)).is_valid(), "entrepôt 2×1 en (0..1, 0)")

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
	return b


func _test_production() -> void:
	var map := _flat_map(Vector2i(32, 32))
	var reg := BuildingRegistry.new(map)
	var prod := Production.new(reg)
	var tick := 0

	# Chaîne bois : deux forêts, un bûcheron, une centrale biomasse.
	for c in [Vector2i(2, 1), Vector2i(3, 1)]:
		map.terrain[map.index_of(c)] = TerrainDef.Type.FOREST
		map.wood[map.index_of(c)] = 30.0
	var lumberjack := _built(reg, &"lumberjack", Vector2i(2, 2))
	var plant := _built(reg, &"biomass_plant", Vector2i(6, 6))
	var site := reg.place(reg.check_placement(BuildingDb.get_def(&"laboratory"), Vector2i(10, 10)))
	tick += 1
	var r := prod.step(tick)
	_check(lumberjack.status == Building.Status.RUNNING and is_equal_approx(lumberjack.output_stock, 1.5),
		"bûcheron : 1,5 t la première heure")
	_check(plant.status == Building.Status.NO_INPUT and r.power_mw == 0.0, "centrale sans bois à l'arrêt")
	_check(site.status == Building.Status.CONSTRUCTION, "chantier signalé")
	_check(is_equal_approx(map.wood[map.index_of(Vector2i(2, 1))], 28.5), "forêt la plus proche coupée d'abord")
	tick += 1
	r = prod.step(tick)
	_check(is_equal_approx(plant.input_stock, 1.5 - 0.5 * 3.0) and plant.status == Building.Status.RUNNING,
		"livraison directe puis combustion partielle")
	_check(is_equal_approx(r.power_mw, 8.0 * 0.5), "puissance proportionnelle au combustible")
	var depleted := false
	while tick < 200:
		tick += 1
		r = prod.step(tick)
		depleted = depleted or Vector2i(2, 1) in r.changed_cells
	_check(depleted and map.get_terrain(Vector2i(2, 1)) == TerrainDef.Type.PLAIN, "forêt épuisée → plaine")
	_check(lumberjack.status == Building.Status.DEPLETED, "bûcheron sans forêt : ressource épuisée")
	_check(map.wood[map.index_of(Vector2i(3, 1))] == 0.0, "les deux forêts coupées")
	_check(plant.status == Building.Status.NO_INPUT and plant.input_stock == 0.0, "centrale à court de bois")
	_check(lumberjack.output_stock == 0.0, "tout le bois livré")

	# Stock de sortie plein sans client à portée.
	map.terrain[map.index_of(Vector2i(25, 1))] = TerrainDef.Type.FOREST
	map.wood[map.index_of(Vector2i(25, 1))] = WorldMap.WOOD_PER_FOREST
	var lonely := _built(reg, &"lumberjack", Vector2i(25, 2))
	_check(Production.footprint_distance(lonely, plant) > Production.DELIVERY_RADIUS, "hors de portée")
	for i in 20:
		tick += 1
		prod.step(tick)
	_check(lonely.status == Building.Status.OUTPUT_FULL
		and is_equal_approx(lonely.output_stock, lonely.def.buffer_capacity), "sortie pleine → arrêt")

	# Chaîne charbon : gisement, mine, centrale près de l'eau.
	var coal := Vector2i(20, 20)
	map.deposit[map.index_of(coal)] = WorldMap.Deposit.COAL
	map.deposit_amount[map.index_of(coal)] = 10.0
	map.deposit[map.index_of(Vector2i(21, 20))] = WorldMap.Deposit.COAL
	map.deposit_amount[map.index_of(Vector2i(21, 20))] = 2.0
	map.water_access[map.index_of(Vector2i(24, 24))] = 1
	var mine := _built(reg, &"coal_mine", coal)
	var coal_plant := _built(reg, &"coal_plant", Vector2i(24, 24))
	_check(prod.suppliers_of(coal_plant) == [mine], "mine fournisseur de la centrale")
	_check(prod.suppliers_of(plant) == [lumberjack], "bûcheron lointain exclu des fournisseurs")
	var gone := false
	for i in 10:
		tick += 1
		r = prod.step(tick)
		gone = gone or coal in r.changed_cells
	_check(gone and map.deposit[map.index_of(coal)] == WorldMap.Deposit.NONE, "gisement épuisé")
	_check(map.deposit[map.index_of(Vector2i(21, 20))] == WorldMap.Deposit.NONE, "gisement voisin exploité")
	_check(mine.status == Building.Status.DEPLETED, "mine épuisée")
	_check(coal_plant.status == Building.Status.NO_INPUT, "centrale à charbon à court")

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
