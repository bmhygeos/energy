extends Node2D
## Rendu de la carte (sols, décors, overlays) et sélection de tuile à la souris.

## Opacité des décors (arbres, sommets) quand un overlay est affiché.
const DECOR_DIMMED_ALPHA := 0.35

var map: WorldMap
var _hovered := Vector2i(-1, -1)
var _selected := Vector2i(-1, -1)

@onready var _ground: TileMapLayer = $Ground
@onready var _decor: TileMapLayer = $Decor
@onready var _overlay: OverlayLayer = $Overlay


func _ready() -> void:
	var tile_set := TerrainTileSet.build()
	_ground.tile_set = tile_set
	_decor.tile_set = tile_set
	EventBus.game_started.connect(func(_seed: int) -> void: _load_map(GameState.world_map))
	EventBus.overlay_changed.connect(func(mode: int) -> void:
		_decor.modulate.a = 1.0 if mode == OverlayLayer.Mode.NONE else DECOR_DIMMED_ALPHA)
	_load_map(GameState.world_map)


func _load_map(p_map: WorldMap) -> void:
	map = p_map
	_ground.clear()
	_decor.clear()
	for i in map.cell_count():
		var cell := map.cell_of(i)
		var def := TerrainDb.get_def(map.terrain[i])
		var v := map.variant[i]
		_ground.set_cell(cell, TerrainTileSet.GROUND_SOURCE, Vector2i(v, def.type))
		if def.decor_row >= 0:
			_decor.set_cell(cell, TerrainTileSet.DECOR_SOURCE, Vector2i(v, def.decor_row))
	_overlay.set_map(map)
	_set_hovered(Vector2i(-1, -1))
	_set_selected(Vector2i(-1, -1))


func _process(_delta: float) -> void:
	_set_hovered(_cell_under_mouse())


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var cell := _cell_under_mouse()
		_set_selected(Vector2i(-1, -1) if cell == _selected else cell)
	elif event.is_action_pressed("ui_cancel") and _selected.x >= 0:
		_set_selected(Vector2i(-1, -1))
	else:
		return
	get_viewport().set_input_as_handled()


func _cell_under_mouse() -> Vector2i:
	if map == null:
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
