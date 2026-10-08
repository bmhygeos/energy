class_name TerrainDef
extends Resource
## Définition d'un type de terrain (données d'équilibrage et de rendu).

enum Type { PLAIN, FOREST, HILL, MOUNTAIN, RIVER, LAKE, SEA, DESERT }

@export var type: Type = Type.PLAIN
@export var display_name := ""
## Couleur de base, utilisée pour générer les tuiles (tools/generate_tile_art.gd).
@export var color := Color.WHITE
## Les bâtiments ordinaires peuvent-ils s'y construire ?
@export var buildable := true
@export var is_water := false
## Ligne dans assets/tiles/decor.png (arbres, sommets), -1 si aucun décor.
@export var decor_row := -1
