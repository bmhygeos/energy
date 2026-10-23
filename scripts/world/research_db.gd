class_name ResearchDb
extends RefCounted
## Définitions des recherches, dans l'ordre du panneau.

const DEFS: Array[ResearchDef] = [
	preload("res://data/research/irrigation.tres"),
]


static func get_def(id: StringName) -> ResearchDef:
	for def in DEFS:
		if def.id == id:
			return def
	return null
