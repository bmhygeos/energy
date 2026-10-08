extends CanvasLayer
## Bandeau supérieur : date, argent, contrôle de la vitesse, FPS.

@onready var _date_label: Label = %DateLabel
@onready var _money_label: Label = %MoneyLabel
@onready var _fps_label: Label = %FpsLabel
@onready var _speed_buttons: Dictionary[int, Button] = {
	0: %PauseButton, 1: %Speed1Button, 2: %Speed2Button, 4: %Speed4Button,
}


func _ready() -> void:
	for value: int in _speed_buttons:
		_speed_buttons[value].pressed.connect(func() -> void: GameClock.speed = value)
	EventBus.tick_advanced.connect(_on_tick)
	EventBus.speed_changed.connect(_on_speed_changed)
	EventBus.money_changed.connect(_on_money_changed)
	_on_tick(GameClock.tick)
	_on_speed_changed(GameClock.speed)
	_on_money_changed(GameState.money)


func _process(_delta: float) -> void:
	_fps_label.text = "%d FPS" % Engine.get_frames_per_second()


func _on_tick(tick: int) -> void:
	_date_label.text = GameDate.format(tick)


func _on_speed_changed(speed: int) -> void:
	for value: int in _speed_buttons:
		_speed_buttons[value].button_pressed = value == speed


func _on_money_changed(money: int) -> void:
	_money_label.text = "%s €" % format_thousands(money)


## 1234567 → "1 234 567" (espace fine insécable, usage français).
static func format_thousands(value: int) -> String:
	var digits := str(absi(value))
	var groups := PackedStringArray()
	while digits.length() > 3:
		groups.insert(0, digits.right(3))
		digits = digits.left(-3)
	groups.insert(0, digits)
	return ("-" if value < 0 else "") + "\u202f".join(groups)
