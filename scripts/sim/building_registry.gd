class_name BuildingRegistry
extends RefCounted
## Bâtiments de la partie : occupation des tuiles, règles de placement et
## chantiers. Pure donnée.


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
var _buildings: Dictionary[int, Building] = {}
## Identifiant du bâtiment par tuile (0 : libre).
var _occupancy: PackedInt32Array
var _next_id := 1


func _init(p_map: WorldMap) -> void:
	map = p_map
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
		var i := map.index_of(cell)
		if _occupancy[i] != 0:
			return "Emplacement occupé (%s)" % _buildings[_occupancy[i]].def.display_name
		var t := map.terrain[i]
		var terrain := TerrainDb.get_def(t)
		if not terrain.buildable:
			return "Terrain non constructible (%s)" % terrain.display_name.to_lower()
		if not def.allowed_terrains.is_empty() and t not in def.allowed_terrains:
			return "Terrain interdit pour ce bâtiment (%s)" % terrain.display_name.to_lower()
		if t == TerrainDef.Type.FOREST:
			p.cleared.append(cell)
		water_found = water_found or map.water_access[i] != 0
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
