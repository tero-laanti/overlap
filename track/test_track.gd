@tool
class_name TestTrack
extends Node3D

const TrackLayoutResource := preload("res://track/track_layout.gd")

class ClosestSegmentResult:
	var distance: float
	var segment_index: int
	var segment_t: float

	func _init(new_distance: float = INF, new_segment_index: int = 0, new_segment_t: float = 0.0) -> void:
		distance = new_distance
		segment_index = new_segment_index
		segment_t = new_segment_t


const SURFACE_PROVIDER_GROUP := &"surface_provider"
const GROUND_MARGIN := 24.0

var _starter_layouts: Array[TrackLayoutResource] = []
var _active_starter_layout_index: int = 0

@export_group("Layout")
@export var starter_layouts: Array[TrackLayoutResource]:
	get:
		return _starter_layouts
	set(value):
		_starter_layouts = value
		_refresh_layout_observers()
		_queue_generated_track_rebuild()
@export_range(0, 8, 1) var active_starter_layout_index: int:
	get:
		return _active_starter_layout_index
	set(value):
		_active_starter_layout_index = value
		_queue_generated_track_rebuild()

@export_group("Fallback Oval")
## Oval shape.
@export var semi_major_x: float = 60.0
@export var semi_minor_z: float = 40.0
@export var oval_segments: int = 64

## Track dimensions.
@export var track_width: float = 12.0
@export var sand_width: float = 8.0

## Wall dimensions.
@export var wall_height: float = 1.2
@export var wall_thickness: float = 0.4

@export_group("Surface Profiles")
@export var tarmac_surface: SurfaceProfile = preload("res://track/tarmac_surface.tres")
@export var sand_surface: SurfaceProfile = preload("res://track/sand_surface.tres")
@export var grass_surface: SurfaceProfile = preload("res://track/grass_surface.tres")

@export_group("Lap")
@export_range(0.0, 1.0, 0.01) var lap_start_progress: float = 0.5

const WALL_COLLISION_LAYER := 2
const TARMAC_COLOR := Color(0.20, 0.20, 0.25)
const SAND_COLOR := Color(0.76, 0.70, 0.50)
const GRASS_COLOR := Color(0.30, 0.45, 0.22)
const BARRIER_COLOR := Color(0.60, 0.60, 0.62)
const START_LINE_COLOR := Color(0.95, 0.95, 0.95)
const START_LINE_LENGTH := 0.8
const START_LINE_HEIGHT := 0.04
const START_LINE_Y_OFFSET := 0.03
const TRACK_EDGE_PADDING := 0.6
const PLACEMENT_SURFACE_Y_OFFSET := 0.02
const GENERATED_ROOT_NAME := "GeneratedTrack"
const START_SEGMENT_MAX_TURN_ANGLE := deg_to_rad(10.0)
const START_SEGMENT_SAMPLE_DISTANCE_RATIO := 0.75

var _points: Array[Vector3] = []
var _segment_lengths: Array[float] = []
var _cumulative_lengths: Array[float] = []
var _track_length: float = 0.0
var _resolved_lap_start_progress: float = 0.0
var _generated_root: Node3D = null
var _is_rebuild_queued: bool = false
var _observed_layouts: Array[TrackLayoutResource] = []


func _enter_tree() -> void:
	_refresh_layout_observers()


func _exit_tree() -> void:
	_clear_layout_observers()
	_is_rebuild_queued = false


func _ready() -> void:
	if not is_in_group(SURFACE_PROVIDER_GROUP):
		add_to_group(SURFACE_PROVIDER_GROUP)
	_rebuild_generated_track()


func _build_centerline() -> void:
	var active_layout: TrackLayoutResource = _get_active_layout()
	if active_layout != null:
		_warn_about_layout_issues(active_layout)
		_points = active_layout.build_centerline_points()
		if _points.size() >= 3:
			_rebuild_length_cache()
			return

		push_warning("TestTrack fell back to the oval because the active layout did not produce enough points.")

	_build_fallback_oval_centerline()


func _build_fallback_oval_centerline() -> void:
	_points.clear()
	for i in range(oval_segments):
		var t := float(i) / float(oval_segments) * TAU
		_points.append(Vector3(semi_major_x * cos(t), 0.0, semi_minor_z * sin(t)))
	_rebuild_length_cache()


## Returns the inward-pointing perpendicular at the given centerline index.
func _perp_at(index: int) -> Vector3:
	var n := _points.size()
	var dir := (_points[(index + 1) % n] - _points[(index - 1 + n) % n]).normalized()
	return Vector3(-dir.z, 0.0, dir.x)


func _add_ground() -> void:
	var mi := MeshInstance3D.new()
	mi.name = "Ground"
	var box := BoxMesh.new()
	var bounds: AABB = _get_track_bounds()
	box.size = Vector3(maxf(bounds.size.x, 16.0), 0.1, maxf(bounds.size.z, 16.0))
	mi.mesh = box
	mi.position = Vector3(bounds.position.x + bounds.size.x * 0.5, -0.05, bounds.position.z + bounds.size.z * 0.5)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = GRASS_COLOR
	mi.material_override = mat
	_add_generated_child(mi)


func get_surface_profile_at_position(world_position: Vector3) -> SurfaceProfile:
	if _points.is_empty():
		_build_centerline()

	var point: Vector2 = _get_local_track_point(world_position)
	var distance_to_centerline: float = _get_closest_segment(point).distance
	var track_half_width: float = track_width / 2.0
	var sand_boundary: float = track_half_width + sand_width

	if distance_to_centerline <= track_half_width:
		return tarmac_surface
	if distance_to_centerline <= sand_boundary:
		return sand_surface
	return grass_surface


func get_progress_at_position(world_position: Vector3) -> float:
	if _points.is_empty():
		_build_centerline()
	if is_zero_approx(_track_length):
		return 0.0

	var point: Vector2 = _get_local_track_point(world_position)
	var closest: ClosestSegmentResult = _get_closest_segment(point)
	var distance_along_track: float = _cumulative_lengths[closest.segment_index] + _segment_lengths[closest.segment_index] * closest.segment_t
	return wrapf(distance_along_track / _track_length, 0.0, 1.0)


func get_lap_start_progress() -> float:
	if _points.is_empty():
		_build_centerline()
	return wrapf(_resolved_lap_start_progress, 0.0, 1.0)


func get_track_transform(progress: float, lateral_offset: float = 0.0, y_offset: float = PLACEMENT_SURFACE_Y_OFFSET) -> Transform3D:
	if _points.is_empty():
		_build_centerline()
	if _segment_lengths.is_empty() or is_zero_approx(_track_length):
		return Transform3D(Basis.IDENTITY, to_global(Vector3.UP * y_offset))

	var safe_progress: float = wrapf(progress, 0.0, 1.0)
	var distance_along_track: float = safe_progress * _track_length
	var segment_index: int = _get_segment_index_for_distance(distance_along_track)
	var segment_start_distance: float = _cumulative_lengths[segment_index]
	var segment_length: float = _segment_lengths[segment_index]
	var segment_t: float = 0.0 if is_zero_approx(segment_length) else (distance_along_track - segment_start_distance) / segment_length
	var from: Vector3 = _points[segment_index]
	var to: Vector3 = _points[(segment_index + 1) % _points.size()]
	var tangent: Vector3 = (to - from).normalized()
	var right: Vector3 = Vector3(tangent.z, 0.0, -tangent.x).normalized()
	var local_position: Vector3 = from.lerp(to, segment_t) + right * lateral_offset
	local_position.y = y_offset
	var local_basis: Basis = Basis(right, Vector3.UP, -tangent).orthonormalized()
	return Transform3D(global_basis * local_basis, to_global(local_position))


func get_start_transform(y_offset: float = START_LINE_Y_OFFSET) -> Transform3D:
	return get_track_transform(get_lap_start_progress(), 0.0, y_offset)


func get_max_lateral_offset(clearance: float = 0.0) -> float:
	return maxf(track_width * 0.5 - clearance, 0.0)


func is_track_position_valid(progress: float, lateral_offset: float, clearance: float = 0.0) -> bool:
	if absf(lateral_offset) > get_max_lateral_offset(clearance):
		return false

	var placement_position: Vector3 = get_track_transform(progress, lateral_offset).origin
	return get_surface_profile_at_position(placement_position) == tarmac_surface


## Generates a filled band of given half-width around the centerline.
func _add_ring_mesh(mesh_name: String, half_w: float, y_offset: float, color: Color) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var n := _points.size()
	var y := Vector3.UP * y_offset

	for i in range(n):
		var j := (i + 1) % n
		var p0 := _points[i]
		var p1 := _points[j]
		var n0 := _perp_at(i)
		var n1 := _perp_at(j)

		var a := p0 + n0 * half_w + y
		var b := p0 - n0 * half_w + y
		var c := p1 - n1 * half_w + y
		var d := p1 + n1 * half_w + y

		st.set_normal(Vector3.UP)
		st.add_vertex(b)
		st.add_vertex(c)
		st.add_vertex(d)

		st.set_normal(Vector3.UP)
		st.add_vertex(b)
		st.add_vertex(d)
		st.add_vertex(a)

	var mi := MeshInstance3D.new()
	mi.name = mesh_name
	mi.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mi.material_override = mat
	_add_generated_child(mi)


func _add_start_finish_line() -> void:
	if _segment_lengths.is_empty() or is_zero_approx(_track_length):
		return

	var line := MeshInstance3D.new()
	line.name = "StartFinishLine"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(maxf(track_width - TRACK_EDGE_PADDING, 0.2), START_LINE_HEIGHT, START_LINE_LENGTH)
	line.mesh = mesh
	line.global_transform = get_start_transform()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = START_LINE_COLOR
	line.material_override = mat
	_add_generated_child(line)


func _rebuild_length_cache() -> void:
	_segment_lengths.clear()
	_cumulative_lengths.clear()
	_track_length = 0.0

	for i in range(_points.size()):
		_cumulative_lengths.append(_track_length)
		var next_index: int = (i + 1) % _points.size()
		var segment_length: float = _points[i].distance_to(_points[next_index])
		_segment_lengths.append(segment_length)
		_track_length += segment_length

	_resolved_lap_start_progress = _resolve_lap_start_progress()


func _get_segment_index_for_distance(distance_along_track: float) -> int:
	var wrapped_distance: float = wrapf(distance_along_track, 0.0, _track_length)
	var segment_index: int = _segment_lengths.size() - 1

	for i in range(_segment_lengths.size()):
		var segment_start_distance: float = _cumulative_lengths[i]
		var segment_length: float = _segment_lengths[i]
		if wrapped_distance <= segment_start_distance + segment_length:
			segment_index = i
			break

	return segment_index


func _resolve_lap_start_progress() -> float:
	var requested_progress: float = _get_requested_lap_start_progress()
	if _segment_lengths.is_empty() or is_zero_approx(_track_length):
		return requested_progress

	var preferred_distance: float = wrapf(requested_progress, 0.0, 1.0) * _track_length
	var fallback_segment_index: int = _get_segment_index_for_distance(preferred_distance)
	var best_segment_index: int = _find_best_start_segment(preferred_distance, fallback_segment_index)
	return _get_segment_midpoint_progress(best_segment_index)


func _find_best_start_segment(preferred_distance: float, fallback_segment_index: int) -> int:
	var best_straight_segment_index: int = -1
	var best_straight_distance: float = INF
	var best_straight_length: float = -INF
	var best_fallback_segment_index: int = fallback_segment_index
	var best_fallback_turn_angle: float = INF
	var best_fallback_distance: float = INF
	var best_fallback_length: float = -INF
	var sample_distance: float = minf(_track_length * 0.25, maxf(track_width * START_SEGMENT_SAMPLE_DISTANCE_RATIO, START_LINE_LENGTH * 2.0))

	for segment_index in range(_segment_lengths.size()):
		var segment_length: float = _segment_lengths[segment_index]
		var segment_midpoint_distance: float = _get_segment_midpoint_distance(segment_index)
		var wrapped_distance_to_preferred: float = _get_wrapped_track_distance(segment_midpoint_distance, preferred_distance)
		var local_turn_angle: float = _get_local_turn_angle(segment_midpoint_distance, sample_distance)

		if local_turn_angle <= START_SEGMENT_MAX_TURN_ANGLE:
			var is_better_straight_segment: bool = (
				wrapped_distance_to_preferred < best_straight_distance - 0.001
				or (
					is_equal_approx(wrapped_distance_to_preferred, best_straight_distance)
					and segment_length > best_straight_length
				)
			)
			if is_better_straight_segment:
				best_straight_segment_index = segment_index
				best_straight_distance = wrapped_distance_to_preferred
				best_straight_length = segment_length
			continue

		var is_better_fallback_segment: bool = (
			local_turn_angle < best_fallback_turn_angle - 0.001
			or (
				is_equal_approx(local_turn_angle, best_fallback_turn_angle)
				and wrapped_distance_to_preferred < best_fallback_distance - 0.001
			)
			or (
				is_equal_approx(local_turn_angle, best_fallback_turn_angle)
				and is_equal_approx(wrapped_distance_to_preferred, best_fallback_distance)
				and segment_length > best_fallback_length
			)
		)
		if is_better_fallback_segment:
			best_fallback_segment_index = segment_index
			best_fallback_turn_angle = local_turn_angle
			best_fallback_distance = wrapped_distance_to_preferred
			best_fallback_length = segment_length

	if best_straight_segment_index != -1:
		return best_straight_segment_index
	return best_fallback_segment_index


func _get_segment_midpoint_progress(segment_index: int) -> float:
	if _segment_lengths.is_empty() or is_zero_approx(_track_length):
		return 0.0
	return wrapf(_get_segment_midpoint_distance(segment_index) / _track_length, 0.0, 1.0)


func _get_segment_midpoint_distance(segment_index: int) -> float:
	return _cumulative_lengths[segment_index] + _segment_lengths[segment_index] * 0.5


func _get_local_turn_angle(distance_along_track: float, sample_distance: float) -> float:
	if sample_distance <= 0.0:
		return 0.0

	var before_direction: Vector2 = _get_tangent_direction_2d(distance_along_track - sample_distance)
	var after_direction: Vector2 = _get_tangent_direction_2d(distance_along_track + sample_distance)
	return _get_direction_turn_angle(before_direction, after_direction)


func _get_tangent_direction_2d(distance_along_track: float) -> Vector2:
	var point_count: int = _points.size()
	if point_count == 0:
		return Vector2.ZERO

	var segment_index: int = _get_segment_index_for_distance(distance_along_track)
	var from: Vector3 = _points[segment_index]
	var to: Vector3 = _points[(segment_index + 1) % point_count]
	return Vector2(to.x - from.x, to.z - from.z).normalized()


func _get_direction_turn_angle(from_direction: Vector2, to_direction: Vector2) -> float:
	if from_direction.is_zero_approx() or to_direction.is_zero_approx():
		return 0.0
	return absf(from_direction.angle_to(to_direction))


func _get_wrapped_track_distance(first_distance: float, second_distance: float) -> float:
	var direct_distance: float = absf(first_distance - second_distance)
	return minf(direct_distance, _track_length - direct_distance)


func _get_requested_lap_start_progress() -> float:
	var active_layout: TrackLayoutResource = _get_active_layout()
	if active_layout != null:
		return wrapf(active_layout.lap_start_progress, 0.0, 1.0)
	return wrapf(lap_start_progress, 0.0, 1.0)


func _get_local_track_point(world_position: Vector3) -> Vector2:
	var local_position: Vector3 = to_local(world_position)
	return Vector2(local_position.x, local_position.z)


func _get_closest_segment(point: Vector2) -> ClosestSegmentResult:
	var nearest: ClosestSegmentResult = ClosestSegmentResult.new()
	var point_count: int = _points.size()

	for i in range(point_count):
		var j: int = (i + 1) % point_count
		var from := Vector2(_points[i].x, _points[i].z)
		var to := Vector2(_points[j].x, _points[j].z)
		var segment: Vector2 = to - from
		var length_squared: float = segment.length_squared()
		var segment_t: float = 0.0
		if not is_zero_approx(length_squared):
			segment_t = clampf((point - from).dot(segment) / length_squared, 0.0, 1.0)

		var projected_point: Vector2 = from + segment * segment_t
		var distance: float = point.distance_to(projected_point)
		if distance < nearest.distance:
			nearest.distance = distance
			nearest.segment_index = i
			nearest.segment_t = segment_t

	return nearest


func _add_walls() -> void:
	var boundary := track_width / 2.0 + sand_width
	var n := _points.size()

	for i in range(n):
		var j := (i + 1) % n
		var p0 := _points[i]
		var p1 := _points[j]
		var n0 := _perp_at(i)
		var n1 := _perp_at(j)

		var out0 := p0 - n0 * boundary
		var out1 := p1 - n1 * boundary
		_add_wall("WallOuter_%d" % i, out0, out1)

		var in0 := p0 + n0 * boundary
		var in1 := p1 + n1 * boundary
		_add_wall("WallInner_%d" % i, in0, in1)


func _add_wall(wall_name: String, from: Vector3, to: Vector3) -> void:
	var center := (from + to) / 2.0
	var dir := (to - from)
	var seg_length := dir.length() + 0.5
	dir = dir.normalized()
	var angle := atan2(dir.x, dir.z)

	var body := StaticBody3D.new()
	body.name = wall_name
	body.position = Vector3(center.x, wall_height / 2.0, center.z)
	body.rotation.y = angle
	body.collision_layer = WALL_COLLISION_LAYER
	body.collision_mask = 0
	_add_generated_child(body)

	var shape := BoxShape3D.new()
	shape.size = Vector3(wall_thickness, wall_height, seg_length)
	var col := CollisionShape3D.new()
	col.shape = shape
	body.add_child(col)

	var mesh := BoxMesh.new()
	mesh.size = Vector3(wall_thickness, wall_height, seg_length)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = BARRIER_COLOR
	mi.material_override = mat
	body.add_child(mi)


func _rebuild_generated_track() -> void:
	_clear_generated_track()
	_build_centerline()
	_generated_root = _get_or_create_generated_root()
	_add_ground()
	_add_ring_mesh("SandSurface", track_width / 2.0 + sand_width, 0.005, SAND_COLOR)
	_add_ring_mesh("TrackSurface", track_width / 2.0, 0.01, TARMAC_COLOR)
	_add_start_finish_line()
	_add_walls()


func _clear_generated_track() -> void:
	var existing_generated_root: Node3D = get_node_or_null(GENERATED_ROOT_NAME) as Node3D
	if existing_generated_root != null:
		existing_generated_root.free()

	_generated_root = null


func _get_or_create_generated_root() -> Node3D:
	if is_instance_valid(_generated_root):
		return _generated_root

	_generated_root = get_node_or_null(GENERATED_ROOT_NAME) as Node3D
	if _generated_root != null:
		return _generated_root

	_generated_root = Node3D.new()
	_generated_root.name = GENERATED_ROOT_NAME
	add_child(_generated_root)
	return _generated_root


func _add_generated_child(child: Node) -> void:
	_get_or_create_generated_root().add_child(child)


func _queue_generated_track_rebuild() -> void:
	if not is_inside_tree() or _is_rebuild_queued:
		return

	_is_rebuild_queued = true
	call_deferred("_rebuild_generated_track_deferred")


func _rebuild_generated_track_deferred() -> void:
	_is_rebuild_queued = false
	if not is_inside_tree():
		return

	_rebuild_generated_track()


func _get_active_layout() -> TrackLayoutResource:
	if starter_layouts.is_empty():
		return null

	var safe_index: int = clampi(active_starter_layout_index, 0, starter_layouts.size() - 1)
	return starter_layouts[safe_index]


func get_active_layout() -> TrackLayoutResource:
	return _get_active_layout()


## Swaps the active layout resource and rebuilds the generated geometry
## synchronously so callers can read the new centerline immediately.
func set_active_layout(new_layout: TrackLayoutResource) -> void:
	if starter_layouts.is_empty():
		push_warning("TestTrack.set_active_layout called with no starter_layouts configured.")
		return

	var safe_index: int = clampi(active_starter_layout_index, 0, starter_layouts.size() - 1)
	_starter_layouts[safe_index] = new_layout
	_refresh_layout_observers()
	_rebuild_generated_track()


func _warn_about_layout_issues(layout: TrackLayoutResource) -> void:
	for issue in layout.get_validation_issues():
		push_warning(issue)


func _refresh_layout_observers() -> void:
	_clear_layout_observers()

	for layout in starter_layouts:
		if layout == null or _observed_layouts.has(layout):
			continue

		_observed_layouts.append(layout)
		if not layout.changed.is_connected(_on_layout_resource_changed):
			layout.changed.connect(_on_layout_resource_changed)


func _clear_layout_observers() -> void:
	for layout in _observed_layouts:
		if layout != null and layout.changed.is_connected(_on_layout_resource_changed):
			layout.changed.disconnect(_on_layout_resource_changed)

	_observed_layouts.clear()


func _on_layout_resource_changed() -> void:
	_queue_generated_track_rebuild()


func _get_track_bounds() -> AABB:
	if _points.is_empty():
		return AABB(Vector3(-8.0, -0.05, -8.0), Vector3(16.0, 0.1, 16.0))

	var min_x: float = _points[0].x
	var max_x: float = _points[0].x
	var min_z: float = _points[0].z
	var max_z: float = _points[0].z
	var boundary_padding: float = track_width * 0.5 + sand_width + GROUND_MARGIN

	for point in _points:
		min_x = minf(min_x, point.x)
		max_x = maxf(max_x, point.x)
		min_z = minf(min_z, point.z)
		max_z = maxf(max_z, point.z)

	return AABB(
		Vector3(min_x - boundary_padding, -0.05, min_z - boundary_padding),
		Vector3(
			(max_x - min_x) + boundary_padding * 2.0,
			0.1,
			(max_z - min_z) + boundary_padding * 2.0
		)
	)
