class_name Production
extends RefCounted
## Production des zones : rendement de chaque tuile occupée = travailleurs ×
## rendement de base × qualité × facteur de saison × proximité du village.
## La coupe du bois vide la forêt (coupe à blanc : la tuile devient plaine et
## garde sa zone de coupe, sans bois jusqu'à la repousse) ; une forêt entamée
## se densifie hors exploitation, une coupe à blanc sans bâtiment ni autre zone
## que la coupe du bois redevient forêt. Cultiver use la fertilité,
## qui se reconstitue au repos. Avec la recherche Irrigation, les champs
## proches d'une rivière ou d'un lac rendent davantage. Pure donnée.

## Fertilité perdue par jour par un champ cultivé (avec récolte), regagnée
## par jour au repos jusqu'à sa valeur naturelle.
const FERTILITY_WEAR_PER_DAY := 0.0015
const FERTILITY_RECOVERY_PER_DAY := 0.003
## Bois regagné par jour par une forêt entamée hors exploitation.
const FOREST_REGROWTH_PER_DAY := 1.5
## Jours pour qu'une coupe à blanc redevienne forêt, et son bois à ce moment.
const CLEARCUT_REGROW_DAYS := 120
const REGROWN_WOOD := 60.0
## Irrigation : bonus des champs à IRRIGATION_RANGE tuiles ou moins (distance
## de Tchebychev) d'une rivière, d'un lac ou d'un puits.
const IRRIGATION_BONUS := 1.3
const IRRIGATION_RANGE := 3
const FRESH_WATER: Array[TerrainDef.Type] = [TerrainDef.Type.RIVER, TerrainDef.Type.LAKE]
## Inventions du village (recherches) : bonus de rendement.
const SAW_BONUS := 1.4
const PLOUGH_HARNESSED_BONUS := 1.3
const PLOUGH_BONUS := 1.1
const ROTATION_BONUS := 1.15
const GEARS_BONUS := 1.15
## Bourg : laine des troupeaux (fibres par éleveur et par jour, en plus de la
## nourriture).
const WOOL_PER_WORKER := 0.25


class Report:
	## Tuiles qui ont perdu leur zone (gisement épuisé) pendant l'heure.
	var cleared: Array[Vector2i] = []
	## Tuiles devenues plaine (coupe à blanc, zone gardée) pendant l'heure.
	var clearcut: Array[Vector2i] = []


var map: WorldMap
var zones: ZoneMap
var labor: Labor
var buildings: BuildingRegistry
## Recherches terminées (irrigation) ; null : aucune.
var research: Research
## Chevaux attelés (distance des tuiles desservies) ; null : aucun.
var draft: DraftAnimals
## Production du jour en cours, par marchandise (Stockpile.Good).
var produced_today := Stockpile.zeros()
## Valeur naturelle des fertilités entamées, bois maximal des forêts entamées
## et jours écoulés depuis les coupes à blanc (tuiles ramenées sur la planète).
var _natural_fertility: Dictionary[Vector2i, float] = {}
var _forest_max: Dictionary[Vector2i, float] = {}
var _clearcuts: Dictionary[Vector2i, int] = {}
## Outils en stock (scies, charrues) : sans eux, leurs bonus disparaissent.
var tools_ok := true
## Bonus du meilleur moulin (à grain) en service sur les champs de céréales
## (0 : aucun moulin).
var mill_bonus := 0.0
## Bonus de la coupe du bois des scieries (le meilleur ; 0 : aucune) et de la
## force motrice des moulins à eau.
var sawmill_bonus := 0.0
var drive_bonus := 0.0
## Laine des pâturages (à partir du bourg).
var wool := false
## Tuiles irrigables par une rivière ou un lac déjà calculées (l'eau douce ne
## bouge pas).
var _irrigable: Dictionary[Vector2i, bool] = {}
## Tuiles (ramenées sur la planète) des puits en service, sources d'irrigation.
var wells: Array[Vector2i] = []


func _init(p_zones: ZoneMap, p_labor: Labor) -> void:
	zones = p_zones
	labor = p_labor
	map = zones.map
	buildings = zones.buildings


## Production par jour de [param workers] travailleurs sur [param cell] de la
## zone [param def] pendant la saison [param season].
func tile_rate(def: ZoneDef, cell: Vector2i, workers: int, season: int) -> float:
	return workers * def.base_yield * def.quality_at(map, cell) * def.season_factors[season] \
		* proximity(cell) * irrigation_factor(def, cell) * invention_factor(def, cell)


func _done(id: StringName) -> bool:
	return research != null and research.is_done(id)


## Bonus des inventions du village pour [param def] sur [param cell] (1 :
## aucun) : scie (coupe du bois), charrue, assolement et moulin (champs),
## engrenage (carrières), moulins (céréales seulement), moulin à eau (coupe
## du bois). Scie et charrue demandent des outils en stock.
func invention_factor(def: ZoneDef, cell: Vector2i) -> float:
	var factor := 1.0
	match def.quality:
		ZoneDef.Quality.FERTILITY:
			if _done(&"plough") and tools_ok:
				var harnessed := draft != null and draft.harnessed.has(map.wrap_cell(cell))
				factor *= PLOUGH_HARNESSED_BONUS if harnessed else PLOUGH_BONUS
			if _done(&"crop_rotation"):
				factor *= ROTATION_BONUS
			if def.output == Stockpile.Good.FOOD:
				factor *= 1.0 + mill_bonus
		ZoneDef.Quality.WOOD:
			if _done(&"tools") and tools_ok:
				factor *= SAW_BONUS
			factor *= (1.0 + sawmill_bonus) * (1.0 + drive_bonus)
	if def.output == Stockpile.Good.STONE and _done(&"gears"):
		factor *= GEARS_BONUS
	return factor


## Facteur de proximité du village de [param cell] (trajets), meilleur sur
## une tuile desservie par un attelage.
func proximity(cell: Vector2i) -> float:
	var d := labor.distance(cell)
	if draft and draft.harnessed.has(map.wrap_cell(cell)):
		return draft.distance_factor(d)
	return Labor.distance_factor(d)


## Bonus d'irrigation de la zone [param def] sur [param cell] (1 : aucun).
func irrigation_factor(def: ZoneDef, cell: Vector2i) -> float:
	if def.quality != ZoneDef.Quality.FERTILITY or research == null or not research.is_done(&"irrigation"):
		return 1.0
	return IRRIGATION_BONUS if is_irrigable(cell) else 1.0


## Rivière, lac ou puits à IRRIGATION_RANGE tuiles ou moins de [param cell].
func is_irrigable(cell: Vector2i) -> bool:
	var c := map.wrap_cell(cell)
	for w in wells:
		var dx := absi(posmod(w.x - c.x + map.size.x / 2, map.size.x) - map.size.x / 2)
		if maxi(dx, absi(w.y - c.y)) <= IRRIGATION_RANGE:
			return true
	if not _irrigable.has(c):
		var found := false
		for dy in range(-IRRIGATION_RANGE, IRRIGATION_RANGE + 1):
			for dx in range(-IRRIGATION_RANGE, IRRIGATION_RANGE + 1):
				var n := cell + Vector2i(dx, dy)
				if map.has_cell(n) and map.get_terrain(n) in FRESH_WATER:
					found = true
		_irrigable[c] = found
	return _irrigable[c]


## Production prévue par jour de la zone [param def] avec l'affectation
## actuelle, pendant la saison [param season].
func expected_per_day(def: ZoneDef, season: int) -> float:
	var total := 0.0
	for cell: Vector2i in labor.workers_at:
		if zones.zone_at(cell) == def:
			total += tile_rate(def, cell, labor.workers_at[cell], season)
	return total


## Laine prévue par jour (fibres des troupeaux, à partir du bourg).
func expected_wool_per_day() -> float:
	if not wool:
		return 0.0
	var total := 0.0
	for cell: Vector2i in labor.workers_at:
		var def := zones.zone_at(cell)
		if def and def.quality == ZoneDef.Quality.PASTURE:
			total += labor.workers_at[cell] * WOOL_PER_WORKER * proximity(cell)
	return total


## Production de l'heure [param tick], versée dans [param stock].
func step_hour(tick: int, stock: Stockpile) -> Report:
	var report := Report.new()
	var season := GameDate.season(tick)
	for cell: Vector2i in labor.workers_at:
		var def := zones.zone_at(cell)
		if def == null:
			continue
		var qty := tile_rate(def, cell, labor.workers_at[cell], season) / GameDate.HOURS_PER_DAY
		if qty <= 0.0:
			continue
		if def.output == Stockpile.Good.WOOD:
			qty = _cut(cell, qty, report)
		elif def.deposit != 0:
			qty = _mine(cell, qty, report)
		stock.add(def.output, qty)
		produced_today[def.output] += qty
		if wool and def.quality == ZoneDef.Quality.PASTURE:
			var fiber := labor.workers_at[cell] * WOOL_PER_WORKER * proximity(cell) / GameDate.HOURS_PER_DAY
			stock.add(Stockpile.Good.FIBER, fiber)
			produced_today[Stockpile.Good.FIBER] += fiber
	if not report.cleared.is_empty():
		zones.clear(report.cleared)
	return report


## Extrait [param qty] du gisement de [param cell] ; épuisé, la tuile perd sa
## zone. Renvoie la quantité obtenue.
func _mine(cell: Vector2i, qty: float, report: Report) -> float:
	var left := map.get_deposit_amount(cell)
	var got := minf(qty, left)
	map.set_deposit_amount(cell, left - got)
	if left - got <= 0.0:
		report.cleared.append(cell)
	return got


## Coupe [param qty] de bois sur [param cell] ; renvoie le bois obtenu.
func _cut(cell: Vector2i, qty: float, report: Report) -> float:
	var wood := map.get_wood(cell)
	if not _forest_max.has(cell):
		_forest_max[cell] = wood
	var got := minf(qty, wood)
	map.set_wood(cell, wood - got)
	if wood - got <= 0.0:
		map.set_terrain(cell, TerrainDef.Type.PLAIN)
		_forest_max.erase(cell)
		_clearcuts[cell] = 0
		report.clearcut.append(cell)
	return got


## Fin de la journée [param day_tick] (tick du jour clos) : usure et repos
## des champs, repousse des forêts ; renvoie les tuiles redevenues forêt.
func end_day(day_tick: int) -> Array[Vector2i]:
	var season := GameDate.season(day_tick)
	var farm := ZoneDb.DEFS.filter(func(d: ZoneDef) -> bool: return d.quality == ZoneDef.Quality.FERTILITY)
	# Champs travaillés en saison de culture : la fertilité baisse.
	for cell: Vector2i in labor.workers_at:
		var def := zones.zone_at(cell)
		if def in farm and def.season_factors[season] > 0.0:
			if not _natural_fertility.has(cell):
				_natural_fertility[cell] = map.get_fertility(cell)
			if not _done(&"crop_rotation"):
				map.set_fertility(cell, map.get_fertility(cell) - FERTILITY_WEAR_PER_DAY)
	for cell: Vector2i in _natural_fertility.keys():
		if labor.workers_at.has(cell) and zones.zone_at(cell) in farm:
			continue
		var target := _natural_fertility[cell]
		var value := minf(target, map.get_fertility(cell) + FERTILITY_RECOVERY_PER_DAY)
		map.set_fertility(cell, value)
		if value >= target:
			_natural_fertility.erase(cell)
	# Forêts entamées laissées au repos : le bois repousse.
	for cell: Vector2i in _forest_max.keys():
		if labor.workers_at.has(cell) and zones.zone_at(cell) != null:
			continue
		var wood := minf(_forest_max[cell], map.get_wood(cell) + FOREST_REGROWTH_PER_DAY)
		map.set_wood(cell, wood)
		if wood >= _forest_max[cell]:
			_forest_max.erase(cell)
	# Coupes à blanc sans bâtiment ni autre zone que la coupe : redeviennent forêt.
	var regrown: Array[Vector2i] = []
	for cell: Vector2i in _clearcuts.keys():
		if map.get_terrain(cell) != TerrainDef.Type.PLAIN or buildings.building_at(cell):
			_clearcuts.erase(cell)
			continue
		var zone := zones.zone_at(cell)
		if zone and zone.quality != ZoneDef.Quality.WOOD:
			continue
		_clearcuts[cell] += 1
		if _clearcuts[cell] >= CLEARCUT_REGROW_DAYS:
			map.set_terrain(cell, TerrainDef.Type.FOREST)
			map.set_wood(cell, REGROWN_WOOD)
			_forest_max[cell] = WorldMap.WOOD_PER_FOREST * 0.6
			_clearcuts.erase(cell)
			regrown.append(cell)
	return regrown


## Jours restants avant qu'une coupe à blanc redevienne forêt (-1 : aucune).
func regrowth_days_left(cell: Vector2i) -> int:
	var c := map.wrap_cell(cell)
	return CLEARCUT_REGROW_DAYS - _clearcuts[c] if _clearcuts.has(c) else -1


func reset_day() -> void:
	produced_today = Stockpile.zeros()
