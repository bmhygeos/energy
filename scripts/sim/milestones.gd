class_name Milestones
extends RefCounted
## Jalons facultatifs du bac à sable, vérifiés à chaque fin de journée :
## premiers hivers, exploration, paliers, recherche et inventions des paliers
## 1 et 2, premiers pas du bourg (standard). Pure donnée.

## Territoire visé par les jalons d'exploration (tuiles ; 144 au départ).
const EXPLORER_TILES := 300
const LARGE_TERRITORY_TILES := 2000
## Chevaux d'une écurie pleine.
const STABLE_HORSES := 6
## Pièces du jalon « Trésor ».
const TREASURY_MONEY := 1000

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
	## Jour clos (index, 0 : premier jour).
	var day := 0
	var population := 0
	var tier := 1
	## Tuiles du territoire.
	var territory := 0
	var horses := 0.0
	var water_coverage := 1.0
	## Part des vêtements usés remplacés la veille (0 avant le bourg).
	var clothes_coverage := 0.0
	## Gares desservies par le train.
	var served_stations := 0
	var research: Research
	## Pièces du trésor.
	var money := 0.0

	func has_building(id: StringName) -> bool:
		return buildings.any(func(b: Building) -> bool: return b.def.id == id and b.is_complete())

	func is_researched(id: StringName) -> bool:
		return research != null and research.is_done(id)


var defs: Array[Def] = []
## Jalons atteints : id → jour (index) de l'atteinte.
var reached: Dictionary[StringName, int] = {}


## Jalons de la partie, dans l'ordre où ils viennent d'habitude.
static func standard() -> Array[Def]:
	var village_research := ResearchDb.DEFS.filter(func(d: ResearchDef) -> bool: return d.tier == 2)
	return [
		Def.new(&"first_winter", "Premier hiver",
			"Arriver au printemps de l'an 2 sans avoir perdu d'habitant (%d ou plus)." % Population.START,
			func(f: Facts) -> bool: return (f.day >= GameDate.DAYS_PER_SEASON * GameDate.SEASONS_PER_YEAR - 1
				and f.population >= Population.START)),
		Def.new(&"explorer", "Au-delà de l'horizon",
			"Agrandir le territoire à %d tuiles par les expéditions." % EXPLORER_TILES,
			func(f: Facts) -> bool: return f.territory >= EXPLORER_TILES),
		Def.new(&"irrigation", "Irrigation", "Terminer la recherche Irrigation.",
			func(f: Facts) -> bool: return f.is_researched(&"irrigation")),
		Def.new(&"prosperous", "Hameau prospère", "Atteindre 50 habitants.",
			func(f: Facts) -> bool: return f.population >= 50),
		Def.new(&"village", "Village", "Passer au palier Village (%d habitants, besoins satisfaits)." % CityTier.POPULATION[1],
			func(f: Facts) -> bool: return f.tier >= 2),
		Def.new(&"water", "Eau pour tous", "Au village, servir tous les habitants par des puits.",
			func(f: Facts) -> bool: return f.tier >= 2 and f.has_building(&"well") and f.water_coverage >= 1.0),
		Def.new(&"stone_house", "Maisons en dur", "Améliorer une maison en maison en pierre.",
			func(f: Facts) -> bool: return f.has_building(&"stone_house")),
		Def.new(&"forge", "Maître de forge", "Forger les premiers outils.",
			func(f: Facts) -> bool: return f.stats != null and f.stats.last(&"tools_produced") > 0.0),
		Def.new(&"stable", "Écurie pleine", "Avoir %d chevaux de trait." % STABLE_HORSES,
			func(f: Facts) -> bool: return f.horses >= STABLE_HORSES),
		Def.new(&"inventions", "Inventions du village", "Terminer les %d recherches du village." % village_research.size(),
			func(f: Facts) -> bool: return village_research.all(func(d: ResearchDef) -> bool: return f.is_researched(d.id))),
		Def.new(&"large_territory", "Grand territoire", "Agrandir le territoire à %d tuiles." % LARGE_TERRITORY_TILES,
			func(f: Facts) -> bool: return f.territory >= LARGE_TERRITORY_TILES),
		Def.new(&"bourg", "Bourg", "Passer au palier Bourg (%d habitants)." % CityTier.POPULATION[2],
			func(f: Facts) -> bool: return f.tier >= 3),
		Def.new(&"coal", "Gueules noires", "Extraire le premier charbon (gisement prospecté au bourg).",
			func(f: Facts) -> bool: return f.stats != null and f.stats.last(&"coal_produced") > 0.0),
		Def.new(&"clothes", "Bien vêtus", "Au bourg, remplacer tous les vêtements usés (atelier de tissage).",
			func(f: Facts) -> bool: return (f.tier >= 3 and f.clothes_coverage >= 1.0
				and f.stats != null and f.stats.last(&"clothes_produced") > 0.0)),
		Def.new(&"laboratory", "Savants", "Construire un laboratoire (recherche ×5).",
			func(f: Facts) -> bool: return f.has_building(&"laboratory")),
		Def.new(&"railway", "Chemin de fer", "Relier une gare lointaine à une gare du village par la voie ferrée.",
			func(f: Facts) -> bool: return f.served_stations > 0),
		Def.new(&"market", "Jour de marché", "Construire un marché pour commercer.",
			func(f: Facts) -> bool: return f.has_building(&"market")),
		Def.new(&"treasury", "Trésor", "Amasser %d pièces." % TREASURY_MONEY,
			func(f: Facts) -> bool: return f.money >= TREASURY_MONEY),
	]


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
