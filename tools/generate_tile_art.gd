extends SceneTree
## Génère les atlas de tuiles provisoires à partir des couleurs des TerrainDef :
##   assets/tiles/terrain.png : sols 128×64, une ligne par terrain, 4 variantes ;
##   assets/tiles/decor.png   : décors 128×128 (arbres, sommets), une ligne par decor_row.
## Lancer : godot --headless -s res://tools/generate_tile_art.gd
## (à refaire après modification des couleurs ; remplaçable par de vrais graphismes).

const T := TerrainDef.Type
const W := 128
const H := 64
const VARIANTS := 4
const DECOR_H := 128

var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.seed = 12345
	var ground := Image.create_empty(W * VARIANTS, H * TerrainDb.DEFS.size(), false, Image.FORMAT_RGBA8)
	var decor_rows := 0
	for def in TerrainDb.DEFS:
		decor_rows = maxi(decor_rows, def.decor_row + 1)
	var decor := Image.create_empty(W * VARIANTS, DECOR_H * decor_rows, false, Image.FORMAT_RGBA8)
	for def in TerrainDb.DEFS:
		for v in VARIANTS:
			_draw_ground(ground, Vector2i(v * W, def.type * H), def)
			if def.decor_row >= 0:
				var origin := Vector2i(v * W, def.decor_row * DECOR_H)
				match def.type:
					T.FOREST:
						_draw_trees(decor, origin, def.color)
					T.MOUNTAIN:
						_draw_mountain(decor, origin, def.color)
	_save(ground, "res://assets/tiles/terrain.png")
	_save(decor, "res://assets/tiles/decor.png")
	quit()


func _save(img: Image, path: String) -> void:
	var err := img.save_png(ProjectSettings.globalize_path(path))
	print("%s : %s" % [path, error_string(err)])


## Distance « losange » normalisée du pixel au centre de la tuile (≤ 1 : dedans).
func _diamond_dist(px: int, py: int) -> float:
	return absf(px + 0.5 - W / 2.0) / (W / 2.0) + absf(py + 0.5 - H / 2.0) / (H / 2.0)


func _draw_ground(img: Image, origin: Vector2i, def: TerrainDef) -> void:
	var phase := _rng.randf() * TAU
	for py in H:
		for px in W:
			var d := _diamond_dist(px, py)
			if d > 1.0 + 1.0 / H:  # léger débord pour éviter les joints
				continue
			var cx := px + 0.5 - W / 2.0
			var cy := py + 0.5 - H / 2.0
			var c := def.color
			var noise := _rng.randf_range(-1.0, 1.0)
			match def.type:
				T.SEA, T.LAKE, T.RIVER:
					var wave := sin(cx * 0.18 + cy * 0.5 + phase + sin(cy * 0.4) * 1.5)
					c = c.lightened(0.12) if wave > 0.85 else c.darkened(0.03 * noise)
				T.DESERT:
					var dune := sin(cx * 0.09 + cy * 0.35 + phase)
					c = c.lightened(0.07 * dune).darkened(0.03 * absf(noise))
				T.HILL:
					var bump := 1.0 - pow((cx + 8.0) / 52.0, 2) - pow((cy + 3.0) / 24.0, 2)
					c = c.lightened(0.18 * bump) if bump > 0.0 else c.darkened(-0.12 * bump)
					c = c.darkened(0.04 * absf(noise))
				T.MOUNTAIN:
					c = c.darkened(0.12 * absf(noise))
				_:
					c = c.lightened(0.06 * noise) if absf(noise) > 0.85 else c.darkened(0.03 * absf(noise))
			# Éclairage venant du nord-ouest et bord inférieur assombri.
			c = c.lightened(0.05 * (-cy / (H / 2.0) - cx / W))
			if d > 0.93 and cy > 0 and not def.is_water:
				c = c.darkened(0.15)
			img.set_pixel(origin.x + px, origin.y + py, c)


func _draw_trees(img: Image, origin: Vector2i, base: Color) -> void:
	var trees: Array[Vector2] = []
	for i in _rng.randi_range(6, 8):
		for attempt in 20:
			var p := Vector2(_rng.randf_range(-40, 40), _rng.randf_range(-20, 20))
			if absf(p.x) / 48.0 + absf(p.y) / 24.0 > 0.8:
				continue
			if trees.all(func(o: Vector2) -> bool: return o.distance_to(p) > 11.0):
				trees.append(p)
				break
	trees.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.y < b.y)
	var ground_center := Vector2(W / 2.0, DECOR_H - H / 2.0)
	for p in trees:
		var foot := ground_center + p
		var height := _rng.randf_range(22, 32)
		var width := height * 0.45
		var shade := base.darkened(_rng.randf_range(0.0, 0.2))
		# Tronc.
		_fill_rect(img, origin, Rect2(foot.x - 1.5, foot.y - 6, 3, 6), Color("5a3d22"))
		# Feuillage en deux étages de triangles.
		for layer in 2:
			var top := foot.y - height + layer * height * 0.3
			var bottom := foot.y - 4 - (1 - layer) * height * 0.35
			_fill_triangle(img, origin, Vector2(foot.x, top),
				Vector2(foot.x - width / (2 - layer * 0.5), bottom),
				Vector2(foot.x + width / (2 - layer * 0.5), bottom), shade, 0.12)


func _draw_mountain(img: Image, origin: Vector2i, base: Color) -> void:
	var ground_center := Vector2(W / 2.0, DECOR_H - H / 2.0)
	# Un sommet secondaire en arrière-plan, puis le principal.
	var side := 1.0 if _rng.randf() < 0.5 else -1.0
	var peaks := [
		[ground_center + Vector2(side * 26, -2), _rng.randf_range(44, 56), 30.0],
		[ground_center + Vector2(_rng.randf_range(-6, 6), 8), _rng.randf_range(78, 92), 46.0],
	]
	for peak: Array in peaks:
		var foot: Vector2 = peak[0]
		var height: float = peak[1]
		var half_w: float = peak[2]
		var apex := foot + Vector2(_rng.randf_range(-5, 5), -height)
		var left := foot + Vector2(-half_w, 0)
		var right := foot + Vector2(half_w, 0)
		var mid := foot + Vector2(_rng.randf_range(-4, 4), 0)
		_fill_triangle(img, origin, apex, left, mid, base.lightened(0.12), 0.08)
		_fill_triangle(img, origin, apex, mid, right, base.darkened(0.18), 0.08)
		# Neiges : le haut du sommet.
		var snow := 0.32
		var s_left := apex.lerp(left, snow)
		var s_mid := apex.lerp(mid, snow + 0.08)
		var s_right := apex.lerp(right, snow)
		_fill_triangle(img, origin, apex, s_left, s_mid, Color("f4f6f8"), 0.03)
		_fill_triangle(img, origin, apex, s_mid, s_right, Color("c9d3dd"), 0.03)


func _fill_rect(img: Image, origin: Vector2i, rect: Rect2, color: Color) -> void:
	for y in range(floori(rect.position.y), ceili(rect.end.y)):
		for x in range(floori(rect.position.x), ceili(rect.end.x)):
			img.set_pixel(origin.x + x, origin.y + y, color)


## Triangle plein (avec un léger grain), lissé par sur-échantillonnage 4×.
func _fill_triangle(img: Image, origin: Vector2i, a: Vector2, b: Vector2, c: Vector2,
		color: Color, grain: float) -> void:
	var lo := Vector2(minf(a.x, minf(b.x, c.x)), minf(a.y, minf(b.y, c.y))).floor()
	var hi := Vector2(maxf(a.x, maxf(b.x, c.x)), maxf(a.y, maxf(b.y, c.y))).ceil()
	for y in range(int(lo.y), int(hi.y)):
		for x in range(int(lo.x), int(hi.x)):
			var cover := 0
			for s in 4:
				var p := Vector2(x + 0.25 + 0.5 * (s % 2), y + 0.25 + 0.5 * (s / 2))
				if Geometry2D.point_is_inside_triangle(p, a, b, c):
					cover += 1
			if cover == 0 or x < 0 or y < 0 or x >= W or y >= DECOR_H:
				continue
			var col := color.darkened(_rng.randf() * grain)
			col.a = cover / 4.0
			var dst := Vector2i(origin.x + x, origin.y + y)
			img.set_pixel(dst.x, dst.y, img.get_pixel(dst.x, dst.y).blend(col))
