extends CanvasLayer
## Panneau « Décrets » (E), à partir du bourg : rationnement, corvée et fête.

const MUTED_COLOR := Color(1, 1, 1, 0.6)

var _panel: PanelContainer
var _locked: Label
var _content: VBoxContainer
var _rationing: CheckBox
var _corvee: CheckBox
var _feast: Button
var _feast_status: Label


func _ready() -> void:
	_build()
	_panel.hide()
	EventBus.economy_changed.connect(_refresh)
	EventBus.stocks_changed.connect(_refresh)
	EventBus.tier_changed.connect(_refresh)
	EventBus.game_started.connect(func(_s: int) -> void: _refresh())


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("economy"):
		toggle()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	_panel.visible = not _panel.visible
	_refresh()


func _build() -> void:
	_panel = PanelContainer.new()
	_panel.anchor_left = 1.0
	_panel.anchor_right = 1.0
	_panel.offset_right = -12.0
	_panel.offset_top = 56.0
	_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_panel.custom_minimum_size = Vector2(420, 0)
	add_child(_panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	_panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)
	var header := HBoxContainer.new()
	box.add_child(header)
	var title := Label.new()
	title.text = "Décrets (E)"
	title.add_theme_font_size_override("font_size", 18)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close := Button.new()
	close.text = "×"
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(toggle)
	header.add_child(close)
	_locked = Label.new()
	_locked.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_locked.modulate = MUTED_COLOR
	box.add_child(_locked)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 8)
	box.add_child(_content)
	_build_decrees()


func _note(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.modulate = MUTED_COLOR
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 13)
	return label


func _build_decrees() -> void:
	_rationing = CheckBox.new()
	_rationing.text = "Rationnement : nourriture −%d %%, satisfaction −%d %%" % [
		roundi((1.0 - Decrees.RATION_FOOD) * 100.0), roundi((1.0 - Decrees.RATION_MOOD) * 100.0)]
	_rationing.focus_mode = Control.FOCUS_NONE
	_rationing.toggled.connect(func(on: bool) -> void: GameState.set_rationing(on))
	_content.add_child(_rationing)
	_corvee = CheckBox.new()
	_corvee.text = "Corvée : actifs %d %% → %d %% des habitants, satisfaction −%d %%" % [
		roundi(Population.ACTIVE_SHARE * 100.0), roundi((Population.ACTIVE_SHARE + Decrees.CORVEE_ACTIVE) * 100.0),
		roundi((1.0 - Decrees.CORVEE_MOOD) * 100.0)]
	_corvee.focus_mode = Control.FOCUS_NONE
	_corvee.toggled.connect(func(on: bool) -> void: GameState.set_corvee(on))
	_content.add_child(_corvee)
	var row := HBoxContainer.new()
	_content.add_child(row)
	_feast = Button.new()
	_feast.focus_mode = Control.FOCUS_NONE
	_feast.pressed.connect(func() -> void: GameState.hold_feast())
	row.add_child(_feast)
	_feast_status = Label.new()
	_feast_status.modulate = MUTED_COLOR
	row.add_child(_feast_status)
	_content.add_child(_note("La satisfaction du jour est multipliée par l'humeur (décrets) ; il en faut %d %% pour passer au palier suivant." % roundi(CityTier.SATISFACTION_REQUIRED * 100.0)))


func _refresh() -> void:
	if not _panel.visible or GameState.decrees == null:
		return
	var error := GameState.decrees_error()
	_locked.visible = not error.is_empty()
	_content.visible = error.is_empty()
	if not error.is_empty():
		_locked.text = "%s : les décrets arrivent avec le bourg." % error
		return
	var pop := GameState.population
	var decrees := GameState.decrees
	_rationing.set_pressed_no_signal(decrees.rationing)
	_corvee.set_pressed_no_signal(decrees.corvee)
	_feast.text = "Donner une fête (%d nourriture)" % roundi(Decrees.feast_food(pop.count))
	var feast_error := GameState.feast_error()
	_feast.disabled = not feast_error.is_empty()
	_feast.tooltip_text = feast_error if not feast_error.is_empty() else "Satisfaction +%d %% pendant %d jours, une fête tous les %d jours au plus" % [
		roundi((Decrees.FEAST_MOOD - 1.0) * 100.0), Decrees.FEAST_DAYS, Decrees.FEAST_COOLDOWN_DAYS]
	_feast_status.text = "En fête : encore %d j" % decrees.feast_days_left if decrees.feast_days_left > 0 else ""
