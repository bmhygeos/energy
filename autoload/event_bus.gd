extends Node
## Bus de signaux global : la simulation publie, le rendu et l'UI écoutent.

## Émis à chaque tick de simulation (1 tick = 1 heure de jeu).
signal tick_advanced(tick: int)
signal day_changed(day_index: int)
signal season_changed(season: int, year: int)
signal speed_changed(speed: int)
## Nouvelle partie : la carte (GameState.world_map) vient d'être générée.
signal game_started(seed: int)
## Tuile sous la souris ; (-1, -1) hors de la carte.
signal tile_hovered(cell: Vector2i)
## Tuile sélectionnée au clic ; (-1, -1) pour désélectionner.
signal tile_selected(cell: Vector2i)
signal overlay_changed(mode: int)
## Outil de la souris : BuildTool.Mode, et la définition à construire
## (BuildingDef en mode BUILD) ou à peindre (ZoneDef en mode ZONE), null sinon.
signal tool_changed(mode: int, def: Resource)
## Aperçu du placement sous la souris en mode BUILD (null : aucun).
signal placement_previewed(placement: BuildingRegistry.Placement)
signal building_placed(building: Building)
signal building_completed(building: Building)
signal building_removed(building: Building)
## Le terrain de ces tuiles a changé (défrichement…).
signal tiles_changed(cells: Array[Vector2i])
## Zones peintes ou effacées sur ces tuiles.
signal zones_changed(cells: Array[Vector2i])
## Aperçu de la peinture ou de l'effacement de zones (null : aucun).
signal zone_plan_previewed(plan: ZoneMap.Plan)
## Message bref pour le joueur (erreur de construction…).
signal notified(message: String)
## Jalon du bac à sable atteint (Milestones.Def).
signal milestone_reached(milestone: Milestones.Def)
