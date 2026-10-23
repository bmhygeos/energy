class_name Stockpile
extends RefCounted
## Stocks centralisés de la cité (nourriture, bois, pierre, fer, outils) :
## capacité, gâchis de la
## nourriture au-delà de la moitié du grenier, pertes au-delà de la capacité,
## et énergie contenue (compteur de puissance). Pure donnée.

enum Good { FOOD, WOOD, STONE, IRON, TOOLS }

const COUNT := 5
const GOOD_NAMES: PackedStringArray = ["Nourriture", "Bois", "Pierre", "Fer", "Outils"]
## Contenu énergétique d'une unité (MJ) : 2 500 kcal de nourriture, 10 kg de
## bois sec ; les matériaux n'en ont pas.
const ENERGY_MJ: PackedFloat32Array = [10.5, 150.0, 0.0, 0.0, 0.0]
## Capacité du village sans bâtiment de stockage.
const BASE_CAPACITY: PackedFloat32Array = [200.0, 150.0, 300.0, 200.0, 100.0]
## Stocks au départ : de quoi tenir jusqu'aux premières récoltes.
const START: PackedFloat32Array = [550.0, 120.0, 0.0, 0.0, 0.0]
## Nourriture gâtée par jour, en part de l'excédent au-delà de la moitié de
## la capacité.
const SPOILAGE_PER_DAY := 0.01
## Un stock devient plein à FULL_RATIO de sa capacité et le reste jusqu'à
## redescendre sous REFILL_RATIO (hystérésis : pas de va-et-vient quotidien des
## travailleurs autour du seuil).
const FULL_RATIO := 0.95
const REFILL_RATIO := 0.75

var amount := zeros()
## Stocks pleins (voir update_full).
var full: Array[bool] = [false, false, false, false, false]
var capacity := zeros()
## Pertes de la journée en cours (gâchis et débordement), par marchandise.
var lost_today := zeros()
## Multiplicateur du gâchis de la nourriture (moitié avec un moulin).
var spoilage_factor := 1.0


## Une valeur nulle par marchandise.
static func zeros() -> PackedFloat32Array:
	var values := PackedFloat32Array()
	values.resize(COUNT)
	return values


func _init() -> void:
	amount = START.duplicate()
	capacity = BASE_CAPACITY.duplicate()


## Ajoute [param qty] de [param good] ; le surplus au-delà de la capacité est
## perdu. Renvoie la quantité stockée.
func add(good: Good, qty: float) -> float:
	var stored := minf(qty, maxf(0.0, capacity[good] - amount[good]))
	amount[good] += stored
	lost_today[good] += qty - stored
	return stored


## Retire jusqu'à [param qty] de [param good] ; renvoie la quantité obtenue.
func take(good: Good, qty: float) -> float:
	var got := minf(qty, amount[good])
	amount[good] -= got
	return got


func has(good: Good, qty: float) -> bool:
	return amount[good] >= qty


## Met à jour les stocks pleins : produire davantage serait perdu.
func update_full() -> void:
	for good in amount.size():
		if amount[good] >= capacity[good] * FULL_RATIO:
			full[good] = true
		elif amount[good] < capacity[good] * REFILL_RATIO:
			full[good] = false


## Jours de réserve de [param good] pour une consommation de [param per_day].
func days_of(good: Good, per_day: float) -> float:
	return amount[good] / per_day if per_day > 0.0 else INF


## Fin de journée : la nourriture se gâte au-delà de la moitié du grenier.
func end_day() -> void:
	var excess := amount[Good.FOOD] - capacity[Good.FOOD] / 2.0
	if excess > 0.0:
		var spoiled := excess * SPOILAGE_PER_DAY * spoilage_factor
		amount[Good.FOOD] -= spoiled
		lost_today[Good.FOOD] += spoiled


## Remet à zéro les pertes du jour (après les statistiques).
func reset_day() -> void:
	lost_today = zeros()
