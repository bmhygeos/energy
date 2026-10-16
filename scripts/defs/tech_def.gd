class_name TechDef
extends Resource
## Technologie de l'arbre de recherche (data/techs/*.tres). Les bâtiments et
## véhicules qu'elle débloque la désignent par leur required_tech.

## Modificateurs reconnus (multiplicatifs, cumulés sur les technologies
## acquises) et leur libellé.
const MODIFIER_NAMES := {
	&"grid_loss": "Pertes en ligne",
	&"fuel_use": "Consommation de combustible",
	&"extraction": "Rendement des extracteurs",
	&"regrowth": "Repousse des forêts",
	&"research": "Production de recherche",
	&"vehicle_speed": "Vitesse des véhicules",
	&"penalty": "Pénalités de délestage",
	&"waste": "Déchets nucléaires produits",
	&"pollution": "Pollution des centrales à combustible",
}

@export var id: StringName
@export var display_name := ""
@export_multiline var description := ""
## Ère (1 : bois … 7 : fusion).
@export_range(1, 7) var era := 1
## Coût en points de recherche.
@export var cost := 100
@export var prerequisites: Array[StringName] = []
## Clé (voir MODIFIER_NAMES) → facteur multiplicatif.
@export var modifiers: Dictionary[StringName, float] = {}
## Connue dès le début de la partie.
@export var start_known := false
## Condition d'essai : la technologie ne s'achève qu'après
## [member requires_hours] heures de fonctionnement d'un bâtiment
## [member requires_building] (tokamak avant la fusion commerciale).
@export var requires_building: StringName
@export var requires_hours := 0
## Contenu prévu dans une étape ultérieure (aucun effet pour l'instant).
@export var placeholder := false


## Effets lisibles des modificateurs, une ligne chacun.
func describe_modifiers() -> PackedStringArray:
	var lines := PackedStringArray()
	for key in modifiers:
		var pct := roundi((modifiers[key] - 1.0) * 100.0)
		lines.append("%s %s%d %%" % [MODIFIER_NAMES.get(key, key), "+" if pct > 0 else "", pct])
	return lines
