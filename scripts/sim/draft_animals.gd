class_name DraftAnimals
extends RefCounted
## Chevaux de trait (palier 2, section 7 du plan) : les troupeaux des
## pâturages donnent des poulains, dans la limite des écuries ; ils mangent
## du fourrage au grenier et dépérissent sans lui. Ils sont attelés aux tuiles
## travaillées les plus lointaines, dont la pénalité de distance commence plus
## loin et compte moitié moins ; partis en expédition comme chevaux de bât,
## ils portent des vivres. Pure donnée.

## Fourrage (nourriture) par cheval et par jour à l'écurie.
const FODDER_PER_DAY := 3.0
## Poulains par jour et par tuile de pâturage (pondérée par sa qualité) tant
## que les écuries ont de la place.
const FOALS_PER_PASTURE_PER_DAY := 0.01
## Sans fourrage, part des chevaux perdue par jour.
const STARVE_PER_DAY := 0.05
## Attelage : la pénalité de distance commence à DRAFT_FREE_DISTANCE tuiles
## et vaut DRAFT_PENALTY par tuile au-delà.
const DRAFT_FREE_DISTANCE := 12
const DRAFT_PENALTY := 0.015
## Vivres portés par un cheval de bât, en multiple de ceux d'un explorateur.
const PACK_FACTOR := 4.0
## Puissance d'un cheval au travail (compteur de puissance).
const WORK_WATTS := 700.0

## Chevaux (fractionnaire : les poulains grandissent peu à peu).
var horses := 0.0
## Places dans les écuries.
var capacity := 0
## Chevaux partis en expédition.
var away := 0
## Tuiles (ramenées sur la planète) desservies par un attelage.
var harnessed: Dictionary[Vector2i, bool] = {}


func count() -> int:
	return floori(horses + 1e-6)


## Chevaux à l'écurie ou au travail (hors expédition).
func at_home() -> int:
	return maxi(0, count() - away)


func fodder_need() -> float:
	return at_home() * FODDER_PER_DAY


## Élevage du jour sur [param pastures] tuiles de pâturage (somme de leurs
## qualités) ; renvoie les poulains nés (fraction).
func breed(pastures: float) -> float:
	var room := capacity - horses
	if room <= 0.0 or pastures <= 0.0:
		return 0.0
	var foals := minf(room, FOALS_PER_PASTURE_PER_DAY * pastures)
	horses += foals
	return foals


## Fin de journée avec la part du fourrage obtenue [param fodder_coverage]
## (0–1) : dépérissement sans fourrage, chevaux en trop sans écurie.
func end_day(fodder_coverage: float) -> void:
	if fodder_coverage < 1.0:
		horses -= horses * STARVE_PER_DAY * (1.0 - clampf(fodder_coverage, 0.0, 1.0))
	horses = clampf(horses, float(away), maxf(float(capacity), float(away)))


## Attelle les chevaux à l'écurie aux tuiles de [param workers_at] les plus
## lointaines (au-delà de la distance sans pénalité) ; [param distance]
## donne la distance d'une tuile au village.
func harness(workers_at: Dictionary[Vector2i, int], distance: Callable) -> void:
	harnessed.clear()
	var cells: Array[Vector2i] = []
	for cell in workers_at:
		if distance.call(cell) > Labor.FREE_DISTANCE:
			cells.append(cell)
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return distance.call(a) > distance.call(b))
	for cell in cells.slice(0, at_home()):
		harnessed[cell] = true


## Chevaux attelés (au travail).
func working() -> int:
	return harnessed.size()


## Facteur de proximité d'une tuile desservie par un attelage.
static func draft_distance_factor(tiles: int) -> float:
	return clampf(1.0 - DRAFT_PENALTY * maxi(0, tiles - DRAFT_FREE_DISTANCE), 0.0, 1.0)
