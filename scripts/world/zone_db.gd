class_name ZoneDb
extends RefCounted
## Définitions des zones, dans l'ordre du menu.

const DEFS: Array[ZoneDef] = [
	preload("res://data/zones/agriculture.tres"),
	preload("res://data/zones/pasture.tres"),
	preload("res://data/zones/forestry.tres"),
	preload("res://data/zones/fishing.tres"),
	preload("res://data/zones/quarry.tres"),
	preload("res://data/zones/iron_mine.tres"),
]


static func get_def(id: StringName) -> ZoneDef:
	for def in DEFS:
		if def.id == id:
			return def
	return null
