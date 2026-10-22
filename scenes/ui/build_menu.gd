extends CanvasLayer
## Menu de construction (à gauche), bandeau d'aide de l'outil actif (en bas)
## et messages brefs au joueur.

const OK_COLOR := "#7ee787"
const ERROR_COLOR := "#ff7a6e"
const TOAST_SECONDS := 2.5

var _mode := BuildTool.Mode.SELECT
var _def: BuildingDef
var _placement: BuildingRegistry.Placement
var _hovered := Vector2i(-1, -1)
var _group := ButtonGroup.new()
var _build_buttons: Dictionary[BuildingDef, Button] = {}
var _demolish_button: Button
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
	EventBus.notified.connect(_show_toast)
	_toast.modulate.a = 0.0
	_on_tool_changed(BuildTool.Mode.SELECT, null)


func _build_list() -> void:
	for category in BuildingDef.Category.size():
		var defs := BuildingDb.DEFS.filter(func(d: BuildingDef) -> bool:
			return d.category == category and d.player_buildable)
		if defs.is_empty():
			continue
		var header := Label.new()
		header.text = BuildingDef.CATEGORY_NAMES[category]
		header.modulate = Color(1, 1, 1, 0.6)
		_list.add_child(header)
		for def: BuildingDef in defs:
			var button := _tool_button(def.display_name)
			button.tooltip_text = _tooltip(def)
			button.pressed.connect(func() -> void:
				_select_tool(button, BuildTool.Mode.BUILD, def))
			_build_buttons[def] = button
	_list.add_child(HSeparator.new())
	_demolish_button = _tool_button("Démolir (X)")
	_demolish_button.tooltip_text = "Démolit un bâtiment ou annule un chantier."
	_demolish_button.pressed.connect(func() -> void:
		_select_tool(_demolish_button, BuildTool.Mode.DEMOLISH, null))


## Clic sur un bouton d'outil : l'active, ou revient à la sélection si le
## clic l'a relâché (re-clic).
func _select_tool(button: Button, mode: BuildTool.Mode, def: BuildingDef) -> void:
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
	lines.append("Chantier : %s" % Format.duration_hours(def.build_hours))
	var constraints := def.describe_constraints()
	if not constraints.is_empty():
		lines.append("")
		lines.append_array(constraints)
	return "\n".join(lines)


func _on_tool_changed(mode: int, def: BuildingDef) -> void:
	_mode = mode as BuildTool.Mode
	_def = def
	_placement = null
	# Reflète l'outil dans les boutons sans réémettre de signal.
	for d: BuildingDef in _build_buttons:
		_build_buttons[d].set_pressed_no_signal(_mode == BuildTool.Mode.BUILD and d == def)
	_demolish_button.set_pressed_no_signal(_mode == BuildTool.Mode.DEMOLISH)
	_refresh_hint()


func _refresh_hint() -> void:
	var text := ""
	match _mode:
		BuildTool.Mode.BUILD:
			text = "[b]%s[/b] — chantier %s" % [_def.display_name, Format.duration_hours(_def.build_hours)]
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
	_hint.text = text
	_hint_panel.visible = not text.is_empty()


func _show_toast(message: String) -> void:
	_toast.text = message
	if _toast_tween:
		_toast_tween.kill()
	_toast.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(TOAST_SECONDS)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.5)
