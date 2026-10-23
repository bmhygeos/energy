class_name Exploration
extends RefCounted
## Expéditions (section 3 du plan) : des habitants actifs partent du centre
## du village vers une tuile cible avec des vivres, avancent selon le terrain
## (rivières à gué, lacs et mer infranchissables au début), révèlent les
## tuiles dans leur rayon de vue puis reviennent : objectif atteint, eau
## devant eux, ou plus que de quoi manger sur le chemin du retour. Pure donnée ; les tuiles sont dans le
## repère de la vue (abscisses dépliées autour du village).

## Par palier de la ville (hameau, village…) : expéditions simultanées et
## jours de vivres emportés au plus ; explorateurs par expédition.
const MAX_EXPEDITIONS: PackedInt32Array = [1, 3, 3, 3, 3]
const MAX_DAYS: PackedInt32Array = [20, 40, 40, 40, 40]
const MAX_MEMBERS := 5
## Rayon de vue (tuiles) autour de l'expédition.
const SIGHT_RADIUS := 3
## Vivres consommés par explorateur et par jour.
const FOOD_PER_MEMBER_PER_DAY := Population.FOOD_PER_DAY
## Tuiles parcourues par jour selon le terrain (0 : infranchissable).
const TILES_PER_DAY: Dictionary[TerrainDef.Type, float] = {
	TerrainDef.Type.PLAIN: 4.0,
	TerrainDef.Type.PRAIRIE: 4.0,
	TerrainDef.Type.DESERT: 3.0,
	TerrainDef.Type.TUNDRA: 3.0,
	TerrainDef.Type.FOREST: 2.0,
	TerrainDef.Type.HILL: 2.0,
	TerrainDef.Type.MOUNTAIN: 1.0,
	TerrainDef.Type.ICE: 1.5,
	# Rivière passée à gué ; lacs et mer restent infranchissables.
	TerrainDef.Type.RIVER: 1.0,
}

enum Reason { NONE, TARGET, WATER, FOOD }
const REASON_TEXTS: PackedStringArray = ["", "objectif atteint", "eau infranchissable", "vivres juste suffisants pour le retour"]


class Expedition:
	var members := 0
	## Chevaux de bât (rendus à l'écurie au retour).
	var horses := 0
	## Vivres restants.
	var food := 0.0
	## Trajet aller, du centre du village (indice 0) vers la cible.
	var path: Array[Vector2i] = []
	## Cible demandée (le trajet peut s'arrêter avant, devant l'eau).
	var target := Vector2i.ZERO
	## Position le long du trajet (indice fractionnaire).
	var position := 0.0
	var returning := false
	## Motif du demi-tour.
	var reason := Reason.NONE
	## Tuiles révélées par l'expédition.
	var revealed := 0

	func cell() -> Vector2i:
		return path[clampi(floori(position), 0, path.size() - 1)]

	## Le trajet s'arrête avant la cible (eau infranchissable).
	func is_blocked() -> bool:
		return path[-1] != target


class Report:
	## Tuiles devenues explorées pendant l'heure.
	var revealed: Array[Vector2i] = []
	## Expéditions qui ont fait demi-tour, et celles revenues au village.
	var turned: Array[Expedition] = []
	var returned: Array[Expedition] = []


var map: WorldMap
var territory: Territory
var expeditions: Array[Expedition] = []
## Palier de la ville (limites des expéditions).
var tier := 1


func _init(p_territory: Territory) -> void:
	territory = p_territory
	map = territory.map


## Vitesse (tuiles par jour) sur [param cell] ; 0 si infranchissable.
func speed_at(cell: Vector2i) -> float:
	return TILES_PER_DAY.get(map.get_terrain(cell) as TerrainDef.Type, 0.0)


func members_out() -> int:
	var total := 0
	for e in expeditions:
		total += e.members
	return total


func can_launch() -> bool:
	return expeditions.size() < max_expeditions()


func max_expeditions() -> int:
	return MAX_EXPEDITIONS[tier - 1]


func max_days() -> int:
	return MAX_DAYS[tier - 1]


## Trajet en ligne droite (8-connexité) de [param from] vers [param to],
## arrêté avant la première tuile infranchissable ou hors de la carte.
func plan_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = [from]
	var d := to - from
	var steps := maxi(absi(d.x), absi(d.y))
	for k in range(1, steps + 1):
		var t := float(k) / steps
		var cell := Vector2i(roundi(from.x + d.x * t), roundi(from.y + d.y * t))
		if not map.has_cell(cell) or speed_at(cell) <= 0.0:
			break
		path.append(cell)
	return path


## Jours de marche de l'indice [param index] du trajet jusqu'au village.
func days_back(e: Expedition, index: int) -> float:
	var days := 0.0
	for k in range(1, mini(index, e.path.size() - 1) + 1):
		days += 1.0 / speed_at(e.path[k])
	return days


## Vivres pour revenir au village depuis la position actuelle.
func food_to_return(e: Expedition) -> float:
	return days_back(e, ceili(e.position)) * e.members * FOOD_PER_MEMBER_PER_DAY


## Durée prévue (jours) de l'aller-retour vers [param target] par le trajet
## qui part de [param from].
func round_trip_days(from: Vector2i, target: Vector2i) -> float:
	var e := Expedition.new()
	e.path = plan_path(from, target)
	return 2.0 * days_back(e, e.path.size() - 1)


## Lance une expédition de [param members] explorateurs avec [param food]
## vivres de [param from] vers [param target] ; null si le trajet est vide.
func launch(from: Vector2i, target: Vector2i, members: int, food: float) -> Expedition:
	var path := plan_path(from, target)
	if path.size() < 2 or members <= 0 or not can_launch():
		return null
	var e := Expedition.new()
	e.members = members
	e.food = food
	e.path = path
	e.target = target
	expeditions.append(e)
	_reveal(e, Report.new())
	return e


## Une heure de marche pour chaque expédition.
func step_hour() -> Report:
	var report := Report.new()
	for e in expeditions.duplicate():
		e.food = maxf(0.0, e.food - e.members * FOOD_PER_MEMBER_PER_DAY / GameDate.HOURS_PER_DAY)
		var step := speed_at(e.cell()) / GameDate.HOURS_PER_DAY
		if e.returning:
			e.position = maxf(0.0, e.position - step)
		else:
			e.position = minf(e.path.size() - 1, e.position + step)
		_reveal(e, report)
		if not e.returning:
			var reason := Reason.NONE
			if e.position >= e.path.size() - 1:
				reason = Reason.WATER if e.is_blocked() else Reason.TARGET
			elif e.food <= food_to_return(e):
				reason = Reason.FOOD
			if reason != Reason.NONE:
				e.returning = true
				e.reason = reason
				report.turned.append(e)
		elif e.position <= 0.0:
			expeditions.erase(e)
			report.returned.append(e)
	return report


## Rend explorées les tuiles en vue de [param e].
func _reveal(e: Expedition, report: Report) -> void:
	var center := e.cell()
	var r := SIGHT_RADIUS
	var fresh: Array[Vector2i] = []
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var cell := center + Vector2i(dx, dy)
			if dx * dx + dy * dy <= r * r + r and map.has_cell(cell) and not territory.is_known(cell):
				fresh.append(cell)
	territory.explore(fresh)
	e.revealed += fresh.size()
	report.revealed.append_array(fresh)
