extends Control
## Corner minimap, per-island (MAP_DESIGN_V3 §3): the ACTIVE island —
## the one the car is on — fills the map; every other island renders as
## a small coast silhouette clamped to the map edge in its true compass
## direction (the horizon is the ad for the next island). Reads the
## world, never writes: island bounds come from the "island_land"
## group's land polygons, roads from every visible RoadSegment
## centerline (secret roads stay off the map until revealed), gates
## from the "gate" group (pins vanish once bought), you and your ghosts
## as dots. Off-island geometry projects outside the control and is
## clipped. Rebuilds its road cache on a slow timer so reveals show up.

const RoadSegmentScript = preload("res://scenes/track/road_segment.gd")
const CarScript = preload("res://scenes/car/car.gd")
const ShopPacingScript = preload("res://scenes/ui/shop_pacing.gd")

const REBUILD_INTERVAL := 2.0
const BG_COLOR := Color(0.05, 0.07, 0.1, 0.55)
const COAST_COLOR := Color(0.55, 0.8, 0.85, 0.7)
const SILHOUETTE_COLOR := Color(0.55, 0.8, 0.85, 0.35)
const ROAD_COLOR := Color(0.85, 0.86, 0.9, 0.85)
const GATE_COLOR := Color(0.95, 0.55, 0.1, 1.0)
const GHOST_COLOR := Color(0.35, 0.8, 1.0, 0.8)
const CAR_COLOR := Color(0.95, 0.25, 0.2, 1.0)
const MAX_GHOST_DOTS := 40
## View margin around the active island, as a fraction of its short side.
const WORLD_PADDING := 0.08
## Longest dimension of an off-island silhouette, in map pixels.
const SILHOUETTE_MAX := 18.0
const SILHOUETTE_EDGE_INSET := 14.0

var _world := Rect2()
## Each island's land bounds in world space, tree order (Home first).
var _islands: Array[Rect2] = []
var _active_island := 0
## Each entry: {"line": PackedVector2Array (WORLD points), "alpha":
## float} — projected at draw time so island switches need no rebuild;
## preview (faded) roads draw as faintly on the map as in the world.
var _roads: Array[Dictionary] = []
var _rebuild_timer := 0.0
var _track: Node2D
var _car: CarScript


func _ready() -> void:
	clip_contents = true
	_track = get_tree().get_first_node_in_group("track")
	if _track == null:
		visible = false
		return
	for land in get_tree().get_nodes_in_group("island_land"):
		var poly: Polygon2D = land
		var island := Rect2(poly.polygon[0], Vector2.ZERO)
		for point in poly.polygon:
			island = island.expand(point)
		_islands.append(island)
	if _islands.is_empty():
		visible = false
		return
	_apply_active(0)
	# Deferred so the first build runs after TrackReveal's deferred sync
	# (also queued at ready, earlier in the tree) hides locked annexes.
	_rebuild_roads.call_deferred()
	Events.gate_purchased.connect(func(_id: String) -> void: _rebuild_roads())
	Events.ghost_hired.connect(func(_count: int) -> void: _rebuild_roads())
	Events.profile_reset.connect(_rebuild_roads)


func _process(delta: float) -> void:
	_rebuild_timer += delta
	if _rebuild_timer >= REBUILD_INTERVAL:
		_rebuild_timer = 0.0
		_rebuild_roads()
	_track_active_island()
	queue_redraw()


## The active island is the one under the car; mid-strait (a jump) it
## simply stays whatever it was — the landing switches it.
func _track_active_island() -> void:
	if _car == null:
		_car = get_tree().get_first_node_in_group("player_car")
		if _car == null:
			return
	for i in _islands.size():
		if i != _active_island and _islands[i].has_point(_car.global_position):
			_apply_active(i)
			return


func _apply_active(index: int) -> void:
	_active_island = index
	var island := _islands[index]
	_world = island.grow(minf(island.size.x, island.size.y) * WORLD_PADDING)
	# Height follows the island's aspect so the map never distorts.
	custom_minimum_size = Vector2(size.x, size.x * _world.size.y / _world.size.x)
	size = custom_minimum_size


func _rebuild_roads() -> void:
	_roads.clear()
	for segment: RoadSegmentScript in _find_segments(_track.get_node("Road")):
		if not segment.is_visible_in_tree() or segment.curve == null:
			continue
		var line := PackedVector2Array()
		for point in segment.curve.tessellate(4, 8.0):
			line.append(segment.to_global(point))
		_roads.append({"line": line, "alpha": segment.modulate.a})


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
	draw_rect(Rect2(_to_map(_islands[_active_island].position),
			_islands[_active_island].size / _world.size * size),
			COAST_COLOR, false, 1.5)
	for i in _islands.size():
		if i != _active_island:
			_draw_silhouette(_islands[i])
	for road in _roads:
		var line: PackedVector2Array = road.line
		if line.size() < 2:
			continue
		var mapped := PackedVector2Array()
		for point in line:
			mapped.append(_to_map(point))
		var color: Color = ROAD_COLOR
		color.a *= road.alpha
		draw_polyline(mapped, color, 2.0)
	# Only the gate currently on sale gets a pin — closed doors farther
	# down the ladder stay off the map.
	var next: Resource = ShopPacingScript.next_gate(Bank)
	if next != null:
		for gate in get_tree().get_nodes_in_group("gate"):
			if gate.visible and gate.gate_id == next.id:
				_draw_dot(gate.global_position, GATE_COLOR, 3.5)
	var ghosts := get_tree().get_nodes_in_group("ghost")
	for i in mini(ghosts.size(), MAX_GHOST_DOTS):
		_draw_dot(ghosts[i].global_position, GHOST_COLOR, 1.5)
	if _car != null:
		_draw_dot(_car.global_position, CAR_COLOR, 3.0)


## A distant island: a tiny aspect-true coast rect clamped to the map
## edge along the true bearing from the active island.
func _draw_silhouette(island: Rect2) -> void:
	var bearing := (island.get_center()
			- _islands[_active_island].get_center()).normalized()
	var center := size / 2.0 + bearing * size.length()
	center = center.clamp(Vector2.ONE * SILHOUETTE_EDGE_INSET,
			size - Vector2.ONE * SILHOUETTE_EDGE_INSET)
	var sil_size := island.size * (SILHOUETTE_MAX / maxf(island.size.x, island.size.y))
	draw_rect(Rect2(center - sil_size / 2.0, sil_size),
			SILHOUETTE_COLOR, false, 1.5)


func _draw_dot(world_pos: Vector2, color: Color, radius: float) -> void:
	draw_circle(_to_map(world_pos), radius, color)
