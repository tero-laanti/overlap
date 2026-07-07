extends Control
## Corner minimap. Reads the world, never writes: island bounds come
## from the track's Grass polygon, roads from every visible RoadSegment
## centerline (secret roads stay off the map until revealed), gates from
## the "gate" group (pins vanish once bought), you and your ghosts as
## dots. Rebuilds its road cache on a slow timer so reveals show up.

const RoadSegmentScript = preload("res://scenes/track/road_segment.gd")
const CarScript = preload("res://scenes/car/car.gd")

const REBUILD_INTERVAL := 2.0
const BG_COLOR := Color(0.05, 0.07, 0.1, 0.55)
const COAST_COLOR := Color(0.55, 0.8, 0.85, 0.7)
const ROAD_COLOR := Color(0.85, 0.86, 0.9, 0.85)
const GATE_COLOR := Color(0.95, 0.55, 0.1, 1.0)
const GHOST_COLOR := Color(0.35, 0.8, 1.0, 0.8)
const CAR_COLOR := Color(0.95, 0.25, 0.2, 1.0)
const MAX_GHOST_DOTS := 40

var _world := Rect2()
var _roads: Array[PackedVector2Array] = []
var _rebuild_timer := 0.0
var _track: Node2D
var _car: CarScript


func _ready() -> void:
	_track = get_tree().get_first_node_in_group("track")
	if _track == null:
		visible = false
		return
	var grass: Polygon2D = _track.get_node("Grass")
	var bounds := Rect2(grass.polygon[0], Vector2.ZERO)
	for point in grass.polygon:
		bounds = bounds.expand(point)
	_world = bounds
	# Height follows the island's aspect so the map never distorts.
	custom_minimum_size = Vector2(size.x, size.x * _world.size.y / _world.size.x)
	size = custom_minimum_size
	_rebuild_roads()


func _process(delta: float) -> void:
	_rebuild_timer += delta
	if _rebuild_timer >= REBUILD_INTERVAL:
		_rebuild_timer = 0.0
		_rebuild_roads()
	queue_redraw()


func _rebuild_roads() -> void:
	_roads.clear()
	for segment: RoadSegmentScript in _find_segments(_track.get_node("Road")):
		if not segment.is_visible_in_tree() or segment.curve == null:
			continue
		var line := PackedVector2Array()
		for point in segment.curve.tessellate(4, 8.0):
			line.append(_to_map(segment.to_global(point)))
		_roads.append(line)


func _find_segments(node: Node) -> Array[RoadSegmentScript]:
	var found: Array[RoadSegmentScript] = []
	for child in node.get_children():
		if child is RoadSegmentScript:
			found.append(child)
		else:
			found.append_array(_find_segments(child))
	return found


func _to_map(world_pos: Vector2) -> Vector2:
	return (world_pos - _world.position) / _world.size * size


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BG_COLOR)
	draw_rect(Rect2(Vector2.ZERO, size), COAST_COLOR, false, 1.5)
	for line in _roads:
		if line.size() >= 2:
			draw_polyline(line, ROAD_COLOR, 2.0)
	for gate in get_tree().get_nodes_in_group("gate"):
		if gate.visible:  # purchased gates hide themselves
			_draw_dot(gate.global_position, GATE_COLOR, 3.5)
	var ghosts := get_tree().get_nodes_in_group("ghost")
	for i in mini(ghosts.size(), MAX_GHOST_DOTS):
		_draw_dot(ghosts[i].global_position, GHOST_COLOR, 1.5)
	if _car == null:
		_car = get_tree().get_first_node_in_group("player_car")
	if _car != null:
		_draw_dot(_car.global_position, CAR_COLOR, 3.0)


func _draw_dot(world_pos: Vector2, color: Color, radius: float) -> void:
	draw_circle(_to_map(world_pos), radius, color)
