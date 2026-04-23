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

## Must stay in sync with `TestTrack.track_width`: the physics surface
## profile query returns `tarmac_surface` inside this band.
const TRACK_WIDTH: float = 12.0
## Must stay in sync with `TestTrack.sand_width`: the physics surface
## profile query returns `sand_surface` in this band past the tarmac edge.
const SAND_WIDTH: float = 8.0
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

	var world_points: Array[Vector3] = definition.get_world_points(tile_size, Vector2i.ZERO, rotation_steps, reverse_path)
	if world_points.size() < 2:
		return

	var perpendiculars: Array[Vector3] = _compute_perpendiculars(world_points)
	_build_road(world_points, perpendiculars)
	_build_sand_strips(world_points, perpendiculars)
	_build_center_marking(world_points, perpendiculars)


## Perpendiculars at every polyline point, with the two endpoints forced
## to the cardinal tangent implied by the tile's socket directions. That
## way two tiles sharing a socket (one's exit == opposite of the next's
## entry) land on the exact same perpendicular at the boundary, so road,
## sand, and marking ribbons stitch flush across tiles instead of
## leaving notches at every tile seam.
func _compute_perpendiculars(points: Array[Vector3]) -> Array[Vector3]:
	var result: Array[Vector3] = []
	var n: int = points.size()
	result.resize(n)

	var entry_dir: int = definition.get_entry_direction(rotation_steps, reverse_path)
	var exit_dir: int = definition.get_exit_direction(rotation_steps, reverse_path)
	var entry_tangent: Vector3 = _socket_tangent_inward(entry_dir)
	var exit_tangent: Vector3 = _socket_tangent_outward(exit_dir)

	result[0] = _perpendicular_from_tangent(entry_tangent)
	result[n - 1] = _perpendicular_from_tangent(exit_tangent)

	for i in range(1, n - 1):
		var direction: Vector3 = points[i + 1] - points[i - 1]
		result[i] = _perpendicular_from_tangent(direction)

	return result


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


## Right-hand perpendicular (in XZ) of the given tangent: rotate 90° CW
## from above so the returned vector points to the right side of a car
## moving along `tangent`.
static func _perpendicular_from_tangent(tangent: Vector3) -> Vector3:
	var flat: Vector3 = tangent
	flat.y = 0.0
	if flat.length_squared() < 0.0001:
		return Vector3(0.0, 0.0, 1.0)
	flat = flat.normalized()
	return Vector3(-flat.z, 0.0, flat.x)


func _build_road(points: Array[Vector3], perpendiculars: Array[Vector3]) -> void:
	var mesh: ArrayMesh = _build_ribbon_mesh(points, perpendiculars, TRACK_WIDTH * 0.5, -TRACK_WIDTH * 0.5, 0.0)
	_add_visual_ribbon("RoadVisual", mesh, TARMAC_COLOR)
	_add_trimesh_collider("RoadCollider", mesh, 1 << (TRACK_SURFACE_COLLISION_LAYER - 1))


func _build_sand_strips(points: Array[Vector3], perpendiculars: Array[Vector3]) -> void:
	var inner: float = TRACK_WIDTH * 0.5
	var outer: float = inner + SAND_WIDTH
	var right_mesh: ArrayMesh = _build_ribbon_mesh(points, perpendiculars, outer, inner, 0.0)
	var left_mesh: ArrayMesh = _build_ribbon_mesh(points, perpendiculars, -inner, -outer, 0.0)
	_add_visual_ribbon("SandRight", right_mesh, SAND_COLOR)
	_add_visual_ribbon("SandLeft", left_mesh, SAND_COLOR)


func _build_center_marking(points: Array[Vector3], perpendiculars: Array[Vector3]) -> void:
	var mesh: ArrayMesh = _build_ribbon_mesh(points, perpendiculars, MARKING_WIDTH * 0.5, -MARKING_WIDTH * 0.5, MARKING_Y_OFFSET)
	_add_visual_ribbon("CenterMarking", mesh, MARKING_COLOR)


func _build_ribbon_mesh(points: Array[Vector3], perpendiculars: Array[Vector3], side_a_offset: float, side_b_offset: float, y_offset: float) -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)

	for i in range(points.size() - 1):
		var p0: Vector3 = points[i]
		var p1: Vector3 = points[i + 1]
		var perp0: Vector3 = perpendiculars[i]
		var perp1: Vector3 = perpendiculars[i + 1]
		var a: Vector3 = p0 + perp0 * side_a_offset + Vector3.UP * y_offset
		var b: Vector3 = p0 + perp0 * side_b_offset + Vector3.UP * y_offset
		var c: Vector3 = p1 + perp1 * side_b_offset + Vector3.UP * y_offset
		var d: Vector3 = p1 + perp1 * side_a_offset + Vector3.UP * y_offset
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
