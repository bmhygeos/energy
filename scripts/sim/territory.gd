class_name Territory
extends RefCounted
## Connaissance et possession des tuiles de la planète : état (inconnue,
## explorée, territoire) et gisements prospectés. Stocké sous forme compacte,
## un octet par tuile des seuls blocs connus. Plusieurs villes : chaque tuile
## du territoire appartient à une ville (owner) ; les questions « territoire »
## portent sur la ville active (owner), la connaissance est commune. Pure
## donnée.

enum State { UNKNOWN, EXPLORED, TERRITORY }

const STATE_NAMES: PackedStringArray = ["Inconnue", "Explorée", "Territoire"]
## Bits d'un octet : état (2 bits) et gisement prospecté.
const STATE_MASK := 3
const PROSPECTED_BIT := 4
## Palier à partir duquel chaque gisement (WorldMap.Deposit) se prospecte :
## fer au village, charbon au bourg, pétrole et cuivre à la ville, uranium et
## lithium à la cité-État.
const DEPOSIT_TIER: PackedInt32Array = [0, 3, 2, 4, 4, 5, 5, 2]

var map: WorldMap
## Palier de la ville : seuls les gisements de ce palier ou d'avant sont vus.
var tier := 1
var _blocks: Dictionary[Vector2i, PackedByteArray] = {}
## Ville active (identifiant) : celle dont on demande le territoire et qui
## annexe.
var owner := 0
## Ville propriétaire des tuiles du territoire (absente : la ville 0).
var _owners: Dictionary[Vector2i, int] = {}


func _init(p_map: WorldMap) -> void:
	map = p_map


func state_at(cell: Vector2i) -> State:
	if not map.has_cell(cell):
		return State.UNKNOWN
	return (_byte(cell) & STATE_MASK) as State


## Tuile visible (explorée ou territoire) ?
func is_known(cell: Vector2i) -> bool:
	return state_at(cell) != State.UNKNOWN


## Tuile du territoire de la ville active ?
func is_territory(cell: Vector2i) -> bool:
	return state_at(cell) == State.TERRITORY and owner_at(cell) == owner


## Tuile du territoire d'une ville, quelle qu'elle soit ?
func is_owned(cell: Vector2i) -> bool:
	return state_at(cell) == State.TERRITORY


## Ville propriétaire de [param cell] (-1 : hors de tout territoire).
func owner_at(cell: Vector2i) -> int:
	if state_at(cell) != State.TERRITORY:
		return -1
	return _owners.get(map.wrap_cell(cell), 0)


func set_state(cell: Vector2i, state: State) -> void:
	_set_byte(cell, (_byte(cell) & ~STATE_MASK) | state)


## Explore [param cells] (sans retirer une tuile du territoire).
func explore(cells: Array[Vector2i]) -> void:
	for cell in cells:
		if map.has_cell(cell) and state_at(cell) == State.UNKNOWN:
			set_state(cell, State.EXPLORED)


## Intègre [param cells] au territoire de la ville active (sans prendre les
## tuiles d'une autre ville).
func annex(cells: Array[Vector2i]) -> void:
	for cell in cells:
		if map.has_cell(cell) and owner_at(cell) < 0:
			set_state(cell, State.TERRITORY)
			_set_owner(cell, owner)


## Donne [param cells] à la ville [param city] (fondation d'une ville), même
## si elles appartenaient à une autre.
func transfer(cells: Array[Vector2i], city: int) -> void:
	for cell in cells:
		if map.has_cell(cell):
			set_state(cell, State.TERRITORY)
			_set_owner(cell, city)


func _set_owner(cell: Vector2i, city: int) -> void:
	if city == 0:
		_owners.erase(map.wrap_cell(cell))
	else:
		_owners[map.wrap_cell(cell)] = city


## Prospection : rend visibles les gisements de [param cells] connues.
func prospect(cells: Array[Vector2i]) -> void:
	for cell in cells:
		if is_known(cell):
			_set_byte(cell, _byte(cell) | PROSPECTED_BIT)


func is_prospected(cell: Vector2i) -> bool:
	return map.has_cell(cell) and _byte(cell) & PROSPECTED_BIT != 0


## Gisement connu du joueur : tuile prospectée et gisement de son palier
## (NONE sinon).
func known_deposit(cell: Vector2i) -> int:
	if not is_prospected(cell):
		return WorldMap.Deposit.NONE
	var kind := map.get_deposit(cell)
	return kind if DEPOSIT_TIER[kind] <= tier else WorldMap.Deposit.NONE


## Tuiles connues (abscisses ramenées sur la planète).
func known_cells() -> Array[Vector2i]:
	return _cells_where(-1)


func territory_cells() -> Array[Vector2i]:
	return _cells_where(State.TERRITORY).filter(func(c: Vector2i) -> bool: return _owners.get(c, 0) == owner)


func count(state: State) -> int:
	if state == State.UNKNOWN:
		return map.size.x * map.size.y - _cells_where(-1).size()
	if state == State.TERRITORY:
		return territory_cells().size()
	var total := 0
	for key: Vector2i in _blocks:
		for b in _blocks[key]:
			if b & STATE_MASK == state:
				total += 1
	return total


## Blocs (WorldMap.CHUNK_SIZE tuiles de côté) où une tuile au moins est connue.
func known_blocks() -> Array[Vector2i]:
	return _blocks.keys()


## Tuiles dans l'état [param state] (-1 : toutes les connues).
func _cells_where(state: int) -> Array[Vector2i]:
	var n := WorldMap.CHUNK_SIZE
	var result: Array[Vector2i] = []
	for key: Vector2i in _blocks:
		var bytes := _blocks[key]
		var origin := key * n
		for i in bytes.size():
			var s := bytes[i] & STATE_MASK
			if s != State.UNKNOWN and (state < 0 or s == state):
				result.append(origin + Vector2i(i % n, i / n))
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
