class_name Statistics
extends RefCounted
## Historique journalier de la partie, pour les graphiques : énergie par
## source, demande, finances, émissions, villes, recherche. Les heures
## s'accumulent pendant la journée, une valeur par série à sa clôture.
## Pure donnée.

## Séries journalières (une valeur par jour clos).
const SERIES: Array[StringName] = [
	&"produced", &"demand", &"delivered", &"shed_hours", &"renewable_share",
	&"emissions", &"money", &"sales", &"subsidies", &"costs", &"net",
	&"satisfaction", &"population", &"research", &"price",
]

## Nombre de jours clos.
var days := 0
var series: Dictionary[StringName, PackedFloat32Array] = {}
## Énergie produite par type de bâtiment (id → MWh/j), même longueur que
## les séries (zéros avant la première centrale du type).
var mix: Dictionary[StringName, PackedFloat32Array] = {}
var _hour_sums: Dictionary[StringName, float] = {}
var _mix_sums: Dictionary[StringName, float] = {}
var _hours := 0


func _init() -> void:
	for key in SERIES:
		series[key] = PackedFloat32Array()


## Ajoute l'heure écoulée : production des bâtiments de [param registry],
## bilan du réseau, émissions (t) et recherche (RP).
func record_hour(registry: BuildingRegistry, grid: PowerGrid.Report, emissions: float, research: float,
		price: float) -> void:
	_hours += 1
	var renewable := 0.0
	for b in registry.all():
		if b.power_mw > 0.0:
			_mix_sums[b.def.id] = _mix_sums.get(b.def.id, 0.0) + b.power_mw
			if b.def.is_renewable():
				renewable += b.power_mw
	_add(&"produced", grid.produced_mw)
	_add(&"renewable", renewable)
	_add(&"demand", grid.demand_mw)
	_add(&"delivered", grid.delivered_mw)
	_add(&"shed_hours", grid.shed_cities)
	_add(&"emissions", emissions)
	_add(&"research", research)
	_add(&"price", price)


## Clôt la journée avec l'argent en caisse, les comptes du jour
## [param accounts] et les villes.
func end_day(money: int, accounts: Economy.Accounts, cities: Array[Building]) -> void:
	var produced: float = _hour_sums.get(&"produced", 0.0)
	_push(&"produced", produced)
	_push(&"demand", _hour_sums.get(&"demand", 0.0))
	_push(&"delivered", _hour_sums.get(&"delivered", 0.0))
	_push(&"shed_hours", _hour_sums.get(&"shed_hours", 0.0))
	_push(&"renewable_share", 100.0 * _hour_sums.get(&"renewable", 0.0) / produced if produced > 0.0 else 0.0)
	_push(&"emissions", _hour_sums.get(&"emissions", 0.0))
	_push(&"research", _hour_sums.get(&"research", 0.0))
	_push(&"price", _hour_sums.get(&"price", 0.0) / maxi(1, _hours))
	_push(&"money", money)
	_push(&"sales", accounts.sales)
	_push(&"subsidies", accounts.subsidies)
	_push(&"costs", accounts.penalties + accounts.carbon_tax + accounts.transport + accounts.upkeep + accounts.repairs)
	_push(&"net", accounts.net())
	var people := 0
	var happy := 0.0
	for c in cities:
		people += c.city.population()
		happy += c.city.satisfaction * c.city.population()
	_push(&"population", people)
	_push(&"satisfaction", 100.0 * happy / people if people > 0 else 0.0)
	for id: StringName in _mix_sums:
		if not mix.has(id):
			var zeros := PackedFloat32Array()
			zeros.resize(days)
			mix[id] = zeros
	for id: StringName in mix:
		var values := mix[id]
		values.append(_mix_sums.get(id, 0.0))
		mix[id] = values
	days += 1
	_hour_sums.clear()
	_mix_sums.clear()
	_hours = 0


func values(key: StringName) -> PackedFloat32Array:
	return series[key]


## Dernière valeur close de [param key] (0 avant le premier jour).
func last(key: StringName) -> float:
	var v := series[key]
	return v[v.size() - 1] if not v.is_empty() else 0.0


func _add(key: StringName, amount: float) -> void:
	_hour_sums[key] = _hour_sums.get(key, 0.0) + amount


func _push(key: StringName, value: float) -> void:
	# Les tableaux compacts sont copiés à l'accès : réaffecter après l'ajout.
	var v := series[key]
	v.append(value)
	series[key] = v
