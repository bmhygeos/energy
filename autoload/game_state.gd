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
	weather = Weather.new(seed_value)
	stats = Statistics.new()
	milestones = Milestones.new()
	GameClock.reset()
	EventBus.game_started.emit(seed_value)


## Tuile [param cell] dans le repère de la vue : abscisse dépliée autour du
## village et décalée d'un tour de planète, donc toujours positive (les
## tuiles (-1, -1) restent libres pour dire « aucune tuile »).
func display_cell(cell: Vector2i) -> Vector2i:
	return world_map.unwrap_near(cell, home.x + world_map.size.x)


## Graine aléatoire lisible (6 chiffres).
static func random_seed() -> int:
	return randi_range(100_000, 999_999)


func check_placement(def: BuildingDef, anchor: Vector2i) -> BuildingRegistry.Placement:
	return buildings.check_placement(def, anchor)


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


func _on_tick(_tick: int) -> void:
	for b in buildings.advance():
		EventBus.building_completed.emit(b)


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
