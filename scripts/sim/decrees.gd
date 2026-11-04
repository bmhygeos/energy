class_name Decrees
extends RefCounted
## Décrets du gouverneur (à partir du bourg) : rationnement (moins de
## nourriture, moins de satisfaction), corvée (plus d'actifs, moins de
## satisfaction) et fête (nourriture et pièces contre un regain de
## satisfaction quelques jours). Pure donnée.

## Rationnement : nourriture par habitant ×RATION_FOOD ; satisfaction ×RATION_MOOD.
const RATION_FOOD := 0.75
const RATION_MOOD := 0.9
## Corvée : part active +CORVEE_ACTIVE ; satisfaction ×CORVEE_MOOD.
const CORVEE_ACTIVE := 0.1
const CORVEE_MOOD := 0.9
## Fête : nourriture et pièces par habitant ; satisfaction ×FEAST_MOOD pendant
## FEAST_DAYS jours, une fois tous les FEAST_COOLDOWN_DAYS jours.
const FEAST_FOOD_PER_INHABITANT := 1.0
const FEAST_MONEY_PER_INHABITANT := 0.5
const FEAST_MOOD := 1.2
const FEAST_DAYS := 10
const FEAST_COOLDOWN_DAYS := 30

var rationing := false
var corvee := false
## Jours de fête restants, et jours avant la prochaine fête possible.
var feast_days_left := 0
var feast_cooldown := 0


## Facteur de la nourriture par habitant.
func food_factor() -> float:
	return RATION_FOOD if rationing else 1.0


## Supplément de part active.
func active_bonus() -> float:
	return CORVEE_ACTIVE if corvee else 0.0


## Facteur de satisfaction des décrets en vigueur.
func mood() -> float:
	var m := 1.0
	if rationing:
		m *= RATION_MOOD
	if corvee:
		m *= CORVEE_MOOD
	if feast_days_left > 0:
		m *= FEAST_MOOD
	return m


## Nourriture et pièces d'une fête pour [param count] habitants.
static func feast_food(count: int) -> float:
	return count * FEAST_FOOD_PER_INHABITANT


static func feast_money(count: int) -> float:
	return count * FEAST_MONEY_PER_INHABITANT


func can_feast() -> bool:
	return feast_cooldown <= 0


## Ouvre la fête (coûts déjà payés).
func start_feast() -> void:
	feast_days_left = FEAST_DAYS
	feast_cooldown = FEAST_COOLDOWN_DAYS


## Fin de journée : décompte de la fête.
func end_day() -> void:
	feast_days_left = maxi(0, feast_days_left - 1)
	feast_cooldown = maxi(0, feast_cooldown - 1)
