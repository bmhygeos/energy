class_name PowerGrid
extends RefCounted
## Réseau électrique : lignes HT tracées à la tuile, réseaux (composantes
## connexes de lignes, reliées entre elles par les bâtiments qui les
## touchent), équilibre production / demande avec pertes, délestage des
## villes, stockage (batteries, STEP), vente et pénalités, consignes de
## puissance des centrales. Pure donnée.

const LINE_COST := 40
## Multiplicateur de coût sur rivière et montagne (pylônes renforcés).
const HARD_TERRAIN_FACTOR := 3
const UPKEEP_PER_TILE_PER_DAY := 1
## Pertes en ligne : part de la production perdue par tuile de ligne du
## réseau, plafonnée.
const LOSS_PER_TILE := 0.002
const MAX_LOSS := 0.25
## Pénalité (€/MWh non livré à une ville raccordée à un réseau doté de
## centrales) ; le prix de vente suit le marché (Economy).
const PENALTY_PER_MWH := 1.0
## Marge de production demandée aux centrales pilotables.
const MARGIN := 0.05


## État d'un réseau pendant la dernière heure.
class Network:
	var id := 0
	var tiles := 0
	var producers: Array[Building] = []
	var cities: Array[Building] = []
	## Bâtiments consommateurs (laboratoires…), servis avant les villes.
	var loads: Array[Building] = []
	## Stockages (batteries, STEP) : chargent les surplus, couvrent les manques.
	var storages: Array[Building] = []
	var supply_mw := 0.0
	## Part renouvelable de la production (MW).
	var renewable_mw := 0.0
	var demand_mw := 0.0
	var delivered_mw := 0.0
	var loss_ratio := 0.0
	var shed := 0

	func has_supply() -> bool:
		return not producers.is_empty() or not storages.is_empty()


## Bilan d'une heure.
class Report:
	var produced_mw := 0.0
	var demand_mw := 0.0
	var delivered_mw := 0.0
	var revenue := 0.0
	var penalty := 0.0
	## Énergie livrée aux villes (vendue), hors consommation propre.
	var sold_mw := 0.0
	## Part de l'énergie vendue venant des renouvelables (subventionnée).
	var renewable_sold_mw := 0.0
	## Prix de marché de l'heure (€/MWh).
	var price := 0.0
	var shed_cities := 0
	## Énergie mise en stock et restituée pendant l'heure (MWh).
	var charged_mwh := 0.0
	var discharged_mwh := 0.0


var map: WorldMap
## Facteurs des technologies acquises (Research.modifier).
var loss_factor := 1.0
var penalty_factor := 1.0
var fuel_factor := 1.0
## Météo, pour prévoir la production des renouvelables de l'heure suivante.
var weather := Weather.new()
## Marché de l'électricité (prix horaire).
var economy := Economy.new()
## Réseaux de la dernière heure, par identifiant.
var networks: Dictionary[int, Network] = {}
var _line: PackedByteArray
var _component: PackedInt32Array
var _component_count := 0
## Composante de lignes → identifiant de réseau (après union par les bâtiments).
var _component_network: PackedInt32Array
var _tile_count := 0


func _init(p_map: WorldMap) -> void:
	map = p_map
	_line.resize(map.cell_count())
	_component.resize(map.cell_count())
	_rebuild_components()


# --- Lignes ----------------------------------------------------------------

func has_line(cell: Vector2i) -> bool:
	return map.has_cell(cell) and _line[map.index_of(cell)] != 0


func tile_count() -> int:
	return _tile_count


func daily_upkeep() -> int:
	return _tile_count * UPKEEP_PER_TILE_PER_DAY


func tile_cost(cell: Vector2i) -> int:
	match map.get_terrain(cell):
		TerrainDef.Type.SEA, TerrainDef.Type.LAKE:
			return -1
		TerrainDef.Type.RIVER, TerrainDef.Type.MOUNTAIN:
			return LINE_COST * HARD_TERRAIN_FACTOR
	return LINE_COST


func plan(cells: Array[Vector2i], registry: BuildingRegistry, money: int = -1) -> TilePlan:
	return TilePlan.check(cells, map, has_line, tile_cost, registry, false, money)


func build(p: TilePlan) -> void:
	assert(p.is_valid(), "Tracé invalide : " + p.error)
	add_cells(p.new_cells)


func add_cells(cells: Array[Vector2i]) -> void:
	for cell in cells:
		if not has_line(cell):
			_line[map.index_of(cell)] = 1
			_tile_count += 1
	_rebuild_components()


func remove(cell: Vector2i) -> bool:
	if not has_line(cell):
		return false
	_line[map.index_of(cell)] = 0
	_tile_count -= 1
	_rebuild_components()
	return true


func _rebuild_components() -> void:
	_component.fill(0)
	var next := 1
	for i in map.cell_count():
		if not _line[i] or _component[i] != 0:
			continue
		var stack: Array[int] = [i]
		_component[i] = next
		while not stack.is_empty():
			var j: int = stack.pop_back()
			for n in map.neighbors(map.cell_of(j)):
				var k := map.index_of(n)
				if _line[k] and _component[k] == 0:
					_component[k] = next
					stack.append(k)
		next += 1
	_component_count = next - 1
	_component_network = PackedInt32Array()
	_component_network.resize(next)
	for c in next:
		_component_network[c] = c


## Réseau auquel appartient la ligne de [param cell] (0 : aucune).
func network_at(cell: Vector2i) -> int:
	if not has_line(cell):
		return 0
	var c := _component[map.index_of(cell)]
	return _component_network[c] if c < _component_network.size() else c


## Composantes de lignes touchant (4-connexité) l'emprise de [param b].
func _adjacent_components(b: Building) -> Array[int]:
	var result: Array[int] = []
	for cell in b.cells:
		for n in map.neighbors(cell):
			if has_line(n) and n not in b.cells:
				var c := _component[map.index_of(n)]
				if c not in result:
					result.append(c)
	return result


# --- Topologie et équilibre -----------------------------------------------

## Recalcule le raccordement des bâtiments et les réseaux (union des
## composantes reliées par un même bâtiment).
func refresh_topology(registry: BuildingRegistry) -> void:
	var parent := PackedInt32Array()
	parent.resize(_component_count + 1)
	for c in parent.size():
		parent[c] = c
	var adjacency: Dictionary[int, Array] = {}
	for b in registry.all():
		var comps := _adjacent_components(b)
		adjacency[b.id] = comps
		for k in range(1, comps.size()):
			var ra := _find(parent, comps[0])
			var rb := _find(parent, comps[k])
			if ra != rb:
				parent[maxi(ra, rb)] = mini(ra, rb)
	for c in parent.size():
		_component_network[c] = _find(parent, c)
	networks.clear()
	for c in range(1, parent.size()):
		var id := _component_network[c]
		if not networks.has(id):
			var n := Network.new()
			n.id = id
			networks[id] = n
	for i in map.cell_count():
		if _line[i]:
			networks[_component_network[_component[i]]].tiles += 1
	for b in registry.all():
		var comps: Array = adjacency[b.id]
		b.grid_id = _component_network[comps[0]] if not comps.is_empty() else 0
		if b.grid_id == 0:
			b.power_setpoint = 0.0
			b.powered = false
			if b.city:
				b.city.supply = City.Supply.NOT_CONNECTED
			continue
		var net := networks[b.grid_id]
		if b.city:
			net.cities.append(b)
		elif b.def.is_grid_storage() and b.is_complete():
			net.storages.append(b)
		elif b.def.power_mw > 0.0 and b.is_complete():
			net.producers.append(b)
		elif b.def.power_demand_mw > 0.0 and b.is_complete():
			net.loads.append(b)
	for net: Network in networks.values():
		net.loss_ratio = minf(MAX_LOSS, net.tiles * LOSS_PER_TILE * loss_factor)


static func _find(parent: PackedInt32Array, c: int) -> int:
	while parent[c] != c:
		parent[c] = parent[parent[c]]
		c = parent[c]
	return c


## Règle l'heure [param tick] : livre la production de l'heure aux villes
## (délestage des villes qui ne peuvent être servies, les plus petites étant
## servies d'abord) au prix du marché, modulé par la satisfaction de chaque
## ville, puis fixe les consignes de l'heure suivante.
func step(tick: int, registry: BuildingRegistry) -> Report:
	refresh_topology(registry)
	var report := Report.new()
	report.price = economy.price_at(tick)
	for net: Network in networks.values():
		for p in net.producers:
			net.supply_mw += p.power_mw
			if p.def.is_renewable():
				net.renewable_mw += p.power_mw
		var sold := 0.0
		var produced := net.supply_mw * (1.0 - net.loss_ratio)
		# Les stockages complètent la production pour éviter les délestages.
		var discharge_capacity := 0.0
		for st in net.storages:
			discharge_capacity += minf(st.def.storage_power_mw, st.stored_mwh)
		var available := produced + discharge_capacity
		# Bâtiments consommateurs d'abord (consommation propre, non vendue).
		for b in net.loads:
			var need := b.def.power_demand_mw
			net.demand_mw += need
			b.powered = net.has_supply() and need <= available + 0.0001
			if b.powered:
				available -= need
				net.delivered_mw += need
		var cities := net.cities.duplicate()
		cities.sort_custom(func(a: Building, b: Building) -> bool:
			var da := a.city.demand_at(tick)
			var db := b.city.demand_at(tick)
			return da < db if da != db else a.id < b.id)
		for b: Building in cities:
			var city := b.city
			var d := city.demand_at(tick)
			net.demand_mw += d
			if not net.has_supply():
				city.supply = City.Supply.NO_SUPPLY
			elif d <= available + 0.0001:
				available -= d
				net.delivered_mw += d
				sold += d
				report.revenue += d * report.price * Economy.tariff(city.satisfaction)
				city.supply = City.Supply.SERVED
				city.served_hours_today += 1
			else:
				city.supply = City.Supply.SHED
				city.shed_hours_today += 1
				net.shed += 1
				report.penalty += d * PENALTY_PER_MWH * penalty_factor
		var used := produced + discharge_capacity - available
		if used > produced:
			report.discharged_mwh += _discharge(net, used - produced, discharge_capacity)
		else:
			for st in net.storages:
				st.storage_flow_mw = 0.0
			report.charged_mwh += _charge(net, produced - used)
		report.sold_mw += sold
		if net.supply_mw > 0.0:
			report.renewable_sold_mw += sold * net.renewable_mw / net.supply_mw
		report.produced_mw += net.supply_mw
		report.demand_mw += net.demand_mw
		report.delivered_mw += net.delivered_mw
		report.shed_cities += net.shed
	plan_setpoints(tick + 1)
	return report


## Restitue [param amount] MWh, répartis au prorata de ce que chaque
## stockage peut fournir ([param capacity] au total).
func _discharge(net: Network, amount: float, capacity: float) -> float:
	for st in net.storages:
		var share := minf(st.def.storage_power_mw, st.stored_mwh) / capacity * amount
		st.stored_mwh = maxf(0.0, st.stored_mwh - share)
		st.storage_flow_mw = -share
	return amount


## Met en stock jusqu'à [param surplus] MWh, au prorata de ce que chaque
## stockage peut absorber ; le rendement s'applique à la charge.
func _charge(net: Network, surplus: float) -> float:
	var room := 0.0
	for st in net.storages:
		room += _charge_room(st)
	if room <= 0.0 or surplus <= 0.0:
		return 0.0
	var absorbed := minf(surplus, room)
	for st in net.storages:
		var share := _charge_room(st) / room * absorbed
		st.stored_mwh = minf(st.def.storage_mwh, st.stored_mwh + share * st.def.storage_efficiency)
		st.storage_flow_mw = share
	return absorbed


## Énergie (MWh, côté réseau) qu'un stockage peut encore absorber en une heure.
static func _charge_room(st: Building) -> float:
	return minf(st.def.storage_power_mw, (st.def.storage_mwh - st.stored_mwh) / st.def.storage_efficiency)


## Consignes des centrales pilotables pour l'heure [param tick] : les
## renouvelables d'abord (production prévue avec la météo), le reste réparti
## au prorata de ce que chaque centrale peut fournir (combustible, chaleur).
func plan_setpoints(tick: int) -> void:
	for net: Network in networks.values():
		var required := 0.0
		for b in net.cities:
			required += b.city.demand_at(tick)
		for b in net.loads:
			required += b.def.power_demand_mw
		required *= (1.0 + MARGIN) / (1.0 - net.loss_ratio)
		var capacity := 0.0
		var dispatchable: Array[Building] = []
		for p in net.producers:
			if p.def.is_dispatchable():
				dispatchable.append(p)
				capacity += p.def.power_mw * _available_fraction(p, tick)
			else:
				required -= p.def.power_mw * Production.renewable_factor(map, weather, p, tick)
		var ratio := clampf(required / capacity, 0.0, 1.0) if capacity > 0.0 else 0.0
		for p in dispatchable:
			p.power_setpoint = ratio * _available_fraction(p, tick)


## Part de la pleine puissance qu'une centrale pilotable peut fournir
## pendant l'heure [param tick] (combustible ou chaleur en stock).
func _available_fraction(b: Building, tick: int) -> float:
	if b.def.power_source == BuildingDef.PowerSource.SOLAR_THERMAL:
		var heat := b.stored_mwh + Production.heat_collected(map, weather, b, tick)
		return clampf(heat / b.def.power_mw, 0.0, 1.0)
	return _fuel_fraction(b, fuel_factor)


## Part de la pleine puissance que le combustible en stock (et la place
## libre pour les résidus, déchets nucléaires) permet pendant une heure.
static func _fuel_fraction(b: Building, fuel_use: float) -> float:
	var fraction := 1.0
	if b.def.input_good != Goods.Type.NONE and b.def.input_per_hour > 0.0:
		fraction = b.input_stock / (b.def.input_per_hour * fuel_use)
	if b.def.output_good != Goods.Type.NONE and b.def.output_per_hour > 0.0:
		fraction = minf(fraction, (b.def.buffer_capacity - b.output_stock) / b.def.output_per_hour)
	return clampf(fraction, 0.0, 1.0)
