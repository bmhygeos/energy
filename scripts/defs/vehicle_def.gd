class_name VehicleDef
extends Resource
## Définition d'un type de véhicule (data/vehicles/*.tres).

@export var id: StringName
@export var display_name := ""
## Charge utile (t).
@export var capacity := 5.0
## Vitesse en tuiles par heure de jeu.
@export var speed := 0.3
@export var cost := 300
@export var upkeep_per_day := 5
## Coût d'usage par tuile parcourue (€).
@export var cost_per_tile := 0.5
## Technologie requise (appliquée en M5).
@export var required_tech: StringName
@export_group("Apparence")
@export var color := Color.SADDLE_BROWN
## Longueur du dessin, en pixels.
@export var length := 16.0
