class_name VehicleDb
extends RefCounted
## Définitions des véhicules routiers.

const DEFS: Array[VehicleDef] = [
	preload("res://data/vehicles/cart.tres"),
	preload("res://data/vehicles/truck.tres"),
]


static func get_def(id: StringName) -> VehicleDef:
	for def in DEFS:
		if def.id == id:
			return def
	return null
