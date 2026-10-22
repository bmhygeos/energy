extends Node
## État global de la partie en cours.

## Planète en longitude / latitude (tuiles), multiple de WorldMap.CHUNK_SIZE.
const PLANET_SIZE := Vector2i(1024, 512)

var world_map: WorldMap
## État des tuiles (inconnue, explorée, territoire) et gisements prospectés.
var territory: Territory
## Centre du village (abscisse ramenée sur la planète).
var home: Vector2i
var buildings: BuildingRegistry
## Zones peintes (agriculture, élevage, coupe du bois).
var zones: ZoneMap
var population: Population
## Répartition des actifs entre les zones.
var labor: Labor
var weather: Weather
## Historique journalier (graphiques) et jalons du bac à sable.
var stats: Statistics
var milestones: Milestones


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
	buildings = BuildingRegistry.new(world_map, territory)
	zones = ZoneMap.new(world_map, territory, buildings)
	population = Population.new()
	labor = Labor.new(zones, home)
	weather = Weather.new(seed_value)
	stats = Statistics.new()
	milestones = Milestones.new()
	GameClock.reset()
	labor.step(GameClock.tick, population.active())
	EventBus.game_started.emit(seed_value)


## Tuile [param cell] dans le repère de la vue : abscisse dépliée autour du
## village et décalée d'un tour de planète, donc toujours positive (les
## tuiles (-1, -1) restent libres pour dire « aucune tuile »).
func display_cell(cell: Vector2i) -> Vector2i:
	return world_map.unwrap_near(cell, home.x + world_map.size.x)


## Graine aléatoire lisible (6 chiffres).
static func random_seed() -> int:
	return randi_range(100_000, 999_999)


## Placement de [param def] en [param anchor] : règles du registre, et pas
## sur une zone (à effacer d'abord).
func check_placement(def: BuildingDef, anchor: Vector2i) -> BuildingRegistry.Placement:
	var placement := buildings.check_placement(def, anchor)
	if placement.is_valid():
		for cell in placement.cells:
			var zone := zones.zone_at(cell)
			if zone:
				placement.error = "Zone présente (%s) : effacez-la d'abord" % zone.display_name
				break
	return placement


## Aperçu de la peinture de [param def] (null : effacement) entre deux tuiles.
func plan_zones(def: ZoneDef, from: Vector2i, to: Vector2i) -> ZoneMap.Plan:
	return zones.plan(def, ZoneMap.rect_between(from, to))


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


func _update_labor() -> void:
	labor.step(GameClock.tick, population.active())
	EventBus.labor_changed.emit()


## Lance le chantier de [param def] en [param anchor] ; renvoie le bâtiment,
## ou null (raison notifiée) si le placement est invalide.
func build(def: BuildingDef, anchor: Vector2i) -> Building:
	var placement := check_placement(def, anchor)
	if not placement.is_valid():
		EventBus.notified.emit(placement.error)
		return null
	var b := buildings.place(placement)
	if not placement.cleared.is_empty():
		EventBus.tiles_changed.emit(placement.cleared)
	EventBus.building_placed.emit(b)
	return b


## Démolit le bâtiment présent en [param cell] ; false s'il n'y en a pas.
func demolish(cell: Vector2i) -> bool:
	var b := buildings.building_at(cell)
	if b == null:
		return false
	buildings.remove(b)
	EventBus.building_removed.emit(b)
	return true


func _on_tick(tick: int) -> void:
	for b in buildings.advance():
		EventBus.building_completed.emit(b)
	var before := [labor.employed(), labor.in_transit(), labor.assigned.duplicate()]
	labor.step(tick, population.active())
	if before != [labor.employed(), labor.in_transit(), labor.assigned]:
		EventBus.labor_changed.emit()
	stats.add(&"population", population.count)
	stats.add(&"active", population.active())
	stats.add(&"employed", labor.employed())
	stats.add(&"unemployed", labor.unemployed())
	stats.end_hour()


func _on_day(day: int) -> void:
	stats.end_day()
	_check_milestones(day - 1)


func _check_milestones(day: int) -> void:
	var facts := Milestones.Facts.new()
	facts.stats = stats
	facts.buildings = buildings.all()
	for def in milestones.check(facts, day):
		EventBus.milestone_reached.emit(def)
		EventBus.notified.emit("Jalon atteint : %s — %s" % [def.display_name, def.description])
