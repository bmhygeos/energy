class_name BuildingDef
extends Resource
## Définition d'un type de bâtiment : coûts, emprise, contraintes de placement
## et apparence provisoire. Équilibrage dans data/buildings/*.tres.

enum Category { RESOURCES, ENERGY, LOGISTICS, OTHER }
## Ressource naturelle exploitée par un extracteur.
enum Extraction { NONE, FOREST, DEPOSIT, REFOREST }
## Ce qui module la puissance électrique produite.
enum PowerSource { NONE, FUEL, WIND, SUN }
## Forme du dessin provisoire (scenes/world/building_sprite.gd).
enum Style { BOX, TURBINE, PANELS, CITY }

const CATEGORY_NAMES: PackedStringArray = ["Ressources", "Énergie", "Logistique", "Divers"]

@export var id: StringName
@export var display_name := ""
@export_multiline var description := ""
@export var category: Category = Category.OTHER
## Proposé dans le menu de construction (false : villes).
@export var player_buildable := true
## Emprise en tuiles (x, y) ; ancrée sur la tuile avant-bas (x et y maximaux).
@export var size := Vector2i.ONE

@export_group("Coûts")
@export var cost := 1000
## Durée du chantier, en heures de jeu (ticks).
@export var build_hours := 24
@export var upkeep_per_day := 10
## Durée de vie en années de jeu (0 : illimitée). Pas encore simulée.
@export var lifetime_years := 0
## Technologie requise (vide : disponible dès le départ). Appliquée en M5.
@export var required_tech: StringName

@export_group("Placement")
## Terrains autorisés pour chaque tuile de l'emprise (vide : tout terrain
## constructible). Construire sur une forêt la défriche.
@export var allowed_terrains: Array[TerrainDef.Type] = []
## Gisement requis sous au moins une tuile de l'emprise.
@export var required_deposit: WorldMap.Deposit = WorldMap.Deposit.NONE
## Une route doit border l'emprise.
@export var needs_road := false
## Une voie ferrée doit border l'emprise.
@export var needs_rail := false
## Au moins une tuile de l'emprise doit avoir accès à l'eau.
@export var needs_water_access := false
## Au moins une tuile de l'emprise doit toucher la mer.
@export var needs_coast := false
## Au moins une tuile autour de l'emprise doit être de l'un de ces terrains.
@export var adjacent_terrains: Array[TerrainDef.Type] = []
## Moyennes minimales de vent / d'ensoleillement sur l'emprise (0 : aucune).
@export_range(0.0, 1.0) var min_wind := 0.0
@export_range(0.0, 1.0) var min_sun := 0.0

@export_group("Production")
## Extraction : bois des forêts / gisement dans [member harvest_radius] tuiles
## autour de l'emprise ; REFOREST : la pépinière replante et fait repousser.
@export var extraction: Extraction = Extraction.NONE
@export var harvest_radius := 1
@export var input_good: Goods.Type = Goods.Type.NONE
## Consommation à plein régime (t/h).
@export var input_per_hour := 0.0
@export var output_good: Goods.Type = Goods.Type.NONE
## Production à plein régime (t/h).
@export var output_per_hour := 0.0
## Puissance électrique à plein régime (MW).
@export var power_mw := 0.0
@export var power_source: PowerSource = PowerSource.NONE
## Points de recherche produits par heure (laboratoires).
@export var research_per_hour := 0.0
## Puissance électrique consommée en fonctionnement (MW) : le bâtiment doit
## être raccordé et alimenté par le réseau.
@export var power_demand_mw := 0.0
## Capacité de chaque tampon (entrée et sortie), en tonnes.
@export var buffer_capacity := 20.0

@export_group("Logistique")
## Entrepôt : capacité totale de stockage, toutes marchandises (t).
@export var storage_capacity := 0.0
## Dépôt : nombre maximal de véhicules…
@export var vehicle_slots := 0
## … et leur réseau (dépôt routier ou gare).
@export var vehicle_network: VehicleDef.Network = VehicleDef.Network.ROAD
## Véhicules offerts à la construction (identifiants de VehicleDef).
@export var starting_vehicles: Array[StringName] = []

@export_group("Apparence")
@export var style: Style = Style.BOX
@export var color := Color.GRAY
@export var roof_color := Color.DIM_GRAY
## Hauteur du volume dessiné, en pixels.
@export var height := 24.0
@export var has_chimney := false


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


## Bâtiment qui échange des marchandises par la route ou le rail.
func uses_logistics() -> bool:
	return input_good != Goods.Type.NONE or output_good != Goods.Type.NONE \
		or storage_capacity > 0.0 or vehicle_slots > 0


## Dépôt routier (héberge charrettes et camions).
func is_road_depot() -> bool:
	return vehicle_slots > 0 and vehicle_network == VehicleDef.Network.ROAD


## Gare : point de chargement des trains, qui y sont hébergés.
func is_station() -> bool:
	return vehicle_slots > 0 and vehicle_network == VehicleDef.Network.RAIL


func is_producer() -> bool:
	return extraction != Extraction.NONE or output_good != Goods.Type.NONE or power_mw > 0.0 \
		or research_per_hour > 0.0


## Production à plein régime, une ligne par flux (vide : aucune).
func describe_production() -> PackedStringArray:
	var lines := PackedStringArray()
	if input_good != Goods.Type.NONE:
		lines.append("Consomme : %s t/h de %s" % [_num(input_per_hour), Goods.display_name(input_good).to_lower()])
	if output_good != Goods.Type.NONE:
		lines.append("Produit : %s t/h de %s" % [_num(output_per_hour), Goods.display_name(output_good).to_lower()])
	if power_mw > 0.0:
		var factor := ""
		match power_source:
			PowerSource.WIND:
				factor = " × vent"
			PowerSource.SUN:
				factor = " × ensoleillement"
		lines.append("Électricité : %s MW%s" % [_num(power_mw), factor])
	if research_per_hour > 0.0:
		lines.append("Recherche : %s RP/h" % _num(research_per_hour))
	if power_demand_mw > 0.0:
		lines.append("Consomme : %s MW d'électricité" % _num(power_demand_mw))
	match extraction:
		Extraction.FOREST:
			lines.append("Coupe les forêts à %d tuiles (les épuise)" % harvest_radius)
		Extraction.DEPOSIT:
			lines.append("Exploite le gisement à %d tuile%s" % [harvest_radius, "s" if harvest_radius > 1 else ""])
		Extraction.REFOREST:
			lines.append("Replante et régénère les forêts à %d tuiles" % harvest_radius)
	return lines


static func _num(value: float) -> String:
	return str(roundi(value)) if is_equal_approx(value, roundf(value)) else "%.1f" % value


## Contraintes de placement lisibles, une par ligne (vide : aucune).
func describe_constraints() -> PackedStringArray:
	var lines := PackedStringArray()
	if not allowed_terrains.is_empty():
		var names := PackedStringArray()
		for t in allowed_terrains:
			names.append(TerrainDb.get_def(t).display_name.to_lower())
		lines.append("Sur : " + ", ".join(names))
	if required_deposit != WorldMap.Deposit.NONE:
		lines.append("Sur un gisement de " + WorldMap.DEPOSIT_NAMES[required_deposit].to_lower())
	if needs_road:
		lines.append("Relié à une route")
	if needs_rail:
		lines.append("Relié à une voie ferrée")
	if needs_water_access:
		lines.append("Près de l'eau")
	if needs_coast:
		lines.append("Sur la côte")
	if not adjacent_terrains.is_empty():
		var names := PackedStringArray()
		for t in adjacent_terrains:
			names.append(TerrainDb.get_def(t).display_name.to_lower())
		lines.append("À côté de : " + ", ".join(names))
	if min_wind > 0.0:
		lines.append("Vent ≥ %d %%" % roundi(min_wind * 100.0))
	if min_sun > 0.0:
		lines.append("Ensoleillement ≥ %d %%" % roundi(min_sun * 100.0))
	return lines
