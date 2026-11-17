class_name PowerGrid
extends TrackNetwork
## Réseau électrique de la ville : lignes en cuivre posées au glisser (tracé en
## L). Une centrale produit pour la ville si elle est à Labor.FREE_DISTANCE
## tuiles du centre ou moins, ou si elle touche une ligne reliée au village.
## Bilan journalier (puissances moyennes) : l'eau et le vent servent jour et
## nuit, le soleil de jour seulement ; les batteries rendent la nuit le surplus
## du jour. Les centrales complètent ensuite : uranium, puis charbon, puis
## fioul (le carburant des raffineries). Le courant remplace le carburant des
## lampes et fait tourner plus vite les ateliers. Pure donnée.

## Cuivre par tuile de ligne.
const COPPER_PER_TILE := 1.0
## Demande de la ville, par habitant : éclairage et petits moteurs.
const WATTS_PER_INHABITANT := 20.0
## Puissance moyenne d'un charbon par jour (290 MJ à 30 % de rendement).
const WATTS_PER_COAL := 1000.0
## Puissance moyenne d'un carburant par jour (420 MJ à 30 % de rendement).
const WATTS_PER_FUEL := 1500.0
## Puissance moyenne d'une unité de combustible nucléaire (uranium enrichi)
## par jour.
const WATTS_PER_NUCLEAR_FUEL := 500000.0
## Usine d'enrichissement : minerais d'uranium par unité de combustible.
const ENRICH_URANIUM := 5.0
## Forges, tissages et raffineries à pleine couverture : +INDUSTRY_BONUS.
const INDUSTRY_BONUS := 0.25
## Débit des rivières par saison (printemps, été, automne, hiver).
const HYDRO_SEASON: PackedFloat32Array = [1.3, 0.7, 1.0, 0.8]
## Éolienne à l'abri (ni crête, ni côte) : part du rendement.
const SHELTERED_WIND := 0.6
## Ensoleillement minimal (hautes latitudes) : part de celui de l'équateur.
const MIN_SUN_LATITUDE := 0.2

## Tuiles de ligne reliées au village.
var linked: Dictionary[Vector2i, bool] = {}
## Centrales, barrages et batteries raccordés.
var connected: Array[Building] = []
## Conditions du jour, posées par GameState avant run_day : vent moyen
## (Weather.wind_at), soleil moyen (Weather.sun_at, nuits comprises), part de
## la journée éclairée, demande des machines (W, centres de calcul, camions
## électriques) et centrales nucléaires à l'arrêt (incident).
var wind := 0.0
var sun := 0.0
var day_share := 0.5
var machine_demand := 0.0
## Chauffage électrique demandé (W, pompes à chaleur de la cité-État).
var heat_demand := 0.0
var nuclear_stopped := false
## Bilan du dernier jour (W) ; coverage : part de la demande servie (0–1).
var demand := 0.0
var supplied := 0.0
## Courant servi par source (W) : eau, vent, soleil (batteries comprises),
## uranium.
var hydro := 0.0
var wind_power := 0.0
var solar := 0.0
var nuclear := 0.0
## Courant rendu la nuit par les batteries (W).
var stored := 0.0
## Combustibles brûlés le dernier jour (carburant, combustible nucléaire).
var fuel_burnt := 0.0
var nuclear_fuel_burnt := 0.0
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


## Facteur de site d'une éolienne : crêtes (collines, montagnes) et côtes à
## plein rendement.
func wind_site(b: Building) -> float:
	for cell in b.cells:
		var t := map.get_terrain(cell)
		if t == TerrainDef.Type.HILL or t == TerrainDef.Type.MOUNTAIN or map.is_coastal(cell):
			return 1.0
	return SHELTERED_WIND


## Ensoleillement selon la latitude de [param b] (1 à l'équateur).
func sun_site(b: Building) -> float:
	return maxf(MIN_SUN_LATITUDE, cos(deg_to_rad(map.latitude(map.wrap_cell(b.anchor).y))))


## Puissance moyenne de [param b] aujourd'hui (W), selon sa source (pour les
## centrales à combustible : à plein régime).
func output_of(b: Building, season: int) -> float:
	match b.def.power_source:
		BuildingDef.PowerSource.HYDRO:
			return b.def.power_watts * HYDRO_SEASON[season]
		BuildingDef.PowerSource.WIND:
			return b.def.power_watts * wind * wind_site(b)
		BuildingDef.PowerSource.SOLAR:
			return b.def.power_watts * sun * sun_site(b)
		BuildingDef.PowerSource.NUCLEAR:
			return 0.0 if nuclear_stopped else b.def.power_watts
	return b.def.power_watts


## Puissance que le réseau peut fournir pendant [param season] (W), aux
## conditions du jour.
func capacity(season: int) -> float:
	var total := 0.0
	for b in connected:
		total += output_of(b, season)
	return total


## Bilan du jour pour [param count] habitants pendant [param season] : eau et
## vent, soleil de jour, batteries, puis uranium, charbon et fioul dans la
## limite des stocks de combustible nucléaire [param nuclear_fuel], de
## [param coal] et de [param fuel] (brûlés : nuclear_fuel_burnt, fuel_burnt) ;
## renvoie le charbon brûlé.
func run_day(count: int, season: int, coal: float, fuel := 0.0, nuclear_fuel := 0.0) -> float:
	demand = count * WATTS_PER_INHABITANT + machine_demand + heat_demand
	var water := 0.0
	var air := 0.0
	var sunlight := 0.0
	var thermal := 0.0
	var oil := 0.0
	var atom := 0.0
	var battery := 0.0
	for b in connected:
		var w := output_of(b, season)
		match b.def.power_source:
			BuildingDef.PowerSource.HYDRO:
				water += w
			BuildingDef.PowerSource.WIND:
				air += w
			BuildingDef.PowerSource.SOLAR:
				sunlight += w
			BuildingDef.PowerSource.COAL:
				thermal += w
			BuildingDef.PowerSource.FUEL:
				oil += w
			BuildingDef.PowerSource.NUCLEAR:
				atom += w
		battery += b.def.storage_kwh * 1000.0 / GameDate.HOURS_PER_DAY
	# Jour et nuit : l'eau et le vent servent les deux, le soleil le jour seul.
	var share := clampf(day_share, 0.0, 1.0)
	var steady := water + air
	var day_need := demand * share
	var night_need := demand - day_need
	var day_served := minf(day_need, steady * share + sunlight)
	var night_served := minf(night_need, steady * (1.0 - share))
	var surplus := steady * share + sunlight - day_served
	stored = minf(minf(surplus, battery), night_need - night_served)
	night_served += stored
	var green := day_served + night_served
	# Parts servies par source, au prorata de la production.
	var produced := steady + sunlight
	hydro = green * water / produced if produced > 0.0 else 0.0
	wind_power = green * air / produced if produced > 0.0 else 0.0
	solar = green - hydro - wind_power
	var left := demand - green
	nuclear = minf(minf(left, atom), nuclear_fuel * WATTS_PER_NUCLEAR_FUEL)
	nuclear_fuel_burnt = nuclear / WATTS_PER_NUCLEAR_FUEL
	left -= nuclear
	var burnt := minf(minf(left, thermal), coal * WATTS_PER_COAL)
	left -= burnt
	var oil_burnt := minf(minf(left, oil), fuel * WATTS_PER_FUEL)
	fuel_burnt = oil_burnt / WATTS_PER_FUEL
	supplied = green + nuclear + burnt + oil_burnt
	coverage = supplied / demand if demand > 0.0 else 0.0
	return burnt / WATTS_PER_COAL


## Facteur des ateliers selon la couverture de la demande.
func industry_factor() -> float:
	return 1.0 + INDUSTRY_BONUS * coverage
