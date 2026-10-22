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
	_test_weather()
	_test_statistics()
	_test_milestones()
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
	var map := _flat_map()
	var reg := BuildingRegistry.new(map)
	var small := _def()
	var big := _def(Vector2i(2, 2))
	var wide := _def(Vector2i(2, 1))

	_check(reg.check_placement(small, Vector2i(2, 2)).is_valid(), "plaine libre : valide")
	_check(not reg.check_placement(big, Vector2i(0, 3)).is_valid(), "emprise hors carte")
	_check(not reg.check_placement(wide, Vector2i(0, 3)).is_valid(), "2×1 hors carte à x=0")
	_check(reg.check_placement(wide, Vector2i(1, 0)).is_valid(), "2×1 en (0..1, 0)")

	map.terrain[map.index_of(Vector2i(3, 3))] = TerrainDef.Type.MOUNTAIN
	_check(not reg.check_placement(small, Vector2i(3, 3)).is_valid(), "montagne non constructible")
	map.terrain[map.index_of(Vector2i(3, 3))] = TerrainDef.Type.HILL
	_check(reg.check_placement(small, Vector2i(3, 3)).is_valid(), "colline constructible")
	var plain_only := _def()
	plain_only.allowed_terrains = [TerrainDef.Type.PLAIN]
	_check(not reg.check_placement(plain_only, Vector2i(3, 3)).is_valid(), "terrain non autorisé")

	var near_forest := _def()
	near_forest.adjacent_terrains = [TerrainDef.Type.FOREST]
	_check(not reg.check_placement(near_forest, Vector2i(5, 5)).is_valid(), "pas de forêt voisine")
	map.terrain[map.index_of(Vector2i(6, 6))] = TerrainDef.Type.FOREST
	_check(reg.check_placement(near_forest, Vector2i(5, 5)).is_valid(), "forêt voisine (diagonale)")
	var on_forest := reg.check_placement(small, Vector2i(6, 6))
	_check(on_forest.is_valid() and on_forest.cleared == [Vector2i(6, 6)], "forêt à défricher")
	_check(not reg.check_placement(near_forest, Vector2i(6, 6)).is_valid(),
		"la forêt de l'emprise ne compte pas comme voisine")

	var wet := _def(Vector2i(2, 2))
	wet.needs_water_access = true
	_check(not reg.check_placement(wet, Vector2i(7, 1)).is_valid(), "sans eau")
	map.water_access[map.index_of(Vector2i(6, 0))] = 1
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
	var reg := BuildingRegistry.new(_flat_map())
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


func _test_statistics() -> void:
	var stats := Statistics.new()
	stats.series[&"test"] = PackedFloat32Array()
	_check(stats.last(&"test") == 0.0, "série vide : 0")
	stats.add(&"test", 2.0)
	stats.add(&"test", 3.0)
	stats.end_day()
	stats.end_day()
	_check(stats.days == 2 and stats.values(&"test") == PackedFloat32Array([5.0, 0.0]),
		"une valeur par jour clos (somme des heures)")


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
