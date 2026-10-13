class_name Logistics
extends RefCounted
## Transport des marchandises : véhicules des dépôts, trains des gares et
## barges des ports, missions source (sortie disponible) → destination
## (entrée en manque), surplus vers les entrepôts, gares et ports, trains et
## barges de plateforme en plateforme vers les clients, réservations des
## quantités promises, déplacement le long des routes, des voies et de
## l'eau, coût d'usage. Pure donnée.

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
	## Véhicules à vendre rentrés au dépôt et vendus pendant l'heure.
	var sold: Array[Vehicle] = []


var registry: BuildingRegistry
var roads: RoadNetwork
var rails: RailNetwork
var waters: WaterNetwork
var vehicles: Array[Vehicle] = []
## Facteur de vitesse des technologies acquises.
var speed_factor := 1.0
var _next_id := 1
## Longueur du trajet entre deux bâtiments (Vector3i(id, id, réseau) →
## tuiles, -1 : injoignable), invalidé à chaque modification des réseaux.
var _distance_cache: Dictionary[Vector3i, int] = {}


func _init(p_registry: BuildingRegistry) -> void:
	registry = p_registry
	roads = registry.roads
	rails = registry.rails
	waters = registry.waters


## Réseau emprunté par [param v].
func _net(v: Vehicle) -> RoadNetwork:
	return _net_of(v.def.network)


func _net_of(network: VehicleDef.Network) -> RoadNetwork:
	match network:
		VehicleDef.Network.RAIL:
			return rails
		VehicleDef.Network.WATER:
			return waters
	return roads


# --- Véhicules -------------------------------------------------------------

func vehicles_of(depot: Building) -> Array[Vehicle]:
	return vehicles.filter(func(v: Vehicle) -> bool: return v.depot == depot)


## Motif empêchant l'achat de [param def] pour [param depot] (vide : possible).
func buy_error(depot: Building, def: VehicleDef, money: int = -1) -> String:
	if depot.def.vehicle_slots <= 0:
		return "Ce bâtiment n'héberge pas de véhicules"
	if depot.def.vehicle_network != def.network:
		match def.network:
			VehicleDef.Network.RAIL:
				return "Les trains s'achètent en gare"
			VehicleDef.Network.WATER:
				return "Les barges s'achètent au port"
		return "Les véhicules routiers s'achètent au dépôt"
	if not depot.is_complete():
		return "Dépôt en chantier"
	if active_vehicles_of(depot).size() >= depot.def.vehicle_slots:
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


## Véhicules du dépôt hors ceux en attente de vente (qui libèrent leur place).
func active_vehicles_of(depot: Building) -> Array[Vehicle]:
	return vehicles.filter(func(v: Vehicle) -> bool: return v.depot == depot and not v.retiring)


static func refund_of(v: Vehicle) -> int:
	return floori(v.def.cost * SELL_REFUND)


## Revend [param v] : tout de suite s'il est au dépôt (renvoie le
## remboursement), sinon à son retour (renvoie -1) : vide, il abandonne sa
## mission ; chargé, il livre d'abord.
func sell(v: Vehicle) -> int:
	if v.state == Vehicle.State.IDLE:
		vehicles.erase(v)
		return refund_of(v)
	v.retiring = true
	if v.state in [Vehicle.State.TO_SOURCE, Vehicle.State.LOADING]:
		_cancel(v)
	return -1


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

## Longueur du trajet entre deux bâtiments par la route (ou par le réseau
## [param net]) ; -1 : injoignable.
func distance(a: Building, b: Building, net: RoadNetwork = null) -> int:
	if net == null:
		net = roads
	var key := Vector3i(mini(a.id, b.id), maxi(a.id, b.id), [roads, rails, waters].find(net))
	if not _distance_cache.has(key):
		var path := net.path_between(net.access_cells(a), net.access_cells(b))
		_distance_cache[key] = path.size() - 1 if not path.is_empty() else -1
	return _distance_cache[key]


## Tuiles de départ possibles du véhicule : sortie du dépôt, ou sa position.
func _start_cells(v: Vehicle) -> Array[Vector2i]:
	var net := _net(v)
	if v.state == Vehicle.State.IDLE:
		return net.access_cells(v.depot)
	var cells: Array[Vector2i] = []
	if net.has_road(v.current_cell()):
		cells.append(v.current_cell())
	return cells


## À appeler après toute modification des routes ou des voies : invalide les
## distances et recalcule le chemin des véhicules en route.
func on_networks_changed() -> void:
	_distance_cache.clear()
	for v in vehicles:
		if v.state not in [Vehicle.State.TO_SOURCE, Vehicle.State.TO_DESTINATION, Vehicle.State.RETURNING]:
			continue
		var net := _net(v)
		var intact := true
		for k in range(floori(v.progress), v.path.size()):
			intact = intact and net.has_road(v.path[k])
		if intact:
			continue
		var target: Building = v.source if v.state == Vehicle.State.TO_SOURCE \
			else v.destination if v.state == Vehicle.State.TO_DESTINATION else v.depot
		var path := net.path_between(_start_cells(v), net.access_cells(target))
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
	if def.is_hub() and b.is_complete():
		return _diagnose_hub(b)
	if not b.is_complete() or def.vehicle_slots > 0 or not def.uses_logistics():
		return ""
	var access := roads.access_cells(b)
	if access.is_empty():
		return "non relié à une route"
	# Marchandises échangées par le bâtiment (aucune en propre pour un entrepôt).
	var flows: Array[int] = []
	if is_warehouse(b):
		var partners := registry.all().filter(func(o: Building) -> bool:
			return o != b and o.is_complete() and distance(b, o) >= 0 \
				and (o.def.input_good != Goods.Type.NONE or o.def.output_good != Goods.Type.NONE))
		if partners.is_empty():
			return "aucun fournisseur joignable par la route"
	if def.output_good != Goods.Type.NONE:
		flows.append(def.output_good)
		if not _has_partner(b, def.output_good, true):
			if def.output_good == Goods.Type.NUCLEAR_WASTE:
				return "aucun site de stockage des déchets joignable par la route"
			return "aucun client (centrale, entrepôt) joignable par la route"
	if def.input_good != Goods.Type.NONE:
		flows.append(def.input_good)
		if not _has_partner(b, def.input_good, false):
			return "aucun fournisseur de %s joignable par la route" % Goods.display_name(def.input_good).to_lower()
	var components := {}
	for c in access:
		components[roads.component_of(c)] = true
	var reachable: Array[Vehicle] = []
	for v in vehicles:
		if v.def.network != VehicleDef.Network.ROAD:
			continue
		var cells := _start_cells(v) if v.state != Vehicle.State.IDLE else roads.access_cells(v.depot)
		for c in cells:
			if components.has(roads.component_of(c)):
				reachable.append(v)
				break
	if reachable.is_empty():
		if vehicles.is_empty():
			return "aucun véhicule : construisez un dépôt de véhicules relié à cette route"
		return "aucun véhicule ne peut rejoindre ce bâtiment : reliez un dépôt à cette route"
	if flows.is_empty():
		flows.append(Goods.Type.NONE)
	for good in flows:
		if not reachable.any(func(v: Vehicle) -> bool: return can_carry(v, good)):
			if Goods.is_hazardous(good):
				return "aucun camion blindé (%s) : achetez-en au dépôt" % Goods.display_name(good).to_lower()
			return "aucun véhicule ordinaire : achetez des charrettes ou des camions au dépôt"
	var carriers := reachable.filter(func(v: Vehicle) -> bool:
		return flows.any(func(good: int) -> bool: return can_carry(v, good)))
	var busy := carriers.filter(func(v: Vehicle) -> bool: return not v.is_available()).size()
	if busy == carriers.size():
		return "tous les véhicules sont occupés (%d) : achetez-en au dépôt" % busy
	return ""


## Un partenaire joignable par la route échange-t-il [param good] avec
## [param b] (client si [param as_output], sinon fournisseur) ? Les
## entrepôts comptent, sauf pour les matières dangereuses.
func _has_partner(b: Building, good: int, as_output: bool) -> bool:
	for other in registry.all():
		if other == b or not other.is_complete():
			continue
		var trades := (other.def.input_good if as_output else other.def.output_good) == good \
			or (is_warehouse(other) and not Goods.is_hazardous(good))
		if trades and distance(b, other) >= 0:
			return true
	return false


## [param v] peut-il transporter [param good] ? Les véhicules blindés sont
## réservés aux matières dangereuses (NONE : marchandise ordinaire).
static func can_carry(v: Vehicle, good: int) -> bool:
	return v.def.armored == Goods.is_hazardous(good)


## Gare ou port : accès, plateforme partenaire, trains ou barges.
func _diagnose_hub(b: Building) -> String:
	var network := b.def.vehicle_network
	var net := _net_of(network)
	var port := network == VehicleDef.Network.WATER
	if net.access_cells(b).is_empty():
		return "sans accès à l'eau navigable" if port else "non reliée à une voie ferrée"
	if roads.access_cells(b).is_empty():
		return "non relié à une route" if port else "non reliée à une route"
	var linked: Array[Building] = registry.all().filter(func(o: Building) -> bool:
		return o != b and o.def.is_hub() and o.def.vehicle_network == network and o.is_complete() \
			and distance(b, o, net) >= 0)
	if linked.is_empty():
		return "aucun autre port joignable par l'eau" if port else "aucune autre gare joignable par le rail"
	if not vehicles.any(func(v: Vehicle) -> bool:
			return v.def.network == network and (v.depot == b or v.depot in linked)):
		return "aucune barge : achetez-en une au port" if port else "aucun train : achetez-en un en gare"
	return ""


# --- Simulation ------------------------------------------------------------

func step() -> Report:
	var report := Report.new()
	for v in vehicles:
		_update(v, report)
	for v in vehicles.duplicate():
		if v.retiring and v.state == Vehicle.State.IDLE:
			vehicles.erase(v)
			report.sold.append(v)
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
				var net := _net(v)
				var path := net.path_between(_start_cells(v), net.access_cells(v.destination))
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
	var net := _net(v)
	var path := net.path_between(_start_cells(v), net.access_cells(v.depot))
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
	var available: Array[Vehicle] = vehicles.filter(func(v: Vehicle) -> bool:
		return v.is_available() and v.def.network == VehicleDef.Network.ROAD)
	_dispatch_road(available)
	for network in [VehicleDef.Network.RAIL, VehicleDef.Network.WATER]:
		_dispatch_hubs(vehicles.filter(func(v: Vehicle) -> bool:
			return v.is_available() and v.def.network == network), network)


func _dispatch_road(available: Array[Vehicle]) -> void:
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
			var carriers := available.filter(func(v: Vehicle) -> bool: return can_carry(v, good))
			if carriers.is_empty():
				break
			var capacity := 0.0
			for v in carriers:
				capacity = maxf(capacity, v.def.capacity)
			var source := _best_source(consumer, good, minf(capacity, need) * FULL_LOAD_RATIO)
			if source == null:
				break  # aucune source n'a encore une charge correcte : on attend
			var v := _nearest_vehicle(carriers, source)
			if v == null:
				break
			var qty := minf(minf(need, supply(source, good)), v.def.capacity)
			if not _start(v, source, consumer, good, qty):
				break
			available.erase(v)
	# Surplus des producteurs vers les entrepôts (jamais de matières dangereuses).
	for producer in registry.all():
		var good := producer.def.output_good
		if good == Goods.Type.NONE or Goods.is_hazardous(good) or is_warehouse(producer):
			continue
		while not available.is_empty() \
				and supply(producer, good) >= producer.def.buffer_capacity * SURPLUS_RATIO:
			var warehouse := _best_warehouse(producer)
			if warehouse == null:
				break
			var v := _nearest_vehicle(available.filter(func(c: Vehicle) -> bool: return can_carry(c, good)),
				producer)
			if v == null:
				break
			var qty := minf(minf(supply(producer, good), storage_room(warehouse)), v.def.capacity)
			if not _start(v, producer, warehouse, good, qty):
				break
			available.erase(v)


## Trains et barges : le stock d'une plateforme (gare, port) part vers la
## plateforme du même réseau qui rapproche cette marchandise de ses clients,
## par chargements presque complets (ou tout de suite si la plateforme de
## départ est presque pleine).
func _dispatch_hubs(available: Array[Vehicle], network: VehicleDef.Network) -> void:
	if available.is_empty():
		return
	for station in registry.all():
		if not station.def.is_hub() or station.def.vehicle_network != network or not station.is_complete():
			continue
		for good: int in station.store.keys():
			while not available.is_empty():
				var stock := supply(station, good)
				if stock < MIN_LOAD:
					break
				var target := _best_hub(station, good)
				if target == null:
					break
				var v := _nearest_vehicle(available, station)
				if v == null:
					break
				var qty := minf(minf(stock, storage_room(target)), v.def.capacity)
				if qty < v.def.capacity * FULL_LOAD_RATIO \
						and station.stored_total() < station.def.storage_capacity * SOURCE_FULL_RATIO:
					break  # chargement trop faible : on attend
				if not _start(v, station, target, good, qty):
					break
				available.erase(v)


## Plateforme du réseau de [param from] la plus proche (par ce réseau),
## ayant de la place, et plus proche par la route que [param from] d'un
## client de [param good].
func _best_hub(from: Building, good: int) -> Building:
	var network := from.def.vehicle_network
	var best: Building = null
	var best_d := 0
	for b in registry.all():
		if b == from or not b.def.is_hub() or b.def.vehicle_network != network or storage_room(b) < MIN_LOAD:
			continue
		var d := distance(from, b, _net_of(network))
		if d < 0 or (best != null and d >= best_d) or not _closer_to_client(b, from, good):
			continue
		best = b
		best_d = d
	return best


## [param station] est-elle plus proche par la route que [param origin] d'un
## consommateur de [param good] ? (Les marchandises ne font que se
## rapprocher de leurs clients : pas d'aller-retour entre gares.)
func _closer_to_client(station: Building, origin: Building, good: int) -> bool:
	for c in registry.all():
		if c.def.input_good != good or not c.is_complete():
			continue
		var d := distance(station, c)
		if d < 0:
			continue
		var from_origin := distance(origin, c)
		if from_origin < 0 or d < from_origin:
			return true
	return false


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
## [param source] par son réseau.
func _nearest_vehicle(available: Array[Vehicle], source: Building) -> Vehicle:
	var center := Vector2(source.anchor)
	var best: Vehicle = null
	var best_d := 0.0
	for v in available:
		var net := _net(v)
		var components := {}
		for c in net.access_cells(source):
			components[net.component_of(c)] = true
		var reachable := false
		for c in _start_cells(v):
			reachable = reachable or components.has(net.component_of(c))
		if not reachable:
			continue
		var d := v.grid_pos.distance_squared_to(center)
		if best == null or d < best_d:
			best = v
			best_d = d
	return best


## Lance la mission ; false si le véhicule ne peut pas rejoindre la source.
func _start(v: Vehicle, source: Building, destination: Building, good: int, qty: float) -> bool:
	var net := _net(v)
	if qty < MIN_LOAD or distance(source, destination, net) < 0:
		return false
	var path := net.path_between(_start_cells(v), net.access_cells(source))
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
