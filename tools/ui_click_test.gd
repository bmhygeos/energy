extends SceneTree
## Test de fumée de l'interface avec de vrais événements souris : choix d'un
## outil dans le menu, construction et démolition d'un grenier, peinture et
## effacement de zones au glisser, Échap,
## sélection d'une tuile, calques (O), panneau Main-d'œuvre (M) et fenêtre
## des statistiques (G).
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

	await _press_tool("Grenier")
	_check(_map_view._mode == 1, "outil Construire actif")
	var start_count: int = _gs.buildings.count()
	var spot := await _find_spot(BuildingDb.get_def(&"granary"))
	await _click(spot)
	_check(_gs.buildings.count() == start_count + 1, "grenier construit au clic")

	await _press_tool("Démolir")
	_check(_map_view._mode == 2, "outil Démolir actif")
	await _click(spot)
	_check(_gs.buildings.count() == start_count, "grenier démoli au clic")

	await _press_tool("Élevage")
	_check(_map_view._mode == 3, "outil Zone actif")
	await _drag(Vector2(650, 430), Vector2(950, 470))
	var zoned: int = _gs.zones.all_cells().size()
	_check(zoned > 3, "zone peinte au glisser (%d tuiles)" % zoned)
	_check(_gs.labor.employed() > 0, "des chômeurs affectés à la zone (%d)" % _gs.labor.employed())
	var labor_panel: Node = root.get_node("Main/LaborPanel")
	root.push_input(_key(KEY_M))
	await process_frame
	_check(labor_panel.is_open(), "M ouvre le panneau Main-d'œuvre")
	root.push_input(_key(KEY_M))
	await process_frame
	_check(not labor_panel.is_open(), "M referme le panneau")
	await _press_tool("Effacer les zones")
	_check(_map_view._mode == 4, "outil Effacer actif")
	await _drag(Vector2(600, 400), Vector2(1000, 500))
	_check(_gs.zones.all_cells().size() < zoned, "zones effacées au glisser (%d → %d)" % [zoned, _gs.zones.all_cells().size()])

	var esc := _key(KEY_ESCAPE)
	root.push_input(esc)
	await process_frame
	_check(_map_view._mode == 0, "Échap : retour à la sélection")
	await _click(Vector2(800, 500))
	_check(_map_view._selected.x >= 0, "tuile sélectionnée au clic")

	var hud: Node = root.get_node("Main/HUD")
	var seen := {}
	for i in hud._overlay_buttons.size():
		root.push_input(_key(KEY_O))
		await process_frame
		seen[hud._overlay_mode] = true
		_check(not hud._overlay_buttons[i].disabled, "calque %d disponible" % i)
	_check(seen.size() == hud._overlay_buttons.size(), "O fait défiler tous les calques")

	var stats: Node = root.get_node("Main/StatsWindow")
	root.push_input(_key(KEY_G))
	await process_frame
	_check(stats.is_open(), "G ouvre les statistiques")
	root.push_input(esc)
	await process_frame
	_check(not stats.is_open(), "Échap ferme les statistiques")

	print("Interface : %s" % ("OK" if _failures == 0 else "%d échec(s)" % _failures))
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures += 1
		printerr("ÉCHEC : ", label)


func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = true
	return e


func _move(pos: Vector2) -> void:
	Input.warp_mouse(pos)
	var m := InputEventMouseMotion.new()
	m.position = pos
	m.global_position = pos
	root.push_input(m)
	for i in 3:
		await process_frame


func _button(pos: Vector2, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = pos
	e.global_position = pos
	root.push_input(e)


func _drag(from: Vector2, to: Vector2) -> void:
	await _move(from)
	_button(from, true)
	await process_frame
	await _move(to)
	_button(to, false)
	await process_frame


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
