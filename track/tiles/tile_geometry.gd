@tool
class_name TileGeometry
extends Node3D

## Builds the primitive visuals and collider for one authored track tile:
## road ribbon, sand shoulders on either side, and a centerline marking —
## all driven by the tile's own `interior_points` polyline. Each tile
## scene attaches this script to its root Node3D; `TestTrack._instance_tiles`
## passes `definition`, `tile_size`, `rotation_steps`, and `reverse_path`
## from the layout before the scene enters the tree so `_ready` builds
## already-oriented geometry — no per-frame transform needed.
##
## The tile does not generate walls. Off-track containment is handled
## elsewhere: the grass `SurfaceProfile` slows the car past the drivable
## band, the lap tracker's mid-lap virtual checkpoint rejects any lap
## that cuts across the infield, and placed `WallBarrier` hazards stand
## in where a specific track section needs a hard blocker.

const TrackTileDefinitionResource := preload("res://track/track_tile_definition.gd")
const TrackDirectionRef := preload("res://track/track_direction.gd")
const TrackCurveRef := preload("res://track/track_curve.gd")

## Must stay in sync with `TestTrack.track_width`: the physics surface
## profile query returns `tarmac_surface` inside this band.
const TRACK_WIDTH: float = 12.0
## Must stay in sync with `TestTrack.sand_width`: the physics surface
## profile query returns `sand_surface` in this band past the tarmac edge.
const SAND_WIDTH: float = 8.0
const CURVE_SAMPLE_SPACING: float = 2.5
const ROAD_VISUAL_Y_OFFSET: float = 0.001
const MARKING_WIDTH: float = 0.4
const MARKING_Y_OFFSET: float = 0.02

const TARMAC_COLOR: Color = Color(0.2, 0.2, 0.25)
const SAND_COLOR: Color = Color(0.76, 0.7, 0.5)
const MARKING_COLOR: Color = Color(0.95, 0.95, 0.95)

const TRACK_SURFACE_COLLISION_LAYER: int = 3

@export var definition: TrackTileDefinitionResource = null
@export var tile_size: float = 36.0
@export_range(0, 7, 1) var rotation_steps: int = 0
@export var reverse_path: bool = false


func _ready() -> void:
	if definition == null:
		return

	var sampled_points: Array[Vector3] = build_sampled_path(definition, tile_size, rotation_steps, reverse_path)
	if sampled_points.size() < 2:
		return

	var endpoint_tangents: Array[Vector3] = get_endpoint_tangents(definition, rotation_steps, reverse_path)
	_build_road(sampled_points, endpoint_tangents[0], endpoint_tangents[1])
	_build_sand_strips(sampled_points, endpoint_tangents[0], endpoint_tangents[1])
	_build_center_marking(sampled_points, endpoint_tangents[0], endpoint_tangents[1])


## Curved tiles are authored as sparse control points. Resample them into a
## denser Hermite curve before building ribbons so broad corners read as
## continuous arcs instead of a handful of straight segments.
static func build_sampled_path(
	tile_definition: TrackTileDefinitionResource,
	target_tile_size: float,
	target_rotation_steps: int = 0,
	target_reverse_path: bool = false
) -> Array[Vector3]:
	if tile_definition == null:
		return []

	var world_points: Array[Vector3] = tile_definition.get_world_points(
		target_tile_size,
		Vector2i.ZERO,
		target_rotation_steps,
		target_reverse_path
	)
	if world_points.size() < 2:
		return world_points

	var endpoint_tangents: Array[Vector3] = get_endpoint_tangents(
		tile_definition,
		target_rotation_steps,
		target_reverse_path
	)
	return TrackCurveRef.build_smoothed_path(
		world_points,
		false,
		CURVE_SAMPLE_SPACING,
		endpoint_tangents[0],
		endpoint_tangents[1]
	)


static func get_endpoint_tangents(
	tile_definition: TrackTileDefinitionResource,
	target_rotation_steps: int = 0,
	target_reverse_path: bool = false
) -> Array[Vector3]:
	if tile_definition == null:
		return [Vector3.ZERO, Vector3.ZERO]

	var entry_direction: int = tile_definition.get_entry_direction(target_rotation_steps, target_reverse_path)
	var exit_direction: int = tile_definition.get_exit_direction(target_rotation_steps, target_reverse_path)
	return [
		_socket_tangent_inward(entry_direction),
		_socket_tangent_outward(exit_direction),
	]


static func build_offset_polyline(
	points: Array[Vector3],
	offset: float,
	start_tangent: Vector3 = Vector3.ZERO,
	end_tangent: Vector3 = Vector3.ZERO
) -> Array[Vector3]:
	return TrackCurveRef.build_offset_path(points, offset, false, start_tangent, end_tangent)


## Tangent pointing INTO the cell at an entry socket. The boundary point
## sits on the cell edge in the socket's direction; the tangent inward
## is the negated and normalised boundary vector.
static func _socket_tangent_inward(direction: int) -> Vector3:
	var boundary: Vector3 = TrackDirectionRef.get_boundary_point(direction)
	boundary.y = 0.0
	if boundary.length_squared() < 0.0001:
		return Vector3(1.0, 0.0, 0.0)
	return -boundary.normalized()


## Tangent pointing OUT of the cell at an exit socket. Points in the
## direction the car is moving as it leaves, so the successor tile's
## entry tangent (computed as inward from its own socket) matches when
## the sockets are mirrored (exit direction == opposite of next entry).
static func _socket_tangent_outward(direction: int) -> Vector3:
	var boundary: Vector3 = TrackDirectionRef.get_boundary_point(direction)
	boundary.y = 0.0
	if boundary.length_squared() < 0.0001:
		return Vector3(1.0, 0.0, 0.0)
	return boundary.normalized()


func _build_road(points: Array[Vector3], start_tangent: Vector3, end_tangent: Vector3) -> void:
	var right_edge: Array[Vector3] = build_offset_polyline(points, TRACK_WIDTH * 0.5, start_tangent, end_tangent)
	var left_edge: Array[Vector3] = build_offset_polyline(points, -TRACK_WIDTH * 0.5, start_tangent, end_tangent)
	var visual_mesh: ArrayMesh = _build_strip_mesh(right_edge, left_edge, ROAD_VISUAL_Y_OFFSET)
	var collider_mesh: ArrayMesh = _build_strip_mesh(right_edge, left_edge, 0.0)
	_add_visual_ribbon("RoadVisual", visual_mesh, TARMAC_COLOR)
	_add_trimesh_collider("RoadCollider", collider_mesh, 1 << (TRACK_SURFACE_COLLISION_LAYER - 1))


func _build_sand_strips(points: Array[Vector3], start_tangent: Vector3, end_tangent: Vector3) -> void:
	var inner: float = TRACK_WIDTH * 0.5
	var outer: float = inner + SAND_WIDTH
	var sand_right: Array[Vector3] = build_offset_polyline(points, outer, start_tangent, end_tangent)
	var road_right: Array[Vector3] = build_offset_polyline(points, inner, start_tangent, end_tangent)
	var road_left: Array[Vector3] = build_offset_polyline(points, -inner, start_tangent, end_tangent)
	var sand_left: Array[Vector3] = build_offset_polyline(points, -outer, start_tangent, end_tangent)
	var right_mesh: ArrayMesh = _build_strip_mesh(sand_right, road_right, 0.0)
	var left_mesh: ArrayMesh = _build_strip_mesh(road_left, sand_left, 0.0)
	_add_visual_ribbon("SandRight", right_mesh, SAND_COLOR)
	_add_visual_ribbon("SandLeft", left_mesh, SAND_COLOR)


func _build_center_marking(points: Array[Vector3], start_tangent: Vector3, end_tangent: Vector3) -> void:
	var right_edge: Array[Vector3] = build_offset_polyline(points, MARKING_WIDTH * 0.5, start_tangent, end_tangent)
	var left_edge: Array[Vector3] = build_offset_polyline(points, -MARKING_WIDTH * 0.5, start_tangent, end_tangent)
	var mesh: ArrayMesh = _build_strip_mesh(right_edge, left_edge, MARKING_Y_OFFSET)
	_add_visual_ribbon("CenterMarking", mesh, MARKING_COLOR)


func _build_strip_mesh(
	side_a_points: Array[Vector3],
	side_b_points: Array[Vector3],
	y_offset: float
) -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)

	var point_count: int = mini(side_a_points.size(), side_b_points.size())
	for i in range(point_count - 1):
		var a: Vector3 = side_a_points[i] + Vector3.UP * y_offset
		var b: Vector3 = side_b_points[i] + Vector3.UP * y_offset
		var c: Vector3 = side_b_points[i + 1] + Vector3.UP * y_offset
		var d: Vector3 = side_a_points[i + 1] + Vector3.UP * y_offset
		st.set_normal(Vector3.UP)
		st.add_vertex(b); st.add_vertex(c); st.add_vertex(d)
		st.add_vertex(b); st.add_vertex(d); st.add_vertex(a)

	return st.commit()


func _add_visual_ribbon(child_name: String, mesh: ArrayMesh, color: Color) -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = child_name
	mi.mesh = mesh
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mi.material_override = mat
	add_child(mi)


func _add_trimesh_collider(collider_name: String, mesh: ArrayMesh, collision_layer: int) -> void:
	var shape: ConcavePolygonShape3D = mesh.create_trimesh_shape()
	if shape == null:
		return
	var body: StaticBody3D = StaticBody3D.new()
	body.name = collider_name
	body.collision_layer = collision_layer
	body.collision_mask = 0
	add_child(body)
	var col: CollisionShape3D = CollisionShape3D.new()
	col.shape = shape
	body.add_child(col)
