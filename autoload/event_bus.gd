extends Node
## Bus de signaux global : la simulation publie, le rendu et l'UI écoutent.

## Émis à chaque tick de simulation (1 tick = 1 heure de jeu).
signal tick_advanced(tick: int)
signal day_changed(day_index: int)
signal season_changed(season: int, year: int)
signal speed_changed(speed: int)
signal money_changed(money: int)
## Nouvelle partie : la carte (GameState.world_map) vient d'être générée.
signal game_started(seed: int)
## Tuile sous la souris ; (-1, -1) hors de la carte.
signal tile_hovered(cell: Vector2i)
## Tuile sélectionnée au clic ; (-1, -1) pour désélectionner.
signal tile_selected(cell: Vector2i)
signal overlay_changed(mode: int)
## Outil de la souris : BuildTool.Mode, et la définition à construire en
## mode BUILD (null sinon).
signal tool_changed(mode: int, def: BuildingDef)
## Aperçu du placement sous la souris en mode BUILD (null : aucun).
signal placement_previewed(placement: BuildingRegistry.Placement)
signal building_placed(building: Building)
signal building_completed(building: Building)
signal building_removed(building: Building)
## Le terrain de ces tuiles a changé (défrichement…).
signal tiles_changed(cells: Array[Vector2i])
## Message bref pour le joueur (erreur de construction…).
signal notified(message: String)
## Bilan de l'heure de production écoulée (Production.Report).
signal production_stepped(report: Production.Report)
## Statut d'un bâtiment (Building.Status) modifié.
signal building_status_changed(building: Building)
## Routes construites ou supprimées sur ces tuiles.
signal roads_changed(cells: Array[Vector2i])
signal vehicle_added(vehicle: Vehicle)
signal vehicle_removed(vehicle: Vehicle)
## Aperçu du tracé de route en mode ROAD (null : aucun).
signal road_previewed(plan: RoadNetwork.Plan)
