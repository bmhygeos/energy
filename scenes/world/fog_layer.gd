class_name FogLayer
extends Node2D
## Brume des tuiles explorées hors du territoire (assombries) et frontière
## du territoire. Les tuiles inconnues ne sont pas dessinées (fond noir). Seules
## les tuiles à l'écran sont dessinées : la planète entière peut être connue.

const FOG_COLOR := Color(0, 0, 0, 0.45)
const BORDER_COLOR := Color(1.0, 0.85, 0.35, 0.8)
const BORDER_WIDTH := 3.0
## Tuiles ajoutées autour de l'écran (bordure dessinée sans trou).
const MARGIN := 2
## Côté du losange (indices de Iso.diamond : nord, est, sud, ouest) partagé
## avec chaque voisin.
const EDGES: Dictionary[Vector2i, Vector2i] = {
	Vector2i(1, 0): Vector2i(1, 2),
	Vector2i(-1, 0): Vector2i(3, 0),
	Vector2i(0, 1): Vector2i(2, 3),
	Vector2i(0, -1): Vector2i(0, 1),
}

var _view := Transform2D()


func refresh() -> void:
	queue_redraw()


func _process(_delta: float) -> void:
	# La vue a bougé (déplacement, zoom) : redessiner les tuiles à l'écran.
	var view := get_viewport().get_canvas_transform()
	if view != _view:
		_view = view
		queue_redraw()


func _draw() -> void:
	var territory := GameState.territory
	if territory == null or GameState.view_city:
		return
	var map := GameState.world_map
	var area := Iso.visible_cells(get_viewport(), MARGIN)
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			var cell := Vector2i(x, y)
			if not map.has_cell(cell) or not territory.is_known(cell):
				continue
			var d := Iso.diamond(cell)
			var owner := territory.owner_at(cell)
			if owner < 0:
				draw_colored_polygon(d, FOG_COLOR)
				continue
			# Frontière du territoire, et entre deux villes.
			for offset: Vector2i in EDGES:
				if territory.owner_at(cell + offset) != owner:
					var edge := EDGES[offset]
					draw_line(d[edge.x], d[edge.y], BORDER_COLOR, BORDER_WIDTH, true)
