extends Node2D
## Contours au sol : tuile ou bâtiment survolé et sélectionné, emprise du
## placement en cours, cible de la démolition, rectangle de zones, tracé de
## voie ferrée.

const HOVER_COLOR := Color(1, 1, 1, 0.8)
const SELECT_COLOR := Color("ffd23f")
const VALID_COLOR := Color(0.35, 0.95, 0.4)
const INVALID_COLOR := Color(1.0, 0.3, 0.25)

var hovered := Vector2i(-1, -1)
var selected := Vector2i(-1, -1)
var mode := BuildTool.Mode.SELECT
var placement: BuildingRegistry.Placement
var zone_plan: ZoneMap.Plan
var track_plan: TrackNetwork.Plan


func _ready() -> void:
	EventBus.tile_hovered.connect(func(c: Vector2i) -> void:
		hovered = c
		queue_redraw())
	EventBus.tile_selected.connect(func(c: Vector2i) -> void:
		selected = c
		queue_redraw())
	EventBus.tool_changed.connect(func(m: int, _def: Resource) -> void:
		mode = m as BuildTool.Mode
		queue_redraw())
	EventBus.placement_previewed.connect(func(p: BuildingRegistry.Placement) -> void:
		placement = p
		queue_redraw())
	EventBus.zone_plan_previewed.connect(func(p: ZoneMap.Plan) -> void:
		zone_plan = p
		queue_redraw())
	EventBus.track_plan_previewed.connect(func(p: TrackNetwork.Plan) -> void:
		track_plan = p
		queue_redraw())
	for s: Signal in [EventBus.building_placed, EventBus.building_removed]:
		s.connect(func(_b: Building) -> void: queue_redraw())


func _draw() -> void:
	match mode:
		BuildTool.Mode.BUILD:
			if placement:
				var color := VALID_COLOR if placement.is_valid() else INVALID_COLOR
				var d := Iso.footprint_diamond(placement.def.footprint_origin(placement.anchor),
					placement.def.size)
				draw_colored_polygon(d, color * Color(1, 1, 1, 0.3))
				_outline(d, color, 3.0)
		BuildTool.Mode.RAIL, BuildTool.Mode.ROAD:
			if track_plan:
				for cell in track_plan.cells:
					var color := HOVER_COLOR
					if not track_plan.error.is_empty():
						color = INVALID_COLOR
					elif cell in track_plan.new_cells:
						color = VALID_COLOR
					draw_colored_polygon(Iso.diamond(cell), color * Color(1, 1, 1, 0.3))
					_outline(Iso.diamond(cell), color, 1.5)
		BuildTool.Mode.DEMOLISH:
			var b := _building_at(hovered)
			if b:
				var d := _building_diamond(b)
				draw_colored_polygon(d, INVALID_COLOR * Color(1, 1, 1, 0.35))
				_outline(d, INVALID_COLOR, 3.0)
			elif hovered.x >= 0:
				_outline(Iso.diamond(hovered), INVALID_COLOR * Color(1, 1, 1, 0.6), 2.0)
		BuildTool.Mode.ZONE, BuildTool.Mode.ERASE_ZONE:
			if zone_plan:
				for cell in zone_plan.cells:
					var color := HOVER_COLOR
					if cell in zone_plan.changed:
						color = INVALID_COLOR if zone_plan.def == null else VALID_COLOR
					elif zone_plan.def and not GameState.zones.check_cell(zone_plan.def, cell).is_empty():
						color = INVALID_COLOR * Color(1, 1, 1, 0.5)
					draw_colored_polygon(Iso.diamond(cell), color * Color(1, 1, 1, 0.3))
					_outline(Iso.diamond(cell), color, 1.5)
		_:
			if hovered.x >= 0 and hovered != selected:
				_outline(_shape_at(hovered), HOVER_COLOR, 2.0)
	if selected.x >= 0:
		_outline(_shape_at(selected), SELECT_COLOR, 4.0)


func _building_at(cell: Vector2i) -> Building:
	return GameState.buildings.building_at(cell) if cell.x >= 0 and GameState.buildings else null


func _building_diamond(b: Building) -> PackedVector2Array:
	return Iso.footprint_diamond(b.def.footprint_origin(b.anchor), b.def.size)


## Emprise du bâtiment présent sur [param cell], sinon la tuile seule.
func _shape_at(cell: Vector2i) -> PackedVector2Array:
	var b := _building_at(cell)
	return _building_diamond(b) if b else Iso.diamond(cell)


func _outline(points: PackedVector2Array, color: Color, width: float) -> void:
	var closed := points.duplicate()
	closed.append(points[0])
	draw_polyline(closed, color, width, true)
