class_name BuildingDb
extends RefCounted
## Définitions des bâtiments, dans l'ordre du menu de construction.

const DEFS: Array[BuildingDef] = [
	preload("res://data/buildings/lumberjack.tres"),
	preload("res://data/buildings/nursery.tres"),
	preload("res://data/buildings/coal_mine.tres"),
	preload("res://data/buildings/biomass_plant.tres"),
	preload("res://data/buildings/coal_plant.tres"),
	preload("res://data/buildings/wind_turbine.tres"),
	preload("res://data/buildings/solar_farm.tres"),
	preload("res://data/buildings/depot.tres"),
	preload("res://data/buildings/warehouse.tres"),
	preload("res://data/buildings/station.tres"),
	preload("res://data/buildings/laboratory.tres"),
]


static func get_def(id: StringName) -> BuildingDef:
	for def in DEFS:
		if def.id == id:
			return def
	return null
