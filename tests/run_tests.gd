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
	_test_annex()
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
	_test_production()
	_test_forest_cycle()
	_test_irrigation()
	_test_auto_priorities()
	_test_power_meter()
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
			and counts.stone >= StartSite.MIN_STONE and counts.farmland > 0,
			"graine %d : forêt, plaine, eau et collines %s (%d retouches)" % [seed_value, counts, changed.size()])
	var flat := WorldMap.new(Vector2i(64, 64), 0, FlatGenerator.new(Vector2i(64, 64)))
	var rect := StartSite.territory_rect(Vector2i(20, 20))
	var changed := StartSite.ensure(flat, rect)
	var counts := StartSite._counts(rect, func(c: Vector2i) -> int: return flat.get_terrain(c))
	_check(changed.size() == StartSite.MIN_FOREST + StartSite.MIN_STONE + 1 and counts.water == 1
		and counts.forest == StartSite.MIN_FOREST and counts.stone == StartSite.MIN_STONE,
		"plaine nue : forêt, lac et collines ajoutés %s" % counts)


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
	_check(e.revealed > 0 and territory.count(Territory.State.EXPLORED) == territory.known_cells().size() - 64,
		"tuiles révélées comptées (%d)" % e.revealed)
	_check(territory.state_at(home) == Territory.State.TERRITORY, "le territoire reste territoire")
	# Cible atteinte avec des vivres en trop.
	e = exploration.launch(home, Vector2i(10, 4), 1, 20.0)
	while not exploration.expeditions.is_empty():
		exploration.step_hour()
	_check(e.reason == Exploration.Reason.TARGET and e.food > 15.0, "objectif atteint, vivres rapportés (%.1f)" % e.food)


func _test_annex() -> void:
	var flat := _flat_map()
	var territory: Territory = flat[1]
	var explored: Array[Vector2i] = []
	for y in 12:
		for x in range(8, 12):
			explored.append(Vector2i(x, y))
	explored.append(Vector2i(20, 20))
	territory.explore(explored)
	var plan := territory.plan_annex(Rect2i(8, 0, 2, 8), 100)
	_check(plan.cells.size() == 16 and plan.refused == 0, "rectangle exploré au bord du territoire : annexable")
	plan = territory.plan_annex(Rect2i(8, 0, 2, 12), 100)
	_check(plan.cells.size() == 24, "de proche en proche au-delà du bord (%d)" % plan.cells.size())
	plan = territory.plan_annex(Rect2i(8, 0, 2, 8), 5)
	_check(plan.cells.size() == 5 and plan.refused == 11 and plan.cells.all(func(c: Vector2i) -> bool: return c.x == 8),
		"limite : les plus proches de la frontière d'abord")
	plan = territory.plan_annex(Rect2i(19, 19, 3, 3), 100)
	_check(plan.cells.is_empty() and plan.refused == 9, "isolée ou inconnue : refusée (%s)" % plan.error)
	territory.annex(territory.plan_annex(Rect2i(8, 0, 1, 1), 100).cells)
	_check(territory.is_territory(Vector2i(8, 0)), "tuile annexée")


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
	_check(is_equal_approx(pop.wood_need(0), 5.0) and is_equal_approx(pop.wood_need(GameDate.WINTER), 10.0),
		"bois : 0,2 par habitant, double en hiver")


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
	stock.capacity = PackedFloat32Array([100.0, 50.0, 100.0])
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
	var cleared: Array[Vector2i] = []
	for h in 24 * 30:
		cleared.append_array(prod.step_hour(h, stock).cleared)
		if not cleared.is_empty():
			break
	_check(cleared == [cell] and map.get_terrain(cell) == TerrainDef.Type.PLAIN and zones.zone_at(cell) == null,
		"coupe à blanc : plaine, zone retirée")
	_check(absf(stock.amount[1] - wood_before - 10.0) < 0.01, "tout le bois de la tuile récolté (%.3f)" % (stock.amount[1] - wood_before))
	labor.step(24 * 30, 1)
	var regrown: Array[Vector2i] = []
	for d in Production.CLEARCUT_REGROW_DAYS:
		regrown.append_array(prod.end_day(0))
	_check(regrown == [cell] and map.get_terrain(cell) == TerrainDef.Type.FOREST and map.get_wood(cell) > 0.0,
		"repousse après %d jours sans zone" % Production.CLEARCUT_REGROW_DAYS)
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
