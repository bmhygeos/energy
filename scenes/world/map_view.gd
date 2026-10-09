extends Node2D
## Rendu de la carte (sols, décors, overlays, bâtiments) et interactions à la
## souris selon l'outil actif : sélection, construction, démolition.

## Opacité des décors (arbres, sommets) quand un overlay est affiché.
const DECOR_DIMMED_ALPHA := 0.35

var map: WorldMap
var _hovered := Vector2i(-1, -1)
var _selected := Vector2i(-1, -1)
var _mode := BuildTool.Mode.SELECT
var _build_def: BuildingDef
var _placement: BuildingRegistry.Placement

@onready var _ground: TileMapLayer = $Ground
@onready var _decor: TileMapLayer = $Decor
@onready var _overlay: OverlayLayer = $Overlay
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
	for i in map.cell_count():
		_paint_cell(map.cell_of(i))
	_overlay.set_map(map)
	_set_hovered(Vector2i(-1, -1))
	_set_selected(Vector2i(-1, -1))
	EventBus.tool_changed.emit(BuildTool.Mode.SELECT, null)


func _paint_cell(cell: Vector2i) -> void:
	var i := map.index_of(cell)
	var def := TerrainDb.get_def(map.terrain[i])
	var v := map.variant[i]
	_ground.set_cell(cell, TerrainTileSet.GROUND_SOURCE, Vector2i(v, def.type))
	if def.decor_row >= 0:
		_decor.set_cell(cell, TerrainTileSet.DECOR_SOURCE, Vector2i(v, def.decor_row))
	else:
		_decor.erase_cell(cell)


func _process(_delta: float) -> void:
	_set_hovered(_cell_under_mouse())
	if _mode == BuildTool.Mode.BUILD:
		_update_placement()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
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
			if b:
				var refund := GameState.demolish(cell)
				EventBus.notified.emit("%s démoli : +%s €" % [b.def.display_name, Format.thousands(refund)])
		_:
			_set_selected(Vector2i(-1, -1) if cell == _selected else cell)


func _on_tool_changed(mode: int, def: BuildingDef) -> void:
	_mode = mode as BuildTool.Mode
	_build_def = def
	_placement = null
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


## Tuile sous la souris, ou (-1, -1) hors de la carte ou au-dessus de l'interface.
func _cell_under_mouse() -> Vector2i:
	if map == null or get_viewport().gui_get_hovered_control() != null:
		return Vector2i(-1, -1)
	var cell := _ground.local_to_map(_ground.get_local_mouse_position())
	return cell if map.has_cell(cell) else Vector2i(-1, -1)


func _set_hovered(cell: Vector2i) -> void:
	if cell != _hovered:
		_hovered = cell
		EventBus.tile_hovered.emit(cell)


func _set_selected(cell: Vector2i) -> void:
	if cell != _selected:
		_selected = cell
		EventBus.tile_selected.emit(cell)
