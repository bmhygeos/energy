extends Node
## État global de la partie en cours.

const DEFAULT_MAP_SIZE := Vector2i(64, 64)
const DEFAULT_START_MONEY := 50_000

var map_size: Vector2i = DEFAULT_MAP_SIZE
var world_map: WorldMap
var buildings: BuildingRegistry
var production: Production
var roads: RoadNetwork
var logistics: Logistics
## Puissance électrique produite pendant la dernière heure (MW).
var power_mw := 0.0
## Coût d'usage des véhicules pas encore débité (fraction d'euro).
var _travel_cost := 0.0
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
	buildings = BuildingRegistry.new(world_map, roads)
	production = Production.new(buildings)
	logistics = Logistics.new(buildings)
	power_mw = 0.0
	_travel_cost = 0.0
	money = start_money
	GameClock.reset()
	EventBus.game_started.emit(seed_value)


## Graine aléatoire lisible (6 chiffres).
static func random_seed() -> int:
	return randi_range(100_000, 999_999)


## Vérifie le placement de [param def] en [param anchor] avec l'argent actuel.
func check_placement(def: BuildingDef, anchor: Vector2i) -> BuildingRegistry.Placement:
	return buildings.check_placement(def, anchor, money)


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
	return b


## Démolit le bâtiment (ou à défaut la route) présent en [param cell] et
## rembourse une part du bâtiment et de ses véhicules ; renvoie la somme
## remboursée (-1 s'il n'y a rien à démolir).
func demolish(cell: Vector2i) -> int:
	var b := buildings.building_at(cell)
	if b == null:
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
	EventBus.building_removed.emit(b)
	return refund


## Tracé de route en L de [param from] à [param to], vérifié avec l'argent actuel.
func plan_road(from: Vector2i, to: Vector2i) -> RoadNetwork.Plan:
	return roads.plan(RoadNetwork.l_path(from, to), buildings, money)


## Construit et paie un tracé ; false (motif notifié) s'il est invalide.
func build_road(plan: RoadNetwork.Plan) -> bool:
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


## Achète un véhicule [param def] pour [param depot] ; null (motif notifié)
## si impossible.
func buy_vehicle(depot: Building, def: VehicleDef) -> Vehicle:
	var error := logistics.buy_error(depot, def, money)
	if not error.is_empty():
		EventBus.notified.emit(error)
		return null
	money -= def.cost
	var v := logistics.add_vehicle(depot, def)
	EventBus.vehicle_added.emit(v)
	return v


## Revend un véhicule disponible de [param depot] (de préférence du type
## [param def]) ; renvoie le remboursement, -1 si aucun n'est au dépôt.
func sell_vehicle(depot: Building, def: VehicleDef = null) -> int:
	var idle := logistics.vehicles_of(depot).filter(func(v: Vehicle) -> bool:
		return v.state == Vehicle.State.IDLE and (def == null or v.def == def))
	if idle.is_empty():
		EventBus.notified.emit("Aucun véhicule de ce type au dépôt")
		return -1
	var v: Vehicle = idle[0]
	var refund := logistics.sell(v)
	money += refund
	EventBus.vehicle_removed.emit(v)
	return refund


## Entretien journalier total : bâtiments, routes, véhicules.
func daily_upkeep() -> int:
	return buildings.daily_upkeep() + roads.daily_upkeep() + logistics.daily_upkeep()


func _on_tick(tick: int) -> void:
	for b in buildings.advance():
		for id in b.def.starting_vehicles:
			EventBus.vehicle_added.emit(logistics.add_vehicle(b, VehicleDb.get_def(id)))
		EventBus.building_completed.emit(b)
	var report := production.step(tick)
	var transport := logistics.step()
	_travel_cost += transport.travel_cost
	if _travel_cost >= 1.0:
		money -= floori(_travel_cost)
		_travel_cost -= floori(_travel_cost)
	power_mw = report.power_mw
	if not report.changed_cells.is_empty():
		EventBus.tiles_changed.emit(report.changed_cells)
	for b in report.status_changed:
		EventBus.building_status_changed.emit(b)
	EventBus.production_stepped.emit(report)


func _on_day(_day: int) -> void:
	var upkeep := daily_upkeep()
	if upkeep > 0:
		money -= upkeep
