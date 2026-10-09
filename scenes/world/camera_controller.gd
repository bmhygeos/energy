extends Camera2D
## Caméra de la carte : déplacement clavier (ZQSD/WASD selon la disposition,
## flèches), glisser avec le bouton du milieu ou droit, zoom à la molette
## centré sur le curseur, bornée à la carte.

@export var pan_speed := 900.0  ## Pixels écran par seconde.
@export var zoom_min := 0.25
@export var zoom_max := 2.0
@export var zoom_step := 1.15

var _dragging := false
var _bounds := Rect2()


func _ready() -> void:
	EventBus.game_started.connect(func(_seed: int) -> void: reset_view())
	reset_view()


func reset_view() -> void:
	_bounds = Iso.world_bounds(GameState.map_size)
	zoom = Vector2.ONE * 0.5
	position = _bounds.get_center()


func _process(delta: float) -> void:
	if get_viewport().gui_get_focus_owner() is LineEdit:
		return  # saisie de texte en cours : le clavier n'est pas pour la caméra
	var dir := Input.get_vector("camera_left", "camera_right", "camera_up", "camera_down")
	if dir != Vector2.ZERO:
		position += dir * pan_speed * delta / zoom.x
	if Input.is_action_pressed("camera_zoom_in"):
		_zoom_at(pow(zoom_step, delta * 6.0), get_viewport_rect().size / 2.0)
	elif Input.is_action_pressed("camera_zoom_out"):
		_zoom_at(pow(zoom_step, -delta * 6.0), get_viewport_rect().size / 2.0)
	_clamp_position()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_WHEEL_UP when mb.pressed:
				_zoom_at(zoom_step, mb.position)
			MOUSE_BUTTON_WHEEL_DOWN when mb.pressed:
				_zoom_at(1.0 / zoom_step, mb.position)
			MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT:
				_dragging = mb.pressed
			_:
				return  # clic gauche : laissé à la carte (sélection, construction)
	elif event is InputEventMouseMotion and _dragging:
		position -= (event as InputEventMouseMotion).relative / zoom.x
		_clamp_position()
	elif event is InputEventMagnifyGesture:
		_zoom_at((event as InputEventMagnifyGesture).factor, event.position)
	elif event is InputEventPanGesture:
		position += (event as InputEventPanGesture).delta * 20.0 / zoom.x
	elif event.is_action_pressed("camera_reset"):
		reset_view()
	else:
		return
	get_viewport().set_input_as_handled()


## Multiplie le zoom par [param factor] en gardant fixe le point du monde
## situé sous [param screen_point].
func _zoom_at(factor: float, screen_point: Vector2) -> void:
	var before := _screen_to_world(screen_point)
	var z := clampf(zoom.x * factor, zoom_min, zoom_max)
	zoom = Vector2(z, z)
	position += before - _screen_to_world(screen_point)
	_clamp_position()


func _screen_to_world(screen_point: Vector2) -> Vector2:
	return position + (screen_point - get_viewport_rect().size / 2.0) / zoom.x


func _clamp_position() -> void:
	position = position.clamp(_bounds.position, _bounds.end)
