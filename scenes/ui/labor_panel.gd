extends CanvasLayer
## Panneau « Main-d'œuvre » (M) : habitants, actifs, chômeurs, besoins, et
## par type de zone les tuiles, places, travailleurs affectés, la production
## prévue et la priorité.

const UNEMPLOYED_COLOR := Color("ff7a6e")
const MUTED_COLOR := Color(1, 1, 1, 0.6)
## Ordre des choix de priorité : automatique, puis 0 à 5.
const PRIORITY_CHOICES: Array[int] = [Labor.AUTO, 0, 1, 2, 3, 4, 5]

var _panel: PanelContainer
var _summary: Label
var _needs: Label
## Par type de zone : [tuiles, places, affectés, prévu, priorité].
var _rows: Dictionary[ZoneDef, Array] = {}


func _ready() -> void:
	_build()
	_panel.hide()
	EventBus.labor_changed.connect(_refresh)
	EventBus.zones_changed.connect(func(_c: Array[Vector2i]) -> void: _refresh())
	EventBus.game_started.connect(func(_s: int) -> void: _refresh())
	EventBus.season_changed.connect(func(_s: int, _y: int) -> void: _refresh())
	EventBus.population_changed.connect(_refresh)
	EventBus.expeditions_changed.connect(func() -> void:
		if GameState.exploration.expeditions.is_empty() or GameClock.tick % GameDate.HOURS_PER_DAY == 0:
			_refresh())
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("labor"):
		toggle()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	_panel.visible = not _panel.visible
	_refresh()


func is_open() -> bool:
	return _panel.visible


func _build() -> void:
	_panel = PanelContainer.new()
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = 12.0
	_panel.offset_bottom = -12.0
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(_panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	_panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	margin.add_child(box)
	var header := HBoxContainer.new()
	box.add_child(header)
	var title := Label.new()
	title.text = "Main-d'œuvre (M)"
	title.add_theme_font_size_override("font_size", 18)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close := Button.new()
	close.text = "×"
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(toggle)
	header.add_child(close)
	_summary = Label.new()
	box.add_child(_summary)
	_needs = Label.new()
	_needs.modulate = MUTED_COLOR
	box.add_child(_needs)
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 14)
	box.add_child(grid)
	for text in ["Zone", "Tuiles", "Places", "Affectés", "Prévu /j", "Priorité"]:
		var label := Label.new()
		label.text = text
		label.modulate = MUTED_COLOR
		grid.add_child(label)
	for def in ZoneDb.DEFS:
		var name_label := Label.new()
		name_label.text = def.display_name
		name_label.add_theme_color_override("font_color", def.color.lightened(0.3))
		grid.add_child(name_label)
		var cells: Array = []
		for k in 4:
			var label := Label.new()
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			grid.add_child(label)
			cells.append(label)
		var priority := OptionButton.new()
		priority.focus_mode = Control.FOCUS_NONE
		for choice in PRIORITY_CHOICES:
			priority.add_item("Auto (%d)" % Labor.AUTO_PRIORITY if choice == Labor.AUTO else str(choice))
		priority.tooltip_text = "Priorité de %s : 0 (aucun travailleur) à 5 ; automatique par défaut." % def.display_name.to_lower()
		priority.item_selected.connect(func(index: int) -> void:
			GameState.set_priority(def, PRIORITY_CHOICES[index]))
		grid.add_child(priority)
		cells.append(priority)
		_rows[def] = cells
	var note := Label.new()
	note.text = "Répartition au prorata priorité × places (comptées au plus jusqu'au nombre d'actifs) ;\nchanger de zone prend %d h. Auto : priorité haute quand la nourriture (ou le bois)\nmanque ; personne hors saison ni quand le stock est plein." % Labor.REASSIGN_HOURS
	note.modulate = MUTED_COLOR
	note.add_theme_font_size_override("font_size", 13)
	box.add_child(note)


func _refresh() -> void:
	var labor := GameState.labor
	var population := GameState.population
	if labor == null or not _panel.visible:
		return
	var unemployed := labor.unemployed()
	_summary.text = "Habitants %d  ·  actifs %d  ·  au travail %d  ·  en route %d  ·  chômeurs %d" % [
		population.count, population.active(), labor.employed(), labor.in_transit(), unemployed]
	var explorers := GameState.exploration.members_out()
	if explorers > 0:
		_summary.text += "  ·  en expédition %d" % explorers
	_summary.add_theme_color_override("font_color", UNEMPLOYED_COLOR if unemployed > 0 else Color.WHITE)
	var season := GameDate.season(GameClock.tick)
	_needs.text = "Besoins : nourriture %s /j  ·  bois %s /j%s" % [Format.decimal(GameState.food_need()),
		Format.decimal(GameState.wood_need(season)), {GameDate.SUMMER: " (été)", GameDate.WINTER: " (hiver)"}.get(season, "")]
	if GameState.coal_heat_need(season) > 0.0:
		_needs.text += "  ·  charbon %s /j (chauffage)" % Format.decimal(GameState.coal_heat_need(season))
	if GameState.clothes_need() > 0.0:
		_needs.text += "  ·  vêtements %s /j" % Format.decimal(GameState.clothes_need())
	var draft := GameState.draft
	if draft.capacity > 0 or draft.count() > 0:
		_needs.text += "\nChevaux %d / %d (écuries)  ·  attelés %d  ·  en expédition %d  ·  fourrage %s /j" % [
			draft.count(), draft.capacity, draft.working(), draft.away, Format.decimal(draft.fodder_need())]
	for def: ZoneDef in _rows:
		var row := _rows[def]
		(row[0] as Label).text = str(GameState.zones.tile_count(def))
		(row[1] as Label).text = str(GameState.zones.places(def))
		(row[2] as Label).text = str(labor.assigned[def])
		(row[3] as Label).text = "%s %s" % [Format.decimal(GameState.production.expected_per_day(def, season)),
			Stockpile.GOOD_NAMES[def.output].to_lower()]
		var priority := row[4] as OptionButton
		priority.set_item_text(0, "Auto (%d)" % labor.auto_priorities[def])
		priority.select(PRIORITY_CHOICES.find(labor.priorities[def]))
