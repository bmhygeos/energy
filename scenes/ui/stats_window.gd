extends CanvasLayer
## Fenêtre des statistiques (G) : graphiques journaliers par onglet
## (électricité, finances, environnement, villes et recherche) et jalons du
## bac à sable.

## Couleurs des sources dans le mix électrique (sinon couleur du bâtiment).
const SOURCE_COLORS: Dictionary[StringName, Color] = {
	&"biomass_plant": Color("a07a45"),
	&"coal_plant": Color("85858f"),
	&"nuclear_plant": Color("b37feb"),
	&"wind_turbine": Color("5ec8e5"),
	&"offshore_wind": Color("2f8fd0"),
	&"solar_farm": Color("f2d14b"),
	&"solar_thermal_plant": Color("f08a24"),
}
const RANGES: PackedInt32Array = [30, 120, 0]
const RANGE_NAMES: PackedStringArray = ["30 jours", "1 an", "Tout"]
const REACHED_COLOR := Color("4caf50")
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
	_add_tab("Électricité", [
		_chart(&"mix", "Production par source et demande", "MWh/j"),
		_chart(&"shed", "Délestages", "villes × h"),
	])
	_add_tab("Finances", [
		_chart(&"money", "Trésorerie", "€"),
		_chart(&"flows", "Recettes et dépenses du jour", "€"),
		_chart(&"price", "Prix moyen du marché", "€/MWh"),
	])
	_add_tab("Environnement", [
		_chart(&"emissions", "Émissions de CO₂", "t/j"),
		_chart(&"shares", "Renouvelable et satisfaction", "%"),
	])
	_add_tab("Villes et recherche", [
		_chart(&"population", "Population", "habitants"),
		_chart(&"research", "Recherche produite", "RP/j"),
	])
	_charts[&"shares"].fixed_max = 100.0
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
	var mix: Array[Chart.Series] = []
	for id: StringName in stats.mix:
		var def := BuildingDb.get_def(id)
		mix.append(Chart.Series.new(def.display_name, stats.mix[id], SOURCE_COLORS.get(id, def.color), true))
	mix.append(Chart.Series.new("Demande", stats.values(&"demand"), Color.WHITE))
	_show(&"mix", mix, first)
	_show(&"shed", [Chart.Series.new("Villes délestées", stats.values(&"shed_hours"), Color("e5484d"))], first)
	_show(&"money", [Chart.Series.new("Argent", stats.values(&"money"), Color("f2d14b"))], first)
	_show(&"flows", [
		Chart.Series.new("Ventes", stats.values(&"sales"), Color("4caf50")),
		Chart.Series.new("Subventions", stats.values(&"subsidies"), Color("5ec8e5")),
		Chart.Series.new("Dépenses", stats.values(&"costs"), Color("e5484d")),
		Chart.Series.new("Bilan", stats.values(&"net"), Color.WHITE),
	], first)
	_show(&"price", [Chart.Series.new("Prix", stats.values(&"price"), Color("f0a020"))], first)
	_show(&"emissions", [Chart.Series.new("CO₂", stats.values(&"emissions"), Color("a0a0a8"))], first)
	_show(&"shares", [
		Chart.Series.new("Part renouvelable", stats.values(&"renewable_share"), Color("4caf50")),
		Chart.Series.new("Satisfaction", stats.values(&"satisfaction"), Color("f2d14b")),
	], first)
	_show(&"population", [Chart.Series.new("Habitants", stats.values(&"population"), Color("5b9bd5"))], first)
	_show(&"research", [Chart.Series.new("Recherche", stats.values(&"research"), Color("b37feb"))], first)
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
