extends Node
## État global de la partie en cours.

const DEFAULT_MAP_SIZE := Vector2i(64, 64)
const DEFAULT_START_MONEY := 50_000
## Technologie qui révèle les gisements.
const PROSPECTING_TECH := &"prospecting"
## Technologie des voies ferrées.
const RAIL_TECH := &"rail"

var map_size: Vector2i = DEFAULT_MAP_SIZE
var world_map: WorldMap
var buildings: BuildingRegistry
var production: Production
var roads: RoadNetwork
var rails: RailNetwork
## Voies navigables (mer, lacs, rivières), données par la carte.
var waters: WaterNetwork
var logistics: Logistics
var grid: PowerGrid
var research: Research
var pollution: Pollution
var weather: Weather
## Marché, taxe carbone, subventions et comptes du jour.
var economy: Economy
## Tempêtes, sécheresses, crises, grèves, incidents nucléaires.
var events: Events
## Historique journalier (graphiques) et jalons du bac à sable.
var stats: Statistics
var milestones: Milestones
## Points de recherche produits pendant la dernière heure.
var research_rate := 0.0
## Villes de la partie (bâtiments portant une City).
var cities: Array[Building] = []
## Bilan électrique de la dernière heure.
var last_grid: PowerGrid.Report = PowerGrid.Report.new()
## Puissance électrique produite pendant la dernière heure (MW).
var power_mw := 0.0
## Montant pas encore débité ou crédité (fractions d'euro : usage des
## véhicules, ventes, subventions, pénalités, taxe carbone).
var _pending_money := 0.0
var money: int = DEFAULT_START_MONEY:
	set(value):
		money = value
		EventBus.money_changed.emit(money)


func _ready() -> void:
	EventBus.tick_advanced.connect(_on_tick)
	EventBus.day_changed.connect(_on_day)
	new_game(random_seed())


func new_game(seed_value: int, size: Vector2i = DEFAULT_MAP_SIZE,
		start_money: int = DEFAULT_START_MONEY) -> void:
	Rng.set_seed(seed_value)
	map_size = size
	world_map = MapGenerator.generate(size, seed_value)
	roads = RoadNetwork.new(world_map)
	rails = RailNetwork.new(world_map)
	waters = WaterNetwork.new(world_map)
	grid = PowerGrid.new(world_map)
	buildings = BuildingRegistry.new(world_map, roads, grid, rails, waters)
	production = Production.new(buildings)
	logistics = Logistics.new(buildings)
	pollution = Pollution.new(buildings)
	research = Research.new(TechDb.DEFS)
	weather = Weather.new(seed_value)
	economy = Economy.new(seed_value)
	events = Events.new(Rng.fork("events"), weather)
	stats = Statistics.new()
	milestones = Milestones.new()
	production.weather = weather
	grid.weather = weather
	grid.economy = economy
	research_rate = 0.0
	_apply_modifiers()
	cities = CityGenerator.populate(buildings, Rng.fork("cities"))
	grid.refresh_topology(buildings)
	power_mw = 0.0
	last_grid = PowerGrid.Report.new()
	_pending_money = 0.0
	money = start_money
	GameClock.reset()
	EventBus.game_started.emit(seed_value)


## Graine aléatoire lisible (6 chiffres).
static func random_seed() -> int:
	return randi_range(100_000, 999_999)


## Vérifie le placement de [param def] en [param anchor] avec l'argent et
## les technologies actuels.
func check_placement(def: BuildingDef, anchor: Vector2i) -> BuildingRegistry.Placement:
	var placement := buildings.check_placement(def, anchor, money)
	if not research.is_known(def.required_tech):
		placement.error = "Technologie requise : " + research.get_def(def.required_tech).display_name
	return placement


## Motif empêchant l'achat de [param def] pour [param depot] (vide : possible).
func vehicle_error(depot: Building, def: VehicleDef) -> String:
	if not research.is_known(def.required_tech):
		return "Technologie requise : " + research.get_def(def.required_tech).display_name
	return logistics.buy_error(depot, def, money)


## Les gisements ne sont connus qu'après la technologie Prospection.
func deposits_revealed() -> bool:
	return research != null and research.is_known(PROSPECTING_TECH)


## Met une technologie en recherche (avec ses prérequis manquants).
func enqueue_research(id: StringName) -> void:
	_on_techs_done(research.enqueue(id))
	EventBus.research_changed.emit()


func dequeue_research(id: StringName) -> void:
	research.dequeue(id)
	EventBus.research_changed.emit()


func _on_techs_done(done: Array[TechDef]) -> void:
	if done.is_empty():
		return
	_apply_modifiers()
	for def in done:
		EventBus.tech_unlocked.emit(def)
		EventBus.notified.emit("Technologie acquise : " + def.display_name)


## Reporte les modificateurs des technologies acquises sur la simulation.
func _apply_modifiers() -> void:
	production.fuel_factor = research.modifier(&"fuel_use")
	production.extraction_factor = research.modifier(&"extraction")
	production.regrowth_factor = research.modifier(&"regrowth")
	production.research_factor = research.modifier(&"research")
	production.waste_factor = research.modifier(&"waste")
	pollution.filter_factor = research.modifier(&"pollution")
	grid.loss_factor = research.modifier(&"grid_loss")
	grid.penalty_factor = research.modifier(&"penalty")
	grid.fuel_factor = research.modifier(&"fuel_use")
	logistics.speed_factor = research.modifier(&"vehicle_speed")


## Lance le chantier de [param def] en [param anchor] et le paie ; renvoie
## le bâtiment, ou null (raison notifiée) si le placement est invalide.
func build(def: BuildingDef, anchor: Vector2i) -> Building:
	var placement := check_placement(def, anchor)
	if not placement.is_valid():
		EventBus.notified.emit(placement.error)
		return null
	money -= def.cost
	var b := buildings.place(placement)
	if not placement.cleared.is_empty():
		EventBus.tiles_changed.emit(placement.cleared)
	EventBus.building_placed.emit(b)
	_refresh_grid()
	if def.uses_logistics() and not def.is_road_depot() \
			and not buildings.all().any(func(o: Building) -> bool: return o.def.is_road_depot()):
		EventBus.notified.emit("Sans dépôt de véhicules relié à la route, les marchandises ne circulent pas")
	return b


## Démolit le bâtiment (ou à défaut la ligne, la voie ou la route) présent en [param cell] et
## rembourse une part du bâtiment et de ses véhicules ; renvoie la somme
## remboursée (-1 s'il n'y a rien à démolir).
func demolish(cell: Vector2i) -> int:
	var b := buildings.building_at(cell)
	if b and b.city:
		EventBus.notified.emit("Une ville ne peut pas être démolie")
		return -1
	if b == null:
		if grid.remove(cell):
			_refresh_grid()
			EventBus.lines_changed.emit([cell] as Array[Vector2i])
			return 0
		if rails.remove(cell):
			logistics.on_networks_changed()
			EventBus.rails_changed.emit([cell] as Array[Vector2i])
			return 0
		if roads.remove(cell):
			logistics.on_networks_changed()
			EventBus.roads_changed.emit([cell] as Array[Vector2i])
			return 0
		return -1
	var refund := BuildingRegistry.refund_for(b)
	buildings.remove(b)
	for v in logistics.on_building_removed(b):
		refund += floori(v.def.cost * Logistics.SELL_REFUND)
		EventBus.vehicle_removed.emit(v)
	money += refund
	_refresh_grid()
	EventBus.building_removed.emit(b)
	return refund


## Tracé de route en L de [param from] à [param to], vérifié avec l'argent actuel.
func plan_road(from: Vector2i, to: Vector2i) -> TilePlan:
	return roads.plan(RoadNetwork.l_path(from, to), buildings, money)


## Construit et paie un tracé ; false (motif notifié) s'il est invalide.
func build_road(plan: TilePlan) -> bool:
	plan = roads.plan(plan.cells, buildings, money)
	if not plan.is_valid():
		EventBus.notified.emit(plan.error)
		return false
	money -= plan.cost
	roads.build(plan)
	logistics.on_networks_changed()
	if not plan.cleared.is_empty():
		EventBus.tiles_changed.emit(plan.cleared)
	EventBus.roads_changed.emit(plan.new_cells)
	return true


## Tracé de voie ferrée en L, vérifié avec l'argent et les technologies actuels.
func plan_rail(from: Vector2i, to: Vector2i) -> TilePlan:
	var plan := rails.plan(TilePlan.l_path(from, to), buildings, money)
	if not research.is_known(RAIL_TECH):
		plan.error = "Technologie requise : " + research.get_def(RAIL_TECH).display_name
	return plan


func build_rail(plan: TilePlan) -> bool:
	plan = rails.plan(plan.cells, buildings, money)
	if not research.is_known(RAIL_TECH):
		plan.error = "Technologie requise : " + research.get_def(RAIL_TECH).display_name
	if not plan.is_valid():
		EventBus.notified.emit(plan.error)
		return false
	money -= plan.cost
	rails.build(plan)
	logistics.on_networks_changed()
	if not plan.cleared.is_empty():
		EventBus.tiles_changed.emit(plan.cleared)
	EventBus.rails_changed.emit(plan.new_cells)
	return true


## Tracé de ligne électrique en L, vérifié avec l'argent actuel.
func plan_line(from: Vector2i, to: Vector2i) -> TilePlan:
	return grid.plan(TilePlan.l_path(from, to), buildings, money)


func build_line(plan: TilePlan) -> bool:
	plan = grid.plan(plan.cells, buildings, money)
	if not plan.is_valid():
		EventBus.notified.emit(plan.error)
		return false
	money -= plan.cost
	grid.build(plan)
	_refresh_grid()
	EventBus.lines_changed.emit(plan.new_cells)
	return true


## Raccordements et consignes à jour après un changement de topologie.
func _refresh_grid() -> void:
	grid.refresh_topology(buildings)
	grid.plan_setpoints(GameClock.tick + 1)
	EventBus.grid_changed.emit()


## Achète un véhicule [param def] pour [param depot] ; null (motif notifié)
## si impossible.
func buy_vehicle(depot: Building, def: VehicleDef) -> Vehicle:
	var error := vehicle_error(depot, def)
	if not error.is_empty():
		EventBus.notified.emit(error)
		return null
	money -= def.cost
	var v := logistics.add_vehicle(depot, def)
	EventBus.vehicle_added.emit(v)
	return v


## Revend un véhicule de [param depot] (du type [param def] si donné) :
## de préférence un véhicule au dépôt, sinon un véhicule en mission, vendu
## à son retour (le moins avancé : vide d'abord). Renvoie le remboursement
## immédiat, 0 si la vente est différée, -1 s'il n'y a rien à vendre.
func sell_vehicle(depot: Building, def: VehicleDef = null) -> int:
	var candidates := logistics.active_vehicles_of(depot).filter(func(v: Vehicle) -> bool:
		return def == null or v.def == def)
	if candidates.is_empty():
		EventBus.notified.emit("Aucun véhicule de ce type à vendre")
		return -1
	candidates.sort_custom(func(a: Vehicle, b: Vehicle) -> bool:
		return _sale_rank(a) < _sale_rank(b))
	var v: Vehicle = candidates[0]
	var refund := logistics.sell(v)
	if refund >= 0:
		money += refund
		EventBus.vehicle_removed.emit(v)
		return refund
	EventBus.notified.emit("%s vendu à son retour au dépôt" % v.def.display_name)
	EventBus.vehicles_changed.emit()
	return 0


## Ordre de préférence pour la revente : au dépôt, puis vide, puis chargé.
static func _sale_rank(v: Vehicle) -> int:
	match v.state:
		Vehicle.State.IDLE:
			return 0
		Vehicle.State.RETURNING, Vehicle.State.TO_SOURCE:
			return 1
		Vehicle.State.LOADING:
			return 2
	return 3


## Entretien journalier total : bâtiments, routes, voies, lignes, véhicules.
func daily_upkeep() -> int:
	return buildings.daily_upkeep() + roads.daily_upkeep() + rails.daily_upkeep() \
		+ grid.daily_upkeep() + logistics.daily_upkeep()


func _on_tick(tick: int) -> void:
	for b in buildings.advance():
		for id in b.def.starting_vehicles:
			EventBus.vehicle_added.emit(logistics.add_vehicle(b, VehicleDb.get_def(id)))
		EventBus.building_completed.emit(b)
	_step_events(tick)
	var report := production.step(tick)
	pollution.step()
	research_rate = report.research
	var waiting := research.is_waiting()
	_count_operation_hours()
	if report.research > 0.0 or (waiting and research.is_ready(research.current().id)):
		_on_techs_done(research.add_points(report.research))
		EventBus.research_changed.emit()
	var transport := logistics.step()
	for v in transport.sold:
		money += Logistics.refund_of(v)
		EventBus.vehicle_removed.emit(v)
		EventBus.notified.emit("%s vendu : +%s €" % [v.def.display_name, Format.thousands(Logistics.refund_of(v))])
	last_grid = grid.step(tick, buildings)
	_pending_money += economy.settle_hour(tick, last_grid, pollution.emitted_last_hour, transport.travel_cost)
	stats.record_hour(buildings, last_grid, pollution.emitted_last_hour, report.research, last_grid.price)
	if absf(_pending_money) >= 1.0:
		var whole := int(_pending_money)
		money += whole
		_pending_money -= whole
	power_mw = report.power_mw
	if not report.changed_cells.is_empty():
		EventBus.tiles_changed.emit(report.changed_cells)
	for b in report.status_changed:
		EventBus.building_status_changed.emit(b)
	EventBus.production_stepped.emit(report)
	EventBus.grid_stepped.emit(last_grid)


## Heures de fonctionnement par type de bâtiment (conditions d'essai).
func _count_operation_hours() -> void:
	var running := {}
	for b in buildings.all():
		if b.status == Building.Status.RUNNING:
			running[b.def.id] = true
	for id: StringName in running:
		research.operation_hours[id] = research.operation_hours.get(id, 0) + 1


## Événements de l'heure : effets sur la simulation, réparations, annonces.
func _step_events(tick: int) -> void:
	var result := events.step(tick, buildings, production.extraction_factor)
	production.cooling_factor = events.cooling_factor()
	grid.cooling_factor = events.cooling_factor()
	economy.price_factor = events.price_factor()
	if result.repair_cost > 0.0:
		economy.pay_repairs(result.repair_cost)
		_pending_money -= result.repair_cost
	if not result.status_changed.is_empty():
		grid.plan_setpoints(tick)
	for text in result.messages:
		EventBus.notified.emit(text)


func _on_day(day: int) -> void:
	for c in cities:
		c.city.end_day(pollution.air_quality(c.cells))
	var upkeep := daily_upkeep()
	economy.end_day(upkeep)
	if upkeep > 0:
		money -= upkeep
	stats.end_day(money, economy.yesterday, cities)
	_check_milestones(day - 1)
	if day % (GameDate.DAYS_PER_SEASON * GameDate.SEASONS_PER_YEAR) == 0:
		_announce_year(GameClock.tick)


func _check_milestones(day: int) -> void:
	var facts := Milestones.Facts.new()
	facts.stats = stats
	facts.money = money
	facts.cities = cities
	facts.buildings = buildings.all()
	facts.research = research
	for def in milestones.check(facts, day):
		EventBus.milestone_reached.emit(def)
		EventBus.notified.emit("Jalon atteint : %s — %s" % [def.display_name, def.description])


## Nouveaux taux de l'année : taxe carbone et subvention aux renouvelables.
func _announce_year(tick: int) -> void:
	var tax := Economy.carbon_tax_at(tick)
	var text := "An %d : subvention renouvelable %s €/MWh" % [GameDate.year(tick), Format.decimal(Economy.subsidy_at(tick))]
	if tax > 0.0:
		text += ", taxe carbone %s €/t de CO₂" % Format.decimal(tax)
	EventBus.notified.emit(text)
