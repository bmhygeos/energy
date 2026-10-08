class_name WorldMap
extends RefCounted
## Données de la carte : terrain et attributs par tuile, stockés à plat
## (index = y * largeur + x). Pure donnée, sans nœud.

enum Deposit { NONE, COAL, URANIUM, LITHIUM }

const DEPOSIT_NAMES: PackedStringArray = ["Aucun", "Charbon", "Uranium", "Lithium"]
const NEIGHBORS_4: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
]
const NEIGHBORS_8: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
]

var size: Vector2i
var seed_value: int
## TerrainDef.Type par tuile.
var terrain: PackedByteArray
## Variante visuelle (0–3), purement cosmétique.
var variant: PackedByteArray
## Altitude normalisée 0–1.
var elevation: PackedFloat32Array
## Potentiel éolien 0–1.
var wind: PackedFloat32Array
## Ensoleillement 0–1.
var sun: PackedFloat32Array
## 1 si la tuile (terrestre) touche de l'eau (rivière, lac, mer).
var water_access: PackedByteArray
## 1 si la tuile (terrestre) touche la mer.
var coastal: PackedByteArray
## Deposit par tuile, et quantité restante (tonnes).
var deposit: PackedByteArray
var deposit_amount: PackedInt32Array


func _init(p_size: Vector2i, p_seed: int = 0) -> void:
	size = p_size
	seed_value = p_seed
	var n := size.x * size.y
	terrain.resize(n)
	variant.resize(n)
	elevation.resize(n)
	wind.resize(n)
	sun.resize(n)
	water_access.resize(n)
	coastal.resize(n)
	deposit.resize(n)
	deposit_amount.resize(n)


func cell_count() -> int:
	return size.x * size.y


func has_cell(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < size.x and cell.y < size.y


func index_of(cell: Vector2i) -> int:
	return cell.y * size.x + cell.x


func cell_of(index: int) -> Vector2i:
	return Vector2i(index % size.x, index / size.x)


func get_terrain(cell: Vector2i) -> int:
	return terrain[index_of(cell)]


func is_water(cell: Vector2i) -> bool:
	return TerrainDb.is_water(terrain[index_of(cell)])


## Voisins de [param cell] dans la carte, selon [param offsets].
func neighbors(cell: Vector2i, offsets: Array[Vector2i] = NEIGHBORS_4) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for o in offsets:
		if has_cell(cell + o):
			result.append(cell + o)
	return result
