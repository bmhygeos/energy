class_name RailNetwork
extends RoadNetwork
## Voies ferrées : même graphe que les routes (4-connexité), avec leurs
## propres coûts. Une voie peut croiser une route (passage à niveau). Les
## méthodes héritées « has_road » désignent ici une tuile de voie.

const RAIL_COST_PER_TILE := 150
const RAIL_FOREST_EXTRA_COST := 50
const RAIL_BRIDGE_COST := 1200
const RAIL_UPKEEP_PER_TILE_PER_DAY := 2


func has_rail(cell: Vector2i) -> bool:
	return has_road(cell)


func daily_upkeep() -> int:
	return tile_count() * RAIL_UPKEEP_PER_TILE_PER_DAY


func tile_cost(cell: Vector2i) -> int:
	match map.get_terrain(cell):
		TerrainDef.Type.PLAIN, TerrainDef.Type.DESERT:
			return RAIL_COST_PER_TILE
		TerrainDef.Type.FOREST:
			return RAIL_COST_PER_TILE + RAIL_FOREST_EXTRA_COST
		TerrainDef.Type.HILL:
			return roundi(RAIL_COST_PER_TILE * HILL_COST_FACTOR)
		TerrainDef.Type.RIVER:
			return RAIL_BRIDGE_COST
	return -1
