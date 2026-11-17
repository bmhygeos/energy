class_name FlatGenerator
extends MapGenerator
## Générateur d'une plaine uniforme (carte de la ville, cartes de test) :
## terrain constructible partout, vent et soleil moyens.


func _init(p_size: Vector2i) -> void:
	super(0, p_size)


func generate_chunk(_coord: Vector2i) -> WorldMap.Chunk:
	var chunk := WorldMap.Chunk.new()
	chunk.terrain.fill(TerrainDef.Type.PLAIN)
	chunk.wind.fill(0.3)
	chunk.sun.fill(0.5)
	chunk.fertility.fill(0.7)
	return chunk
