class_name VehicleSprite
extends Node2D
## Véhicule animé sur la route (voie de droite), la voie ferrée ou l'eau :
## position interpolée entre deux ticks, caisse colorée selon le chargement.

## Décalage latéral (voie de droite), en tuiles.
const LANE_OFFSET := 0.1
const WIDTH := 8.0
const HEIGHT := 6.0

var vehicle: Vehicle
var _forward := Vector2(1, 0.5).normalized()


func _process(_delta: float) -> void:
	visible = vehicle.state != Vehicle.State.IDLE
	if not visible:
		return
	var g := vehicle.prev_grid_pos.lerp(vehicle.grid_pos, GameClock.get_alpha())
	var d := vehicle.grid_pos - vehicle.prev_grid_pos
	if d.length_squared() > 0.000001:
		var world_dir := _vec(d)
		_forward = world_dir.normalized()
		d = d.normalized()
		if vehicle.def.network == VehicleDef.Network.ROAD:
			g += Vector2(-d.y, d.x) * LANE_OFFSET
	position = Iso.map_to_world(g)
	queue_redraw()


## Vecteur de grille → vecteur monde.
static func _vec(v: Vector2) -> Vector2:
	return Iso.map_to_world(v) - Iso.map_to_world(Vector2.ZERO)


func _draw() -> void:
	var f := _forward * vehicle.def.length / 2.0
	var water := vehicle.def.network == VehicleDef.Network.WATER
	var s := Vector2(-_forward.y, _forward.x) * WIDTH * (2.0 if water else 1.0) / 2.0
	s.y *= 0.5  # aplatissement isométrique de la largeur
	var up := Vector2(0, -HEIGHT)
	var base := PackedVector2Array([f + s, f - s, -f - s, -f + s])
	if water:
		# Coque à l'étrave en pointe, posée sur l'eau.
		base = PackedVector2Array([f * 1.15, f * 0.7 - s, -f - s, -f + s, f * 0.7 + s])
	draw_colored_polygon(base, Color(0, 0, 0, 0.3))
	var top := PackedVector2Array()
	for p in base:
		top.append(p + up)
	# Flancs puis dessus.
	draw_colored_polygon(PackedVector2Array([base[1], base[2], top[2], top[1]]), vehicle.def.color.darkened(0.35))
	draw_colored_polygon(PackedVector2Array([base[0], base[1], top[1], top[0]]), vehicle.def.color.darkened(0.2))
	draw_colored_polygon(top, vehicle.def.color)
	if vehicle.cargo > 0.0:
		var cargo := PackedVector2Array()
		for p in top:
			cargo.append(p * 0.65 + up * 0.6 - f * 0.25)
		draw_colored_polygon(cargo, Goods.COLORS[vehicle.good])
