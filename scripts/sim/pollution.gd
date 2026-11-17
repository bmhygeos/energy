class_name Pollution
extends RefCounted
## Pollution de l'air de la cité (reprise de la v1, ramenée à la ville
## entière : la planète de la v2 est trop grande pour un niveau par tuile).
## Chaque jour, le combustible brûlé (charbon, carburant, bois de chauffage)
## émet ; la pollution accumulée se dissipe en partie, et son indice (0–1)
## dépend des émissions par habitant : en dessous de TOLERANCE, l'air reste
## pur. Elle rend malade (satisfaction réduite, épidémies plus meurtrières),
## moins là où les dispensaires soignent. Pure donnée.

## Émission par unité brûlée (charbon, carburant, bois).
const COAL_EMISSION := 1.0
const FUEL_EMISSION := 0.8
const WOOD_EMISSION := 0.1
## Part de la pollution qui subsiste d'un jour à l'autre : à émission
## constante, la pollution tend vers 1 / (1 − RETENTION) jours d'émissions.
const RETENTION := 0.9
## Émission journalière par habitant sans effet, et au-delà de laquelle
## (TOLERANCE + RANGE) l'indice est plein.
const TOLERANCE := 0.05
const RANGE := 0.15

## Pollution accumulée (jours d'émissions).
var level := 0.0
## Émissions du dernier jour.
var emitted := 0.0


## Clôt la journée : dissipation, puis émissions du charbon [param coal], du
## carburant [param fuel] et du bois [param wood] brûlés ; renvoie l'émission.
func end_day(coal: float, fuel: float, wood: float) -> float:
	emitted = coal * COAL_EMISSION + fuel * FUEL_EMISSION + wood * WOOD_EMISSION
	level = level * RETENTION + emitted
	return emitted


## Indice de pollution (0 : air pur, 1 : irrespirable) pour [param count]
## habitants.
func index(count: int) -> float:
	if count <= 0:
		return 0.0
	var per_capita := level * (1.0 - RETENTION) / count
	return clampf((per_capita - TOLERANCE) / RANGE, 0.0, 1.0)
