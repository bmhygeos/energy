class_name Goods
extends RefCounted
## Marchandises transportables (en tonnes). L'électricité n'en fait pas partie :
## elle passe par le réseau.

enum Type { NONE, WOOD, COAL }

const NAMES: PackedStringArray = ["—", "Bois", "Charbon"]
const COLORS: Array[Color] = [Color.TRANSPARENT, Color("a8743f"), Color("2a2a2a")]


static func display_name(type: Type) -> String:
	return NAMES[type]
