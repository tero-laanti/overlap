@tool
class_name TileGeometry
extends Node3D

## Builds the primitive visuals and colliders for one authored track tile:
## road ribbon, sand shoulders, outer walls, and a centerline marking — all
## driven by the tile's own `interior_points` polyline. Each tile scene
## attaches this script to its root Node3D and points `definition` at the
## matching `TrackTileDefinition` resource. `TestTrack._instance_tiles`
## passes `tile_size`, `rotation_steps`, and `reverse_path` from the layout
## before the scene enters the tree so `_ready` builds already-oriented
## geometry — no per-frame transform needed.

const TrackTileDefinitionResource := preload("res://track/track_tile_definition.gd")

## Must stay in sync with `TestTrack.track_width`: the physics surface
## profile query returns `tarmac_surface` inside this band.
const TRACK_WIDTH: float = 12.0
## Must stay in sync with `TestTrack.sand_width`: the physics surface
## profile query returns `sand_surface` in this band past the tarmac edge.
const SAND_WIDTH: float = 8.0
const WALL_HEIGHT: float = 1.2
const WALL_THICKNESS: float = 0.4
const MARKING_WIDTH: float = 0.4
const MARKING_Y_OFFSET: float = 0.02

const TARMAC_COLOR: Color = Color(0.2, 0.2, 0.25)
const SAND_COLOR: Color = Color(0.76, 0.7, 0.5)
const WALL_COLOR: Color = Color(0.6, 0.6, 0.62)
const MARKING_COLOR: Color = Color(0.95, 0.95, 0.95)

const TRACK_SURFACE_COLLISION_LAYER: int = 3
const WALL_COLLISION_LAYER: int = 2

@export var definition: TrackTileDefinitionResource = null
@export var tile_size: float = 36.0
@export_range(0, 7, 1) var rotation_steps: int = 0
@export var reverse_path: bool = false
## When false, the tile skips wall generation. Lets detour shapes that
## should not re-wall the splice point omit them without editing the
## script, and simplifies inspecting colliders in the editor.
@export var include_walls: bool = true


func _ready() -> void:
	if definition == null:
		return

	var world_points: Array[Vector3] = definition.get_world_points(tile_size, Vector2i.ZERO, rotation_steps, reverse_path)
	if world_points.size() < 2:
		return

	_build_road(world_points)
	_build_sand_strips(world_points)
	if include_walls:
		_build_walls(world_points)
	_build_center_marking(world_points)


func _build_road(points: Array[Vector3]) -> void:
	var mesh: ArrayMesh = _build_ribbon_mesh(points, TRACK_WIDTH * 0.5, -TRACK_WIDTH * 0.5, 0.0)
	_add_visual_ribbon("RoadVisual", mesh, TARMAC_COLOR)
	_add_trimesh_collider("RoadCollider", mesh, 1 << (TRACK_SURFACE_COLLISION_LAYER - 1))


func _build_sand_strips(points: Array[Vector3]) -> void:
	var inner: float = TRACK_WIDTH * 0.5
	var outer: float = inner + SAND_WIDTH
	var right_mesh: ArrayMesh = _build_ribbon_mesh(points, outer, inner, 0.0)
	var left_mesh: ArrayMesh = _build_ribbon_mesh(points, -inner, -outer, 0.0)
	_add_visual_ribbon("SandRight", right_mesh, SAND_COLOR)
	_add_visual_ribbon("SandLeft", left_mesh, SAND_COLOR)


func _build_walls(points: Array[Vector3]) -> void:
	var boundary: float = TRACK_WIDTH * 0.5 + SAND_WIDTH
	_build_wall("WallRight", points, boundary)
	_build_wall("WallLeft", points, -boundary)


func _build_wall(wall_name: String, points: Array[Vector3], perp_offset: float) -> void:
	var half_thickness: float = WALL_THICKNESS * 0.5
	var thickness_sign: float = signf(perp_offset)
	var inner_offset: float = perp_offset - thickness_sign * half_thickness
	var outer_offset: float = perp_offset + thickness_sign * half_thickness
	var up_vector: Vector3 = Vector3.UP * WALL_HEIGHT
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)

	for i in range(points.size() - 1):
		var p0: Vector3 = points[i]
		var p1: Vector3 = points[i + 1]
		var perp0: Vector3 = _perpendicular_at(points, i)
		var perp1: Vector3 = _perpendicular_at(points, i + 1)
		var b0_in: Vector3 = p0 + perp0 * inner_offset
		var b0_out: Vector3 = p0 + perp0 * outer_offset
		var b1_in: Vector3 = p1 + perp1 * inner_offset
		var b1_out: Vector3 = p1 + perp1 * outer_offset
		var t0_in: Vector3 = b0_in + up_vector
		var t0_out: Vector3 = b0_out + up_vector
		var t1_in: Vector3 = b1_in + up_vector
		var t1_out: Vector3 = b1_out + up_vector
		_emit_quad(st, b0_in, b1_in, t1_in, t0_in)
		_emit_quad(st, b1_out, b0_out, t0_out, t1_out)
		_emit_quad(st, t0_in, t1_in, t1_out, t0_out)

	st.generate_normals()
	var mesh: ArrayMesh = st.commit()
	_add_visual_ribbon(wall_name + "Visual", mesh, WALL_COLOR)
	_add_trimesh_collider(wall_name, mesh, 1 << (WALL_COLLISION_LAYER - 1))


func _build_center_marking(points: Array[Vector3]) -> void:
	var mesh: ArrayMesh = _build_ribbon_mesh(points, MARKING_WIDTH * 0.5, -MARKING_WIDTH * 0.5, MARKING_Y_OFFSET)
	_add_visual_ribbon("CenterMarking", mesh, MARKING_COLOR)


func _build_ribbon_mesh(points: Array[Vector3], side_a_offset: float, side_b_offset: float, y_offset: float) -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)

	for i in range(points.size() - 1):
		var p0: Vector3 = points[i]
		var p1: Vector3 = points[i + 1]
		var perp0: Vector3 = _perpendicular_at(points, i)
		var perp1: Vector3 = _perpendicular_at(points, i + 1)
		var a: Vector3 = p0 + perp0 * side_a_offset + Vector3.UP * y_offset
		var b: Vector3 = p0 + perp0 * side_b_offset + Vector3.UP * y_offset
		var c: Vector3 = p1 + perp1 * side_b_offset + Vector3.UP * y_offset
		var d: Vector3 = p1 + perp1 * side_a_offset + Vector3.UP * y_offset
		st.set_normal(Vector3.UP)
		st.add_vertex(b); st.add_vertex(c); st.add_vertex(d)
		st.add_vertex(b); st.add_vertex(d); st.add_vertex(a)

	return st.commit()


## Perpendicular (in the XZ plane, pointing to the right side of the
## direction of travel) at the given point. Open polyline: endpoints use
## the first/last segment tangent. Interior points use the neighbor-to-
## neighbor span to average out tangent jumps at corners.
static func _perpendicular_at(points: Array[Vector3], index: int) -> Vector3:
	var n: int = points.size()
	if n < 2:
		return Vector3(0.0, 0.0, 1.0)

	var direction: Vector3
	if index <= 0:
		direction = points[1] - points[0]
	elif index >= n - 1:
		direction = points[n - 1] - points[n - 2]
	else:
		direction = points[index + 1] - points[index - 1]

	direction.y = 0.0
	if direction.length_squared() < 0.0001:
		return Vector3(0.0, 0.0, 1.0)
	direction = direction.normalized()
	return Vector3(-direction.z, 0.0, direction.x)


static func _emit_quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	st.add_vertex(a); st.add_vertex(b); st.add_vertex(c)
	st.add_vertex(a); st.add_vertex(c); st.add_vertex(d)


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
