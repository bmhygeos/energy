class_name City
extends RefCounted
## Ville : demande électrique variant selon l'heure et la saison, croissance
## annuelle (plus rapide si elle est bien alimentée, freinée par la
## pollution), satisfaction des habitants. Pure donnée.

enum Supply { NOT_CONNECTED, NO_SUPPLY, SERVED, SHED }

const SUPPLY_NAMES: PackedStringArray = [
	"Non raccordée", "Raccordée, sans centrale", "Alimentée", "Délestée (coupure)",
]
## Profil horaire de la demande (moyenne ≈ 0,9 ; pic en soirée).
const HOURLY: PackedFloat32Array = [
	0.6, 0.55, 0.5, 0.5, 0.55, 0.65, 0.8, 0.95, 1.0, 1.0, 1.0, 1.0,
	1.0, 1.0, 0.95, 0.95, 1.0, 1.1, 1.25, 1.3, 1.2, 1.0, 0.85, 0.7,
]
## Facteur saisonnier (printemps, été, automne, hiver).
const SEASONAL: PackedFloat32Array = [1.0, 0.9, 1.0, 1.25]
## Croissance annuelle de la demande de base selon l'alimentation.
const GROWTH_SERVED := 0.25
const GROWTH_UNSERVED := 0.02
## Croissance annuelle retirée par un air irrespirable (qualité nulle).
const POLLUTION_SHRINK := 0.08
## Poids de la fiabilité de l'alimentation dans la satisfaction (le reste :
## qualité de l'air), et part de l'écart rattrapée chaque jour.
const SATISFACTION_SUPPLY_WEIGHT := 0.7
const SATISFACTION_RATE := 0.25
## Habitants par MW de demande de base.
const PEOPLE_PER_MW := 1000

var name := ""
## Demande de base (MW), multipliée par les profils horaire et saisonnier.
var base_demand := 10.0
var supply: Supply = Supply.NOT_CONNECTED
## Heures alimentées et heures de coupure du jour en cours, et taux
## d'alimentation de la veille.
var served_hours_today := 0
var shed_hours_today := 0
var served_ratio_yesterday := 0.0
## Qualité de l'air (0–1) et satisfaction des habitants (0–1), mises à jour
## chaque jour.
var air_quality := 1.0
var satisfaction := 0.5


func _init(p_name: String = "", p_base_demand: float = 10.0) -> void:
	name = p_name
	base_demand = p_base_demand


func population() -> int:
	return roundi(base_demand * PEOPLE_PER_MW)


static func demand_factor(tick: int) -> float:
	return HOURLY[GameDate.hour_of_day(tick)] * SEASONAL[GameDate.season(tick)]


## Demande (MW) pendant l'heure [param tick].
func demand_at(tick: int) -> float:
	return base_demand * demand_factor(tick)


## Pic de demande de la saison de [param tick] (MW).
func peak_demand(tick: int) -> float:
	return base_demand * 1.3 * SEASONAL[GameDate.season(tick)]


## Fin de journée : croissance selon la part d'heures alimentées et la
## qualité de l'air [param p_air_quality] (0–1) ; la satisfaction se
## rapproche de sa cible.
func end_day(p_air_quality: float = 1.0) -> void:
	served_ratio_yesterday = served_hours_today / float(GameDate.HOURS_PER_DAY)
	air_quality = p_air_quality
	var target := SATISFACTION_SUPPLY_WEIGHT * served_ratio_yesterday + (1.0 - SATISFACTION_SUPPLY_WEIGHT) * air_quality
	satisfaction = lerpf(satisfaction, target, SATISFACTION_RATE)
	var growth := lerpf(GROWTH_UNSERVED, GROWTH_SERVED, served_ratio_yesterday) - POLLUTION_SHRINK * (1.0 - air_quality)
	base_demand *= 1.0 + growth / (GameDate.DAYS_PER_SEASON * GameDate.SEASONS_PER_YEAR)
	served_hours_today = 0
	shed_hours_today = 0
