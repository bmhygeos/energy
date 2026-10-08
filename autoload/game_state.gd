extends Node
## État global de la partie en cours.

const DEFAULT_MAP_SIZE := Vector2i(64, 64)
const DEFAULT_START_MONEY := 50_000

var map_size: Vector2i = DEFAULT_MAP_SIZE
var world_map: WorldMap
var money: int = DEFAULT_START_MONEY:
	set(value):
		money = value
		EventBus.money_changed.emit(money)


func _ready() -> void:
	new_game(random_seed())


func new_game(seed_value: int, size: Vector2i = DEFAULT_MAP_SIZE,
		start_money: int = DEFAULT_START_MONEY) -> void:
	Rng.set_seed(seed_value)
	map_size = size
	world_map = MapGenerator.generate(size, seed_value)
	money = start_money
	GameClock.reset()
	EventBus.game_started.emit(seed_value)


## Graine aléatoire lisible (6 chiffres).
static func random_seed() -> int:
	return randi_range(100_000, 999_999)
