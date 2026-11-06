class_name PowerGrid
extends TrackNetwork
## Réseau électrique de la ville : lignes en cuivre posées au glisser (tracé en
## L). Une centrale produit pour la ville si elle est à Labor.FREE_DISTANCE
## tuiles du centre ou moins, ou si elle touche une ligne reliée au village.
## Les barrages passent d'abord (sans combustible, selon la saison), puis les
## centrales complètent en brûlant du charbon. Le courant remplace le carburant
## des lampes et fait tourner plus vite les ateliers. Pure donnée.

## Cuivre par tuile de ligne.
const COPPER_PER_TILE := 1.0
## Demande de la ville, par habitant : éclairage et petits moteurs.
const WATTS_PER_INHABITANT := 20.0
## Puissance moyenne d'un charbon par jour (290 MJ à 30 % de rendement).
const WATTS_PER_COAL := 1000.0
## Forges, tissages et raffineries à pleine couverture : +INDUSTRY_BONUS.
const INDUSTRY_BONUS := 0.25
## Débit des rivières par saison (printemps, été, automne, hiver).
const HYDRO_SEASON: PackedFloat32Array = [1.3, 0.7, 1.0, 0.8]

## Tuiles de ligne reliées au village.
var linked: Dictionary[Vector2i, bool] = {}
## Centrales et barrages raccordés.
var connected: Array[Building] = []
## Bilan du dernier jour (W) ; coverage : part de la demande servie (0–1).
var demand := 0.0
var supplied := 0.0
var hydro := 0.0
var coverage := 0.0


func track_name() -> String:
	return "ligne"


func base_costs() -> PackedFloat32Array:
	var values := Stockpile.zeros()
	values[Stockpile.Good.COPPER] = COPPER_PER_TILE
	return values


## Recalcule les lignes reliées au village et les [param plants] (terminées)
## raccordées.
func refresh(plants: Array[Building]) -> void:
	linked.clear()
	var queue: Array[Vector2i] = []
	for cell: Vector2i in _tiles:
		if cheb(cell, center) <= Labor.FREE_DISTANCE:
			linked[cell] = true
			queue.append(cell)
	var head := 0
	while head < queue.size():
		var cell := queue[head]
		head += 1
		for o in WorldMap.NEIGHBORS_4:
			var n := map.wrap_cell(cell + o)
			if _tiles.has(n) and not linked.has(n):
				linked[n] = true
				queue.append(n)
	connected = plants.filter(feeds_city)


## [param b] alimente-t-il la ville ?
func feeds_city(b: Building) -> bool:
	if cheb(b.anchor, center) <= Labor.FREE_DISTANCE:
		return true
	for cell in b.cells:
		for o in WorldMap.NEIGHBORS_4:
			if linked.has(map.wrap_cell(cell + o)):
				return true
	return false


## Puissance que le réseau peut fournir pendant [param season] (W).
func capacity(season: int) -> float:
	var total := 0.0
	for b in connected:
		total += b.def.power_watts * (1.0 if b.def.burns_coal else HYDRO_SEASON[season])
	return total


## Bilan du jour pour [param count] habitants : barrages d'abord, puis
## centrales dans la limite de [param coal] ; renvoie le charbon brûlé.
func run_day(count: int, season: int, coal: float) -> float:
	demand = count * WATTS_PER_INHABITANT
	var water := 0.0
	var thermal := 0.0
	for b in connected:
		if b.def.burns_coal:
			thermal += b.def.power_watts
		else:
			water += b.def.power_watts * HYDRO_SEASON[season]
	hydro = minf(water, demand)
	var burnt := minf(minf(demand - hydro, thermal), coal * WATTS_PER_COAL)
	supplied = hydro + burnt
	coverage = supplied / demand if demand > 0.0 else 0.0
	return burnt / WATTS_PER_COAL


## Facteur des ateliers selon la couverture de la demande.
func industry_factor() -> float:
	return 1.0 + INDUSTRY_BONUS * coverage
