class_name BuildingRegistry
extends RefCounted
## Bâtiments de la partie : occupation des tuiles, règles de placement,
## chantiers, entretien et remboursement à la démolition. Pure donnée :
## l'argent est géré par l'appelant (GameState).

## Part du coût remboursée à la démolition d'un bâtiment terminé…
const REFUND_COMPLETE := 0.25
## … et à l'annulation d'un chantier.
const REFUND_UNDER_CONSTRUCTION := 0.75


## Résultat d'une vérification de placement.
class Placement:
	var def: BuildingDef
	var anchor: Vector2i
	var cells: Array[Vector2i] = []
	## Message d'erreur en français ; vide si le placement est possible.
	var error := ""
	## Tuiles de forêt qui seront défrichées.
	var cleared: Array[Vector2i] = []

	func is_valid() -> bool:
		return error.is_empty()


var map: WorldMap
var roads: RoadNetwork
var rails: RailNetwork
var grid: PowerGrid
var _buildings: Dictionary[int, Building] = {}
## Identifiant du bâtiment par tuile (0 : libre).
var _occupancy: PackedInt32Array
var _next_id := 1


func _init(p_map: WorldMap, p_roads: RoadNetwork = null, p_grid: PowerGrid = null,
		p_rails: RailNetwork = null) -> void:
	map = p_map
	roads = p_roads if p_roads else RoadNetwork.new(map)
	grid = p_grid if p_grid else PowerGrid.new(map)
	rails = p_rails if p_rails else RailNetwork.new(map)
	_occupancy.resize(map.cell_count())


func all() -> Array[Building]:
	return _buildings.values()


func count() -> int:
	return _buildings.size()


func get_building(id: int) -> Building:
	return _buildings.get(id)


## Bâtiment occupant [param cell], ou null.
func building_at(cell: Vector2i) -> Building:
	if not map.has_cell(cell):
		return null
	return _buildings.get(_occupancy[map.index_of(cell)])


## Vérifie que [param def] peut être construit ancré en [param anchor] avec
## [param money] disponible (argent ignoré si négatif).
func check_placement(def: BuildingDef, anchor: Vector2i, money: int = -1) -> Placement:
	var p := Placement.new()
	p.def = def
	p.anchor = anchor
	p.cells = def.footprint(anchor)
	p.error = _placement_error(p)
	if p.error.is_empty() and money >= 0 and money < def.cost:
		p.error = "Fonds insuffisants (%s € requis)" % Format.thousands(def.cost)
	return p


func _placement_error(p: Placement) -> String:
	var def := p.def
	var deposit_found := false
	var water_found := false
	var coast_found := false
	var wind := 0.0
	var sun := 0.0
	for cell in p.cells:
		if not map.has_cell(cell):
			return "Hors de la carte"
		var i := map.index_of(cell)
		if _occupancy[i] != 0:
			return "Emplacement occupé (%s)" % _buildings[_occupancy[i]].def.display_name
		if roads.has_road(cell):
			return "Route présente"
		if rails.has_rail(cell):
			return "Voie ferrée présente"
		if grid.has_line(cell):
			return "Ligne électrique présente"
		var t := map.terrain[i]
		var terrain := TerrainDb.get_def(t)
		if not terrain.buildable:
			return "Terrain non constructible (%s)" % terrain.display_name.to_lower()
		if not def.allowed_terrains.is_empty() and t not in def.allowed_terrains:
			return "Terrain interdit pour ce bâtiment (%s)" % terrain.display_name.to_lower()
		if t == TerrainDef.Type.FOREST:
			p.cleared.append(cell)
		deposit_found = deposit_found or map.deposit[i] == def.required_deposit
		water_found = water_found or map.water_access[i] != 0
		coast_found = coast_found or map.coastal[i] != 0
		wind += map.wind[i]
		sun += map.sun[i]
	if def.required_deposit != WorldMap.Deposit.NONE and not deposit_found:
		return "Nécessite un gisement de %s" % WorldMap.DEPOSIT_NAMES[def.required_deposit].to_lower()
	if def.needs_road and not _touches(roads, p.cells):
		return "Doit être relié à une route"
	if def.needs_rail and not _touches(rails, p.cells):
		return "Doit être relié à une voie ferrée"
	if def.needs_water_access and not water_found:
		return "Nécessite un accès à l'eau"
	if def.needs_coast and not coast_found:
		return "Doit être sur la côte"
	if not def.adjacent_terrains.is_empty() and not _has_adjacent(p.cells, def.adjacent_terrains):
		var names := PackedStringArray()
		for t in def.adjacent_terrains:
			names.append(TerrainDb.get_def(t).display_name.to_lower())
		return "Doit être à côté de : " + ", ".join(names)
	var n := float(p.cells.size())
	if wind / n < def.min_wind:
		return "Vent insuffisant (%d %% < %d %%)" % [roundi(wind / n * 100.0), roundi(def.min_wind * 100.0)]
	if sun / n < def.min_sun:
		return "Ensoleillement insuffisant (%d %% < %d %%)" % [roundi(sun / n * 100.0), roundi(def.min_sun * 100.0)]
	return ""


## Une tuile du réseau [param network] borde-t-elle ces tuiles ?
func _touches(network: RoadNetwork, cells: Array[Vector2i]) -> bool:
	for cell in cells:
		for n in map.neighbors(cell):
			if network.has_road(n):
				return true
	return false


## Une tuile voisine (8-connexité) hors de l'emprise est-elle d'un de ces
## terrains ?
func _has_adjacent(cells: Array[Vector2i], terrains: Array[TerrainDef.Type]) -> bool:
	for cell in cells:
		for n in map.neighbors(cell, WorldMap.NEIGHBORS_8):
			if n not in cells and map.terrain[map.index_of(n)] in terrains:
				return true
	return false


## Pose le chantier d'un placement valide ; défriche les forêts de l'emprise.
func place(p: Placement) -> Building:
	assert(p.is_valid(), "Placement invalide : " + p.error)
	var b := Building.new(_next_id, p.def, p.anchor)
	_next_id += 1
	_buildings[b.id] = b
	for cell in b.cells:
		_occupancy[map.index_of(cell)] = b.id
	for cell in p.cleared:
		map.terrain[map.index_of(cell)] = TerrainDef.Type.PLAIN
		map.wood[map.index_of(cell)] = 0.0
	return b


func remove(b: Building) -> void:
	assert(_buildings.get(b.id) == b, "Bâtiment inconnu")
	for cell in b.cells:
		_occupancy[map.index_of(cell)] = 0
	_buildings.erase(b.id)


## Somme remboursée si [param b] est démoli maintenant.
static func refund_for(b: Building) -> int:
	var ratio := REFUND_COMPLETE if b.is_complete() else REFUND_UNDER_CONSTRUCTION
	return floori(b.def.cost * ratio)


## Fait avancer les chantiers de [param hours] heures ; renvoie les bâtiments
## qui viennent d'être terminés.
func advance(hours: int = 1) -> Array[Building]:
	var completed: Array[Building] = []
	for b: Building in _buildings.values():
		if b.is_complete():
			continue
		b.build_progress = mini(b.build_progress + hours, b.def.build_hours)
		if b.is_complete():
			completed.append(b)
	return completed


## Entretien journalier des bâtiments terminés.
func daily_upkeep() -> int:
	var total := 0
	for b: Building in _buildings.values():
		if b.is_complete():
			total += b.def.upkeep_per_day
	return total
