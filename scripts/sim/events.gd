class_name Events
extends RefCounted
## Événements aléatoires : tempêtes (éoliennes mises en sécurité, parfois
## endommagées), sécheresses d'été (centrales refroidies par l'eau bridées),
## crises de l'énergie (prix du marché en hausse), grèves des mineurs de
## charbon, incidents nucléaires ; alertes d'épuisement des gisements.
## Tirages reproductibles (flux dédié). Pure donnée.

enum Kind { STORM, DROUGHT, ENERGY_CRISIS, MINERS_STRIKE }

const KIND_NAMES: PackedStringArray = ["Tempête", "Sécheresse", "Crise de l'énergie", "Grève des mineurs"]
## Intervalle moyen (heures) entre deux déclenchements, par saison
## (printemps, été, automne, hiver ; 0 : jamais) : environ une tempête tous
## les dix jours en automne et en hiver, une sécheresse par été, une crise
## tous les deux ans, une grève par an.
const STORM_INTERVAL: PackedInt32Array = [720, 1440, 240, 240]
const DROUGHT_INTERVAL: PackedInt32Array = [0, 720, 0, 0]
const CRISIS_INTERVAL := 5760
const STRIKE_INTERVAL := 2880
## Durée (heures) min et max, indexée par Kind.
const DURATION: Array[Vector2i] = [
	Vector2i(12, 36),
	Vector2i(5 * 24, 12 * 24),
	Vector2i(10 * 24, 20 * 24),
	Vector2i(3 * 24, 6 * 24),
]
## Sécheresse : part de la puissance permise aux centrales refroidies par l'eau.
const DROUGHT_COOLING := 0.5
## Crise de l'énergie : multiplicateur du prix du marché.
const CRISIS_PRICE := 1.5
## Tempête : chance qu'une éolienne soit endommagée, durée de réparation
## (heures) et coût (part du prix de construction).
const STORM_DAMAGE_CHANCE := 0.1
const STORM_REPAIR_HOURS := Vector2i(48, 96)
const STORM_REPAIR_COST := 0.05
## Incident nucléaire : arrêt (heures), coût (part du prix de construction),
## rayon (tuiles) et perte de satisfaction des villes voisines.
const INCIDENT_HOURS := 10 * 24
const INCIDENT_COST := 0.1
const INCIDENT_RADIUS := 20
const INCIDENT_SATISFACTION := 0.25
## Alerte quand un gisement n'a plus que ce nombre de jours d'extraction.
const DEPOSIT_WARNING_DAYS := 30.0


## Événement en cours.
class Active:
	var kind: Kind
	var start := 0
	var end := 0


## Effets d'une heure d'événements.
class Report:
	var messages: Array[String] = []
	## Réparations à payer (€).
	var repair_cost := 0.0
	var status_changed: Array[Building] = []


var rng: RandomNumberGenerator
var weather: Weather
var active: Array[Active] = []


func _init(p_rng: RandomNumberGenerator = RandomNumberGenerator.new(), p_weather: Weather = Weather.new()) -> void:
	rng = p_rng
	weather = p_weather


func is_active(kind: Kind) -> bool:
	return active.any(func(e: Active) -> bool: return e.kind == kind)


## Part de la puissance permise aux centrales refroidies par l'eau.
func cooling_factor() -> float:
	return DROUGHT_COOLING if is_active(Kind.DROUGHT) else 1.0


## Multiplicateur du prix du marché.
func price_factor() -> float:
	return CRISIS_PRICE if is_active(Kind.ENERGY_CRISIS) else 1.0


## Événements en cours, avec les heures restantes, pour l'affichage.
func describe(tick: int) -> PackedStringArray:
	var lines := PackedStringArray()
	for e in active:
		lines.append("%s (encore %s)" % [KIND_NAMES[e.kind], Format.duration_hours(e.end - tick)])
	return lines


## Heure [param tick] : fin des événements échus, nouveaux tirages,
## incidents nucléaires.
func step(tick: int, registry: BuildingRegistry, extraction_factor: float = 1.0) -> Report:
	var report := Report.new()
	for e in active.duplicate():
		if tick >= e.end:
			active.erase(e)
			report.messages.append("Fin : " + KIND_NAMES[e.kind].to_lower())
	var season := GameDate.season(tick)
	for kind: Kind in Kind.values():
		if not is_active(kind) and rng.randf() < chance(kind, season):
			if kind == Kind.MINERS_STRIKE and _coal_mines(registry).is_empty():
				continue
			start(kind, tick, rng.randi_range(DURATION[kind].x, DURATION[kind].y), registry, report)
	for b in registry.all():
		if b.def.incident_per_year > 0.0 and b.status == Building.Status.RUNNING \
				and rng.randf() < b.def.incident_per_year / GameDate.HOURS_PER_YEAR:
			nuclear_incident(b, tick, registry, report)
	if GameDate.hour_of_day(tick) == 0:
		_check_deposits(registry, extraction_factor, report)
	return report


## Probabilité horaire de déclenchement de [param kind] pendant [param season].
static func chance(kind: Kind, season: int) -> float:
	var interval := 0
	match kind:
		Kind.STORM:
			interval = STORM_INTERVAL[season]
		Kind.DROUGHT:
			interval = DROUGHT_INTERVAL[season]
		Kind.ENERGY_CRISIS:
			interval = CRISIS_INTERVAL
		Kind.MINERS_STRIKE:
			interval = STRIKE_INTERVAL
	return 1.0 / interval if interval > 0 else 0.0


## Déclenche [param kind] pour [param duration] heures dès [param tick].
func start(kind: Kind, tick: int, duration: int, registry: BuildingRegistry, report: Report) -> void:
	var e := Active.new()
	e.kind = kind
	e.start = tick
	e.end = tick + duration
	active.append(e)
	var text := "%s pour %s" % [KIND_NAMES[kind], Format.duration_hours(duration)]
	match kind:
		Kind.STORM:
			weather.storm_until = e.end
			var damaged := 0
			for b in registry.all():
				if b.def.power_source == BuildingDef.PowerSource.WIND and b.is_complete() \
						and not b.is_out(tick) and rng.randf() < STORM_DAMAGE_CHANCE:
					_put_out(b, tick + rng.randi_range(STORM_REPAIR_HOURS.x, STORM_REPAIR_HOURS.y),
						Building.Status.REPAIR, report)
					report.repair_cost += b.def.cost * STORM_REPAIR_COST
					damaged += 1
			text += " : éoliennes mises en sécurité"
			if damaged > 0:
				text += ", %d endommagée(s)" % damaged
		Kind.DROUGHT:
			text += " : centrales refroidies par l'eau limitées à %d %%" % roundi(DROUGHT_COOLING * 100.0)
		Kind.ENERGY_CRISIS:
			text += " : prix du marché ×%s" % Format.decimal(CRISIS_PRICE)
		Kind.MINERS_STRIKE:
			for b in _coal_mines(registry):
				_put_out(b, maxi(b.outage_until, e.end), Building.Status.STRIKE, report)
			text += " : mines de charbon à l'arrêt"
	report.messages.append(text)


## Incident sur [param b] : arrêt, réparation, inquiétude des villes voisines.
func nuclear_incident(b: Building, tick: int, registry: BuildingRegistry, report: Report) -> void:
	_put_out(b, tick + INCIDENT_HOURS, Building.Status.REPAIR, report)
	report.repair_cost += b.def.cost * INCIDENT_COST
	for c in registry.all():
		if c.city and Production.footprint_distance(b, c) <= INCIDENT_RADIUS:
			c.city.satisfaction = maxf(0.0, c.city.satisfaction - INCIDENT_SATISFACTION)
	report.messages.append("Incident nucléaire en (%d, %d) : réacteur arrêté %s, réparations %s €" % [
		b.anchor.x, b.anchor.y, Format.duration_hours(INCIDENT_HOURS), Format.thousands(roundi(b.def.cost * INCIDENT_COST))])


func _put_out(b: Building, until: int, status: Building.Status, report: Report) -> void:
	b.outage_until = until
	b.outage_status = status
	b.power_setpoint = 0.0
	report.status_changed.append(b)


static func _coal_mines(registry: BuildingRegistry) -> Array[Building]:
	return registry.all().filter(func(b: Building) -> bool:
		return b.is_complete() and b.def.required_deposit == WorldMap.Deposit.COAL)


## Alerte une fois par mine quand son gisement touche à sa fin.
func _check_deposits(registry: BuildingRegistry, extraction_factor: float, report: Report) -> void:
	for b in registry.all():
		if b.deposit_warned or b.def.extraction != BuildingDef.Extraction.DEPOSIT or not b.is_complete():
			continue
		var per_day := b.def.output_per_hour * extraction_factor * GameDate.HOURS_PER_DAY
		var left := Production.resource_available(registry.map, b.def, b.anchor)
		if per_day > 0.0 and left < per_day * DEPOSIT_WARNING_DAYS:
			b.deposit_warned = true
			report.messages.append("%s (%d, %d) : gisement bientôt épuisé (≈ %d j)" % [
				b.def.display_name, b.anchor.x, b.anchor.y, floori(left / per_day)])
