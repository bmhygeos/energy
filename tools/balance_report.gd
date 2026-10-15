extends SceneTree
## Rapport d'équilibrage sur le rythme cible d'une partie d'1 h à ×1 (10
## ticks/s : 1 min réelle = 600 h de jeu = 25 jours) : arrivée de chaque ère
## selon un rythme de construction de laboratoires « joueur moyen »,
## rentabilité des centrales, demande des villes.
## Lancer : godot --headless -s res://tools/balance_report.gd

const HOURS_PER_MINUTE := 600.0
## Laboratoires en service d'un joueur moyen : [minute, nombre].
const LAB_RAMP: Array[Vector2] = [
	Vector2(1, 1), Vector2(3, 2), Vector2(6, 3), Vector2(10, 4), Vector2(15, 6),
	Vector2(22, 8), Vector2(30, 10), Vector2(40, 12),
]
## Ère → [minute cible, technologie qui marque l'arrivée dans l'ère].
const ERA_TARGETS := {
	2: [5.0, &"coal_plant"], 3: [12.0, &"hv_lines"], 4: [20.0, &"nuclear_physics"],
	5: [30.0, &"wind"], 6: [40.0, &"batteries"], 7: [55.0, &"commercial_fusion"],
}
## Facteur de charge supposé d'un bon site (potentiel de tuile).
const GOOD_WIND_SITE := 0.7
const GOOD_SUN_SITE := 0.75
## Demande initiale totale d'une carte 64×64 (5 villes de 3 à 10 MW).
const START_DEMAND := 32.0


func _initialize() -> void:
	_research_pacing()
	_plants()
	_demand()
	quit()


## Ordre de recherche : ère par ère, prérequis d'abord ; les technologies
## d'une ère passent avant celles de l'ère suivante.
func _research_pacing() -> void:
	print("=== Recherche (labos : %s ; efficacité n^%s) ===" % [_ramp_text(), Production.RESEARCH_SCALING])
	var known := {}
	var order: Array[TechDef] = []
	var defs := TechDb.DEFS.duplicate()
	defs.sort_custom(func(a: TechDef, b: TechDef) -> bool: return a.era < b.era if a.era != b.era else a.cost < b.cost)
	for def in defs:
		if def.start_known:
			known[def.id] = true
	while true:
		var progressed := false
		for def in defs:
			if known.has(def.id):
				continue
			if def.prerequisites.all(func(p: StringName) -> bool: return known.has(p)):
				order.append(def)
				known[def.id] = true
				progressed = true
				break
		if not progressed:
			break
	var minute := 0.0
	var bank := 0.0
	var factor := 1.0
	var reached := {}
	for def in order:
		while bank < def.cost:
			minute += 0.05
			bank += _rp_per_minute(minute) * factor * 0.05
			if minute > 200.0:
				break
		bank -= def.cost
		factor *= def.modifiers.get(&"research", 1.0)
		reached[def.id] = minute
		print("  %5.1f min  ère %d  %-28s %6d RP" % [minute, def.era, def.display_name, def.cost])
	print("--- Arrivée des ères (cible → estimée)")
	for era: int in ERA_TARGETS:
		var target: Array = ERA_TARGETS[era]
		print("  ère %d : %4.0f min → %5.1f min (%s)" % [era, target[0], reached.get(target[1], -1.0), target[1]])


func _rp_per_minute(minute: float) -> float:
	var labs := 0
	for step in LAB_RAMP:
		if minute >= step.x:
			labs = int(step.y)
	return labs * Production.research_efficiency(labs) * HOURS_PER_MINUTE


func _ramp_text() -> String:
	var parts := PackedStringArray()
	for step in LAB_RAMP:
		parts.append("%d@%dmin" % [step.y, step.x])
	return " ".join(parts)


func _plants() -> void:
	var weather := Weather.new(1)
	var wind := 0.0
	var sun := 0.0
	for tick in GameDate.HOURS_PER_YEAR:
		wind += weather.wind_at(tick)
		sun += weather.sun_at(tick)
	wind /= GameDate.HOURS_PER_YEAR
	sun /= GameDate.HOURS_PER_YEAR
	print("\n=== Centrales à pleine demande (prix moyen %s €/MWh, subvention an 1 %s €/MWh) ===" % [
		Economy.BASE_PRICE, Economy.subsidy_at(0)])
	print("  %-26s %9s %8s %8s %9s %9s %8s" % ["", "coût €", "MW moy.", "€/j net", "entretien", "rentab. j", "€/MW"])
	for def in BuildingDb.DEFS:
		if def.power_mw <= 0.0:
			continue
		var load := 1.0
		match def.power_source:
			BuildingDef.PowerSource.WIND:
				load = wind * GOOD_WIND_SITE * (1.25 if def.on_sea else 1.0)
			BuildingDef.PowerSource.SUN:
				load = sun * GOOD_SUN_SITE
			BuildingDef.PowerSource.SOLAR_THERMAL:
				load = minf(1.0, sun * GOOD_SUN_SITE * def.solar_multiple)
		var mw := def.power_mw * load
		var price := Economy.BASE_PRICE + (Economy.subsidy_at(0) if def.is_renewable() else 0.0)
		var net := mw * 24.0 * price - def.upkeep_per_day
		print("  %-26s %9s %8.1f %8.0f %9d %9.1f %8.0f" % [def.display_name, Format.thousands(def.cost), mw, net,
			def.upkeep_per_day, def.cost / net if net > 0.0 else INF, def.cost / def.power_mw])


func _demand() -> void:
	print("\n=== Demande totale (villes toujours alimentées, %d %%/an) ===" % roundi(City.GROWTH_SERVED * 100.0))
	var demand := START_DEMAND
	for year in range(1, 14):
		var minute := (year - 1) * GameDate.HOURS_PER_YEAR / HOURS_PER_MINUTE
		print("  an %2d (%4.1f min) : %6.0f MW de base, recette max %s €/j" % [year, minute, demand,
			Format.thousands(roundi(demand * 0.9 * 24.0 * Economy.BASE_PRICE))])
		demand *= pow(1.0 + City.GROWTH_SERVED / (GameDate.DAYS_PER_SEASON * GameDate.SEASONS_PER_YEAR),
			GameDate.DAYS_PER_SEASON * GameDate.SEASONS_PER_YEAR)
