extends Node
## État global de la partie en cours.

## Planète en longitude / latitude (tuiles), multiple de WorldMap.CHUNK_SIZE.
const PLANET_SIZE := Vector2i(1024, 512)
## Palier à partir duquel les habitants ont besoin d'eau (puits).
const WATER_TIER := 2

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
## Historique journalier (graphiques) et jalons du bac à sable.
var stats: Statistics
var milestones: Milestones
## Logements des maisons terminées.
var housing := 0
## Habitants approvisionnés en eau par les puits.
var water_supply := 0
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
	population = Population.new()
	tier = CityTier.new()
	labor = Labor.new(zones, home)
	stockpile = Stockpile.new()
	production = Production.new(zones, labor)
	research = Research.new()
	production.research = research
	draft = DraftAnimals.new()
	production.draft = draft
	power = PowerMeter.new()
	weather = Weather.new(seed_value)
	stats = Statistics.new()
	milestones = Milestones.new()
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
			# Sans défricher : la forêt du départ reste à couper.
			if placement.is_valid() and placement.cleared.is_empty():
				var b := buildings.place(placement)
				b.build_progress = def.build_hours
				b.status = Building.Status.RUNNING
				break


## Tuile [param cell] dans le repère de la vue : abscisse dépliée autour du
## village et décalée d'un tour de planète, donc toujours positive (les
## tuiles (-1, -1) restent libres pour dire « aucune tuile »).
func display_cell(cell: Vector2i) -> Vector2i:
	return world_map.unwrap_near(cell, home.x + world_map.size.x)


## Graine aléatoire lisible (6 chiffres).
static func random_seed() -> int:
	return randi_range(100_000, 999_999)


## Placement de [param def] en [param anchor] : palier atteint, règles du
## registre, pas sur une zone (à effacer d'abord) et assez de matériaux.
func check_placement(def: BuildingDef, anchor: Vector2i) -> BuildingRegistry.Placement:
	var placement := buildings.check_placement(def, anchor)
	if placement.is_valid() and def.tier > tier.level:
		placement.error = "Disponible au palier %s" % CityTier.NAMES[def.tier - 1]
	var costs := def.costs()
	for good in costs.size():
		if placement.is_valid() and not stockpile.has(good, costs[good]):
			placement.error = "%s insuffisant%s (%d requis)" % [Stockpile.GOOD_NAMES[good],
				"e" if good == Stockpile.Good.STONE else "", roundi(costs[good])]
	if placement.is_valid():
		for cell in placement.cells:
			var zone := zones.zone_at(cell)
			if zone:
				placement.error = "Zone présente (%s) : effacez-la d'abord" % zone.display_name
				break
	return placement


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
	var costs := def.costs()
	for good in costs.size():
		stockpile.take(good, costs[good])
	var b := buildings.place(placement)
	if not placement.cleared.is_empty():
		EventBus.tiles_changed.emit(placement.cleared)
	EventBus.building_placed.emit(b)
	EventBus.stocks_changed.emit()
	return b


## Démolit le bâtiment présent en [param cell] ; false s'il n'y en a pas.
func demolish(cell: Vector2i) -> bool:
	var b := buildings.building_at(cell)
	if b == null:
		return false
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
		if b.is_complete():
			housing += b.def.housing
			water_supply += b.def.water_supply
			horse_capacity += b.def.horse_capacity
			capacity[Stockpile.Good.FOOD] += b.def.food_capacity
			capacity[Stockpile.Good.WOOD] += b.def.wood_capacity
	stockpile.capacity = capacity
	draft.capacity = horse_capacity


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
	return maxf(0.0, population.food_need() - exploration.members_out() * Exploration.FOOD_PER_MEMBER_PER_DAY) \
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
	draft.away += horses
	EventBus.notified.emit("Expédition partie : %d explorateur%s%s, %s jours de vivres" % [
		members, "s" if members > 1 else "", " et %d cheva%s" % [horses, "ux" if horses > 1 else "l"] if horses > 0 else "",
		Format.decimal(days)])
	_update_labor()
	EventBus.stocks_changed.emit()
	EventBus.expeditions_changed.emit()
	return e


## Jours de vivres que portent [param members] explorateurs et
## [param horses] chevaux de bât (chacun porte DraftAnimals.PACK_FACTOR fois
## la charge d'un explorateur).
func max_expedition_days(members: int, horses: int) -> float:
	if members <= 0:
		return 0.0
	return exploration.max_days() * (members + DraftAnimals.PACK_FACTOR * horses) / members


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
		if b.is_complete() and b.def.research_coverage > 0:
			boosts.append(Vector2(b.def.research_multiplier, b.def.research_coverage))
	return Research.points_per_day(population.count, population.satisfaction, boosts)


## Lance la recherche [param def] ; false (raison notifiée) si indisponible.
func start_research(def: ResearchDef) -> bool:
	if not research.start(def, tier.level):
		EventBus.notified.emit("%s n'est pas disponible" % def.display_name)
		return false
	EventBus.research_changed.emit()
	return true


## Tuiles encore annexables (surface permise par la population).
func annex_room() -> int:
	return maxi(0, population.count * Territory.TILES_PER_INHABITANT - territory.count(Territory.State.TERRITORY))


## Annexion du rectangle de [param from] à [param to] (repère de la vue),
## limitée par la surface que permet la population (sans coût).
func plan_annex(from: Vector2i, to: Vector2i) -> Territory.AnnexPlan:
	return territory.plan_annex(ZoneMap.rect_between(from, to), annex_room())


## Annexe les tuiles de [param plan] ; renvoie leur nombre.
func apply_annex(plan: Territory.AnnexPlan) -> int:
	if plan.cells.is_empty():
		if not plan.error.is_empty():
			EventBus.notified.emit("Annexion impossible : " + plan.error)
		return 0
	var n := plan.cells.size()
	territory.annex(plan.cells)
	EventBus.tiles_changed.emit(plan.cells)
	EventBus.territory_changed.emit()
	EventBus.notified.emit("%d tuile%s annexée%s" % [n, "s" if n > 1 else "", "s" if n > 1 else ""])
	return n


## Jours de réserve de nourriture et de bois au rythme actuel.
func food_days() -> float:
	return stockpile.days_of(Stockpile.Good.FOOD, food_need())


func wood_days() -> float:
	return stockpile.days_of(Stockpile.Good.WOOD, population.wood_need(GameDate.season(GameClock.tick)))


## Priorités automatiques d'après les stocks. La nourriture doit tenir
## jusqu'aux prochaines récoltes ; en automne, le bois doit couvrir l'hiver
## entier. Ces réserves visées sont plafonnées par la capacité des stocks :
## au-delà, viser plus ne servirait à rien et priverait l'autre activité.
func _update_auto_priorities(tick: int) -> void:
	var season := GameDate.season(tick)
	var food_goal := food_need() * maxf(Labor.FOOD_ALERT_DAYS, lean_days(tick))
	var wood_goal := population.wood_need(GameDate.season(tick)) * Labor.WOOD_ALERT_DAYS
	if season == GameDate.WINTER - 1:
		wood_goal = maxf(wood_goal, population.wood_need(GameDate.WINTER) * GameDate.DAYS_PER_SEASON)
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
	if not report.cleared.is_empty():
		var shown: Array[Vector2i] = []
		for cell in report.cleared:
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
	stats.add(&"food_stock", stockpile.amount[Stockpile.Good.FOOD])
	stats.add(&"wood_stock", stockpile.amount[Stockpile.Good.WOOD])
	stats.end_hour()


## Consommation de l'heure : besoins du jour répartis sur 24 h.
func _consume(tick: int) -> void:
	var needs := [food_need(), population.wood_need(GameDate.season(tick))]
	for good in needs.size():
		var want: float = needs[good] / GameDate.HOURS_PER_DAY
		_needed_today[good] += want
		_consumed_today[good] += stockpile.take(good, want)


func _on_day(day: int) -> void:
	var day_tick := GameClock.tick - 1
	stockpile.end_day()
	for cell in production.end_day(day_tick):
		EventBus.tiles_changed.emit([display_cell(cell)] as Array[Vector2i])
	var coverage := PackedFloat32Array()
	for good in _needed_today.size():
		coverage.append(_consumed_today[good] / _needed_today[good] if _needed_today[good] > 0.0 else 1.0)
	var before := population.count
	var change := population.end_day(coverage[Stockpile.Good.FOOD], coverage[Stockpile.Good.WOOD], housing,
		water_coverage())
	_announce_population(before, change, coverage)
	if tier.update(population.count, population.satisfaction):
		exploration.tier = tier.level
		EventBus.notified.emit("Nouveau palier : %s (palier %d)" % [tier.name(), tier.level])
		EventBus.tier_changed.emit()
	var finished := research.add_points(research_per_day())
	if finished:
		EventBus.notified.emit("Recherche terminée : %s" % finished.display_name)
	EventBus.research_changed.emit()
	draft.breed(_pasture_quality())
	draft.end_day(coverage[Stockpile.Good.FOOD])
	power.push_day(production.produced_today, draft.working() * DraftAnimals.WORK_WATTS)
	stats.add(&"food_produced", production.produced_today[Stockpile.Good.FOOD])
	stats.add(&"wood_produced", production.produced_today[Stockpile.Good.WOOD])
	stats.add(&"food_lost", stockpile.lost_today[Stockpile.Good.FOOD])
	stats.add(&"wood_lost", stockpile.lost_today[Stockpile.Good.WOOD])
	stats.add(&"satisfaction", population.satisfaction * 100.0)
	stats.add(&"power", power.average())
	stats.add(&"power_per_capita", power.per_capita(population.count))
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
	for def in milestones.check(facts, day):
		EventBus.milestone_reached.emit(def)
		EventBus.notified.emit("Jalon atteint : %s — %s" % [def.display_name, def.description])
