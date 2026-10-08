class_name TerrainDb
extends RefCounted
## Accès aux définitions de terrain, indexées par TerrainDef.Type.

const DEFS: Array[TerrainDef] = [
	preload("res://data/terrains/plain.tres"),
	preload("res://data/terrains/forest.tres"),
	preload("res://data/terrains/hill.tres"),
	preload("res://data/terrains/mountain.tres"),
	preload("res://data/terrains/river.tres"),
	preload("res://data/terrains/lake.tres"),
	preload("res://data/terrains/sea.tres"),
	preload("res://data/terrains/desert.tres"),
]


static func get_def(type: int) -> TerrainDef:
	var def := DEFS[type]
	assert(def.type == type, "data/terrains : ordre incohérent pour %d" % type)
	return def


static func is_water(type: int) -> bool:
	return DEFS[type].is_water
