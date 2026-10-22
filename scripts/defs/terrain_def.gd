class_name TerrainDef
extends Resource
## Définition d'un type de terrain (données d'équilibrage et de rendu).

enum Type { PLAIN, FOREST, HILL, MOUNTAIN, RIVER, LAKE, SEA, DESERT, PRAIRIE, TUNDRA, ICE }

@export var type: Type = Type.PLAIN
@export var display_name := ""
## Couleur de base, utilisée pour générer les tuiles (tools/generate_tile_art.gd).
@export var color := Color.WHITE
## Les bâtiments ordinaires peuvent-ils s'y construire ?
@export var buildable := true
@export var is_water := false
## Ligne dans assets/tiles/decor.png (arbres, sommets), -1 si aucun décor.
@export var decor_row := -1
## Fertilité (agriculture) et pâturage (élevage) de base, 0–1, avant climat
## et accès à l'eau. Pour une forêt : fertilité une fois défrichée.
@export_range(0.0, 1.0) var fertility := 0.0
@export_range(0.0, 1.0) var pasture := 0.0
