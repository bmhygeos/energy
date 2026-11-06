class_name BuildingDb
extends RefCounted
## Définitions des bâtiments, dans l'ordre du menu de construction.

const DEFS: Array[BuildingDef] = [
	preload("res://data/buildings/house.tres"),
	preload("res://data/buildings/granary.tres"),
	preload("res://data/buildings/woodshed.tres"),
	preload("res://data/buildings/sawmill.tres"),
	preload("res://data/buildings/stone_house.tres"),
	preload("res://data/buildings/well.tres"),
	preload("res://data/buildings/workshop.tres"),
	preload("res://data/buildings/stable.tres"),
	preload("res://data/buildings/forge.tres"),
	preload("res://data/buildings/stone_yard.tres"),
	preload("res://data/buildings/tool_store.tres"),
	preload("res://data/buildings/iron_yard.tres"),
	preload("res://data/buildings/coal_yard.tres"),
	preload("res://data/buildings/oil_tank.tres"),
	preload("res://data/buildings/copper_yard.tres"),
	preload("res://data/buildings/windmill.tres"),
	preload("res://data/buildings/weaver.tres"),
	preload("res://data/buildings/laboratory.tres"),
	preload("res://data/buildings/water_mill.tres"),
	preload("res://data/buildings/steam_engine.tres"),
	preload("res://data/buildings/station.tres"),
	preload("res://data/buildings/fishing_port.tres"),
	preload("res://data/buildings/port.tres"),
	preload("res://data/buildings/market.tres"),
	preload("res://data/buildings/refinery.tres"),
	preload("res://data/buildings/university.tres"),
	preload("res://data/buildings/power_plant.tres"),
	preload("res://data/buildings/dam.tres"),
	preload("res://data/buildings/stone_granary.tres"),
	preload("res://data/buildings/large_granary.tres"),
	preload("res://data/buildings/warehouse.tres"),
	preload("res://data/buildings/silo.tres"),
	preload("res://data/buildings/town_house.tres"),
	preload("res://data/buildings/apartment.tres"),
	preload("res://data/buildings/tower.tres"),
]


static func get_def(id: StringName) -> BuildingDef:
	for def in DEFS:
		if def.id == id:
			return def
	return null
