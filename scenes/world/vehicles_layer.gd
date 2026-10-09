extends Node2D
## Sprites des véhicules, triés en Y avec les bâtiments et les décors.

var _sprites: Dictionary[int, VehicleSprite] = {}


func _ready() -> void:
	EventBus.vehicle_added.connect(_add)
	EventBus.vehicle_removed.connect(func(v: Vehicle) -> void:
		if _sprites.has(v.id):
			_sprites[v.id].queue_free()
			_sprites.erase(v.id))
	EventBus.game_started.connect(func(_seed: int) -> void: _reload())
	_reload()


func _reload() -> void:
	for sprite in _sprites.values():
		sprite.queue_free()
	_sprites.clear()
	if GameState.logistics:
		for v in GameState.logistics.vehicles:
			_add(v)


func _add(v: Vehicle) -> void:
	var sprite := VehicleSprite.new()
	sprite.vehicle = v
	sprite.visible = false
	add_child(sprite)
	_sprites[v.id] = sprite
