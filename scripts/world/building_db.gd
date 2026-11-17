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
	preload("res://data/buildings/outpost.tres"),
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
	preload("res://data/buildings/refinery.tres"),
	preload("res://data/buildings/university.tres"),
	preload("res://data/buildings/artisans.tres"),
	preload("res://data/buildings/dispensary.tres"),
	preload("res://data/buildings/guard_post.tres"),
	preload("res://data/buildings/school.tres"),
	preload("res://data/buildings/theater.tres"),
	preload("res://data/buildings/electronics_factory.tres"),
	preload("res://data/buildings/computer_center.tres"),
	preload("res://data/buildings/datacenter.tres"),
	preload("res://data/buildings/rocket_factory.tres"),
	preload("res://data/buildings/truck_depot.tres"),
	preload("res://data/buildings/charger.tres"),
	preload("res://data/buildings/airfield.tres"),
	preload("res://data/buildings/launch_pad.tres"),
	preload("res://data/buildings/power_plant.tres"),
	preload("res://data/buildings/oil_plant.tres"),
	preload("res://data/buildings/dam.tres"),
	preload("res://data/buildings/enrichment_plant.tres"),
	preload("res://data/buildings/nuclear_plant.tres"),
	preload("res://data/buildings/wind_turbine.tres"),
	preload("res://data/buildings/solar_field.tres"),
	preload("res://data/buildings/battery.tres"),
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
