class_name Milestones
extends RefCounted
## Jalons facultatifs du bac à sable, vérifiés à chaque fin de journée. Les
## jalons de la v2 (paliers, population, exploration…) viendront avec leurs
## simulations. Pure donnée.

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
	var buildings: Array[Building] = []


var defs: Array[Def] = []
## Jalons atteints : id → jour (index) de l'atteinte.
var reached: Dictionary[StringName, int] = {}


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
