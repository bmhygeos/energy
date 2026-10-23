extends CanvasLayer
## Panneau « Recherche » (R) : points produits par jour, recherche en cours
## et recherches du palier actuel (coût, avancement, effet), à lancer d'un
## clic.

const MUTED_COLOR := Color(1, 1, 1, 0.6)
const DONE_COLOR := Color("7ee787")

var _panel: PanelContainer
var _summary: Label
var _list: VBoxContainer


func _ready() -> void:
	_build()
	_panel.hide()
	EventBus.research_changed.connect(_refresh)
	EventBus.population_changed.connect(_refresh)
	EventBus.game_started.connect(func(_s: int) -> void: _refresh())
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("research"):
		toggle()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	_panel.visible = not _panel.visible
	_refresh()


func _build() -> void:
	_panel = PanelContainer.new()
	_panel.anchor_left = 1.0
	_panel.anchor_right = 1.0
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_right = -12.0
	_panel.offset_bottom = -12.0
	_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
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
	title.text = "Recherche (R)"
	title.add_theme_font_size_override("font_size", 18)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close := Button.new()
	close.text = "×"
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(toggle)
	header.add_child(close)
	_summary = Label.new()
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_summary)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 10)
	box.add_child(_list)
	var note := Label.new()
	note.text = "%s point par habitant et par jour, de %d %% à 100 %% selon la satisfaction.\nUne recherche à la fois ; sans recherche, les points sont mis de côté." % [
		Format.decimal(Research.POINTS_PER_INHABITANT), roundi(Research.MIN_SATISFACTION_FACTOR * 100.0)]
	note.modulate = MUTED_COLOR
	note.add_theme_font_size_override("font_size", 13)
	box.add_child(note)


func _refresh() -> void:
	var research := GameState.research
	if research == null or not _panel.visible:
		return
	var per_day := GameState.research_per_day()
	var text := "%s points par jour" % Format.decimal(per_day)
	if research.current:
		text += "  ·  en cours : %s (encore %s j)" % [research.current.display_name,
			Format.decimal(research.days_left(per_day))]
	elif research.bank > 0.0:
		text += "  ·  %s points mis de côté" % Format.decimal(research.bank, 0)
	_summary.text = text
	for child in _list.get_children():
		child.queue_free()
	var shown := 0
	for def in ResearchDb.DEFS:
		if def.tier > GameState.tier.level:
			continue
		shown += 1
		_list.add_child(_row(def))
	if shown == 0:
		var none := Label.new()
		none.text = "Aucune recherche à ce palier."
		none.modulate = MUTED_COLOR
		_list.add_child(none)


func _row(def: ResearchDef) -> Control:
	var research := GameState.research
	var row := VBoxContainer.new()
	var line := HBoxContainer.new()
	row.add_child(line)
	var name_label := Label.new()
	name_label.text = def.display_name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.tooltip_text = "%s\n\n%s" % [def.description, def.effect]
	name_label.mouse_filter = Control.MOUSE_FILTER_STOP
	line.add_child(name_label)
	if research.is_done(def.id):
		name_label.add_theme_color_override("font_color", DONE_COLOR)
		var done := Label.new()
		done.text = "Terminée"
		done.add_theme_color_override("font_color", DONE_COLOR)
		line.add_child(done)
	elif research.current == def:
		var running := Label.new()
		running.text = "En cours"
		line.add_child(running)
	else:
		var start := Button.new()
		start.text = "Rechercher"
		start.focus_mode = Control.FOCUS_NONE
		start.disabled = not research.is_available(def, GameState.tier.level)
		start.pressed.connect(func() -> void: GameState.start_research(def))
		line.add_child(start)
	var bar := ProgressBar.new()
	bar.max_value = def.cost
	bar.value = research.progress_of(def)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 8)
	row.add_child(bar)
	var effect := Label.new()
	effect.text = "%s  ·  %s / %s points" % [def.effect, Format.decimal(research.progress_of(def), 0), Format.decimal(def.cost, 0)]
	effect.modulate = MUTED_COLOR
	effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	effect.add_theme_font_size_override("font_size", 13)
	row.add_child(effect)
	return row
