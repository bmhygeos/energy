class_name RoadNetwork
extends RefCounted
## Routes : tuiles de route, coûts de construction, graphe de transport
## (AStar2D, 4-connexité), composantes connexes et accès des bâtiments.
## Pure donnée.

const COST_PER_TILE := 50
const HILL_COST_FACTOR := 2.0
const FOREST_EXTRA_COST := 25
const BRIDGE_COST := 400
const UPKEEP_PER_TILE_PER_DAY := 1


## Tracé de route projeté.
class Plan:
	## Tuiles du tracé, dans l'ordre.
	var cells: Array[Vector2i] = []
	## Tuiles à construire (hors routes existantes).
	var new_cells: Array[Vector2i] = []
	## Tuiles qui empêchent le tracé.
	var blocked: Array[Vector2i] = []
	## Forêts à défricher.
	var cleared: Array[Vector2i] = []
	var cost := 0
	var error := ""

	func is_valid() -> bool:
		return error.is_empty() and not new_cells.is_empty()


var map: WorldMap
var _road: PackedByteArray
## Composante connexe par tuile de route (0 : pas de route).
var _component: PackedInt32Array
var _astar := AStar2D.new()
var _tile_count := 0


func _init(p_map: WorldMap) -> void:
	map = p_map
	_road.resize(map.cell_count())
	_component.resize(map.cell_count())


func has_road(cell: Vector2i) -> bool:
	return map.has_cell(cell) and _road[map.index_of(cell)] != 0


func tile_count() -> int:
	return _tile_count


func daily_upkeep() -> int:
	return _tile_count * UPKEEP_PER_TILE_PER_DAY


func component_of(cell: Vector2i) -> int:
	return _component[map.index_of(cell)] if map.has_cell(cell) else 0


## Coût de construction d'une route sur [param cell] (-1 : impossible).
func tile_cost(cell: Vector2i) -> int:
	match map.get_terrain(cell):
		TerrainDef.Type.PLAIN, TerrainDef.Type.DESERT:
			return COST_PER_TILE
		TerrainDef.Type.FOREST:
			return COST_PER_TILE + FOREST_EXTRA_COST
		TerrainDef.Type.HILL:
			return roundi(COST_PER_TILE * HILL_COST_FACTOR)
		TerrainDef.Type.RIVER:
			return BRIDGE_COST
	return -1


## Tracé en L de [param from] à [param to] (axe le plus long d'abord).
static func l_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = [from]
	var c := from
	var x_first := absi(to.x - from.x) >= absi(to.y - from.y)
	for pass_index in 2:
		if (pass_index == 0) == x_first:
			while c.x != to.x:
				c.x += signi(to.x - c.x)
				cells.append(c)
		else:
			while c.y != to.y:
				c.y += signi(to.y - c.y)
				cells.append(c)
	return cells


## Vérifie le tracé [param cells] ; [param registry] sert à exclure les
## tuiles occupées par des bâtiments, [param money] (si ≥ 0) le coût.
func plan(cells: Array[Vector2i], registry: BuildingRegistry, money: int = -1) -> Plan:
	var p := Plan.new()
	p.cells = cells
	for cell in cells:
		if not map.has_cell(cell):
			p.blocked.append(cell)
			continue
		if has_road(cell):
			continue
		var cost := tile_cost(cell)
		if cost < 0 or (registry and registry.building_at(cell) != null):
			p.blocked.append(cell)
			continue
		p.new_cells.append(cell)
		p.cost += cost
		if map.get_terrain(cell) == TerrainDef.Type.FOREST:
			p.cleared.append(cell)
	if not p.blocked.is_empty():
		var cell := p.blocked[0]
		if not map.has_cell(cell):
			p.error = "Hors de la carte"
		elif registry and registry.building_at(cell):
			p.error = "Bâtiment sur le tracé (%s)" % registry.building_at(cell).def.display_name
		else:
			p.error = "Terrain infranchissable (%s)" % TerrainDb.get_def(map.get_terrain(cell)).display_name.to_lower()
	elif p.new_cells.is_empty():
		p.error = "Route déjà construite"
	elif money >= 0 and money < p.cost:
		p.error = "Fonds insuffisants (%s € requis)" % Format.thousands(p.cost)
	return p


## Construit les tuiles d'un tracé valide ; défriche les forêts.
func build(p: Plan) -> void:
	assert(p.is_valid(), "Tracé invalide : " + p.error)
	for cell in p.new_cells:
		_road[map.index_of(cell)] = 1
		_tile_count += 1
	for cell in p.cleared:
		map.terrain[map.index_of(cell)] = TerrainDef.Type.PLAIN
		map.wood[map.index_of(cell)] = 0.0
	_rebuild_graph()


## Ajoute des routes sans coût ni vérification (tests, chargement).
func add_cells(cells: Array[Vector2i]) -> void:
	for cell in cells:
		if not has_road(cell):
			_road[map.index_of(cell)] = 1
			_tile_count += 1
	_rebuild_graph()


func remove(cell: Vector2i) -> bool:
	if not has_road(cell):
		return false
	_road[map.index_of(cell)] = 0
	_tile_count -= 1
	_rebuild_graph()
	return true


## Reconstruit le graphe AStar2D et les composantes connexes.
func _rebuild_graph() -> void:
	_astar.clear()
	_component.fill(0)
	for i in map.cell_count():
		if _road[i]:
			_astar.add_point(i, Vector2(map.cell_of(i)))
	for i in map.cell_count():
		if not _road[i]:
			continue
		var cell := map.cell_of(i)
		for o in [Vector2i(1, 0), Vector2i(0, 1)]:
			if has_road(cell + o):
				_astar.connect_points(i, map.index_of(cell + o))
	var next := 1
	for i in map.cell_count():
		if not _road[i] or _component[i] != 0:
			continue
		var stack: Array[int] = [i]
		_component[i] = next
		while not stack.is_empty():
			var j: int = stack.pop_back()
			for n in map.neighbors(map.cell_of(j)):
				var k := map.index_of(n)
				if _road[k] and _component[k] == 0:
					_component[k] = next
					stack.append(k)
		next += 1


## Tuiles de route bordant (4-connexité) l'emprise de [param b].
func access_cells(b: Building) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell in b.cells:
		for n in map.neighbors(cell):
			if has_road(n) and n not in b.cells and n not in result:
				result.append(n)
	return result


func is_connected_building(b: Building) -> bool:
	return not access_cells(b).is_empty()


## Plus court chemin (tuiles, départ et arrivée compris) entre une tuile de
## [param from] et une de [param to] ; vide si aucun.
func path_between(from: Array[Vector2i], to: Array[Vector2i]) -> Array[Vector2i]:
	var best: Array[Vector2i] = []
	# Paires de même composante, de la plus proche à la plus lointaine (à vol
	# d'oiseau) ; on garde le meilleur chemin réel parmi les plus proches.
	var pairs: Array = []
	for a in from:
		for b in to:
			var ca := component_of(a)
			if ca != 0 and ca == component_of(b):
				pairs.append([absi(a.x - b.x) + absi(a.y - b.y), a, b])
	pairs.sort_custom(func(p: Array, q: Array) -> bool: return p[0] < q[0])
	for k in mini(pairs.size(), 4):
		var a: Vector2i = pairs[k][1]
		var b: Vector2i = pairs[k][2]
		var ids := _astar.get_id_path(map.index_of(a), map.index_of(b))
		if ids.is_empty():
			continue
		if best.is_empty() or ids.size() < best.size():
			best = []
			for id in ids:
				best.append(map.cell_of(id))
	return best
