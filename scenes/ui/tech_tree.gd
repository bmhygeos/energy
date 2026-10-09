extends CanvasLayer
## Fenêtre de l'arbre technologique (GraphEdit) : une colonne par ère, liens
## de prérequis, état et progression de chaque technologie ; un clic met en
## recherche ou retire de la file.

const COLUMN_WIDTH := 300
const ROW_HEIGHT := 215
const NODE_WIDTH := 250
const KNOWN_COLOR := Color("4caf50")
const QUEUED_COLOR := Color("f0b429")
const AVAILABLE_COLOR := Color("5b9bd5")
const LOCKED_COLOR := Color("6b6f78")
const LINK_COLOR := Color(0.75, 0.78, 0.85, 0.55)
const ERA_NAMES: PackedStringArray = ["", "Bois", "Charbon", "Réseau", "Atome", "Renouvelable", "Avancé", "Fusion"]

var _nodes: Dictionary[StringName, GraphNode] = {}
var _state_labels: Dictionary[StringName, Label] = {}
var _bars: Dictionary[StringName, ProgressBar] = {}
var _buttons: Dictionary[StringName, Button] = {}

@onready var _panel: PanelContainer = $Panel
@onready var _graph: GraphEdit = %Graph
@onready var _status: Label = %Status


func _ready() -> void:
	_graph.show_menu = false
	_graph.show_grid = false
	_graph.minimap_enabled = false
	_graph.right_disconnects = false
	_graph.connection_lines_thickness = 2.0
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.1, 0.11, 0.13, 0.98)
	bg.set_corner_radius_all(6)
	_panel.add_theme_stylebox_override("panel", bg)
	_build()
	%CloseButton.pressed.connect(close)
	EventBus.research_changed.connect(_refresh)
	EventBus.tech_unlocked.connect(func(_t: TechDef) -> void: _refresh())
	EventBus.game_started.connect(func(_s: int) -> void: _refresh())
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("tech_tree"):
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


func toggle() -> void:
	if _panel.visible:
		close()
	else:
		_panel.show()
		_refresh()
		# Cadre l'arbre en haut à gauche (titres d'ère compris).
		await get_tree().process_frame
		_graph.zoom = 0.85
		_graph.scroll_offset = Vector2(-30, -70)


func close() -> void:
	_panel.hide()


func is_open() -> bool:
	return _panel.visible


func _build() -> void:
	var rows := {}
	for def in TechDb.DEFS:
		var row: int = rows.get(def.era, 0)
		rows[def.era] = row + 1
		var node := GraphNode.new()
		node.name = String(def.id)
		node.title = def.display_name
		node.draggable = false
		node.selectable = false
		node.custom_minimum_size = Vector2(NODE_WIDTH, 0)
		node.position_offset = Vector2((def.era - 1) * COLUMN_WIDTH, row * ROW_HEIGHT)
		node.tooltip_text = _tooltip(def)
		var box := VBoxContainer.new()
		box.mouse_filter = Control.MOUSE_FILTER_PASS
		var state := Label.new()
		box.add_child(state)
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(0, 6)
		bar.show_percentage = false
		bar.max_value = 1.0
		bar.step = 0.0
		box.add_child(bar)
		var effects := Label.new()
		effects.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		# Largeur imposée : sans elle, le retour à la ligne est calculé sur une
		# largeur nulle et le nœud devient démesurément haut.
		effects.custom_minimum_size = Vector2(NODE_WIDTH - 24, 0)
		effects.text = _effects_text(def)
		effects.modulate = Color(1, 1, 1, 0.75)
		box.add_child(effects)
		var button := Button.new()
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(func() -> void: _on_tech_pressed(def.id))
		box.add_child(button)
		node.add_child(box)
		node.set_slot(0, true, 0, LINK_COLOR, true, 0, LINK_COLOR)
		var body := StyleBoxFlat.new()
		body.bg_color = Color(0.16, 0.17, 0.2)
		body.content_margin_left = 10
		body.content_margin_right = 10
		body.content_margin_top = 6
		body.content_margin_bottom = 8
		body.corner_radius_bottom_left = 4
		body.corner_radius_bottom_right = 4
		node.add_theme_stylebox_override("panel", body)
		node.add_theme_stylebox_override("panel_selected", body)
		_graph.add_child(node)
		_nodes[def.id] = node
		_state_labels[def.id] = state
		_bars[def.id] = bar
		_buttons[def.id] = button
	for def in TechDb.DEFS:
		for p in def.prerequisites:
			_graph.connect_node(StringName(p), 0, StringName(def.id), 0)
	_fit_nodes.call_deferred()
	# Titres des ères, au-dessus des colonnes.
	for era in range(1, 8):
		var label := GraphFrame.new()
		label.title = "Ère %d – %s" % [era, ERA_NAMES[era]]
		label.position_offset = Vector2((era - 1) * COLUMN_WIDTH - 10, -60)
		label.size = Vector2(NODE_WIDTH + 20, 40)
		label.draggable = false
		label.selectable = false
		_graph.add_child(label)


## Ramène chaque nœud à sa taille minimale (une fois le texte mis en page).
func _fit_nodes() -> void:
	for node in _nodes.values():
		node.size = Vector2(NODE_WIDTH, 0)
		node.reset_size()


func _effects_text(def: TechDef) -> String:
	var parts := PackedStringArray()
	var unlocks := Research.unlocks_of(def.id)
	if not unlocks.is_empty():
		parts.append("Débloque : " + ", ".join(unlocks))
	parts.append_array(def.describe_modifiers())
	if def.placeholder:
		parts.append("(contenu à venir)")
	if parts.is_empty():
		parts.append(def.description)
	return "\n".join(parts)


func _tooltip(def: TechDef) -> String:
	var lines := PackedStringArray([def.display_name, def.description, "",
		"Coût : %s RP" % Format.thousands(def.cost)])
	if not def.prerequisites.is_empty():
		var names := PackedStringArray()
		for p in def.prerequisites:
			names.append(TechDb.get_def(p).display_name)
		lines.append("Prérequis : " + ", ".join(names))
	return "\n".join(lines)


func _on_tech_pressed(id: StringName) -> void:
	var research := GameState.research
	if research.is_known(id):
		return
	if id in research.queue:
		GameState.dequeue_research(id)
	else:
		GameState.enqueue_research(id)


func _refresh() -> void:
	var research := GameState.research
	if research == null or _nodes.is_empty():
		return
	for def in TechDb.DEFS:
		var id := def.id
		var color := LOCKED_COLOR
		var state := ""
		var button := _buttons[id]
		button.disabled = false
		if research.is_known(id):
			color = KNOWN_COLOR
			state = "Acquise"
			button.text = "Acquise"
			button.disabled = true
		elif id in research.queue:
			color = QUEUED_COLOR
			var pos := research.queue.find(id)
			state = "En cours" if pos == 0 else "En file (%d)" % (pos + 1)
			state += " · %s RP" % Format.thousands(def.cost)
			button.text = "Retirer de la file"
		else:
			color = AVAILABLE_COLOR if research.is_available(id) else LOCKED_COLOR
			state = "%s RP" % Format.thousands(def.cost)
			button.text = "Rechercher"
		_state_labels[id].text = state
		_bars[id].value = research.progress_of(id)
		var node := _nodes[id]
		var style := StyleBoxFlat.new()
		style.bg_color = color.darkened(0.55)
		style.border_color = color
		style.set_border_width_all(2)
		style.set_corner_radius_all(4)
		node.add_theme_stylebox_override("titlebar", style)
		var selected := style.duplicate()
		node.add_theme_stylebox_override("titlebar_selected", selected)
	var current := research.current()
	var rate := GameState.research_rate
	if current:
		_status.text = "%s : %d %% · %s RP/h" % [current.display_name,
			roundi(research.progress_of(current.id) * 100.0), Format.decimal(rate)]
	else:
		_status.text = "Aucune recherche · %s RP en réserve · %s RP/h" % [
			Format.thousands(roundi(research.bank)), Format.decimal(rate)]
