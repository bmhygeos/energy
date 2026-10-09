extends CanvasLayer
## Menu de construction (à gauche), bandeau d'aide de l'outil actif (en bas)
## et messages brefs au joueur.

const UNAFFORDABLE_COLOR := Color("ff7a6e")
const OK_COLOR := "#7ee787"
const ERROR_COLOR := "#ff7a6e"
const TOAST_SECONDS := 2.5
const FONT_COLOR_STATES: PackedStringArray = [
	"font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color",
]

var _mode := BuildTool.Mode.SELECT
var _def: BuildingDef
var _placement: BuildingRegistry.Placement
var _hovered := Vector2i(-1, -1)
var _group := ButtonGroup.new()
var _build_buttons: Dictionary[BuildingDef, Button] = {}
var _demolish_button: Button
var _road_button: Button
var _line_button: Button
var _trace_plan: TilePlan
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
	EventBus.money_changed.connect(func(_m: int) -> void: _refresh_affordability())
	EventBus.tile_plan_previewed.connect(func(p: TilePlan) -> void:
		_trace_plan = p
		_refresh_hint())
	EventBus.notified.connect(_show_toast)
	_toast.modulate.a = 0.0
	_refresh_affordability()
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
		if category == BuildingDef.Category.ENERGY:
			_line_button = _tool_button("Ligne HT   %d €/tuile" % PowerGrid.LINE_COST)
			_line_button.tooltip_text = _line_tooltip()
			_line_button.pressed.connect(func() -> void:
				_select_tool(_line_button, BuildTool.Mode.LINE, null))
		if category == BuildingDef.Category.LOGISTICS:
			_road_button = _tool_button("Route   %d €/tuile" % RoadNetwork.COST_PER_TILE)
			_road_button.tooltip_text = _road_tooltip()
			_road_button.pressed.connect(func() -> void:
				_select_tool(_road_button, BuildTool.Mode.ROAD, null))
		for def: BuildingDef in defs:
			var button := _tool_button("%s   %s €" % [def.display_name, Format.thousands(def.cost)])
			button.tooltip_text = _tooltip(def)
			button.pressed.connect(func() -> void:
				_select_tool(button, BuildTool.Mode.BUILD, def))
			_build_buttons[def] = button
	_list.add_child(HSeparator.new())
	_demolish_button = _tool_button("Démolir (X)")
	_demolish_button.tooltip_text = "Rembourse %d %% du coût d'un bâtiment terminé, %d %% d'un chantier." % [
		roundi(BuildingRegistry.REFUND_COMPLETE * 100), roundi(BuildingRegistry.REFUND_UNDER_CONSTRUCTION * 100)]
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
	lines.append("Coût : %s €" % Format.thousands(def.cost))
	lines.append("Chantier : %s" % Format.duration_hours(def.build_hours))
	lines.append("Entretien : %s €/jour" % Format.thousands(def.upkeep_per_day))
	if def.lifetime_years > 0:
		lines.append("Durée de vie : %d ans" % def.lifetime_years)
	var production := def.describe_production()
	if not production.is_empty():
		lines.append("")
		lines.append_array(production)
	var constraints := def.describe_constraints()
	if not constraints.is_empty():
		lines.append("")
		lines.append_array(constraints)
	return "\n".join(lines)


func _line_tooltip() -> String:
	return "\n".join(PackedStringArray([
		"Ligne haute tension", "Relie centrales et villes. Glisser pour tracer en L ;",
		"un bâtiment est raccordé si une ligne borde son emprise.", "",
		"%d €/tuile (rivière, montagne : %d €)" % [PowerGrid.LINE_COST, PowerGrid.LINE_COST * PowerGrid.HARD_TERRAIN_FACTOR],
		"Pertes : %s %% par tuile du réseau (max. %d %%)" % [
			Format.decimal(PowerGrid.LOSS_PER_TILE * 100.0), roundi(PowerGrid.MAX_LOSS * 100.0)],
		"Entretien : %d €/tuile/jour" % PowerGrid.UPKEEP_PER_TILE_PER_DAY,
		"Peut longer ou croiser les routes.",
	]))


func _road_tooltip() -> String:
	return "\n".join(PackedStringArray([
		"Route", "Support des charrettes et camions d'un dépôt de véhicules", "(indispensable au transport). Glisser pour tracer en L.", "",
		"Plaine, désert : %d €/tuile" % RoadNetwork.COST_PER_TILE,
		"Forêt (défrichée) : %d €/tuile" % (RoadNetwork.COST_PER_TILE + RoadNetwork.FOREST_EXTRA_COST),
		"Colline : %d €/tuile" % roundi(RoadNetwork.COST_PER_TILE * RoadNetwork.HILL_COST_FACTOR),
		"Pont sur rivière : %d €" % RoadNetwork.BRIDGE_COST,
		"Entretien : %d €/tuile/jour" % RoadNetwork.UPKEEP_PER_TILE_PER_DAY,
	]))


func _on_tool_changed(mode: int, def: BuildingDef) -> void:
	_mode = mode as BuildTool.Mode
	_def = def
	_placement = null
	# Reflète l'outil dans les boutons sans réémettre de signal.
	for d: BuildingDef in _build_buttons:
		_build_buttons[d].set_pressed_no_signal(_mode == BuildTool.Mode.BUILD and d == def)
	_demolish_button.set_pressed_no_signal(_mode == BuildTool.Mode.DEMOLISH)
	_road_button.set_pressed_no_signal(_mode == BuildTool.Mode.ROAD)
	_line_button.set_pressed_no_signal(_mode == BuildTool.Mode.LINE)
	_trace_plan = null
	_refresh_hint()


func _refresh_affordability() -> void:
	for def: BuildingDef in _build_buttons:
		var button := _build_buttons[def]
		for state in FONT_COLOR_STATES:
			if GameState.money < def.cost:
				button.add_theme_color_override(state, UNAFFORDABLE_COLOR)
			else:
				button.remove_theme_color_override(state)


func _refresh_hint() -> void:
	var text := ""
	match _mode:
		BuildTool.Mode.BUILD:
			text = "[b]%s[/b] — %s € · chantier %s · entretien %s €/j" % [
				_def.display_name, Format.thousands(_def.cost),
				Format.duration_hours(_def.build_hours), Format.thousands(_def.upkeep_per_day)]
			if _placement == null:
				text += "\nPlacez le bâtiment sur la carte · Échap : annuler"
			elif _placement.is_valid():
				var extra := ""
				if not _placement.cleared.is_empty():
					extra = " (défrichement de %d tuile%s)" % [
						_placement.cleared.size(), "s" if _placement.cleared.size() > 1 else ""]
				var available := Production.resource_available(GameState.world_map, _def, _placement.anchor)
				if available >= 0.0:
					extra += " · ressource à portée : %s t" % Format.thousands(roundi(available))
				text += "\n[color=%s]Clic : construire%s[/color] · Échap : annuler" % [OK_COLOR, extra]
			else:
				text += "\n[color=%s]%s[/color] · Échap : annuler" % [ERROR_COLOR, _placement.error]
		BuildTool.Mode.DEMOLISH:
			text = "[b]Démolition[/b] — cliquez sur un bâtiment, une ligne ou une route · Échap : annuler"
			var b := GameState.buildings.building_at(_hovered) if _hovered.x >= 0 else null
			if b and b.city:
				text += "\n[color=%s]Une ville ne peut pas être démolie[/color]" % ERROR_COLOR
			elif b:
				var refund := BuildingRegistry.refund_for(b)
				var fleet := GameState.logistics.vehicles_of(b)
				for v in fleet:
					refund += floori(v.def.cost * Logistics.SELL_REFUND)
				text += "\n[color=%s]%s %s%s : +%s €[/color]" % [
					ERROR_COLOR, "Annuler le chantier" if not b.is_complete() else "Démolir",
					b.def.display_name, " et ses %d véhicules" % fleet.size() if fleet.size() > 0 else "",
					Format.thousands(refund)]
			elif b == null and _hovered.x >= 0 and GameState.grid.has_line(_hovered):
				text += "\n[color=%s]Supprimer la ligne (sans remboursement)[/color]" % ERROR_COLOR
			elif b == null and _hovered.x >= 0 and GameState.roads.has_road(_hovered):
				text += "\n[color=%s]Supprimer la route (sans remboursement)[/color]" % ERROR_COLOR
		BuildTool.Mode.ROAD, BuildTool.Mode.LINE:
			text = "[b]%s[/b] — glisser pour tracer · Échap : annuler" % (
				"Route" if _mode == BuildTool.Mode.ROAD else "Ligne haute tension")
			if _trace_plan:
				if _trace_plan.is_valid():
					var n := _trace_plan.new_cells.size()
					text += "\n[color=%s]%d tuile%s : %s €[/color]" % [
						OK_COLOR, n, "s" if n > 1 else "", Format.thousands(_trace_plan.cost)]
				else:
					text += "\n[color=%s]%s[/color]" % [ERROR_COLOR, _trace_plan.error]
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
