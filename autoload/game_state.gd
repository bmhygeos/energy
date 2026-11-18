extends Node
## État global de la partie en cours.

## Planète en longitude / latitude (tuiles), multiple de WorldMap.CHUNK_SIZE.
const PLANET_SIZE := Vector2i(1024, 512)
## Palier 6, « Cité des étoiles » : la capitale seule, à la cité-État, avec
## CityTier.STAR_POPULATION habitants, la satisfaction des paliers et un satellite
## en orbite ; sa carte de ville passe à STAR_CITY_SIZE cases de côté.
const STAR_CITY_SIZE := 48
## Fondation d'une ville sur un avant-poste ou un port relié : distance
## minimale (tuiles) à toute autre ville, colons partis de la ville active.
const FOUNDING_DISTANCE := 60
const COLONISTS := 30
## Noms des villes, dans l'ordre de leur fondation.
const CITY_NAMES: PackedStringArray = ["Capitale", "Nouvelle-Rive", "Bellevue", "Portefort", "Hautval", "Sainte-Aube",
	"Clairmont", "Valsec", "Roche-Neuve", "Mirebois"]
## Carte de la ville : plaine (FlatGenerator) dont la partie constructible,
## centrée, grandit avec le palier (côté en cases).
const CITY_MAP_SIZE := Vector2i(64, 64)
const CITY_SIZES: PackedInt32Array = [12, 16, 24, 32, 40]
## Bloc de la ville sur la carte mondiale, par palier (côté en tuiles) : ni
## zone ni bâtiment du monde ; les distances se comptent depuis son bord.
const CITY_BLOCK: PackedInt32Array = [3, 3, 5, 5, 7]
## Identifiants des bâtiments de la ville (distincts de ceux du monde).
const CITY_FIRST_ID := 1_000_000
## Palier à partir duquel les habitants ont besoin d'eau (puits).
const WATER_TIER := 2
## Forge : fer et bois par outil fabriqué.
const FORGE_IRON_PER_TOOL := 1.0
const FORGE_WOOD_PER_TOOL := 0.5
## Durée de vie d'un outil (scie, charrue) en jours de travail d'un habitant.
const TOOL_LIFE_DAYS := 60.0
## Outils : maisons moins chères en bois ; engrenage : puits plus efficaces.
const TOOLS_HOUSE_WOOD := 0.75
## Sylviculture : facteur de la vitesse de repousse des forêts.
const SYLVICULTURE_REGROWTH := 2.0
## Charbon de bois : part du bois coupé du jour transformée, bois par unité de
## charbon, et jours de chauffage d'hiver gardés en bois.
const CHARCOAL_WOOD_SHARE := 0.2
const WOOD_PER_CHARCOAL := 3.0
const CHARCOAL_RESERVE_DAYS := 10.0
const GEARS_WATER_BONUS := 1.15
## Pompe à eau : puits plus efficaces.
const PUMP_WATER_BONUS := 1.5
## Palier à partir duquel les habitants ont besoin de vêtements (bourg).
const CLOTHES_TIER := 3
## Chauffage : sources (HEAT_SHARES), parts du besoin par palier (bois,
## charbon, fioul, électricité ; hameau → cité-État). Une source qui manque
## (stock vide, réseau insuffisant) est remplacée par le charbon et le fioul
## disponibles, au prorata de leurs parts, sinon par le bois.
enum Heat { WOOD, COAL, FUEL, ELECTRICITY }
const HEAT_SOURCES := 4
const HEAT_SHARES: PackedFloat32Array = [
	1.0, 0.0, 0.0, 0.0,
	1.0, 0.0, 0.0, 0.0,
	0.5, 0.5, 0.0, 0.0,
	0.1, 0.4, 0.5, 0.0,
	0.05, 0.15, 0.2, 0.6,
]
## Bois remplacé par unité de charbon (290 MJ contre 150 MJ) et de carburant
## (420 MJ) ; courant (W pendant une journée) qui remplace un bois : pompes à
## chaleur, trois fois l'énergie consommée.
const COAL_WOOD_EQUIVALENT := 2.0
## Isolation par palier : maisons en dur, immeubles, chauffage central ; le
## besoin de chauffage par habitant est multiplié par ce facteur.
const HEAT_INSULATION: PackedFloat32Array = [1.0, 1.0, 0.8, 0.5, 0.4]
## Mécanisation par palier : rendement des mines et des puits sur gisement
## (engins à moteur à la ville, machines électriques à la cité-État).
const MECHANIZATION: PackedFloat32Array = [1.0, 1.0, 1.0, 2.0, 3.0]
const FUEL_WOOD_EQUIVALENT := 2.8
const WATTS_PER_HEAT_WOOD := 290.0
## Pollution : part de sa gêne que les soins évitent (dispensaires).
const CARE_POLLUTION_SHIELD := 0.5
## Coke : les forges brûlent du charbon (COAL_WOOD_EQUIVALENT fois moins que
## de bois) et fabriquent davantage.
const COKE_FORGE_BONUS := 1.5
## Atelier de tissage : fibres par vêtement.
const FIBER_PER_CLOTHES := 1.0
## Palier à partir duquel le gouverneur prend des décrets (bourg).
const DECREES_TIER := 3
## Palier à partir duquel des événements frappent la cité (bourg).
const EVENTS_TIER := 3
## Palier à partir duquel les habitants s'éclairent au carburant (ville).
const LIGHT_TIER := 4
## Palier à partir duquel les habitants veulent des biens variés, des soins
## et de l'ordre (ville).
const SERVICES_TIER := 4
## Palier de la cité-État : éducation, culture et électricité deviennent des
## besoins.
const CITY_STATE_TIER := 5
## Services publics : habitants couverts par les bâtiments.
enum Service { HEALTH, ORDER, EDUCATION, CULTURE }
## Usine d'électronique : cuivre par composant.
const ELECTRONICS_COPPER := 1.0
## Part de la demande d'électricité servie la veille au-dessous de laquelle
## centres informatiques et datacenters s'arrêtent, et camions électriques
## aussi.
const POWERED_COVERAGE := 0.9
const EV_MIN_COVERAGE := 0.5
## Refroidissement des datacenters : part de leur consommation à l'équateur
## gardée aux pôles (le froid refroidit gratuitement).
const POLAR_COOLING := 0.6
## Atelier d'artisans : bois et fer par unité de biens.
const GOODS_WOOD := 1.0
const GOODS_IRON := 0.25
## Tracteurs : carburant par travailleur agricole et par jour.
const TRACTOR_FUEL_PER_WORKER := 0.03
## Cimenterie : pierre et charbon par ciment ; pierres remplacées par un
## ciment ; chantier au ciment : heures gagnées par heure.
const CEMENT_STONE := 1.0
const CEMENT_COAL := 0.25
const STONE_PER_CEMENT := 2.0
const CEMENT_BUILD_SPEED := 2
## Raffinerie : pétrole par unité de carburant.
const OIL_PER_FUEL := 1.0
## Palier à partir duquel la cité pose des routes (bourg).
const ROAD_TIER := 3

var world_map: WorldMap

## Villes de la cité-État ; la ville active (sur laquelle travaillent les
## fonctions et les variables ci-dessous) et la ville choisie par le joueur.
var cities: Array[City] = []
var city: City = City.new()
var selected: City = city

## Variables de la ville active (voir City).
var exploration: Exploration:
	get:
		return city.exploration
	set(value):
		city.exploration = value
var draft: DraftAnimals:
	get:
		return city.draft
	set(value):
		city.draft = value
var home: Vector2i:
	get:
		return city.home
	set(value):
		city.home = value
var buildings: BuildingRegistry:
	get:
		return city.buildings
	set(value):
		city.buildings = value
var city_map: WorldMap:
	get:
		return city.city_map
	set(value):
		city.city_map = value
var city_territory: Territory:
	get:
		return city.city_territory
	set(value):
		city.city_territory = value
var city_buildings: BuildingRegistry:
	get:
		return city.city_buildings
	set(value):
		city.city_buildings = value
var rails: RailNetwork:
	get:
		return city.rails
	set(value):
		city.rails = value
var roads: RoadNetwork:
	get:
		return city.roads
	set(value):
		city.roads = value
var ports: PortNetwork:
	get:
		return city.ports
	set(value):
		city.ports = value
var grid: PowerGrid:
	get:
		return city.grid
	set(value):
		city.grid = value
var canals: CanalNetwork:
	get:
		return city.canals
	set(value):
		city.canals = value
var zones: ZoneMap:
	get:
		return city.zones
	set(value):
		city.zones = value
var population: Population:
	get:
		return city.population
	set(value):
		city.population = value
var labor: Labor:
	get:
		return city.labor
	set(value):
		city.labor = value
var stockpile: Stockpile:
	get:
		return city.stockpile
	set(value):
		city.stockpile = value
var production: Production:
	get:
		return city.production
	set(value):
		city.production = value
var housing: int:
	get:
		return city.housing
	set(value):
		city.housing = value
var water_supply: int:
	get:
		return city.water_supply
	set(value):
		city.water_supply = value
var coal_burned_today: float:
	get:
		return city.coal_burned_today
	set(value):
		city.coal_burned_today = value
var fuel_burned_today: float:
	get:
		return city.fuel_burned_today
	set(value):
		city.fuel_burned_today = value
var wood_burned_today: float:
	get:
		return city.wood_burned_today
	set(value):
		city.wood_burned_today = value
var pollution: Pollution:
	get:
		return city.pollution
	set(value):
		city.pollution = value
var steam_running: bool:
	get:
		return city.steam_running
	set(value):
		city.steam_running = value
var _steam_drive: float:
	get:
		return city.steam_drive
	set(value):
		city.steam_drive = value
var _steam_mine: float:
	get:
		return city.steam_mine
	set(value):
		city.steam_mine = value
var _water_drive: float:
	get:
		return city.water_drive
	set(value):
		city.water_drive = value
var _needed_today: PackedFloat32Array:
	get:
		return city.needed_today
	set(value):
		city.needed_today = value
var _consumed_today: PackedFloat32Array:
	get:
		return city.consumed_today
	set(value):
		city.consumed_today = value
var expedition_origin: int:
	get:
		return city.expedition_origin
	set(value):
		city.expedition_origin = value
## État des tuiles (inconnue, explorée, territoire) et gisements prospectés.
var territory: Territory
var research: Research
## Carte affichée : la ville (vrai) ou le monde.
var view_city := false
## Palier de la ville (Hameau → Cité-État).
var tier: CityTier
var power: PowerMeter
var weather: Weather
## Décrets du gouverneur (bourg).
var decrees: Decrees
## Événements en cours (hiver rude, sécheresse…).
var events: CityEvents
## Historique journalier (graphiques) et jalons du bac à sable.
var stats: Statistics
var milestones: Milestones
## Fusées, lancements et satellites (recherche Fusée).
var space: Space


func _ready() -> void:
	EventBus.tick_advanced.connect(_on_tick)
	EventBus.day_changed.connect(_on_day)
	new_game(random_seed())


func new_game(seed_value: int, size: Vector2i = PLANET_SIZE) -> void:
	Rng.set_seed(seed_value)
	world_map = WorldMap.new(size, seed_value)
	var start := StartSite.find(world_map.generator)
	var rect := StartSite.territory_rect(start)
	StartSite.ensure(world_map, rect)
	territory = Territory.new(world_map)
	tier = CityTier.new()
	research = Research.new()
	power = PowerMeter.new()
	weather = Weather.new(seed_value)
	decrees = Decrees.new()
	events = CityEvents.new(seed_value)
	stats = Statistics.new()
	milestones = Milestones.new()
	milestones.defs = Milestones.standard()
	space = Space.new(seed_value)
	view_city = false
	cities = []
	_city_groups = []
	var capital := _new_city(start, CITY_NAMES[0])
	selected = capital
	activate(capital)
	GameClock.reset()
	_found_village()
	_refresh_capacities()
	_update_auto_priorities(0)
	_step_labor(GameClock.tick)
	EventBus.game_started.emit(seed_value)


## Crée une ville centrée sur [param center] (tuile ramenée sur la planète),
## avec son territoire de départ (TERRITORY_SIZE tuiles de côté, pris aux
## autres villes s'il le faut), ses réseaux, ses zones, ses habitants et sa
## carte ; elle devient la ville active.
func _new_city(center: Vector2i, city_name: String) -> City:
	var c := City.new()
	c.id = cities.size()
	c.name = city_name
	cities.append(c)
	activate(c)
	home = center
	var rect := StartSite.territory_rect(center)
	var cells: Array[Vector2i] = []
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			cells.append(world_map.wrap_cell(Vector2i(x, y)))
	territory.transfer(cells, c.id)
	exploration = Exploration.new(territory)
	exploration.tier = tier.level
	buildings = BuildingRegistry.new(world_map, territory)
	buildings.block_center = center
	buildings.start_ids(c.id * 10_000_000 + 1)
	city_map = WorldMap.new(CITY_MAP_SIZE, 0, FlatGenerator.new(CITY_MAP_SIZE))
	city_territory = Territory.new(city_map)
	city_buildings = BuildingRegistry.new(city_map, city_territory)
	city_buildings.start_ids(c.id * 10_000_000 + CITY_FIRST_ID)
	expedition_origin = 0
	zones = ZoneMap.new(world_map, territory, buildings)
	rails = RailNetwork.new(world_map, territory, buildings, center)
	rails.zones = zones
	buildings.rails = rails
	roads = RoadNetwork.new(world_map, territory, buildings, center)
	roads.zones = zones
	buildings.roads = roads
	grid = PowerGrid.new(world_map, territory, buildings, center)
	grid.zones = zones
	buildings.lines = grid
	canals = CanalNetwork.new(world_map, territory, buildings, center)
	canals.zones = zones
	buildings.canals = canals
	population = Population.new()
	population.active_share = Population.ACTIVE_SHARE + decrees.active_bonus()
	labor = Labor.new(zones, center)
	labor.rails = rails
	labor.roads = roads
	ports = PortNetwork.new(world_map, territory)
	labor.ports = ports
	stockpile = Stockpile.new()
	production = Production.new(zones, labor)
	production.research = research
	production.canals = canals
	draft = DraftAnimals.new()
	production.draft = draft
	production.events = events
	_needed_today = Stockpile.zeros()
	_consumed_today = Stockpile.zeros()
	pollution = Pollution.new()
	_refresh_city_area()
	return c


## Ce qui empêche de fonder une ville sur l'avant-poste ou le port [param b]
## de la ville active (vide : possible).
func founding_error(b: Building) -> String:
	if b == null or not (b.def.outpost or b.def.harbor):
		return "Seul un avant-poste ou un port peut devenir une ville"
	if b not in buildings.all():
		return "Choisissez la ville à laquelle il appartient"
	if outpost_link(b).is_empty():
		return "%s non relié : une route, une voie ferrée, l'eau ou un aérodrome doit le relier" % b.def.display_name
	var center := world_map.wrap_cell(b.anchor)
	for c in cities:
		var d := rails.cheb(center, c.home)
		if d < FOUNDING_DISTANCE:
			return "Trop près de %s (%d tuiles ; au moins %d)" % [c.name, d, FOUNDING_DISTANCE]
	if population.count < COLONISTS + Population.START:
		return "Il faut %d habitants à %s pour envoyer %d colons" % [COLONISTS + Population.START, city.name, COLONISTS]
	for good in [Stockpile.Good.FOOD, Stockpile.Good.WOOD]:
		if not stockpile.has(good, Stockpile.START[good]):
			return "%s insuffisant%s pour les colons (%d requis)" % [Stockpile.GOOD_NAMES[good], Stockpile.GOOD_AGREEMENT[good],
				roundi(Stockpile.START[good])]
	return ""


## Nom de la prochaine ville (« Port-… » pour une ville portuaire).
func founding_name(b: Building) -> String:
	var n := CITY_NAMES[cities.size() % CITY_NAMES.size()]
	return ("Port-%s" % n) if b.def.harbor else n


## Fonde une ville sur l'avant-poste ou le port [param b] de la ville active :
## COLONISTS habitants partent avec des vivres et du bois ; l'avant-poste
## devient le centre de la ville, un port reste celui de la ville portuaire.
## Renvoie la ville (null, raison notifiée, si c'est impossible).
func found_city(b: Building) -> City:
	var error := founding_error(b)
	if not error.is_empty():
		EventBus.notified.emit(error)
		return null
	var founder := city
	population.count -= COLONISTS
	for good in [Stockpile.Good.FOOD, Stockpile.Good.WOOD]:
		stockpile.take(good, Stockpile.START[good])
	buildings.remove(b)
	EventBus.building_removed.emit(b)
	var harbor := b.def.harbor
	var c := _new_city(world_map.wrap_cell(b.anchor), founding_name(b))
	population.count = COLONISTS
	if harbor:
		buildings.adopt(b)
	_found_village(COLONISTS)
	_refresh_capacities()
	_update_auto_priorities(GameClock.tick)
	_step_labor(GameClock.tick)
	activate(founder)
	_refresh_capacities()
	_update_labor()
	_link_cities()
	EventBus.territory_changed.emit()
	EventBus.cities_changed.emit()
	EventBus.population_changed.emit()
	EventBus.stocks_changed.emit()
	EventBus.notified.emit("%s est fondée : %d colons partent de %s" % [c.name, COLONISTS, founder.name])
	return c


## Bâtiments de départ, déjà construits au centre de la carte de la ville :
## un grenier et assez de maisons pour les habitants.
func _found_village(settlers := Population.START) -> void:
	var defs: Array[BuildingDef] = [BuildingDb.get_def(&"granary")]
	for k in ceili(float(settlers) / BuildingDb.get_def(&"house").housing):
		defs.append(BuildingDb.get_def(&"house"))
	for def in defs:
		var b := city_buildings.place(city_buildings.check_placement(def, free_city_spot(def)))
		b.build_progress = def.build_hours
		b.status = Building.Status.RUNNING


## Centre de la carte de la ville.
func city_center() -> Vector2i:
	return CITY_MAP_SIZE / 2


## Emplacement libre le plus proche du centre de la ville pour [param def]
## ((-1, -1) : aucun).
func free_city_spot(def: BuildingDef) -> Vector2i:
	var center := city_center()
	for r in CITY_SIZES[CITY_SIZES.size() - 1] / 2 + 1:
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) == r and city_buildings.check_placement(def, center + Vector2i(dx, dy)).is_valid():
					return center + Vector2i(dx, dy)
	return Vector2i(-1, -1)


## Agrandit la ville au palier atteint : cases constructibles de la carte de
## la ville, bloc de la ville sur la carte mondiale (les zones qui s'y
## trouvaient sont effacées).
func _refresh_city_area() -> void:
	var side := STAR_CITY_SIZE if city.star else CITY_SIZES[clampi(tier.level, 1, CITY_SIZES.size()) - 1]
	var origin := city_center() - Vector2i.ONE * (side / 2)
	var cells: Array[Vector2i] = []
	for y in side:
		for x in side:
			cells.append(origin + Vector2i(x, y))
	city_territory.annex(cells)
	var radius := CITY_BLOCK[clampi(tier.level, 1, CITY_BLOCK.size()) - 1] / 2
	buildings.block_radius = radius
	labor.city_radius = radius
	var block: Array[Vector2i] = []
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			block.append(world_map.wrap_cell(home + Vector2i(dx, dy)))
	var cleared := zones.clear(block)
	if not cleared.is_empty():
		var shown: Array[Vector2i] = []
		for c in cleared:
			shown.append(display_cell(c))
		EventBus.zones_changed.emit(shown)
	EventBus.city_changed.emit()


## Tous les bâtiments, du monde et de la ville (effets, statistiques).
func all_buildings() -> Array[Building]:
	var result: Array[Building] = buildings.all()
	result.append_array(city_buildings.all())
	return result


## Bâtiment affiché en [param cell] : sur la carte de la ville, celui de la
## ville choisie ; sur la carte mondiale, celui de n'importe quelle ville.
func shown_building_at(cell: Vector2i) -> Building:
	if view_city:
		return selected.city_buildings.building_at(cell)
	for c in cities:
		var b := c.buildings.building_at(cell)
		if b:
			return b
	return null


## Registre, carte et territoire de la carte affichée.
func view_buildings() -> BuildingRegistry:
	return city_buildings if view_city else buildings


func view_map() -> WorldMap:
	return city_map if view_city else world_map


func view_territory() -> Territory:
	return city_territory if view_city else territory


## Registre où se construit [param def].
func registry_for(def: BuildingDef) -> BuildingRegistry:
	return city_buildings if def.site == BuildingDef.Site.CITY else buildings


## Affiche la carte de la ville ([param city] vrai) ou la carte mondiale.
func set_view(city: bool) -> void:
	if city == view_city:
		return
	view_city = city
	EventBus.view_changed.emit()


## Tuile gardée pour les carrières (colline, montagne) ou les mines
## (gisement) du village, où ne pas poser les bâtiments de départ.
func _reserved_at_start(cell: Vector2i) -> bool:
	return world_map.get_terrain(cell) in [TerrainDef.Type.HILL, TerrainDef.Type.MOUNTAIN] \
		or world_map.get_deposit(cell) != WorldMap.Deposit.NONE


## Tuile [param cell] dans le repère de la vue : abscisse dépliée autour du
## village et décalée d'un tour de planète, donc toujours positive (les
## tuiles (-1, -1) restent libres pour dire « aucune tuile »).
func display_cell(cell: Vector2i) -> Vector2i:
	var capital := cities[0].home if not cities.is_empty() else home
	return world_map.unwrap_near(cell, capital.x + world_map.size.x)


## Graine aléatoire lisible (6 chiffres).
static func random_seed() -> int:
	return randi_range(100_000, 999_999)


## Niveau construit pour [param def] : un bâtiment qui se construit au niveau
## du palier (grenier) monte sa chaîne d'améliorations tant que le palier et
## les recherches le permettent ; les autres restent tels quels.
func build_level(def: BuildingDef) -> BuildingDef:
	var level := def
	if not def.build_at_tier or tier == null:
		return level
	while level.upgrade and level.upgrade.tier <= tier.level \
			and (not level.upgrade.research or research.is_done(level.upgrade.research)):
		level = level.upgrade
	return level


## Coût de construction de [param def] : celui du niveau de base, plus celui
## des améliorations sautées pour arriver au niveau du palier (build_level).
func build_costs(def: BuildingDef) -> PackedFloat32Array:
	var total := costs_of(def)
	var level := def
	var target := build_level(def)
	while level != target:
		level = level.upgrade
		var step := costs_of(level)
		for good in Stockpile.COUNT:
			total[good] += step[good]
	return with_cement(total)


## [param values] avec la pierre remplacée par du ciment (recherche
## Cimenterie), s'il y en a assez en stock ; sinon inchangé.
func with_cement(values: PackedFloat32Array) -> PackedFloat32Array:
	var stone := values[Stockpile.Good.STONE]
	if stone <= 0.0 or research == null or not research.is_done(&"cement"):
		return values
	var cement := ceilf(stone / STONE_PER_CEMENT)
	if not stockpile.has(Stockpile.Good.CEMENT, cement + values[Stockpile.Good.CEMENT]):
		return values
	var result := values.duplicate()
	result[Stockpile.Good.STONE] = 0.0
	result[Stockpile.Good.CEMENT] += cement
	return result


## Placement de [param def] (à son niveau construit, build_level) en
## [param anchor] : palier atteint, règles du registre, pas sur une zone (à
## effacer d'abord) et assez de matériaux.
func check_placement(def: BuildingDef, anchor: Vector2i) -> BuildingRegistry.Placement:
	var costs := build_costs(def)
	def = build_level(def)
	var registry := registry_for(def)
	var placement := registry.check_placement(def, anchor)
	if placement.is_valid() and def.tier > city_level():
		placement.error = "Disponible au palier %s" % CityTier.label(def.tier)
	if placement.is_valid() and def.research and not research.is_done(def.research):
		placement.error = "Recherche requise : %s" % ResearchDb.get_def(def.research).display_name
	for good in costs.size():
		if placement.is_valid() and not stockpile.has(good, costs[good]):
			placement.error = "%s insuffisant%s (%d requis)" % [Stockpile.GOOD_NAMES[good],
				Stockpile.GOOD_AGREEMENT[good], roundi(costs[good])]
	if placement.is_valid() and registry == buildings:
		for cell in placement.cells:
			var zone := zones.zone_at(cell)
			if zone:
				placement.error = "Zone présente (%s) : effacez-la d'abord" % zone.display_name
				break
	return placement


## Coût de [param def] avec les inventions (outils : maisons −25 % de bois).
func costs_of(def: BuildingDef) -> PackedFloat32Array:
	var values := def.costs()
	if def.category == BuildingDef.Category.HOUSING and research and research.is_done(&"tools"):
		values[Stockpile.Good.WOOD] = ceilf(values[Stockpile.Good.WOOD] * TOOLS_HOUSE_WOOD)
	return values


## Aperçu de la peinture de [param def] (null : effacement) entre deux tuiles.
func plan_zones(def: ZoneDef, from: Vector2i, to: Vector2i) -> ZoneMap.Plan:
	var plan := zones.plan(def, ZoneMap.rect_between(from, to))
	if def and def.tier > tier.level:
		plan.refused += plan.changed.size()
		plan.changed.clear()
		plan.error = "Disponible au palier %s" % CityTier.label(def.tier)
	return plan


## Peint ou efface selon [param plan] ; renvoie le nombre de tuiles changées.
func apply_zones(plan: ZoneMap.Plan) -> int:
	var changed := zones.apply(plan)
	if changed.is_empty() and plan.def and not plan.error.is_empty():
		EventBus.notified.emit(plan.error)
	if not changed.is_empty():
		# Les camions se répartissent entre les tuiles zonées.
		if roads.has_trucks():
			roads.refresh()
		EventBus.zones_changed.emit(changed)
		_update_labor()
	return changed.size()


## Priorité (0–5 ou Labor.AUTO) du type de zone [param def].
func set_priority(def: ZoneDef, priority: int) -> void:
	labor.priorities[def] = priority
	_update_labor()


## Affectation des travailleurs à l'heure [param tick], puis attelage des
## chevaux aux tuiles travaillées les plus lointaines.
func _step_labor(tick: int) -> void:
	labor.step(tick, workers())
	draft.harness(labor.workers_at, labor.distance)


func _update_labor() -> void:
	_step_labor(GameClock.tick)
	EventBus.labor_changed.emit()


## Lance le chantier de [param def] en [param anchor] ; renvoie le bâtiment,
## ou null (raison notifiée) si le placement est invalide.
func build(def: BuildingDef, anchor: Vector2i) -> Building:
	var placement := check_placement(def, anchor)
	if not placement.is_valid():
		EventBus.notified.emit(placement.error)
		return null
	var costs := build_costs(def)
	for good in costs.size():
		stockpile.take(good, costs[good])
	var b := registry_for(def).place(placement)
	# Chantier au ciment : deux fois plus rapide.
	if costs[Stockpile.Good.CEMENT] > 0.0:
		b.speed = CEMENT_BUILD_SPEED
	if not placement.cleared.is_empty():
		EventBus.tiles_changed.emit(placement.cleared)
	EventBus.building_placed.emit(b)
	EventBus.stocks_changed.emit()
	return b


## Ce qui empêche d'améliorer [param b] (vide : possible).
func upgrade_error(b: Building) -> String:
	if b == null:
		return "Aucun bâtiment ici"
	if b.def.outpost or (b.def.harbor and b.def.upgrade == null):
		return founding_error(b)
	var next := b.def.upgrade
	if next == null:
		return "%s : pas d'amélioration" % b.def.display_name
	if not b.is_complete():
		return "Chantier en cours"
	if next.tier > city_level():
		return "%s : au palier %s" % [next.display_name, CityTier.label(next.tier)]
	if next.research and not research.is_done(next.research):
		return "Recherche requise : %s" % ResearchDb.get_def(next.research).display_name
	var costs := with_cement(costs_of(next))
	for good in costs.size():
		if not stockpile.has(good, costs[good]):
			return "%s insuffisant%s (%d requis)" % [Stockpile.GOOD_NAMES[good],
				Stockpile.GOOD_AGREEMENT[good], roundi(costs[good])]
	return ""


## Améliore le bâtiment présent en [param cell] sur la carte affichée
## (chantier sur place) ; false (raison notifiée) si c'est impossible.
func upgrade(cell: Vector2i) -> bool:
	return upgrade_building(view_buildings().building_at(cell))


## Améliore [param b] (chantier sur place) ; false (raison notifiée) si c'est
## impossible.
func upgrade_building(b: Building) -> bool:
	var error := upgrade_error(b)
	if not error.is_empty():
		EventBus.notified.emit(error)
		return false
	if b.def.outpost or b.def.harbor:
		return found_city(b) != null
	var next := b.def.upgrade
	var costs := with_cement(costs_of(next))
	for good in costs.size():
		stockpile.take(good, costs[good])
	EventBus.building_removed.emit(b)
	b.start_upgrade(next)
	if costs[Stockpile.Good.CEMENT] > 0.0:
		b.speed = CEMENT_BUILD_SPEED
	EventBus.building_placed.emit(b)
	EventBus.stocks_changed.emit()
	EventBus.notified.emit("Amélioration lancée : %s" % next.display_name)
	return true


## Démolit le bâtiment présent en [param cell], sinon la voie ferrée, sinon la
## route ; false s'il n'y a rien.
func demolish(cell: Vector2i) -> bool:
	var b := view_buildings().building_at(cell)
	if b == null and view_city:
		return false
	if b == null:
		if rails.remove(cell):
			EventBus.rails_changed.emit([cell] as Array[Vector2i])
			_refresh_rails()
		elif roads.remove(cell):
			roads.refresh()
			EventBus.roads_changed.emit([cell] as Array[Vector2i])
		elif grid.remove(cell):
			_refresh_grid()
			EventBus.grid_changed.emit([cell] as Array[Vector2i])
		elif canals.remove(cell):
			_refresh_canals()
			EventBus.canals_changed.emit([cell] as Array[Vector2i])
		else:
			return false
		_update_labor()
		return true
	registry_for(b.def).remove(b)
	_refresh_capacities()
	EventBus.building_removed.emit(b)
	return true


## Logements et capacités de stockage des bâtiments terminés.
func _refresh_capacities() -> void:
	housing = 0
	water_supply = 0
	var horse_capacity := 0
	var capacity := Stockpile.BASE_CAPACITY.duplicate()
	for b in all_buildings():
		# Pendant une amélioration, l'ancien niveau reste en service.
		var d := b.effective_def()
		if d:
			housing += d.housing
			water_supply += d.water_supply
			horse_capacity += d.horse_capacity
			for good in Stockpile.COUNT:
				capacity[good] += d.capacity_of(good)
	stockpile.capacity = capacity
	draft.capacity = horse_capacity
	var water_factor := 1.0
	if research.is_done(&"gears"):
		water_factor *= GEARS_WATER_BONUS
	if research.is_done(&"water_pump"):
		water_factor *= PUMP_WATER_BONUS
	water_supply = roundi(water_supply * water_factor)
	var mill := 0.0
	var sawmill := 0.0
	var drive := 0.0
	var steam_drive := 0.0
	var steam_mine := 0.0
	var wells: Array[Vector2i] = []
	for b in all_buildings():
		if b.is_complete() and b.def.grinds_grain:
			mill = maxf(mill, b.def.grain_bonus)
		if b.is_complete():
			sawmill = maxf(sawmill, b.def.forestry_bonus)
			if b.def.coal_per_day > 0.0:
				steam_drive = maxf(steam_drive, b.def.drive_bonus)
				steam_mine = maxf(steam_mine, b.def.mine_bonus)
			else:
				drive = maxf(drive, b.def.drive_bonus)
		if b.is_complete() and b.def.water_supply > 0:
			for c in b.cells:
				wells.append(world_map.wrap_cell(c))
	production.wells = wells
	_refresh_canals()
	production.sawmill_bonus = sawmill
	production.mill_bonus = mill
	_water_drive = drive
	_steam_drive = steam_drive
	_steam_mine = steam_mine
	_apply_steam()
	_refresh_rails()
	_refresh_ports()
	_refresh_grid()
	_refresh_trucks()
	production.wool = tier.level >= CLOTHES_TIER
	stockpile.spoilage_factor = 0.5 if mill > 0.0 else 1.0
	draft.collar = research.is_done(&"harness_collar")
	production.regrowth_factor = SYLVICULTURE_REGROWTH if research.is_done(&"sylviculture") else 1.0
	roads.electric = research.is_done(&"electric_vehicle")
	production.mechanization = MECHANIZATION[clampi(tier.level, 1, MECHANIZATION.size()) - 1]


## Bonus des machines (moulin à eau ; machines à vapeur si alimentées).
func _apply_steam() -> void:
	production.drive_bonus = maxf(_water_drive, _steam_drive if steam_running else 0.0)
	production.mine_bonus = _steam_mine if steam_running else 0.0


## Charbon brûlé par jour par les machines à vapeur terminées.
func steam_coal_need() -> float:
	var total := 0.0
	for b in all_buildings():
		if b.is_complete():
			total += b.def.coal_per_day
	return total


## Machines à vapeur : brûlent leur charbon du jour s'il y en a assez,
## sinon elles s'arrêtent (bonus perdus jusqu'au lendemain).
func _run_steam() -> void:
	var need := steam_coal_need()
	var was := steam_running
	steam_running = need > 0.0 and stockpile.has(Stockpile.Good.COAL, need)
	if steam_running:
		coal_burned_today += stockpile.take(Stockpile.Good.COAL, need)
	elif was and need > 0.0:
		EventBus.notified.emit("Plus de charbon : les machines à vapeur s'arrêtent")
	_apply_steam()


## Dépôts de camions terminés ; les routes en tiennent compte.
func _refresh_trucks() -> void:
	roads.depots.clear()
	roads.chargers.clear()
	for b in all_buildings():
		if b.is_complete() and b.def.truck_depot:
			roads.depots.append(b)
		if b.is_complete() and b.def.charger:
			roads.chargers.append(b)
	roads.refresh()
	EventBus.roads_changed.emit([] as Array[Vector2i])


## Lignes reliées et centrales raccordées d'après les bâtiments terminés.
func _refresh_grid() -> void:
	var plants: Array[Building] = []
	for b in all_buildings():
		if b.is_complete() and (b.def.power_watts > 0.0 or b.def.storage_kwh > 0.0):
			plants.append(b)
	grid.refresh(plants)
	EventBus.grid_changed.emit([] as Array[Vector2i])


## Électricité du jour [param day_tick] : vent et soleil moyens de la journée,
## machines branchées, puis bilan (eau, vent, soleil, batteries, uranium,
## charbon, fioul).
func _run_grid(day_tick: int) -> void:
	var season := GameDate.season(day_tick)
	var first := day_tick - GameDate.hour_of_day(day_tick)
	var wind := 0.0
	var sun := 0.0
	for h in GameDate.HOURS_PER_DAY:
		wind += weather.wind_at(first + h)
		sun += weather.sun_at(first + h)
	grid.wind = wind / GameDate.HOURS_PER_DAY
	grid.sun = sun / GameDate.HOURS_PER_DAY
	grid.day_share = Weather.DAY_LENGTH[season] / GameDate.HOURS_PER_DAY
	grid.machine_demand = machine_demand()
	grid.heat_demand = electric_heat_watts(season)
	grid.nuclear_stopped = events.is_active(CityEvents.Kind.NUCLEAR_INCIDENT)
	var burnt := grid.run_day(population.count, season, stockpile.amount[Stockpile.Good.COAL],
		stockpile.amount[Stockpile.Good.FUEL], stockpile.amount[Stockpile.Good.NUCLEAR_FUEL],
		stockpile.amount[Stockpile.Good.LITHIUM])
	stockpile.take(Stockpile.Good.LITHIUM, grid.lithium_burnt)
	coal_burned_today += stockpile.take(Stockpile.Good.COAL, burnt)
	fuel_burned_today += stockpile.take(Stockpile.Good.FUEL, grid.fuel_burnt)
	stockpile.take(Stockpile.Good.NUCLEAR_FUEL, grid.nuclear_fuel_burnt)


## Courant demandé par les machines (W) : centres informatiques et datacenters
## (moins aux latitudes froides pour ceux qu'il faut refroidir), camions
## électriques.
func machine_demand() -> float:
	var total := roads.electric_watts()
	var cooling := lerpf(POLAR_COOLING, 1.0, cos(deg_to_rad(world_map.latitude(home.y))))
	for b in all_buildings():
		if b.is_complete() and b.def.power_demand > 0.0:
			total += b.def.power_demand * (cooling if b.def.needs_water_access else 1.0)
	return total


## Les machines électriques tournent (assez de courant la veille).
func machines_powered() -> bool:
	return grid.coverage >= POWERED_COVERAGE


## Retenue du barrage [param b] : la rivière en amont (tuiles de rivière qui
## touchent le barrage, puis celles qui ne descendent pas en dessous de la plus
## haute d'entre elles) devient un lac, puis les rives les plus basses autour,
## jusqu'à flood_tiles tuiles du territoire sans bâtiment. Zones, routes, voies
## et lignes noyées disparaissent. Renvoie les tuiles noyées (repère de la vue).
func flood_reservoir(b: Building) -> Array[Vector2i]:
	var limit := b.def.flood_tiles
	var dam_cells: Array[Vector2i] = []
	for c in b.cells:
		dam_cells.append(world_map.wrap_cell(c))
	var start: Array[Vector2i] = []
	var level := -INF
	for c in dam_cells:
		for o in WorldMap.NEIGHBORS_4:
			var n := world_map.wrap_cell(c + o)
			if world_map.get_terrain(n) == TerrainDef.Type.RIVER and n not in start:
				start.append(n)
				level = maxf(level, world_map.get_elevation(n))
	# Rivière en amont : parcours le long du lit, sans redescendre sous la retenue.
	var river: Array[Vector2i] = []
	var queue := start.filter(func(c: Vector2i) -> bool: return world_map.get_elevation(c) >= level)
	while not queue.is_empty() and river.size() < limit:
		var cell: Vector2i = queue.pop_front()
		if cell in river or not _floodable(cell, dam_cells):
			continue
		river.append(cell)
		for o in WorldMap.NEIGHBORS_4:
			var n := world_map.wrap_cell(cell + o)
			if world_map.get_terrain(n) == TerrainDef.Type.RIVER and world_map.get_elevation(n) >= level and n not in river:
				queue.append(n)
	# Rives : les plus basses autour du lit noyé.
	var banks: Array[Vector2i] = []
	for cell in river:
		for o in WorldMap.NEIGHBORS_4:
			var n := world_map.wrap_cell(cell + o)
			if not world_map.is_water(n) and n not in banks and _floodable(n, dam_cells):
				banks.append(n)
	banks.sort_custom(func(a: Vector2i, c: Vector2i) -> bool:
		return world_map.get_elevation(a) < world_map.get_elevation(c))
	var flooded: Array[Vector2i] = river.duplicate()
	flooded.append_array(banks.slice(0, maxi(0, limit - river.size())))
	var shown: Array[Vector2i] = []
	for cell in flooded:
		world_map.set_terrain(cell, TerrainDef.Type.LAKE)
		world_map.set_wood(cell, 0.0)
		rails.remove(cell)
		roads.remove(cell)
		grid.remove(cell)
		canals.remove(cell)
		shown.append(display_cell(cell))
	if flooded.is_empty():
		return shown
	zones.clear(flooded)
	roads.refresh()
	_refresh_rails()
	_refresh_grid()
	_refresh_ports()
	_refresh_canals()
	EventBus.tiles_changed.emit(shown)
	EventBus.zones_changed.emit(shown)
	EventBus.rails_changed.emit(shown)
	EventBus.roads_changed.emit(shown)
	_update_labor()
	EventBus.notified.emit("Le barrage est en eau : %d tuile%s noyée%s en amont" % [
		flooded.size(), "s" if flooded.size() > 1 else "", "s" if flooded.size() > 1 else ""])
	return shown


## Tuile que la retenue peut noyer : dans le territoire, ni le barrage ni un
## autre bâtiment.
func _floodable(cell: Vector2i, dam_cells: Array[Vector2i]) -> bool:
	return territory.is_territory(cell) and cell not in dam_cells and buildings.building_at(display_cell(cell)) == null


## Portée de la pêche, navires des expéditions et liaisons entre les ports
## terminés.
func _refresh_ports() -> void:
	var harbors: Array[Building] = []
	var reach := ZoneMap.SHORE_REACH
	for b in all_buildings():
		var def := b.effective_def()
		if def:
			reach = maxi(reach, def.fishing_reach)
			if def.harbor:
				harbors.append(b)
	zones.water_reach = reach if harbors.is_empty() else ZoneMap.ALL_WATERS
	exploration.ships = not harbors.is_empty()
	ports.refresh(harbors, labor.land_distance)


## Gares desservies d'après les voies et les gares terminées.
func _refresh_rails() -> void:
	var stations: Array[Building] = []
	for b in all_buildings():
		if b.is_complete() and b.def.station:
			stations.append(b)
	var before := rails.served.duplicate()
	rails.refresh(stations)
	if rails.served != before:
		EventBus.rails_changed.emit([] as Array[Vector2i])


## Convois : brûlent leur charbon du jour s'il y en a assez, sinon ils
## s'arrêtent (gares sans effet jusqu'au lendemain).
func _run_trains() -> void:
	var need := rails.coal_need()
	var was := rails.running
	rails.running = need <= 0.0 or stockpile.has(Stockpile.Good.COAL, need)
	if need > 0.0 and rails.running:
		coal_burned_today += stockpile.take(Stockpile.Good.COAL, need)
	if was and not rails.running:
		EventBus.notified.emit("Plus de charbon : les trains s'arrêtent")
	if was != rails.running:
		EventBus.rails_changed.emit([] as Array[Vector2i])


## Camions : brûlent leur carburant du jour s'il y en a assez, sinon ils
## s'arrêtent (les routes retrouvent leur portée de charrette).
func _run_trucks() -> void:
	var need := roads.fuel_need()
	var was := roads.running
	# Camions au carburant et camions électriques (si le réseau les sert).
	var powered := roads.electric_watts() <= 0.0 or grid.coverage >= EV_MIN_COVERAGE
	var fuelled := need <= 0.0 or stockpile.has(Stockpile.Good.FUEL, need)
	roads.running = powered and fuelled
	if need > 0.0 and roads.running:
		fuel_burned_today += stockpile.take(Stockpile.Good.FUEL, need)
	if was and not roads.running:
		EventBus.notified.emit("Plus de carburant : les camions s'arrêtent" if not fuelled
			else "Plus de courant : les camions électriques s'arrêtent")
	if was != roads.running:
		roads.refresh()
		EventBus.roads_changed.emit([] as Array[Vector2i])
		_update_labor()


## Ce qui empêche de poser des voies (vide : possible).
func rails_error() -> String:
	var station := BuildingDb.get_def(&"station")
	if tier.level < station.tier:
		return "Disponible au palier %s" % CityTier.label(station.tier)
	if not research.is_done(station.research):
		return "Recherche requise : %s" % ResearchDb.get_def(station.research).display_name
	return ""


## Ce qui empêche de poser des lignes électriques (vide : possible).
func lines_error() -> String:
	var plant := BuildingDb.get_def(&"power_plant")
	if tier.level < plant.tier:
		return "Disponible au palier %s" % CityTier.label(plant.tier)
	if not research.is_done(plant.research):
		return "Recherche requise : %s" % ResearchDb.get_def(plant.research).display_name
	return ""


## Ce qui empêche de creuser des canaux (vide : possible).
func canals_error() -> String:
	if not research.is_done(&"irrigation"):
		return "Recherche requise : %s" % ResearchDb.get_def(&"irrigation").display_name
	return ""


## Canaux reliés à l'eau (rivières, lacs, puits) et champs qu'ils irriguent.
func _refresh_canals() -> void:
	canals.refresh(production.wells)
	EventBus.canals_changed.emit([] as Array[Vector2i])


func plan_canals(from: Vector2i, to: Vector2i) -> TrackNetwork.Plan:
	return _plan_track(canals, canals_error(), from, to)


## Creuse les canaux de [param p] ; renvoie le nombre de tuiles creusées
## (raison notifiée si aucune).
func build_canals(p: TrackNetwork.Plan) -> int:
	var built := _lay_track(canals, p)
	if built.is_empty():
		return 0
	_refresh_canals()
	EventBus.canals_changed.emit(built)
	_update_labor()
	return built.size()


## Ce qui empêche de poser des routes (vide : possible).
func roads_error() -> String:
	if tier.level < ROAD_TIER:
		return "Disponible au palier %s" % CityTier.label(ROAD_TIER)
	return ""


## Aperçu d'un tracé de voie entre deux tuiles (repère de la vue) : palier,
## recherche, règles du réseau et matériaux.
func plan_rails(from: Vector2i, to: Vector2i) -> TrackNetwork.Plan:
	return _plan_track(rails, rails_error(), from, to)


func plan_roads(from: Vector2i, to: Vector2i) -> TrackNetwork.Plan:
	return _plan_track(roads, roads_error(), from, to)


func plan_lines(from: Vector2i, to: Vector2i) -> TrackNetwork.Plan:
	return _plan_track(grid, lines_error(), from, to)


func _plan_track(network: TrackNetwork, error: String, from: Vector2i, to: Vector2i) -> TrackNetwork.Plan:
	var p := network.plan(from, to)
	p.costs = with_cement(p.costs)
	if not error.is_empty():
		p.error = error
	for good in Stockpile.COUNT:
		if p.is_valid() and not stockpile.has(good, p.costs[good]):
			p.error = "%s insuffisant%s (%d requis)" % [Stockpile.GOOD_NAMES[good],
				Stockpile.GOOD_AGREEMENT[good], roundi(p.costs[good])]
	if not p.is_valid():
		p.new_cells.clear()
	return p


## Pose les voies de [param p] ; renvoie le nombre de tuiles posées (raison
## notifiée si aucune).
func build_rails(p: TrackNetwork.Plan) -> int:
	var built := _lay_track(rails, p)
	if built.is_empty():
		return 0
	EventBus.rails_changed.emit(built)
	_refresh_rails()
	_update_labor()
	return built.size()


## Pose les lignes de [param p] ; renvoie le nombre de tuiles posées (raison
## notifiée si aucune).
func build_lines(p: TrackNetwork.Plan) -> int:
	var built := _lay_track(grid, p)
	if built.is_empty():
		return 0
	_refresh_grid()
	EventBus.grid_changed.emit(built)
	return built.size()


## Pose les routes de [param p] ; renvoie le nombre de tuiles posées (raison
## notifiée si aucune).
func build_roads(p: TrackNetwork.Plan) -> int:
	var built := _lay_track(roads, p)
	if built.is_empty():
		return 0
	roads.refresh()
	EventBus.roads_changed.emit(built)
	_update_labor()
	return built.size()


## Paie et pose le tracé [param p] sur [param network] ; renvoie les tuiles
## posées (raison notifiée si aucune).
func _lay_track(network: TrackNetwork, p: TrackNetwork.Plan) -> Array[Vector2i]:
	if not p.is_valid():
		if not p.error.is_empty():
			EventBus.notified.emit(p.error)
		return []
	for good in Stockpile.COUNT:
		stockpile.take(good, p.costs[good])
	var built := network.build(p)
	if not p.cleared.is_empty():
		EventBus.tiles_changed.emit(p.cleared)
	EventBus.stocks_changed.emit()
	return built


## Part des habitants approvisionnés en eau : besoin à partir du village
## (palier 2), couvert par les puits.
func water_coverage() -> float:
	if tier.level < WATER_TIER or population.count == 0:
		return 1.0
	return minf(1.0, float(water_supply) / population.count)


## Actifs disponibles pour les zones (hors explorateurs partis).
func workers() -> int:
	return maxi(0, population.active() - exploration.members_out())


## Nourriture puisée chaque jour au grenier : habitants (les explorateurs
## mangent leurs vivres) et fourrage des chevaux à l'écurie.
func food_need() -> float:
	return maxf(0.0, population.food_need() * decrees.food_factor() - exploration.members_out() * Exploration.FOOD_PER_MEMBER_PER_DAY) \
		+ draft.fodder_need()




## Moyen par lequel l'avant-poste ou le port [param b] est relié au village :
## « l'eau » (port relié à une tête de ligne), « route », « voie ferrée »,
## « aérodrome », ou vide s'il ne l'est pas.
func outpost_link(b: Building) -> String:
	if not b.is_complete() or not (b.def.outpost or b.def.harbor):
		return ""
	if space and space.has(Space.Kind.COMMUNICATIONS):
		return "satellite"
	if b.def.harbor and ports.is_linked(b.anchor):
		return "l'eau"
	for cell in b.cells:
		for o in WorldMap.NEIGHBORS_4:
			if roads.lengths.has(world_map.wrap_cell(cell + o)):
				return "route"
	for r in rails.access_tiles(b):
		if rails.reached.has(r):
			return "voie ferrée"
	if tier.level >= Exploration.PLANE_TIER:
		for other in buildings.all():
			if other.is_complete() and other.def.airfield \
					and rails.cheb(other.anchor, b.anchor) <= Exploration.AIRFIELD_RANGE + maxi(other.def.size.x, other.def.size.y):
				return "aérodrome"
	return ""


## Départs possibles des expéditions (repère de la vue) : le village, puis les
## avant-postes et les ports reliés.
func expedition_origins() -> Array[Vector2i]:
	var result: Array[Vector2i] = [display_cell(home)]
	for b in buildings.all():
		if not outpost_link(b).is_empty():
			result.append(b.anchor)
	return result


## Départ des expéditions (repère de la vue) : le choix du joueur s'il est
## toujours possible, sinon le village.
func expedition_start() -> Vector2i:
	var origins := expedition_origins()
	return origins[expedition_origin] if expedition_origin < origins.size() else origins[0]


func set_expedition_origin(index: int) -> void:
	expedition_origin = maxi(0, index)
	EventBus.expeditions_changed.emit()


## Lance une expédition de [param members] explorateurs et [param horses]
## chevaux de bât avec [param days] jours de vivres vers [param target]
## (repère de la vue) ; null (raison notifiée) si c'est impossible.
func launch_expedition(target: Vector2i, members: int, days: float, horses := 0) -> Exploration.Expedition:
	var error := expedition_error(members, days, horses)
	var transport := expedition_transport(members, days, horses)
	var start := expedition_start()
	if error.is_empty() and exploration.plan_path(start, target, transport).size() < 2:
		error = "Trajet impossible : de l'eau barre le chemin"
	if not error.is_empty():
		EventBus.notified.emit(error)
		return null
	var food := members * days * Exploration.FOOD_PER_MEMBER_PER_DAY
	stockpile.take(Stockpile.Good.FOOD, food)
	var fuel := stockpile.take(Stockpile.Good.FUEL, expedition_fuel(transport, members, days))
	# En véhicule ou en avion, les chevaux restent à l'écurie.
	if transport >= Exploration.Transport.MOTOR:
		horses = 0
	var e := exploration.launch(start, target, members, food, transport, fuel)
	e.horses = horses
	e.speed = exploration.speed_for(members, horses)
	draft.away += horses
	EventBus.notified.emit("Expédition partie %s : %d explorateur%s%s, %s jours de vivres%s" % [
		Exploration.TRANSPORT_NAMES[transport], members, "s" if members > 1 else "",
		" et %d cheva%s" % [horses, "ux" if horses > 1 else "l"] if horses > 0 else "",
		Format.decimal(days), ", %s carburant" % Format.decimal(fuel) if fuel > 0.0 else ""])
	_update_labor()
	EventBus.stocks_changed.emit()
	EventBus.expeditions_changed.emit()
	return e


## Moyen de transport d'une expédition de [param members] explorateurs pour
## [param days] jours : le meilleur du palier dont le carburant est en stock
## (avion, puis véhicules à moteur), sinon à cheval ou à pied.
func expedition_transport(members: int, days: float, horses := 0) -> Exploration.Transport:
	var best := exploration.best_transport(members, horses)
	for t in [Exploration.Transport.PLANE, Exploration.Transport.MOTOR]:
		if best >= t and stockpile.has(Stockpile.Good.FUEL, expedition_fuel(t, members, days)):
			return t
	return Exploration.Transport.HORSE if exploration.speed_for(members, horses) > 1.0 else Exploration.Transport.FOOT


## Carburant emporté par [param members] explorateurs pour [param days]
## jours en [param transport].
func expedition_fuel(transport: Exploration.Transport, members: int, days: float) -> float:
	return members * days * Exploration.fuel_rate(transport)


## Jours de vivres que portent [param members] explorateurs et
## [param horses] chevaux de bât (chacun porte DraftAnimals.pack_factor() fois
## la charge d'un explorateur).
func max_expedition_days(members: int, horses: int) -> float:
	if members <= 0:
		return 0.0
	return exploration.max_days() * (members + draft.pack_factor() * horses) / members


## Ce qui empêche une expédition de [param members] explorateurs et
## [param horses] chevaux avec [param days] jours de vivres (vide : possible).
func expedition_error(members: int, days: float, horses := 0) -> String:
	if not exploration.can_launch():
		return "Déjà %d expédition%s en route (le maximum à ce palier)" % [
			exploration.max_expeditions(), "s" if exploration.max_expeditions() > 1 else ""]
	if members <= 0 or days <= 0.0:
		return "Il faut au moins un explorateur et des vivres"
	if horses < 0 or horses > draft.at_home():
		return "Pas assez de chevaux à l'écurie (%d)" % draft.at_home()
	if days > max_expedition_days(members, horses) + 0.001:
		return "Au plus %s jours de vivres (portés par les explorateurs%s)" % [
			Format.decimal(max_expedition_days(members, horses)), " et les chevaux" if horses > 0 else ""]
	if members > mini(Exploration.MAX_MEMBERS, workers()):
		return "Pas assez d'habitants actifs disponibles"
	if not stockpile.has(Stockpile.Good.FOOD, members * days * Exploration.FOOD_PER_MEMBER_PER_DAY):
		return "Pas assez de nourriture au grenier pour les vivres"
	return ""


func _step_expeditions() -> void:
	if exploration.expeditions.is_empty():
		return
	var report := exploration.step_hour()
	if not report.revealed.is_empty():
		EventBus.tiles_changed.emit(report.revealed)
		EventBus.territory_changed.emit()
	if not report.prospected.is_empty():
		EventBus.tiles_changed.emit(report.prospected)
	for e in report.turned:
		EventBus.notified.emit("L'expédition fait demi-tour : %s" % Exploration.REASON_TEXTS[e.reason])
	for e in report.returned:
		stockpile.add(Stockpile.Good.FOOD, e.food)
		stockpile.add(Stockpile.Good.FUEL, e.fuel)
		draft.away = maxi(0, draft.away - e.horses)
		EventBus.notified.emit("L'expédition est rentrée : %d tuile%s découverte%s" % [
			e.revealed, "s" if e.revealed > 1 else "", "s" if e.revealed > 1 else ""])
	if not report.returned.is_empty():
		_refresh_ports()
		_update_labor()
	EventBus.expeditions_changed.emit()


## Nouveau palier : les habitants prospectent leur territoire (gisements du
## palier visibles).
func _prospect_territory() -> void:
	var cells := territory.territory_cells()
	territory.prospect(cells)
	var shown: Array[Vector2i] = []
	for c in cells:
		shown.append(display_cell(c))
	EventBus.tiles_changed.emit(shown)


## Forges : fer et combustible du jour transformés en outils, dans la limite
## du stock. Avec le coke, elles brûlent du charbon (s'il y en a) et
## fabriquent davantage ; un moulin à eau entraîne leurs soufflets.
func _run_forges() -> void:
	var rate := 0.0
	for b in all_buildings():
		if b.is_complete():
			rate += b.def.tools_per_day
	rate *= (1.0 + production.drive_bonus) * grid.industry_factor()
	var fuel := Stockpile.Good.WOOD
	var fuel_per_tool := FORGE_WOOD_PER_TOOL
	if research.is_done(&"coke") and stockpile.amount[Stockpile.Good.COAL] > 0.0:
		fuel = Stockpile.Good.COAL
		fuel_per_tool /= COAL_WOOD_EQUIVALENT
		rate *= COKE_FORGE_BONUS
	var room := stockpile.capacity[Stockpile.Good.TOOLS] - stockpile.amount[Stockpile.Good.TOOLS]
	var n := minf(minf(rate, room), minf(stockpile.amount[Stockpile.Good.IRON] / FORGE_IRON_PER_TOOL,
		stockpile.amount[fuel] / fuel_per_tool))
	if n <= 0.0:
		return
	stockpile.take(Stockpile.Good.IRON, n * FORGE_IRON_PER_TOOL)
	var burnt := stockpile.take(fuel, n * fuel_per_tool)
	if fuel == Stockpile.Good.COAL:
		coal_burned_today += burnt
	else:
		wood_burned_today += burnt
	stockpile.add(Stockpile.Good.TOOLS, n)
	production.produced_today[Stockpile.Good.TOOLS] += n


## Charbon de bois : une part du bois coupé aujourd'hui devient du charbon,
## sans entamer la réserve de chauffage ni dépasser la place en stock.
func _run_charcoal() -> void:
	if not research.is_done(&"charcoal"):
		return
	var spare := stockpile.amount[Stockpile.Good.WOOD] - wood_need(GameDate.WINTER) * CHARCOAL_RESERVE_DAYS
	var room := stockpile.capacity[Stockpile.Good.COAL] - stockpile.amount[Stockpile.Good.COAL]
	var wood := minf(production.produced_today[Stockpile.Good.WOOD] * CHARCOAL_WOOD_SHARE,
		minf(spare, room * WOOD_PER_CHARCOAL))
	if wood <= 0.0:
		return
	var n := wood / WOOD_PER_CHARCOAL
	stockpile.take(Stockpile.Good.WOOD, wood)
	stockpile.add(Stockpile.Good.COAL, n)
	production.produced_today[Stockpile.Good.COAL] += n


## Ateliers de tissage : fibres du jour transformées en vêtements, dans la
## limite du stock.
func _run_weavers() -> void:
	var rate := 0.0
	for b in all_buildings():
		if b.is_complete():
			rate += b.def.clothes_per_day
	rate *= grid.industry_factor()
	var room := stockpile.capacity[Stockpile.Good.CLOTHES] - stockpile.amount[Stockpile.Good.CLOTHES]
	var n := minf(minf(rate, room), stockpile.amount[Stockpile.Good.FIBER] / FIBER_PER_CLOTHES)
	if n <= 0.0:
		return
	stockpile.take(Stockpile.Good.FIBER, n * FIBER_PER_CLOTHES)
	stockpile.add(Stockpile.Good.CLOTHES, n)
	production.produced_today[Stockpile.Good.CLOTHES] += n


## Raffineries : pétrole du jour transformé en carburant, dans la limite du
## stock.
func _run_refineries() -> void:
	var rate := 0.0
	for b in all_buildings():
		if b.is_complete():
			rate += b.def.fuel_per_day
	rate *= grid.industry_factor()
	var room := stockpile.capacity[Stockpile.Good.FUEL] - stockpile.amount[Stockpile.Good.FUEL]
	var n := minf(minf(rate, room), stockpile.amount[Stockpile.Good.OIL] / OIL_PER_FUEL)
	if n <= 0.0:
		return
	stockpile.take(Stockpile.Good.OIL, n * OIL_PER_FUEL)
	stockpile.add(Stockpile.Good.FUEL, n)
	production.produced_today[Stockpile.Good.FUEL] += n


## Ateliers d'artisans : bois et fer du jour transformés en biens variés,
## dans la limite du stock (le bois de chauffage d'hiver reste en réserve).
func _run_artisans() -> void:
	var rate := 0.0
	for b in all_buildings():
		if b.is_complete():
			rate += b.def.goods_per_day
	if rate <= 0.0:
		return
	rate *= (1.0 + production.drive_bonus) * grid.industry_factor()
	var room := stockpile.capacity[Stockpile.Good.GOODS] - stockpile.amount[Stockpile.Good.GOODS]
	var spare_wood := stockpile.amount[Stockpile.Good.WOOD] - wood_need(GameDate.WINTER) * CHARCOAL_RESERVE_DAYS
	var n := minf(minf(rate, room), minf(spare_wood / GOODS_WOOD, stockpile.amount[Stockpile.Good.IRON] / GOODS_IRON))
	if n <= 0.0:
		return
	stockpile.take(Stockpile.Good.WOOD, n * GOODS_WOOD)
	stockpile.take(Stockpile.Good.IRON, n * GOODS_IRON)
	stockpile.add(Stockpile.Good.GOODS, n)
	production.produced_today[Stockpile.Good.GOODS] += n


## Biens variés usés par jour (à partir de la ville).
func goods_need() -> float:
	return population.goods_need() if tier.level >= SERVICES_TIER else 0.0


## Usure du jour : prend les biens au stock ; renvoie la part obtenue (1 sans
## besoin).
func _wear_goods() -> float:
	var need := goods_need()
	if need <= 0.0:
		return 1.0
	return stockpile.take(Stockpile.Good.GOODS, need) / need


## Habitants couverts par [param service] : bâtiments terminés et entretenus
## (dispensaires, postes de garde, écoles et universités, théâtres).
func service_capacity(service: Service) -> int:
	var total := 0
	for b in all_buildings():
		if b.is_complete():
			match service:
				Service.HEALTH:
					total += b.def.health_coverage
				Service.ORDER:
					total += b.def.order_coverage
				Service.EDUCATION:
					total += b.def.education_coverage
				Service.CULTURE:
					total += b.def.culture_coverage
	return total


## Part des habitants soignés (à partir de la ville ; 1 avant).
func health_coverage() -> float:
	return _service_coverage(Service.HEALTH, SERVICES_TIER)


## Part des habitants sous la garde des postes (à partir de la ville ; 1 avant).
func order_coverage() -> float:
	return _service_coverage(Service.ORDER, SERVICES_TIER)


## Part des habitants instruits, et qui ont accès à la culture (à partir de la
## cité-État ; 1 avant).
func education_coverage() -> float:
	return _service_coverage(Service.EDUCATION, CITY_STATE_TIER)


func culture_coverage() -> float:
	return _service_coverage(Service.CULTURE, CITY_STATE_TIER)


## Part de la demande d'électricité servie (besoin à partir de la cité-État ;
## 1 avant).
func electricity_coverage() -> float:
	return grid.coverage if tier.level >= CITY_STATE_TIER else 1.0


func _service_coverage(service: Service, from_tier: int) -> float:
	if tier.level < from_tier or population.count == 0:
		return 1.0
	return minf(1.0, float(service_capacity(service)) / population.count)


## Usines d'enrichissement : minerai d'uranium du jour transformé en
## combustible nucléaire, dans la limite du stock, au prorata du courant servi
## la veille (sans courant, à l'arrêt).
func _run_enrichment() -> void:
	var rate := 0.0
	for b in all_buildings():
		if b.is_complete():
			rate += b.def.nuclear_fuel_per_day
	rate *= clampf(grid.coverage, 0.0, 1.0)
	if rate <= 0.0:
		return
	var room := stockpile.capacity[Stockpile.Good.NUCLEAR_FUEL] - stockpile.amount[Stockpile.Good.NUCLEAR_FUEL]
	var n := minf(minf(rate, room), stockpile.amount[Stockpile.Good.URANIUM] / PowerGrid.ENRICH_URANIUM)
	if n <= 0.0:
		return
	stockpile.take(Stockpile.Good.URANIUM, n * PowerGrid.ENRICH_URANIUM)
	stockpile.add(Stockpile.Good.NUCLEAR_FUEL, n)
	production.produced_today[Stockpile.Good.NUCLEAR_FUEL] += n


## Ère spatiale du jour : assemblage dans les usines de fusées alimentées,
## lancement depuis une base s'il y a une fusée et assez de carburant,
## cartographie par le satellite.
func _run_space() -> void:
	var factories := 0.0
	var pad: Building = null
	for b in all_buildings():
		if b.is_complete() and b.def.rocket_factory and machines_powered():
			factories += 1.0
		if b.is_complete() and b.def.launch_pad and pad == null:
			pad = b
	space.lunar_project = research.is_done(&"moon_voyage")
	if space.assemble(stockpile, factories):
		EventBus.notified.emit("%s est prête%s" % ["La fusée lunaire" if space.lunar_ready else "Une fusée",
			"" if pad else " : construisez une base de lancement"])
	if pad and space.lunar_ready:
		var lunar_fuel := Space.lunar_fuel(world_map.latitude(world_map.wrap_cell(pad.anchor).y))
		if stockpile.has(Stockpile.Good.FUEL, lunar_fuel):
			fuel_burned_today += stockpile.take(Stockpile.Good.FUEL, lunar_fuel)
			if space.launch_lunar():
				EventBus.notified.emit("Alunissage : l'équipage de %s marche sur la Lune !" % city.name)
			else:
				EventBus.notified.emit("Échec de la mission lunaire : la fusée est perdue, les usines en construisent une autre")
	if pad and space.rockets > 0:
		var fuel := space.next_launch_fuel(world_map.latitude(world_map.wrap_cell(pad.anchor).y))
		if stockpile.has(Stockpile.Good.FUEL, fuel):
			fuel_burned_today += stockpile.take(Stockpile.Good.FUEL, fuel)
			var first := space.satellites == 0
			if space.launch():
				var kind: int = space.kinds[-1]
				events.forecast = space.has(Space.Kind.WEATHER)
				EventBus.notified.emit("Lancement réussi : satellite %s en orbite %s%s" % [Space.KIND_NAMES[kind],
					Space.ORBIT_NAMES[Space.orbit_of(kind)], {
					Space.Kind.SURVEY: " — il cartographie la planète" if first else "",
					Space.Kind.WEATHER: " — prévisions météo, intempéries atténuées",
					Space.Kind.COMMUNICATIONS: " — avant-postes et ports reliés, recherche +%d %%" % roundi(Space.COMMUNICATIONS_RESEARCH * 100.0),
				}.get(kind, "")])
			else:
				EventBus.notified.emit("Échec du lancement : la fusée est perdue")


## Le satellite cartographie ses colonnes du jour (en partant de la longitude
## du village, vers l'est) : tuiles explorées, gisements prospectés.
func _survey() -> void:
	var columns := space.survey_day(world_map.size.x)
	if columns.is_empty():
		return
	var cells: Array[Vector2i] = []
	for k in columns:
		var x := posmod(home.x + k, world_map.size.x)
		for y in world_map.size.y:
			cells.append(Vector2i(x, y))
	territory.explore(cells)
	territory.prospect(cells)
	var shown: Array[Vector2i] = []
	for c in cells:
		shown.append(display_cell(c))
	EventBus.tiles_changed.emit(shown)
	EventBus.territory_changed.emit()
	if space.surveyed(world_map.size.x) >= 1.0:
		EventBus.notified.emit("Le satellite a cartographié toute la planète")


## Indice de pollution de l'air (0 : pur, 1 : irrespirable).
func pollution_index() -> float:
	return pollution.index(population.count)


## Gêne de la pollution pour les habitants : l'indice, moins la part que les
## soins évitent (à partir de la ville, quand les dispensaires comptent).
func pollution_harm() -> float:
	return pollution_index() * (1.0 - CARE_POLLUTION_SHIELD * (health_coverage() if tier.level >= SERVICES_TIER else 0.0))


## Cimenteries : pierre et charbon du jour cuits en ciment, dans la limite
## du stock.
func _run_cement() -> void:
	var rate := 0.0
	for b in all_buildings():
		if b.is_complete():
			rate += b.def.cement_per_day
	if rate <= 0.0:
		return
	rate *= grid.industry_factor()
	var room := stockpile.capacity[Stockpile.Good.CEMENT] - stockpile.amount[Stockpile.Good.CEMENT]
	var n := minf(minf(rate, room), minf(stockpile.amount[Stockpile.Good.STONE] / CEMENT_STONE,
		stockpile.amount[Stockpile.Good.COAL] / CEMENT_COAL))
	if n <= 0.0:
		return
	stockpile.take(Stockpile.Good.STONE, n * CEMENT_STONE)
	coal_burned_today += stockpile.take(Stockpile.Good.COAL, n * CEMENT_COAL)
	stockpile.add(Stockpile.Good.CEMENT, n)
	production.produced_today[Stockpile.Good.CEMENT] += n


## Usines d'électronique : cuivre du jour transformé en composants, dans la
## limite du stock.
func _run_electronics() -> void:
	var rate := 0.0
	for b in all_buildings():
		if b.is_complete():
			rate += b.def.electronics_per_day
	if rate <= 0.0:
		return
	rate *= grid.industry_factor()
	var room := stockpile.capacity[Stockpile.Good.ELECTRONICS] - stockpile.amount[Stockpile.Good.ELECTRONICS]
	var n := minf(minf(rate, room), stockpile.amount[Stockpile.Good.COPPER] / ELECTRONICS_COPPER)
	if n <= 0.0:
		return
	stockpile.take(Stockpile.Good.COPPER, n * ELECTRONICS_COPPER)
	stockpile.add(Stockpile.Good.ELECTRONICS, n)
	production.produced_today[Stockpile.Good.ELECTRONICS] += n


## Éclairage voulu par jour, en carburant (à partir de la ville).
func _light_demand() -> float:
	return population.light_need() if tier.level >= LIGHT_TIER else 0.0


## Carburant des lampes par jour : le courant en remplace une part.
func light_need() -> float:
	return _light_demand() * (1.0 - grid.coverage)


## Éclairage du jour : prend le carburant au stock ; renvoie la part obtenue
## (1 sans besoin).
func _burn_light() -> float:
	var demand := _light_demand()
	if demand <= 0.0:
		return 1.0
	var lamps := stockpile.take(Stockpile.Good.FUEL, light_need())
	fuel_burned_today += lamps
	return grid.coverage + lamps / demand


## Vêtements usés par jour (à partir du bourg).
func clothes_need() -> float:
	return population.clothes_need() if tier.level >= CLOTHES_TIER else 0.0


## Usure du jour : prend les vêtements au stock ; renvoie la part obtenue (1
## sans besoin).
func _wear_clothes() -> float:
	var need := clothes_need()
	if need <= 0.0:
		return 1.0
	return stockpile.take(Stockpile.Good.CLOTHES, need) / need


## Travailleurs agricoles (champs, lin, élevage) qui conduisent des tracteurs
## (recherche Tracteur).
func tractor_users() -> int:
	if not research.is_done(&"tractor"):
		return 0
	var users := 0
	for def in ZoneDb.DEFS:
		if def.quality == ZoneDef.Quality.FERTILITY or def.quality == ZoneDef.Quality.PASTURE:
			users += labor.assigned[def]
	return users


## Carburant des tracteurs par jour.
func tractor_fuel_need() -> float:
	return tractor_users() * TRACTOR_FUEL_PER_WORKER


## Tracteurs du jour : prennent leur carburant au stock ; la part obtenue fixe
## leur bonus du lendemain.
func _run_tractors() -> void:
	var need := tractor_fuel_need()
	if need <= 0.0:
		production.tractor_fuel = 1.0 if research.is_done(&"tractor") else 0.0
		return
	var got := stockpile.take(Stockpile.Good.FUEL, need)
	fuel_burned_today += got
	var was := production.tractor_fuel
	production.tractor_fuel = got / need
	if was >= 0.999 and production.tractor_fuel < 0.999:
		EventBus.notified.emit("Carburant insuffisant : les tracteurs tournent à %d %%" % roundi(production.tractor_fuel * 100.0))


## Habitants qui usent des outils : bûcherons (scies, recherche Outils) et
## laboureurs des champs, céréales et lin (charrues, recherche Charrue).
func tool_users() -> int:
	var users := 0
	if research.is_done(&"tools"):
		users += labor.assigned[ZoneDb.get_def(&"forestry")]
	if research.is_done(&"plough"):
		for def in ZoneDb.DEFS:
			if def.quality == ZoneDef.Quality.FERTILITY:
				users += labor.assigned[def]
	return users


## Outils usés par jour.
func tools_need() -> float:
	return tool_users() / TOOL_LIFE_DAYS


## Usure du jour : prend les outils au stock ; renvoie la part obtenue (1 sans
## besoin). Sans outils, les bonus de la scie et de la charrue disparaissent.
func _wear_tools() -> float:
	var need := tools_need()
	if need <= 0.0:
		production.tools_ok = true
		return 1.0
	var got := stockpile.take(Stockpile.Good.TOOLS, need)
	production.tools_ok = got >= need * 0.999
	return got / need


## Puissance mécanique des moulins le jour de [param tick] (selon le vent
## pour les moulins à vent).
func _mill_watts(tick: int) -> float:
	var watts := 0.0
	for b in all_buildings():
		if b.is_complete():
			watts += b.def.mechanical_watts * (weather.wind_at(tick) if b.def.wind_powered else 1.0)
	return watts


## Somme des qualités des tuiles de pâturage (troupeaux, élevage des chevaux).
func _pasture_quality() -> float:
	var pasture := ZoneDb.get_def(&"pasture")
	var total := 0.0
	for cell in zones.cells_of(pasture):
		total += pasture.quality_at(world_map, cell)
	return total


## Points de recherche produits par jour.
func research_per_day() -> float:
	var boosts: Array[Vector2] = []
	for b in all_buildings():
		if b.is_complete() and b.def.research_coverage > 0 and (b.def.power_demand <= 0.0 or machines_powered()):
			boosts.append(Vector2(b.def.research_multiplier, b.def.research_coverage))
	var points := Research.points_per_day(population.count, population.satisfaction, boosts)
	# Satellite de communications : les savants échangent plus vite.
	if space and space.has(Space.Kind.COMMUNICATIONS):
		points *= 1.0 + Space.COMMUNICATIONS_RESEARCH
	return points


## Lance la recherche [param def] ; false (raison notifiée) si indisponible.
func start_research(def: ResearchDef) -> bool:
	if not research.start(def, research_level()):
		EventBus.notified.emit("%s n'est pas disponible" % def.display_name)
		return false
	EventBus.research_changed.emit()
	return true


## Jours de réserve de nourriture et de bois au rythme actuel.
func food_days() -> float:
	return stockpile.days_of(Stockpile.Good.FOOD, food_need())


func wood_days() -> float:
	return stockpile.days_of(Stockpile.Good.WOOD, wood_need(GameDate.season(GameClock.tick)))


## Parts du chauffage (Heat) au palier atteint, d'après ce qui est
## disponible : charbon et carburant en stock, courant servi la veille. La part
## qui manque passe au charbon et au fioul disponibles (au prorata), sinon au
## bois.
func heat_mix() -> PackedFloat32Array:
	var base := heat_shares()
	var available := PackedFloat32Array([1.0,
		1.0 if stockpile.amount[Stockpile.Good.COAL] > 0.0 else 0.0,
		1.0 if stockpile.amount[Stockpile.Good.FUEL] > 0.0 else 0.0,
		clampf(grid.coverage, 0.0, 1.0) if not grid.connected.is_empty() else 0.0])
	var mix := PackedFloat32Array()
	var missing := 0.0
	for k in base.size():
		mix.append(base[k] * available[k])
		missing += base[k] - mix[k]
	var fossil := mix[Heat.COAL] + mix[Heat.FUEL]
	if fossil > 0.0:
		var coal_part := mix[Heat.COAL] / fossil
		mix[Heat.COAL] += missing * coal_part
		mix[Heat.FUEL] += missing * (1.0 - coal_part)
	else:
		mix[Heat.WOOD] += missing
	return mix


## Charbon brûlé par jour pour le chauffage pendant la saison [param season].
func coal_heat_need(season: int) -> float:
	return heat_need(season) * heat_mix()[Heat.COAL] / COAL_WOOD_EQUIVALENT


## Carburant brûlé par jour pour le chauffage (fioul, à partir de la ville).
func fuel_heat_need(season: int) -> float:
	return heat_need(season) * heat_mix()[Heat.FUEL] / FUEL_WOOD_EQUIVALENT


## Courant demandé pour le chauffage pendant [param season] (W ; part prévue
## au palier, que le réseau la serve ou non).
func electric_heat_watts(season: int) -> float:
	return heat_need(season) * heat_shares()[Heat.ELECTRICITY] * WATTS_PER_HEAT_WOOD


## Parts prévues du chauffage (Heat) au palier atteint.
func heat_shares() -> PackedFloat32Array:
	var level := clampi(tier.level, 1, CityTier.NAMES.size()) - 1
	return HEAT_SHARES.slice(level * HEAT_SOURCES, (level + 1) * HEAT_SOURCES)


## Bois brûlé par jour pendant la saison [param season], les autres sources
## déduites.
func wood_need(season: int) -> float:
	return heat_need(season) * heat_mix()[Heat.WOOD]


## Chauffage du jour pendant [param season], en bois (hiver rude et isolation
## du palier compris).
func heat_need(season: int) -> float:
	return population.wood_need(season) * events.heat_factor() * HEAT_INSULATION[clampi(tier.level, 1, HEAT_INSULATION.size()) - 1]


## Priorités automatiques d'après les stocks. La nourriture doit tenir
## jusqu'aux prochaines récoltes ; en automne, le bois doit couvrir l'hiver
## entier. Ces réserves visées sont plafonnées par la capacité des stocks :
## au-delà, viser plus ne servirait à rien et priverait l'autre activité.
func _update_auto_priorities(tick: int) -> void:
	var season := GameDate.season(tick)
	var food_goal := food_need() * maxf(Labor.FOOD_ALERT_DAYS, lean_days(tick))
	var wood_goal := wood_need(GameDate.season(tick)) * Labor.WOOD_ALERT_DAYS
	if season == GameDate.WINTER - 1:
		wood_goal = maxf(wood_goal, wood_need(GameDate.WINTER) * GameDate.DAYS_PER_SEASON)
	var food_short := stockpile.amount[Stockpile.Good.FOOD] < _reachable(Stockpile.Good.FOOD, food_goal)
	var wood_short := stockpile.amount[Stockpile.Good.WOOD] < _reachable(Stockpile.Good.WOOD, wood_goal)
	stockpile.update_full()
	var short: Array[bool] = [food_short, wood_short]
	labor.update_auto(short, season, stockpile.full)


## Réserve [param goal] de [param good], ramenée à ce que le stock peut contenir.
func _reachable(good: Stockpile.Good, goal: float) -> float:
	return minf(goal, stockpile.capacity[good] * Stockpile.REFILL_RATIO)


## Pendant une saison de récolte, jours de la fin des récoltes au retour des
## récoltes (morte-saison) ; hors récolte, jours restant jusqu'aux récoltes.
func lean_days(tick: int) -> float:
	var farm := ZoneDb.get_def(&"agriculture")
	var season := GameDate.season(tick)
	var lean := 0
	if farm.season_factors[season] <= 0.0:
		lean = GameDate.DAYS_PER_SEASON - GameDate.day_of_season(tick) + 1
		for k in range(1, GameDate.SEASONS_PER_YEAR):
			if farm.season_factors[(season + k) % GameDate.SEASONS_PER_YEAR] > 0.0:
				break
			lean += GameDate.DAYS_PER_SEASON
		return lean
	for k in GameDate.SEASONS_PER_YEAR:
		var s := (season + 1 + k) % GameDate.SEASONS_PER_YEAR
		if farm.season_factors[s] > 0.0 and lean > 0:
			break
		if farm.season_factors[s] <= 0.0:
			lean += GameDate.DAYS_PER_SEASON
	return lean


## Événements du jour (à partir du bourg) : fin de ceux en cours, tirage
## d'un nouveau et effets immédiats.
func _run_events(season: int) -> void:
	if tier.level < EVENTS_TIER:
		return
	var nuclear := grid.connected.any(func(b: Building) -> bool:
		return b.def.power_source == BuildingDef.PowerSource.NUCLEAR)
	var kind := events.roll(season, tier.level, nuclear)
	if kind >= 0:
		apply_event(kind)


## Effets immédiats et annonce de l'événement [param kind].
func apply_event(kind: int) -> void:
	var text := CityEvents.START_TEXTS[kind]
	match kind:
		CityEvents.Kind.EPIZOOTIC:
			draft.horses *= 1.0 - CityEvents.EPIZOOTIC_HORSES_LOST
		CityEvents.Kind.FOREST_FIRE:
			text += " : %d tuiles brûlées" % _burn_forest()
		CityEvents.Kind.EPIDEMIC:
			var deaths := floori(population.count * CityEvents.EPIDEMIC_DEATHS * (1.0 - health_coverage())
				* (1.0 + pollution_index()))
			population.count -= deaths
			text += " : %d morts%s" % [deaths, ", les dispensaires ont soigné tout le monde" if deaths == 0
				else " (dispensaires : %d %% des habitants soignés)" % roundi(health_coverage() * 100.0)]
			if deaths > 0:
				_update_labor()
		CityEvents.Kind.MIGRANTS:
			var arrivals := mini(ceili(population.count * CityEvents.MIGRANTS_SHARE), maxi(0, housing - population.count))
			if arrivals == 0:
				text += ", mais ne trouvent aucun logement et repartent"
			else:
				population.count += arrivals
				text += " : %d nouveaux habitants" % arrivals
				_update_labor()
	EventBus.notified.emit(text)


## Feu parti d'une forêt du territoire, qui gagne les forêts voisines ;
## renvoie le nombre de tuiles brûlées.
func _burn_forest() -> int:
	var forests: Array[Vector2i] = []
	for cell in territory.territory_cells():
		if world_map.get_terrain(cell) == TerrainDef.Type.FOREST:
			forests.append(cell)
	if forests.is_empty():
		return 0
	var front: Array[Vector2i] = [forests[events.rng.randi_range(0, forests.size() - 1)]]
	var burnt: Array[Vector2i] = []
	while not front.is_empty() and burnt.size() < events.fire_tiles():
		var cell: Vector2i = front.pop_front()
		if world_map.get_terrain(cell) != TerrainDef.Type.FOREST or not territory.is_territory(cell):
			continue
		production.burn(cell)
		burnt.append(cell)
		for o in WorldMap.NEIGHBORS_4:
			front.append(world_map.wrap_cell(cell + o))
	var shown: Array[Vector2i] = []
	for cell in burnt:
		shown.append(display_cell(cell))
	EventBus.tiles_changed.emit(shown)
	EventBus.zones_changed.emit(shown)
	_update_labor()
	return burnt.size()


## Ce qui empêche les décrets (vide : possible).
func decrees_error() -> String:
	if tier.level < DECREES_TIER:
		return "Disponible au palier %s" % CityTier.label(DECREES_TIER)
	return ""


## Humeur du jour : facteur de satisfaction des décrets.
func mood() -> float:
	if tier.level < DECREES_TIER:
		return 1.0
	return decrees.mood()


## Décret de rationnement ou de corvée.
func set_rationing(enabled: bool) -> void:
	if enabled and not decrees_error().is_empty():
		EventBus.notified.emit(decrees_error())
		return
	decrees.rationing = enabled
	EventBus.economy_changed.emit()


func set_corvee(enabled: bool) -> void:
	if enabled and not decrees_error().is_empty():
		EventBus.notified.emit(decrees_error())
		return
	decrees.corvee = enabled
	for c in cities:
		activate(c)
		population.active_share = Population.ACTIVE_SHARE + decrees.active_bonus()
		_update_labor()
	activate(selected)
	EventBus.population_changed.emit()
	EventBus.economy_changed.emit()


## Ce qui empêche une fête (vide : possible).
func feast_error() -> String:
	var error := decrees_error()
	if not error.is_empty():
		return error
	if not decrees.can_feast():
		return "Prochaine fête possible dans %d jours" % decrees.feast_cooldown
	var food := Decrees.feast_food(population.count)
	if not stockpile.has(Stockpile.Good.FOOD, food):
		return "Nourriture insuffisante (%d requis)" % roundi(food)
	return ""


## Donne une fête ; false (raison notifiée) si c'est impossible.
func hold_feast() -> bool:
	var error := feast_error()
	if not error.is_empty():
		EventBus.notified.emit(error)
		return false
	stockpile.take(Stockpile.Good.FOOD, Decrees.feast_food(population.count))
	decrees.start_feast()
	EventBus.notified.emit("Fête au bourg : la satisfaction grimpe pendant %d jours" % Decrees.FEAST_DAYS)
	EventBus.stocks_changed.emit()
	EventBus.economy_changed.emit()
	return true


## Groupes de villes reliées (stock commun), recalculés chaque jour : indices
## dans cities.
var _city_groups: Array[PackedInt32Array] = []


## Deux villes sont reliées si leurs routes ou leurs voies se touchent (ou
## touchent le bloc de l'autre), si elles ont chacune un port, ou chacune un
## aérodrome (cité-État).
func cities_linked(a: City, b: City) -> bool:
	if _networks_touch(a.roads.lengths, b) or _networks_touch(b.roads.lengths, a) \
			or _networks_touch(a.rails.reached, b) or _networks_touch(b.rails.reached, a):
		return true
	if _has_complete(a, &"harbor") and _has_complete(b, &"harbor"):
		return true
	return tier.level >= Exploration.PLANE_TIER and _has_complete(a, &"airfield") and _has_complete(b, &"airfield")


## Les tuiles [param tiles] d'un réseau touchent-elles le bloc ou le même
## réseau de [param other] ?
func _networks_touch(tiles: Dictionary, other: City) -> bool:
	var radius := other.buildings.block_radius + 1
	for cell: Vector2i in tiles:
		if other.roads.cheb(cell, other.home) <= radius:
			return true
		for o in WorldMap.NEIGHBORS_4:
			var n := world_map.wrap_cell(cell + o)
			if other.roads.lengths.has(n) or other.rails.reached.has(n):
				return true
	return false


static func _has_complete(c: City, flag: StringName) -> bool:
	return c.buildings.all().any(func(b: Building) -> bool: return b.is_complete() and b.def.get(flag))


## Recalcule les groupes de villes reliées.
func _link_cities() -> void:
	_city_groups.clear()
	var group_of: Array[int] = []
	group_of.resize(cities.size())
	group_of.fill(-1)
	for i in cities.size():
		if group_of[i] >= 0:
			continue
		var group := PackedInt32Array([i])
		group_of[i] = _city_groups.size()
		var k := 0
		while k < group.size():
			for j in cities.size():
				if group_of[j] < 0 and cities_linked(cities[group[k]], cities[j]):
					group_of[j] = group_of[i]
					group.append(j)
			k += 1
		_city_groups.append(group)


## Villes reliées à [param c] (elle comprise).
func linked_cities(c: City) -> Array[City]:
	var result: Array[City] = [c]
	for group in _city_groups:
		if cities.find(c) in group:
			result.clear()
			for i in group:
				result.append(cities[i])
	return result


## Stock commun des villes reliées : chaque marchandise est répartie entre
## elles au prorata de leurs capacités.
func _pool_stocks() -> void:
	for group in _city_groups:
		if group.size() < 2:
			continue
		for good in Stockpile.COUNT:
			var amount := 0.0
			var capacity := 0.0
			for i in group:
				amount += cities[i].stockpile.amount[good]
				capacity += cities[i].stockpile.capacity[good]
			if capacity <= 0.0:
				continue
			for i in group:
				var stock := cities[i].stockpile
				stock.amount[good] = amount * stock.capacity[good] / capacity if capacity > 0.0 else 0.0


## Le joueur choisit la ville [param c] : panneaux, carte de la ville et
## constructions portent sur elle.
func select_city(c: City) -> void:
	if c == selected or c not in cities:
		return
	selected = c
	activate(c)
	EventBus.city_selected.emit()
	EventBus.stocks_changed.emit()
	EventBus.population_changed.emit()
	EventBus.labor_changed.emit()
	EventBus.expeditions_changed.emit()


## Rend [param c] active : les variables de GameState et le territoire
## portent sur elle.
func activate(c: City) -> void:
	city = c
	if territory:
		territory.owner = c.id


func _on_tick(tick: int) -> void:
	_pool_stocks()
	for c in cities:
		activate(c)
		_city_tick(tick)
	activate(selected)
	var totals := Stockpile.zeros()
	var count := 0
	var active := 0
	var employed := 0
	var unemployed := 0
	for c in cities:
		count += c.population.count
		active += c.population.active()
		employed += c.labor.employed()
		unemployed += c.labor.unemployed()
		for good in Stockpile.COUNT:
			totals[good] += c.stockpile.amount[good]
	stats.add(&"population", count)
	stats.add(&"active", active)
	stats.add(&"employed", employed)
	stats.add(&"unemployed", unemployed)
	for good in Stockpile.COUNT:
		stats.add(Statistics.STOCK_KEYS[good], totals[good])
	stats.end_hour()


## Heure de la ville active : chantiers, expéditions, travail, production,
## consommation.
func _city_tick(tick: int) -> void:
	var completed := buildings.advance()
	completed.append_array(city_buildings.advance())
	if not completed.is_empty():
		_refresh_capacities()
	for b in completed:
		if b.def.flood_tiles > 0:
			flood_reservoir(b)
		EventBus.building_completed.emit(b)
	_step_expeditions()
	var before := [labor.employed(), labor.in_transit(), labor.assigned.duplicate()]
	_step_labor(tick)
	if before != [labor.employed(), labor.in_transit(), labor.assigned]:
		EventBus.labor_changed.emit()
	# L'heure écoulée est celle qui précède le tick.
	var report := production.step_hour(tick - 1, stockpile)
	if not report.cleared.is_empty() or not report.clearcut.is_empty():
		var shown: Array[Vector2i] = []
		for cell in report.cleared + report.clearcut:
			shown.append(display_cell(cell))
		EventBus.tiles_changed.emit(shown)
		EventBus.zones_changed.emit(shown)
		_update_labor()
	_consume(tick - 1)
	EventBus.stocks_changed.emit()


## Consommation de l'heure : besoins du jour répartis sur 24 h. Le chauffage
## suit heat_mix (bois, charbon, fioul, courant) ; ce que le charbon ou le
## carburant ne couvrent pas faute de stock est pris sur le bois.
func _consume(tick: int) -> void:
	var food: float = food_need() / GameDate.HOURS_PER_DAY
	_needed_today[Stockpile.Good.FOOD] += food
	_consumed_today[Stockpile.Good.FOOD] += stockpile.take(Stockpile.Good.FOOD, food)
	var season := GameDate.season(tick)
	var heat := heat_need(season) / GameDate.HOURS_PER_DAY
	var mix := heat_mix()
	var coal := stockpile.take(Stockpile.Good.COAL, heat * mix[Heat.COAL] / COAL_WOOD_EQUIVALENT)
	var fuel := stockpile.take(Stockpile.Good.FUEL, heat * mix[Heat.FUEL] / FUEL_WOOD_EQUIVALENT)
	coal_burned_today += coal
	fuel_burned_today += fuel
	var warm := coal * COAL_WOOD_EQUIVALENT + fuel * FUEL_WOOD_EQUIVALENT + heat * mix[Heat.ELECTRICITY]
	var wood := stockpile.take(Stockpile.Good.WOOD, maxf(0.0, heat - warm))
	wood_burned_today += wood
	_needed_today[Stockpile.Good.WOOD] += heat
	_consumed_today[Stockpile.Good.WOOD] += warm + wood


func _on_day(day: int) -> void:
	var day_tick := GameClock.tick - 1
	_link_cities()
	for c in cities:
		activate(c)
		_city_day(day_tick)
	activate(selected)
	decrees.end_day()
	for kind in events.end_day():
		EventBus.notified.emit("Fin de l'événement : %s" % CityEvents.NAMES[kind])
	if tier.level >= EVENTS_TIER:
		var target := cities[events.rng.randi_range(0, cities.size() - 1)]
		activate(target)
		_run_events(GameDate.season(day_tick))
		activate(selected)
	_survey()
	_check_star_city()
	if tier.update(total_population(), mean_satisfaction()):
		for c in cities:
			activate(c)
			exploration.tier = tier.level
			territory.tier = tier.level
			_prospect_territory()
			_refresh_capacities()
			_refresh_city_area()
		activate(selected)
		EventBus.notified.emit("Nouveau palier : %s (palier %d)" % [tier.name(), tier.level])
		if tier.level == CLOTHES_TIER:
			EventBus.notified.emit("Le bourg a besoin de vêtements : champs de lin, laine des pâturages, atelier de tissage")
		if tier.level == LIGHT_TIER:
			EventBus.notified.emit("La ville veut s'éclairer : puits de pétrole, réservoir et raffinerie (recherche Raffinage du pétrole)")
		if tier.level == SERVICES_TIER:
			EventBus.notified.emit("La ville veut des biens, des soins et de l'ordre : atelier d'artisans, dispensaire (recherche Médecine) et poste de garde")
		if tier.level == CITY_STATE_TIER:
			EventBus.notified.emit("La cité-État veut de l'électricité pour tous, des écoles et des théâtres ; uranium et lithium se prospectent")
		if tier.level == DECREES_TIER:
			EventBus.notified.emit("Le gouverneur du bourg prend des décrets (rationnement, corvée, fête) : panneau Décrets (E)")
		EventBus.tier_changed.emit()
	var points := 0.0
	for c in cities:
		activate(c)
		points += research_per_day()
	activate(selected)
	var finished := research.add_points(points)
	if finished:
		EventBus.notified.emit("Recherche terminée : %s" % finished.display_name)
		for c in cities:
			activate(c)
			_refresh_capacities()
		activate(selected)
	EventBus.research_changed.emit()
	_day_stats(day_tick, points)
	for c in cities:
		activate(c)
		production.reset_day()
		stockpile.reset_day()
		coal_burned_today = 0.0
		fuel_burned_today = 0.0
		wood_burned_today = 0.0
		_update_auto_priorities(GameClock.tick)
		_update_labor()
	activate(selected)
	EventBus.economy_changed.emit()
	EventBus.population_changed.emit()
	_check_milestones(day - 1)


## Journée de la ville active : stocks, ateliers, réseaux, besoins,
## habitants, chevaux.
func _city_day(day_tick: int) -> void:
	stockpile.end_day()
	var regrown := production.end_day(day_tick)
	for cell in regrown:
		EventBus.tiles_changed.emit([display_cell(cell)] as Array[Vector2i])
	if not regrown.is_empty():
		_update_labor()
	var coverage := PackedFloat32Array()
	for good in _needed_today.size():
		coverage.append(_consumed_today[good] / _needed_today[good] if _needed_today[good] > 0.0 else 1.0)
	_run_charcoal()
	_run_grid(day_tick)
	_run_forges()
	_run_weavers()
	_run_refineries()
	_run_artisans()
	_run_electronics()
	_run_cement()
	_run_enrichment()
	_run_space()
	_run_steam()
	_run_trains()
	_run_trucks()
	_run_tractors()
	var tools := _wear_tools()
	var clothes := _wear_clothes()
	var light := _burn_light()
	var goods := _wear_goods()
	var health := health_coverage()
	var order := order_coverage()
	var education := education_coverage()
	var culture := culture_coverage()
	pollution.end_day(coal_burned_today, fuel_burned_today, wood_burned_today)
	var before := population.count
	var change := population.end_day(coverage[Stockpile.Good.FOOD], coverage[Stockpile.Good.WOOD], housing,
		water_coverage(), tools, clothes, mood(), light, goods, health, order, education, culture, electricity_coverage(),
		pollution_harm())
	_announce_population(before, change, coverage)
	draft.breed(_pasture_quality())
	draft.end_day(coverage[Stockpile.Good.FOOD])
	city.last_coverage = {&"water": water_coverage(), &"clothes": clothes, &"light": light, &"electricity": grid.coverage,
		&"goods": goods, &"health": health, &"order": order, &"education": education, &"culture": culture,
		&"pollution": pollution_index(), &"coal_burned": coal_burned_today}
	_needed_today = Stockpile.zeros()
	_consumed_today = Stockpile.zeros()


## Palier de la ville active pour ses bâtiments : CityTier.STAR_TIER pour la
## capitale Cité des étoiles, sinon le palier commun.
func city_level() -> int:
	return CityTier.STAR_TIER if city.star else tier.level


## Palier des recherches : la Cité des étoiles ouvre celles du palier 6.
func research_level() -> int:
	return CityTier.STAR_TIER if not cities.is_empty() and cities[0].star else tier.level


## Nom du palier de la ville [param c] (la capitale peut être Cité des
## étoiles).
func tier_name(c: City = null) -> String:
	return CityTier.STAR_NAME if (c if c else city).star else tier.name()


## Ce qui manque à la capitale pour devenir Cité des étoiles (vide : atteint
## ou possible).
func star_city_missing() -> String:
	var capital := cities[0]
	if capital.star:
		return ""
	var missing := PackedStringArray()
	if not tier.is_max():
		missing.append("le palier %s" % CityTier.label(CityTier.NAMES.size()))
	if capital.population.count < CityTier.STAR_POPULATION:
		missing.append("%d habitants à %s (%d)" % [CityTier.STAR_POPULATION, capital.name, capital.population.count])
	if capital.population.satisfaction < CityTier.SATISFACTION_REQUIRED:
		missing.append("%d %% de satisfaction" % roundi(CityTier.SATISFACTION_REQUIRED * 100.0))
	if space.satellites < 1:
		missing.append("un satellite en orbite")
	return ", ".join(missing)


## La capitale devient Cité des étoiles si tout y est (une fois pour toutes).
func _check_star_city() -> void:
	var capital := cities[0]
	if capital.star or not star_city_missing().is_empty():
		return
	capital.star = true
	activate(capital)
	_refresh_city_area()
	activate(selected)
	EventBus.notified.emit("%s devient %s : la capitale s'ouvre à l'ère spatiale" % [capital.name, CityTier.STAR_NAME])
	EventBus.tier_changed.emit()


## Habitants de toutes les villes.
func total_population() -> int:
	var total := 0
	for c in cities:
		total += c.population.count
	return total


## Satisfaction moyenne des villes, pondérée par leurs habitants.
func mean_satisfaction() -> float:
	var total := total_population()
	if total <= 0:
		return selected.population.satisfaction
	var sum := 0.0
	for c in cities:
		sum += c.population.satisfaction * c.population.count
	return sum / total


## Statistiques du jour de la cité-État : production et pertes cumulées,
## couvertures moyennes pondérées par les habitants, puissance totale.
func _day_stats(day_tick: int, points: float) -> void:
	var produced := Stockpile.zeros()
	var extra := PackedFloat32Array([0.0, 0.0, 0.0, 0.0, 0.0, 0.0])
	var food_lost := 0.0
	var wood_lost := 0.0
	var horses := 0.0
	var owned := 0
	var weighted: Dictionary[StringName, float] = {}
	var total := maxi(1, total_population())
	for c in cities:
		activate(c)
		for good in Stockpile.COUNT:
			produced[good] += production.produced_today[good]
		var parts := [draft.working() * DraftAnimals.WORK_WATTS, _mill_watts(day_tick), grid.hydro, grid.wind_power, grid.solar,
			grid.fusion]
		for k in parts.size():
			extra[k] += parts[k]
		food_lost += stockpile.lost_today[Stockpile.Good.FOOD]
		wood_lost += stockpile.lost_today[Stockpile.Good.WOOD]
		horses += draft.horses
		owned += territory.count(Territory.State.TERRITORY)
		for key: StringName in c.last_coverage:
			var w := 1.0 if key == &"coal_burned" else float(c.population.count) / total
			weighted[key] = weighted.get(key, 0.0) + c.last_coverage[key] * w
	activate(selected)
	power.push_day(produced, extra)
	for good in Stockpile.COUNT:
		stats.add(Statistics.PRODUCED_KEYS[good], produced[good])
	stats.add(&"food_lost", food_lost)
	stats.add(&"wood_lost", wood_lost)
	stats.add(&"satisfaction", mean_satisfaction() * 100.0)
	stats.add(&"power", power.average())
	stats.add(&"power_per_capita", power.per_capita(total_population()))
	stats.add(&"territory", owned)
	stats.add(&"horses", horses)
	stats.add(&"research", points)
	stats.add(&"coal_burned", weighted.get(&"coal_burned", 0.0))
	for key: StringName in [&"water", &"clothes", &"light", &"electricity", &"goods", &"health", &"order", &"education",
			&"culture", &"pollution"]:
		stats.add(key, weighted.get(key, 0.0) * 100.0)
	stats.end_day()


func _announce_population(before: int, change: int, coverage: PackedFloat32Array) -> void:
	if coverage[Stockpile.Good.FOOD] < 1.0:
		EventBus.notified.emit("Disette : %d %% de la nourriture nécessaire" % roundi(coverage[Stockpile.Good.FOOD] * 100.0))
	elif coverage[Stockpile.Good.WOOD] < 1.0:
		EventBus.notified.emit("Manque de bois : %d %% du chauffage" % roundi(coverage[Stockpile.Good.WOOD] * 100.0))
	elif water_coverage() < 1.0 and GameClock.tick % (GameDate.HOURS_PER_DAY * 5) < GameDate.HOURS_PER_DAY:
		EventBus.notified.emit("Manque d'eau : %d %% des habitants servis, construisez des puits" % roundi(water_coverage() * 100.0))
	if population.count == 0 and before > 0:
		EventBus.notified.emit("Le hameau est déserté")
	elif change > 0 and population.count >= housing:
		EventBus.notified.emit("Population %d : plus de logement libre, construisez des maisons" % population.count)


func _check_milestones(day: int) -> void:
	var facts := Milestones.Facts.new()
	facts.stats = stats
	facts.buildings = []
	for c in cities:
		facts.buildings.append_array(c.buildings.all())
		facts.buildings.append_array(c.city_buildings.all())
	facts.day = day
	facts.population = total_population()
	facts.tier = tier.level
	facts.territory = 0
	for c in cities:
		territory.owner = c.id
		facts.territory += territory.count(Territory.State.TERRITORY)
	territory.owner = city.id
	facts.horses = draft.horses
	facts.water_coverage = water_coverage()
	facts.served_stations = rails.served.size()
	facts.clothes_coverage = population.clothes_coverage if tier.level >= CLOTHES_TIER else 0.0
	facts.research = research
	facts.grid_coverage = grid.coverage
	facts.nuclear_power = grid.nuclear
	facts.satellites = space.satellites
	var kinds: Array[int] = []
	for kind in space.kinds:
		if kind not in kinds:
			kinds.append(kind)
	facts.satellite_kinds = kinds.size()
	facts.star_city = cities[0].star
	facts.moon = space.moon_landed
	facts.surveyed = space.surveyed(world_map.size.x)
	facts.pollution = pollution_index()
	facts.green_share = (grid.hydro + grid.wind_power + grid.solar) / grid.demand if grid.demand > 0.0 else 0.0
	if tier.level >= SERVICES_TIER:
		facts.services_coverage = minf(population.goods_coverage, minf(population.health_coverage, population.order_coverage))
	for def in milestones.check(facts, day):
		EventBus.milestone_reached.emit(def)
		EventBus.notified.emit("Jalon atteint : %s — %s" % [def.display_name, def.description])
