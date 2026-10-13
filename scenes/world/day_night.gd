class_name DayNight
extends CanvasModulate
## Teinte du monde selon la lumière du jour : bleutée la nuit, claire le jour
## (l'interface, sur ses propres calques, n'est pas teintée).

const NIGHT_COLOR := Color(0.6, 0.65, 0.85)
## Lumière du jour à partir de laquelle la teinte disparaît.
const FULL_LIGHT := 0.3


func _process(_delta: float) -> void:
	var tick := GameClock.tick
	var light := lerpf(Weather.daylight_at(tick), Weather.daylight_at(tick + 1), GameClock.get_alpha())
	color = NIGHT_COLOR.lerp(Color.WHITE, clampf(light / FULL_LIGHT, 0.0, 1.0))
