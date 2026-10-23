class_name CityTier
extends RefCounted
## Palier de la ville (section 7 du plan) : il se débloque par la population
## et des besoins satisfaits, et ne redescend jamais. Pure donnée.

const NAMES: PackedStringArray = ["Hameau", "Village", "Bourg", "Ville", "Cité-État"]
## Population demandée pour chaque palier (le premier est celui du départ).
const POPULATION: PackedInt32Array = [0, 100, 400, 1500, 5000]
## Satisfaction demandée pour passer au palier suivant.
const SATISFACTION_REQUIRED := 0.8

## Palier atteint, de 1 (Hameau) à NAMES.size() (Cité-État).
var level := 1


func name() -> String:
	return NAMES[level - 1]


func is_max() -> bool:
	return level >= NAMES.size()


## Population demandée pour le palier suivant (-1 au dernier palier).
func next_population() -> int:
	return -1 if is_max() else POPULATION[level]


## Passe au palier suivant si [param count] habitants et [param satisfaction]
## (0–1) le permettent ; renvoie true si le palier a changé.
func update(count: int, satisfaction: float) -> bool:
	var before := level
	while not is_max() and count >= POPULATION[level] and satisfaction >= SATISFACTION_REQUIRED:
		level += 1
	return level != before
