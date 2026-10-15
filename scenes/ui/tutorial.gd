extends CanvasLayer
## Tutoriel pas à pas (H pour afficher ou masquer) : chaque étape décrit une
## action et passe d'elle-même quand la condition est remplie ; les étapes
## d'explication avancent par le bouton « Suivant ».

## Une étape : titre, texte (BBCode) et condition (vide : bouton Suivant).
class Step:
	var title := ""
	var text := ""
	var done: Callable

	func _init(p_title: String, p_text: String, p_done: Callable = Callable()) -> void:
		title = p_title
		text = p_text
		done = p_done


const CHECK_INTERVAL := 0.25
const DONE_COLOR := Color("4caf50")

var _steps: Array[Step] = []
var _index := 0
var _stats_opened := false
var _dismissed := false
var _elapsed := 0.0
var _panel: PanelContainer
var _title: Label
var _body: RichTextLabel
var _next: Button
var _skip: Button
var _back: Button


func _ready() -> void:
	layer = 1
	_steps = _make_steps()
	_build()
	EventBus.game_started.connect(func(_s: int) -> void:
		_index = 0
		_stats_opened = false
		_panel.visible = not _dismissed
		_show_step())
	_show_step()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("tutorial"):
		_panel.visible = not _panel.visible
		_dismissed = not _panel.visible
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	var stats := get_node_or_null("../StatsWindow")
	if stats and stats.is_open():
		_stats_opened = true
	_elapsed += delta
	if not _panel.visible or _elapsed < CHECK_INTERVAL:
		return
	_elapsed = 0.0
	var step := _steps[_index]
	if step.done.is_valid() and step.done.call():
		_advance()


func _make_steps() -> Array[Step]:
	return [
		Step.new("Bienvenue", "Vous dirigez une compagnie d'électricité : produire, transporter, vendre aux villes, puis rechercher de meilleures technologies.\n\n[b]Caméra[/b] : ZQSD ou flèches, glisser avec le clic droit, molette pour zoomer.\n[b]Temps[/b] : Espace pour la pause, 1 / 2 / 3 pour les vitesses.\n\nMettez le jeu en pause pendant que vous construisez."),
		Step.new("Couper du bois", "Dans le menu [b]Construction[/b] à gauche, choisissez [b]Bûcheron[/b] (Ressources) et placez-le à côté d'une forêt : il coupe le bois à 2 tuiles.\n\nLe fantôme est vert quand le placement est valide ; sinon le motif s'affiche en bas.",
			_has_lumberjack),
		Step.new("Brûler le bois", "Placez une [b]Centrale biomasse[/b] (Énergie) non loin du bûcheron : elle transforme le bois en électricité.",
			_has_biomass_plant),
		Step.new("Transporter", "Les marchandises voyagent par la route. Placez un [b]Dépôt de véhicules[/b] (Logistique) : il arrive avec deux charrettes. Tracez ensuite des [b]routes[/b] (bouton Route, glisser) reliant bûcheron, dépôt et centrale.",
			_has_depot_and_road),
		Step.new("Premières livraisons", "Les charrettes vont chercher le bois et le livrent à la centrale. Accélérez le temps et attendez la première livraison.\n\nUn clic sur un bâtiment ouvre son panneau : état, stocks et diagnostic du transport.",
			_wood_delivered),
		Step.new("Alimenter une ville", "Tracez une [b]ligne électrique[/b] (bouton Ligne HT, glisser) de la centrale jusqu'à une ville. Chaque MWh livré est vendu ; une ville privée de courant coûte des pénalités et perd en satisfaction.\n\nLe calque [b]Réseau[/b] (O) montre ce qui est alimenté.",
			_city_served),
		Step.new("Rechercher", "Ouvrez l'[b]arbre technologique[/b] (T) et choisissez une technologie. Les points de recherche viennent des [b]laboratoires[/b] : construisez-en un, raccordé au réseau (il consomme de l'électricité).",
			_researching),
		Step.new("Suivre la partie", "Le bandeau résume la trésorerie, le réseau et le bilan d'hier : survolez-les pour le détail. La fenêtre [b]Statistiques[/b] (G) trace l'historique et liste les jalons. Ouvrez-la.",
			func() -> bool: return _stats_opened),
		Step.new("À vous de jouer", "La demande des villes croît chaque année et varie avec l'heure et la saison. Charbon et nucléaire produisent beaucoup, mais polluent ou demandent des précautions ; éolien et solaire dépendent de la météo, le stockage lisse leur production. Taxe carbone, subventions, tempêtes et sécheresses pèsent sur vos comptes.\n\nPas de victoire imposée : visez les jalons, jusqu'à la fusion. H rouvre ce tutoriel."),
	]


func _has(id: StringName) -> bool:
	return GameState.buildings.all().any(func(b: Building) -> bool: return b.def.id == id)


func _has_lumberjack() -> bool:
	return _has(&"lumberjack")


func _has_biomass_plant() -> bool:
	return _has(&"biomass_plant")


func _has_depot_and_road() -> bool:
	return GameState.roads.tile_count() > 0 \
		and GameState.buildings.all().any(func(b: Building) -> bool: return b.def.is_road_depot())


func _wood_delivered() -> bool:
	return GameState.buildings.all().any(func(b: Building) -> bool:
		return b.def.id == &"biomass_plant" and b.input_stock > 0.0)


func _city_served() -> bool:
	return GameState.cities.any(func(c: Building) -> bool: return c.city.supply == City.Supply.SERVED)


func _researching() -> bool:
	return GameState.research.current() != null


func _build() -> void:
	_panel = PanelContainer.new()
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.offset_left = -270.0
	_panel.offset_right = 270.0
	_panel.offset_top = 60.0
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.1, 0.11, 0.13, 0.94)
	bg.border_color = Color("f2d14b")
	bg.set_border_width_all(0)
	bg.border_width_left = 4
	bg.set_corner_radius_all(6)
	_panel.add_theme_stylebox_override("panel", bg)
	add_child(_panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	_panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(_title)
	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.fit_content = true
	_body.scroll_active = false
	_body.custom_minimum_size = Vector2(516, 0)
	vbox.add_child(_body)
	var row := HBoxContainer.new()
	vbox.add_child(row)
	_back = Button.new()
	_back.text = "◀ Précédent"
	_back.focus_mode = Control.FOCUS_NONE
	_back.pressed.connect(func() -> void:
		_index = maxi(0, _index - 1)
		_show_step())
	row.add_child(_back)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	_skip = Button.new()
	_skip.text = "Masquer (H)"
	_skip.focus_mode = Control.FOCUS_NONE
	_skip.pressed.connect(func() -> void:
		_panel.hide()
		_dismissed = true)
	row.add_child(_skip)
	_next = Button.new()
	_next.focus_mode = Control.FOCUS_NONE
	_next.pressed.connect(_advance)
	row.add_child(_next)


func _advance() -> void:
	if _index >= _steps.size() - 1:
		_panel.hide()
		_dismissed = true
		return
	_index += 1
	_show_step()


func _show_step() -> void:
	var step := _steps[_index]
	_title.text = "Tutoriel %d/%d — %s" % [_index + 1, _steps.size(), step.title]
	_body.text = step.text
	if step.done.is_valid():
		_body.text += "\n\n[color=#8b8f99]Passe à la suite dès que c'est fait.[/color]"
	_back.disabled = _index == 0
	_next.text = "Terminer" if _index == _steps.size() - 1 else ("Suivant ▶" if not step.done.is_valid() else "Passer ▶")
	_panel.reset_size()
