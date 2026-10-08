class_name TerrainTileSet
extends RefCounted
## Construit le TileSet isométrique de la carte à partir des atlas
## assets/tiles/terrain.png (sols) et decor.png (arbres, sommets).

const GROUND_SOURCE := 0
const DECOR_SOURCE := 1
const VARIANTS := 4
const DECOR_SIZE := Vector2i(128, 128)


static func build() -> TileSet:
	var tile_set := TileSet.new()
	tile_set.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	tile_set.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	tile_set.tile_size = Iso.TILE_SIZE

	var ground := TileSetAtlasSource.new()
	ground.texture = preload("res://assets/tiles/terrain.png")
	ground.texture_region_size = Iso.TILE_SIZE
	for def in TerrainDb.DEFS:
		for v in VARIANTS:
			ground.create_tile(Vector2i(v, def.type))
	tile_set.add_source(ground, GROUND_SOURCE)

	var decor := TileSetAtlasSource.new()
	decor.texture = preload("res://assets/tiles/decor.png")
	decor.texture_region_size = DECOR_SIZE
	for def in TerrainDb.DEFS:
		if def.decor_row < 0:
			continue
		for v in VARIANTS:
			var coords := Vector2i(v, def.decor_row)
			decor.create_tile(coords)
			# Le losange de base occupe le bas de l'image : on remonte le dessin
			# pour l'aligner sur la tuile ; le tri en Y se fait au centre de la tuile.
			decor.get_tile_data(coords, 0).texture_origin = Vector2i(0, (DECOR_SIZE.y - Iso.TILE_SIZE.y) / 2)
	tile_set.add_source(decor, DECOR_SOURCE)
	return tile_set
