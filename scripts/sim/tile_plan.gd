class_name TilePlan
extends RefCounted
## Tracé projeté d'un réseau tracé à la tuile (route, ligne électrique).

## Tuiles du tracé, dans l'ordre.
var cells: Array[Vector2i] = []
## Tuiles à construire (hors tuiles déjà équipées).
var new_cells: Array[Vector2i] = []
## Tuiles qui empêchent le tracé.
var blocked: Array[Vector2i] = []
## Forêts à défricher.
var cleared: Array[Vector2i] = []
var cost := 0
var error := ""


func is_valid() -> bool:
	return error.is_empty() and not new_cells.is_empty()


## Vérifie [param p_cells] : [param exists] (tuile → bool) indique les tuiles
## déjà équipées, [param tile_cost] (tuile → int, -1 : impossible) le coût ;
## les bâtiments de [param registry] bloquent ; [param clears_forest] défriche.
static func check(p_cells: Array[Vector2i], map: WorldMap, exists: Callable, tile_cost: Callable,
		registry: BuildingRegistry, clears_forest: bool, money: int = -1) -> TilePlan:
	var p := TilePlan.new()
	p.cells = p_cells
	for cell in p_cells:
		if not map.has_cell(cell):
			p.blocked.append(cell)
			continue
		if exists.call(cell):
			continue
		var cost: int = tile_cost.call(cell)
		if cost < 0 or (registry and registry.building_at(cell) != null):
			p.blocked.append(cell)
			continue
		p.new_cells.append(cell)
		p.cost += cost
		if clears_forest and map.get_terrain(cell) == TerrainDef.Type.FOREST:
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
		p.error = "Déjà construit"
	elif money >= 0 and money < p.cost:
		p.error = "Fonds insuffisants (%s € requis)" % Format.thousands(p.cost)
	return p


## Tracé en L de [param from] à [param to] (axe le plus long d'abord).
static func l_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = [from]
	var c := from
	var x_first := absi(to.x - from.x) >= absi(to.y - from.y)
	for pass_index in 2:
		if (pass_index == 0) == x_first:
			while c.x != to.x:
				c.x += signi(to.x - c.x)
				result.append(c)
		else:
			while c.y != to.y:
				c.y += signi(to.y - c.y)
				result.append(c)
	return result
