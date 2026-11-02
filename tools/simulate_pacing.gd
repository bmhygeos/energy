extends SceneTree
## Rythme des paliers : joue une partie sans affichage avec une stratégie
## simple (zones sur tout le territoire, maisons et greniers quand il en faut,
## une expédition à la fois, recherches dans l'ordre, puits, atelier et
## carrière au village) et affiche l'évolution mois par mois, puis les jours
## où chaque palier et chaque jalon sont atteints.
## Lancer : godot --headless -s res://tools/simulate_pacing.gd -- [graine] [années]

const ZONE_ORDER: Array[StringName] = [&"pasture", &"agriculture", &"forestry", &"quarry", &"fishing", &"iron_mine"]
## Demi-côté du carré (autour du village) repeint en zones.
const ZONE_RADIUS := 24
## Demi-côté du carré central laissé sans zone pour les bâtiments (agrandi
## avec la population).
const BUILD_RADIUS := 4
## Logements libres en dessous desquels une maison est construite.
const HOUSING_MARGIN := 3
const DIRECTIONS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(-1, 1), Vector2i(-1, -1), Vector2i(1, -1)]

var _gs: Node
var _clock: Node
var _center: Vector2i
var _expeditions := 0
var _tier_days: Dictionary[int, int] = {}


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var seed_value := int(args[0]) if args.size() > 0 else 42
	var years := int(args[1]) if args.size() > 1 else 6
	_gs = root.get_node("GameState")
	_clock = root.get_node("GameClock")
	# Autoloads prêts (signaux d'horloge branchés) avant la partie.
	await process_frame
	_gs.new_game(seed_value)
	_clock.speed = 0
	_center = _gs.display_cell(_gs.home)
	_paint_zones()
	print("Graine %d — jour, palier, habitants / logements, stocks, eau servie, satisfaction, territoire, recherche" % seed_value)
	var days := years * GameDate.DAYS_PER_SEASON * GameDate.SEASONS_PER_YEAR
	for day in days:
		_play_day(day)
		for h in GameDate.HOURS_PER_DAY:
			_clock._step()
		if not _tier_days.has(_gs.tier.level):
			_tier_days[_gs.tier.level] = day + 1
		if day % 30 == 29:
			_print_month(day + 1)
		if _gs.population.count == 0:
			print("Village déserté au jour %d" % (day + 1))
			break
	print("\nPaliers : ", ", ".join(_tier_days.keys().map(func(t: int) -> String:
		return "%s jour %d" % [CityTier.NAMES[t - 1], _tier_days[t]])))
	var milestones: Milestones = _gs.milestones
	for def in milestones.defs:
		var when := "jour %d" % (milestones.reached[def.id] + 1) if milestones.is_reached(def.id) else "—"
		print("  %-24s %s" % [def.display_name, when])
	print("Expéditions : %d" % _expeditions)
	quit()


func _print_month(day: int) -> void:
	var stock: Stockpile = _gs.stockpile
	print("%4d  %-9s %4d / %-4d  nourr. %5d  bois %5d  pierre %4d  fer %4d  outils %3d  eau %3d %%  sat. %3d %%  terr. %4d  %s" % [
		day, _gs.tier.name(), _gs.population.count, _gs.housing,
		stock.amount[Stockpile.Good.FOOD], stock.amount[Stockpile.Good.WOOD], stock.amount[Stockpile.Good.STONE],
		stock.amount[Stockpile.Good.IRON], stock.amount[Stockpile.Good.TOOLS], roundi(_gs.water_coverage() * 100.0),
		roundi(_gs.population.satisfaction * 100.0), _gs.territory.count(Territory.State.TERRITORY),
		_gs.research.current.display_name if _gs.research.current else "-"])


func _play_day(day: int) -> void:
	if _gs.research.current == null:
		for def in ResearchDb.DEFS:
			if _gs.start_research(def):
				break
	if day == 0:
		_build_near(&"woodshed")
	if _gs.housing - _gs.population.count <= HOUSING_MARGIN:
		_build_near(&"house")
	var stock: Stockpile = _gs.stockpile
	if stock.amount[Stockpile.Good.FOOD] >= 0.9 * stock.capacity[Stockpile.Good.FOOD] \
			and stock.capacity[Stockpile.Good.FOOD] < _gs.food_need() * GameDate.DAYS_PER_SEASON * 2:
		_build_near(&"granary")
	if stock.amount[Stockpile.Good.WOOD] >= 0.9 * stock.capacity[Stockpile.Good.WOOD]:
		_build_near(&"woodshed")
	if _gs.tier.level >= 2:
		if _gs.water_coverage() < 1.0:
			_build_near(&"well")
		if not _has(&"workshop"):
			_build_near(&"workshop")
		if not _has(&"stable"):
			_build_near(&"stable")
		if _gs.research.is_done(&"iron_metallurgy") and not _has(&"forge"):
			_build_near(&"forge")
	if _gs.exploration.can_launch() and day % 10 == 0 and _gs.food_days() > 30.0:
		var dir := DIRECTIONS[_expeditions % DIRECTIONS.size()]
		var reach := 20 + 8 * (_expeditions / DIRECTIONS.size())
		if _gs.launch_expedition(_center + dir * reach, 3, float(_gs.exploration.max_days())):
			_expeditions += 1
	if day % 10 == 5:
		_paint_zones()


## Zones sur tout le territoire proche, dans ZONE_ORDER (les suivantes
## repeignent les tuiles valides des précédentes), sauf au centre.
func _paint_zones() -> void:
	var from := _center - Vector2i.ONE * ZONE_RADIUS
	var to := _center + Vector2i.ONE * ZONE_RADIUS
	for id in ZONE_ORDER:
		var def := ZoneDb.get_def(id)
		if def.tier > _gs.tier.level:
			continue
		_gs.apply_zones(_gs.plan_zones(def, from, to))
	var r := _build_radius()
	_gs.apply_zones(_gs.plan_zones(null, _center - Vector2i.ONE * r, _center + Vector2i.ONE * r))
	# La colline à pierre du village est au centre : la carrière y reste.
	if _gs.tier.level >= 2:
		_gs.apply_zones(_gs.plan_zones(ZoneDb.get_def(&"quarry"), _center - Vector2i.ONE * r, _center + Vector2i.ONE * r))


func _build_radius() -> int:
	return BUILD_RADIUS + _gs.population.count / 40


## Construit [param id] au plus près du centre ; renvoie true si posé.
func _build_near(id: StringName) -> bool:
	var def := BuildingDb.get_def(id)
	if def.tier > _gs.tier.level:
		return false
	for r in range(1, _build_radius() + 1):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var placement: BuildingRegistry.Placement = _gs.check_placement(def, _center + Vector2i(dx, dy))
				# Ni sur la colline des carrières, ni sur le fer des mines.
				if placement.is_valid() and placement.cleared.is_empty() \
						and not placement.cells.any(Callable(_gs, &"_reserved_at_start")):
					return _gs.build(def, _center + Vector2i(dx, dy)) != null
	return false


func _has(id: StringName) -> bool:
	return _gs.buildings.all().any(func(b: Building) -> bool: return b.def.id == id)
