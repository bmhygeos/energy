class_name Territory
extends RefCounted
## Connaissance et possession des tuiles de la planète : état (inconnue,
## explorée, territoire) et gisements prospectés. Stocké sous forme compacte,
## un octet par tuile des seuls blocs connus. Pure donnée.

enum State { UNKNOWN, EXPLORED, TERRITORY }

const STATE_NAMES: PackedStringArray = ["Inconnue", "Explorée", "Territoire"]
## Bits d'un octet : état (2 bits) et gisement prospecté.
const STATE_MASK := 3
const PROSPECTED_BIT := 4

var map: WorldMap
var _blocks: Dictionary[Vector2i, PackedByteArray] = {}


func _init(p_map: WorldMap) -> void:
	map = p_map


func state_at(cell: Vector2i) -> State:
	if not map.has_cell(cell):
		return State.UNKNOWN
	return (_byte(cell) & STATE_MASK) as State


## Tuile visible (explorée ou territoire) ?
func is_known(cell: Vector2i) -> bool:
	return state_at(cell) != State.UNKNOWN


func is_territory(cell: Vector2i) -> bool:
	return state_at(cell) == State.TERRITORY


func set_state(cell: Vector2i, state: State) -> void:
	_set_byte(cell, (_byte(cell) & ~STATE_MASK) | state)


## Explore [param cells] (sans retirer une tuile du territoire).
func explore(cells: Array[Vector2i]) -> void:
	for cell in cells:
		if map.has_cell(cell) and state_at(cell) == State.UNKNOWN:
			set_state(cell, State.EXPLORED)


## Intègre [param cells] au territoire.
func annex(cells: Array[Vector2i]) -> void:
	for cell in cells:
		if map.has_cell(cell):
			set_state(cell, State.TERRITORY)


## Prospection : rend visibles les gisements de [param cells] connues.
func prospect(cells: Array[Vector2i]) -> void:
	for cell in cells:
		if is_known(cell):
			_set_byte(cell, _byte(cell) | PROSPECTED_BIT)


func is_prospected(cell: Vector2i) -> bool:
	return map.has_cell(cell) and _byte(cell) & PROSPECTED_BIT != 0


## Gisement connu du joueur (NONE tant que la tuile n'est pas prospectée).
func known_deposit(cell: Vector2i) -> int:
	return map.get_deposit(cell) if is_prospected(cell) else WorldMap.Deposit.NONE


## Tuiles connues (abscisses ramenées sur la planète).
func known_cells() -> Array[Vector2i]:
	return _cells_where(func(b: int) -> bool: return b & STATE_MASK != State.UNKNOWN)


func territory_cells() -> Array[Vector2i]:
	return _cells_where(func(b: int) -> bool: return b & STATE_MASK == State.TERRITORY)


func count(state: State) -> int:
	return _cells_where(func(b: int) -> bool: return b & STATE_MASK == state).size()


func _cells_where(test: Callable) -> Array[Vector2i]:
	var n := WorldMap.CHUNK_SIZE
	var result: Array[Vector2i] = []
	for key: Vector2i in _blocks:
		var bytes := _blocks[key]
		for i in bytes.size():
			if test.call(bytes[i]):
				result.append(key * n + Vector2i(i % n, i / n))
	return result


func _byte(cell: Vector2i) -> int:
	var bytes: PackedByteArray = _blocks.get(map.chunk_of(cell), PackedByteArray())
	return bytes[_local(cell)] if not bytes.is_empty() else 0


func _set_byte(cell: Vector2i, value: int) -> void:
	var key := map.chunk_of(cell)
	if not _blocks.has(key):
		var bytes := PackedByteArray()
		bytes.resize(WorldMap.CHUNK_SIZE * WorldMap.CHUNK_SIZE)
		_blocks[key] = bytes
	# Les tableaux compacts sont copiés à l'accès : réaffecter après l'écriture.
	var bytes := _blocks[key]
	bytes[_local(cell)] = value
	_blocks[key] = bytes


func _local(cell: Vector2i) -> int:
	var c := map.wrap_cell(cell)
	var n := WorldMap.CHUNK_SIZE
	return (c.y % n) * n + c.x % n
