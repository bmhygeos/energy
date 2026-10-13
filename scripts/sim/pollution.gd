class_name Pollution
extends RefCounted
## Pollution de l'air : chaque bâtiment en service émet selon son activité
## (CO₂ et particules) ; l'émission se répand autour de lui en s'atténuant
## avec la distance, et la pollution de chaque tuile se dissipe peu à peu.
## Pure donnée.

## Part de la pollution d'une tuile qui subsiste après une heure.
const RETENTION := 0.96
## Rayon de dispersion (tuiles) autour de l'emprise.
const RADIUS := 8
## Pollution à partir de laquelle la qualité de l'air est nulle.
const FULL_POLLUTION := 400.0
const EPSILON := 0.01

var registry: BuildingRegistry
var map: WorldMap
## Pollution par tuile (indice sans unité, ≈ émission cumulée).
var level: PackedFloat32Array
## Facteur des technologies (filtres CO₂) appliqué aux centrales à combustible.
var filter_factor := 1.0
## Émissions de la dernière heure (t de CO₂), pour la taxe carbone.
var emitted_last_hour := 0.0


func _init(p_registry: BuildingRegistry) -> void:
	registry = p_registry
	map = registry.map
	level.resize(map.cell_count())


## Émission (t/h) de [param b] pendant la dernière heure de production.
func emission_of(b: Building) -> float:
	if b.status != Building.Status.RUNNING or b.def.emission_per_hour <= 0.0:
		return 0.0
	var factor := filter_factor if b.def.power_source == BuildingDef.PowerSource.FUEL else 1.0
	return b.def.emission_per_hour * b.activity * factor


## Dissipation puis émissions de l'heure ; renvoie les émissions (t).
func step() -> float:
	for i in level.size():
		level[i] = level[i] * RETENTION if level[i] > EPSILON else 0.0
	emitted_last_hour = 0.0
	for b in registry.all():
		var e := emission_of(b)
		if e > 0.0:
			emitted_last_hour += e
			_spread(b, e)
	return emitted_last_hour


## Répand [param amount] autour de l'emprise de [param b] : pleine valeur
## sur l'emprise, décroissance linéaire jusqu'à RADIUS tuiles.
func _spread(b: Building, amount: float) -> void:
	var origin := b.def.footprint_origin(b.anchor)
	for y in range(origin.y - RADIUS, b.anchor.y + RADIUS + 1):
		for x in range(origin.x - RADIUS, b.anchor.x + RADIUS + 1):
			var c := Vector2i(x, y)
			if not map.has_cell(c):
				continue
			var dx := maxi(0, maxi(origin.x - x, x - b.anchor.x))
			var dy := maxi(0, maxi(origin.y - y, y - b.anchor.y))
			var d := sqrt(float(dx * dx + dy * dy))
			if d <= RADIUS:
				level[map.index_of(c)] += amount * (1.0 - d / (RADIUS + 1))


func level_at(cell: Vector2i) -> float:
	return level[map.index_of(cell)] if map.has_cell(cell) else 0.0


## Pollution moyenne sur ces tuiles.
func average(cells: Array[Vector2i]) -> float:
	var total := 0.0
	for c in cells:
		total += level_at(c)
	return total / cells.size() if not cells.is_empty() else 0.0


## Qualité de l'air 0 (irrespirable) – 1 (pur) sur ces tuiles.
func air_quality(cells: Array[Vector2i]) -> float:
	return clampf(1.0 - average(cells) / FULL_POLLUTION, 0.0, 1.0)
