extends SceneTree
## Test de fumée de l'interface avec de vrais événements souris : choix d'un
## outil dans le menu, construction d'une centrale et d'un bûcheron, tracé
## d'une ligne HT au glisser, Échap, sélection d'une tuile, bâtiment
## verrouillé, arbre technologique (T, clic sur une technologie).
## Nécessite un affichage (pas --headless) ; déplace le pointeur réel.
## Lancer : godot -s res://tools/ui_click_test.gd

var _failures := 0
var _map_view: Node
var _gs: Node


func _initialize() -> void:
	DisplayServer.window_set_position(Vector2i.ZERO)
	root.add_child(load("res://scenes/main.tscn").instantiate())
	await process_frame
	_gs = root.get_node("GameState")
	_gs.new_game(42)
	root.get_node("GameClock").speed = 0
	_map_view = root.get_node("Main/World/MapView")
	for i in 5:
		await process_frame

	await _press_tool("Centrale biomasse")
	_check(_map_view._mode == 1, "outil Construire actif")
	var n := _gs.buildings.count() as int
	await _click(await _find_spot(BuildingDb.get_def(&"biomass_plant")))
	_check(_gs.buildings.count() == n + 1, "centrale construite au clic")

	await _press_tool("Bûcheron")
	n = _gs.buildings.count()
	await _click(await _find_spot(BuildingDb.get_def(&"lumberjack")))
	_check(_gs.buildings.count() == n + 1, "bûcheron construit au clic")

	await _press_tool("Ligne HT")
	_check(_map_view._mode == 4, "outil Ligne HT actif")
	await _move(Vector2(700, 600))
	_button(Vector2(700, 600), true)
	await _move(Vector2(900, 650))
	_button(Vector2(900, 650), false)
	await process_frame
	_check(_gs.grid.tile_count() > 1, "ligne tracée au glisser (%d tuiles)" % _gs.grid.tile_count())

	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.physical_keycode = KEY_ESCAPE
	esc.pressed = true
	root.push_input(esc)
	await process_frame
	_check(_map_view._mode == 0, "Échap : retour à la sélection")
	await _click(Vector2(800, 500))
	_check(_map_view._selected.x >= 0, "tuile sélectionnée au clic")

	var hud: Node = root.get_node("Main/HUD")
	# Indices de OverlayLayer.Mode (non référençable ici : le script est compilé
	# avant les autoloads).
	var deposits_mode := 5
	var deposits_button: Button = hud._overlay_buttons[deposits_mode]
	_check(deposits_button.disabled, "calque Gisements verrouillé avant Prospection")
	var o_key := InputEventKey.new()
	o_key.keycode = KEY_O
	o_key.physical_keycode = KEY_O
	o_key.pressed = true
	_check(deposits_button.text == "Gisements", "bouton du calque Gisements")
	for i in hud._overlay_buttons.size():
		root.push_input(o_key)
		await process_frame
		_check(hud._overlay_mode != deposits_mode, "O saute le calque Gisements")
	var mine_button: Button = null
	for b in root.get_node("Main/BuildMenu").find_children("*", "Button", true, false):
		if (b as Button).text.begins_with("Mine de charbon"):
			mine_button = b
	_check(mine_button != null and mine_button.disabled, "mine verrouillée sans la technologie")

	var key := InputEventKey.new()
	key.keycode = KEY_T
	key.physical_keycode = KEY_T
	key.pressed = true
	root.push_input(key)
	for i in 3:
		await process_frame
	var tree: Node = root.get_node("Main/TechTree")
	_check(tree.is_open(), "T ouvre l'arbre technologique")
	var tech_button: Button = tree._buttons[&"mining"]
	await _click(tech_button.get_global_rect().get_center())
	_check(_gs.research.queue == [&"prospecting", &"mining"], "clic : technologie et prérequis en file (%s)" % [_gs.research.queue])
	var nodes: Array = tree._nodes.values()
	var overlaps := 0
	for a: GraphNode in nodes:
		for b: GraphNode in nodes:
			if a != b and Rect2(a.position_offset, a.size).grow(-1).intersects(Rect2(b.position_offset, b.size).grow(-1)):
				overlaps += 1
	_check(overlaps == 0, "aucun nœud de l'arbre n'en recouvre un autre (%d)" % overlaps)
	_gs._on_techs_done(_gs.research.add_points(5000.0))
	for i in 2:
		await process_frame
	_check(not mine_button.disabled, "mine déverrouillée après la recherche")
	_check(not deposits_button.disabled, "calque Gisements disponible après Prospection")
	root.push_input(esc)
	await process_frame
	_check(not tree.is_open(), "Échap ferme l'arbre")

	print("Interface : %s" % ("OK" if _failures == 0 else "%d échec(s)" % _failures))
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures += 1
		printerr("ÉCHEC : ", label)


func _move(pos: Vector2) -> void:
	Input.warp_mouse(pos)
	var m := InputEventMouseMotion.new()
	m.position = pos
	m.global_position = pos
	root.push_input(m)
	await process_frame
	await process_frame


func _button(pos: Vector2, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = pos
	e.global_position = pos
	root.push_input(e)


func _click(pos: Vector2) -> void:
	await _move(pos)
	_button(pos, true)
	await process_frame
	_button(pos, false)
	await process_frame


func _press_tool(prefix: String) -> void:
	for b in root.get_node("Main/BuildMenu").find_children("*", "Button", true, false):
		if (b as Button).text.begins_with(prefix):
			await _click((b as Button).get_global_rect().get_center())
			return
	_check(false, "bouton « %s » introuvable" % prefix)


## Point de l'écran (hors menus) dont la tuile survolée accepte [param def].
func _find_spot(def: BuildingDef) -> Vector2:
	for y in range(300, 800, 20):
		for x in range(400, 1200, 20):
			await _move(Vector2(x, y))
			var cell: Vector2i = _map_view._hovered
			if cell.x >= 0 and _gs.check_placement(def, cell).is_valid():
				return Vector2(x, y)
	_check(false, "aucun emplacement pour %s" % def.id)
	return Vector2.ZERO
