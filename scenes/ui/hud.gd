extends CanvasLayer
## Bandeau supérieur (date, météo, vitesse, graine) et sélecteur de calque
## d'information en bas à droite.

## Légendes et info-bulles des calques (par OverlayLayer.Mode).
const LEGENDS: PackedStringArray = [
	"",
	"Altitude : fonds marins → sommets",
	"Fertilité (agriculture) : faible → forte",
	"Pâturage (élevage) : faible → fort",
	"[color=#3fa0ff]■[/color] accès à l'eau   [color=#1a59d9]■[/color] côte   [color=#c04030]■[/color] sans eau",
	"Gisements prospectés : [color=#1a1a1a]■[/color] charbon   [color=#b0503a]■[/color] fer   [color=#2b2b55]■[/color] pétrole   [color=#d9822b]■[/color] cuivre   [color=#4be03c]■[/color] uranium   [color=#c45cff]■[/color] lithium",
	"Potentiel éolien : faible → fort",
	"Ensoleillement : faible → fort",
]
const OVERLAY_TIPS: PackedStringArray = [
	"Aucun calque (O pour faire défiler)",
	"Altitude : repérer collines et montagnes",
	"Fertilité : plaines et berges, plus faible au froid",
	"Pâturage : prairies et collines",
	"Accès à l'eau : tuiles bordant une rivière, un lac ou la mer",
	"Gisements révélés par la prospection (aucun au départ)",
	"Potentiel éolien : plus fort sur les côtes, les crêtes et aux latitudes moyennes",
	"Ensoleillement : plus fort près de l'équateur et dans les déserts",
]

const WARNING_COLOR := Color("ff7a6e")

var _overlay_mode := OverlayLayer.Mode.NONE
var _overlay_buttons: Array[Button] = []

@onready var _date_label: Label = %DateLabel
@onready var _weather_label: Label = %WeatherLabel
@onready var _tier_label: Label = %TierLabel
@onready var _population_label: Label = %PopulationLabel
@onready var _food_label: Label = %FoodLabel
@onready var _wood_label: Label = %WoodLabel
@onready var _stone_label: Label = %StoneLabel
@onready var _water_label: Label = %WaterLabel
@onready var _power_label: Label = %PowerLabel
@onready var _money_button: Button = %EconomyButton
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
	%LaborButton.pressed.connect(func() -> void: get_node("../LaborPanel").toggle())
	%ResearchButton.pressed.connect(func() -> void: get_node("../ResearchPanel").toggle())
	%EconomyButton.pressed.connect(func() -> void: get_node("../EconomyPanel").toggle())
	_build_game_menu()
	EventBus.labor_changed.connect(_refresh_population)
	EventBus.population_changed.connect(_refresh_population)
	EventBus.stocks_changed.connect(_refresh_stocks)
	EventBus.tier_changed.connect(_refresh_population)
	EventBus.economy_changed.connect(_refresh_money)
	EventBus.tier_changed.connect(_refresh_money)
	_on_tick(GameClock.tick)
	_on_speed_changed(GameClock.speed)
	_on_game_started(Rng.seed_value)
	_on_overlay_changed(_overlay_mode)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("overlay_cycle"):
		EventBus.overlay_changed.emit((_overlay_mode + 1) % OverlayLayer.Mode.size())
		get_viewport().set_input_as_handled()


## Menu « Partie » : graine, nouvelle carte et aide (le tutoriel se rouvre
## aussi sans clavier, sur tablette), hors du bandeau pour lui laisser la place.
func _build_game_menu() -> void:
	var menu := Button.new()
	menu.text = "Partie ▾"
	menu.tooltip_text = "Nouvelle carte, graine, aide"
	menu.focus_mode = Control.FOCUS_NONE
	%Speed.add_sibling(menu)
	%Speed.get_parent().move_child(menu, %Speed.get_index())
	var popup := PopupPanel.new()
	add_child(popup)
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	popup.add_child(box)
	for node: Control in [_seed_edit, %GenerateButton, %RandomButton]:
		node.reparent(box)
	var help := Button.new()
	help.text = "Aide"
	help.tooltip_text = "Afficher ou masquer le tutoriel (H)"
	help.focus_mode = Control.FOCUS_NONE
	help.pressed.connect(func() -> void:
		popup.hide()
		get_node("../Tutorial").toggle())
	box.add_child(help)
	%GenerateButton.pressed.connect(popup.hide)
	%RandomButton.pressed.connect(popup.hide)
	menu.pressed.connect(func() -> void:
		var at := menu.get_global_rect()
		popup.popup(Rect2i(Vector2i(at.end.x - box.get_combined_minimum_size().x - 8, at.end.y + 4), Vector2i.ZERO)))


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
	_date_label.text = _short_date(tick)
	if GameDate.hour_of_day(tick) == 0 or _date_label.tooltip_text.is_empty():
		_date_label.tooltip_text = _date_tooltip(tick)
	var weather := GameState.weather
	if weather == null:
		return
	_weather_label.text = weather.sky(tick)
	_weather_label.remove_theme_color_override("font_color")
	_weather_label.tooltip_text = "Météo : %s\nVent : %d %% de la normale\nNébulosité : %d %%\nLumière du jour : %d %%" % [
		weather.describe(tick), roundi(weather.wind_at(tick) * 100.0),
		roundi(weather.cloud_at(tick) * 100.0), roundi(Weather.daylight_at(tick) * 100.0)]
	# Événement en cours : à la place du ciel, détail au survol.
	var events := GameState.events
	for kind: CityEvents.Kind in events.active:
		_weather_label.text = CityEvents.NAMES[kind]
		_weather_label.add_theme_color_override("font_color", WARNING_COLOR)
		_weather_label.tooltip_text += "\n\n%s : encore %d jours\n%s" % [CityEvents.NAMES[kind], events.active[kind],
			CityEvents.START_TEXTS[kind]]


## Habitants / logements (rouge s'il y a des chômeurs) ; détail au survol.
func _refresh_population() -> void:
	var population := GameState.population
	var labor := GameState.labor
	if population == null:
		return
	var unemployed := labor.unemployed()
	_population_label.text = "Habitants %d / %d" % [population.count, GameState.housing]
	_population_label.add_theme_color_override("font_color", WARNING_COLOR if unemployed > 0 else Color.WHITE)
	_population_label.tooltip_text = "Habitants / logements\nActifs : %d (%d %%)  ·  au travail : %d  ·  en route : %d  ·  chômeurs : %d  ·  en expédition : %d\nSatisfaction : %d %% (besoins couverts hier : nourriture %d %%, bois %d %%)" % [
		population.active(), roundi(population.active_share * 100.0), labor.employed(), labor.in_transit(), unemployed,
		GameState.exploration.members_out(), roundi(population.satisfaction * 100.0), roundi(population.food_coverage * 100.0), roundi(population.wood_coverage * 100.0)]
	_refresh_tier()
	_refresh_water()
	_refresh_power()


## Eau (à partir du village) : part des habitants servis par les puits.
func _refresh_water() -> void:
	var shown := GameState.tier.level >= GameState.WATER_TIER
	_water_label.visible = shown
	if not shown:
		return
	var coverage := GameState.water_coverage()
	_water_label.text = "Eau %d %%" % roundi(coverage * 100.0)
	_water_label.add_theme_color_override("font_color", WARNING_COLOR if coverage < 1.0 else Color.WHITE)
	_water_label.tooltip_text = "Eau : puits pour %d habitants, %d habitants\nSans eau, la satisfaction baisse (jusqu'à −%d %%) et la population ne grandit plus." % [
		GameState.water_supply, GameState.population.count, roundi(Population.WATER_WEIGHT * 100.0)]


## Palier de la ville ; au survol, ce qu'il faut pour le suivant.
func _refresh_tier() -> void:
	var tier := GameState.tier
	var population := GameState.population
	_tier_label.text = tier.name()
	if tier.is_max():
		_tier_label.tooltip_text = "Palier de la ville : %s, le dernier" % tier.name()
		return
	_tier_label.tooltip_text = "Palier de la ville : %s\nPalier suivant : %s\n  Habitants : %d / %d\n  Satisfaction : %d %% / %d %%" % [
		tier.name(), CityTier.NAMES[tier.level], population.count, tier.next_population(),
		roundi(population.satisfaction * 100.0), roundi(CityTier.SATISFACTION_REQUIRED * 100.0)]


## Stocks en unités et en jours de réserve ; rouge sous les seuils d'alerte.
func _refresh_stocks() -> void:
	var stock := GameState.stockpile
	if stock == null:
		return
	var tick := GameClock.tick
	_refresh_stone()
	var labels := [_food_label, _wood_label]
	var days := [GameState.food_days(), GameState.wood_days()]
	var alerts := [Labor.FOOD_ALERT_DAYS, Labor.WOOD_ALERT_DAYS]
	var needs := [GameState.food_need(), GameState.wood_need(GameDate.season(tick))]
	for good in labels.size():
		var label: Label = labels[good]
		var d: float = days[good]
		label.text = "%s %d (%s j)" % [Stockpile.GOOD_NAMES[good], roundi(stock.amount[good]),
			"∞" if is_inf(d) else str(floori(d))]
		label.add_theme_color_override("font_color", WARNING_COLOR if d < alerts[good] else Color.WHITE)
		var expected := 0.0
		for def in ZoneDb.DEFS:
			if def.output == good:
				expected += GameState.production.expected_per_day(def, GameDate.season(tick))
		label.tooltip_text = "%s : %d / %d (capacité)\nConsommation : %s /j  ·  production prévue : %s /j\nPertes d'hier (gâchis, stock plein) : %s" % [
			Stockpile.GOOD_NAMES[good], roundi(stock.amount[good]), roundi(stock.capacity[good]),
			Format.decimal(needs[good]), Format.decimal(expected), Format.decimal(GameState.stats.last(
				[&"food_lost", &"wood_lost"][good]))]


## Pierre (à partir du village, ou dès qu'il y en a en stock).
func _refresh_stone() -> void:
	var stock := GameState.stockpile
	var good := Stockpile.Good.STONE
	_stone_label.visible = GameState.tier.level >= 2 or stock.amount[good] > 0.0
	_stone_label.text = "Pierre %d" % roundi(stock.amount[good])
	var tools := Stockpile.Good.TOOLS
	var iron := Stockpile.Good.IRON
	if stock.amount[tools] > 0.0 or GameState.tools_need() > 0.0:
		_stone_label.text += " · Outils %d" % roundi(stock.amount[tools])
	var bourg := GameState.tier.level >= GameState.CLOTHES_TIER
	if bourg:
		_stone_label.text += " · Charbon %d · Vêtements %d" % [roundi(stock.amount[Stockpile.Good.COAL]),
			roundi(stock.amount[Stockpile.Good.CLOTHES])]
	var short_clothes := bourg and GameState.population.clothes_coverage < 1.0
	_stone_label.add_theme_color_override("font_color", WARNING_COLOR if not GameState.production.tools_ok or short_clothes else Color.WHITE)
	var expected := 0.0
	for def in ZoneDb.DEFS:
		if def.output == good:
			expected += GameState.production.expected_per_day(def, GameDate.season(GameClock.tick))
	_stone_label.tooltip_text = "Pierre : %d / %d (capacité)\nProduction prévue : %s /j (carrières)\nSert aux maisons en pierre, aux puits et à l'atelier.\n\nFer : %d / %d (mines de fer)\nOutils : %d / %d (forges : fer et bois)\nUsure : %s outils /j (%d bûcherons et laboureurs équipés)%s" % [
		roundi(stock.amount[good]), roundi(stock.capacity[good]), Format.decimal(expected),
		roundi(stock.amount[iron]), roundi(stock.capacity[iron]), roundi(stock.amount[tools]), roundi(stock.capacity[tools]),
		Format.decimal(GameState.tools_need(), 2), GameState.tool_users(),
		"\nPlus d'outils : scie et charrue sans effet." if not GameState.production.tools_ok else ""]
	if bourg:
		var season := GameDate.season(GameClock.tick)
		var coal := Stockpile.Good.COAL
		var fiber := Stockpile.Good.FIBER
		var clothes := Stockpile.Good.CLOTHES
		var fiber_expected := GameState.production.expected_wool_per_day()
		for def in ZoneDb.DEFS:
			if def.output == fiber:
				fiber_expected += GameState.production.expected_per_day(def, season)
		_stone_label.tooltip_text += "\n\nCharbon : %d / %d (mines de charbon)\nChauffage : %s charbon /j au lieu de %s bois%s\nFibres : %d / %d · prévues %s /j (lin, laine)\nVêtements : %d / %d (ateliers de tissage)\nUsure : %s vêtements /j%s" % [
			roundi(stock.amount[coal]), roundi(stock.capacity[coal]), Format.decimal(GameState.coal_heat_need(season)),
			Format.decimal(GameState.coal_heat_need(season) * GameState.COAL_WOOD_EQUIVALENT),
			"" if GameState.coal_heat_need(season) > 0.0 else " (plus de charbon)",
			roundi(stock.amount[fiber]), roundi(stock.capacity[fiber]), Format.decimal(fiber_expected),
			roundi(stock.amount[clothes]), roundi(stock.capacity[clothes]), Format.decimal(GameState.clothes_need()),
			"\nVêtements manquants : satisfaction réduite." if short_clothes else ""]
	# Pétrole : dès qu'il y a de quoi le stocker.
	var oil := Stockpile.Good.OIL
	if stock.capacity[oil] > Stockpile.BASE_CAPACITY[oil] or stock.amount[oil] > 0.0:
		_stone_label.tooltip_text += "\n%s : %d / %d" % [Stockpile.GOOD_NAMES[oil],
			roundi(stock.amount[oil]), roundi(stock.capacity[oil])]


## Bouton du trésor (à partir du bourg) : pièces ; impôts et commerce
## d'hier au survol, panneau Économie au clic.
func _refresh_money() -> void:
	var treasury := GameState.treasury
	if treasury == null:
		return
	_money_button.visible = GameState.tier.level >= GameState.ECONOMY_TIER
	_money_button.text = "Trésor %d" % floori(treasury.money)
	_money_button.tooltip_text = "Trésor : %d pièces\nImpôts (%s) hier : +%s\nCommerce hier : %s\nImpôts, décrets et commerce : panneau Économie (E)" % [
		floori(treasury.money), Treasury.TAX_NAMES[treasury.tax_level].to_lower(),
		Format.decimal(GameState.stats.last(&"taxes")), Format.decimal(GameState.stats.last(&"trade"))]


## Puissance de la cité (moyenne glissante) et par habitant ; parts au survol.
func _refresh_power() -> void:
	var power := GameState.power
	if power == null:
		return
	_power_label.text = "%s · %s/hab" % [PowerMeter.format(power.average()),
		PowerMeter.format(power.per_capita(GameState.population.count))]
	var lines := PackedStringArray(["Puissance de la cité : énergie produite, moyenne sur %d jours" % PowerMeter.WINDOW_DAYS])
	for good in Stockpile.GOOD_NAMES.size():
		if Stockpile.ENERGY_MJ[good] <= 0.0:
			continue
		var w := power.average(good)
		lines.append("%s : %s (%d %%)" % [Stockpile.GOOD_NAMES[good], PowerMeter.format(w),
			roundi(100.0 * w / power.average()) if power.average() > 0.0 else 0])
	for k in PowerMeter.EXTRA_NAMES.size():
		var w := power.average(Stockpile.COUNT + k)
		if w > 0.0:
			lines.append("%s : %s (%d %%)" % [PowerMeter.EXTRA_NAMES[k], PowerMeter.format(w), roundi(100.0 * w / power.average())])
	lines.append("Repère : 1 nourriture/j ≈ 120 W, 0,2 bois/j ≈ 350 W, un cheval au travail %d W" % roundi(DraftAnimals.WORK_WATTS))
	_power_label.tooltip_text = "\n".join(lines)


func _on_speed_changed(speed: int) -> void:
	for value: int in _speed_buttons:
		_speed_buttons[value].button_pressed = value == speed


## Date compacte du bandeau (« Printemps j1, an 1 · 03:00 »).
static func _short_date(tick: int) -> String:
	return "%s j%d, an %d · %02d:00" % [GameDate.SEASON_NAMES[GameDate.season(tick)], GameDate.day_of_season(tick),
		GameDate.year(tick), GameDate.hour_of_day(tick)]


## Saison, durée du jour, prochaine saison.
static func _date_tooltip(tick: int) -> String:
	var season := GameDate.season(tick)
	var days_left := GameDate.DAYS_PER_SEASON - GameDate.day_of_season(tick) + 1
	return "%s\n%s, an %d\nJour : %d h de soleil\n%s dans %d jour(s)\n1 jour ≈ 2,4 s à ×1" % [
		GameDate.format(tick), GameDate.SEASON_NAMES[season], GameDate.year(tick), roundi(Weather.DAY_LENGTH[season]),
		GameDate.SEASON_NAMES[(season + 1) % GameDate.SEASONS_PER_YEAR], days_left]


func _on_game_started(seed_value: int) -> void:
	_seed_edit.text = str(seed_value)
	_refresh_population()
	_refresh_stocks()
	_refresh_money()


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
