class_name Population
extends RefCounted
## Habitants de la cité : nombre, part active, besoins journaliers,
## satisfaction (couverture des besoins des derniers jours) et évolution :
## croissance si les besoins sont couverts et qu'il reste des logements,
## départs si la satisfaction est basse ou les maisons trop pleines, déclin
## rapide en cas de famine. Pure donnée.

## Habitants au départ (palier 1, hameau).
const START := 20
## Part des habitants qui travaille (le reste : enfants, anciens).
const ACTIVE_SHARE := 0.6
## Nourriture (unités) et bois (unités de 10 kg) par habitant et par jour ;
## le bois double en hiver (chauffage).
const FOOD_PER_DAY := 1.0
const WOOD_PER_DAY := 0.2
const WINTER_WOOD_FACTOR := 2.0
## Satisfaction : moyenne sur ce nombre de jours, nourriture pondérée.
const SATISFACTION_DAYS := 10
const FOOD_WEIGHT := 0.7
## Eau (à partir du village, puits) : satisfaction réduite jusqu'à cette part
## quand elle manque tout à fait.
const WATER_WEIGHT := 0.3
## Outils (scies, charrues) : satisfaction réduite jusqu'à cette part sans eux.
const TOOLS_WEIGHT := 0.15
## Croissance par jour (part de la population) à pleine satisfaction.
const GROWTH_PER_DAY := 0.006
## Sous ce seuil de satisfaction, des habitants partent (jusqu'à
## LEAVE_PER_DAY de la population à satisfaction nulle).
const LEAVE_THRESHOLD := 0.5
const LEAVE_PER_DAY := 0.03
## Famine (moins de la moitié de la nourriture) : jusqu'à cette part de la
## population perdue par jour.
const FAMINE_PER_DAY := 0.06
## Part des habitants sans logement qui part chaque jour.
const HOMELESS_LEAVE_PER_DAY := 0.2

var count := START
## Satisfaction 0–1 (moyenne des derniers jours).
var satisfaction := 1.0
## Couverture des besoins de la veille (0–1).
var food_coverage := 1.0
var wood_coverage := 1.0
var water_coverage := 1.0
var tools_coverage := 1.0
var _history: Array[float] = []
## Fraction d'habitant accumulée (naissances, départs).
var _change := 0.0


## Habitants actifs (arrondi inférieur).
func active() -> int:
	return floori(count * ACTIVE_SHARE)


## Nourriture nécessaire par jour (unités).
func food_need() -> float:
	return count * FOOD_PER_DAY


## Bois nécessaire par jour pendant la saison [param season] (unités).
func wood_need(season: int) -> float:
	return count * WOOD_PER_DAY * (WINTER_WOOD_FACTOR if season == GameDate.WINTER else 1.0)


## Clôt la journée avec la couverture des besoins (0–1 ; l'eau, à partir du
## village) et les logements ; renvoie la variation du nombre d'habitants.
func end_day(p_food_coverage: float, p_wood_coverage: float, housing: int, p_water_coverage := 1.0,
		p_tools_coverage := 1.0) -> int:
	food_coverage = clampf(p_food_coverage, 0.0, 1.0)
	wood_coverage = clampf(p_wood_coverage, 0.0, 1.0)
	water_coverage = clampf(p_water_coverage, 0.0, 1.0)
	tools_coverage = clampf(p_tools_coverage, 0.0, 1.0)
	_history.append((FOOD_WEIGHT * food_coverage + (1.0 - FOOD_WEIGHT) * wood_coverage)
		* (1.0 - WATER_WEIGHT * (1.0 - water_coverage)) * (1.0 - TOOLS_WEIGHT * (1.0 - tools_coverage)))
	if _history.size() > SATISFACTION_DAYS:
		_history.pop_front()
	var total := 0.0
	for v in _history:
		total += v
	satisfaction = total / _history.size()
	var change := 0.0
	if food_coverage >= 1.0 and wood_coverage >= 1.0 and water_coverage >= 1.0 and count < housing:
		change += count * GROWTH_PER_DAY * satisfaction
	if satisfaction < LEAVE_THRESHOLD:
		change -= count * LEAVE_PER_DAY * (1.0 - satisfaction / LEAVE_THRESHOLD)
	if food_coverage < 0.5:
		change -= count * FAMINE_PER_DAY * (1.0 - 2.0 * food_coverage)
	if count > housing:
		change -= (count - housing) * HOMELESS_LEAVE_PER_DAY
	_change += change
	var whole := int(_change)
	if count + whole > housing and whole > 0:
		whole = maxi(0, housing - count)
	whole = maxi(whole, -count)
	# Bornée : une croissance bloquée par les logements ne s'accumule pas.
	_change = clampf(_change - whole, -1.0, 1.0)
	count += whole
	return whole
