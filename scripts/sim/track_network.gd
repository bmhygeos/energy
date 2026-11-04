class_name TrackNetwork
extends RefCounted
## Tracé posé tuile à tuile au glisser (tracé en L), sur le territoire, hors
## des bâtiments et des zones : base des voies ferrées et des routes. Forêts
## défrichées, pont plus cher sur une rivière. Tuiles stockées ramenées sur la
## planète. Pure donnée.

## Un pont sur une rivière coûte BRIDGE_FACTOR fois plus.
const BRIDGE_FACTOR := 5.0
const FORBIDDEN: Array[TerrainDef.Type] = [TerrainDef.Type.MOUNTAIN, TerrainDef.Type.LAKE,
	TerrainDef.Type.SEA, TerrainDef.Type.ICE]


## Aperçu d'un tracé de voie.
class Plan:
	## Tuiles du tracé (repère de l'appelant).
	var cells: Array[Vector2i] = []
	## Tuiles sans voie à poser.
	var new_cells: Array[Vector2i] = []
	## Forêts défrichées.
	var cleared: Array[Vector2i] = []
	var costs := Stockpile.zeros()
	## Message d'erreur ; vide si le tracé est possible.
	var error := ""

	func is_valid() -> bool:
		return error.is_empty() and not new_cells.is_empty()


var map: WorldMap
var territory: Territory
var buildings: BuildingRegistry
## Zones (null : pas de vérification).
var zones: ZoneMap
## Centre du village.
var center: Vector2i
var _tiles: Dictionary[Vector2i, bool] = {}


func _init(p_map: WorldMap, p_territory: Territory, p_buildings: BuildingRegistry, p_center: Vector2i) -> void:
	map = p_map
	territory = p_territory
	buildings = p_buildings
	center = p_center


func has_tile(cell: Vector2i) -> bool:
	return _tiles.has(map.wrap_cell(cell))


func tile_count() -> int:
	return _tiles.size()


## Tuiles de voie (ramenées sur la planète).
func cells() -> Array[Vector2i]:
	return _tiles.keys()


## Tracé en L de [param from] à [param to] : l'axe le plus long d'abord.
static func l_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = [from]
	var d := to - from
	var corner := Vector2i(to.x, from.y) if absi(d.x) >= absi(d.y) else Vector2i(from.x, to.y)
	for target in [corner, to]:
		var cell: Vector2i = path[-1]
		while cell != target:
			cell += Vector2i(signi(target.x - cell.x), signi(target.y - cell.y))
			path.append(cell)
	return path


## Motif qui empêche une voie sur [param cell] (vide : possible).
func check_cell(cell: Vector2i) -> String:
	if not map.has_cell(cell) or not territory.is_territory(cell):
		return "Hors du territoire"
	var b := buildings.building_at(cell)
	if b:
		return "Bâtiment présent (%s)" % b.def.display_name
	if zones and zones.zone_at(cell):
		return "Zone présente (%s) : effacez-la d'abord" % zones.zone_at(cell).display_name
	var t := map.get_terrain(cell)
	if t in FORBIDDEN:
		return "Pas de %s sur : %s" % [track_name(), TerrainDb.get_def(t).display_name.to_lower()]
	return ""


## Matériaux d'une tuile hors rivière (à définir par chaque réseau).
func base_costs() -> PackedFloat32Array:
	return Stockpile.zeros()


## Nom du tracé (« voie », « route »), au féminin.
func track_name() -> String:
	return "voie"


## Matériaux pour un tracé sur [param cell] (pont sur une rivière : plus cher).
func tile_costs(cell: Vector2i) -> PackedFloat32Array:
	var values := base_costs()
	if map.get_terrain(cell) == TerrainDef.Type.RIVER:
		for good in Stockpile.COUNT:
			values[good] *= BRIDGE_FACTOR
	return values


## Aperçu du tracé de [param from] à [param to].
func plan(from: Vector2i, to: Vector2i) -> Plan:
	var p := Plan.new()
	p.cells = l_path(from, to)
	for cell in p.cells:
		if has_tile(cell):
			continue
		var error := check_cell(cell)
		if not error.is_empty():
			p.error = error
			p.new_cells.clear()
			return p
		p.new_cells.append(cell)
		if map.get_terrain(cell) == TerrainDef.Type.FOREST:
			p.cleared.append(cell)
		var costs := tile_costs(cell)
		for good in Stockpile.COUNT:
			p.costs[good] += costs[good]
	if p.new_cells.is_empty():
		p.error = "%s déjà posée" % track_name().capitalize()
	return p


## Pose les voies d'un tracé valide (forêts défrichées) ; renvoie les tuiles
## posées.
func build(p: Plan) -> Array[Vector2i]:
	assert(p.is_valid(), "Tracé invalide : " + p.error)
	for cell in p.cleared:
		map.set_terrain(cell, TerrainDef.Type.PLAIN)
		map.set_wood(cell, 0.0)
	add_cells(p.new_cells)
	return p.new_cells


## Ajoute des voies sans coût ni vérification (tests).
func add_cells(new_cells: Array[Vector2i]) -> void:
	for cell in new_cells:
		_tiles[map.wrap_cell(cell)] = true


func remove(cell: Vector2i) -> bool:
	return _tiles.erase(map.wrap_cell(cell))


## Distance de Tchebychev entre deux tuiles (longitude bouclée).
func cheb(a: Vector2i, b: Vector2i) -> int:
	var w := map.size.x
	var dx := absi(posmod(a.x - b.x + w / 2, w) - w / 2)
	return maxi(dx, absi(a.y - b.y))
