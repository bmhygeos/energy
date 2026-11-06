class_name ResearchDb
extends RefCounted
## Définitions des recherches, dans l'ordre du panneau.

const DEFS: Array[ResearchDef] = [
	preload("res://data/research/irrigation.tres"),
	preload("res://data/research/harness_collar.tres"),
	preload("res://data/research/iron_metallurgy.tres"),
	preload("res://data/research/tools.tres"),
	preload("res://data/research/plough.tres"),
	preload("res://data/research/crop_rotation.tres"),
	preload("res://data/research/gears.tres"),
	preload("res://data/research/water_pump.tres"),
	preload("res://data/research/windmill.tres"),
	preload("res://data/research/scientific_method.tres"),
	preload("res://data/research/coke.tres"),
	preload("res://data/research/water_mill.tres"),
	preload("res://data/research/steam_engine.tres"),
	preload("res://data/research/locomotive.tres"),
	preload("res://data/research/refining.tres"),
	preload("res://data/research/conductivity.tres"),
	preload("res://data/research/hydroelectricity.tres"),
	preload("res://data/research/combustion_engine.tres"),
	preload("res://data/research/university.tres"),
]


static func get_def(id: StringName) -> ResearchDef:
	for def in DEFS:
		if def.id == id:
			return def
	return null
