class_name ResearchDef
extends Resource
## Définition d'une recherche (section 7 du plan) : palier, coût en points,
## prérequis et effet. Équilibrage dans data/research/*.tres ; les effets sont
## appliqués par les modules concernés (ex. Production pour l'irrigation).

@export var id: StringName
@export var display_name := ""
@export_multiline var description := ""
## Palier de la ville à partir duquel la recherche est proposée (1 : hameau).
@export_range(1, 5) var tier := 1
## Points de recherche à accumuler.
@export var cost := 100.0
## Recherches à terminer d'abord.
@export var prerequisites: Array[StringName] = []
## Effet, lisible (info-bulle du panneau).
@export_multiline var effect := ""
