extends Node
## Bus de signaux global : la simulation publie, le rendu et l'UI écoutent.

## Émis à chaque tick de simulation (1 tick = 1 heure de jeu).
signal tick_advanced(tick: int)
signal day_changed(day_index: int)
signal season_changed(season: int, year: int)
signal speed_changed(speed: int)
signal money_changed(money: int)
signal game_started(seed: int)
