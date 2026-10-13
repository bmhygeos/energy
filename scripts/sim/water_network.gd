class_name WaterNetwork
extends RoadNetwork
## Voies navigables : toutes les tuiles de mer, de lac et de rivière, sans
## construction ni entretien. Même graphe que les routes (4-connexité) ; les
## méthodes héritées « has_road » désignent ici une tuile navigable.


func _init(p_map: WorldMap) -> void:
	super(p_map)
	var cells: Array[Vector2i] = []
	for i in map.cell_count():
		if TerrainDb.is_water(map.terrain[i]):
			cells.append(map.cell_of(i))
	add_cells(cells)


func is_navigable(cell: Vector2i) -> bool:
	return has_road(cell)


func daily_upkeep() -> int:
	return 0


func tile_cost(_cell: Vector2i) -> int:
	return -1
