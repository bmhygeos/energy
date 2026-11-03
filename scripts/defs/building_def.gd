class_name BuildingDef
extends Resource
## Définition d'un type de bâtiment de la ville : emprise, chantier,
## contraintes de placement et apparence provisoire. Équilibrage dans
## data/buildings/*.tres.

enum Category { HOUSING, STORAGE, OTHER }

const CATEGORY_NAMES: PackedStringArray = ["Logement", "Stockage", "Divers"]

@export var id: StringName
@export var display_name := ""
@export_multiline var description := ""
@export var category: Category = Category.OTHER
## Proposé dans le menu de construction.
@export var player_buildable := true
## Palier de la ville à partir duquel il se construit (1 : hameau).
@export_range(1, 5) var tier := 1
## Recherche à terminer avant de le construire (vide : aucune).
@export var research: StringName
## Emprise en tuiles (x, y) ; ancrée sur la tuile avant-bas (x et y maximaux).
@export var size := Vector2i.ONE

@export_group("Chantier")
## Durée du chantier, en heures de jeu (ticks).
@export var build_hours := 24
## Bois, pierre, fer et outils pris sur les stocks au lancement du chantier
## (pour une amélioration : son coût).
@export var wood_cost := 0
@export var stone_cost := 0
@export var iron_cost := 0
@export var tools_cost := 0
## Niveau suivant, construit sur place (grenier → grenier en pierre…).
@export var upgrade: BuildingDef

@export_group("Effets")
## Habitants logés (maisons).
@export var housing := 0
## Capacité de stockage ajoutée (grenier, camp d'abattage, parc à pierre,
## entrepôt à outils, parcs à fer et à charbon, réservoir de pétrole).
@export var food_capacity := 0.0
@export var wood_capacity := 0.0
@export var stone_capacity := 0.0
@export var iron_capacity := 0.0
@export var tools_capacity := 0.0
@export var coal_capacity := 0.0
@export var oil_capacity := 0.0
## Forge : outils fabriqués par jour (FORGE_IRON_PER_TOOL fer et
## FORGE_WOOD_PER_TOOL bois chacun).
@export var tools_per_day := 0.0
## Atelier de tissage : vêtements tissés par jour (une fibre chacun).
@export var clothes_per_day := 0.0
## Moulin : moud le grain (agriculture : bonus grain_bonus, le meilleur
## compte ; gâchis) ; puissance mécanique moyenne (W), à vent normal pour un
## moulin à vent.
@export var grinds_grain := false
@export var grain_bonus := 0.2
@export var wind_powered := true
## Moulin à eau : entraîne scies et soufflets (coupe du bois et forges, part ;
## le meilleur compte).
@export var drive_bonus := 0.0
## Scierie : bonus de la coupe du bois (part ; un seul compte).
@export var forestry_bonus := 0.0
@export var mechanical_watts := 0.0
## Machine à vapeur : charbon brûlé par jour ; sans lui, ses bonus
## (drive_bonus, mine_bonus) disparaissent.
@export var coal_per_day := 0.0
## Carrières et mines : bonus (pompes d'exhaure, treuils à vapeur).
@export var mine_bonus := 0.0
## Gare : dessert les tuiles autour d'elle si une voie la relie au village.
@export var station := false
## Places pour les chevaux (écurie).
@export var horse_capacity := 0
## Habitants approvisionnés en eau (puits).
@export var water_supply := 0
## Recherche : multiplicateur des points des habitants couverts (atelier…).
@export var research_multiplier := 1.0
@export var research_coverage := 0

@export_group("Placement")
## Terrains autorisés pour chaque tuile de l'emprise (vide : tout terrain
## constructible). Construire sur une forêt la défriche.
@export var allowed_terrains: Array[TerrainDef.Type] = []
## Au moins une tuile de l'emprise doit avoir accès à l'eau.
@export var needs_water_access := false
## Au moins une tuile autour de l'emprise doit être de l'un de ces terrains.
@export var adjacent_terrains: Array[TerrainDef.Type] = []

@export_group("Apparence")
@export var color := Color.GRAY
@export var roof_color := Color.DIM_GRAY
## Hauteur du volume dessiné, en pixels.
@export var height := 24.0


func footprint_origin(anchor: Vector2i) -> Vector2i:
	return anchor - size + Vector2i.ONE


## Tuiles occupées si le bâtiment est ancré en [param anchor].
func footprint(anchor: Vector2i) -> Array[Vector2i]:
	var origin := footprint_origin(anchor)
	var cells: Array[Vector2i] = []
	for y in size.y:
		for x in size.x:
			cells.append(origin + Vector2i(x, y))
	return cells


## Coût par marchandise (Stockpile.Good).
func costs() -> PackedFloat32Array:
	var values := Stockpile.zeros()
	values[Stockpile.Good.WOOD] = wood_cost
	values[Stockpile.Good.STONE] = stone_cost
	values[Stockpile.Good.IRON] = iron_cost
	values[Stockpile.Good.TOOLS] = tools_cost
	return values


## Coût lisible (« 15 bois, 20 pierre » ; « gratuit ») de [param values]
## (par défaut, le coût de base).
func describe_cost(values: PackedFloat32Array = PackedFloat32Array()) -> String:
	var parts := PackedStringArray()
	if values.is_empty():
		values = costs()
	for good in values.size():
		if values[good] > 0.0:
			parts.append("%d %s" % [roundi(values[good]), Stockpile.GOOD_NAMES[good].to_lower()])
	return ", ".join(parts) if not parts.is_empty() else "gratuit"


## Effets lisibles, un par ligne (vide : aucun).
func describe_effects() -> PackedStringArray:
	var lines := PackedStringArray()
	if housing > 0:
		lines.append("Loge %d habitants" % housing)
	for good in Stockpile.COUNT:
		if capacity_of(good) > 0.0:
			lines.append("Stocke %d de %s" % [roundi(capacity_of(good)), Stockpile.GOOD_NAMES[good].to_lower()])
	if tools_per_day > 0.0:
		lines.append("Fabrique %s outils par jour (fer et bois)" % Format.decimal(tools_per_day))
	if forestry_bonus > 0.0:
		lines.append("Coupe du bois +%d %%" % roundi(forestry_bonus * 100.0))
	if clothes_per_day > 0.0:
		lines.append("Tisse %s vêtements par jour (une fibre chacun)" % Format.decimal(clothes_per_day))
	if grinds_grain:
		lines.append("Moud le grain : agriculture +%d %%, gâchis de la nourriture moitié moindre" % roundi(grain_bonus * 100.0))
	if drive_bonus > 0.0:
		lines.append("Entraîne scies et soufflets : coupe du bois et forges +%d %%" % roundi(drive_bonus * 100.0))
	if mine_bonus > 0.0:
		lines.append("Carrières et mines +%d %%" % roundi(mine_bonus * 100.0))
	if coal_per_day > 0.0:
		lines.append("Brûle %s charbon par jour (sans charbon, à l'arrêt)" % Format.decimal(coal_per_day))
	if station:
		lines.append("Gare : reliée par la voie à une gare du village, elle rapproche les tuiles autour d'elle")
	if mechanical_watts > 0.0:
		lines.append("Puissance mécanique ≈ %s%s" % [PowerMeter.format(mechanical_watts), " selon le vent" if wind_powered else ""])
	if horse_capacity > 0:
		lines.append("Loge %d chevaux" % horse_capacity)
	if water_supply > 0:
		lines.append("Eau pour %d habitants ; irrigue les champs voisins (recherche Irrigation)" % water_supply)
	if research_coverage > 0:
		lines.append("Recherche ×%s pour %d habitants" % [Format.decimal(research_multiplier), research_coverage])
	return lines


## Contraintes de placement lisibles, une par ligne (vide : aucune).
func describe_constraints() -> PackedStringArray:
	var lines := PackedStringArray()
	if not allowed_terrains.is_empty():
		lines.append("Sur : " + _terrain_names(allowed_terrains))
	if needs_water_access:
		lines.append("Près de l'eau")
	if not adjacent_terrains.is_empty():
		lines.append("À côté de : " + _terrain_names(adjacent_terrains))
	return lines


static func _terrain_names(terrains: Array[TerrainDef.Type]) -> String:
	var names := PackedStringArray()
	for t in terrains:
		names.append(TerrainDb.get_def(t).display_name.to_lower())
	return ", ".join(names)


## Capacité de stockage ajoutée pour [param good] (Stockpile.Good).
func capacity_of(good: int) -> float:
	match good:
		Stockpile.Good.FOOD:
			return food_capacity
		Stockpile.Good.WOOD:
			return wood_capacity
		Stockpile.Good.STONE:
			return stone_capacity
		Stockpile.Good.IRON:
			return iron_capacity
		Stockpile.Good.TOOLS:
			return tools_capacity
		Stockpile.Good.COAL:
			return coal_capacity
		Stockpile.Good.OIL:
			return oil_capacity
	return 0.0
