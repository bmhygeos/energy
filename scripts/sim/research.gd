class_name Research
extends RefCounted
## Recherche (section 7 du plan) : la ville produit des points par habitant
## et par jour, modulés par la satisfaction, et mène une recherche à la fois.
## Sans recherche en cours, les points sont mis de côté et versés à la
## suivante ; une recherche interrompue garde son avancement. Pure donnée.

## Points par habitant et par jour (à satisfaction pleine).
const POINTS_PER_INHABITANT := 1.0
## Part des points produite même à satisfaction nulle.
const MIN_SATISFACTION_FACTOR := 0.5

## Recherche en cours (null : aucune).
var current: ResearchDef
## Points mis de côté sans recherche en cours.
var bank := 0.0
var _progress: Dictionary[StringName, float] = {}
var _done: Dictionary[StringName, bool] = {}


## Points produits par jour par [param count] habitants à [param satisfaction] (0–1).
static func points_per_day(count: int, satisfaction: float) -> float:
	var factor := MIN_SATISFACTION_FACTOR + (1.0 - MIN_SATISFACTION_FACTOR) * clampf(satisfaction, 0.0, 1.0)
	return count * POINTS_PER_INHABITANT * factor


func is_done(id: StringName) -> bool:
	return _done.has(id)


func progress_of(def: ResearchDef) -> float:
	return def.cost if is_done(def.id) else _progress.get(def.id, 0.0)


## Recherche [param def] proposée au palier [param tier] : palier atteint,
## prérequis terminés, pas déjà faite.
func is_available(def: ResearchDef, tier: int) -> bool:
	if is_done(def.id) or def.tier > tier:
		return false
	for id in def.prerequisites:
		if not is_done(id):
			return false
	return true


## Lance (ou reprend) [param def] ; les points mis de côté lui sont versés.
## Renvoie false si elle n'est pas disponible au palier [param tier].
func start(def: ResearchDef, tier: int) -> bool:
	if not is_available(def, tier):
		return false
	current = def
	_progress[def.id] = _progress.get(def.id, 0.0) + bank
	bank = 0.0
	return true


## Ajoute les [param points] du jour ; renvoie la recherche terminée, ou null.
func add_points(points: float) -> ResearchDef:
	if current == null:
		bank += points
		return null
	var def := current
	_progress[def.id] = _progress.get(def.id, 0.0) + points
	if _progress[def.id] < def.cost:
		return null
	bank = _progress[def.id] - def.cost
	_progress.erase(def.id)
	_done[def.id] = true
	current = null
	return def


## Jours restants pour la recherche en cours à [param per_day] points par jour.
func days_left(per_day: float) -> float:
	if current == null or per_day <= 0.0:
		return INF
	return (current.cost - progress_of(current)) / per_day
