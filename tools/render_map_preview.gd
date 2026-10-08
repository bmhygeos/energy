extends SceneTree
## Compose une image de la carte générée (sols + décors), sans affichage.
## Lancer : godot --headless -s res://tools/render_map_preview.gd -- <graine> <sortie.png> [largeur]

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var seed_value := int(args[0]) if args.size() > 0 else 1
	var out := args[1] if args.size() > 1 else "user://map_preview.png"
	var width := int(args[2]) if args.size() > 2 else 2048
	var map := MapGenerator.generate(Vector2i(64, 64), seed_value)
	var ground := Image.load_from_file("res://assets/tiles/terrain.png")
	var decor := Image.load_from_file("res://assets/tiles/decor.png")
	var bounds := Iso.world_bounds(map.size)
	var top_pad := TerrainTileSet.DECOR_SIZE.y - Iso.TILE_SIZE.y
	var img := Image.create_empty(int(bounds.size.x), int(bounds.size.y) + top_pad, false, Image.FORMAT_RGBA8)
	img.fill(Color("1b1f24"))
	var shift := -bounds.position + Vector2(0, top_pad)
	# Sols, puis décors dans l'ordre des Y croissants (comme le tri en Y).
	var order := range(map.cell_count())
	order.sort_custom(func(a: int, b: int) -> bool:
		return Iso.map_to_world(map.cell_of(a)).y < Iso.map_to_world(map.cell_of(b)).y)
	for pass_decor in [false, true]:
		for i: int in order:
			var cell := map.cell_of(i)
			var def := TerrainDb.get_def(map.terrain[i])
			var center := Iso.map_to_world(Vector2(cell)) + shift
			if not pass_decor:
				var src := Rect2i(Vector2i(map.variant[i], def.type) * Iso.TILE_SIZE, Iso.TILE_SIZE)
				img.blend_rect(ground, src, Vector2i(center - Iso.HALF))
			elif def.decor_row >= 0:
				var size := TerrainTileSet.DECOR_SIZE
				var src := Rect2i(Vector2i(map.variant[i], def.decor_row) * size, size)
				var dst := center - Vector2(size) / 2.0 - Vector2(0, (size.y - Iso.TILE_SIZE.y) / 2.0)
				img.blend_rect(decor, src, Vector2i(dst))
	img.resize(width, int(width * float(img.get_height()) / img.get_width()), Image.INTERPOLATE_LANCZOS)
	img.save_png(out)
	print("Aperçu : ", out)
	quit()
