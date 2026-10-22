extends CanvasLayer
## Fenêtre des statistiques (G) : graphiques journaliers par onglet et
## jalons du bac à sable. Les onglets de graphiques de la v2 (population,
## stocks, puissance…) viendront avec leurs simulations.

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
	if GameState.stats == null:
		return
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
