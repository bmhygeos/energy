class_name TickAccumulator
extends RefCounted
## Convertit un temps réel écoulé en nombre de ticks de simulation.
##
## Classe pure (sans nœud) : déterministe et testable hors scène.

## Ticks par seconde réelle à la vitesse ×1.
var ticks_per_second: float
## Plafond de ticks par appel, pour éviter la spirale de rattrapage
## quand une image est très lente.
var max_ticks_per_step: int

var _pending: float = 0.0


func _init(p_ticks_per_second: float = 10.0, p_max_ticks_per_step: int = 16) -> void:
	ticks_per_second = p_ticks_per_second
	max_ticks_per_step = p_max_ticks_per_step


## Ajoute [param delta] secondes à la vitesse [param multiplier] et renvoie
## le nombre de ticks entiers à exécuter maintenant.
func consume(delta: float, multiplier: float) -> int:
	if multiplier <= 0.0 or delta <= 0.0:
		return 0
	_pending += delta * ticks_per_second * multiplier
	var count := floori(_pending)
	if count > max_ticks_per_step:
		# Retard trop important : on abandonne le surplus plutôt que de geler.
		count = max_ticks_per_step
		_pending = 0.0
	else:
		_pending -= count
	return count


## Fraction du prochain tick déjà écoulée (0–1), utile pour interpoler le rendu.
func get_alpha() -> float:
	return clampf(_pending, 0.0, 1.0)


func reset() -> void:
	_pending = 0.0
