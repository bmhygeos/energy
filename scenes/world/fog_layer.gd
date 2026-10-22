class_name FogLayer
extends Node2D
## Brume des tuiles explorées hors du territoire (assombries) et frontière
## du territoire. Les tuiles inconnues ne sont pas dessinées (fond noir).

const FOG_COLOR := Color(0, 0, 0, 0.45)
const BORDER_COLOR := Color(1.0, 0.85, 0.35, 0.8)
const BORDER_WIDTH := 3.0
## Côté du losange (indices de Iso.diamond : nord, est, sud, ouest) partagé
## avec chaque voisin.
const EDGES: Dictionary[Vector2i, Vector2i] = {
	Vector2i(1, 0): Vector2i(1, 2),
	Vector2i(-1, 0): Vector2i(3, 0),
	Vector2i(0, 1): Vector2i(2, 3),
	Vector2i(0, -1): Vector2i(0, 1),
}


func refresh() -> void:
	queue_redraw()


func _draw() -> void:
	var territory := GameState.territory
	if territory == null:
		return
	for c in territory.known_cells():
		var cell := GameState.display_cell(c)
		var d := Iso.diamond(cell)
		if not territory.is_territory(cell):
			draw_colored_polygon(d, FOG_COLOR)
			continue
		for offset: Vector2i in EDGES:
			if not territory.is_territory(cell + offset):
				var edge := EDGES[offset]
				draw_line(d[edge.x], d[edge.y], BORDER_COLOR, BORDER_WIDTH, true)
