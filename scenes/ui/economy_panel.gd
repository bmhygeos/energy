extends CanvasLayer
## Panneau « Économie » (E), à partir du bourg : trésor, taux d'impôt,
## décrets (rationnement, corvée, fête) et commerce au marché (achat, vente
## par lots, vente automatique des surplus).

const MUTED_COLOR := Color(1, 1, 1, 0.6)
const WARNING_COLOR := Color("ff7a6e")

var _panel: PanelContainer
var _locked: Label
var _content: VBoxContainer
var _treasury: Label
var _tax_buttons: Array[Button] = []
var _tax_summary: Label
var _rationing: CheckBox
var _corvee: CheckBox
var _feast: Button
var _feast_status: Label
var _trade_summary: Label
var _trade_grid: GridContainer
## Par marchandise : étiquettes de stock, boutons et case des surplus.
var _stock_labels: Dictionary[int, Label] = {}
var _sell_buttons: Dictionary[int, Button] = {}
var _buy_buttons: Dictionary[int, Button] = {}
var _auto_boxes: Dictionary[int, CheckBox] = {}
var _trade_cells: Dictionary[int, Array] = {}


func _ready() -> void:
	_build()
	_panel.hide()
	EventBus.economy_changed.connect(_refresh)
	EventBus.stocks_changed.connect(_refresh)
	EventBus.tier_changed.connect(_refresh)
	EventBus.game_started.connect(func(_s: int) -> void: _refresh())


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("economy"):
		toggle()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	_panel.visible = not _panel.visible
	_refresh()


func _build() -> void:
	_panel = PanelContainer.new()
	_panel.anchor_left = 1.0
	_panel.anchor_right = 1.0
	_panel.offset_right = -12.0
	_panel.offset_top = 56.0
	_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_panel.custom_minimum_size = Vector2(500, 0)
	add_child(_panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	_panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)
	var header := HBoxContainer.new()
	box.add_child(header)
	var title := Label.new()
	title.text = "Économie (E)"
	title.add_theme_font_size_override("font_size", 18)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close := Button.new()
	close.text = "×"
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(toggle)
	header.add_child(close)
	_locked = Label.new()
	_locked.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_locked.modulate = MUTED_COLOR
	box.add_child(_locked)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 8)
	box.add_child(_content)
	_treasury = Label.new()
	_content.add_child(_treasury)
	_build_taxes()
	_build_decrees()
	_build_trade()


func _section(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 16)
	_content.add_child(HSeparator.new())
	_content.add_child(label)


func _note(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.modulate = MUTED_COLOR
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 13)
	return label


func _build_taxes() -> void:
	_section("Impôts")
	var row := HBoxContainer.new()
	_content.add_child(row)
	var group := ButtonGroup.new()
	for level in Treasury.TAX_NAMES.size():
		var b := Button.new()
		b.text = Treasury.TAX_NAMES[level]
		b.toggle_mode = true
		b.button_group = group
		b.focus_mode = Control.FOCUS_NONE
		b.tooltip_text = "%s pièce par habitant et par jour%s" % [Format.decimal(Treasury.TAX_PER_INHABITANT[level], 2),
			"" if Treasury.TAX_MOOD[level] >= 1.0 else ", satisfaction −%d %%" % roundi((1.0 - Treasury.TAX_MOOD[level]) * 100.0)]
		b.pressed.connect(func() -> void: GameState.set_tax_level(level))
		row.add_child(b)
		_tax_buttons.append(b)
	_tax_summary = _note("")
	_content.add_child(_tax_summary)


func _build_decrees() -> void:
	_section("Décrets")
	_rationing = CheckBox.new()
	_rationing.text = "Rationnement : nourriture −%d %%, satisfaction −%d %%" % [
		roundi((1.0 - Decrees.RATION_FOOD) * 100.0), roundi((1.0 - Decrees.RATION_MOOD) * 100.0)]
	_rationing.focus_mode = Control.FOCUS_NONE
	_rationing.toggled.connect(func(on: bool) -> void: GameState.set_rationing(on))
	_content.add_child(_rationing)
	_corvee = CheckBox.new()
	_corvee.text = "Corvée : actifs %d %% → %d %% des habitants, satisfaction −%d %%" % [
		roundi(Population.ACTIVE_SHARE * 100.0), roundi((Population.ACTIVE_SHARE + Decrees.CORVEE_ACTIVE) * 100.0),
		roundi((1.0 - Decrees.CORVEE_MOOD) * 100.0)]
	_corvee.focus_mode = Control.FOCUS_NONE
	_corvee.toggled.connect(func(on: bool) -> void: GameState.set_corvee(on))
	_content.add_child(_corvee)
	var row := HBoxContainer.new()
	_content.add_child(row)
	_feast = Button.new()
	_feast.focus_mode = Control.FOCUS_NONE
	_feast.pressed.connect(func() -> void: GameState.hold_feast())
	row.add_child(_feast)
	_feast_status = Label.new()
	_feast_status.modulate = MUTED_COLOR
	row.add_child(_feast_status)
	_content.add_child(_note("La satisfaction du jour est multipliée par l'humeur (impôt et décrets) ; il en faut %d %% pour passer au palier suivant." % roundi(CityTier.SATISFACTION_REQUIRED * 100.0)))


func _build_trade() -> void:
	_section("Commerce")
	_trade_summary = Label.new()
	_trade_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(_trade_summary)
	_trade_grid = GridContainer.new()
	_trade_grid.columns = 6
	_trade_grid.add_theme_constant_override("h_separation", 10)
	_content.add_child(_trade_grid)
	for text in ["Marchandise", "Stock", "Vente", "Achat", "", "Surplus"]:
		var head := Label.new()
		head.text = text
		head.modulate = MUTED_COLOR
		_trade_grid.add_child(head)
	for good in Stockpile.COUNT:
		var cells: Array = []
		var name_label := Label.new()
		name_label.text = Stockpile.GOOD_NAMES[good]
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cells.append(name_label)
		var stock := Label.new()
		_stock_labels[good] = stock
		cells.append(stock)
		var sell_price := Label.new()
		sell_price.text = Format.decimal(Treasury.sell_price(good))
		cells.append(sell_price)
		var buy_price := Label.new()
		buy_price.text = Format.decimal(Treasury.buy_price(good))
		cells.append(buy_price)
		var buttons := HBoxContainer.new()
		var sell := Button.new()
		sell.text = "Vendre %d" % roundi(Treasury.LOT)
		sell.focus_mode = Control.FOCUS_NONE
		sell.pressed.connect(func() -> void: GameState.trade(good, -Treasury.LOT))
		buttons.add_child(sell)
		_sell_buttons[good] = sell
		var buy := Button.new()
		buy.text = "Acheter %d" % roundi(Treasury.LOT)
		buy.focus_mode = Control.FOCUS_NONE
		buy.pressed.connect(func() -> void: GameState.trade(good, Treasury.LOT))
		buttons.add_child(buy)
		_buy_buttons[good] = buy
		cells.append(buttons)
		var auto := CheckBox.new()
		auto.focus_mode = Control.FOCUS_NONE
		auto.tooltip_text = "Vendre chaque jour ce qui dépasse %d %% de la capacité" % roundi(Treasury.AUTO_SELL_RATIO * 100.0)
		auto.toggled.connect(func(on: bool) -> void: GameState.set_auto_sell(good, on))
		cells.append(auto)
		_auto_boxes[good] = auto
		for c: Control in cells:
			_trade_grid.add_child(c)
		_trade_cells[good] = cells
	_content.add_child(_note("Prix en pièces par unité. Les marchands traitent un volume limité par jour (%d par marché), ventes automatiques comprises." % roundi(BuildingDb.get_def(&"market").trade_per_day)))


func _refresh() -> void:
	if not _panel.visible or GameState.treasury == null:
		return
	var error := GameState.economy_error()
	_locked.visible = not error.is_empty()
	_content.visible = error.is_empty()
	if not error.is_empty():
		_locked.text = "%s : impôts, décrets et commerce arrivent avec le bourg." % error
		return
	var treasury := GameState.treasury
	var stats := GameState.stats
	var pop := GameState.population
	_treasury.text = "Trésor : %d pièces  ·  hier : impôts +%s, commerce %s" % [floori(treasury.money),
		Format.decimal(stats.last(&"taxes")), _signed(stats.last(&"trade"))]
	if GameState.upkeep_need() > 0.0:
		_treasury.text += "  ·  entretien −%s /j%s" % [Format.decimal(GameState.upkeep_need()),
			"" if GameState.upkeep_paid else " (impayé)"]
	for level in _tax_buttons.size():
		_tax_buttons[level].set_pressed_no_signal(level == treasury.tax_level)
	_tax_summary.text = "Taux %s : ≈ %s pièces par jour pour %d habitants (moins si la satisfaction baisse)%s" % [
		Treasury.TAX_NAMES[treasury.tax_level].to_lower(), Format.decimal(treasury.taxes_for(pop.count, pop.satisfaction)),
		pop.count, "" if treasury.mood() >= 1.0 else " ; satisfaction ×%s" % Format.decimal(treasury.mood(), 2)]
	var decrees := GameState.decrees
	_rationing.set_pressed_no_signal(decrees.rationing)
	_corvee.set_pressed_no_signal(decrees.corvee)
	_feast.text = "Donner une fête (%d nourriture, %d pièces)" % [roundi(Decrees.feast_food(pop.count)),
		roundi(Decrees.feast_money(pop.count))]
	var feast_error := GameState.feast_error()
	_feast.disabled = not feast_error.is_empty()
	_feast.tooltip_text = feast_error if not feast_error.is_empty() else "Satisfaction +%d %% pendant %d jours, une fête tous les %d jours au plus" % [
		roundi((Decrees.FEAST_MOOD - 1.0) * 100.0), Decrees.FEAST_DAYS, Decrees.FEAST_COOLDOWN_DAYS]
	_feast_status.text = "En fête : encore %d j" % decrees.feast_days_left if decrees.feast_days_left > 0 else ""
	_refresh_trade()


func _refresh_trade() -> void:
	var treasury := GameState.treasury
	var stock := GameState.stockpile
	var error := GameState.trade_error()
	_trade_summary.text = error if not error.is_empty() else "Marchands : %d / %d marchandises échangées aujourd'hui" % [
		roundi(treasury.traded_today), roundi(treasury.trade_capacity)]
	_trade_summary.add_theme_color_override("font_color", WARNING_COLOR if not error.is_empty() else Color.WHITE)
	_trade_grid.visible = error.is_empty()
	if not error.is_empty():
		return
	var left := treasury.trade_left()
	for good in Stockpile.COUNT:
		var shown := stock.capacity[good] > 0.0
		for c: Control in _trade_cells[good]:
			c.visible = shown
		if not shown:
			continue
		_stock_labels[good].text = "%d / %d" % [roundi(stock.amount[good]), roundi(stock.capacity[good])]
		_sell_buttons[good].disabled = left <= 0.0 or stock.amount[good] < 1.0
		_buy_buttons[good].disabled = left <= 0.0 or treasury.money < Treasury.buy_price(good) \
			or stock.amount[good] >= stock.capacity[good] - 0.5
		_auto_boxes[good].set_pressed_no_signal(treasury.auto_sell[good])


static func _signed(value: float) -> String:
	return ("+" if value >= 0.0 else "−") + Format.decimal(absf(value))
