class_name VehicleDb
extends RefCounted
## Définitions des véhicules (routiers et ferroviaires).

const DEFS: Array[VehicleDef] = [
	preload("res://data/vehicles/cart.tres"),
	preload("res://data/vehicles/truck.tres"),
	preload("res://data/vehicles/armored_truck.tres"),
	preload("res://data/vehicles/train.tres"),
]


static func get_def(id: StringName) -> VehicleDef:
	for def in DEFS:
		if def.id == id:
			return def
	return null
