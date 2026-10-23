class_name PowerMeter
extends RefCounted
## Compteur de puissance de la cité : énergie des ressources produites
## chaque jour (contenu énergétique, Stockpile.ENERGY_MJ) ramenée à une
## puissance moyenne, en moyenne glissante sur WINDOW_DAYS jours (la
## production agricole est saisonnière). Pure donnée.

const WINDOW_DAYS := 30
const SECONDS_PER_DAY := 86400.0

## Puissance moyenne de chaque jour clos, par marchandise (W).
var _days: Array[PackedFloat32Array] = []


## Enregistre la production d'un jour clos (unités par marchandise).
func push_day(produced: PackedFloat32Array) -> void:
	var watts := PackedFloat32Array()
	for good in produced.size():
		watts.append(produced[good] * Stockpile.ENERGY_MJ[good] * 1e6 / SECONDS_PER_DAY)
	_days.append(watts)
	if _days.size() > WINDOW_DAYS:
		_days.pop_front()


## Puissance moyenne (W) de [param good] sur la fenêtre (toutes si -1).
func average(good: int = -1) -> float:
	if _days.is_empty():
		return 0.0
	var total := 0.0
	for day in _days:
		for g in day.size():
			if good < 0 or g == good:
				total += day[g]
	return total / _days.size()


## Puissance par habitant (W).
func per_capita(population: int) -> float:
	return average() / population if population > 0 else 0.0


## Puissance en texte : 850 W, 12,3 kW, 1,2 MW.
static func format(watts: float) -> String:
	if watts >= 1e6:
		return Format.decimal(watts / 1e6) + " MW"
	if watts >= 1e3:
		return Format.decimal(watts / 1e3) + " kW"
	return "%d W" % roundi(watts)
