class_name BuildingDb
extends RefCounted
## Définitions des bâtiments, dans l'ordre du menu de construction.

const DEFS: Array[BuildingDef] = [
	preload("res://data/buildings/granary.tres"),
]


static func get_def(id: StringName) -> BuildingDef:
	for def in DEFS:
		if def.id == id:
			return def
	return null
