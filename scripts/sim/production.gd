class_name Production
extends RefCounted
## Production des zones : rendement de chaque tuile occupée = travailleurs ×
## rendement de base × qualité × facteur de saison × proximité du village.
## La coupe du bois vide la forêt (coupe à blanc : la tuile devient plaine et
## perd sa zone) ; une forêt entamée se densifie hors exploitation, une coupe
## à blanc sans zone ni bâtiment redevient forêt. Cultiver use la fertilité,
## qui se reconstitue au repos. Pure donnée.

## Fertilité perdue par jour par un champ cultivé (avec récolte), regagnée
## par jour au repos jusqu'à sa valeur naturelle.
const FERTILITY_WEAR_PER_DAY := 0.0015
const FERTILITY_RECOVERY_PER_DAY := 0.003
## Bois regagné par jour par une forêt entamée hors exploitation.
const FOREST_REGROWTH_PER_DAY := 1.5
## Jours pour qu'une coupe à blanc redevienne forêt, et son bois à ce moment.
const CLEARCUT_REGROW_DAYS := 120
const REGROWN_WOOD := 60.0


class Report:
	## Tuiles devenues plaine (coupe à blanc) pendant l'heure.
	var cleared: Array[Vector2i] = []


var map: WorldMap
var zones: ZoneMap
var labor: Labor
var buildings: BuildingRegistry
## Production du jour en cours, par marchandise (Stockpile.Good).
var produced_today := PackedFloat32Array([0.0, 0.0])
## Valeur naturelle des fertilités entamées, bois maximal des forêts entamées
## et jours écoulés depuis les coupes à blanc (tuiles ramenées sur la planète).
var _natural_fertility: Dictionary[Vector2i, float] = {}
var _forest_max: Dictionary[Vector2i, float] = {}
var _clearcuts: Dictionary[Vector2i, int] = {}


func _init(p_zones: ZoneMap, p_labor: Labor) -> void:
	zones = p_zones
	labor = p_labor
	map = zones.map
	buildings = zones.buildings


## Production par jour de [param workers] travailleurs sur [param cell] de la
## zone [param def] pendant la saison [param season].
func tile_rate(def: ZoneDef, cell: Vector2i, workers: int, season: int) -> float:
	return workers * def.base_yield * def.quality_at(map, cell) * def.season_factors[season] \
		* Labor.distance_factor(labor.distance(cell))


## Production prévue par jour de la zone [param def] avec l'affectation
## actuelle, pendant la saison [param season].
func expected_per_day(def: ZoneDef, season: int) -> float:
	var total := 0.0
	for cell: Vector2i in labor.workers_at:
		if zones.zone_at(cell) == def:
			total += tile_rate(def, cell, labor.workers_at[cell], season)
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
		stock.add(def.output, qty)
		produced_today[def.output] += qty
	if not report.cleared.is_empty():
		zones.clear(report.cleared)
	return report


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
		report.cleared.append(cell)
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
	# Coupes à blanc sans zone ni bâtiment : redeviennent forêt.
	var regrown: Array[Vector2i] = []
	for cell: Vector2i in _clearcuts.keys():
		if map.get_terrain(cell) != TerrainDef.Type.PLAIN or buildings.building_at(cell):
			_clearcuts.erase(cell)
			continue
		if zones.zone_at(cell):
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
	produced_today = PackedFloat32Array([0.0, 0.0])
