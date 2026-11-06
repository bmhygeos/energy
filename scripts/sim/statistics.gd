class_name Statistics
extends RefCounted
## Historique journalier de la partie, pour les graphiques. Les heures
## s'accumulent pendant la journée (add), une valeur par série à sa clôture
## (end_day). Pure donnée.

## Séries journalières (une valeur par jour clos) : population, emploi et
## stocks en moyenne sur la journée ; production, pertes, satisfaction (%),
## puissance (W, moyenne glissante), territoire (tuiles), chevaux, eau (% des
## habitants servis), points de recherche du jour, trésor (pièces en fin de
## journée), impôts et solde du commerce du jour.
const SERIES: Array[StringName] = [
	&"population", &"active", &"employed", &"unemployed",
	&"food_stock", &"wood_stock", &"stone_stock", &"iron_stock", &"tools_stock", &"coal_stock", &"oil_stock",
	&"fiber_stock", &"clothes_stock", &"fuel_stock", &"copper_stock",
	&"food_produced", &"wood_produced", &"stone_produced", &"iron_produced", &"tools_produced",
	&"coal_produced", &"oil_produced", &"fiber_produced", &"clothes_produced", &"fuel_produced", &"copper_produced",
	&"food_lost", &"wood_lost", &"satisfaction", &"power", &"power_per_capita",
	&"territory", &"horses", &"water", &"research", &"coal_burned", &"clothes",
	&"money", &"taxes", &"trade", &"light", &"electricity",
]
## Séries dont la valeur du jour est la moyenne horaire (sinon : la somme).
const AVERAGED: Array[StringName] = [
	&"population", &"active", &"employed", &"unemployed",
	&"food_stock", &"wood_stock", &"stone_stock", &"iron_stock", &"tools_stock", &"coal_stock", &"oil_stock",
	&"fiber_stock", &"clothes_stock", &"fuel_stock", &"copper_stock",
]
## Marchandise (Stockpile.Good) → séries de stock et de production.
const STOCK_KEYS: Array[StringName] = [
	&"food_stock", &"wood_stock", &"stone_stock", &"iron_stock", &"tools_stock", &"coal_stock", &"oil_stock",
	&"fiber_stock", &"clothes_stock", &"fuel_stock", &"copper_stock",
]
const PRODUCED_KEYS: Array[StringName] = [
	&"food_produced", &"wood_produced", &"stone_produced", &"iron_produced", &"tools_produced",
	&"coal_produced", &"oil_produced", &"fiber_produced", &"clothes_produced", &"fuel_produced", &"copper_produced",
]

## Nombre de jours clos.
var days := 0
var series: Dictionary[StringName, PackedFloat32Array] = {}
var _hour_sums: Dictionary[StringName, float] = {}
var _hours := 0


func _init() -> void:
	for key in SERIES:
		series[key] = PackedFloat32Array()


## Ajoute [param amount] à la somme du jour de la série [param key].
func add(key: StringName, amount: float) -> void:
	_hour_sums[key] = _hour_sums.get(key, 0.0) + amount


## Clôt l'heure (diviseur des séries moyennées).
func end_hour() -> void:
	_hours += 1


## Clôt la journée : une valeur par série (somme du jour, ou moyenne horaire).
func end_day() -> void:
	for key: StringName in series:
		var total: float = _hour_sums.get(key, 0.0)
		_push(key, total / maxi(1, _hours) if key in AVERAGED else total)
	days += 1
	_hour_sums.clear()
	_hours = 0


func values(key: StringName) -> PackedFloat32Array:
	return series[key]


## Somme de toutes les valeurs closes de [param key].
func total(key: StringName) -> float:
	var sum := 0.0
	for v in series[key]:
		sum += v
	return sum


## Dernière valeur close de [param key] (0 avant le premier jour).
func last(key: StringName) -> float:
	var v := series[key]
	return v[v.size() - 1] if not v.is_empty() else 0.0


func _push(key: StringName, value: float) -> void:
	# Les tableaux compacts sont copiés à l'accès : réaffecter après l'ajout.
	var v := series[key]
	v.append(value)
	series[key] = v
