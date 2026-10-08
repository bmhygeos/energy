extends Node
## Horloge de simulation à tick fixe, indépendante du rendu.
## Vitesses : pause (0), ×1, ×2, ×4 ; à ×1, 10 ticks/s (1 jour ≈ 2,4 s).

const TICKS_PER_SECOND := 10.0
const SPEEDS: PackedInt32Array = [0, 1, 2, 4]

var tick: int = 0
var speed: int = 1:
	set = set_speed

var _accumulator := TickAccumulator.new(TICKS_PER_SECOND)
var _speed_before_pause: int = 1


func _process(delta: float) -> void:
	advance(delta)


## Fait avancer l'horloge de [param delta] secondes réelles ; renvoie le
## nombre de ticks exécutés.
func advance(delta: float) -> int:
	var count := _accumulator.consume(delta, speed)
	for i in count:
		_step()
	return count


func set_speed(value: int) -> void:
	assert(value in SPEEDS, "Vitesse invalide : %d" % value)
	if value == speed:
		return
	if value == 0:
		_speed_before_pause = speed
	speed = value
	EventBus.speed_changed.emit(speed)


func toggle_pause() -> void:
	speed = _speed_before_pause if speed == 0 else 0


func is_paused() -> bool:
	return speed == 0


func reset() -> void:
	tick = 0
	_accumulator.reset()


func get_alpha() -> float:
	return _accumulator.get_alpha()


func _step() -> void:
	tick += 1
	EventBus.tick_advanced.emit(tick)
	if tick % GameDate.HOURS_PER_DAY == 0:
		EventBus.day_changed.emit(GameDate.day_index(tick))
	if tick % GameDate.HOURS_PER_SEASON == 0:
		EventBus.season_changed.emit(GameDate.season(tick), GameDate.year(tick))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("time_toggle_pause"):
		toggle_pause()
	elif event.is_action_pressed("time_speed_1"):
		speed = 1
	elif event.is_action_pressed("time_speed_2"):
		speed = 2
	elif event.is_action_pressed("time_speed_4"):
		speed = 4
	else:
		return
	get_viewport().set_input_as_handled()
