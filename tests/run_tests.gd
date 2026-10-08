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
