extends Node
## État global de la partie en cours.

const DEFAULT_MAP_SIZE := Vector2i(64, 64)
const DEFAULT_START_MONEY := 50_000
## Technologie qui révèle les gisements.
const PROSPECTING_TECH := &"prospecting"

var map_size: Vector2i = DEFAULT_MAP_SIZE
var world_map: WorldMap
var buildings: BuildingRegistry
var production: Production
var roads: RoadNetwork
var logistics: Logistics
var grid: PowerGrid
var research: Research
## Points de recherche produits pendant la dernière heure.
var research_rate := 0.0
## Villes de la partie (bâtiments portant une City).
var cities: Array[Building] = []
## Bilan électrique de la dernière heure.
var last_grid: PowerGrid.Report = PowerGrid.Report.new()
## Ventes et pénalités du jour en cours et de la veille (€).
var revenue_today := 0.0
var penalty_today := 0.0
var revenue_yesterday := 0.0
var penalty_yesterday := 0.0
## Puissance électrique produite pendant la dernière heure (MW).
var power_mw := 0.0
## Montant pas encore débité ou crédité (fractions d'euro : usage des
## véhicules, ventes, pénalités).
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
	grid = PowerGrid.new(world_map)
	buildings = BuildingRegistry.new(world_map, roads, grid)
	production = Production.new(buildings)
	logistics = Logistics.new(buildings)
	research = Research.new(TechDb.DEFS)
	research_rate = 0.0
	_apply_modifiers()
	cities = CityGenerator.populate(buildings, Rng.fork("cities"))
	grid.refresh_topology(buildings)
	power_mw = 0.0
	last_grid = PowerGrid.Report.new()
	revenue_today = 0.0
	penalty_today = 0.0
	revenue_yesterday = 0.0
	penalty_yesterday = 0.0
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
	if def.uses_logistics() and def.vehicle_slots == 0 \
			and not buildings.all().any(func(o: Building) -> bool: return o.def.vehicle_slots > 0):
		EventBus.notified.emit("Sans dépôt de véhicules relié à la route, les marchandises ne circulent pas")
	return b


## Démolit le bâtiment (ou à défaut la route) présent en [param cell] et
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
		if roads.remove(cell):
			logistics.on_roads_changed()
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
	logistics.on_roads_changed()
	if not plan.cleared.is_empty():
		EventBus.tiles_changed.emit(plan.cleared)
	EventBus.roads_changed.emit(plan.new_cells)
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


## Entretien journalier total : bâtiments, routes, véhicules.
func daily_upkeep() -> int:
	return buildings.daily_upkeep() + roads.daily_upkeep() + grid.daily_upkeep() \
		+ logistics.daily_upkeep()


func _on_tick(tick: int) -> void:
	for b in buildings.advance():
		for id in b.def.starting_vehicles:
			EventBus.vehicle_added.emit(logistics.add_vehicle(b, VehicleDb.get_def(id)))
		EventBus.building_completed.emit(b)
	var report := production.step(tick)
	research_rate = report.research
	if report.research > 0.0:
		_on_techs_done(research.add_points(report.research))
		EventBus.research_changed.emit()
	var transport := logistics.step()
	for v in transport.sold:
		money += Logistics.refund_of(v)
		EventBus.vehicle_removed.emit(v)
		EventBus.notified.emit("%s vendu : +%s €" % [v.def.display_name, Format.thousands(Logistics.refund_of(v))])
	last_grid = grid.step(tick, buildings)
	revenue_today += last_grid.revenue
	penalty_today += last_grid.penalty
	_pending_money += last_grid.revenue - last_grid.penalty - transport.travel_cost
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


func _on_day(_day: int) -> void:
	for c in cities:
		c.city.end_day()
	revenue_yesterday = revenue_today
	penalty_yesterday = penalty_today
	revenue_today = 0.0
	penalty_today = 0.0
	var upkeep := daily_upkeep()
	if upkeep > 0:
		money -= upkeep
