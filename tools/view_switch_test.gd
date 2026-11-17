extends SceneTree
## Test sans affichage du passage entre la carte mondiale et la carte de la
## ville : calques, bâtiments affichés, menu de construction, caméra.
## Lancer : godot --headless -s res://tools/view_switch_test.gd

var _failures := 0


func _initialize() -> void:
	root.add_child(load("res://scenes/main.tscn").instantiate())
	await process_frame
	var gs: Node = root.get_node("GameState")
	gs.new_game(4242)
	root.get_node("GameClock").speed = 0
	for i in 3:
		await process_frame
	var map_view: Node = root.get_node("Main/World/MapView")
	var sprites: Node = map_view.get_node("Buildings")
	var camera: Camera2D = root.get_node("Main/Camera")
	_check(not gs.view_city and _sprite_count(sprites) == gs.buildings.count(), "monde : bâtiments du monde seulement")
	_check(map_view.get_node("Zones").visible and map_view._city_block.visible, "monde : zones et bloc de la ville")
	var world_position := camera.position
	gs.set_view(true)
	await process_frame
	_check(_sprite_count(sprites) == gs.city_buildings.count() and gs.city_buildings.count() > 0, "ville : maisons et grenier affichés")
	_check(not map_view.get_node("Zones").visible and not map_view._city_block.visible, "ville : calques du monde masqués")
	var build_menu: Node = root.get_node("Main/BuildMenu")
	var house_button: Button = build_menu._build_buttons[BuildingDb.get_def(&"house")]
	var well_button: Button = build_menu._build_buttons[BuildingDb.get_def(&"well")]
	_check(house_button.visible and not well_button.visible, "menu : bâtiments de la ville seulement")
	for good in Stockpile.COUNT:
		gs.stockpile.amount[good] = 1000.0
	var house := BuildingDb.get_def(&"house")
	gs.build(house, gs.free_city_spot(house))
	await process_frame
	_check(_sprite_count(sprites) == gs.city_buildings.count(), "maison construite : sprite ajouté")
	gs.set_view(false)
	await process_frame
	_check(_sprite_count(sprites) == gs.buildings.count() and camera.position == world_position, "retour au monde : vue et caméra retrouvées")
	_check(not house_button.visible and well_button.visible, "menu : bâtiments du monde")
	print("%s" % ("Passage ville / monde : OK" if _failures == 0 else "%d échec(s)" % _failures))
	quit(1 if _failures > 0 else 0)


static func _sprite_count(layer: Node) -> int:
	return layer.get_children().filter(func(n: Node) -> bool: return n is BuildingSprite and n.visible and n.def != null).size() \
		- (1 if layer._ghost and layer._ghost.visible else 0)


func _check(ok: bool, label: String) -> void:
	if not ok:
		_failures += 1
		print("ÉCHEC : " + label)
