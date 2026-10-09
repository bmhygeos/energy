extends Node
## État global de la partie en cours.

const DEFAULT_MAP_SIZE := Vector2i(64, 64)
const DEFAULT_START_MONEY := 50_000

var map_size: Vector2i = DEFAULT_MAP_SIZE
var world_map: WorldMap
var buildings: BuildingRegistry
var money: int = DEFAULT_START_MONEY:
	set(value):
		money = value
		EventBus.money_changed.emit(money)


func _ready() -> void:
	EventBus.tick_advanced.connect(_on_tick)
	EventBus.day_changed.connect(_on_day)
	new_game(random_seed())


func new_game(seed_value: int, size: Vector2i = DEFAULT_MAP_SIZE,
		start_money: int = DEFAULT_START_MONEY) -> void:
	Rng.set_seed(seed_value)
	map_size = size
	world_map = MapGenerator.generate(size, seed_value)
	buildings = BuildingRegistry.new(world_map)
	money = start_money
	GameClock.reset()
	EventBus.game_started.emit(seed_value)


## Graine aléatoire lisible (6 chiffres).
static func random_seed() -> int:
	return randi_range(100_000, 999_999)


## Vérifie le placement de [param def] en [param anchor] avec l'argent actuel.
func check_placement(def: BuildingDef, anchor: Vector2i) -> BuildingRegistry.Placement:
	return buildings.check_placement(def, anchor, money)


## Lance le chantier de [param def] en [param anchor] et le paie ; renvoie
## le bâtiment, ou null (raison notifiée) si le placement est invalide.
func build(def: BuildingDef, anchor: Vector2i) -> Building:
	var placement := check_placement(def, anchor)
	if not placement.is_valid():
		EventBus.notified.emit(placement.error)
		return null
	money -= def.cost
	var b := buildings.place(placement)
	if not placement.cleared.is_empty():
		EventBus.tiles_changed.emit(placement.cleared)
	EventBus.building_placed.emit(b)
	return b


## Démolit le bâtiment présent en [param cell] et rembourse une part de son
## coût ; renvoie la somme remboursée (-1 s'il n'y a rien à démolir).
func demolish(cell: Vector2i) -> int:
	var b := buildings.building_at(cell)
	if b == null:
		return -1
	var refund := BuildingRegistry.refund_for(b)
	buildings.remove(b)
	money += refund
	EventBus.building_removed.emit(b)
	return refund


func _on_tick(_tick: int) -> void:
	for b in buildings.advance():
		EventBus.building_completed.emit(b)


func _on_day(_day: int) -> void:
	var upkeep := buildings.daily_upkeep()
	if upkeep > 0:
		money -= upkeep
