@tool
class_name TestTrack
extends Node3D

## Oval shape.
@export var semi_major_x := 60.0
@export var semi_minor_z := 40.0
@export var oval_segments := 64

## Track dimensions.
@export var track_width := 12.0
@export var sand_width := 8.0

## Wall dimensions.
@export var wall_height := 1.2
@export var wall_thickness := 0.4

const WALL_COLLISION_LAYER := 2
const TARMAC_COLOR := Color(0.20, 0.20, 0.25)
const SAND_COLOR := Color(0.76, 0.70, 0.50)
const GRASS_COLOR := Color(0.30, 0.45, 0.22)
const BARRIER_COLOR := Color(0.60, 0.60, 0.62)

var _points: Array[Vector3] = []


func _ready() -> void:
	_build_centerline()
	_add_ground()
	_add_ring_mesh("SandSurface", track_width / 2.0 + sand_width, 0.005, SAND_COLOR)
	_add_ring_mesh("TrackSurface", track_width / 2.0, 0.01, TARMAC_COLOR)
	_add_walls()


func _build_centerline() -> void:
	_points.clear()
	for i in range(oval_segments):
		var t := float(i) / float(oval_segments) * TAU
		_points.append(Vector3(semi_major_x * cos(t), 0.0, semi_minor_z * sin(t)))


## Returns the inward-pointing perpendicular at the given centerline index.
func _perp_at(index: int) -> Vector3:
	var n := _points.size()
	var dir := (_points[(index + 1) % n] - _points[(index - 1 + n) % n]).normalized()
	return Vector3(-dir.z, 0.0, dir.x)


func _add_ground() -> void:
	var mi := MeshInstance3D.new()
	mi.name = "Ground"
	var box := BoxMesh.new()
	box.size = Vector3(200.0, 0.1, 200.0)
	mi.mesh = box
	mi.position = Vector3(0.0, -0.05, 0.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = GRASS_COLOR
	mi.material_override = mat
	add_child(mi)


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
	add_child(mi)


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
	add_child(body)

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
