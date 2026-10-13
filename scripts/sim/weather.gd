class_name Weather
extends RefCounted
## Météo et course du soleil : facteurs globaux de vent et de nébulosité,
## lumière du jour selon l'heure et la saison. Fonctions pures du tick et de
## la graine (même graine → même météo), donc prévisibles une heure à
## l'avance par le réseau. Pure donnée.

## Durée du jour (heures) par saison, centrée sur MIDDAY.
const DAY_LENGTH: PackedFloat32Array = [12.0, 15.0, 12.0, 9.0]
const MIDDAY := 13.0
## Vent moyen relatif par saison (hiver venteux, été calme).
const SEASON_WIND: PackedFloat32Array = [1.0, 0.85, 1.05, 1.2]
## Nébulosité ajoutée par saison.
const SEASON_CLOUD: PackedFloat32Array = [0.0, -0.15, 0.05, 0.15]
## Part du rayonnement arrêtée par un ciel entièrement couvert.
const CLOUD_BLOCK := 0.75
## Périodes (heures) des deux échelles de variation : fronts journaliers et
## rafales de quelques heures.
const SLOW_PERIOD := 24
const FAST_PERIOD := 6

var seed_value := 0


func _init(p_seed: int = 0) -> void:
	seed_value = p_seed


## Facteur global de vent (≈ 0,1 – 1,4 ; moyenne ≈ 0,85 au printemps),
## multiplié par le potentiel éolien de la tuile.
func wind_at(tick: int) -> float:
	var n := 0.6 * _smooth(1, SLOW_PERIOD, tick) + 0.4 * _smooth(2, FAST_PERIOD, tick)
	return clampf((0.2 + 1.3 * n) * SEASON_WIND[GameDate.season(tick)], 0.05, 1.4)


## Nébulosité 0 (ciel clair) – 1 (couvert).
func cloud_at(tick: int) -> float:
	var n := 0.7 * _smooth(3, SLOW_PERIOD, tick) + 0.5 * _smooth(4, FAST_PERIOD, tick)
	return clampf(n - 0.25 + SEASON_CLOUD[GameDate.season(tick)], 0.0, 1.0)


## Lumière du jour 0 (nuit) – 1 (midi), selon l'heure et la saison.
static func daylight_at(tick: int) -> float:
	var length := DAY_LENGTH[GameDate.season(tick)]
	var t := (GameDate.hour_of_day(tick) + 0.5 - (MIDDAY - length / 2.0)) / length
	return sin(PI * t) if t > 0.0 and t < 1.0 else 0.0


static func is_night(tick: int) -> bool:
	return daylight_at(tick) <= 0.0


## Rayonnement solaire relatif (lumière du jour atténuée par les nuages),
## multiplié par l'ensoleillement de la tuile.
func sun_at(tick: int) -> float:
	return daylight_at(tick) * (1.0 - CLOUD_BLOCK * cloud_at(tick))


## État du ciel en un mot.
func sky(tick: int) -> String:
	var cloud := cloud_at(tick)
	if cloud < 0.3:
		return "Nuit claire" if is_night(tick) else "Ensoleillé"
	return "Nuageux" if cloud < 0.65 else "Couvert"


## Description courte du ciel et du vent.
func describe(tick: int) -> String:
	var wind := wind_at(tick)
	var breeze := "vent calme"
	if wind >= 1.1:
		breeze = "vent fort"
	elif wind >= 0.6:
		breeze = "vent modéré"
	return "%s, %s" % [sky(tick), breeze]


## Bruit de valeur 0–1 sur le canal [param channel], interpolé en douceur
## entre des valeurs aléatoires tirées toutes les [param period] heures.
func _smooth(channel: int, period: int, tick: int) -> float:
	var k := floori(float(tick) / period)
	var t := float(tick - k * period) / period
	t = t * t * (3.0 - 2.0 * t)
	return lerpf(_value(channel, k), _value(channel, k + 1), t)


func _value(channel: int, k: int) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, channel, k])
	return rng.randf()
