class_name WorldMap
extends RefCounted
## Données de la planète : grille longitude / latitude (équirectangulaire) qui
## boucle d'est en ouest, les pôles étant les bords nord (y = 0) et sud. Les
## tuiles sont générées à la demande par blocs de CHUNK_SIZE × CHUNK_SIZE
## (MapGenerator), gardés en mémoire une fois créés. Pure donnée, sans nœud.
##
## Toutes les fonctions acceptent une abscisse hors de [0, largeur) : elle est
## ramenée sur la planète (wrap), ce qui permet à la vue d'utiliser des
## coordonnées « dépliées » autour du village.

enum Deposit { NONE, COAL, IRON, OIL, COPPER, URANIUM, LITHIUM }

const DEPOSIT_NAMES: PackedStringArray = ["Aucun", "Charbon", "Fer", "Pétrole", "Cuivre", "Uranium", "Lithium"]
const CHUNK_SIZE := 32
## Bois sur pied d'une forêt de densité maximale (unités de 10 kg).
const WOOD_PER_FOREST := 400.0
const NEIGHBORS_4: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
]
const NEIGHBORS_8: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
]


## Un bloc de tuiles, stockées à plat (index = y * CHUNK_SIZE + x).
class Chunk:
	## TerrainDef.Type par tuile.
	var terrain := PackedByteArray()
	## Variante visuelle (0–3), purement cosmétique.
	var variant := PackedByteArray()
	## Altitude 0–1 (mer : sous MapGenerator.sea_level).
	var elevation := PackedFloat32Array()
	## Température 0 (pôle) – 1 (équateur), altitude comprise.
	var temperature := PackedFloat32Array()
	## Potentiel éolien et ensoleillement 0–1.
	var wind := PackedFloat32Array()
	var sun := PackedFloat32Array()
	## Fertilité (agriculture) et pâturage (élevage) 0–1.
	var fertility := PackedFloat32Array()
	var pasture := PackedFloat32Array()
	## Bois sur pied (unités de 10 kg) ; la forêt disparaît à 0.
	var wood := PackedFloat32Array()
	## 1 si la tuile (terrestre) touche de l'eau (rivière, lac, mer) / la mer.
	var water_access := PackedByteArray()
	var coastal := PackedByteArray()
	## Deposit par tuile, et quantité (tonnes). Cachés au joueur tant que la
	## tuile n'est pas prospectée (Territory).
	var deposit := PackedByteArray()
	var deposit_amount := PackedFloat32Array()

	func _init() -> void:
		var n := CHUNK_SIZE * CHUNK_SIZE
		terrain.resize(n)
		variant.resize(n)
		water_access.resize(n)
		coastal.resize(n)
		deposit.resize(n)
		elevation.resize(n)
		temperature.resize(n)
		wind.resize(n)
		sun.resize(n)
		fertility.resize(n)
		pasture.resize(n)
		wood.resize(n)
		deposit_amount.resize(n)


var size: Vector2i
var seed_value: int
var generator: MapGenerator
var _chunks: Dictionary[Vector2i, Chunk] = {}


func _init(p_size: Vector2i, p_seed: int = 0, p_generator: MapGenerator = null) -> void:
	assert(p_size.x % CHUNK_SIZE == 0 and p_size.y % CHUNK_SIZE == 0, "taille multiple des blocs")
	size = p_size
	seed_value = p_seed
	generator = p_generator if p_generator else MapGenerator.new(p_seed, p_size)


## La tuile existe-t-elle (latitude dans la carte) ? La longitude boucle.
func has_cell(cell: Vector2i) -> bool:
	return cell.y >= 0 and cell.y < size.y


## Tuile ramenée sur la planète (0 ≤ x < largeur).
func wrap_cell(cell: Vector2i) -> Vector2i:
	return Vector2i(posmod(cell.x, size.x), cell.y)


## Copie de [param cell] la plus proche de l'abscisse [param ref_x]
## (ref_x − largeur/2 ≤ x < ref_x + largeur/2).
func unwrap_near(cell: Vector2i, ref_x: int) -> Vector2i:
	var half := size.x / 2
	return Vector2i(ref_x - half + posmod(cell.x - ref_x + half, size.x), cell.y)


## Latitude (degrés, positive au nord) et longitude (degrés, −180 à 180) du
## centre de la tuile.
func latitude(y: int) -> float:
	return 90.0 - (y + 0.5) * 180.0 / size.y


func longitude(x: int) -> float:
	return (posmod(x, size.x) + 0.5) * 360.0 / size.x - 180.0


## Bloc contenant [param cell] (après wrap).
func chunk_of(cell: Vector2i) -> Vector2i:
	var c := wrap_cell(cell)
	return Vector2i(c.x / CHUNK_SIZE, c.y / CHUNK_SIZE)


func is_generated(chunk: Vector2i) -> bool:
	return _chunks.has(chunk)


func generated_count() -> int:
	return _chunks.size()


## Voisins de [param cell] dans la carte, selon [param offsets] (abscisses
## non ramenées : voisins dans le même repère que [param cell]).
func neighbors(cell: Vector2i, offsets: Array[Vector2i] = NEIGHBORS_4) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for o in offsets:
		if has_cell(cell + o):
			result.append(cell + o)
	return result


func get_terrain(cell: Vector2i) -> int:
	return _chunk(cell).terrain[_local(cell)]


func is_water(cell: Vector2i) -> bool:
	return TerrainDb.is_water(get_terrain(cell))


func get_variant(cell: Vector2i) -> int:
	return _chunk(cell).variant[_local(cell)]


func get_elevation(cell: Vector2i) -> float:
	return _chunk(cell).elevation[_local(cell)]


func get_temperature(cell: Vector2i) -> float:
	return _chunk(cell).temperature[_local(cell)]


func get_wind(cell: Vector2i) -> float:
	return _chunk(cell).wind[_local(cell)]


func get_sun(cell: Vector2i) -> float:
	return _chunk(cell).sun[_local(cell)]


func get_fertility(cell: Vector2i) -> float:
	return _chunk(cell).fertility[_local(cell)]


func set_fertility(cell: Vector2i, value: float) -> void:
	_chunk(cell).fertility[_local(cell)] = clampf(value, 0.0, 1.0)


func get_pasture(cell: Vector2i) -> float:
	return _chunk(cell).pasture[_local(cell)]


func get_wood(cell: Vector2i) -> float:
	return _chunk(cell).wood[_local(cell)]


func set_wood(cell: Vector2i, tonnes: float) -> void:
	_chunk(cell).wood[_local(cell)] = tonnes


func has_water_access(cell: Vector2i) -> bool:
	return _chunk(cell).water_access[_local(cell)] != 0


func is_coastal(cell: Vector2i) -> bool:
	return _chunk(cell).coastal[_local(cell)] != 0


## Gisement réel de la tuile (le joueur ne voit que les gisements prospectés :
## Territory.known_deposit).
func get_deposit(cell: Vector2i) -> int:
	return _chunk(cell).deposit[_local(cell)]


func get_deposit_amount(cell: Vector2i) -> float:
	return _chunk(cell).deposit_amount[_local(cell)]


## Place un gisement [param kind] de [param amount] tonnes sur [param cell].
func set_deposit(cell: Vector2i, kind: int, amount: float) -> void:
	var chunk := _chunk(cell)
	chunk.deposit[_local(cell)] = kind
	chunk.deposit_amount[_local(cell)] = amount


## Quantité restante du gisement de [param cell] (épuisé à 0 : plus de gisement).
func set_deposit_amount(cell: Vector2i, amount: float) -> void:
	var chunk := _chunk(cell)
	chunk.deposit_amount[_local(cell)] = maxf(0.0, amount)
	if amount <= 0.0:
		chunk.deposit[_local(cell)] = Deposit.NONE


## Change le terrain de [param cell] (défrichement…) et met à jour l'accès à
## l'eau de la tuile et de ses voisines.
func set_terrain(cell: Vector2i, type: int) -> void:
	_chunk(cell).terrain[_local(cell)] = type
	var around := neighbors(cell, NEIGHBORS_8)
	around.append(cell)
	for c in around:
		_update_water_access(c)


func _update_water_access(cell: Vector2i) -> void:
	var access := 0
	var coast := 0
	if not is_water(cell):
		for n in neighbors(cell, NEIGHBORS_8):
			var t := get_terrain(n)
			if TerrainDb.is_water(t):
				access = 1
			if t == TerrainDef.Type.SEA:
				coast = 1
	var chunk := _chunk(cell)
	chunk.water_access[_local(cell)] = access
	chunk.coastal[_local(cell)] = coast


## Bloc de [param cell], généré au premier accès.
func _chunk(cell: Vector2i) -> Chunk:
	var key := chunk_of(cell)
	var chunk: Chunk = _chunks.get(key)
	if chunk == null:
		chunk = generator.generate_chunk(key)
		_chunks[key] = chunk
	return chunk


func _local(cell: Vector2i) -> int:
	var c := wrap_cell(cell)
	return (c.y % CHUNK_SIZE) * CHUNK_SIZE + c.x % CHUNK_SIZE
