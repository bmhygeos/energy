class_name ZoneLayer
extends Node2D
## Calque des zones peintes : couleur de la zone en surimpression (les champs
## changent d'aspect selon la saison : labour, blé vert, blé mûr, chaume),
## liseré intérieur et petites silhouettes des travailleurs, sous les décors
## (arbres) et les bâtiments.

const FILL_ALPHA := 0.35
const BORDER_ALPHA := 0.9
## Réduction du liseré par rapport au losange de la tuile.
const INSET := 0.82
const WORKER_COLOR := Color(0.15, 0.12, 0.1, 0.9)
const WORKER_HEAD := Color(0.95, 0.85, 0.7, 1)
## Aspect des champs : labour (printemps), blé vert puis mûr (été, automne),
## chaume (hiver).
const PLOUGHED := Color("7a5a3a")
const GREEN_WHEAT := Color("6fae3a")
const RIPE_WHEAT := Color("e0be4a")
const STUBBLE := Color("c8b890")


func _ready() -> void:
	EventBus.game_started.connect(func(_s: int) -> void: queue_redraw())
	EventBus.zones_changed.connect(func(_c: Array[Vector2i]) -> void: queue_redraw())
	EventBus.labor_changed.connect(queue_redraw)
	EventBus.day_changed.connect(func(_d: int) -> void: queue_redraw())


func _draw() -> void:
	var zones := GameState.zones
	if zones == null:
		return
	for c in zones.all_cells():
		var cell := GameState.display_cell(c)
		var def := zones.zone_at(cell)
		var d := Iso.diamond(cell)
		var field := def.quality == ZoneDef.Quality.FERTILITY
		if field:
			draw_colored_polygon(d, _field_color(GameClock.tick) * Color(1, 1, 1, 0.75))
		else:
			draw_colored_polygon(d, def.color * Color(1, 1, 1, FILL_ALPHA))
		var center := (d[0] + d[2]) / 2.0
		var inner := PackedVector2Array()
		for p in d:
			inner.append(center + (p - center) * INSET)
		inner.append(inner[0])
		draw_polyline(inner, def.color * Color(1, 1, 1, BORDER_ALPHA), 2.0, true)
		var workers: int = GameState.labor.workers_at.get(c, 0)
		for k in workers:
			_draw_worker(center + Vector2((k - (workers - 1) / 2.0) * 14.0, 4.0))


## Couleur des champs au tick [param tick] : labour au printemps, blé qui
## mûrit en été, récolté en automne, chaume en hiver.
static func _field_color(tick: int) -> Color:
	var t := float(GameDate.day_of_season(tick) - 1) / GameDate.DAYS_PER_SEASON
	match GameDate.season(tick):
		0:
			return PLOUGHED.lerp(GREEN_WHEAT, maxf(0.0, t - 0.5) * 2.0)
		1:
			return GREEN_WHEAT.lerp(RIPE_WHEAT, t)
		2:
			return RIPE_WHEAT.lerp(STUBBLE, t)
	return STUBBLE


## Silhouette d'un travailleur debout en [param feet].
func _draw_worker(feet: Vector2) -> void:
	draw_line(feet, feet + Vector2(0, -10), WORKER_COLOR, 4.0)
	draw_circle(feet + Vector2(0, -13), 3.0, WORKER_HEAD)
