class_name BuildingsLayer
extends Node2D
## Sprites des bâtiments de la carte affichée (ville ou monde ; triés en Y
## avec les décors) et fantôme de placement.

const GHOST_VALID := Color(0.7, 1.0, 0.7, 0.6)
const GHOST_INVALID := Color(1.0, 0.45, 0.4, 0.55)

var _sprites: Dictionary[int, BuildingSprite] = {}
## Bâtiments affichés (pour l'avancement des chantiers).
var _shown_buildings: Dictionary[int, Building] = {}
var _ghost: BuildingSprite


func _ready() -> void:
	EventBus.game_started.connect(func(_seed: int) -> void: reload())
	EventBus.view_changed.connect(reload)
	EventBus.city_selected.connect(reload)
	EventBus.cities_changed.connect(reload)
	EventBus.building_placed.connect(func(b: Building) -> void:
		if _shown(b):
			_add(b))
	EventBus.building_removed.connect(func(b: Building) -> void:
		if _sprites.has(b.id):
			_sprites[b.id].queue_free()
			_sprites.erase(b.id)
			_shown_buildings.erase(b.id))
	EventBus.building_completed.connect(func(b: Building) -> void:
		if _sprites.has(b.id):
			_sprites[b.id].progress = 1.0)
	EventBus.tick_advanced.connect(_on_tick)
	reload()


func reload() -> void:
	for sprite in _sprites.values():
		sprite.queue_free()
	_sprites.clear()
	_shown_buildings.clear()
	hide_ghost()
	if GameState.buildings == null:
		return
	if GameState.view_city:
		for b in GameState.selected.city_buildings.all():
			_add(b)
	else:
		# Carte mondiale : les bâtiments du monde de toutes les villes.
		for c in GameState.cities:
			for b in c.buildings.all():
				_add(b)


## [param b] est-il sur la carte affichée (ville choisie, ou monde) ?
static func _shown(b: Building) -> bool:
	if GameState.view_city:
		return b.def.site == BuildingDef.Site.CITY and GameState.selected.city_buildings.building_at(b.anchor) == b
	return b.def.site == BuildingDef.Site.WORLD


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
	add_child(sprite)
	_sprites[b.id] = sprite
	_shown_buildings[b.id] = b


func _on_tick(_tick: int) -> void:
	for id: int in _shown_buildings:
		var b := _shown_buildings[id]
		if not b.is_complete():
			_sprites[id].progress = b.progress_ratio()
