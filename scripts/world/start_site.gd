class_name StartSite
extends RefCounted
## Choix du site du village : un territoire de départ de TERRITORY_SIZE ×
## TERRITORY_SIZE tuiles aux latitudes tempérées, avec forêt, terres
## cultivables, un point d'eau, une colline à pierre près du centre pour les
## carrières du village, un gisement de fer pour ses mines et un filon de
## charbon pour celles du bourg (garantis par ensure).

const TERRITORY_SIZE := 12
const MIN_FOREST := 10
## Plaines et prairies.
const MIN_FARMLAND := 40
## Rivière, lac ou mer.
const MIN_WATER := 1
## Collines ou montagnes (carrières du village), à STONE_RADIUS tuiles au
## plus du centre ; à défaut, un bloc de STONE_BLOCK × STONE_BLOCK collines
## est placé à cette distance.
const MIN_STONE := 4
const STONE_RADIUS := 4
const STONE_BLOCK := 2
## Tuiles de fer (mines du village) à IRON_MIN_DISTANCE–IRON_RADIUS tuiles du
## centre (hors des bâtiments de départ) ; à défaut, un gisement de IRON_AMOUNT
## tonnes par tuile est placé à cette distance.
const MIN_IRON := 2
const IRON_MIN_DISTANCE := 3
const IRON_RADIUS := 5
const IRON_AMOUNT := 30000.0
## Tuiles de charbon (mines du bourg) à COAL_MIN_DISTANCE–COAL_RADIUS tuiles
## du centre, de COAL_AMOUNT tonnes chacune à défaut.
const MIN_COAL := 2
const COAL_MIN_DISTANCE := 4
const COAL_RADIUS := 5
const COAL_AMOUNT := 40000.0
## Tuiles de pétrole (puits de la ville) à OIL_MIN_DISTANCE–OIL_RADIUS tuiles
## du centre, de OIL_AMOUNT tonnes chacune à défaut.
const MIN_OIL := 4
const OIL_MIN_DISTANCE := 4
const OIL_RADIUS := 6
const OIL_AMOUNT := 10000.0
## Tuiles de cuivre (mines de la ville) à COPPER_MIN_DISTANCE–COPPER_RADIUS
## tuiles du centre, de COPPER_AMOUNT tonnes chacune à défaut.
const MIN_COPPER := 2
const COPPER_MIN_DISTANCE := 4
const COPPER_RADIUS := 6
const COPPER_AMOUNT := 20000.0
## Tuiles de pierre (carrières hors des collines) à STONE_DEPOSIT_MIN_DISTANCE–
## STONE_DEPOSIT_RADIUS tuiles du centre, avec STONE_DEPOSIT_AMOUNT de pierre.
const MIN_STONE_DEPOSIT := 6
const STONE_DEPOSIT_MIN_DISTANCE := 4
const STONE_DEPOSIT_RADIUS := 8
const STONE_DEPOSIT_AMOUNT := 30000.0
## Terrains où placer le fer et le charbon, par préférence (forêt et collines avant les
## terres cultivables).
const IRON_TERRAINS: Array[int] = [T.FOREST, T.HILL, T.TUNDRA, T.PRAIRIE, T.PLAIN]
const MIN_BUILDABLE := 100
## Latitudes (valeur absolue, degrés) explorées pour le départ.
const MIN_LATITUDE := 20.0
const MAX_LATITUDE := 55.0
const MAX_TRIES := 400

const T := TerrainDef.Type


## Tuiles du territoire de départ centré sur [param center].
static func territory_rect(center: Vector2i) -> Rect2i:
	return Rect2i(center - Vector2i.ONE * (TERRITORY_SIZE / 2), Vector2i.ONE * TERRITORY_SIZE)


## Centre du village : premier site tiré au hasard (selon la graine) qui
## remplit tous les critères, à défaut le meilleur.
static func find(generator: MapGenerator) -> Vector2i:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([generator.seed_value, "start"])
	var size := generator.size
	var best := Vector2i.ZERO
	var best_shortfall := INF
	for k in MAX_TRIES:
		var lat := rng.randf_range(MIN_LATITUDE, MAX_LATITUDE) * (1.0 if rng.randf() < 0.5 else -1.0)
		var center := Vector2i(rng.randi_range(0, size.x - 1), int((90.0 - lat) / 180.0 * size.y))
		var counts := _counts(territory_rect(center), func(c: Vector2i) -> int: return generator.fields(c).terrain)
		var shortfall := _shortfall(counts)
		if shortfall < best_shortfall:
			best = center
			best_shortfall = shortfall
		if shortfall == 0.0:
			break
	return best


## Complète le territoire [param rect] de [param map] s'il manque de forêt,
## d'eau, de collines ou de fer près du centre (après find) ; renvoie les tuiles
## modifiées.
static func ensure(map: WorldMap, rect: Rect2i) -> Array[Vector2i]:
	var changed: Array[Vector2i] = []
	var counts := _counts(rect, func(c: Vector2i) -> int: return map.get_terrain(c))
	var farmland: Array[Vector2i] = []
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if map.get_terrain(Vector2i(x, y)) in [T.PLAIN, T.PRAIRIE]:
				farmland.append(Vector2i(x, y))
	if counts.water < MIN_WATER and not farmland.is_empty():
		var cell: Vector2i = farmland.pop_front()
		map.set_terrain(cell, T.LAKE)
		changed.append(cell)
	for k in maxi(0, MIN_FOREST - counts.forest):
		if farmland.is_empty():
			break
		var cell: Vector2i = farmland.pop_back()
		map.set_terrain(cell, T.FOREST)
		map.set_wood(cell, WorldMap.WOOD_PER_FOREST * 0.7)
		changed.append(cell)
	changed.append_array(_ensure_stone(map, rect))
	for c in _ensure_deposit(map, rect, WorldMap.Deposit.IRON, MIN_IRON, IRON_MIN_DISTANCE, IRON_RADIUS, IRON_AMOUNT) \
			+ _ensure_deposit(map, rect, WorldMap.Deposit.COAL, MIN_COAL, COAL_MIN_DISTANCE, COAL_RADIUS, COAL_AMOUNT) \
			+ _ensure_deposit(map, rect, WorldMap.Deposit.OIL, MIN_OIL, OIL_MIN_DISTANCE, OIL_RADIUS, OIL_AMOUNT) \
			+ _ensure_deposit(map, rect, WorldMap.Deposit.COPPER, MIN_COPPER, COPPER_MIN_DISTANCE, COPPER_RADIUS, COPPER_AMOUNT) \
			+ _ensure_deposit(map, rect, WorldMap.Deposit.STONE, MIN_STONE_DEPOSIT, STONE_DEPOSIT_MIN_DISTANCE, STONE_DEPOSIT_RADIUS,
				STONE_DEPOSIT_AMOUNT):
		if c not in changed:
			changed.append(c)
	return changed


## Colline à pierre près du centre de [param rect] : si moins de MIN_STONE
## collines ou montagnes à STONE_RADIUS tuiles, un bloc de collines sur des
## terres basses (plaine, prairie, forêt) à cette distance, côté le plus libre.
static func _ensure_stone(map: WorldMap, rect: Rect2i) -> Array[Vector2i]:
	var center := rect.position + rect.size / 2
	var near := 0
	for dy in range(-STONE_RADIUS, STONE_RADIUS + 1):
		for dx in range(-STONE_RADIUS, STONE_RADIUS + 1):
			var t := map.get_terrain(center + Vector2i(dx, dy))
			if t == T.HILL or t == T.MOUNTAIN:
				near += 1
	if near >= MIN_STONE:
		return []
	var lowland: Array[int] = [T.PLAIN, T.PRAIRIE, T.FOREST]
	var r := STONE_RADIUS - STONE_BLOCK + 1
	for origin: Vector2i in [Vector2i(r, -1), Vector2i(-r - 1, -1), Vector2i(-1, r), Vector2i(-1, -r - 1),
			Vector2i(r, r), Vector2i(-r - 1, -r - 1), Vector2i(r, -r - 1), Vector2i(-r - 1, r)]:
		var block: Array[Vector2i] = []
		for y in STONE_BLOCK:
			for x in STONE_BLOCK:
				block.append(center + origin + Vector2i(x, y))
		if block.all(func(c: Vector2i) -> bool: return map.get_terrain(c) in lowland):
			for c in block:
				map.set_terrain(c, T.HILL)
			return block
	return []


## Gisement [param kind] près du centre de [param rect] : si moins de
## [param minimum] tuiles dans l'anneau [param min_distance]–[param radius],
## complète par des tuiles voisines de cet anneau (terrain préféré, puis
## distance au centre), de [param amount] tonnes chacune.
static func _ensure_deposit(map: WorldMap, rect: Rect2i, kind: WorldMap.Deposit, minimum: int, min_distance: int,
		radius: int, amount: float) -> Array[Vector2i]:
	var center := rect.position + rect.size / 2
	var ring: Array[Vector2i] = []
	var found := 0
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var cell := center + Vector2i(dx, dy)
			if maxi(absi(dx), absi(dy)) < min_distance or not rect.has_point(cell):
				continue
			if map.get_deposit(cell) == kind:
				found += 1
			elif map.get_deposit(cell) == WorldMap.Deposit.NONE and map.get_terrain(cell) in IRON_TERRAINS:
				ring.append(cell)
	var missing := minimum - found
	if missing <= 0 or ring.is_empty():
		return []
	var rank := func(c: Vector2i) -> int:
		var d := c - center
		return IRON_TERRAINS.find(map.get_terrain(c)) * 100 + maxi(absi(d.x), absi(d.y)) * 10 + absi(d.x) + absi(d.y)
	ring.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return rank.call(a) < rank.call(b) or rank.call(a) == rank.call(b) and (a.y < b.y or a.y == b.y and a.x < b.x))
	# Un seul filon : les tuiles suivantes touchent les précédentes si possible.
	var placed: Array[Vector2i] = [ring.pop_front()]
	while placed.size() < missing and not ring.is_empty():
		var next := ring[0]
		for c in ring:
			if placed.any(func(p: Vector2i) -> bool: return maxi(absi(c.x - p.x), absi(c.y - p.y)) == 1):
				next = c
				break
		ring.erase(next)
		placed.append(next)
	for c in placed:
		map.set_deposit(c, kind, amount)
	return placed


## Nombre de tuiles par catégorie dans [param rect], selon [param terrain_of].
static func _counts(rect: Rect2i, terrain_of: Callable) -> Dictionary:
	var counts := {forest = 0, farmland = 0, water = 0, stone = 0, buildable = 0}
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var t: int = terrain_of.call(Vector2i(x, y))
			if t == T.FOREST:
				counts.forest += 1
			elif t == T.PLAIN or t == T.PRAIRIE:
				counts.farmland += 1
			elif t in [T.RIVER, T.LAKE, T.SEA]:
				counts.water += 1
			elif t == T.HILL or t == T.MOUNTAIN:
				counts.stone += 1
			if TerrainDb.get_def(t).buildable:
				counts.buildable += 1
	return counts


## Écart aux critères (0 : site valide).
static func _shortfall(counts: Dictionary) -> float:
	return maxf(0, MIN_FOREST - counts.forest) + maxf(0, MIN_FARMLAND - counts.farmland) \
		+ 10.0 * maxf(0, MIN_WATER - counts.water) + maxf(0, MIN_BUILDABLE - counts.buildable)
