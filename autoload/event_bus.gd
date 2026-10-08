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
