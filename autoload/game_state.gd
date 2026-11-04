extends Node
## État global de la partie en cours.

## Planète en longitude / latitude (tuiles), multiple de WorldMap.CHUNK_SIZE.
const PLANET_SIZE := Vector2i(1024, 512)
## Palier à partir duquel les habitants ont besoin d'eau (puits).
const WATER_TIER := 2
## Forge : fer et bois par outil fabriqué.
const FORGE_IRON_PER_TOOL := 1.0
const FORGE_WOOD_PER_TOOL := 0.5
## Durée de vie d'un outil (scie, charrue) en jours de travail d'un habitant.
const TOOL_LIFE_DAYS := 60.0
## Outils : maisons moins chères en bois ; engrenage : puits plus efficaces.
const TOOLS_HOUSE_WOOD := 0.75
const GEARS_WATER_BONUS := 1.15
## Pompe à eau : puits plus efficaces.
const PUMP_WATER_BONUS := 1.5
## Palier à partir duquel les habitants ont besoin de vêtements et se
## chauffent aussi au charbon (bourg).
const CLOTHES_TIER := 3
const COAL_HEAT_TIER := 3
## Chauffage : part du bois remplaçable par le charbon, et bois remplacé par
## unité de charbon (290 MJ contre 150 MJ).
const COAL_HEAT_SHARE := 0.5
const COAL_WOOD_EQUIVALENT := 2.0
## Coke : les forges brûlent du charbon (même quantité que le bois) et
## fabriquent davantage.
const COKE_FORGE_BONUS := 1.5
## Atelier de tissage : fibres par vêtement.
const FIBER_PER_CLOTHES := 1.0
## Palier à partir duquel la cité lève l'impôt et prend des décrets (bourg).
const ECONOMY_TIER := 3
## Palier à partir duquel des événements frappent la cité (bourg).
const EVENTS_TIER := 3
## Palier à partir duquel les habitants s'éclairent au carburant (ville).
const LIGHT_TIER := 4
## Raffinerie : pétrole par unité de carburant.
const OIL_PER_FUEL := 1.0
## Palier à partir duquel la cité pose des routes (bourg).
const ROAD_TIER := 3

var world_map: WorldMap
## État des tuiles (inconnue, explorée, territoire) et gisements prospectés.
var territory: Territory
var exploration: Exploration
var research: Research
## Chevaux de trait (écuries).
var draft: DraftAnimals
## Centre du village (abscisse ramenée sur la planète).
var home: Vector2i
var buildings: BuildingRegistry
## Voies ferrées et gares desservies (bourg).
var rails: RailNetwork
## Routes (bourg).
var roads: RoadNetwork
## Zones peintes (agriculture, élevage, coupe du bois).
var zones: ZoneMap
var population: Population
## Palier de la ville (Hameau → Cité-État).
var tier: CityTier
## Répartition des actifs entre les zones.
var labor: Labor
## Stocks (nourriture, bois), production des zones, compteur de puissance.
var stockpile: Stockpile
var production: Production
var power: PowerMeter
var weather: Weather
## Pièces, impôts et commerce ; décrets du gouverneur (bourg).
var treasury: Treasury
var decrees: Decrees
## Événements en cours (hiver rude, sécheresse…).
var events: CityEvents
## Historique journalier (graphiques) et jalons du bac à sable.
var stats: Statistics
var milestones: Milestones
## Logements des maisons terminées.
var housing := 0
## Habitants approvisionnés en eau par les puits.
var water_supply := 0
## Charbon brûlé dans la journée en cours (chauffage, machines, convois).
var coal_burned_today := 0.0
## Machines à vapeur alimentées en charbon (la veille), et leurs bonus.
var steam_running := false
## Entretien payé la veille (sinon, universités à l'arrêt).
var upkeep_paid := true
var _steam_drive := 0.0
var _steam_mine := 0.0
var _water_drive := 0.0
## Besoins et consommation du jour en cours, par marchandise.
var _needed_today := Stockpile.zeros()
var _consumed_today := Stockpile.zeros()


func _ready() -> void:
	EventBus.tick_advanced.connect(_on_tick)
	EventBus.day_changed.connect(_on_day)
	new_game(random_seed())


func new_game(seed_value: int, size: Vector2i = PLANET_SIZE) -> void:
	Rng.set_seed(seed_value)
	world_map = WorldMap.new(size, seed_value)
	home = StartSite.find(world_map.generator)
	var rect := StartSite.territory_rect(home)
	StartSite.ensure(world_map, rect)
	territory = Territory.new(world_map)
	var cells: Array[Vector2i] = []
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			cells.append(Vector2i(x, y))
	territory.annex(cells)
	exploration = Exploration.new(territory)
	buildings = BuildingRegistry.new(world_map, territory)
	zones = ZoneMap.new(world_map, territory, buildings)
	rails = RailNetwork.new(world_map, territory, buildings, home)
	rails.zones = zones
	buildings.rails = rails
	roads = RoadNetwork.new(world_map, territory, buildings, home)
	roads.zones = zones
	buildings.roads = roads
	population = Population.new()
	tier = CityTier.new()
	labor = Labor.new(zones, home)
	labor.rails = rails
	labor.roads = roads
	stockpile = Stockpile.new()
	production = Production.new(zones, labor)
	research = Research.new()
	production.research = research
	draft = DraftAnimals.new()
	production.draft = draft
	power = PowerMeter.new()
	weather = Weather.new(seed_value)
	treasury = Treasury.new()
	decrees = Decrees.new()
	events = CityEvents.new(seed_value)
	production.events = events
	stats = Statistics.new()
	milestones = Milestones.new()
	milestones.defs = Milestones.standard()
	_needed_today = Stockpile.zeros()
	_consumed_today = Stockpile.zeros()
	GameClock.reset()
	_found_village()
	_refresh_capacities()
	_update_auto_priorities(0)
	_step_labor(GameClock.tick)
	EventBus.game_started.emit(seed_value)


## Bâtiments de départ, déjà construits au plus près du centre du village :
## un grenier et assez de maisons pour les habitants (repère de la vue,
## comme les bâtiments posés par le joueur).
func _found_village() -> void:
	var center := display_cell(home)
	var defs: Array[BuildingDef] = [BuildingDb.get_def(&"granary")]
	for k in ceili(float(Population.START) / BuildingDb.get_def(&"house").housing):
		defs.append(BuildingDb.get_def(&"house"))
	var rect := StartSite.territory_rect(center)
	var spots: Array[Vector2i] = []
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			spots.append(Vector2i(x, y))
	spots.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.distance_squared_to(center) < b.distance_squared_to(center))
	for def in defs:
		for spot in spots:
			var placement := buildings.check_placement(def, spot)
			# Sans défricher (la forêt du départ reste à couper) ni prendre la
			# colline des futures carrières ou le fer des futures mines.
			if placement.is_valid() and placement.cleared.is_empty() and not placement.cells.any(_reserved_at_start):
				var b := buildings.place(placement)
				b.build_progress = def.build_hours
				b.status = Building.Status.RUNNING
				break


## Tuile gardée pour les carrières (colline, montagne) ou les mines
## (gisement) du village, où ne pas poser les bâtiments de départ.
func _reserved_at_start(cell: Vector2i) -> bool:
	return world_map.get_terrain(cell) in [TerrainDef.Type.HILL, TerrainDef.Type.MOUNTAIN] \
		or world_map.get_deposit(cell) != WorldMap.Deposit.NONE


## Tuile [param cell] dans le repère de la vue : abscisse dépliée autour du
## village et décalée d'un tour de planète, donc toujours positive (les
## tuiles (-1, -1) restent libres pour dire « aucune tuile »).
func display_cell(cell: Vector2i) -> Vector2i:
	return world_map.unwrap_near(cell, home.x + world_map.size.x)


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
	return total


## Placement de [param def] (à son niveau construit, build_level) en
## [param anchor] : palier atteint, règles du registre, pas sur une zone (à
## effacer d'abord) et assez de matériaux.
func check_placement(def: BuildingDef, anchor: Vector2i) -> BuildingRegistry.Placement:
	var costs := build_costs(def)
	def = build_level(def)
	var placement := buildings.check_placement(def, anchor)
	if placement.is_valid() and def.tier > tier.level:
		placement.error = "Disponible au palier %s" % CityTier.NAMES[def.tier - 1]
	if placement.is_valid() and def.research and not research.is_done(def.research):
		placement.error = "Recherche requise : %s" % ResearchDb.get_def(def.research).display_name
	for good in costs.size():
		if placement.is_valid() and not stockpile.has(good, costs[good]):
			placement.error = "%s insuffisant%s (%d requis)" % [Stockpile.GOOD_NAMES[good],
				Stockpile.GOOD_AGREEMENT[good], roundi(costs[good])]
	if placement.is_valid():
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
		plan.error = "Disponible au palier %s" % CityTier.NAMES[def.tier - 1]
	return plan


## Peint ou efface selon [param plan] ; renvoie le nombre de tuiles changées.
func apply_zones(plan: ZoneMap.Plan) -> int:
	var changed := zones.apply(plan)
	if changed.is_empty() and plan.def and not plan.error.is_empty():
		EventBus.notified.emit(plan.error)
	if not changed.is_empty():
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
	var b := buildings.place(placement)
	if not placement.cleared.is_empty():
		EventBus.tiles_changed.emit(placement.cleared)
	EventBus.building_placed.emit(b)
	EventBus.stocks_changed.emit()
	return b


## Ce qui empêche d'améliorer [param b] (vide : possible).
func upgrade_error(b: Building) -> String:
	if b == null:
		return "Aucun bâtiment ici"
	var next := b.def.upgrade
	if next == null:
		return "%s : pas d'amélioration" % b.def.display_name
	if not b.is_complete():
		return "Chantier en cours"
	if next.tier > tier.level:
		return "%s : au palier %s" % [next.display_name, CityTier.NAMES[next.tier - 1]]
	if next.research and not research.is_done(next.research):
		return "Recherche requise : %s" % ResearchDb.get_def(next.research).display_name
	var costs := costs_of(next)
	for good in costs.size():
		if not stockpile.has(good, costs[good]):
			return "%s insuffisant%s (%d requis)" % [Stockpile.GOOD_NAMES[good],
				Stockpile.GOOD_AGREEMENT[good], roundi(costs[good])]
	return ""


## Améliore le bâtiment présent en [param cell] (chantier sur place) ; false
## (raison notifiée) si c'est impossible.
func upgrade(cell: Vector2i) -> bool:
	var b := buildings.building_at(cell)
	var error := upgrade_error(b)
	if not error.is_empty():
		EventBus.notified.emit(error)
		return false
	var next := b.def.upgrade
	var costs := costs_of(next)
	for good in costs.size():
		stockpile.take(good, costs[good])
	EventBus.building_removed.emit(b)
	b.start_upgrade(next)
	EventBus.building_placed.emit(b)
	EventBus.stocks_changed.emit()
	EventBus.notified.emit("Amélioration lancée : %s" % next.display_name)
	return true


## Démolit le bâtiment présent en [param cell], sinon la voie ferrée, sinon la
## route ; false s'il n'y a rien.
func demolish(cell: Vector2i) -> bool:
	var b := buildings.building_at(cell)
	if b == null:
		if rails.remove(cell):
			EventBus.rails_changed.emit([cell] as Array[Vector2i])
			_refresh_rails()
		elif roads.remove(cell):
			roads.refresh()
			EventBus.roads_changed.emit([cell] as Array[Vector2i])
		else:
			return false
		_update_labor()
		return true
	buildings.remove(b)
	_refresh_capacities()
	EventBus.building_removed.emit(b)
	return true


## Logements et capacités de stockage des bâtiments terminés.
func _refresh_capacities() -> void:
	housing = 0
	water_supply = 0
	var horse_capacity := 0
	var capacity := Stockpile.BASE_CAPACITY.duplicate()
	for b in buildings.all():
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
	for b in buildings.all():
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
	production.sawmill_bonus = sawmill
	production.mill_bonus = mill
	_water_drive = drive
	_steam_drive = steam_drive
	_steam_mine = steam_mine
	_apply_steam()
	_refresh_rails()
	production.wool = tier.level >= CLOTHES_TIER
	stockpile.spoilage_factor = 0.5 if mill > 0.0 else 1.0
	var trade := 0.0
	for b in buildings.all():
		if b.is_complete():
			trade += b.def.trade_per_day
	treasury.trade_capacity = trade
	draft.collar = research.is_done(&"harness_collar")


## Bonus des machines (moulin à eau ; machines à vapeur si alimentées).
func _apply_steam() -> void:
	production.drive_bonus = maxf(_water_drive, _steam_drive if steam_running else 0.0)
	production.mine_bonus = _steam_mine if steam_running else 0.0


## Charbon brûlé par jour par les machines à vapeur terminées.
func steam_coal_need() -> float:
	var total := 0.0
	for b in buildings.all():
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


## Gares desservies d'après les voies et les gares terminées.
func _refresh_rails() -> void:
	var stations: Array[Building] = []
	for b in buildings.all():
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


## Ce qui empêche de poser des voies (vide : possible).
func rails_error() -> String:
	var station := BuildingDb.get_def(&"station")
	if tier.level < station.tier:
		return "Disponible au palier %s" % CityTier.NAMES[station.tier - 1]
	if not research.is_done(station.research):
		return "Recherche requise : %s" % ResearchDb.get_def(station.research).display_name
	return ""


## Ce qui empêche de poser des routes (vide : possible).
func roads_error() -> String:
	if tier.level < ROAD_TIER:
		return "Disponible au palier %s" % CityTier.NAMES[ROAD_TIER - 1]
	return ""


## Aperçu d'un tracé de voie entre deux tuiles (repère de la vue) : palier,
## recherche, règles du réseau et matériaux.
func plan_rails(from: Vector2i, to: Vector2i) -> TrackNetwork.Plan:
	return _plan_track(rails, rails_error(), from, to)


func plan_roads(from: Vector2i, to: Vector2i) -> TrackNetwork.Plan:
	return _plan_track(roads, roads_error(), from, to)


func _plan_track(network: TrackNetwork, error: String, from: Vector2i, to: Vector2i) -> TrackNetwork.Plan:
	var p := network.plan(from, to)
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


## Lance une expédition de [param members] explorateurs et [param horses]
## chevaux de bât avec [param days] jours de vivres vers [param target]
## (repère de la vue) ; null (raison notifiée) si c'est impossible.
func launch_expedition(target: Vector2i, members: int, days: float, horses := 0) -> Exploration.Expedition:
	var error := expedition_error(members, days, horses)
	if error.is_empty() and exploration.plan_path(display_cell(home), target).size() < 2:
		error = "Trajet impossible : de l'eau barre le chemin"
	if not error.is_empty():
		EventBus.notified.emit(error)
		return null
	var food := members * days * Exploration.FOOD_PER_MEMBER_PER_DAY
	stockpile.take(Stockpile.Good.FOOD, food)
	var e := exploration.launch(display_cell(home), target, members, food)
	e.horses = horses
	e.speed = exploration.speed_for(members, horses)
	draft.away += horses
	EventBus.notified.emit("Expédition partie : %d explorateur%s%s, %s jours de vivres" % [
		members, "s" if members > 1 else "", " et %d cheva%s" % [horses, "ux" if horses > 1 else "l"] if horses > 0 else "",
		Format.decimal(days)])
	_update_labor()
	EventBus.stocks_changed.emit()
	EventBus.expeditions_changed.emit()
	return e


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
		draft.away = maxi(0, draft.away - e.horses)
		EventBus.notified.emit("L'expédition est rentrée : %d tuile%s découverte%s" % [
			e.revealed, "s" if e.revealed > 1 else "", "s" if e.revealed > 1 else ""])
	if not report.returned.is_empty():
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
	for b in buildings.all():
		if b.is_complete():
			rate += b.def.tools_per_day
	rate *= 1.0 + production.drive_bonus
	var fuel := Stockpile.Good.WOOD
	if research.is_done(&"coke") and stockpile.amount[Stockpile.Good.COAL] > 0.0:
		fuel = Stockpile.Good.COAL
		rate *= COKE_FORGE_BONUS
	var room := stockpile.capacity[Stockpile.Good.TOOLS] - stockpile.amount[Stockpile.Good.TOOLS]
	var n := minf(minf(rate, room), minf(stockpile.amount[Stockpile.Good.IRON] / FORGE_IRON_PER_TOOL,
		stockpile.amount[fuel] / FORGE_WOOD_PER_TOOL))
	if n <= 0.0:
		return
	stockpile.take(Stockpile.Good.IRON, n * FORGE_IRON_PER_TOOL)
	stockpile.take(fuel, n * FORGE_WOOD_PER_TOOL)
	stockpile.add(Stockpile.Good.TOOLS, n)
	production.produced_today[Stockpile.Good.TOOLS] += n


## Ateliers de tissage : fibres du jour transformées en vêtements, dans la
## limite du stock.
func _run_weavers() -> void:
	var rate := 0.0
	for b in buildings.all():
		if b.is_complete():
			rate += b.def.clothes_per_day
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
	for b in buildings.all():
		if b.is_complete():
			rate += b.def.fuel_per_day
	var room := stockpile.capacity[Stockpile.Good.FUEL] - stockpile.amount[Stockpile.Good.FUEL]
	var n := minf(minf(rate, room), stockpile.amount[Stockpile.Good.OIL] / OIL_PER_FUEL)
	if n <= 0.0:
		return
	stockpile.take(Stockpile.Good.OIL, n * OIL_PER_FUEL)
	stockpile.add(Stockpile.Good.FUEL, n)
	production.produced_today[Stockpile.Good.FUEL] += n


## Carburant des lampes par jour (à partir de la ville).
func light_need() -> float:
	return population.light_need() if tier.level >= LIGHT_TIER else 0.0


## Éclairage du jour : prend le carburant au stock ; renvoie la part obtenue
## (1 sans besoin).
func _burn_light() -> float:
	var need := light_need()
	if need <= 0.0:
		return 1.0
	return stockpile.take(Stockpile.Good.FUEL, need) / need


## Entretien par jour des bâtiments terminés (pièces).
func upkeep_need() -> float:
	var total := 0.0
	for b in buildings.all():
		if b.is_complete():
			total += b.def.upkeep_per_day
	return total


## Paie l'entretien du jour ; sans pièces, les bâtiments concernés s'arrêtent
## jusqu'au prochain paiement.
func _pay_upkeep() -> void:
	var need := upkeep_need()
	var was := upkeep_paid
	upkeep_paid = need <= 0.0 or treasury.pay_upkeep(need)
	if was and not upkeep_paid:
		EventBus.notified.emit("Trésor vide : l'université ferme ses portes faute d'entretien")


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
	for b in buildings.all():
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
	for b in buildings.all():
		if b.is_complete() and b.def.research_coverage > 0 and (upkeep_paid or b.def.upkeep_per_day <= 0.0):
			boosts.append(Vector2(b.def.research_multiplier, b.def.research_coverage))
	return Research.points_per_day(population.count, population.satisfaction, boosts)


## Lance la recherche [param def] ; false (raison notifiée) si indisponible.
func start_research(def: ResearchDef) -> bool:
	if not research.start(def, tier.level):
		EventBus.notified.emit("%s n'est pas disponible" % def.display_name)
		return false
	EventBus.research_changed.emit()
	return true


## Jours de réserve de nourriture et de bois au rythme actuel.
func food_days() -> float:
	return stockpile.days_of(Stockpile.Good.FOOD, food_need())


func wood_days() -> float:
	return stockpile.days_of(Stockpile.Good.WOOD, wood_need(GameDate.season(GameClock.tick)))


## Charbon brûlé par jour pour le chauffage pendant la saison [param season]
## (à partir du bourg, tant qu'il y en a en stock) : il remplace jusqu'à
## COAL_HEAT_SHARE du bois.
func coal_heat_need(season: int) -> float:
	if tier.level < COAL_HEAT_TIER or stockpile.amount[Stockpile.Good.COAL] <= 0.0:
		return 0.0
	return heat_need(season) * COAL_HEAT_SHARE / COAL_WOOD_EQUIVALENT


## Bois brûlé par jour pendant la saison [param season], le charbon déduit.
func wood_need(season: int) -> float:
	return heat_need(season) - coal_heat_need(season) * COAL_WOOD_EQUIVALENT


## Chauffage du jour pendant [param season], en bois (hiver rude compris).
func heat_need(season: int) -> float:
	return population.wood_need(season) * events.heat_factor()


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
	for kind in events.end_day():
		EventBus.notified.emit("Fin de l'événement : %s" % CityEvents.NAMES[kind])
	if tier.level < EVENTS_TIER:
		return
	var kind := events.roll(season)
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
	while not front.is_empty() and burnt.size() < CityEvents.FIRE_TILES:
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


## Ce qui empêche l'impôt et les décrets (vide : possible).
func economy_error() -> String:
	if tier.level < ECONOMY_TIER:
		return "Disponible au palier %s" % CityTier.NAMES[ECONOMY_TIER - 1]
	return ""


## Ce qui empêche le commerce (vide : possible).
func trade_error() -> String:
	var error := economy_error()
	if error.is_empty() and treasury.trade_capacity <= 0.0:
		error = "Construisez un marché pour commercer"
	return error


## Humeur du jour : facteur de satisfaction de l'impôt et des décrets.
func mood() -> float:
	if tier.level < ECONOMY_TIER:
		return 1.0
	return treasury.mood() * decrees.mood()


## Impôts du jour et vente des surplus (à partir du bourg).
func _run_economy() -> void:
	if tier.level < ECONOMY_TIER:
		return
	treasury.collect_taxes(population.count, population.satisfaction)
	treasury.sell_surplus(stockpile)
	_pay_upkeep()


func set_tax_level(level: int) -> void:
	treasury.tax_level = clampi(level, 0, Treasury.TAX_NAMES.size() - 1)
	EventBus.economy_changed.emit()


func set_auto_sell(good: int, enabled: bool) -> void:
	treasury.auto_sell[good] = enabled
	EventBus.economy_changed.emit()


## Achète (qty > 0) ou vend (qty < 0) au marché ; renvoie la quantité
## échangée (raison notifiée si aucune).
func trade(good: int, qty: float) -> float:
	var error := trade_error()
	var done := 0.0
	if error.is_empty():
		done = treasury.buy(stockpile, good, qty) if qty > 0.0 else treasury.sell(stockpile, good, -qty)
		if done <= 0.0:
			if treasury.trade_left() <= 0.0:
				error = "Les marchands ont tout échangé aujourd'hui"
			elif qty < 0.0:
				error = "%s : rien à vendre" % Stockpile.GOOD_NAMES[good]
			elif stockpile.amount[good] >= stockpile.capacity[good]:
				error = "%s : stock plein" % Stockpile.GOOD_NAMES[good]
			else:
				error = "Pas assez de pièces"
	if not error.is_empty():
		EventBus.notified.emit(error)
		return 0.0
	EventBus.stocks_changed.emit()
	EventBus.economy_changed.emit()
	return done


## Décret de rationnement ou de corvée.
func set_rationing(enabled: bool) -> void:
	if enabled and not economy_error().is_empty():
		EventBus.notified.emit(economy_error())
		return
	decrees.rationing = enabled
	EventBus.economy_changed.emit()


func set_corvee(enabled: bool) -> void:
	if enabled and not economy_error().is_empty():
		EventBus.notified.emit(economy_error())
		return
	decrees.corvee = enabled
	population.active_share = Population.ACTIVE_SHARE + decrees.active_bonus()
	_update_labor()
	EventBus.population_changed.emit()
	EventBus.economy_changed.emit()


## Ce qui empêche une fête (vide : possible).
func feast_error() -> String:
	var error := economy_error()
	if not error.is_empty():
		return error
	if not decrees.can_feast():
		return "Prochaine fête possible dans %d jours" % decrees.feast_cooldown
	var food := Decrees.feast_food(population.count)
	if not stockpile.has(Stockpile.Good.FOOD, food):
		return "Nourriture insuffisante (%d requis)" % roundi(food)
	var money := Decrees.feast_money(population.count)
	if treasury.money < money:
		return "Pièces insuffisantes (%d requises)" % roundi(money)
	return ""


## Donne une fête ; false (raison notifiée) si c'est impossible.
func hold_feast() -> bool:
	var error := feast_error()
	if not error.is_empty():
		EventBus.notified.emit(error)
		return false
	stockpile.take(Stockpile.Good.FOOD, Decrees.feast_food(population.count))
	treasury.money -= Decrees.feast_money(population.count)
	decrees.start_feast()
	EventBus.notified.emit("Fête au bourg : la satisfaction grimpe pendant %d jours" % Decrees.FEAST_DAYS)
	EventBus.stocks_changed.emit()
	EventBus.economy_changed.emit()
	return true


func _on_tick(tick: int) -> void:
	var completed := buildings.advance()
	if not completed.is_empty():
		_refresh_capacities()
	for b in completed:
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
	stats.add(&"population", population.count)
	stats.add(&"active", population.active())
	stats.add(&"employed", labor.employed())
	stats.add(&"unemployed", labor.unemployed())
	for good in Stockpile.COUNT:
		stats.add(Statistics.STOCK_KEYS[good], stockpile.amount[good])
	stats.end_hour()


## Consommation de l'heure : besoins du jour répartis sur 24 h. Au bourg, le
## charbon en stock chauffe une partie des maisons à la place du bois.
func _consume(tick: int) -> void:
	var food: float = food_need() / GameDate.HOURS_PER_DAY
	_needed_today[Stockpile.Good.FOOD] += food
	_consumed_today[Stockpile.Good.FOOD] += stockpile.take(Stockpile.Good.FOOD, food)
	var season := GameDate.season(tick)
	var heat := heat_need(season) / GameDate.HOURS_PER_DAY
	var coal := stockpile.take(Stockpile.Good.COAL, coal_heat_need(season) / GameDate.HOURS_PER_DAY)
	coal_burned_today += coal
	_needed_today[Stockpile.Good.WOOD] += heat
	_consumed_today[Stockpile.Good.WOOD] += coal * COAL_WOOD_EQUIVALENT \
		+ stockpile.take(Stockpile.Good.WOOD, heat - coal * COAL_WOOD_EQUIVALENT)


func _on_day(day: int) -> void:
	var day_tick := GameClock.tick - 1
	stockpile.end_day()
	var regrown := production.end_day(day_tick)
	for cell in regrown:
		EventBus.tiles_changed.emit([display_cell(cell)] as Array[Vector2i])
	if not regrown.is_empty():
		_update_labor()
	var coverage := PackedFloat32Array()
	for good in _needed_today.size():
		coverage.append(_consumed_today[good] / _needed_today[good] if _needed_today[good] > 0.0 else 1.0)
	_run_forges()
	_run_weavers()
	_run_refineries()
	_run_steam()
	_run_trains()
	var tools := _wear_tools()
	var clothes := _wear_clothes()
	var light := _burn_light()
	_run_economy()
	var before := population.count
	var change := population.end_day(coverage[Stockpile.Good.FOOD], coverage[Stockpile.Good.WOOD], housing,
		water_coverage(), tools, clothes, mood(), light)
	decrees.end_day()
	_run_events(GameDate.season(day_tick))
	_announce_population(before, change, coverage)
	if tier.update(population.count, population.satisfaction):
		exploration.tier = tier.level
		territory.tier = tier.level
		_prospect_territory()
		_refresh_capacities()
		EventBus.notified.emit("Nouveau palier : %s (palier %d)" % [tier.name(), tier.level])
		if tier.level == CLOTHES_TIER:
			EventBus.notified.emit("Le bourg a besoin de vêtements : champs de lin, laine des pâturages, atelier de tissage")
		if tier.level == LIGHT_TIER:
			EventBus.notified.emit("La ville veut s'éclairer : puits de pétrole, réservoir et raffinerie (recherche Raffinage du pétrole)")
		if tier.level == ECONOMY_TIER:
			EventBus.notified.emit("Le bourg lève l'impôt : trésor, marché et décrets dans le panneau Économie (E)")
		EventBus.tier_changed.emit()
	var points := research_per_day()
	var finished := research.add_points(points)
	if finished:
		EventBus.notified.emit("Recherche terminée : %s" % finished.display_name)
		_refresh_capacities()
	EventBus.research_changed.emit()
	draft.breed(_pasture_quality())
	draft.end_day(coverage[Stockpile.Good.FOOD])
	power.push_day(production.produced_today, PackedFloat32Array([draft.working() * DraftAnimals.WORK_WATTS,
		_mill_watts(day_tick)]))
	for good in Stockpile.COUNT:
		stats.add(Statistics.PRODUCED_KEYS[good], production.produced_today[good])
	stats.add(&"food_lost", stockpile.lost_today[Stockpile.Good.FOOD])
	stats.add(&"wood_lost", stockpile.lost_today[Stockpile.Good.WOOD])
	stats.add(&"satisfaction", population.satisfaction * 100.0)
	stats.add(&"power", power.average())
	stats.add(&"power_per_capita", power.per_capita(population.count))
	stats.add(&"territory", territory.count(Territory.State.TERRITORY))
	stats.add(&"horses", draft.horses)
	stats.add(&"water", water_coverage() * 100.0)
	stats.add(&"research", points)
	stats.add(&"coal_burned", coal_burned_today)
	stats.add(&"clothes", clothes * 100.0)
	stats.add(&"light", light * 100.0)
	stats.add(&"money", treasury.money)
	stats.add(&"taxes", treasury.taxes_today)
	stats.add(&"trade", treasury.sales_today - treasury.purchases_today)
	treasury.reset_day()
	EventBus.economy_changed.emit()
	coal_burned_today = 0.0
	stats.end_day()
	production.reset_day()
	stockpile.reset_day()
	_needed_today = Stockpile.zeros()
	_consumed_today = Stockpile.zeros()
	_update_auto_priorities(GameClock.tick)
	_update_labor()
	EventBus.population_changed.emit()
	_check_milestones(day - 1)


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
	facts.buildings = buildings.all()
	facts.day = day
	facts.population = population.count
	facts.tier = tier.level
	facts.territory = territory.count(Territory.State.TERRITORY)
	facts.horses = draft.horses
	facts.water_coverage = water_coverage()
	facts.served_stations = rails.served.size()
	facts.clothes_coverage = population.clothes_coverage if tier.level >= CLOTHES_TIER else 0.0
	facts.research = research
	facts.money = treasury.money
	for def in milestones.check(facts, day):
		EventBus.milestone_reached.emit(def)
		EventBus.notified.emit("Jalon atteint : %s — %s" % [def.display_name, def.description])
