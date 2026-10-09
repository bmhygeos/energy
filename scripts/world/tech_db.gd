class_name TechDb
extends RefCounted
## Technologies, dans l'ordre de l'arbre (par ère).

const DEFS: Array[TechDef] = [
	preload("res://data/techs/woodcutting.tres"),
	preload("res://data/techs/biomass.tres"),
	preload("res://data/techs/silviculture.tres"),
	preload("res://data/techs/prospecting.tres"),
	preload("res://data/techs/mining.tres"),
	preload("res://data/techs/trucks.tres"),
	preload("res://data/techs/steam.tres"),
	preload("res://data/techs/coal_plant.tres"),
	preload("res://data/techs/rail.tres"),
	preload("res://data/techs/hv_lines.tres"),
	preload("res://data/techs/transformers.tres"),
	preload("res://data/techs/dispatching.tres"),
	preload("res://data/techs/nuclear_physics.tres"),
	preload("res://data/techs/enrichment.tres"),
	preload("res://data/techs/reactor.tres"),
	preload("res://data/techs/waste_management.tres"),
	preload("res://data/techs/wind.tres"),
	preload("res://data/techs/solar_pv.tres"),
	preload("res://data/techs/offshore.tres"),
	preload("res://data/techs/solar_thermal.tres"),
	preload("res://data/techs/batteries.tres"),
	preload("res://data/techs/pumped_storage.tres"),
	preload("res://data/techs/smart_grid.tres"),
	preload("res://data/techs/co2_filters.tres"),
	preload("res://data/techs/plasma_physics.tres"),
	preload("res://data/techs/hts.tres"),
	preload("res://data/techs/deuterium.tres"),
	preload("res://data/techs/breeding_blanket.tres"),
	preload("res://data/techs/tokamak.tres"),
	preload("res://data/techs/commercial_fusion.tres"),
	preload("res://data/techs/advanced_fusion.tres"),
]


static func get_def(id: StringName) -> TechDef:
	for def in DEFS:
		if def.id == id:
			return def
	return null
