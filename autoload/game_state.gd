extends Node
## État global de la partie en cours.

const DEFAULT_MAP_SIZE := Vector2i(64, 64)

var map_size: Vector2i = DEFAULT_MAP_SIZE
var world_map: WorldMap
var buildings: BuildingRegistry
var weather: Weather
## Historique journalier (graphiques) et jalons du bac à sable.
var stats: Statistics
var milestones: Milestones


func _ready() -> void:
	EventBus.tick_advanced.connect(_on_tick)
	EventBus.day_changed.connect(_on_day)
	new_game(random_seed())


func new_game(seed_value: int, size: Vector2i = DEFAULT_MAP_SIZE) -> void:
	Rng.set_seed(seed_value)
	map_size = size
	world_map = MapGenerator.generate(size, seed_value)
	buildings = BuildingRegistry.new(world_map)
	weather = Weather.new(seed_value)
	stats = Statistics.new()
	milestones = Milestones.new()
	GameClock.reset()
	EventBus.game_started.emit(seed_value)


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
