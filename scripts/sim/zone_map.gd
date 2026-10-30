class_name ZoneMap
extends RefCounted
## Zones peintes par le joueur : au plus une zone par tuile du territoire,
## hors des bâtiments, sur un terrain valide pour la zone. Indexée par tuile
## ramenée sur la planète. Pure donnée.


## Aperçu d'une peinture (ou d'un effacement) sur un rectangle.
class Plan:
	## Zone peinte (null : effacement).
	var def: ZoneDef
	var cells: Array[Vector2i] = []
	## Tuiles qui changeront.
	var changed: Array[Vector2i] = []
	## Motif du premier refus (vide : aucune tuile refusée).
	var error := ""
	var refused := 0


var map: WorldMap
var territory: Territory
var buildings: BuildingRegistry
var _zones: Dictionary[Vector2i, ZoneDef] = {}


func _init(p_map: WorldMap, p_territory: Territory, p_buildings: BuildingRegistry) -> void:
	map = p_map
	territory = p_territory
	buildings = p_buildings


## Zone de [param cell] (null : aucune).
func zone_at(cell: Vector2i) -> ZoneDef:
	return _zones.get(map.wrap_cell(cell)) if map.has_cell(cell) else null


## Tuiles de la zone [param def] (ramenées sur la planète).
func cells_of(def: ZoneDef) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell: Vector2i in _zones:
		if _zones[cell] == def:
			result.append(cell)
	return result


## Toutes les tuiles zonées (ramenées sur la planète).
func all_cells() -> Array[Vector2i]:
	return _zones.keys()


func tile_count(def: ZoneDef) -> int:
	return cells_of(def).size()


## Places de travail offertes par la zone [param def] (tuiles productives).
func places(def: ZoneDef) -> int:
	return cells_of(def).filter(func(c: Vector2i) -> bool: return def.is_productive(map, c)).size() \
		* def.workers_per_tile


## Motif qui empêche la zone [param def] sur [param cell] (vide : valide).
func check_cell(def: ZoneDef, cell: Vector2i) -> String:
	if not map.has_cell(cell) or not territory.is_territory(cell):
		return "Hors du territoire"
	var b := buildings.building_at(cell)
	if b:
		return "Bâtiment présent (%s)" % b.def.display_name
	if def.deposit != 0 and territory.known_deposit(cell) != def.deposit:
		return "Pas de gisement de %s prospecté" % WorldMap.DEPOSIT_NAMES[def.deposit].to_lower()
	return def.terrain_error(map, cell)


## Aperçu de la peinture de [param def] (null : effacement) sur les tuiles
## de [param rect].
func plan(def: ZoneDef, rect: Rect2i) -> Plan:
	var p := Plan.new()
	p.def = def
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var cell := Vector2i(x, y)
			if not map.has_cell(cell):
				continue
			p.cells.append(cell)
			var current := zone_at(cell)
			if def == null:
				if current:
					p.changed.append(cell)
				continue
			var error := check_cell(def, cell)
			if not error.is_empty():
				p.refused += 1
				if p.error.is_empty():
					p.error = error
			elif current != def:
				p.changed.append(cell)
	return p


## Applique un aperçu (peinture ou effacement) ; renvoie les tuiles changées.
func apply(p: Plan) -> Array[Vector2i]:
	var changed: Array[Vector2i] = []
	for cell in p.changed:
		if p.def == null:
			_zones.erase(map.wrap_cell(cell))
		elif check_cell(p.def, cell).is_empty():
			_zones[map.wrap_cell(cell)] = p.def
		else:
			continue
		changed.append(cell)
	return changed


## Retire la zone de [param cells] (forêt coupée à blanc…) ; renvoie les
## tuiles qui en portaient une.
func clear(cells: Array[Vector2i]) -> Array[Vector2i]:
	var cleared: Array[Vector2i] = []
	for cell in cells:
		if _zones.erase(map.wrap_cell(cell)):
			cleared.append(cell)
	return cleared


## Rectangle (bornes incluses) entre deux tuiles d'un glisser.
static func rect_between(a: Vector2i, b: Vector2i) -> Rect2i:
	var lo := Vector2i(mini(a.x, b.x), mini(a.y, b.y))
	var hi := Vector2i(maxi(a.x, b.x), maxi(a.y, b.y))
	return Rect2i(lo, hi - lo + Vector2i.ONE)
