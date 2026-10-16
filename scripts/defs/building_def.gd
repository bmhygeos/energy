class_name BuildingDef
extends Resource
## Définition d'un type de bâtiment : coûts, emprise, contraintes de placement
## et apparence provisoire. Équilibrage dans data/buildings/*.tres.

enum Category { RESOURCES, ENERGY, LOGISTICS, OTHER }
## Ressource naturelle exploitée par un extracteur.
enum Extraction { NONE, FOREST, DEPOSIT, REFOREST }
## Ce qui module la puissance électrique produite.
## SOLAR_THERMAL : la chaleur captée le jour est stockée, puis restituée à la
## demande (pilotable tant que le stock dure).
enum PowerSource { NONE, FUEL, WIND, SUN, SOLAR_THERMAL }
## Forme du dessin provisoire (scenes/world/building_sprite.gd).
enum Style { BOX, TURBINE, PANELS, CITY, REACTOR, SOLAR_TOWER, BASIN, PORT, TOKAMAK }

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
## Construit en mer : toute l'emprise sur la mer, au contact de la terre
## (pour y raccorder une ligne).
@export var on_sea := false
## Une route doit border l'emprise.
@export var needs_road := false
## Une voie ferrée doit border l'emprise.
@export var needs_rail := false
## Une tuile navigable (mer, lac, rivière) doit border l'emprise.
@export var needs_navigable := false
## Un port terminé doit se trouver à moins de ce nombre de tuiles, sur la
## même étendue d'eau (0 : aucun) : desserte des chantiers en mer.
@export var port_range := 0
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
## Seconde marchandise consommée en même temps (réacteur de fusion :
## deutérium + lithium), avec son propre tampon de même capacité.
@export var input2_good: Goods.Type = Goods.Type.NONE
@export var input2_per_hour := 0.0
@export var output_good: Goods.Type = Goods.Type.NONE
## Production à plein régime (t/h).
@export var output_per_hour := 0.0
## Puissance électrique à plein régime (MW).
@export var power_mw := 0.0
@export var power_source: PowerSource = PowerSource.NONE
## Émissions à plein régime (t/h de CO₂ et de particules) : polluent l'air
## alentour et sont taxées.
@export var emission_per_hour := 0.0
## Incidents par an en fonctionnement continu (centrale nucléaire, fusion) :
## nom, arrêt (heures), coût (part du prix) et perte de satisfaction des
## villes voisines.
@export var incident_per_year := 0.0
@export var incident_name := "Incident nucléaire"
@export var incident_hours := 240
@export var incident_cost := 0.1
@export_range(0.0, 1.0) var incident_satisfaction := 0.25
## Points de recherche produits par heure (laboratoires, tokamak).
@export var research_per_hour := 0.0
## Soumis au rendement décroissant des laboratoires (pas le tokamak).
@export var research_diminishing := true
## Montée en puissance (heures de fonctionnement de 10 % à 100 %) après la
## mise en service ou un arrêt forcé (réacteur de fusion).
@export var ramp_up_hours := 0
## Puissance électrique consommée en fonctionnement (MW) : le bâtiment doit
## être raccordé et alimenté par le réseau.
@export var power_demand_mw := 0.0
## Solaire thermique : chaleur captée en plein soleil, en multiple de
## [member power_mw] (surplus stocké pour la nuit).
@export var solar_multiple := 1.0
## Énergie stockable (MWh) : batterie, STEP, réservoir de chaleur.
@export var storage_mwh := 0.0
## Stockage du réseau (batterie, STEP) : puissance maximale de charge et de
## décharge (MW) et rendement d'un cycle complet.
@export var storage_power_mw := 0.0
@export_range(0.0, 1.0) var storage_efficiency := 0.9
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


## Marchandises consommées (une ou deux).
func input_goods() -> Array[int]:
	var goods: Array[int] = []
	if input_good != Goods.Type.NONE:
		goods.append(input_good)
	if input2_good != Goods.Type.NONE:
		goods.append(input2_good)
	return goods


func takes(good: int) -> bool:
	return good != Goods.Type.NONE and (good == input_good or good == input2_good)


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


## Port : point de chargement des barges, qui y sont hébergées.
func is_port() -> bool:
	return vehicle_slots > 0 and vehicle_network == VehicleDef.Network.WATER


## Plateforme (gare ou port) : entrepôt d'où partent trains ou barges vers
## les plateformes du même réseau.
func is_hub() -> bool:
	return vehicle_slots > 0 and vehicle_network != VehicleDef.Network.ROAD


## Stockage du réseau électrique (batterie, STEP).
func is_grid_storage() -> bool:
	return storage_power_mw > 0.0


## Centrale pilotable : le réseau lui fixe une consigne.
## Production renouvelable (vent, soleil), subventionnée.
func is_renewable() -> bool:
	return power_source in [PowerSource.WIND, PowerSource.SUN, PowerSource.SOLAR_THERMAL]


func is_dispatchable() -> bool:
	return power_source in [PowerSource.FUEL, PowerSource.SOLAR_THERMAL]


func is_producer() -> bool:
	return extraction != Extraction.NONE or output_good != Goods.Type.NONE or power_mw > 0.0 \
		or research_per_hour > 0.0


## Production à plein régime, une ligne par flux (vide : aucune).
func describe_production() -> PackedStringArray:
	var lines := PackedStringArray()
	if input_good != Goods.Type.NONE and input_per_hour <= 0.0:
		lines.append("Stocke : %s t de %s" % [_num(buffer_capacity), Goods.display_name(input_good).to_lower()])
	elif input_good != Goods.Type.NONE:
		lines.append("Consomme : %s t/h de %s" % [_num(input_per_hour), Goods.display_name(input_good).to_lower()])
	if input2_good != Goods.Type.NONE:
		lines.append("Consomme : %s t/h de %s" % [_num(input2_per_hour), Goods.display_name(input2_good).to_lower()])
	if output_good != Goods.Type.NONE:
		lines.append("Produit : %s t/h de %s" % [_num(output_per_hour), Goods.display_name(output_good).to_lower()])
	if power_mw > 0.0:
		var factor := ""
		match power_source:
			PowerSource.WIND:
				factor = " × vent"
			PowerSource.SUN:
				factor = " × ensoleillement (nulle la nuit)"
			PowerSource.SOLAR_THERMAL:
				factor = " à la demande"
		lines.append("Électricité : %s MW%s" % [_num(power_mw), factor])
	if power_source == PowerSource.SOLAR_THERMAL:
		lines.append("Stocke la chaleur du jour : %s MWh (nuit comprise)" % _num(storage_mwh))
	if is_grid_storage():
		lines.append("Stocke : %s MWh, charge et décharge %s MW" % [_num(storage_mwh), _num(storage_power_mw)])
		lines.append("Rendement : %d %% (charge les surplus, couvre les manques)" % roundi(storage_efficiency * 100.0))
	if research_per_hour > 0.0:
		lines.append("Recherche : %s RP/h" % _num(research_per_hour))
	if emission_per_hour > 0.0:
		lines.append("Pollue : %s t/h de CO₂ à plein régime" % _num(emission_per_hour))
	if incident_per_year > 0.0:
		lines.append("Risque d'incident : ≈ 1 tous les %s ans de fonctionnement" % _num(1.0 / incident_per_year))
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
	if on_sea:
		lines.append("En mer, au contact de la côte")
	if port_range > 0:
		lines.append("Port à moins de %d tuiles" % port_range)
	if needs_navigable:
		lines.append("Au bord de l'eau navigable (mer, lac, rivière)")
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
