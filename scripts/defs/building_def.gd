class_name BuildingDef
extends Resource
## Définition d'un type de bâtiment de la ville : emprise, chantier,
## contraintes de placement et apparence provisoire. Équilibrage dans
## data/buildings/*.tres.

enum Category { HOUSING, STORAGE, OTHER }
## Carte où il se construit : la ville (logements, ateliers, services) ou le
## monde (ce qui dépend de l'eau, du relief, du vent ou des réseaux).
enum Site { CITY, WORLD }
## Source d'une centrale : eau (barrage), charbon, fioul (carburant), uranium,
## vent (éolienne), soleil (champ solaire).
enum PowerSource { HYDRO, COAL, FUEL, NUCLEAR, WIND, SOLAR, FUSION }

const CATEGORY_NAMES: PackedStringArray = ["Logement", "Stockage", "Divers"]

@export var id: StringName
@export var display_name := ""
@export_multiline var description := ""
@export var category: Category = Category.OTHER
@export var site: Site = Site.CITY
## Proposé dans le menu de construction.
@export var player_buildable := true
## Palier de la ville à partir duquel il se construit (1 : hameau).
@export_range(1, 6) var tier := 1
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
@export var copper_cost := 0
@export var lithium_cost := 0
@export var electronics_cost := 0
## Niveau suivant, construit sur place (grenier → grenier en pierre…).
@export var upgrade: BuildingDef
## Se construit directement au niveau du palier atteint (greniers) : coût de
## base plus celui des améliorations sautées.
@export var build_at_tier := false

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
@export var fuel_capacity := 0.0
@export var copper_capacity := 0.0
## Forge : outils fabriqués par jour (FORGE_IRON_PER_TOOL fer et
## FORGE_WOOD_PER_TOOL bois chacun).
@export var tools_per_day := 0.0
## Atelier de tissage : vêtements tissés par jour (une fibre chacun).
@export var clothes_per_day := 0.0
## Raffinerie : carburant raffiné par jour (un pétrole chacun).
@export var fuel_per_day := 0.0
## Atelier d'artisans : biens variés fabriqués par jour (bois et fer :
## GameState.GOODS_WOOD et GOODS_IRON chacun).
@export var goods_per_day := 0.0
## Dispensaire et poste de garde : habitants soignés, habitants surveillés.
@export var health_coverage := 0
@export var order_coverage := 0
## École, université, théâtre : habitants instruits, habitants qui sortent.
@export var education_coverage := 0
@export var culture_coverage := 0
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
## Centrale : puissance à plein régime (W) et source. Les barrages suivent le
## débit des saisons, les éoliennes le vent, les champs solaires le soleil (de
## jour) ; les centrales brûlent du charbon, du carburant ou de l'uranium
## ou du combustible nucléaire (PowerGrid.WATTS_PER_COAL, WATTS_PER_FUEL,
## WATTS_PER_NUCLEAR_FUEL).
@export var power_watts := 0.0
@export var power_source: PowerSource = PowerSource.HYDRO
## Batteries : énergie stockée de jour, rendue la nuit (kWh par jour).
@export var storage_kwh := 0.0
## Consommation électrique (W) : centre informatique, datacenter ; sans courant,
## à l'arrêt.
@export var power_demand := 0.0
## Cimenterie : ciment cuit par jour (GameState.CEMENT_STONE pierre et
## CEMENT_COAL charbon chacun).
@export var cement_per_day := 0.0
## Usine d'électronique : composants fabriqués par jour (un cuivre chacun).
@export var electronics_per_day := 0.0
## Usine d'enrichissement : combustible nucléaire produit par jour
## (PowerGrid.ENRICH_URANIUM minerais d'uranium chacun ; il lui faut du courant).
@export var nuclear_fuel_per_day := 0.0
## Borne de recharge : à côté d'une route reliée, un dépôt de camions roule à
## l'électricité (véhicules électriques).
@export var charger := false
## Barrage : tuiles noyées en amont à la fin du chantier (la retenue).
@export var flood_tiles := 0
## Dépôt de camions : les routes reliées portent plus loin, contre du carburant.
@export var truck_depot := false
## Avant-poste : relié au village (route, voie ferrée ou aérodrome), il lance
## ses propres expéditions.
@export var outpost := false
## Aérodrome : relie par les airs les avant-postes à AIRFIELD_RANGE tuiles ou
## moins (cité-État).
@export var airfield := false
## Usine de fusées : assemble une fusée (GameState.ROCKET_WORK_DAYS jours de
## fer, d'électronique, de cuivre et de courant).
@export var rocket_factory := false
## Base de lancement : lance les fusées prêtes, contre du carburant.
@export var launch_pad := false
## Port de pêche : les zones de pêche vont jusqu'à ce nombre de tuiles du
## rivage (le plus grand compte).
@export var fishing_reach := 0
## Port : pêche sur toutes les eaux découvertes, expéditions sur l'eau et
## transport entre ports.
@export var harbor := false
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
	values[Stockpile.Good.COPPER] = copper_cost
	values[Stockpile.Good.LITHIUM] = lithium_cost
	values[Stockpile.Good.ELECTRONICS] = electronics_cost
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
	if fuel_per_day > 0.0:
		lines.append("Raffine %s carburant par jour (un pétrole chacun)" % Format.decimal(fuel_per_day))
	if goods_per_day > 0.0:
		lines.append("Fabrique %s biens par jour (bois et fer)" % Format.decimal(goods_per_day))
	if health_coverage > 0:
		lines.append("Soigne %d habitants" % health_coverage)
	if order_coverage > 0:
		lines.append("Garde l'ordre pour %d habitants" % order_coverage)
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
	if power_watts > 0.0:
		var fuel_text := " selon le débit, sans combustible"
		match power_source:
			PowerSource.COAL:
				fuel_text = " pour %s charbon par jour à plein régime" % Format.decimal(power_watts / PowerGrid.WATTS_PER_COAL)
			PowerSource.FUEL:
				fuel_text = " pour %s carburant par jour à plein régime (après le charbon)" % Format.decimal(power_watts / PowerGrid.WATTS_PER_FUEL)
			PowerSource.NUCLEAR:
				fuel_text = " pour %s combustible nucléaire par jour à plein régime" % Format.decimal(power_watts / PowerGrid.WATTS_PER_NUCLEAR_FUEL)
			PowerSource.FUSION:
				fuel_text = " pour %s lithium par jour à plein régime (tritium), sans déchets ni pollution" % Format.decimal(power_watts / PowerGrid.WATTS_PER_LITHIUM)
			PowerSource.WIND:
				fuel_text = " par grand vent ; crêtes et côtes : plein rendement, ailleurs ×%s" % Format.decimal(PowerGrid.SHELTERED_WIND)
			PowerSource.SOLAR:
				fuel_text = " en plein soleil, de jour seulement ; plus près de l'équateur, plus de soleil"
		lines.append("Électricité : %s%s" % [PowerMeter.format(power_watts), fuel_text])
		lines.append("À %d tuiles du centre ou moins, ou raccordé par une ligne électrique" % Labor.FREE_DISTANCE)
	if storage_kwh > 0.0:
		lines.append("Stocke %d kWh : le surplus de jour (soleil, vent, eau) éclaire la nuit" % roundi(storage_kwh))
	if power_demand > 0.0:
		lines.append("Consomme %s d'électricité (sans courant, à l'arrêt)" % PowerMeter.format(power_demand))
	if cement_per_day > 0.0:
		lines.append("Cuit %s ciment par jour (pierre et charbon) ; le ciment remplace la pierre et accélère les chantiers" % Format.decimal(cement_per_day))
	if electronics_per_day > 0.0:
		lines.append("Fabrique %s composants électroniques par jour (un cuivre chacun)" % Format.decimal(electronics_per_day))
	if nuclear_fuel_per_day > 0.0:
		lines.append("Enrichit %s combustible nucléaire par jour (%d uranium chacun)" % [Format.decimal(nuclear_fuel_per_day),
			roundi(PowerGrid.ENRICH_URANIUM)])
	if charger:
		lines.append("Recharge les camions électriques d'un dépôt (à côté d'une route reliée au village)")
	if education_coverage > 0:
		lines.append("Instruit %d habitants" % education_coverage)
	if culture_coverage > 0:
		lines.append("Culture pour %d habitants" % culture_coverage)
	if flood_tiles > 0:
		lines.append("Retenue : noie jusqu'à %d tuiles en amont (rivière et rives basses ; zones, routes et voies effacées)" % flood_tiles)
	if truck_depot:
		lines.append("Camions : à côté d'une route reliée au village, %d tuiles de route sans pénalité, −0,5 %% par tuile ensuite" % RoadNetwork.TRUCK_FREE_TILES)
		lines.append("%d camions : la production de %d travailleurs" % [RoadNetwork.TRUCKS_PER_DEPOT,
			RoadNetwork.TRUCKS_PER_DEPOT * RoadNetwork.PORTERS_PER_TRUCK])
		lines.append("Brûlent %s carburant par jour, plus %s par tuile de route" % [Format.decimal(RoadNetwork.FUEL_PER_DEPOT_PER_DAY),
			Format.decimal(RoadNetwork.FUEL_PER_TILE_PER_DAY, 2)])
	if outpost:
		lines.append("Avant-poste : relié au village par une route, une voie ferrée ou un aérodrome, il lance ses propres expéditions")
	if airfield:
		lines.append("Aérodrome : relie par les airs les avant-postes à %d tuiles ou moins" % Exploration.AIRFIELD_RANGE)
	if rocket_factory:
		lines.append("Assemble une fusée en %d jours de travail (fer, électronique, cuivre ; à l'arrêt sans courant)" % Space.ROCKET_WORK_DAYS)
	if launch_pad:
		lines.append("Lance les fusées prêtes : %d à %d carburant selon la latitude (moins près de l'équateur), ×%s vers l'orbite géostationnaire ; %d %% d'échecs" % [
			roundi(Space.LAUNCH_FUEL_EQUATOR), roundi(Space.LAUNCH_FUEL_POLE), Format.decimal(Space.ORBIT_FUEL[Space.Orbit.GEOSTATIONARY]),
			roundi(Space.FAILURE_CHANCE * 100.0)])
	if fishing_reach > 0:
		lines.append("Pêche jusqu'à %d tuiles du rivage" % fishing_reach)
	if harbor:
		lines.append("Pêche sur toutes les eaux découvertes")
		lines.append("Expéditions sur l'eau, mer comprise (%s tuiles par jour)" % Format.decimal(Exploration.SHIP_TILES_PER_DAY))
		lines.append("Transport : relié par l'eau à un autre port, il rapproche les tuiles autour de lui")
		lines.append("Relié par l'eau (ou comme un avant-poste), il lance ses propres expéditions")
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
		Stockpile.Good.FUEL:
			return fuel_capacity
		Stockpile.Good.COPPER:
			return copper_capacity
	return 0.0
