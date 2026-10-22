class_name Statistics
extends RefCounted
## Historique journalier de la partie, pour les graphiques. Les heures
## s'accumulent pendant la journée (add), une valeur par série à sa clôture
## (end_day). Pure donnée.

## Séries journalières (une valeur par jour clos). Les séries de la v2
## (population, stocks, puissance…) viendront avec leurs simulations.
const SERIES: Array[StringName] = []

## Nombre de jours clos.
var days := 0
var series: Dictionary[StringName, PackedFloat32Array] = {}
var _hour_sums: Dictionary[StringName, float] = {}


func _init() -> void:
	for key in SERIES:
		series[key] = PackedFloat32Array()


## Ajoute [param amount] à la somme du jour de la série [param key].
func add(key: StringName, amount: float) -> void:
	_hour_sums[key] = _hour_sums.get(key, 0.0) + amount


## Clôt la journée : une valeur (somme du jour) par série.
func end_day() -> void:
	for key: StringName in series:
		_push(key, _hour_sums.get(key, 0.0))
	days += 1
	_hour_sums.clear()


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
