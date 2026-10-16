class_name Milestones
extends RefCounted
## Jalons facultatifs du bac à sable (premier MW, villes alimentées,
## renouvelables, fusion…), vérifiés à chaque fin de journée. Pure donnée.

## Un jalon : condition évaluée sur les faits de la journée close.
class Def:
	var id: StringName
	var display_name := ""
	var description := ""
	var check: Callable

	func _init(p_id: StringName, p_name: String, p_description: String, p_check: Callable) -> void:
		id = p_id
		display_name = p_name
		description = p_description
		check = p_check


## Faits de la journée close.
class Facts:
	var stats: Statistics
	var money := 0
	var cities: Array[Building] = []
	var buildings: Array[Building] = []
	var research: Research


## Victoire : émissions maximales (t de CO₂ sur la journée).
const FUSION_MAX_EMISSIONS := 200

var defs: Array[Def] = []
## Jalons atteints : id → jour (index) de l'atteinte.
var reached: Dictionary[StringName, int] = {}


func _init() -> void:
	defs = [
		Def.new(&"first_mw", "Premier mégawatt", "Livrer de l'électricité à une ville.", _first_mw),
		Def.new(&"city_served", "Lumière en ville", "Alimenter une ville 24 h sur 24.", _city_served),
		Def.new(&"all_served", "Réseau national", "Alimenter toutes les villes 24 h sur 24.", _all_served),
		Def.new(&"hundred_mw", "Cent mégawatts", "Livrer 100 MW en moyenne sur une journée.", _hundred_mw),
		Def.new(&"nuclear", "Ère atomique", "Mettre en service une centrale nucléaire.", _nuclear),
		Def.new(&"renewable_half", "Moitié verte",
			"Produire 50 % d'électricité renouvelable sur une journée (10 MW en moyenne au moins).", _renewable_half),
		Def.new(&"carbon_free", "Zéro carbone", "Une journée sans émission en livrant 50 MW en moyenne.", _carbon_free),
		Def.new(&"happy", "Habitants comblés", "Satisfaction moyenne des habitants à 80 %.", _happy),
		Def.new(&"million", "Millionnaire", "Avoir 1 000 000 € en caisse.", _million),
		Def.new(&"scholar", "Savants", "Acquérir 20 technologies.", _scholar),
		Def.new(&"metropolis", "Pays prospère", "Atteindre 500 000 habitants.", _metropolis),
		Def.new(&"fusion_reactor", "Étoile en bouteille", "Mettre en service un réacteur de fusion.", _fusion_running),
		Def.new(&"fusion", "Ère de la fusion (victoire)",
			"Tirer plus de 50 %% de l'électricité de la fusion sur une journée, avec moins de %d t de CO₂." % FUSION_MAX_EMISSIONS,
			_fusion_era),
	]


static func _first_mw(f: Facts) -> bool:
	return f.stats.last(&"delivered") > 0.0


static func _city_served(f: Facts) -> bool:
	return f.cities.any(func(c: Building) -> bool: return c.city.served_ratio_yesterday >= 1.0)


static func _all_served(f: Facts) -> bool:
	return not f.cities.is_empty() and f.cities.all(func(c: Building) -> bool: return c.city.served_ratio_yesterday >= 1.0)


static func _hundred_mw(f: Facts) -> bool:
	return f.stats.last(&"delivered") >= 100.0 * GameDate.HOURS_PER_DAY


static func _nuclear(f: Facts) -> bool:
	return f.buildings.any(func(b: Building) -> bool:
		return b.def.id == &"nuclear_plant" and b.status == Building.Status.RUNNING)


static func _renewable_half(f: Facts) -> bool:
	return f.stats.last(&"renewable_share") >= 50.0 and f.stats.last(&"produced") >= 10.0 * GameDate.HOURS_PER_DAY


static func _carbon_free(f: Facts) -> bool:
	return f.stats.last(&"emissions") <= 0.0 and f.stats.last(&"delivered") >= 50.0 * GameDate.HOURS_PER_DAY


static func _happy(f: Facts) -> bool:
	return f.stats.last(&"satisfaction") >= 80.0


static func _million(f: Facts) -> bool:
	return f.money >= 1_000_000


static func _scholar(f: Facts) -> bool:
	return f.research.known.size() >= 20


static func _metropolis(f: Facts) -> bool:
	return f.stats.last(&"population") >= 500_000


static func _fusion_running(f: Facts) -> bool:
	return f.buildings.any(func(b: Building) -> bool:
		return b.def.id == &"fusion_reactor" and b.status == Building.Status.RUNNING)


static func _fusion_era(f: Facts) -> bool:
	var produced := f.stats.last(&"produced")
	if produced <= 0.0 or not f.stats.mix.has(&"fusion_reactor"):
		return false
	var fusion := f.stats.mix[&"fusion_reactor"]
	return fusion[fusion.size() - 1] > 0.5 * produced and f.stats.last(&"emissions") < FUSION_MAX_EMISSIONS


func is_reached(id: StringName) -> bool:
	return reached.has(id)


## Vérifie les jalons restants à la clôture du jour [param day] ; renvoie
## ceux qui viennent d'être atteints.
func check(facts: Facts, day: int) -> Array[Def]:
	var result: Array[Def] = []
	for def in defs:
		if not reached.has(def.id) and def.check.call(facts):
			reached[def.id] = day
			result.append(def)
	return result
