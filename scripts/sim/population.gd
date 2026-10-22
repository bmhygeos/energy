class_name Population
extends RefCounted
## Habitants de la cité : nombre, part active et besoins journaliers. Les
## besoins sont calculés ici ; leur consommation sur les stocks, la croissance
## et la famine viennent avec la production (V4). Pure donnée.

## Habitants au départ (palier 1, hameau).
const START := 20
## Part des habitants qui travaille (le reste : enfants, anciens).
const ACTIVE_SHARE := 0.6
## Nourriture (unités) et bois (unités de 10 kg) par habitant et par jour ;
## le bois double en hiver (chauffage).
const FOOD_PER_DAY := 1.0
const WOOD_PER_DAY := 0.2
const WINTER_WOOD_FACTOR := 2.0

var count := START


## Habitants actifs (arrondi inférieur).
func active() -> int:
	return floori(count * ACTIVE_SHARE)


## Nourriture nécessaire par jour (unités).
func food_need() -> float:
	return count * FOOD_PER_DAY


## Bois nécessaire par jour pendant la saison [param season] (unités).
func wood_need(season: int) -> float:
	return count * WOOD_PER_DAY * (WINTER_WOOD_FACTOR if season == GameDate.WINTER else 1.0)
