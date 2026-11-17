class_name RoadNetwork
extends TrackNetwork
## Routes du bourg : tuiles posées au glisser (tracé en L). Une route reliée au
## village (une de ses tuiles à Labor.FREE_DISTANCE tuiles du centre ou moins)
## rapproche les tuiles à REACH tuiles ou moins d'elle : leur distance se
## compte depuis la route, plus sa longueur (TILES_PER_WALK_TILE tuiles de
## route valent une tuile de marche). Sans combustible : charrettes et
## piétons. Un dépôt de camions touchant une route reliée porte la route plus
## loin : TRUCK_FREE_TILES tuiles sans pénalité, puis TRUCK_TILES_PER_WALK_TILE
## tuiles de route par tuile de marche, contre du carburant. Les camions
## d'un dépôt ne transportent que la production de TRUCKS_PER_DEPOT ×
## PORTERS_PER_TRUCK travailleurs : ils desservent d'abord les tuiles zonées
## qu'ils rapprochent le plus ; les autres gardent la portée des charrettes.
## Une route peut
## croiser une voie ferrée (passage à niveau) ; comme les canaux, elle passe
## sur les zones, les autres réseaux et sous les bâtiments du monde. Pure
## donnée.

## Pavés par tuile.
const STONE_PER_TILE := 2.0
## Tuiles de route qui valent une tuile de marche.
const TILES_PER_WALK_TILE := 2
## Tuiles desservies de part et d'autre de la route.
const REACH := 2
## Camions : tuiles de route sans pénalité, tuiles de route qui valent une tuile
## de marche ensuite (−0,5 % par tuile), et tuiles desservies de part et d'autre.
const TRUCK_FREE_TILES := 30
const TRUCK_TILES_PER_WALK_TILE := 6
const TRUCK_REACH := 3
## Carburant brûlé par jour : par dépôt, et par tuile de route reliée.
const FUEL_PER_DEPOT_PER_DAY := 2.0
const FUEL_PER_TILE_PER_DAY := 0.05
## Camions par dépôt, et travailleurs (porteurs) dont chacun transporte la
## production.
## Véhicules électriques (cité-État, batteries au lithium) : plus de
## carburant, mais du courant, EV_EFFICIENCY fois l'énergie utile du carburant
## qu'ils auraient brûlé.
const EV_EFFICIENCY := 0.3
const TRUCKS_PER_DEPOT := 5
const PORTERS_PER_TRUCK := 20

## Tuiles de route reliées au village → longueur depuis le village.
var lengths: Dictionary[Vector2i, int] = {}
## Dépôts terminés (posés par GameState avant refresh).
var depots: Array[Building] = []
## Les camions roulent (assez de carburant ou de courant la veille).
var running := true
## Véhicules électriques (recherche) : les camions des dépôts rechargés
## roulent au courant, un dépôt par borne de recharge reliée.
var electric := false
## Bornes de recharge terminées (posées par GameState avant refresh), et
## celles qui touchent une route reliée.
var chargers: Array[Building] = []
var served_chargers: Array[Building] = []
## Dépôts qui touchent une route reliée.
var served_depots: Array[Building] = []
## Tuiles desservies → distance au village par la route, en charrette et en
## camion ; tuiles zonées desservies par les camions et leurs travailleurs.
var _reach: Dictionary[Vector2i, int] = {}
var _truck_reach: Dictionary[Vector2i, int] = {}
var trucked: Dictionary[Vector2i, bool] = {}
var truck_load := 0


func track_name() -> String:
	return "route"


## Motif qui empêche une route sur [param cell] : seulement le terrain (eau,
## montagne, glace) et les limites du territoire ; zones, réseaux et
## bâtiments l'acceptent.
func check_cell(cell: Vector2i) -> String:
	if not map.has_cell(cell) or not territory.is_territory(cell):
		return "Hors du territoire"
	var t := map.get_terrain(cell)
	if t in FORBIDDEN:
		return "Pas de route sur : %s" % TerrainDb.get_def(t).display_name.to_lower()
	return ""


func base_costs() -> PackedFloat32Array:
	var values := Stockpile.zeros()
	values[Stockpile.Good.STONE] = STONE_PER_TILE
	return values


## Recalcule les tuiles reliées au village et celles qu'elles desservent.
func refresh() -> void:
	lengths.clear()
	_reach.clear()
	var queue: Array[Vector2i] = []
	for cell: Vector2i in _tiles:
		if cheb(cell, center) <= Labor.FREE_DISTANCE:
			lengths[cell] = 1
			queue.append(cell)
	var head := 0
	while head < queue.size():
		var cell := queue[head]
		head += 1
		for o in WorldMap.NEIGHBORS_4:
			var n := map.wrap_cell(cell + o)
			if _tiles.has(n) and not lengths.has(n):
				lengths[n] = lengths[cell] + 1
				queue.append(n)
	served_depots = depots.filter(_touches_road)
	served_chargers = chargers.filter(_touches_road)
	_reach = _reach_map(false)
	_truck_reach.clear()
	if has_trucks():
		_truck_reach = _reach_map(true)
	_load_trucks()


## Distance au village par la route des tuiles desservies (en camion :
## [param trucks]).
func _reach_map(trucks: bool) -> Dictionary[Vector2i, int]:
	var result: Dictionary[Vector2i, int] = {}
	var reach := TRUCK_REACH if trucks else REACH
	for cell: Vector2i in lengths:
		var base := _walk_tiles(lengths[cell], trucks)
		for dy in range(-reach, reach + 1):
			for dx in range(-reach, reach + 1):
				var n := map.wrap_cell(cell + Vector2i(dx, dy))
				var d := base + maxi(absi(dx), absi(dy))
				if not result.has(n) or d < result[n]:
					result[n] = d
	return result


## Répartit les camions entre les tuiles zonées qu'ils rapprochent, celles qui
## y gagnent le plus d'abord, dans la limite de capacity() travailleurs.
func _load_trucks() -> void:
	trucked.clear()
	truck_load = 0
	if _truck_reach.is_empty() or zones == null:
		return
	var gains: Dictionary[Vector2i, int] = {}
	for cell: Vector2i in _truck_reach:
		if zones.zone_at(cell) == null:
			continue
		var other := mini(cheb(cell, center), _reach.get(cell, cheb(cell, center)))
		var gain := maxi(0, other - Labor.FREE_DISTANCE) - maxi(0, _truck_reach[cell] - Labor.FREE_DISTANCE)
		if gain > 0:
			gains[cell] = gain
	var cells := gains.keys()
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return gains[a] > gains[b] or gains[a] == gains[b] and (a.y < b.y or a.y == b.y and a.x < b.x))
	var room := capacity()
	for cell: Vector2i in cells:
		var workers := zones.zone_at(cell).workers_per_tile
		if workers > room:
			continue
		trucked[cell] = true
		truck_load += workers
		room -= workers


## Travailleurs dont les camions transportent la production.
func capacity() -> int:
	return served_depots.size() * TRUCKS_PER_DEPOT * PORTERS_PER_TRUCK if has_trucks() else 0


## Des camions roulent sur les routes reliées.
func has_trucks() -> bool:
	return running and not served_depots.is_empty()


## Carburant brûlé par jour par les camions (0 : aucun dépôt desservi).
func fuel_need() -> float:
	if served_depots.is_empty():
		return 0.0
	return _energy_need() * (1.0 - electric_share())


## Dépôts dont les camions roulent au courant (véhicules électriques et
## bornes de recharge reliées).
func electric_depots() -> int:
	return mini(served_chargers.size(), served_depots.size()) if electric else 0


## Part des camions électriques.
func electric_share() -> float:
	return float(electric_depots()) / served_depots.size() if not served_depots.is_empty() else 0.0


## Carburant qu'il faudrait aux camions (moteurs à explosion).
func _energy_need() -> float:
	return FUEL_PER_DEPOT_PER_DAY * served_depots.size() + FUEL_PER_TILE_PER_DAY * lengths.size()


## Courant demandé par les véhicules électriques (W ; 0 sans eux).
func electric_watts() -> float:
	if served_depots.is_empty():
		return 0.0
	return _energy_need() * electric_share() * PowerGrid.WATTS_PER_FUEL * EV_EFFICIENCY


## Tuiles de marche équivalentes à [param length] tuiles de route (en camion :
## [param trucks]).
func _walk_tiles(length: int, trucks: bool) -> int:
	if trucks:
		return ceili(float(maxi(0, length - TRUCK_FREE_TILES)) / TRUCK_TILES_PER_WALK_TILE)
	return ceili(float(length) / TILES_PER_WALK_TILE)


func _touches_road(b: Building) -> bool:
	for cell in b.cells:
		for o in WorldMap.NEIGHBORS_4:
			if lengths.has(map.wrap_cell(cell + o)):
				return true
	return false


## Distance de [param cell] au village par la route (-1 : non desservie) ;
## en camion si les camions la desservent.
func distance_via(cell: Vector2i) -> int:
	var w := map.wrap_cell(cell)
	if trucked.has(w):
		return _truck_reach[w]
	return _reach.get(w, -1)
