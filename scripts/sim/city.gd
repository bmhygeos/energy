class_name City
extends RefCounted
## Une ville de la cité-État : ses habitants, ses stocks, ses zones, ses
## réseaux et bâtiments du monde, sa carte de ville. GameState travaille sur
## la ville active (ses variables renvoient à celle-ci) et passe d'une ville à
## l'autre à chaque heure et chaque jour. Le palier, la recherche, la météo,
## les événements, les décrets et l'espace sont communs. Pure donnée.

## Identifiant (propriétaire des tuiles du territoire) et nom.
var id := 0
var name := ""
## Centre (abscisse ramenée sur la planète).
var home := Vector2i.ZERO
var exploration: Exploration
var draft: DraftAnimals
var buildings: BuildingRegistry
var city_map: WorldMap
var city_territory: Territory
var city_buildings: BuildingRegistry
var rails: RailNetwork
var roads: RoadNetwork
var ports: PortNetwork
var grid: PowerGrid
var canals: CanalNetwork
var zones: ZoneMap
var population: Population
var labor: Labor
var stockpile: Stockpile
var production: Production
var pollution: Pollution
var housing := 0
var water_supply := 0
var coal_burned_today := 0.0
var fuel_burned_today := 0.0
var wood_burned_today := 0.0
var steam_running := false
var steam_drive := 0.0
var steam_mine := 0.0
var water_drive := 0.0
var needed_today := Stockpile.zeros()
var consumed_today := Stockpile.zeros()
var expedition_origin := 0
## Palier 6 « Cité des étoiles » atteint (la capitale seule).
var star := false
## Couverture des besoins de la veille (statistiques de la cité-État).
var last_coverage: Dictionary[StringName, float] = {}
