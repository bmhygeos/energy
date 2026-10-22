extends CanvasLayer
## Bandeau supérieur (date, météo, vitesse, graine) et sélecteur de calque
## d'information en bas à droite.

const LEGENDS: PackedStringArray = [
	"",
	"Altitude : basse → haute",
	"Potentiel éolien : faible → fort",
	"Ensoleillement : faible → fort",
	"[color=#3fa0ff]■[/color] accès à l'eau   [color=#1a59d9]■[/color] côte   [color=#c04030]■[/color] sans eau",
	"[color=#1a1a1a]■[/color] charbon   [color=#4be03c]■[/color] uranium   [color=#c45cff]■[/color] lithium",
]

## Info-bulles des calques (par OverlayLayer.Mode).
const OVERLAY_TIPS: PackedStringArray = [
	"Aucun calque (O pour faire défiler)",
	"Altitude : repérer collines et montagnes",
	"Potentiel éolien : plus fort sur les côtes et les crêtes",
	"Ensoleillement : plus fort dans les déserts",
	"Accès à l'eau : tuiles bordant une rivière, un lac ou la mer",
	"Gisements de charbon, d'uranium et de lithium",
]

var _overlay_mode := OverlayLayer.Mode.NONE
var _overlay_buttons: Array[Button] = []

@onready var _date_label: Label = %DateLabel
@onready var _weather_label: Label = %WeatherLabel
@onready var _seed_edit: LineEdit = %SeedEdit
@onready var _legend: RichTextLabel = %Legend
@onready var _legend_gradient: TextureRect = %LegendGradient
@onready var _speed_buttons: Dictionary[int, Button] = {
	0: %PauseButton, 1: %Speed1Button, 2: %Speed2Button, 4: %Speed4Button,
}


func _ready() -> void:
	for value: int in _speed_buttons:
		_speed_buttons[value].pressed.connect(func() -> void: GameClock.speed = value)
	_build_overlay_buttons()
	%GenerateButton.pressed.connect(_on_generate_pressed)
	_seed_edit.text_submitted.connect(func(_t: String) -> void: _on_generate_pressed())
	%RandomButton.pressed.connect(func() -> void: GameState.new_game(GameState.random_seed()))
	EventBus.tick_advanced.connect(_on_tick)
	EventBus.speed_changed.connect(_on_speed_changed)
	EventBus.game_started.connect(_on_game_started)
	EventBus.overlay_changed.connect(_on_overlay_changed)
	%StatsButton.pressed.connect(func() -> void: get_node("../StatsWindow").toggle())
	_on_tick(GameClock.tick)
	_on_speed_changed(GameClock.speed)
	_on_game_started(Rng.seed_value)
	_on_overlay_changed(_overlay_mode)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("overlay_cycle"):
		EventBus.overlay_changed.emit((_overlay_mode + 1) % OverlayLayer.Mode.size())
		get_viewport().set_input_as_handled()


func _build_overlay_buttons() -> void:
	var group := ButtonGroup.new()
	for mode in OverlayLayer.Mode.size():
		var button := Button.new()
		button.text = OverlayLayer.MODE_NAMES[mode]
		button.toggle_mode = true
		button.button_group = group
		button.focus_mode = Control.FOCUS_NONE
		button.tooltip_text = OVERLAY_TIPS[mode]
		button.pressed.connect(func() -> void: EventBus.overlay_changed.emit(mode))
		%OverlayButtons.add_child(button)
		_overlay_buttons.append(button)


## Graine saisie : un entier tel quel, sinon le hachage du texte.
func _on_generate_pressed() -> void:
	var text := _seed_edit.text.strip_edges()
	if text.is_empty():
		return
	GameState.new_game(text.to_int() if text.is_valid_int() else hash(text))
	_seed_edit.release_focus()


func _on_tick(tick: int) -> void:
	_date_label.text = GameDate.format(tick)
	if GameDate.hour_of_day(tick) == 0 or _date_label.tooltip_text.is_empty():
		_date_label.tooltip_text = _date_tooltip(tick)
	var weather := GameState.weather
	if weather == null:
		return
	_weather_label.text = weather.sky(tick)
	_weather_label.tooltip_text = "Météo : %s\nVent : %d %% de la normale\nNébulosité : %d %%\nLumière du jour : %d %%" % [
		weather.describe(tick), roundi(weather.wind_at(tick) * 100.0),
		roundi(weather.cloud_at(tick) * 100.0), roundi(Weather.daylight_at(tick) * 100.0)]


func _on_speed_changed(speed: int) -> void:
	for value: int in _speed_buttons:
		_speed_buttons[value].button_pressed = value == speed


## Saison, durée du jour, prochaine saison.
static func _date_tooltip(tick: int) -> String:
	var season := GameDate.season(tick)
	var days_left := GameDate.DAYS_PER_SEASON - GameDate.day_of_season(tick) + 1
	return "%s, an %d\nJour : %d h de soleil\n%s dans %d jour(s)\n1 jour ≈ 2,4 s à ×1" % [
		GameDate.SEASON_NAMES[season], GameDate.year(tick), roundi(Weather.DAY_LENGTH[season]),
		GameDate.SEASON_NAMES[(season + 1) % GameDate.SEASONS_PER_YEAR], days_left]


func _on_game_started(seed_value: int) -> void:
	_seed_edit.text = str(seed_value)


func _on_overlay_changed(mode: int) -> void:
	_overlay_mode = mode as OverlayLayer.Mode
	_overlay_buttons[mode].button_pressed = true
	_legend.text = LEGENDS[mode]
	_legend.visible = not LEGENDS[mode].is_empty()
	var gradient := OverlayLayer.gradient_for(_overlay_mode)
	_legend_gradient.visible = gradient != null
	if gradient:
		var texture := GradientTexture1D.new()
		texture.gradient = gradient
		_legend_gradient.texture = texture
