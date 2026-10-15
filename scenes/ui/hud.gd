extends CanvasLayer
## Bandeau supérieur (date, argent, vitesse, graine) et sélecteur de calque
## d'information en bas à droite.

const LEGENDS: PackedStringArray = [
	"",
	"Altitude : basse → haute",
	"Potentiel éolien : faible → fort",
	"Ensoleillement : faible → fort",
	"[color=#3fa0ff]■[/color] accès à l'eau   [color=#1a59d9]■[/color] côte   [color=#c04030]■[/color] sans eau",
	"[color=#1a1a1a]■[/color] charbon   [color=#4be03c]■[/color] uranium   [color=#c45cff]■[/color] lithium",
	"[color=#4dd959]■[/color] alimenté   [color=#f24d40]■[/color] délestage   [color=#999999]■[/color] sans centrale   [color=#ffd933]■[/color] centrale",
	"Pollution de l'air : faible → irrespirable",
]

var _overlay_mode := OverlayLayer.Mode.NONE
var _overlay_buttons: Array[Button] = []

@onready var _date_label: Label = %DateLabel
@onready var _weather_label: Label = %WeatherLabel
@onready var _money_label: Label = %MoneyLabel
@onready var _upkeep_label: Label = %UpkeepLabel
@onready var _power_label: Label = %PowerLabel
@onready var _sales_label: Label = %SalesLabel
@onready var _research_button: Button = %ResearchButton
@onready var _fps_label: Label = %FpsLabel
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
	EventBus.money_changed.connect(_on_money_changed)
	EventBus.game_started.connect(_on_game_started)
	EventBus.overlay_changed.connect(_on_overlay_changed)
	EventBus.grid_stepped.connect(_on_grid)
	EventBus.research_changed.connect(_refresh_research)
	EventBus.tech_unlocked.connect(func(_t: TechDef) -> void:
		_refresh_research()
		_refresh_overlay_locks())
	_research_button.pressed.connect(func() -> void: get_node("../TechTree").toggle())
	for sig: Signal in [EventBus.building_completed, EventBus.building_removed]:
		sig.connect(func(_b: Building) -> void: _refresh_upkeep())
	for sig: Signal in [EventBus.vehicle_added, EventBus.vehicle_removed]:
		sig.connect(func(_v: Vehicle) -> void: _refresh_upkeep())
	for sig: Signal in [EventBus.roads_changed, EventBus.lines_changed]:
		sig.connect(func(_c: Array[Vector2i]) -> void: _refresh_upkeep())
	_on_tick(GameClock.tick)
	_on_speed_changed(GameClock.speed)
	_on_money_changed(GameState.money)
	_on_game_started(Rng.seed_value)
	_on_overlay_changed(_overlay_mode)


func _process(_delta: float) -> void:
	_fps_label.text = "%d FPS" % Engine.get_frames_per_second()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("overlay_cycle"):
		var next := (_overlay_mode + 1) % OverlayLayer.Mode.size()
		if _overlay_locked(next):
			next = (next + 1) % OverlayLayer.Mode.size()
		EventBus.overlay_changed.emit(next)
		get_viewport().set_input_as_handled()


## Calque inaccessible faute de technologie (gisements avant Prospection).
func _overlay_locked(mode: int) -> bool:
	return mode == OverlayLayer.Mode.DEPOSITS and not GameState.deposits_revealed()


func _refresh_overlay_locks() -> void:
	for mode in _overlay_buttons.size():
		var locked := _overlay_locked(mode)
		_overlay_buttons[mode].disabled = locked
		_overlay_buttons[mode].tooltip_text = "Nécessite la technologie : %s (T)" % \
			TechDb.get_def(GameState.PROSPECTING_TECH).display_name if locked else ""
	if _overlay_locked(_overlay_mode):
		EventBus.overlay_changed.emit(OverlayLayer.Mode.NONE)


func _build_overlay_buttons() -> void:
	var group := ButtonGroup.new()
	for mode in OverlayLayer.Mode.size():
		var button := Button.new()
		button.text = OverlayLayer.MODE_NAMES[mode]
		button.toggle_mode = true
		button.button_group = group
		button.focus_mode = Control.FOCUS_NONE
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
	var weather := GameState.weather
	if weather == null:
		return
	_weather_label.text = weather.sky(tick)
	_weather_label.tooltip_text = "Météo : %s\nVent : %d %% de la normale (éoliennes)\nNébulosité : %d %%\nLumière du jour : %d %% (panneaux solaires)" % [
		weather.describe(tick), roundi(weather.wind_at(tick) * 100.0),
		roundi(weather.cloud_at(tick) * 100.0), roundi(Weather.daylight_at(tick) * 100.0)]


func _on_speed_changed(speed: int) -> void:
	for value: int in _speed_buttons:
		_speed_buttons[value].button_pressed = value == speed


func _on_money_changed(money: int) -> void:
	_money_label.text = "%s €" % Format.thousands(money)


func _on_grid(report: PowerGrid.Report) -> void:
	_power_label.text = "Réseau %s / %s MW" % [Format.decimal(report.delivered_mw), Format.decimal(report.demand_mw)]
	_power_label.add_theme_color_override("font_color",
		Color("ff7a6e") if report.shed_cities > 0 else Color.WHITE)
	var stocks := {}
	for b in GameState.buildings.all():
		for good: int in b.store:
			stocks[good] = stocks.get(good, 0.0) + b.store[good]
		if b.def.input_good != Goods.Type.NONE:
			stocks[b.def.input_good] = stocks.get(b.def.input_good, 0.0) + b.input_stock
		if b.def.output_good != Goods.Type.NONE:
			stocks[b.def.output_good] = stocks.get(b.def.output_good, 0.0) + b.output_stock
	var lines := PackedStringArray([
		"Livré / demandé par les villes raccordées (dernière heure)",
		"Production des centrales raccordées : %s MW" % Format.decimal(report.produced_mw),
	])
	if report.shed_cities > 0:
		lines.append("Villes délestées : %d" % report.shed_cities)
	lines.append("Émissions : %s t/h de CO₂" % Format.decimal(GameState.pollution.emitted_last_hour))
	var people := 0
	var happy := 0.0
	for b in GameState.cities:
		people += b.city.population()
		happy += b.city.satisfaction * b.city.population()
	if people > 0:
		lines.append("Satisfaction des habitants : %d %%" % roundi(happy / people * 100.0))
	var stored := 0.0
	var capacity := 0.0
	for b in GameState.buildings.all():
		if b.def.is_grid_storage() and b.is_complete():
			stored += b.stored_mwh
			capacity += b.def.storage_mwh
	if capacity > 0.0:
		lines.append("Stockage : %s / %s MWh (charge %s, décharge %s MW)" % [Format.decimal(stored),
			Format.thousands(roundi(capacity)), Format.decimal(report.charged_mwh), Format.decimal(report.discharged_mwh)])
	for good: int in stocks:
		lines.append("%s en stock : %s t" % [Goods.display_name(good), Format.decimal(stocks[good])])
	_power_label.tooltip_text = "\n".join(lines)
	_refresh_accounts()


## Bilan de la veille (du jour en cours le premier jour) et taux du marché.
func _refresh_accounts() -> void:
	var tick := GameClock.tick
	var first_day := GameDate.day_index(tick) == 0
	var economy := GameState.economy
	var accounts := economy.today if first_day else economy.yesterday
	_sales_label.text = "Bilan %s €/j" % Format.thousands(roundi(accounts.net()))
	var lines := PackedStringArray([
		"Aujourd'hui (premier jour)" if first_day else "Hier",
		"Ventes d'électricité : %s €" % Format.thousands(roundi(accounts.sales)),
		"Subventions renouvelables : %s €" % Format.thousands(roundi(accounts.subsidies)),
		"Pénalités de délestage : " + _cost(accounts.penalties),
		"Taxe carbone : " + _cost(accounts.carbon_tax),
		"Transport : " + _cost(accounts.transport),
		"Entretien : " + _cost(accounts.upkeep),
		"",
		"Prix du marché : %s €/MWh" % Format.decimal(economy.price_at(tick)),
		"Subvention : %s €/MWh renouvelable" % Format.decimal(Economy.subsidy_at(tick)),
		"Taxe carbone : %s €/t de CO₂" % Format.decimal(Economy.carbon_tax_at(tick)),
	])
	if Economy.carbon_tax_at(tick) <= 0.0:
		lines[lines.size() - 1] += " (dès l'an %d)" % Economy.CARBON_TAX_START_YEAR
	_sales_label.tooltip_text = "\n".join(lines)


static func _cost(amount: float) -> String:
	var whole := roundi(amount)
	return ("−%s €" if whole > 0 else "%s €") % Format.thousands(whole)


func _refresh_research() -> void:
	var research := GameState.research
	var current := research.current()
	if current:
		_research_button.text = "Recherche %d %%" % roundi(research.progress_of(current.id) * 100.0)
		_research_button.tooltip_text = "%s (T)\n%s RP/h" % [current.display_name, Format.decimal(GameState.research_rate)]
	else:
		_research_button.text = "Recherche (T)"
		_research_button.tooltip_text = "Aucune recherche en cours (T)\n%s RP en réserve" % Format.thousands(roundi(research.bank))


func _refresh_upkeep() -> void:
	_upkeep_label.text = "Entretien %s €/j" % Format.thousands(GameState.daily_upkeep())


func _on_game_started(seed_value: int) -> void:
	_seed_edit.text = str(seed_value)
	if not _overlay_buttons.is_empty():
		_refresh_overlay_locks()
	_refresh_upkeep()
	_refresh_research()
	_on_grid(PowerGrid.Report.new())


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
