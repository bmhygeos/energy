extends CanvasLayer
## Menu de construction (à gauche : zones à peindre, territoire — expédition
## et annexion —, bâtiments, démolition),
## bandeau d'aide de l'outil actif (en bas) et messages brefs au joueur.

const OK_COLOR := "#7ee787"
const ERROR_COLOR := "#ff7a6e"
const TOAST_SECONDS := 2.5

var _mode := BuildTool.Mode.SELECT
var _def: BuildingDef
var _zone_def: ZoneDef
var _placement: BuildingRegistry.Placement
var _zone_plan: ZoneMap.Plan
var _hovered := Vector2i(-1, -1)
var _group := ButtonGroup.new()
var _build_buttons: Dictionary[BuildingDef, Button] = {}
var _zone_buttons: Dictionary[ZoneDef, Button] = {}
var _erase_zone_button: Button
var _demolish_button: Button
var _expedition_button: Button
var _annex_button: Button
var _members: SpinBox
var _days: SpinBox
var _expedition_status: Label
var _annex_plan: Territory.AnnexPlan
var _toast_tween: Tween

@onready var _list: VBoxContainer = %List
@onready var _hint_panel: PanelContainer = $HintPanel
@onready var _hint: RichTextLabel = %Hint
@onready var _toast: Label = %Toast


func _ready() -> void:
	_group.allow_unpress = true
	_build_list()
	EventBus.tool_changed.connect(_on_tool_changed)
	EventBus.placement_previewed.connect(func(p: BuildingRegistry.Placement) -> void:
		_placement = p
		_refresh_hint())
	EventBus.tile_hovered.connect(func(c: Vector2i) -> void:
		_hovered = c
		if _mode == BuildTool.Mode.DEMOLISH:
			_refresh_hint())
	EventBus.zone_plan_previewed.connect(func(p: ZoneMap.Plan) -> void:
		_zone_plan = p
		_refresh_hint())
	EventBus.annex_plan_previewed.connect(func(p: Territory.AnnexPlan) -> void:
		_annex_plan = p
		_refresh_hint())
	EventBus.tile_hovered.connect(func(_c: Vector2i) -> void:
		if _mode == BuildTool.Mode.EXPEDITION:
			_refresh_hint())
	EventBus.expedition_target_clicked.connect(_on_expedition_target)
	EventBus.expeditions_changed.connect(_refresh_expedition_status)
	EventBus.game_started.connect(func(_s: int) -> void: _refresh_expedition_status())
	EventBus.notified.connect(_show_toast)
	_toast.modulate.a = 0.0
	_on_tool_changed(BuildTool.Mode.SELECT, null)


func _build_list() -> void:
	_add_header("Zones")
	for def in ZoneDb.DEFS:
		var button := _tool_button(def.display_name)
		button.icon = _swatch(def.color)
		button.tooltip_text = _zone_tooltip(def)
		button.pressed.connect(func() -> void:
			_select_tool(button, BuildTool.Mode.ZONE, def))
		_zone_buttons[def] = button
	_erase_zone_button = _tool_button("Effacer les zones")
	_erase_zone_button.tooltip_text = "Glisser pour effacer les zones d'un rectangle."
	_erase_zone_button.pressed.connect(func() -> void:
		_select_tool(_erase_zone_button, BuildTool.Mode.ERASE_ZONE, null))
	_build_territory()
	for category in BuildingDef.Category.size():
		var defs := BuildingDb.DEFS.filter(func(d: BuildingDef) -> bool:
			return d.category == category and d.player_buildable)
		if defs.is_empty():
			continue
		_add_header(BuildingDef.CATEGORY_NAMES[category])
		for def: BuildingDef in defs:
			var button := _tool_button("%s   %d bois" % [def.display_name, def.wood_cost])
			button.tooltip_text = _tooltip(def)
			button.pressed.connect(func() -> void:
				_select_tool(button, BuildTool.Mode.BUILD, def))
			_build_buttons[def] = button
	_list.add_child(HSeparator.new())
	_demolish_button = _tool_button("Démolir (X)")
	_demolish_button.tooltip_text = "Démolit un bâtiment ou annule un chantier."
	_demolish_button.pressed.connect(func() -> void:
		_select_tool(_demolish_button, BuildTool.Mode.DEMOLISH, null))


## Section « Territoire » : expédition (effectif, jours de vivres, état de
## l'expédition en cours) et annexion.
func _build_territory() -> void:
	_add_header("Territoire")
	_expedition_button = _tool_button("Expédition")
	_expedition_button.tooltip_text = "\n".join(PackedStringArray(["Expédition",
		"Des habitants actifs quittent le travail et partent explorer avec des vivres pris au grenier.",
		"Ils marchent en ligne droite vers la tuile choisie (lent en forêt, en colline et aux gués ;",
		"lacs et mer infranchissables), révèlent les tuiles autour d'eux puis reviennent.",
		"Au plus %d expédition à la fois, %d explorateurs." % [Exploration.MAX_EXPEDITIONS, Exploration.MAX_MEMBERS]]))
	_expedition_button.pressed.connect(func() -> void:
		_select_tool(_expedition_button, BuildTool.Mode.EXPEDITION, null))
	var row := HBoxContainer.new()
	_members = _spin_box(1, Exploration.MAX_MEMBERS, 3, "Explorateurs")
	_days = _spin_box(1, 40, 8, "Jours de vivres")
	for pair in [["Explorateurs", _members], ["Vivres (j)", _days]]:
		var label := Label.new()
		label.text = pair[0]
		label.modulate = Color(1, 1, 1, 0.6)
		row.add_child(label)
		row.add_child(pair[1])
	_list.add_child(row)
	for spin in [_members, _days]:
		spin.value_changed.connect(func(_v: float) -> void: _refresh_hint())
	_expedition_status = Label.new()
	_expedition_status.modulate = Color(1, 1, 1, 0.75)
	_expedition_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_expedition_status.custom_minimum_size = Vector2(220, 0)
	_list.add_child(_expedition_status)
	_annex_button = _tool_button("Annexer")
	_annex_button.tooltip_text = "\n".join(PackedStringArray(["Annexer",
		"Intègre au territoire les tuiles explorées reliées à la frontière (glisser un rectangle).",
		"Gratuit.",
		"Surface permise : %d tuiles par habitant." % Territory.TILES_PER_INHABITANT]))
	_annex_button.pressed.connect(func() -> void:
		_select_tool(_annex_button, BuildTool.Mode.ANNEX, null))
	_refresh_expedition_status()


func _spin_box(lo: int, hi: int, value: int, tooltip: String) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = lo
	spin.max_value = hi
	spin.value = value
	spin.tooltip_text = tooltip
	spin.focus_mode = Control.FOCUS_NONE
	spin.get_line_edit().focus_mode = Control.FOCUS_CLICK
	return spin


func _expedition_food() -> float:
	return _members.value * _days.value * Exploration.FOOD_PER_MEMBER_PER_DAY


func _on_expedition_target(cell: Vector2i) -> void:
	if GameState.launch_expedition(cell, int(_members.value), _days.value):
		EventBus.tool_changed.emit(BuildTool.Mode.SELECT, null)


## État des expéditions en cours, sous les réglages.
func _refresh_expedition_status() -> void:
	if _expedition_status == null or GameState.exploration == null:
		return
	var lines := PackedStringArray()
	for e in GameState.exploration.expeditions:
		var leg := "retour (%s)" % Exploration.REASON_TEXTS[e.reason] if e.returning else "aller"
		lines.append("En route : %d explorateur%s, %s · vivres %s · %d tuiles découvertes" % [
			e.members, "s" if e.members > 1 else "", leg, Format.decimal(e.food), e.revealed])
	_expedition_status.text = "\n".join(lines)
	_expedition_status.visible = not lines.is_empty()


## Clic sur un bouton d'outil : l'active, ou revient à la sélection si le
## clic l'a relâché (re-clic).
func _add_header(text: String) -> void:
	var header := Label.new()
	header.text = text
	header.modulate = Color(1, 1, 1, 0.6)
	_list.add_child(header)


## Petit carré de la couleur d'une zone, pour son bouton.
static func _swatch(color: Color) -> Texture2D:
	var img := Image.create_empty(14, 14, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return ImageTexture.create_from_image(img)


func _zone_tooltip(def: ZoneDef) -> String:
	return "\n".join(PackedStringArray([def.display_name, def.description, "",
		"Sur : " + def.describe_terrains(),
		"Travailleurs : %d par tuile" % def.workers_per_tile,
		"Glisser pour peindre un rectangle (les tuiles non valides sont ignorées)."]))


func _select_tool(button: Button, mode: BuildTool.Mode, def: Resource) -> void:
	if button.button_pressed:
		EventBus.tool_changed.emit(mode, def)
	else:
		EventBus.tool_changed.emit(BuildTool.Mode.SELECT, null)


func _tool_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.toggle_mode = true
	button.button_group = _group
	button.focus_mode = Control.FOCUS_NONE
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_list.add_child(button)
	return button


func _tooltip(def: BuildingDef) -> String:
	var lines := PackedStringArray([def.display_name, def.description, ""])
	lines.append("Taille : %d×%d" % [def.size.x, def.size.y])
	lines.append("Coût : %d bois" % def.wood_cost)
	lines.append("Chantier : %s" % Format.duration_hours(def.build_hours))
	var effects := def.describe_effects()
	if not effects.is_empty():
		lines.append("")
		lines.append_array(effects)
	var constraints := def.describe_constraints()
	if not constraints.is_empty():
		lines.append("")
		lines.append_array(constraints)
	return "\n".join(lines)


func _on_tool_changed(mode: int, def: Resource) -> void:
	_mode = mode as BuildTool.Mode
	_def = def as BuildingDef
	_zone_def = def as ZoneDef
	_placement = null
	_zone_plan = null
	# Reflète l'outil dans les boutons sans réémettre de signal.
	for d: BuildingDef in _build_buttons:
		_build_buttons[d].set_pressed_no_signal(_mode == BuildTool.Mode.BUILD and d == def)
	for d: ZoneDef in _zone_buttons:
		_zone_buttons[d].set_pressed_no_signal(_mode == BuildTool.Mode.ZONE and d == def)
	_erase_zone_button.set_pressed_no_signal(_mode == BuildTool.Mode.ERASE_ZONE)
	_demolish_button.set_pressed_no_signal(_mode == BuildTool.Mode.DEMOLISH)
	_expedition_button.set_pressed_no_signal(_mode == BuildTool.Mode.EXPEDITION)
	_annex_button.set_pressed_no_signal(_mode == BuildTool.Mode.ANNEX)
	_annex_plan = null
	_refresh_hint()


func _refresh_hint() -> void:
	var text := ""
	match _mode:
		BuildTool.Mode.BUILD:
			text = "[b]%s[/b] — %d bois · chantier %s" % [_def.display_name, _def.wood_cost,
				Format.duration_hours(_def.build_hours)]
			if _placement == null:
				text += "\nPlacez le bâtiment sur la carte · Échap : annuler"
			elif _placement.is_valid():
				var extra := ""
				if not _placement.cleared.is_empty():
					extra = " (défrichement de %d tuile%s)" % [
						_placement.cleared.size(), "s" if _placement.cleared.size() > 1 else ""]
				text += "\n[color=%s]Clic : construire%s[/color] · Échap : annuler" % [OK_COLOR, extra]
			else:
				text += "\n[color=%s]%s[/color] · Échap : annuler" % [ERROR_COLOR, _placement.error]
		BuildTool.Mode.DEMOLISH:
			text = "[b]Démolition[/b] — cliquez sur un bâtiment · Échap : annuler"
			var b := GameState.buildings.building_at(_hovered) if _hovered.x >= 0 else null
			if b:
				text += "\n[color=%s]%s %s[/color]" % [
					ERROR_COLOR, "Annuler le chantier" if not b.is_complete() else "Démolir", b.def.display_name]
		BuildTool.Mode.ZONE, BuildTool.Mode.ERASE_ZONE:
			if _mode == BuildTool.Mode.ZONE:
				text = "[b]%s[/b] — glisser pour peindre un rectangle · Échap : annuler" % _zone_def.display_name
			else:
				text = "[b]Effacer les zones[/b] — glisser sur un rectangle · Échap : annuler"
			if _zone_plan:
				var n := _zone_plan.changed.size()
				var verb := "effacée" if _zone_def == null or _mode == BuildTool.Mode.ERASE_ZONE else "peinte"
				if n > 0:
					text += "\n[color=%s]%d tuile%s %s%s[/color]" % [OK_COLOR, n, "s" if n > 1 else "", verb, "s" if n > 1 else ""]
				if _zone_plan.refused > 0:
					text += "%s[color=%s]%d ignorée%s : %s[/color]" % ["  ·  " if n > 0 else "\n", ERROR_COLOR,
						_zone_plan.refused, "s" if _zone_plan.refused > 1 else "", _zone_plan.error]
		BuildTool.Mode.EXPEDITION:
			text = _expedition_hint()
		BuildTool.Mode.ANNEX:
			text = _annex_hint()
	_hint.text = text
	_hint_panel.visible = not text.is_empty()


func _expedition_hint() -> String:
	var members := int(_members.value)
	var text := "[b]Expédition[/b] — %d explorateur%s, %s jours de vivres (%s nourriture) · cliquez sur la destination · Échap : annuler" % [
		members, "s" if members > 1 else "", Format.decimal(_days.value), Format.decimal(_expedition_food())]
	var error := GameState.expedition_error(members, _days.value)
	if not error.is_empty():
		return text + "\n[color=%s]%s[/color]" % [ERROR_COLOR, error]
	if _hovered.x >= 0:
		var home := GameState.display_cell(GameState.home)
		var path := GameState.exploration.plan_path(home, _hovered)
		if path.size() < 2:
			return text + "\n[color=%s]Trajet impossible : de l'eau barre le chemin[/color]" % ERROR_COLOR
		var trip := GameState.exploration.round_trip_days(home, _hovered)
		var note := "aller-retour ≈ %s jours" % Format.decimal(trip)
		if path[-1] != _hovered:
			note += " (arrêt devant l'eau)"
		var color := OK_COLOR if trip <= _days.value else ERROR_COLOR
		if trip > _days.value:
			note += " : demi-tour avant la cible, faute de vivres"
		text += "\n[color=%s]%s[/color]" % [color, note]
	return text


func _annex_hint() -> String:
	var text := "[b]Annexer[/b] — glisser sur des tuiles explorées au bord du territoire · place : %d tuiles · Échap : annuler" % GameState.annex_room()
	if _annex_plan:
		var n := _annex_plan.cells.size()
		if n > 0:
			text += "\n[color=%s]%d tuile%s annexée%s[/color]" % [OK_COLOR, n, "s" if n > 1 else "", "s" if n > 1 else ""]
		if _annex_plan.refused > 0:
			text += "%s[color=%s]%d ignorée%s : %s[/color]" % ["  ·  " if n > 0 else "\n", ERROR_COLOR,
				_annex_plan.refused, "s" if _annex_plan.refused > 1 else "", _annex_plan.error]
	return text


func _show_toast(message: String) -> void:
	_toast.text = message
	if _toast_tween:
		_toast_tween.kill()
	_toast.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(TOAST_SECONDS)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.5)
