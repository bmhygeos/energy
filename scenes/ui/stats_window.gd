extends CanvasLayer
## Fenêtre des statistiques (G) : graphiques journaliers par onglet
## (population, stocks et production, territoire et village, puissance) et
## jalons du bac à sable.

const RANGES: PackedInt32Array = [30, 120, 0]
const RANGE_NAMES: PackedStringArray = ["30 jours", "1 an", "Tout"]
const REACHED_COLOR := Color("4caf50")
const FOOD_COLOR := Color("e3b448")
const WOOD_COLOR := Color("a0703c")
## Couleur de chaque marchandise (Stockpile.Good).
const GOOD_COLORS: Array[Color] = [FOOD_COLOR, WOOD_COLOR, Color("9aa3ad"), Color("5f7f9e"), Color("d9774b"),
	Color("5a5a64"), Color("2f6f6a"), Color("7393e6"), Color("c46fb0")]
const PENDING_COLOR := Color("8b8f99")

var _range := 1
var _charts: Dictionary[StringName, Chart] = {}
var _range_buttons: Array[Button] = []
var _milestone_list: VBoxContainer
var _tabs: TabContainer
var _fps: Label

@onready var _panel: PanelContainer = $Panel


func _ready() -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.1, 0.11, 0.13, 0.98)
	bg.set_corner_radius_all(6)
	_panel.add_theme_stylebox_override("panel", bg)
	_build()
	EventBus.day_changed.connect(func(_d: int) -> void:
		if _panel.visible:
			_refresh())
	EventBus.game_started.connect(func(_s: int) -> void:
		if _panel.visible:
			_refresh())


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("statistics"):
		toggle()
	elif _panel.visible and event.is_action_pressed("ui_cancel"):
		close()
	else:
		return
	get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	# Échap ferme la fenêtre avant que la carte ne l'interprète.
	if _panel.visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if _panel.visible:
		_fps.text = "%d FPS" % Engine.get_frames_per_second()


func toggle() -> void:
	if _panel.visible:
		close()
	else:
		_panel.show()
		_refresh()


func close() -> void:
	_panel.hide()


func is_open() -> bool:
	return _panel.visible


func _build() -> void:
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	_panel.add_child(margin)
	var vbox := VBoxContainer.new()
	margin.add_child(vbox)
	var header := HBoxContainer.new()
	vbox.add_child(header)
	var title := Label.new()
	title.text = "Statistiques (G)"
	title.add_theme_font_size_override("font_size", 20)
	header.add_child(title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	_fps = Label.new()
	_fps.modulate = PENDING_COLOR
	header.add_child(_fps)
	var group := ButtonGroup.new()
	for i in RANGES.size():
		var button := Button.new()
		button.text = RANGE_NAMES[i]
		button.toggle_mode = true
		button.button_group = group
		button.button_pressed = i == _range
		button.pressed.connect(func() -> void:
			_range = i
			_refresh())
		header.add_child(button)
		_range_buttons.append(button)
	var close_button := Button.new()
	close_button.text = "Fermer (Échap)"
	close_button.pressed.connect(close)
	header.add_child(close_button)

	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_tabs)
	_add_tab("Population", [
		_chart(&"population", "Habitants et actifs", "habitants"),
		_chart(&"labor", "Emploi (moyenne du jour)", "travailleurs"),
		_chart(&"satisfaction", "Satisfaction et eau", "%"),
	])
	_add_tab("Stocks et production", [
		_chart(&"stocks", "Stocks (moyenne du jour)", "unités"),
		_chart(&"produced", "Production et pertes du jour", "unités"),
	])
	_add_tab("Territoire et village", [
		_chart(&"territory", "Territoire", "tuiles"),
		_chart(&"horses", "Chevaux de trait", "chevaux"),
		_chart(&"research", "Recherche", "points / jour"),
	])
	_add_tab("Économie", [
		_chart(&"money", "Trésor (fin de journée)", "pièces"),
		_chart(&"income", "Impôts et solde du commerce du jour", "pièces"),
	])
	_add_tab("Puissance", [
		_chart(&"power", "Puissance de la cité (moyenne sur %d j)" % PowerMeter.WINDOW_DAYS, "kW"),
		_chart(&"power_per_capita", "Puissance par habitant", "W"),
	])
	_charts[&"satisfaction"].fixed_max = 100.0
	var scroll := ScrollContainer.new()
	scroll.name = "Jalons"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_milestone_list = VBoxContainer.new()
	_milestone_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_milestone_list.add_theme_constant_override("separation", 10)
	scroll.add_child(_milestone_list)
	_tabs.add_child(scroll)
	_tabs.tab_changed.connect(func(_t: int) -> void: _refresh())


func _chart(key: StringName, title: String, unit: String) -> Chart:
	var chart := Chart.new()
	chart.title = title
	chart.unit = unit
	chart.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_charts[key] = chart
	return chart


func _add_tab(tab_name: String, charts: Array[Chart]) -> void:
	var box := VBoxContainer.new()
	box.name = tab_name
	box.add_theme_constant_override("separation", 12)
	for c in charts:
		box.add_child(c)
	_tabs.add_child(box)


func _refresh() -> void:
	var stats := GameState.stats
	if stats == null:
		return
	var span := RANGES[_range]
	var first := maxi(0, stats.days - span) if span > 0 else 0
	_show(&"population", [
		Chart.Series.new("Habitants", stats.values(&"population"), Color("5b9bd5")),
		Chart.Series.new("Actifs", stats.values(&"active"), Color("9ec5ea")),
	], first)
	_show(&"labor", [
		Chart.Series.new("Au travail", stats.values(&"employed"), Color("4caf50")),
		Chart.Series.new("Chômeurs", stats.values(&"unemployed"), Color("e5484d")),
	], first)
	var satisfaction := [Chart.Series.new("Satisfaction", stats.values(&"satisfaction"), Color("f2d14b"))]
	if GameState.tier.level >= GameState.WATER_TIER:
		satisfaction.append(Chart.Series.new("Habitants servis en eau", stats.values(&"water"), Color("4aa3df")))
	if GameState.tier.level >= GameState.CLOTHES_TIER:
		satisfaction.append(Chart.Series.new("Vêtements remplacés", stats.values(&"clothes"), GOOD_COLORS[Stockpile.Good.CLOTHES]))
	_show(&"satisfaction", satisfaction, first)
	# Pierre, fer et outils n'apparaissent qu'une fois produits.
	var stocks := []
	var produced := []
	for good in Stockpile.COUNT:
		if good > Stockpile.Good.WOOD and stats.total(Statistics.PRODUCED_KEYS[good]) <= 0.0:
			continue
		var good_name := Stockpile.GOOD_NAMES[good]
		stocks.append(Chart.Series.new(good_name, stats.values(Statistics.STOCK_KEYS[good]), GOOD_COLORS[good]))
		produced.append(Chart.Series.new(good_name, stats.values(Statistics.PRODUCED_KEYS[good]), GOOD_COLORS[good]))
	produced.append(Chart.Series.new("Nourriture perdue", stats.values(&"food_lost"), Color("e5484d")))
	_show(&"stocks", stocks, first)
	_show(&"produced", produced, first)
	_show(&"territory", [Chart.Series.new("Territoire", stats.values(&"territory"), Color("7ee787"))], first)
	_show(&"horses", [Chart.Series.new("Chevaux", stats.values(&"horses"), Color("c08a5a"))], first)
	_show(&"research", [Chart.Series.new("Points", stats.values(&"research"), Color("b37feb"))], first)
	_show(&"money", [Chart.Series.new("Trésor", stats.values(&"money"), Color("e3c04a"))], first)
	_show(&"income", [
		Chart.Series.new("Impôts", stats.values(&"taxes"), Color("4caf50")),
		Chart.Series.new("Commerce", stats.values(&"trade"), Color("5b9bd5")),
	], first)
	var kw := PackedFloat32Array()
	for w in stats.values(&"power"):
		kw.append(w / 1000.0)
	_show(&"power", [Chart.Series.new("Puissance", kw, Color("f0a020"))], first)
	_show(&"power_per_capita", [Chart.Series.new("Par habitant", stats.values(&"power_per_capita"), Color("b37feb"))], first)
	_refresh_milestones()


func _show(key: StringName, series: Array, first: int) -> void:
	var typed: Array[Chart.Series] = []
	typed.assign(series)
	_charts[key].set_series(typed, first)


func _refresh_milestones() -> void:
	for child in _milestone_list.get_children():
		child.queue_free()
	var milestones := GameState.milestones
	var done := 0
	for def in milestones.defs:
		var reached := milestones.is_reached(def.id)
		if reached:
			done += 1
		var row := VBoxContainer.new()
		var name_label := Label.new()
		name_label.text = ("✔  " if reached else "○  ") + def.display_name
		name_label.add_theme_font_size_override("font_size", 17)
		name_label.modulate = REACHED_COLOR if reached else Color.WHITE
		row.add_child(name_label)
		var detail := Label.new()
		detail.text = "      " + def.description
		if reached:
			detail.text += "  —  atteint : " + Chart._day_label(milestones.reached[def.id])
		detail.modulate = PENDING_COLOR
		row.add_child(detail)
		_milestone_list.add_child(row)
	_tabs.set_tab_title(_tabs.get_tab_count() - 1, "Jalons (%d/%d)" % [done, milestones.defs.size()])
