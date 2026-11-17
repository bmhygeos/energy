class_name CityEvents
extends RefCounted
## Événements de la cité (à partir du bourg, section 8 du plan) : hiver rude,
## sécheresse, épizootie, incendie de forêt, arrivée de migrants, épidémie
## (à partir de la ville, d'autant plus meurtrière que la santé manque),
## incident nucléaire (cité-État, avec une centrale : elle s'arrête). Tirés au sort
## chaque jour parmi ceux de la saison, avec un écart minimal entre deux ;
## la graine de la partie les rend reproductibles. Pure donnée.

enum Kind { HARD_WINTER, DROUGHT, EPIZOOTIC, FOREST_FIRE, MIGRANTS, EPIDEMIC, NUCLEAR_INCIDENT }

const NAMES: PackedStringArray = ["Hiver rude", "Sécheresse", "Épizootie", "Incendie de forêt", "Migrants", "Épidémie", "Incident nucléaire"]
const START_TEXTS: PackedStringArray = [
	"Hiver rude : le chauffage demande moitié plus de combustible",
	"Sécheresse : les champs rendent moitié moins",
	"Épizootie : les troupeaux dépérissent, des chevaux meurent",
	"Incendie de forêt",
	"Des migrants arrivent",
	"Épidémie",
	"Incident nucléaire : les centrales nucléaires s'arrêtent pour inspection",
]
## Saisons possibles, en masque de bits (1 << saison ; 0 printemps … 3 hiver) :
## hiver, été, hors hiver, été et automne, hors hiver, automne et hiver, toute
## l'année.
const SEASON_MASKS: PackedInt32Array = [0b1000, 0b0010, 0b0111, 0b0110, 0b0111, 0b1100, 0b1111]
## Durée en jours (0 : effet immédiat).
const DURATIONS: PackedInt32Array = [20, 20, 15, 0, 0, 0, 15]
## Palier à partir duquel l'événement peut survenir (épidémie : la ville ;
## incident nucléaire : la cité-État).
const MIN_TIERS: PackedInt32Array = [0, 0, 0, 0, 0, 4, 5]
## Chance par jour une fois l'écart minimal écoulé.
const CHANCE_PER_DAY := 0.03
const MIN_GAP_DAYS := 60
## Effets.
const HARD_WINTER_HEAT := 1.5
const DROUGHT_FACTOR := 0.5
const EPIZOOTIC_FACTOR := 0.5
const EPIZOOTIC_HORSES_LOST := 0.2
const FIRE_TILES := 12
const MIGRANTS_SHARE := 0.05
## Épidémie : part des habitants emportée sans aucun soin (moins à mesure que
## les dispensaires couvrent la ville).
const EPIDEMIC_DEATHS := 0.08

## Jours restants des événements en cours.
var active: Dictionary[Kind, int] = {}
var rng := RandomNumberGenerator.new()
var _gap := MIN_GAP_DAYS


func _init(p_seed: int = 0) -> void:
	rng.seed = p_seed


func is_active(kind: Kind) -> bool:
	return active.has(kind)


## Facteur du chauffage.
func heat_factor() -> float:
	return HARD_WINTER_HEAT if is_active(Kind.HARD_WINTER) else 1.0


## Facteur de rendement de la zone [param def].
func zone_factor(def: ZoneDef) -> float:
	if def.quality == ZoneDef.Quality.FERTILITY and is_active(Kind.DROUGHT):
		return DROUGHT_FACTOR
	if def.quality == ZoneDef.Quality.PASTURE and is_active(Kind.EPIZOOTIC):
		return EPIZOOTIC_FACTOR
	return 1.0


## Tire l'événement du jour pendant [param season], au palier
## [param tier] (sans palier : ceux qui n'en demandent pas), avec ou sans
## centrale nucléaire [param nuclear] ; renvoie son genre, ou -1.
func roll(season: int, tier := 0, nuclear := false) -> int:
	_gap -= 1
	if _gap > 0 or rng.randf() >= CHANCE_PER_DAY:
		return -1
	var possible: Array[int] = []
	for kind in Kind.size():
		if SEASON_MASKS[kind] & (1 << season) and tier >= MIN_TIERS[kind] \
				and (kind != Kind.NUCLEAR_INCIDENT or nuclear):
			possible.append(kind)
	if possible.is_empty():
		return -1
	var kind := possible[rng.randi_range(0, possible.size() - 1)]
	_gap = MIN_GAP_DAYS
	if DURATIONS[kind] > 0:
		active[kind] = DURATIONS[kind]
	return kind


## Fin de journée : décompte ; renvoie les événements terminés.
func end_day() -> Array[Kind]:
	var ended: Array[Kind] = []
	for kind: Kind in active.keys():
		active[kind] -= 1
		if active[kind] <= 0:
			active.erase(kind)
			ended.append(kind)
	return ended
