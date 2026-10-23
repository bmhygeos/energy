class_name BuildingDb
extends RefCounted
## Définitions des bâtiments, dans l'ordre du menu de construction.

const DEFS: Array[BuildingDef] = [
	preload("res://data/buildings/house.tres"),
	preload("res://data/buildings/granary.tres"),
	preload("res://data/buildings/woodshed.tres"),
	preload("res://data/buildings/stone_house.tres"),
	preload("res://data/buildings/well.tres"),
	preload("res://data/buildings/workshop.tres"),
]


static func get_def(id: StringName) -> BuildingDef:
	for def in DEFS:
		if def.id == id:
			return def
	return null
