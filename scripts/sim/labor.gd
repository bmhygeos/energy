class_name Labor
extends RefCounted
## Répartition automatique des habitants actifs entre les zones (section 6
## du plan). Chaque type de zone offre des places (tuiles × travailleurs par
## tuile) ; les actifs sont distribués au prorata priorité × places, sans
## dépasser les places, l'excédent allant aux autres zones puis au chômage.
## Un travailleur qui quitte une zone met REASSIGN_HOURS à être de nouveau
## disponible ; dans une zone, les travailleurs vont d'abord aux meilleures
## tuiles (qualité × proximité du village). Pure donnée.

## Priorité « automatique » (réglage par défaut).
const AUTO := -1
const MAX_PRIORITY := 5
## Priorité appliquée en mode automatique ; elle suivra les stocks (V4).
const AUTO_PRIORITY := 3
## Délai pour changer de zone (heures).
const REASSIGN_HOURS := 24
## Pénalité de trajet : −3 % par tuile au-delà de 6 tuiles du village.
const FREE_DISTANCE := 6
const DISTANCE_PENALTY := 0.03

var zones: ZoneMap
var map: WorldMap
## Centre du village (pour la proximité).
var center: Vector2i
## Priorité par type de zone (0–5 ou AUTO).
var priorities: Dictionary[ZoneDef, int] = {}
## Travailleurs affectés par type de zone.
var assigned: Dictionary[ZoneDef, int] = {}
## Travailleurs par tuile zonée (tuile ramenée sur la planète).
var workers_at: Dictionary[Vector2i, int] = {}
## Heures (ticks) où les travailleurs en transit redeviennent disponibles.
var _transit: Array[int] = []
var _active := 0


func _init(p_zones: ZoneMap, p_center: Vector2i) -> void:
	zones = p_zones
	map = zones.map
	center = p_center
	for def in ZoneDb.DEFS:
		priorities[def] = AUTO
		assigned[def] = 0


## Priorité appliquée pour [param def] (AUTO résolu).
func effective_priority(def: ZoneDef) -> int:
	var p := priorities[def]
	return AUTO_PRIORITY if p == AUTO else p


func employed() -> int:
	var total := 0
	for def: ZoneDef in assigned:
		total += assigned[def]
	return total


func in_transit() -> int:
	return _transit.size()


## Actifs disponibles sans emploi (hors transit).
func unemployed() -> int:
	return maxi(0, _active - employed() - in_transit())


## Effectifs visés par type de zone pour [param active] travailleurs, au
## prorata priorité × places, plafonnés par les places (plus grands restes
## pour les arrondis).
func targets(active: int) -> Dictionary[ZoneDef, int]:
	var result: Dictionary[ZoneDef, int] = {}
	var open: Array[ZoneDef] = []
	for def in ZoneDb.DEFS:
		result[def] = 0
		if zones.places(def) > 0 and effective_priority(def) > 0:
			open.append(def)
	var remaining := active
	while remaining > 0 and not open.is_empty():
		var total := 0.0
		for def in open:
			total += effective_priority(def) * zones.places(def)
		var shares: Dictionary[ZoneDef, float] = {}
		var given := 0
		for def in open:
			var share := remaining * effective_priority(def) * zones.places(def) / total
			var n := mini(floori(share), zones.places(def) - result[def])
			result[def] += n
			given += n
			shares[def] = share - floori(share)
		# Plus grands restes : un travailleur de plus aux zones non pleines.
		var by_rest := open.duplicate()
		by_rest.sort_custom(func(a: ZoneDef, b: ZoneDef) -> bool: return shares[a] > shares[b])
		for def in by_rest:
			if given >= remaining:
				break
			if result[def] < zones.places(def) and shares[def] > 0.0:
				result[def] += 1
				given += 1
		remaining -= given
		open = open.filter(func(def: ZoneDef) -> bool: return result[def] < zones.places(def))
		if given == 0:
			# Restes nuls partout : un travailleur à la zone la plus prioritaire.
			open.sort_custom(func(a: ZoneDef, b: ZoneDef) -> bool:
				return effective_priority(a) * zones.places(a) > effective_priority(b) * zones.places(b))
			result[open[0]] += 1
			remaining -= 1
			open = open.filter(func(def: ZoneDef) -> bool: return result[def] < zones.places(def))
	return result


## Met à jour l'affectation à l'heure [param tick] pour [param active]
## actifs : libère les surplus (en transit), pourvoit les manques avec les
## disponibles, puis place les travailleurs sur les tuiles.
func step(tick: int, active: int) -> void:
	_active = active
	_transit = _transit.filter(func(ready: int) -> bool: return ready > tick)
	# Moins d'actifs (départs) : on retire d'abord le transit, puis les affectés.
	while employed() + in_transit() > active:
		if not _transit.is_empty():
			_transit.pop_back()
		else:
			for def: ZoneDef in assigned:
				if assigned[def] > 0:
					assigned[def] -= 1
					break
	var target := targets(active)
	for def in ZoneDb.DEFS:
		if assigned[def] > target[def]:
			for k in assigned[def] - target[def]:
				_transit.append(tick + REASSIGN_HOURS)
			assigned[def] = target[def]
	for def in ZoneDb.DEFS:
		var take := mini(target[def] - assigned[def], unemployed())
		if take > 0:
			assigned[def] += take
	_place_workers()


## Travailleurs sur les meilleures tuiles de chaque zone.
func _place_workers() -> void:
	workers_at.clear()
	for def in ZoneDb.DEFS:
		var left := assigned[def]
		if left <= 0:
			continue
		var cells := zones.cells_of(def)
		var scores: Dictionary[Vector2i, float] = {}
		for cell in cells:
			scores[cell] = tile_score(def, cell)
		cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			return scores[a] > scores[b] or scores[a] == scores[b] and (a.y < b.y or a.y == b.y and a.x < b.x))
		for cell in cells:
			if left <= 0:
				break
			var n := mini(left, def.workers_per_tile)
			workers_at[cell] = n
			left -= n


## Intérêt de [param cell] pour la zone [param def] : qualité × proximité.
func tile_score(def: ZoneDef, cell: Vector2i) -> float:
	return def.quality_at(map, cell) * distance_factor(distance(cell))


## Distance (en tuiles, Tchebychev, longitude bouclée) au centre du village.
func distance(cell: Vector2i) -> int:
	var w := map.size.x
	var dx := absi(posmod(cell.x - center.x + w / 2, w) - w / 2)
	return maxi(dx, absi(cell.y - center.y))


## Rendement restant après le trajet depuis une distance de [param tiles].
static func distance_factor(tiles: int) -> float:
	return clampf(1.0 - DISTANCE_PENALTY * maxi(0, tiles - FREE_DISTANCE), 0.0, 1.0)
