class_name Economy
extends RefCounted
## Économie de l'électricité : prix de marché horaire (pointe du soir,
## hiver, fluctuations), taxe carbone et subventions aux renouvelables qui
## évoluent d'année en année, tarif selon la satisfaction des villes, et
## comptes du jour. Fonctions pures du tick et de la graine. Pure donnée.

## Prix de marché moyen (€/MWh livré).
const BASE_PRICE := 10.0
## Part du prix qui suit le profil horaire de la demande.
const HOURLY_WEIGHT := 0.5
## Amplitude des fluctuations du marché (± part du prix), sur deux jours.
const PRICE_NOISE := 0.15
const NOISE_PERIOD := 48
## Taxe carbone (€/t de CO₂) : nulle la première année, puis croissante.
const CARBON_TAX_START_YEAR := 2
const CARBON_TAX_STEP := 1.0
const CARBON_TAX_MAX := 5.0
## Subvention aux renouvelables (€/MWh vendu), décroissante chaque année.
const SUBSIDY_START := 3.0
const SUBSIDY_STEP := 0.5
const SUBSIDY_MIN := 1.0
## Tarif accepté par une ville, de très mécontente à comblée.
const TARIFF_MIN := 0.8
const TARIFF_MAX := 1.2
const NOISE_CHANNEL := 10


## Comptes d'une journée (€, montants positifs).
class Accounts:
	var sales := 0.0
	var subsidies := 0.0
	var penalties := 0.0
	var carbon_tax := 0.0
	var transport := 0.0
	var upkeep := 0.0

	func net() -> float:
		return sales + subsidies - penalties - carbon_tax - transport - upkeep


var seed_value := 0
var today := Accounts.new()
var yesterday := Accounts.new()


func _init(p_seed: int = 0) -> void:
	seed_value = p_seed


## Prix de marché (€/MWh) pendant l'heure [param tick].
func price_at(tick: int) -> float:
	var hourly := City.HOURLY[GameDate.hour_of_day(tick)] / _mean(City.HOURLY)
	var seasonal := City.SEASONAL[GameDate.season(tick)] / _mean(City.SEASONAL)
	var noise := 1.0 + PRICE_NOISE * (2.0 * Weather.noise(seed_value, NOISE_CHANNEL, NOISE_PERIOD, tick) - 1.0)
	return BASE_PRICE * (1.0 - HOURLY_WEIGHT + HOURLY_WEIGHT * hourly) * seasonal * noise


## Taxe carbone (€/t de CO₂) de l'année de [param tick].
static func carbon_tax_at(tick: int) -> float:
	var years := GameDate.year(tick) - CARBON_TAX_START_YEAR + 1
	return clampf(CARBON_TAX_STEP * years, 0.0, CARBON_TAX_MAX)


## Subvention (€/MWh renouvelable vendu) de l'année de [param tick].
static func subsidy_at(tick: int) -> float:
	return maxf(SUBSIDY_MIN, SUBSIDY_START - SUBSIDY_STEP * (GameDate.year(tick) - 1))


## Multiplicateur de prix accepté par une ville de satisfaction
## [param satisfaction] (0–1) : ×1 à 50 %.
static func tariff(satisfaction: float) -> float:
	return lerpf(TARIFF_MIN, TARIFF_MAX, clampf(satisfaction, 0.0, 1.0))


## Inscrit l'heure [param tick] aux comptes du jour (ventes et pénalités du
## réseau [param report], taxe sur [param emissions] t de CO₂, frais de
## transport) ; renvoie le solde de l'heure.
func settle_hour(tick: int, report: PowerGrid.Report, emissions: float, travel_cost: float) -> float:
	var subsidy := report.renewable_sold_mw * subsidy_at(tick)
	var tax := emissions * carbon_tax_at(tick)
	today.sales += report.revenue
	today.subsidies += subsidy
	today.penalties += report.penalty
	today.carbon_tax += tax
	today.transport += travel_cost
	return report.revenue + subsidy - report.penalty - tax - travel_cost


## Clôt la journée : l'entretien [param upkeep] payé, les comptes passent à
## la veille.
func end_day(upkeep: float) -> void:
	today.upkeep += upkeep
	yesterday = today
	today = Accounts.new()


static func _mean(values: PackedFloat32Array) -> float:
	var total := 0.0
	for v in values:
		total += v
	return total / values.size()
