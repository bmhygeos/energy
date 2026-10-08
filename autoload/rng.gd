extends Node
## Générateur aléatoire global seedé : même graine → même partie.

var seed_value: int = 0
var _rng := RandomNumberGenerator.new()


func set_seed(value: int) -> void:
	seed_value = value
	_rng.seed = value
	_rng.state = 0


func randi_range(from: int, to: int) -> int:
	return _rng.randi_range(from, to)


func randf() -> float:
	return _rng.randf()


func randf_range(from: float, to: float) -> float:
	return _rng.randf_range(from, to)


## Crée un flux indépendant et reproductible pour un sous-système (carte,
## événements, …), pour que l'ordre des tirages d'un système n'affecte pas
## les autres.
func fork(stream_name: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, stream_name])
	return rng
