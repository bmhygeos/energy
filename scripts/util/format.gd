class_name Format
extends RefCounted
## Mise en forme des nombres pour l'interface (usage français).


## 1234567 → "1 234 567" (espace fine insécable).
static func thousands(value: int) -> String:
	var digits := str(absi(value))
	var groups := PackedStringArray()
	while digits.length() > 3:
		groups.insert(0, digits.right(3))
		digits = digits.left(-3)
	groups.insert(0, digits)
	return ("-" if value < 0 else "") + " ".join(groups)
