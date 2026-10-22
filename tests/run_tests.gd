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
	_check(found.size() == WorldMap.Deposit.size() - 1, "les 6 gisements existent (%d)" % found.size())

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
		_check(counts.forest >= StartSite.MIN_FOREST and counts.water >= StartSite.MIN_WATER
			and counts.farmland > 0, "graine %d : forêt, plaine et eau %s (%d retouches)" % [seed_value, counts, changed.size()])
	var flat := WorldMap.new(Vector2i(64, 64), 0, FlatGenerator.new(Vector2i(64, 64)))
	var rect := StartSite.territory_rect(Vector2i(20, 20))
	var changed := StartSite.ensure(flat, rect)
	var counts := StartSite._counts(rect, func(c: Vector2i) -> int: return flat.get_terrain(c))
	_check(changed.size() == StartSite.MIN_FOREST + 1 and counts.water == 1 and counts.forest == StartSite.MIN_FOREST,
		"plaine nue : forêt et lac ajoutés %s" % counts)


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
	_check(territory.known_deposit(a) == WorldMap.Deposit.IRON and territory.is_territory(a),
		"gisement révélé par la prospection, état conservé")
	_check(not territory.is_prospected(Vector2i(30, 30)), "pas de prospection d'une tuile inconnue")


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
