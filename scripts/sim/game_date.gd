class_name GameDate
extends RefCounted
## Calendrier du jeu : 1 tick = 1 heure, 24 h/jour, 30 jours/saison,
## 4 saisons/an. Fonctions pures dérivées du numéro de tick.

const HOURS_PER_DAY := 24
const DAYS_PER_SEASON := 30
const SEASONS_PER_YEAR := 4
const HOURS_PER_SEASON := HOURS_PER_DAY * DAYS_PER_SEASON
const HOURS_PER_YEAR := HOURS_PER_SEASON * SEASONS_PER_YEAR

const SEASON_NAMES: PackedStringArray = ["Printemps", "Été", "Automne", "Hiver"]


static func hour_of_day(tick: int) -> int:
	return tick % HOURS_PER_DAY


## Jour absolu depuis le début de la partie (0-based).
static func day_index(tick: int) -> int:
	return tick / HOURS_PER_DAY


## Jour dans la saison (1–30).
static func day_of_season(tick: int) -> int:
	return (tick % HOURS_PER_SEASON) / HOURS_PER_DAY + 1


## Saison (0 = printemps … 3 = hiver).
static func season(tick: int) -> int:
	return (tick % HOURS_PER_YEAR) / HOURS_PER_SEASON


## Année (1-based).
static func year(tick: int) -> int:
	return tick / HOURS_PER_YEAR + 1


static func format(tick: int) -> String:
	return "%s, jour %d, an %d — %02d:00" % [
		SEASON_NAMES[season(tick)], day_of_season(tick), year(tick), hour_of_day(tick)
	]
