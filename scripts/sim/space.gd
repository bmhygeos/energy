class_name Space
extends RefCounted
## Ère spatiale (recherche Fusée) : les usines de fusées assemblent les
## fusées jour après jour (fer, électronique, cuivre, courant) ; une base de
## lancement les tire contre du carburant (moins près de l'équateur), avec un
## risque d'échec. Le premier satellite cartographie la planète par bandes de
## longitude : tuiles explorées et gisements prospectés. Pure donnée.

## Jours de travail d'une usine pour une fusée, et matériaux par jour.
const ROCKET_WORK_DAYS := 40
const IRON_PER_DAY := 5.0
const ELECTRONICS_PER_DAY := 3.0
const COPPER_PER_DAY := 2.0
## Carburant d'un lancement à l'équateur et aux pôles.
const LAUNCH_FUEL_EQUATOR := 300.0
const LAUNCH_FUEL_POLE := 600.0
## Part des lancements qui échouent (fusée perdue, carburant brûlé).
const FAILURE_CHANCE := 0.15
## Satellites, dans l'ordre des lancements réussis : observation (cartographie
## de la planète), météo (prévisions, intempéries atténuées), communications
## (avant-postes reliés, recherche) ; les suivants s'ajoutent en orbite.
enum Kind { SURVEY, WEATHER, COMMUNICATIONS }
const KIND_NAMES: PackedStringArray = ["observation", "météo", "communications"]
## Satellite de communications : bonus de la recherche.
const COMMUNICATIONS_RESEARCH := 0.1
## Voyage sur la Lune (palier 6) : jours de travail de la fusée lunaire
## (matériaux doublés), carburant à l'équateur (×2 aux pôles), réussite.
const LUNAR_WORK_DAYS := 120
const LUNAR_MATERIALS := 2.0
const LUNAR_FUEL_EQUATOR := 3000.0
const LUNAR_SUCCESS := 0.9
## Colonnes de longitude cartographiées par jour par le satellite.
const SURVEY_COLUMNS_PER_DAY := 16

## Jours de travail accumulés sur la fusée en cours.
var progress := 0.0
## Fusées prêtes à partir.
var rockets := 0
## Satellites en orbite, lancements tentés.
var satellites := 0
var launches := 0
## Genres des satellites en orbite (Kind), dans l'ordre des lancements.
var kinds: Array[int] = []
## Prochaine colonne de longitude à cartographier (-1 : pas de satellite).
var survey_column := -1
var rng := RandomNumberGenerator.new()
## Voyage sur la Lune : projet lancé (recherche faite), avancement de la
## fusée lunaire, fusée prête, équipage sur la Lune.
var lunar_project := false
var lunar_progress := 0.0
var lunar_ready := false
var moon_landed := false


func _init(p_seed: int = 0) -> void:
	rng.seed = p_seed


## Un jour d'assemblage pour [param factories] usines alimentées : prend les
## matériaux de [param stock] (au prorata de ce qui reste) ; renvoie true si
## une fusée vient d'être terminée.
func assemble(stock: Stockpile, factories: float) -> bool:
	if factories <= 0.0:
		return false
	# Projet lunaire en cours : les usines construisent la fusée lunaire.
	var lunar := building_lunar()
	var scale := LUNAR_MATERIALS if lunar else 1.0
	var share := factories
	for pair: Array in [[Stockpile.Good.IRON, IRON_PER_DAY], [Stockpile.Good.ELECTRONICS, ELECTRONICS_PER_DAY],
			[Stockpile.Good.COPPER, COPPER_PER_DAY]]:
		share = minf(share, stock.amount[pair[0]] / (pair[1] * scale))
	if share <= 0.0:
		return false
	stock.take(Stockpile.Good.IRON, IRON_PER_DAY * scale * share)
	stock.take(Stockpile.Good.ELECTRONICS, ELECTRONICS_PER_DAY * scale * share)
	stock.take(Stockpile.Good.COPPER, COPPER_PER_DAY * scale * share)
	if lunar:
		lunar_progress += share
		if lunar_progress >= LUNAR_WORK_DAYS:
			lunar_progress = 0.0
			lunar_ready = true
			return true
		return false
	progress += share
	if progress >= ROCKET_WORK_DAYS:
		progress -= ROCKET_WORK_DAYS
		rockets += 1
		return true
	return false


## Les usines travaillent-elles à la fusée lunaire ?
func building_lunar() -> bool:
	return lunar_project and not moon_landed and not lunar_ready


## Carburant du lancement lunaire à la latitude [param latitude].
static func lunar_fuel(latitude: float) -> float:
	return LUNAR_FUEL_EQUATOR * launch_fuel(latitude) / LAUNCH_FUEL_EQUATOR


## Lance la fusée lunaire prête ; renvoie true si l'équipage se pose sur la
## Lune (sinon la fusée est perdue et le projet reprend).
func launch_lunar() -> bool:
	lunar_ready = false
	launches += 1
	if rng.randf() >= LUNAR_SUCCESS:
		return false
	moon_landed = true
	return true


## Carburant d'un lancement à la latitude [param latitude] (degrés).
static func launch_fuel(latitude: float) -> float:
	return lerpf(LAUNCH_FUEL_EQUATOR, LAUNCH_FUEL_POLE, absf(sin(deg_to_rad(latitude))))


## Genre du prochain satellite : le premier qui manque, sinon un de plus.
func next_kind() -> Kind:
	for kind in Kind.size():
		if kind not in kinds:
			return kind as Kind
	return Kind.COMMUNICATIONS


## Un satellite de ce genre est-il en orbite ?
func has(kind: Kind) -> bool:
	return kind in kinds


## Lance une fusée prête ; renvoie true si le satellite atteint l'orbite (le
## premier, d'observation, commence la cartographie de la planète).
func launch() -> bool:
	rockets -= 1
	launches += 1
	if rng.randf() < FAILURE_CHANCE:
		return false
	satellites += 1
	kinds.append(next_kind())
	if survey_column < 0:
		survey_column = 0
	return true


## Cartographie du jour : colonnes de longitude de la planète [param width]
## tuiles de large ; renvoie leurs abscisses (vide : rien à faire).
func survey_day(width: int) -> PackedInt32Array:
	var columns := PackedInt32Array()
	if survey_column < 0 or survey_column >= width:
		return columns
	for x in range(survey_column, mini(width, survey_column + SURVEY_COLUMNS_PER_DAY)):
		columns.append(x)
	survey_column += columns.size()
	return columns


## Part de la planète cartographiée (0–1).
func surveyed(width: int) -> float:
	return clampf(float(maxi(0, survey_column)) / width, 0.0, 1.0)
