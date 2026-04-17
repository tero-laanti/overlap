@tool
class_name JumpRamp
extends StaticBody3D

## Kicker ramp on collision layer 3 (`track_surface`). Local convention: car
## approaches from +Z (entry edge is at y=0, z=+length/2) and launches off
## the peak at y=height, z=-length/2. Rotate the instance in the parent scene
## to align with the track's travel direction.
const TRACK_SURFACE_LAYER := 3

@export var length: float = 4.0
@export var width: float = 8.0
@export var height: float = 0.9
@export var color: Color = Color(0.92, 0.58, 0.22)


func _ready() -> void:
	collision_layer = 1 << (TRACK_SURFACE_LAYER - 1)
	collision_mask = 0
	_rebuild()


func _rebuild() -> void:
	for child in get_children():
		child.queue_free()

	var verts: PackedVector3Array = _wedge_vertices()

	var col := CollisionShape3D.new()
	var shape := ConvexPolygonShape3D.new()
	shape.points = verts
	col.shape = shape
	add_child(col)

	var mi := MeshInstance3D.new()
	mi.mesh = _build_mesh(verts)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mi.material_override = mat
	add_child(mi)


func _wedge_vertices() -> PackedVector3Array:
	var hl: float = length * 0.5
	var hw: float = width * 0.5
	return PackedVector3Array([
		Vector3(-hw, 0.0, hl),       # V0 entry-left  (low, +Z)
		Vector3(hw, 0.0, hl),        # V1 entry-right (low, +Z)
		Vector3(-hw, 0.0, -hl),      # V2 back-left   (low, -Z)
		Vector3(hw, 0.0, -hl),       # V3 back-right  (low, -Z)
		Vector3(-hw, height, -hl),   # V4 peak-left   (high, -Z)
		Vector3(hw, height, -hl),    # V5 peak-right  (high, -Z)
	])


func _build_mesh(v: PackedVector3Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	# Underside (-Y)
	_tri(st, v[0], v[3], v[1])
	_tri(st, v[0], v[2], v[3])
	# Back wall (-Z)
	_tri(st, v[2], v[4], v[3])
	_tri(st, v[3], v[4], v[5])
	# Sloped top (+Y,+Z)
	_tri(st, v[0], v[1], v[5])
	_tri(st, v[0], v[5], v[4])
	# Left triangle (-X)
	_tri(st, v[0], v[4], v[2])
	# Right triangle (+X)
	_tri(st, v[1], v[3], v[5])
	st.generate_normals()
	return st.commit()


func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)
