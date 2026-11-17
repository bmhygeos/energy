class_name GlobeView
extends CanvasLayer
## Vue globe (ère spatiale, dès le premier satellite) : la planète en 3D, les
## tuiles connues avec la couleur de leur terrain (les territoires teintés,
## les villes marquées), les inconnues sombres, et les satellites en orbite.
## Glisser : tourner ; molette : zoom ; V ou Échap : fermer.

const BACKGROUND := Color(0.02, 0.03, 0.07)
const UNKNOWN_COLOR := Color(0.07, 0.08, 0.1)
const TERRITORY_TINT := Color(1.0, 0.82, 0.3)
const TERRITORY_MIX := 0.3
const CITY_COLOR := Color(1.0, 0.25, 0.2)
## Demi-côté (pixels de la texture) du repère d'une ville.
const CITY_MARK := 2
const ORBIT_RADIUS := 1.35
const ORBIT_TILT := 0.9
## Tours d'orbite par seconde.
const ORBIT_SPEED := 0.05
const DISTANCE_MIN := 1.6
const DISTANCE_MAX := 5.0
## Radians par pixel glissé.
const DRAG_SPEED := 0.006

var _root: Control
var _viewport: SubViewport
var _camera: Camera3D
var _planet: MeshInstance3D
var _material: StandardMaterial3D
var _satellites: Array[MeshInstance3D] = []
var _status: Label
var _yaw := 0.0
var _pitch := 0.0
var _distance := 3.0
var _orbit := 0.0
var _dragging := false
## La texture doit être refaite (territoire changé depuis).
var _dirty := true


func _ready() -> void:
	layer = 20
	_build()
	_root.hide()
	EventBus.territory_changed.connect(func() -> void: _dirty = true)
	EventBus.tiles_changed.connect(func(_c: Array[Vector2i]) -> void: _dirty = true)
	EventBus.cities_changed.connect(func() -> void: _dirty = true)
	EventBus.game_started.connect(func(_s: int) -> void:
		_dirty = true
		_root.hide())


## Ouverte seulement avec un satellite en orbite.
static func available() -> bool:
	return GameState.space != null and GameState.space.satellites > 0


func is_open() -> bool:
	return _root.visible


func toggle() -> void:
	if _root.visible:
		_root.hide()
		return
	if not available():
		EventBus.notified.emit("Vue globe : il faut un satellite en orbite (recherche Fusée, base de lancement)")
		return
	if _dirty:
		_paint()
	_face(GameState.selected.home)
	_root.show()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and (key.keycode == KEY_V or key.keycode == KEY_ESCAPE and _root.visible) \
			and not get_viewport().gui_get_focus_owner() is LineEdit:
		toggle()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not _root.visible:
		return
	_orbit = fmod(_orbit + delta * ORBIT_SPEED * TAU, TAU)
	for k in _satellites.size():
		var a := _orbit + TAU * k / _satellites.size()
		var p := Vector3(cos(a), 0.0, sin(a)) * ORBIT_RADIUS
		_satellites[k].position = Basis(Vector3.RIGHT, ORBIT_TILT + 0.3 * k) * p
	_place_camera()


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var background := ColorRect.new()
	background.color = BACKGROUND
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(background)
	var container := SubViewportContainer.new()
	container.stretch = true
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.gui_input.connect(_on_gui_input)
	_root.add_child(container)
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	container.add_child(_viewport)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = BACKGROUND
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.55, 0.58, 0.65)
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	_viewport.add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.5, 0.8, 0.0)
	_viewport.add_child(sun)
	_camera = Camera3D.new()
	_camera.fov = 45.0
	_viewport.add_child(_camera)
	_planet = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 96
	sphere.rings = 48
	_planet.mesh = sphere
	_material = StandardMaterial3D.new()
	_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_planet.material_override = _material
	_viewport.add_child(_planet)
	var header := HBoxContainer.new()
	header.position = Vector2(16, 12)
	_root.add_child(header)
	var title := Label.new()
	title.text = "Vue globe"
	title.add_theme_font_size_override("font_size", 22)
	header.add_child(title)
	_status = Label.new()
	_status.modulate = Color(1, 1, 1, 0.7)
	header.add_child(_status)
	var close := Button.new()
	close.text = "×"
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(toggle)
	header.add_child(close)
	var help := Label.new()
	help.text = "Glisser : tourner  ·  molette : zoom  ·  V ou Échap : fermer"
	help.modulate = Color(1, 1, 1, 0.55)
	help.anchor_top = 1.0
	help.anchor_bottom = 1.0
	help.offset_left = 16.0
	help.offset_top = -36.0
	_root.add_child(help)


## Texture équirectangulaire de la planète : terrains des tuiles connues,
## territoires teintés, villes marquées ; satellites selon leur nombre.
func _paint() -> void:
	var map: WorldMap = GameState.world_map
	var territory: Territory = GameState.territory
	var w := map.size.x
	var h := map.size.y
	var data := PackedByteArray()
	data.resize(w * h * 3)
	var dark := [roundi(UNKNOWN_COLOR.r * 255), roundi(UNKNOWN_COLOR.g * 255), roundi(UNKNOWN_COLOR.b * 255)]
	for i in w * h:
		data[i * 3] = dark[0]
		data[i * 3 + 1] = dark[1]
		data[i * 3 + 2] = dark[2]
	# Couleurs par terrain, préparées une fois (sur la planète entière, la
	# boucle passe sur un demi-million de tuiles).
	var plain: Array[Color] = []
	var owned: Array[Color] = []
	for t in TerrainDef.Type.size():
		var color := TerrainDb.get_def(t).color
		plain.append(color)
		owned.append(color.lerp(TERRITORY_TINT, TERRITORY_MIX))
	var known := 0
	for cell in territory.known_cells():
		var t := map.get_terrain(cell)
		_put(data, w, cell, owned[t] if territory.is_owned(cell) else plain[t])
		known += 1
	for c in GameState.cities:
		for dy in range(-CITY_MARK, CITY_MARK + 1):
			for dx in range(-CITY_MARK, CITY_MARK + 1):
				var cell := map.wrap_cell(c.home + Vector2i(dx, dy))
				if map.has_cell(cell):
					_put(data, w, cell, CITY_COLOR)
	_material.albedo_texture = ImageTexture.create_from_image(Image.create_from_data(w, h, false, Image.FORMAT_RGB8, data))
	_dirty = false
	_refresh_satellites()
	_status.text = "   %d %% de la planète connue  ·  %d satellite%s" % [roundi(100.0 * known / (w * h)),
		GameState.space.satellites, "s" if GameState.space.satellites > 1 else ""]


static func _put(data: PackedByteArray, width: int, cell: Vector2i, color: Color) -> void:
	var i := (cell.y * width + cell.x) * 3
	data[i] = roundi(color.r * 255)
	data[i + 1] = roundi(color.g * 255)
	data[i + 2] = roundi(color.b * 255)


func _refresh_satellites() -> void:
	var count: int = mini(GameState.space.satellites, 6)
	while _satellites.size() < count:
		var satellite := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.05, 0.02, 0.08)
		satellite.mesh = box
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.9, 0.9, 0.95)
		material.emission_enabled = true
		material.emission = Color(0.6, 0.7, 1.0)
		satellite.material_override = material
		_viewport.add_child(satellite)
		_satellites.append(satellite)
	while _satellites.size() > count:
		_satellites.pop_back().queue_free()


## Tourne la vue vers la tuile [param cell] (texture équirectangulaire posée
## sur la sphère : u = longitude, v = latitude du nord au sud).
func _face(cell: Vector2i) -> void:
	var map: WorldMap = GameState.world_map
	var u := (cell.x + 0.5) / map.size.x
	var v := (cell.y + 0.5) / map.size.y
	var p := Vector3(sin(TAU * u) * sin(PI * v), cos(PI * v), cos(TAU * u) * sin(PI * v))
	_yaw = atan2(p.x, p.z)
	_pitch = asin(clampf(p.y, -1.0, 1.0))
	_place_camera()


func _place_camera() -> void:
	_pitch = clampf(_pitch, -1.45, 1.45)
	_camera.position = Vector3(sin(_yaw) * cos(_pitch), sin(_pitch), cos(_yaw) * cos(_pitch)) * _distance
	_camera.look_at(Vector3.ZERO, Vector3.UP)


func _on_gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button:
		if button.button_index == MOUSE_BUTTON_LEFT or button.button_index == MOUSE_BUTTON_RIGHT:
			_dragging = button.pressed
		elif button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_UP:
			_distance = maxf(DISTANCE_MIN, _distance * 0.9)
		elif button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_distance = minf(DISTANCE_MAX, _distance * 1.1)
	var motion := event as InputEventMouseMotion
	if motion and _dragging:
		_yaw -= motion.relative.x * DRAG_SPEED
		_pitch += motion.relative.y * DRAG_SPEED
