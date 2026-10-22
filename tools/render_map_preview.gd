extends SceneTree
## Image de la planète en projection équirectangulaire (un pixel tous les
## [pas] tuiles, couleur du terrain), avec le territoire de départ encadré en
## rouge, et proportions des terrains. Sans affichage.
## Lancer : godot --headless -s res://tools/render_map_preview.gd -- <graine> <sortie.png> [pas]

const PLANET_SIZE := Vector2i(1024, 512)


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var seed_value := int(args[0]) if args.size() > 0 else 1
	var out := args[1] if args.size() > 1 else "user://planet.png"
	var step := int(args[2]) if args.size() > 2 else 2
	var start_ms := Time.get_ticks_msec()
	var generator := MapGenerator.new(seed_value, PLANET_SIZE)
	var img := Image.create_empty(PLANET_SIZE.x / step, PLANET_SIZE.y / step, false, Image.FORMAT_RGBA8)
	var counts := {}
	for py in img.get_height():
		for px in img.get_width():
			var t := generator.fields(Vector2i(px, py) * step).terrain
			counts[t] = counts.get(t, 0) + 1
			img.set_pixel(px, py, TerrainDb.get_def(t).color)
	var home := StartSite.find(generator)
	var rect := StartSite.territory_rect(home)
	for x in range(rect.position.x, rect.end.x):
		for y in range(rect.position.y, rect.end.y):
			img.set_pixel(posmod(x, PLANET_SIZE.x) / step, y / step, Color.RED)
	img.save_png(out)
	var total := img.get_width() * img.get_height()
	var parts := PackedStringArray()
	for t: int in counts:
		parts.append("%s %.1f %%" % [TerrainDb.get_def(t).display_name, 100.0 * counts[t] / total])
	print(", ".join(parts))
	print("Départ : %s (%s) — %d ms" % [home, Format.coordinates(90.0 - (home.y + 0.5) * 180.0 / PLANET_SIZE.y, (home.x + 0.5) * 360.0 / PLANET_SIZE.x - 180.0), Time.get_ticks_msec() - start_ms])
	print("Aperçu : ", out)
	quit()
