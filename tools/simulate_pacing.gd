extends SceneTree
## Rythme des paliers : joue une partie sans affichage avec une stratégie
## simple (zones sur tout le territoire, maisons et greniers quand il en faut,
## une expédition à la fois, recherches dans l'ordre, puits, atelier et
## carrière au village ; lin, mine de charbon, atelier de tissage,
## laboratoire et moulin à eau au bourg ; réservoir, puits de pétrole,
## raffinerie et université à la ville) et affiche l'évolution mois par mois, puis les jours
## où chaque palier et chaque jalon sont atteints.
## Les camps d'abattage sont plafonnés et le bois en trop vendu au bourg ; sans
## place au centre, un bâtiment remplace une zone.
## Lancer : godot --headless -s res://tools/simulate_pacing.gd -- [graine] [années]

const ZONE_ORDER: Array[StringName] = [&"pasture", &"agriculture", &"forestry", &"quarry", &"fishing", &"iron_mine",
	&"coal_mine", &"oil_well"]
## Bourg : carré de lin (demi-côté) au sud-est du village.
const FLAX_RADIUS := 2
const FLAX_OFFSET := Vector2i(10, 10)
## Demi-côté du carré (autour du village) repeint en zones.
const ZONE_RADIUS := 24
## Demi-côté du carré central laissé sans zone pour les bâtiments (agrandi
## avec la population).
const BUILD_RADIUS := 4
## Plafond de ce carré : au-delà, il effacerait les champs (les zones sont
## retirées dans ce carré) et affamerait la ville.
const MAX_BUILD_RADIUS := 14
## Les maisons restent dans ce carré : le pourtour garde de la place pour les
## puits et les ateliers (ensuite, elles s'améliorent sur place).
const HOUSE_RADIUS := 9
## Marchés visés (volume échangé par jour).
const TRADE_GOAL := 600.0
## Jours de réserve sous lesquels une marchandise est achetée.
const BUY_BELOW_DAYS := 10.0
## Jours de chauffage d'hiver que les camps d'abattage doivent pouvoir stocker
## (au-delà, ils prendraient la place des maisons).
const WOOD_STORE_DAYS := 60.0
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
	print("%4d  %-9s %4d / %-4d  nourr. %5d  bois %5d  pierre %4d  fer %4d  outils %3d  charb. %4d  vêt. %3d  eau %3d %%  sat. %3d %%  terr. %4d  %s" % [
		day, _gs.tier.name(), _gs.population.count, _gs.housing,
		stock.amount[Stockpile.Good.FOOD], stock.amount[Stockpile.Good.WOOD], stock.amount[Stockpile.Good.STONE],
		stock.amount[Stockpile.Good.IRON], stock.amount[Stockpile.Good.TOOLS], stock.amount[Stockpile.Good.COAL],
		stock.amount[Stockpile.Good.CLOTHES], roundi(_gs.water_coverage() * 100.0),
		roundi(_gs.population.satisfaction * 100.0), _gs.territory.count(Territory.State.TERRITORY),
		_gs.research.current.display_name if _gs.research.current else "-"])


func _play_day(day: int) -> void:
	if _gs.research.current == null:
		for def in ResearchDb.DEFS:
			if _gs.start_research(def):
				break
	if day == 0:
		_build_near(&"woodshed")
	if _gs.housing - _gs.population.count <= HOUSING_MARGIN and not _build_near(&"house", 0, HOUSE_RADIUS) \
			and not _upgrade_house():
		_build_anywhere(&"house")
	var stock: Stockpile = _gs.stockpile
	# Au bourg, sous le seuil de vente automatique : sinon, les greniers ne
	# grandiraient plus.
	var full_food := 0.7 if _gs.tier.level >= 3 else 0.9
	if stock.amount[Stockpile.Good.FOOD] >= full_food * stock.capacity[Stockpile.Good.FOOD] \
			and stock.capacity[Stockpile.Good.FOOD] < _gs.food_need() * GameDate.DAYS_PER_SEASON * 2:
		_build_anywhere(&"granary")
	if stock.amount[Stockpile.Good.WOOD] >= 0.9 * stock.capacity[Stockpile.Good.WOOD] \
			and stock.capacity[Stockpile.Good.WOOD] < _gs.wood_need(GameDate.WINTER) * WOOD_STORE_DAYS:
		_build_anywhere(&"woodshed")
	if _gs.tier.level >= 2:
		if _gs.water_coverage() < 1.0:
			_build_anywhere(&"well")
		if not _has(&"workshop"):
			_build_anywhere(&"workshop")
		if not _has(&"stable"):
			_build_anywhere(&"stable")
		if _gs.research.is_done(&"iron_metallurgy") \
				and _count(&"forge") * BuildingDb.get_def(&"forge").tools_per_day < maxf(1.0, _gs.tools_need()):
			_build_anywhere(&"forge")
	if _gs.tier.level >= 3:
		if _count(&"weaver") * BuildingDb.get_def(&"weaver").clothes_per_day < _gs.clothes_need():
			_build_anywhere(&"weaver")
		if _gs.research.is_done(&"scientific_method") and not _has(&"laboratory"):
			_build_anywhere(&"laboratory")
		if _gs.research.is_done(&"water_mill") and not _has(&"water_mill"):
			if not _build_near(&"water_mill", 12):
				_build_clearing(&"water_mill")
		if _gs.research.is_done(&"steam_engine") and not _has(&"steam_engine"):
			_build_anywhere(&"steam_engine")
		if stock.amount[Stockpile.Good.COAL] >= 0.9 * stock.capacity[Stockpile.Good.COAL]:
			_build_anywhere(&"coal_yard")
		if _gs.treasury.trade_capacity + _building_markets() * BuildingDb.get_def(&"market").trade_per_day < TRADE_GOAL:
			_build_anywhere(&"market")
		# Impôt normal et surplus de nourriture vendus : de quoi payer les achats.
		_gs.set_tax_level(2)
		_gs.set_auto_sell(Stockpile.Good.FOOD, true)
		_gs.set_auto_sell(Stockpile.Good.WOOD, true)
		_buy_shortages()
	if _gs.tier.level >= 4:
		if not _has(&"oil_tank"):
			_build_near(&"oil_tank")
		if _gs.research.is_done(&"refining") and _count(&"refinery") * BuildingDb.get_def(&"refinery").fuel_per_day < _gs.light_need():
			_build_near(&"refinery")
		if _gs.research.is_done(&"university") and not _has(&"university") and _gs.treasury.money > 1000.0:
			_build_clearing(&"university")
	if _gs.exploration.can_launch() and day % 10 == 0 and _gs.food_days() > 30.0:
		var dir := DIRECTIONS[_expeditions % DIRECTIONS.size()]
		var reach := 20 + 8 * (_expeditions / DIRECTIONS.size())
		var horses := 3 if _gs.tier.level >= Exploration.MOUNTED_TIER and _gs.draft.at_home() >= 3 else 0
		if _gs.launch_expedition(_center + dir * reach, 3, float(_gs.exploration.max_days()), horses):
			_expeditions += 1
	if day % 10 == 5:
		_paint_zones()


## Zones sur tout le territoire proche, dans ZONE_ORDER (les suivantes
## repeignent les tuiles valides des précédentes), sauf au centre.
func _paint_zones() -> void:
	# Une grande ville va chercher plus loin le bois qu'elle a épuisé.
	var radius := maxi(ZONE_RADIUS, _gs.population.count / 30)
	var from := _center - Vector2i.ONE * radius
	var to := _center + Vector2i.ONE * radius
	for id in ZONE_ORDER:
		var def := ZoneDb.get_def(id)
		if def.tier > _gs.tier.level:
			continue
		_gs.apply_zones(_gs.plan_zones(def, from, to))
	var r := _build_radius()
	_gs.apply_zones(_gs.plan_zones(null, _center - Vector2i.ONE * r, _center + Vector2i.ONE * r))
	# La colline à pierre et le fer du village sont au centre : carrière et mine y restent.
	if _gs.tier.level >= 2:
		_gs.apply_zones(_gs.plan_zones(ZoneDb.get_def(&"quarry"), _center - Vector2i.ONE * r, _center + Vector2i.ONE * r))
		_gs.apply_zones(_gs.plan_zones(ZoneDb.get_def(&"iron_mine"), _center - Vector2i.ONE * r, _center + Vector2i.ONE * r))
	# Le charbon du bourg est près du centre : la mine y reste.
	if _gs.tier.level >= 3:
		_gs.apply_zones(_gs.plan_zones(ZoneDb.get_def(&"coal_mine"), _center - Vector2i.ONE * r, _center + Vector2i.ONE * r))
	# Le pétrole de la ville aussi.
	if _gs.tier.level >= 4:
		_gs.apply_zones(_gs.plan_zones(ZoneDb.get_def(&"oil_well"), _center - Vector2i.ONE * r, _center + Vector2i.ONE * r))
	if _gs.tier.level >= 3:
		var flax := _center + FLAX_OFFSET
		var flax_radius: int = FLAX_RADIUS + _gs.population.count / 400
		_gs.apply_zones(_gs.plan_zones(ZoneDb.get_def(&"flax"), flax - Vector2i.ONE * flax_radius, flax + Vector2i.ONE * flax_radius))


func _build_radius() -> int:
	return mini(BUILD_RADIUS + _gs.population.count / 40, MAX_BUILD_RADIUS)


## Construit [param id] au plus près du centre (jusqu'à [param radius] tuiles,
## par défaut le rayon des bâtiments, au plus [param limit]) ; renvoie true si
## posé.
func _build_near(id: StringName, radius := 0, limit := 1000) -> bool:
	var def := BuildingDb.get_def(id)
	if def.tier > _gs.tier.level:
		return false
	for r in range(1, mini(maxi(radius, _build_radius()), limit) + 1):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var placement: BuildingRegistry.Placement = _gs.check_placement(def, _center + Vector2i(dx, dy))
				# Ni sur la colline des carrières, ni sur le fer des mines.
				if placement.is_valid() and placement.cleared.is_empty() and not placement.cells.any(_reserved):
					return _gs.build(def, _center + Vector2i(dx, dy)) != null
	return false


## Collines et gisements restent aux carrières et aux mines ; les gisements de
## pierre, nombreux près du village, se bâtissent : sinon, plus de place.
func _reserved(cell: Vector2i) -> bool:
	return _gs._reserved_at_start(cell) and _gs.world_map.get_deposit(cell) != WorldMap.Deposit.STONE


## Construit [param id] au centre, ou à défaut à la place d'une zone.
func _build_anywhere(id: StringName) -> bool:
	return _build_near(id) or _build_clearing(id)


## Construit [param id] au plus près du centre en effaçant les zones de son
## emprise ; renvoie true si posé.
func _build_clearing(id: StringName) -> bool:
	var def := BuildingDb.get_def(id)
	var level: BuildingDef = _gs.build_level(def)
	var costs: PackedFloat32Array = _gs.build_costs(def)
	if level.tier > _gs.tier.level:
		return false
	for good in costs.size():
		if not _gs.stockpile.has(good, costs[good]):
			return false
	for r in range(1, ZONE_RADIUS):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var anchor: Vector2i = _center + Vector2i(dx, dy)
				var placement: BuildingRegistry.Placement = _gs.buildings.check_placement(level, anchor)
				if placement.is_valid() and placement.cleared.is_empty() and not placement.cells.any(_reserved):
					_gs.apply_zones(_gs.plan_zones(null, placement.cells[0], placement.cells[-1]))
					return _gs.build(def, anchor) != null
	return false


## Marchés en chantier.
func _building_markets() -> int:
	return _gs.buildings.all().filter(func(b: Building) -> bool: return b.def.id == &"market" and not b.is_complete()).size()


## Achète au marché ce qui manque : vivres et chauffage d'abord, puis le reste.
func _buy_shortages() -> void:
	if _gs.trade_error() != "":
		return
	var stock: Stockpile = _gs.stockpile
	var season := GameDate.season(_clock.tick)
	var needs := {Stockpile.Good.FOOD: _gs.food_need(), Stockpile.Good.WOOD: _gs.wood_need(season), Stockpile.Good.CLOTHES: _gs.clothes_need(),
		Stockpile.Good.TOOLS: _gs.tools_need(), Stockpile.Good.FUEL: _gs.light_need()}
	for good: int in needs:
		var missing: float = needs[good] * BUY_BELOW_DAYS - stock.amount[good]
		if missing > 0.0:
			_gs.treasury.buy(stock, good, missing)


## Plus de place : améliore une maison ; false si aucune ne peut l'être.
func _upgrade_house() -> bool:
	for b: Building in _gs.buildings.all():
		if b.def.category == BuildingDef.Category.HOUSING and _gs.upgrade_error(b).is_empty():
			return _gs.upgrade(b.anchor)
	return false


func _count(id: StringName) -> int:
	return _gs.buildings.all().filter(func(b: Building) -> bool: return b.def.id == id).size()


func _has(id: StringName) -> bool:
	return _gs.buildings.all().any(func(b: Building) -> bool: return b.def.id == id)
