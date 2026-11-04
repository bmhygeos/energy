class_name BuildingRegistry
extends RefCounted
## Bâtiments de la partie : occupation des tuiles, règles de placement (sur
## le territoire) et chantiers. Les tuiles des bâtiments sont dans le repère
## de l'appelant (abscisses dépliées autour du village) ; l'occupation est
## indexée par tuile ramenée sur la planète. Pure donnée.


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
var territory: Territory
## Voies ferrées (null : aucune) : pas de bâtiment dessus.
var rails: RailNetwork
var roads: RoadNetwork
var _buildings: Dictionary[int, Building] = {}
## Identifiant du bâtiment par tuile occupée (ramenée sur la planète).
var _occupancy: Dictionary[Vector2i, int] = {}
var _next_id := 1


func _init(p_map: WorldMap, p_territory: Territory) -> void:
	map = p_map
	territory = p_territory


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
	return _buildings.get(_occupancy.get(map.wrap_cell(cell), 0))


## Vérifie que [param def] peut être construit ancré en [param anchor].
func check_placement(def: BuildingDef, anchor: Vector2i) -> Placement:
	var p := Placement.new()
	p.def = def
	p.anchor = anchor
	p.cells = def.footprint(anchor)
	p.error = _placement_error(p)
	return p


func _placement_error(p: Placement) -> String:
	var def := p.def
	var water_found := false
	for cell in p.cells:
		if not map.has_cell(cell):
			return "Hors de la carte"
		if not territory.is_territory(cell):
			return "Hors du territoire"
		var occupant := building_at(cell)
		if occupant:
			return "Emplacement occupé (%s)" % occupant.def.display_name
		if rails and rails.has_rail(cell):
			return "Voie ferrée présente"
		if roads and roads.has_tile(cell):
			return "Route présente"
		var t := map.get_terrain(cell)
		var terrain := TerrainDb.get_def(t)
		if not terrain.buildable:
			return "Terrain non constructible (%s)" % terrain.display_name.to_lower()
		if not def.allowed_terrains.is_empty() and t not in def.allowed_terrains:
			return "Terrain interdit pour ce bâtiment (%s)" % terrain.display_name.to_lower()
		if t == TerrainDef.Type.FOREST:
			p.cleared.append(cell)
		water_found = water_found or map.has_water_access(cell)
	if def.needs_water_access and not water_found:
		return "Nécessite un accès à l'eau"
	if not def.adjacent_terrains.is_empty() and not _has_adjacent(p.cells, def.adjacent_terrains):
		return "Doit être à côté de : " + BuildingDef._terrain_names(def.adjacent_terrains)
	return ""


## Une tuile voisine (8-connexité) hors de l'emprise est-elle d'un de ces
## terrains ?
func _has_adjacent(cells: Array[Vector2i], terrains: Array[TerrainDef.Type]) -> bool:
	for cell in cells:
		for n in map.neighbors(cell, WorldMap.NEIGHBORS_8):
			if n not in cells and map.get_terrain(n) in terrains:
				return true
	return false


## Pose le chantier d'un placement valide ; défriche les forêts de l'emprise.
func place(p: Placement) -> Building:
	assert(p.is_valid(), "Placement invalide : " + p.error)
	var b := Building.new(_next_id, p.def, p.anchor)
	_next_id += 1
	_buildings[b.id] = b
	for cell in b.cells:
		_occupancy[map.wrap_cell(cell)] = b.id
	for cell in p.cleared:
		map.set_terrain(cell, TerrainDef.Type.PLAIN)
		map.set_wood(cell, 0.0)
	return b


func remove(b: Building) -> void:
	assert(_buildings.get(b.id) == b, "Bâtiment inconnu")
	for cell in b.cells:
		_occupancy.erase(map.wrap_cell(cell))
	_buildings.erase(b.id)


## Fait avancer les chantiers de [param hours] heures ; renvoie les bâtiments
## qui viennent d'être terminés (mis en service).
func advance(hours: int = 1) -> Array[Building]:
	var completed: Array[Building] = []
	for b: Building in _buildings.values():
		if b.is_complete():
			continue
		b.build_progress = mini(b.build_progress + hours, b.def.build_hours)
		if b.is_complete():
			b.status = Building.Status.RUNNING
			completed.append(b)
	return completed
