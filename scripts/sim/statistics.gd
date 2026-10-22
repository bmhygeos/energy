class_name Statistics
extends RefCounted
## Historique journalier de la partie, pour les graphiques. Les heures
## s'accumulent pendant la journée (add), une valeur par série à sa clôture
## (end_day). Pure donnée.

## Séries journalières (une valeur par jour clos) : population et emploi en
## moyenne sur la journée. Stocks et puissance viendront avec la production.
const SERIES: Array[StringName] = [&"population", &"active", &"employed", &"unemployed"]
## Séries dont la valeur du jour est la moyenne horaire (sinon : la somme).
const AVERAGED: Array[StringName] = [&"population", &"active", &"employed", &"unemployed"]

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


## Dernière valeur close de [param key] (0 avant le premier jour).
func last(key: StringName) -> float:
	var v := series[key]
	return v[v.size() - 1] if not v.is_empty() else 0.0


func _push(key: StringName, value: float) -> void:
	# Les tableaux compacts sont copiés à l'accès : réaffecter après l'ajout.
	var v := series[key]
	v.append(value)
	series[key] = v
