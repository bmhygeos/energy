class_name BuildingDb
extends RefCounted
## Définitions des bâtiments, dans l'ordre du menu de construction.

const DEFS: Array[BuildingDef] = [
	preload("res://data/buildings/lumberjack.tres"),
	preload("res://data/buildings/nursery.tres"),
	preload("res://data/buildings/coal_mine.tres"),
	preload("res://data/buildings/uranium_mine.tres"),
	preload("res://data/buildings/enrichment_plant.tres"),
	preload("res://data/buildings/lithium_mine.tres"),
	preload("res://data/buildings/deuterium_plant.tres"),
	preload("res://data/buildings/biomass_plant.tres"),
	preload("res://data/buildings/coal_plant.tres"),
	preload("res://data/buildings/nuclear_plant.tres"),
	preload("res://data/buildings/waste_site.tres"),
	preload("res://data/buildings/wind_turbine.tres"),
	preload("res://data/buildings/solar_farm.tres"),
	preload("res://data/buildings/offshore_wind.tres"),
	preload("res://data/buildings/solar_thermal_plant.tres"),
	preload("res://data/buildings/battery.tres"),
	preload("res://data/buildings/pumped_storage.tres"),
	preload("res://data/buildings/fusion_reactor.tres"),
	preload("res://data/buildings/depot.tres"),
	preload("res://data/buildings/warehouse.tres"),
	preload("res://data/buildings/station.tres"),
	preload("res://data/buildings/port.tres"),
	preload("res://data/buildings/laboratory.tres"),
	preload("res://data/buildings/tokamak.tres"),
]


static func get_def(id: StringName) -> BuildingDef:
	for def in DEFS:
		if def.id == id:
			return def
	return null
