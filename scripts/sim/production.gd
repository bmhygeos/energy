class_name Production
extends RefCounted
## Production horaire des bâtiments terminés : extraction (forêts, gisements),
## transformation (combustible → électricité), renouvelables selon la météo,
## reboisement. Les marchandises circulent par la route (Logistics). Pure
## donnée.

## Pépinière : repousse des forêts du rayon, et une plantation par jour.
const REGROWTH_PER_HOUR := 0.25
const PLANT_INTERVAL_HOURS := 24
const SAPLING_WOOD := 10.0
const EPSILON := 0.0001
## Rendement décroissant de la recherche : n laboratoires produisent comme
## n^RESEARCH_SCALING laboratoires isolés (coordination, équipes).
const RESEARCH_SCALING := 0.75


## Bilan d'une heure de production.
class Report:
	var power_mw := 0.0
	## Points de recherche produits.
	var research := 0.0
	## Tuiles dont le terrain ou le gisement a changé.
	var changed_cells: Array[Vector2i] = []
	var status_changed: Array[Building] = []


var registry: BuildingRegistry
var map: WorldMap
## Facteurs des technologies acquises (Research.modifier).
var fuel_factor := 1.0
var extraction_factor := 1.0
var regrowth_factor := 1.0
var research_factor := 1.0
var waste_factor := 1.0
## Vent, nuages et lumière du jour (renouvelables).
var weather := Weather.new()
## Part de la puissance permise aux centrales refroidies par l'eau
## (sécheresse : < 1).
var cooling_factor := 1.0
## Tuiles exploitables par bâtiment (id → tuiles triées par distance).
var _area_cache: Dictionary[int, Array] = {}


func _init(p_registry: BuildingRegistry) -> void:
	registry = p_registry
	map = registry.map


## Exécute une heure de production (tick [param tick]).
func step(tick: int) -> Report:
	var report := Report.new()
	var labs := 0
	for b in registry.all():
		var old := b.status
		_run(b, tick, report)
		if b.status != old:
			report.status_changed.append(b)
		report.power_mw += b.power_mw
		if b.status == Building.Status.RUNNING and b.def.research_per_hour > 0.0:
			report.research += b.def.research_per_hour * research_factor
			labs += 1
	report.research *= research_efficiency(labs)
	return report


## Rendement de chaque laboratoire quand [param labs] sont en service.
static func research_efficiency(labs: int) -> float:
	return pow(labs, RESEARCH_SCALING - 1.0) if labs > 1 else 1.0


func _run(b: Building, tick: int, report: Report) -> void:
	b.activity = 0.0
	b.power_mw = 0.0
	var def := b.def
	if not b.is_complete():
		b.status = Building.Status.CONSTRUCTION
		return
	if b.is_out(tick):
		b.status = b.outage_status
		return
	if def.is_grid_storage():
		b.status = Building.Status.RUNNING if b.grid_id != 0 else Building.Status.NO_GRID
		return
	if not def.is_producer():
		b.status = Building.Status.RUNNING if def.uses_logistics() else Building.Status.IDLE
		return
	if (def.power_mw > 0.0 or def.power_demand_mw > 0.0) and b.grid_id == 0:
		b.status = Building.Status.NO_GRID
		return
	if def.power_demand_mw > 0.0 and not b.powered:
		b.status = Building.Status.NO_POWER
		return
	match def.power_source:
		BuildingDef.PowerSource.WIND, BuildingDef.PowerSource.SUN:
			var factor := renewable_factor(map, weather, b, tick)
			if factor <= EPSILON:
				if def.power_source == BuildingDef.PowerSource.WIND:
					b.status = Building.Status.STORM if weather.is_storm(tick) else Building.Status.NO_WIND
				else:
					b.status = Building.Status.NIGHT
				return
			b.power_mw = def.power_mw * factor
			b.activity = factor
			b.status = Building.Status.RUNNING
			return
		BuildingDef.PowerSource.SOLAR_THERMAL:
			_run_solar_thermal(b, tick)
			return
	var input_rate := input_rate_of(def)
	var output_rate := output_rate_of(def)
	var fraction := 1.0
	if def.output_good != Goods.Type.NONE:
		var room := def.buffer_capacity - b.output_stock
		if room <= EPSILON:
			b.status = Building.Status.OUTPUT_FULL
			return
		fraction = minf(fraction, room / output_rate)
	if def.input_good != Goods.Type.NONE:
		if b.input_stock <= EPSILON:
			b.status = Building.Status.NO_INPUT
			return
		fraction = minf(fraction, b.input_stock / input_rate)
	if def.power_source == BuildingDef.PowerSource.FUEL:
		if b.power_setpoint <= EPSILON:
			b.status = Building.Status.STANDBY
			return
		fraction = minf(fraction, minf(b.power_setpoint, cooling_limit(b)))
	match def.extraction:
		BuildingDef.Extraction.FOREST:
			var got := _harvest_forest(b, output_rate * fraction, report)
			if got <= EPSILON:
				b.status = Building.Status.DEPLETED
				return
			fraction = got / output_rate
		BuildingDef.Extraction.DEPOSIT:
			var got := _mine_deposit(b, output_rate * fraction, report)
			if got <= EPSILON:
				b.status = Building.Status.DEPLETED
				return
			fraction = got / output_rate
		BuildingDef.Extraction.REFOREST:
			_reforest(b, tick, report)
	b.input_stock = maxf(0.0, b.input_stock - input_rate * fraction)
	b.output_stock = minf(def.buffer_capacity, b.output_stock + output_rate * fraction)
	b.power_mw = def.power_mw * fraction
	b.activity = fraction
	b.status = Building.Status.RUNNING


## Solaire thermique : stocke la chaleur captée, puis produit selon la
## consigne du réseau tant que le stock dure (y compris la nuit).
func _run_solar_thermal(b: Building, tick: int) -> void:
	b.stored_mwh = minf(b.def.storage_mwh, b.stored_mwh + heat_collected(map, weather, b, tick))
	if b.power_setpoint <= EPSILON:
		b.status = Building.Status.STANDBY
		return
	if b.stored_mwh <= EPSILON:
		b.status = Building.Status.NIGHT
		return
	var output := minf(b.def.power_mw * b.power_setpoint, b.stored_mwh)
	b.stored_mwh -= output
	b.power_mw = output
	b.activity = output / b.def.power_mw
	b.status = Building.Status.RUNNING


## Production horaire à plein régime, technologies comprises.
func output_rate_of(def: BuildingDef) -> float:
	if def.extraction != BuildingDef.Extraction.NONE:
		return def.output_per_hour * extraction_factor
	if def.output_good == Goods.Type.NUCLEAR_WASTE:
		return def.output_per_hour * waste_factor
	return def.output_per_hour


## Consommation horaire de combustible à plein régime, technologies comprises.
func input_rate_of(def: BuildingDef) -> float:
	return def.input_per_hour * (fuel_factor if def.power_source == BuildingDef.PowerSource.FUEL else 1.0)


## Part de la pleine puissance d'une éolienne ou d'un panneau pendant
## l'heure [param tick] : potentiel moyen de l'emprise × météo.
static func renewable_factor(p_map: WorldMap, p_weather: Weather, b: Building, tick: int) -> float:
	match b.def.power_source:
		BuildingDef.PowerSource.WIND:
			if p_weather.is_storm(tick):
				return 0.0
			return clampf(site_average(p_map, b, p_map.wind) * p_weather.wind_at(tick), 0.0, 1.0)
		BuildingDef.PowerSource.SUN:
			return clampf(site_average(p_map, b, p_map.sun) * p_weather.sun_at(tick), 0.0, 1.0)
	return 1.0


## Part de la pleine puissance permise par le refroidissement (sécheresse).
func cooling_limit(b: Building) -> float:
	return cooling_factor if b.def.needs_water_access else 1.0


## Chaleur captée (MWh) par une centrale solaire thermique pendant l'heure.
static func heat_collected(p_map: WorldMap, p_weather: Weather, b: Building, tick: int) -> float:
	return b.def.power_mw * b.def.solar_multiple * site_average(p_map, b, p_map.sun) * p_weather.sun_at(tick)


static func site_average(p_map: WorldMap, b: Building, values: PackedFloat32Array) -> float:
	var total := 0.0
	for cell in b.cells:
		total += values[p_map.index_of(cell)]
	return total / b.cells.size()


## Tuiles à [member BuildingDef.harvest_radius] de l'emprise (hors emprise),
## des plus proches aux plus lointaines.
func area_of(b: Building) -> Array[Vector2i]:
	if not _area_cache.has(b.id):
		_area_cache[b.id] = area_cells(map, b.def, b.anchor)
	return _area_cache[b.id]


static func area_cells(p_map: WorldMap, def: BuildingDef, anchor: Vector2i) -> Array[Vector2i]:
	var r := def.harvest_radius
	var origin := def.footprint_origin(anchor)
	var center := (Vector2(origin) + Vector2(anchor)) / 2.0
	var cells: Array[Vector2i] = []
	for y in range(origin.y - r, anchor.y + r + 1):
		for x in range(origin.x - r, anchor.x + r + 1):
			var c := Vector2i(x, y)
			var inside := c.x >= origin.x and c.y >= origin.y and c.x <= anchor.x and c.y <= anchor.y
			if p_map.has_cell(c) and not inside:
				cells.append(c)
	cells.sort_custom(func(a: Vector2i, c: Vector2i) -> bool:
		var da := Vector2(a).distance_squared_to(center)
		var dc := Vector2(c).distance_squared_to(center)
		return da < dc if da != dc else p_map.index_of(a) < p_map.index_of(c))
	return cells


## Ressource exploitable (t) par [param def] ancré en [param anchor] : bois
## des forêts ou gisement requis, emprise comprise ; -1 si non extracteur.
static func resource_available(p_map: WorldMap, def: BuildingDef, anchor: Vector2i) -> float:
	var cells := area_cells(p_map, def, anchor)
	var total := 0.0
	match def.extraction:
		BuildingDef.Extraction.FOREST:
			for c in cells + def.footprint(anchor):
				var i := p_map.index_of(c) if p_map.has_cell(c) else -1
				if i >= 0 and p_map.terrain[i] == TerrainDef.Type.FOREST:
					total += p_map.wood[i]
		BuildingDef.Extraction.DEPOSIT:
			for c in cells + def.footprint(anchor):
				var i := p_map.index_of(c) if p_map.has_cell(c) else -1
				if i >= 0 and p_map.deposit[i] == def.required_deposit:
					total += p_map.deposit_amount[i]
		_:
			return -1.0
	return total


## Coupe jusqu'à [param amount] t de bois, forêts les plus proches d'abord ;
## une forêt vidée redevient plaine. Renvoie la quantité coupée.
func _harvest_forest(b: Building, amount: float, report: Report) -> float:
	var got := 0.0
	for cell in area_of(b):
		var i := map.index_of(cell)
		if map.terrain[i] != TerrainDef.Type.FOREST:
			continue
		var take := minf(amount - got, map.wood[i])
		map.wood[i] -= take
		got += take
		if map.wood[i] <= EPSILON:
			map.wood[i] = 0.0
			map.terrain[i] = TerrainDef.Type.PLAIN
			report.changed_cells.append(cell)
		if got >= amount - EPSILON:
			break
	return got


## Extrait jusqu'à [param amount] t du gisement requis, dans l'emprise et
## autour ; un gisement vidé disparaît. Renvoie la quantité extraite.
func _mine_deposit(b: Building, amount: float, report: Report) -> float:
	var got := 0.0
	var kind := b.def.required_deposit
	for cell in b.cells + area_of(b):
		var i := map.index_of(cell)
		if map.deposit[i] != kind or kind == WorldMap.Deposit.NONE:
			continue
		var take := minf(amount - got, map.deposit_amount[i])
		map.deposit_amount[i] -= take
		got += take
		if map.deposit_amount[i] <= EPSILON:
			map.deposit_amount[i] = 0.0
			map.deposit[i] = WorldMap.Deposit.NONE
			report.changed_cells.append(cell)
		if got >= amount - EPSILON:
			break
	return got


## Fait repousser les forêts du rayon et, une fois par jour, plante une
## plaine libre voisine d'une forêt (à défaut, la plus proche).
func _reforest(b: Building, tick: int, report: Report) -> void:
	var candidate := Vector2i(-1, -1)
	var best_neighbors := -1
	for cell in area_of(b):
		var i := map.index_of(cell)
		if map.terrain[i] == TerrainDef.Type.FOREST:
			map.wood[i] = minf(WorldMap.WOOD_PER_FOREST, map.wood[i] + REGROWTH_PER_HOUR * regrowth_factor)
		elif map.terrain[i] == TerrainDef.Type.PLAIN and registry.building_at(cell) == null \
				and not registry.roads.has_road(cell) and not registry.rails.has_rail(cell) \
				and map.deposit[i] == WorldMap.Deposit.NONE:
			var n := 0
			for o in map.neighbors(cell, WorldMap.NEIGHBORS_4):
				if map.terrain[map.index_of(o)] == TerrainDef.Type.FOREST:
					n += 1
			if n > best_neighbors:
				best_neighbors = n
				candidate = cell
	if candidate.x >= 0 and (tick + b.id) % PLANT_INTERVAL_HOURS == 0:
		var i := map.index_of(candidate)
		map.terrain[i] = TerrainDef.Type.FOREST
		map.wood[i] = SAPLING_WOOD
		report.changed_cells.append(candidate)


## Distance de Tchebychev entre les emprises de deux bâtiments (1 : voisines).
static func footprint_distance(a: Building, b: Building) -> int:
	var ao := a.def.footprint_origin(a.anchor)
	var bo := b.def.footprint_origin(b.anchor)
	var dx := maxi(0, maxi(ao.x - b.anchor.x, bo.x - a.anchor.x))
	var dy := maxi(0, maxi(ao.y - b.anchor.y, bo.y - a.anchor.y))
	return maxi(dx, dy)
