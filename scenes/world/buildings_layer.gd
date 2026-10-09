class_name BuildingsLayer
extends Node2D
## Sprites des bâtiments (triés en Y avec les décors) et fantôme de placement.

const GHOST_VALID := Color(0.7, 1.0, 0.7, 0.6)
const GHOST_INVALID := Color(1.0, 0.45, 0.4, 0.55)

var _sprites: Dictionary[int, BuildingSprite] = {}
var _ghost: BuildingSprite


func _ready() -> void:
	EventBus.game_started.connect(func(_seed: int) -> void: reload())
	EventBus.building_placed.connect(_add)
	EventBus.building_removed.connect(func(b: Building) -> void:
		if _sprites.has(b.id):
			_sprites[b.id].queue_free()
			_sprites.erase(b.id))
	EventBus.building_completed.connect(func(b: Building) -> void:
		if _sprites.has(b.id):
			_sprites[b.id].progress = 1.0)
	EventBus.building_status_changed.connect(func(b: Building) -> void:
		if _sprites.has(b.id):
			_sprites[b.id].status = b.status)
	EventBus.tick_advanced.connect(_on_tick)
	reload()


func reload() -> void:
	for sprite in _sprites.values():
		sprite.queue_free()
	_sprites.clear()
	hide_ghost()
	if GameState.buildings:
		for b in GameState.buildings.all():
			_add(b)


## Affiche le fantôme de [param def] ancré en [param anchor].
func show_ghost(def: BuildingDef, anchor: Vector2i, valid: bool) -> void:
	if _ghost == null:
		_ghost = BuildingSprite.new()
		add_child(_ghost)
	if _ghost.def != def or _ghost.anchor != anchor:
		_ghost.setup(def, anchor)
	_ghost.modulate = GHOST_VALID if valid else GHOST_INVALID
	_ghost.show()


func hide_ghost() -> void:
	if _ghost:
		_ghost.hide()


func _add(b: Building) -> void:
	var sprite := BuildingSprite.new()
	sprite.setup(b.def, b.anchor, b.progress_ratio())
	sprite.status = b.status
	add_child(sprite)
	_sprites[b.id] = sprite


func _on_tick(_tick: int) -> void:
	for b in GameState.buildings.all():
		if not b.is_complete():
			_sprites[b.id].progress = b.progress_ratio()
