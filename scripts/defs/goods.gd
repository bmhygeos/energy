class_name Goods
extends RefCounted
## Marchandises transportables (en tonnes). L'électricité n'en fait pas partie :
## elle passe par le réseau.

enum Type { NONE, WOOD, COAL, URANIUM_ORE, NUCLEAR_FUEL, NUCLEAR_WASTE, DEUTERIUM, LITHIUM }

const NAMES: PackedStringArray = ["—", "Bois", "Charbon", "Minerai d'uranium", "Combustible nucléaire",
	"Déchets nucléaires", "Deutérium", "Lithium"]
const COLORS: Array[Color] = [Color.TRANSPARENT, Color("a8743f"), Color("2a2a2a"), Color("c9b54a"),
	Color("5fd35f"), Color("a64fc9"), Color("6fc3ff"), Color("e6e6f0")]
## Matières dangereuses : transportées seulement par des véhicules blindés,
## jamais stockées en entrepôt ni en gare.
const HAZARDOUS: Array[Type] = [Type.NUCLEAR_FUEL, Type.NUCLEAR_WASTE]


static func display_name(type: Type) -> String:
	return NAMES[type]


static func is_hazardous(type: int) -> bool:
	return type in HAZARDOUS
