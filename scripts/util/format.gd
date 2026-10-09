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


## Durée en heures de jeu : "36 h", "3 j".
static func duration_hours(hours: int) -> String:
	return "%d j" % (hours / 24) if hours >= 24 and hours % 24 == 0 else "%d h" % hours


## Nombre à [param digits] décimales avec virgule : 12.34 → "12,3".
static func decimal(value: float, digits: int = 1) -> String:
	return ("%.*f" % [digits, value]).replace(".", ",")
