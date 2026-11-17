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
## le bois varie selon la saison (chauffage) : moitié en été, double en hiver.
const FOOD_PER_DAY := 1.0
const WOOD_PER_DAY := 0.2
const SEASON_WOOD_FACTOR: PackedFloat32Array = [1.0, 0.5, 1.0, 2.0]
## Satisfaction : moyenne sur ce nombre de jours, nourriture pondérée.
const SATISFACTION_DAYS := 10
const FOOD_WEIGHT := 0.7
## Eau (à partir du village, puits) : satisfaction réduite jusqu'à cette part
## quand elle manque tout à fait.
const WATER_WEIGHT := 0.3
## Outils (scies, charrues) : satisfaction réduite jusqu'à cette part sans eux.
const TOOLS_WEIGHT := 0.15
## Vêtements (à partir du bourg) : satisfaction réduite jusqu'à cette part
## sans eux ; un vêtement par habitant tous les CLOTHES_LIFE_DAYS jours.
const CLOTHES_WEIGHT := 0.15
const CLOTHES_LIFE_DAYS := 100.0
## Éclairage (à partir de la ville) : carburant par habitant et par jour ;
## satisfaction réduite jusqu'à cette part sans lui.
const LIGHT_PER_DAY := 0.01
const LIGHT_WEIGHT := 0.1
## Biens variés (à partir de la ville : meubles, vaisselle, ustensiles) : un
## par habitant tous les GOODS_LIFE_DAYS jours ; satisfaction réduite jusqu'à
## cette part sans eux.
const GOODS_WEIGHT := 0.1
const GOODS_LIFE_DAYS := 50.0
## Santé et ordre (à partir de la ville : part des habitants couverts par les
## dispensaires et les postes de garde) : satisfaction réduite jusqu'à ces
## parts sans eux.
const HEALTH_WEIGHT := 0.1
const ORDER_WEIGHT := 0.1
## Éducation, culture et électricité (à partir de la cité-État : écoles et
## universités, théâtres, réseau) : satisfaction réduite jusqu'à ces parts
## sans eux.
const EDUCATION_WEIGHT := 0.1
const CULTURE_WEIGHT := 0.1
const ELECTRICITY_WEIGHT := 0.15
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
## Part active (ACTIVE_SHARE, plus la corvée).
var active_share := ACTIVE_SHARE
## Satisfaction 0–1 (moyenne des derniers jours).
var satisfaction := 1.0
## Couverture des besoins de la veille (0–1).
var food_coverage := 1.0
var wood_coverage := 1.0
var water_coverage := 1.0
var tools_coverage := 1.0
var clothes_coverage := 1.0
var light_coverage := 1.0
var goods_coverage := 1.0
var health_coverage := 1.0
var order_coverage := 1.0
var education_coverage := 1.0
var culture_coverage := 1.0
var electricity_coverage := 1.0
var _history: Array[float] = []
## Fraction d'habitant accumulée (naissances, départs).
var _change := 0.0


## Habitants actifs (arrondi inférieur).
func active() -> int:
	return floori(count * active_share)


## Nourriture nécessaire par jour (unités).
func food_need() -> float:
	return count * FOOD_PER_DAY


## Bois nécessaire par jour pendant la saison [param season] (unités).
func wood_need(season: int) -> float:
	return count * WOOD_PER_DAY * SEASON_WOOD_FACTOR[season]


## Vêtements usés par jour (à partir du bourg).
func clothes_need() -> float:
	return count / CLOTHES_LIFE_DAYS


## Carburant des lampes par jour (à partir de la ville).
func light_need() -> float:
	return count * LIGHT_PER_DAY


## Biens variés usés par jour (à partir de la ville).
func goods_need() -> float:
	return count / GOODS_LIFE_DAYS


## Clôt la journée avec la couverture des besoins (0–1 ; l'eau et les outils
## à partir du village, les vêtements à partir du bourg, l'éclairage, les
## biens, la santé et l'ordre à partir de la ville, l'éducation, la culture et
## l'électricité à partir de la cité-État), les logements et
## l'humeur [param mood] (impôts, décrets : facteur de la satisfaction du
## jour) ; renvoie la variation du nombre d'habitants.
func end_day(p_food_coverage: float, p_wood_coverage: float, housing: int, p_water_coverage := 1.0,
		p_tools_coverage := 1.0, p_clothes_coverage := 1.0, mood := 1.0, p_light_coverage := 1.0,
		p_goods_coverage := 1.0, p_health_coverage := 1.0, p_order_coverage := 1.0,
		p_education_coverage := 1.0, p_culture_coverage := 1.0, p_electricity_coverage := 1.0) -> int:
	food_coverage = clampf(p_food_coverage, 0.0, 1.0)
	wood_coverage = clampf(p_wood_coverage, 0.0, 1.0)
	water_coverage = clampf(p_water_coverage, 0.0, 1.0)
	tools_coverage = clampf(p_tools_coverage, 0.0, 1.0)
	clothes_coverage = clampf(p_clothes_coverage, 0.0, 1.0)
	light_coverage = clampf(p_light_coverage, 0.0, 1.0)
	goods_coverage = clampf(p_goods_coverage, 0.0, 1.0)
	health_coverage = clampf(p_health_coverage, 0.0, 1.0)
	order_coverage = clampf(p_order_coverage, 0.0, 1.0)
	education_coverage = clampf(p_education_coverage, 0.0, 1.0)
	culture_coverage = clampf(p_culture_coverage, 0.0, 1.0)
	electricity_coverage = clampf(p_electricity_coverage, 0.0, 1.0)
	_history.append((FOOD_WEIGHT * food_coverage + (1.0 - FOOD_WEIGHT) * wood_coverage)
		* (1.0 - WATER_WEIGHT * (1.0 - water_coverage)) * (1.0 - TOOLS_WEIGHT * (1.0 - tools_coverage))
		* (1.0 - CLOTHES_WEIGHT * (1.0 - clothes_coverage))
		* (1.0 - LIGHT_WEIGHT * (1.0 - light_coverage)) * (1.0 - GOODS_WEIGHT * (1.0 - goods_coverage))
		* (1.0 - HEALTH_WEIGHT * (1.0 - health_coverage)) * (1.0 - ORDER_WEIGHT * (1.0 - order_coverage))
		* (1.0 - EDUCATION_WEIGHT * (1.0 - education_coverage)) * (1.0 - CULTURE_WEIGHT * (1.0 - culture_coverage))
		* (1.0 - ELECTRICITY_WEIGHT * (1.0 - electricity_coverage)) * mood)
	_history[-1] = clampf(_history[-1], 0.0, 1.0)
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
