class_name Logistics
extends RefCounted
## Transport routier des marchandises : véhicules des dépôts, missions
## source (sortie disponible) → destination (entrée en manque), surplus vers
## les entrepôts, réservations des quantités promises, déplacement le long
## des routes et coût d'usage. Pure donnée.

## Durée d'un chargement / déchargement (heures).
const LOAD_HOURS := 1
## Plus petite quantité qui justifie un trajet (t).
const MIN_LOAD := 0.5
## On attend une charge d'au moins cette part de min(capacité, besoin), sauf
## si la sortie de la source est presque pleine.
const FULL_LOAD_RATIO := 0.6
const SOURCE_FULL_RATIO := 0.9
## Au-delà de cette part de son tampon, un producteur sans client envoie son
## surplus vers un entrepôt.
const SURPLUS_RATIO := 0.5
## Part du prix remboursée à la revente d'un véhicule.
const SELL_REFUND := 0.5


## Bilan d'une heure de transport.
class Report:
	## Coût d'usage des véhicules (€).
	var travel_cost := 0.0
	## Livraisons terminées (t).
	var delivered := 0.0


var registry: BuildingRegistry
var roads: RoadNetwork
var vehicles: Array[Vehicle] = []
## Facteur de vitesse des technologies acquises.
var speed_factor := 1.0
var _next_id := 1
## Longueur du trajet entre deux bâtiments (Vector2i(id, id) → tuiles, -1 :
## injoignable), invalidé à chaque modification des routes.
var _distance_cache: Dictionary[Vector2i, int] = {}


func _init(p_registry: BuildingRegistry) -> void:
	registry = p_registry
	roads = registry.roads


# --- Véhicules -------------------------------------------------------------

func vehicles_of(depot: Building) -> Array[Vehicle]:
	return vehicles.filter(func(v: Vehicle) -> bool: return v.depot == depot)


## Motif empêchant l'achat de [param def] pour [param depot] (vide : possible).
func buy_error(depot: Building, def: VehicleDef, money: int = -1) -> String:
	if depot.def.vehicle_slots <= 0:
		return "Ce bâtiment n'héberge pas de véhicules"
	if not depot.is_complete():
		return "Dépôt en chantier"
	if vehicles_of(depot).size() >= depot.def.vehicle_slots:
		return "Dépôt complet (%d véhicules)" % depot.def.vehicle_slots
	if money >= 0 and money < def.cost:
		return "Fonds insuffisants (%s € requis)" % Format.thousands(def.cost)
	return ""


## Ajoute un véhicule au dépôt (sans le payer).
func add_vehicle(depot: Building, def: VehicleDef) -> Vehicle:
	var v := Vehicle.new(_next_id, def, depot)
	_next_id += 1
	v.grid_pos = Vector2(depot.anchor)
	v.prev_grid_pos = v.grid_pos
	vehicles.append(v)
	return v


## Revend un véhicule au dépôt ; renvoie le remboursement (-1 s'il est en
## mission).
func sell(v: Vehicle) -> int:
	if v.state != Vehicle.State.IDLE:
		return -1
	vehicles.erase(v)
	return floori(v.def.cost * SELL_REFUND)


func daily_upkeep() -> int:
	var total := 0
	for v in vehicles:
		total += v.def.upkeep_per_day
	return total


# --- Marchandises ----------------------------------------------------------

func is_warehouse(b: Building) -> bool:
	return b.def.storage_capacity > 0.0


## Quantité de [param good] que l'on peut encore venir chercher en [param b].
func supply(b: Building, good: int) -> float:
	if not b.is_complete():
		return 0.0
	if is_warehouse(b):
		return b.store.get(good, 0.0) - b.store_reserved_out.get(good, 0.0)
	if b.def.output_good == good:
		return b.output_stock - b.reserved_out
	return 0.0


## Quantité que le consommateur [param b] peut encore recevoir.
func demand(b: Building) -> float:
	if not b.is_complete() or b.def.input_good == Goods.Type.NONE:
		return 0.0
	return b.def.buffer_capacity - b.input_stock - b.reserved_in


## Place libre (non promise) dans l'entrepôt [param b].
func storage_room(b: Building) -> float:
	if not b.is_complete() or not is_warehouse(b):
		return 0.0
	return b.def.storage_capacity - b.stored_total() - b.reserved_in


## Marchandises en route vers [param b] (t).
func incoming(b: Building) -> float:
	return b.reserved_in


## Réservation restante, ramenée à 0 si négative ou résiduelle (arrondis).
static func _clean(value: float) -> float:
	return value if value > 0.0001 else 0.0


func _reserve_out(b: Building, good: int, qty: float) -> void:
	if is_warehouse(b):
		b.store_reserved_out[good] = b.store_reserved_out.get(good, 0.0) + qty
	else:
		b.reserved_out += qty


func _release_out(b: Building, good: int, qty: float) -> void:
	if is_warehouse(b):
		b.store_reserved_out[good] = _clean(b.store_reserved_out.get(good, 0.0) - qty)
	else:
		b.reserved_out = _clean(b.reserved_out - qty)


## Retire jusqu'à [param qty] de [param good] de [param b] ; renvoie la
## quantité retirée.
func _take(b: Building, good: int, qty: float) -> float:
	if is_warehouse(b):
		var got := minf(qty, b.store.get(good, 0.0))
		b.store[good] = b.store.get(good, 0.0) - got
		if b.store[good] <= 0.0001:
			b.store.erase(good)
		return got
	var got := minf(qty, b.output_stock)
	b.output_stock -= got
	return got


func _put(b: Building, good: int, qty: float) -> void:
	if is_warehouse(b):
		b.store[good] = b.store.get(good, 0.0) + qty
	else:
		b.input_stock = minf(b.def.buffer_capacity, b.input_stock + qty)


# --- Trajets ---------------------------------------------------------------

## Longueur du trajet routier entre deux bâtiments (-1 : injoignable).
func distance(a: Building, b: Building) -> int:
	var key := Vector2i(mini(a.id, b.id), maxi(a.id, b.id))
	if not _distance_cache.has(key):
		var path := roads.path_between(roads.access_cells(a), roads.access_cells(b))
		_distance_cache[key] = path.size() - 1 if not path.is_empty() else -1
	return _distance_cache[key]


## Tuiles de départ possibles du véhicule : sortie du dépôt, ou sa position.
func _start_cells(v: Vehicle) -> Array[Vector2i]:
	if v.state == Vehicle.State.IDLE:
		return roads.access_cells(v.depot)
	var cells: Array[Vector2i] = []
	if roads.has_road(v.current_cell()):
		cells.append(v.current_cell())
	return cells


## À appeler après toute modification des routes : invalide les distances et
## recalcule le chemin des véhicules en route.
func on_roads_changed() -> void:
	_distance_cache.clear()
	for v in vehicles:
		if v.state not in [Vehicle.State.TO_SOURCE, Vehicle.State.TO_DESTINATION, Vehicle.State.RETURNING]:
			continue
		var intact := true
		for k in range(floori(v.progress), v.path.size()):
			intact = intact and roads.has_road(v.path[k])
		if intact:
			continue
		var target: Building = v.source if v.state == Vehicle.State.TO_SOURCE \
			else v.destination if v.state == Vehicle.State.TO_DESTINATION else v.depot
		var path := roads.path_between(_start_cells(v), roads.access_cells(target))
		if not path.is_empty():
			v.set_path(path)
		elif v.state == Vehicle.State.RETURNING:
			_park(v)
		else:
			_cancel(v)


## À appeler quand [param b] est démoli : annule les missions qui le
## concernent ; renvoie les véhicules supprimés (ceux de son dépôt).
func on_building_removed(b: Building) -> Array[Vehicle]:
	var removed: Array[Vehicle] = []
	for v in vehicles.duplicate():
		if v.depot == b:
			if v.source or v.destination:
				_release(v)
			vehicles.erase(v)
			removed.append(v)
		elif v.source == b or v.destination == b:
			_cancel(v)
	_distance_cache.clear()
	return removed


# --- Diagnostic ------------------------------------------------------------

## Pourquoi les marchandises de [param b] ne circulent pas (vide : rien à
## signaler). Pour le panneau d'information.
func diagnose(b: Building) -> String:
	var def := b.def
	if not b.is_complete() or def.vehicle_slots > 0 or not def.uses_logistics():
		return ""
	var access := roads.access_cells(b)
	if access.is_empty():
		return "non relié à une route"
	var partners := 0
	for other in registry.all():
		if other == b or not other.is_complete():
			continue
		var trades := false
		if def.output_good != Goods.Type.NONE:
			trades = other.def.input_good == def.output_good or is_warehouse(other)
		if def.input_good != Goods.Type.NONE:
			trades = trades or other.def.output_good == def.input_good or is_warehouse(other)
		if is_warehouse(b):
			trades = other.def.input_good != Goods.Type.NONE or other.def.output_good != Goods.Type.NONE
		if trades and distance(b, other) >= 0:
			partners += 1
	if partners == 0:
		if def.output_good != Goods.Type.NONE:
			return "aucun client (centrale, entrepôt) joignable par la route"
		return "aucun fournisseur joignable par la route"
	var components := {}
	for c in access:
		components[roads.component_of(c)] = true
	var reachable: Array[Vehicle] = []
	for v in vehicles:
		var cells := _start_cells(v) if v.state != Vehicle.State.IDLE else roads.access_cells(v.depot)
		for c in cells:
			if components.has(roads.component_of(c)):
				reachable.append(v)
				break
	if reachable.is_empty():
		if vehicles.is_empty():
			return "aucun véhicule : construisez un dépôt de véhicules relié à cette route"
		return "aucun véhicule ne peut rejoindre ce bâtiment : reliez un dépôt à cette route"
	var busy := reachable.filter(func(v: Vehicle) -> bool: return not v.is_available()).size()
	if busy == reachable.size():
		return "tous les véhicules sont occupés (%d) : achetez-en au dépôt" % busy
	return ""


# --- Simulation ------------------------------------------------------------

func step() -> Report:
	var report := Report.new()
	for v in vehicles:
		_update(v, report)
	_dispatch()
	return report


func _update(v: Vehicle, report: Report) -> void:
	match v.state:
		Vehicle.State.IDLE:
			v.prev_grid_pos = v.grid_pos
		Vehicle.State.TO_SOURCE, Vehicle.State.TO_DESTINATION, Vehicle.State.RETURNING:
			report.travel_cost += v.move(v.def.speed * speed_factor) * v.def.cost_per_tile
			if v.has_arrived():
				_arrive(v)
		Vehicle.State.LOADING:
			v.prev_grid_pos = v.grid_pos
			v.wait_hours -= 1
			if v.wait_hours <= 0:
				_release_out(v.source, v.good, v.amount)
				v.cargo = _take(v.source, v.good, v.amount)
				v.state = Vehicle.State.TO_DESTINATION
				var path := roads.path_between(_start_cells(v), roads.access_cells(v.destination))
				if path.is_empty() or v.cargo <= 0.0:
					_cancel(v)
				else:
					v.set_path(path)
		Vehicle.State.UNLOADING:
			v.prev_grid_pos = v.grid_pos
			v.wait_hours -= 1
			if v.wait_hours <= 0:
				v.destination.reserved_in = _clean(v.destination.reserved_in - v.amount)
				_put(v.destination, v.good, v.cargo)
				report.delivered += v.cargo
				_clear_mission(v)
				_go_home(v)


func _arrive(v: Vehicle) -> void:
	match v.state:
		Vehicle.State.TO_SOURCE:
			v.state = Vehicle.State.LOADING
			v.wait_hours = LOAD_HOURS
		Vehicle.State.TO_DESTINATION:
			v.state = Vehicle.State.UNLOADING
			v.wait_hours = LOAD_HOURS
		Vehicle.State.RETURNING:
			_park(v)


func _clear_mission(v: Vehicle) -> void:
	v.good = Goods.Type.NONE
	v.amount = 0.0
	v.cargo = 0.0
	v.source = null
	v.destination = null


## Libère les réservations de la mission de [param v].
func _release(v: Vehicle) -> void:
	if v.state in [Vehicle.State.TO_SOURCE, Vehicle.State.LOADING]:
		_release_out(v.source, v.good, v.amount)
	if v.destination:
		v.destination.reserved_in = _clean(v.destination.reserved_in - v.amount)


## Annule la mission (chargement perdu) et renvoie le véhicule au dépôt.
func _cancel(v: Vehicle) -> void:
	_release(v)
	_clear_mission(v)
	_go_home(v)


func _go_home(v: Vehicle) -> void:
	var path := roads.path_between(_start_cells(v), roads.access_cells(v.depot))
	if path.is_empty():
		_park(v)
		return
	v.set_path(path)
	v.state = Vehicle.State.RETURNING


## Rentre le véhicule au dépôt (invisible, disponible).
func _park(v: Vehicle) -> void:
	v.state = Vehicle.State.IDLE
	v.path = []
	v.progress = 0.0
	v.grid_pos = Vector2(v.depot.anchor)
	v.prev_grid_pos = v.grid_pos


# --- Répartition des missions ---------------------------------------------

func _dispatch() -> void:
	var available: Array[Vehicle] = vehicles.filter(func(v: Vehicle) -> bool: return v.is_available())
	if available.is_empty():
		return
	var consumers: Array[Building] = registry.all().filter(func(b: Building) -> bool:
		return demand(b) >= MIN_LOAD)
	consumers.sort_custom(func(a: Building, b: Building) -> bool:
		return _fill_ratio(a) < _fill_ratio(b) if _fill_ratio(a) != _fill_ratio(b) else a.id < b.id)
	for consumer in consumers:
		var good := consumer.def.input_good
		while not available.is_empty():
			var need := demand(consumer)
			if need < MIN_LOAD:
				break
			var capacity := 0.0
			for v in available:
				capacity = maxf(capacity, v.def.capacity)
			var source := _best_source(consumer, good, minf(capacity, need) * FULL_LOAD_RATIO)
			if source == null:
				break  # aucune source n'a encore une charge correcte : on attend
			var v := _nearest_vehicle(available, source)
			if v == null:
				break
			var qty := minf(minf(need, supply(source, good)), v.def.capacity)
			if not _start(v, source, consumer, good, qty):
				break
			available.erase(v)
	# Surplus des producteurs vers les entrepôts.
	for producer in registry.all():
		var good := producer.def.output_good
		if good == Goods.Type.NONE or is_warehouse(producer):
			continue
		while not available.is_empty() \
				and supply(producer, good) >= producer.def.buffer_capacity * SURPLUS_RATIO:
			var warehouse := _best_warehouse(producer)
			if warehouse == null:
				break
			var v := _nearest_vehicle(available, producer)
			if v == null:
				break
			var qty := minf(minf(supply(producer, good), storage_room(warehouse)), v.def.capacity)
			if not _start(v, producer, warehouse, good, qty):
				break
			available.erase(v)


func _fill_ratio(b: Building) -> float:
	return (b.input_stock + b.reserved_in) / b.def.buffer_capacity


## Source joignable la plus proche ayant une charge correcte de [param good] :
## au moins [param wanted], ou n'importe quelle quantité utile si c'est un
## entrepôt ou si sa sortie est presque pleine.
func _best_source(consumer: Building, good: int, wanted: float) -> Building:
	var best: Building = null
	var best_d := 0
	for b in registry.all():
		var available := supply(b, good)
		if b == consumer or available < MIN_LOAD:
			continue
		if available < wanted and not is_warehouse(b) \
				and b.output_stock < b.def.buffer_capacity * SOURCE_FULL_RATIO:
			continue
		var d := distance(b, consumer)
		if d >= 0 and (best == null or d < best_d):
			best = b
			best_d = d
	return best


func _best_warehouse(producer: Building) -> Building:
	var best: Building = null
	var best_d := 0
	for b in registry.all():
		if not is_warehouse(b) or storage_room(b) < MIN_LOAD:
			continue
		var d := distance(producer, b)
		if d >= 0 and (best == null or d < best_d):
			best = b
			best_d = d
	return best


## Véhicule disponible le plus proche (à vol d'oiseau) pouvant rejoindre
## [param source] par la route.
func _nearest_vehicle(available: Array[Vehicle], source: Building) -> Vehicle:
	var targets := roads.access_cells(source)
	var components := {}
	for c in targets:
		components[roads.component_of(c)] = true
	var center := Vector2(source.anchor)
	var best: Vehicle = null
	var best_d := 0.0
	for v in available:
		var reachable := false
		for c in _start_cells(v):
			reachable = reachable or components.has(roads.component_of(c))
		if not reachable:
			continue
		var d := v.grid_pos.distance_squared_to(center)
		if best == null or d < best_d:
			best = v
			best_d = d
	return best


## Lance la mission ; false si le véhicule ne peut pas rejoindre la source.
func _start(v: Vehicle, source: Building, destination: Building, good: int, qty: float) -> bool:
	if qty < MIN_LOAD or distance(source, destination) < 0:
		return false
	var path := roads.path_between(_start_cells(v), roads.access_cells(source))
	if path.is_empty():
		return false
	v.good = good as Goods.Type
	v.amount = qty
	v.source = source
	v.destination = destination
	_reserve_out(source, good, qty)
	destination.reserved_in += qty
	var was_idle := v.state == Vehicle.State.IDLE
	v.set_path(path)
	if was_idle:
		v.prev_grid_pos = v.grid_pos
	v.state = Vehicle.State.TO_SOURCE
	return true
