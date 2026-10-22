extends Node2D
## Rendu des tuiles connues de la planète (sols, décors, brume, overlays,
## bâtiments), dans le repère de GameState.display_cell, et interactions à la
## souris selon l'outil actif : sélection, construction, démolition,
## peinture et effacement de zones (glisser : rectangle).

## Opacité des décors (arbres, sommets) quand un overlay est affiché.
const DECOR_DIMMED_ALPHA := 0.35

var map: WorldMap
var _hovered := Vector2i(-1, -1)
var _selected := Vector2i(-1, -1)
var _mode := BuildTool.Mode.SELECT
var _build_def: BuildingDef
var _zone_def: ZoneDef
var _placement: BuildingRegistry.Placement
## Peinture de zones : tuile de départ du glisser ((-1, -1) : pas de glisser).
var _drag_start := Vector2i(-1, -1)
var _drag_end := Vector2i(-1, -1)
var _zone_plan: ZoneMap.Plan

@onready var _ground: TileMapLayer = $Ground
@onready var _decor: TileMapLayer = $Decor
@onready var _overlay: OverlayLayer = $Overlay
@onready var _fog: FogLayer = $Fog
@onready var _buildings: BuildingsLayer = $Buildings


func _ready() -> void:
	var tile_set := TerrainTileSet.build()
	_ground.tile_set = tile_set
	_decor.tile_set = tile_set
	EventBus.game_started.connect(func(_seed: int) -> void: _load_map(GameState.world_map))
	EventBus.overlay_changed.connect(func(mode: int) -> void:
		_decor.modulate.a = 1.0 if mode == OverlayLayer.Mode.NONE else DECOR_DIMMED_ALPHA)
	EventBus.tiles_changed.connect(func(cells: Array[Vector2i]) -> void:
		for cell in cells:
			_paint_cell(cell))
	EventBus.tool_changed.connect(_on_tool_changed)
	_load_map(GameState.world_map)


func _load_map(p_map: WorldMap) -> void:
	map = p_map
	_ground.clear()
	_decor.clear()
	for cell in GameState.territory.known_cells():
		_paint_cell(GameState.display_cell(cell))
	_overlay.set_map(map)
	_fog.refresh()
	_set_hovered(Vector2i(-1, -1))
	_set_selected(Vector2i(-1, -1))
	EventBus.tool_changed.emit(BuildTool.Mode.SELECT, null)


## Peint [param cell] (repère de la vue), ou l'efface si elle est inconnue.
func _paint_cell(cell: Vector2i) -> void:
	if not GameState.territory.is_known(cell):
		_ground.erase_cell(cell)
		_decor.erase_cell(cell)
		return
	var def := TerrainDb.get_def(map.get_terrain(cell))
	var v := map.get_variant(cell)
	_ground.set_cell(cell, TerrainTileSet.GROUND_SOURCE, Vector2i(v, def.type))
	if def.decor_row >= 0:
		_decor.set_cell(cell, TerrainTileSet.DECOR_SOURCE, Vector2i(v, def.decor_row))
	else:
		_decor.erase_cell(cell)


func _process(_delta: float) -> void:
	_set_hovered(_cell_under_mouse())
	if _mode == BuildTool.Mode.BUILD:
		_update_placement()
	elif _is_zone_mode():
		_update_zone_plan()


func _unhandled_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb and mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
		if not _is_zone_mode() or _drag_start.x < 0:
			return
		_update_zone_plan()
		if _zone_plan:
			GameState.apply_zones(_zone_plan)
		_drag_start = Vector2i(-1, -1)
		_zone_plan = null
	elif mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		_click(_cell_under_mouse())
	elif event.is_action_pressed("ui_cancel") \
			and (_mode != BuildTool.Mode.SELECT or _selected.x >= 0):
		if _mode != BuildTool.Mode.SELECT:
			EventBus.tool_changed.emit(BuildTool.Mode.SELECT, null)
		else:
			_set_selected(Vector2i(-1, -1))
	elif event.is_action_pressed("tool_demolish"):
		var next := BuildTool.Mode.SELECT if _mode == BuildTool.Mode.DEMOLISH else BuildTool.Mode.DEMOLISH
		EventBus.tool_changed.emit(next, null)
	else:
		return
	get_viewport().set_input_as_handled()


func _click(cell: Vector2i) -> void:
	match _mode:
		BuildTool.Mode.BUILD:
			if cell.x >= 0:
				GameState.build(_build_def, cell)
				_placement = null  # force le recalcul de l'aperçu
		BuildTool.Mode.DEMOLISH:
			var b := GameState.buildings.building_at(cell)
			if b and GameState.demolish(cell):
				EventBus.notified.emit("%s démoli" % b.def.display_name)
		BuildTool.Mode.ZONE, BuildTool.Mode.ERASE_ZONE:
			if cell.x >= 0:
				_drag_start = cell
				_drag_end = cell
				_zone_plan = null
		_:
			_set_selected(Vector2i(-1, -1) if cell == _selected else cell)


func _on_tool_changed(mode: int, def: Resource) -> void:
	_mode = mode as BuildTool.Mode
	_build_def = def as BuildingDef
	_zone_def = def as ZoneDef
	_placement = null
	_drag_start = Vector2i(-1, -1)
	_zone_plan = null
	EventBus.zone_plan_previewed.emit(null)
	if _is_zone_mode():
		_set_selected(Vector2i(-1, -1))
	if _mode == BuildTool.Mode.BUILD:
		_set_selected(Vector2i(-1, -1))
		_update_placement()
	else:
		_buildings.hide_ghost()
		EventBus.placement_previewed.emit(null)


## Recalcule l'aperçu de placement sous la souris ; ne le publie que s'il a
## changé (emplacement, validité ou motif).
func _update_placement() -> void:
	if _hovered.x < 0:
		if _placement:
			_placement = null
			_buildings.hide_ghost()
			EventBus.placement_previewed.emit(null)
		return
	var p := GameState.check_placement(_build_def, _hovered)
	if _placement and _placement.anchor == p.anchor and _placement.error == p.error:
		return
	_placement = p
	_buildings.show_ghost(_build_def, _hovered, p.is_valid())
	EventBus.placement_previewed.emit(p)


func _is_zone_mode() -> bool:
	return _mode == BuildTool.Mode.ZONE or _mode == BuildTool.Mode.ERASE_ZONE


## Recalcule l'aperçu de la peinture (glisser en cours, sinon la tuile
## survolée) ; ne le publie que s'il a changé.
func _update_zone_plan() -> void:
	if _hovered.x >= 0:
		_drag_end = _hovered
	var start := _drag_start if _drag_start.x >= 0 else _hovered
	if start.x < 0:
		if _zone_plan:
			_zone_plan = null
			EventBus.zone_plan_previewed.emit(null)
		return
	var end := _drag_end if _drag_start.x >= 0 else _hovered
	var plan := GameState.plan_zones(_zone_def if _mode == BuildTool.Mode.ZONE else null, start, end)
	if _zone_plan and _zone_plan.cells == plan.cells and _zone_plan.changed == plan.changed:
		return
	_zone_plan = plan
	EventBus.zone_plan_previewed.emit(plan)


## Tuile connue sous la souris, ou (-1, -1) ailleurs ou au-dessus de l'interface.
func _cell_under_mouse() -> Vector2i:
	if map == null or get_viewport().gui_get_hovered_control() != null:
		return Vector2i(-1, -1)
	var cell := _ground.local_to_map(_ground.get_local_mouse_position())
	return cell if GameState.territory.is_known(cell) else Vector2i(-1, -1)


func _set_hovered(cell: Vector2i) -> void:
	if cell != _hovered:
		_hovered = cell
		EventBus.tile_hovered.emit(cell)


func _set_selected(cell: Vector2i) -> void:
	if cell != _selected:
		_selected = cell
		EventBus.tile_selected.emit(cell)
