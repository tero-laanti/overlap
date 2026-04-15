class_name TestTrack
extends Node3D

@export var track_width := 10.0
@export var wall_height := 1.5
@export var wall_thickness := 0.5
@export var wall_overlap := 1.0 ## Extra length on each wall segment to cover corners

## Collision layer for track walls (layer 2).
const WALL_COLLISION_LAYER := 2

## Track centerline (closed loop, hand-authored).
const TRACK_POINTS: Array[Vector3] = [
	Vector3(0, 0, 0),
	Vector3(30, 0, 0),
	Vector3(42, 0, -12),
	Vector3(42, 0, -30),
	Vector3(35, 0, -42),
	Vector3(15, 0, -45),
	Vector3(0, 0, -38),
	Vector3(-8, 0, -25),
	Vector3(-5, 0, -15),
	Vector3(-10, 0, -5),
]


func _ready() -> void:
	_generate_ground()
	_generate_track_surface()
	_generate_walls()
	print("Track ready. Children: ", get_child_count())


func _generate_ground() -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Ground"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(150, 0.1, 150)
	mesh_instance.mesh = mesh
	mesh_instance.position = Vector3(15, -0.05, -22)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.28, 0.38, 0.25)
	mesh_instance.material_override = mat
	add_child(mesh_instance)


func _generate_track_surface() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)

	var half_w := track_width / 2.0
	var n := TRACK_POINTS.size()

	for i in range(n):
		var p0 := TRACK_POINTS[i]
		var p1 := TRACK_POINTS[(i + 1) % n]
		var seg_dir := (p1 - p0).normalized()
		var perp := Vector3(-seg_dir.z, 0.0, seg_dir.x)

		var bl := p0 - perp * half_w
		var br := p0 + perp * half_w
		var tl := p1 - perp * half_w
		var tr := p1 + perp * half_w
		var y := Vector3.UP * 0.01

		st.set_normal(Vector3.UP)
		st.add_vertex(bl + y)
		st.add_vertex(br + y)
		st.add_vertex(tr + y)

		st.set_normal(Vector3.UP)
		st.add_vertex(bl + y)
		st.add_vertex(tr + y)
		st.add_vertex(tl + y)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "TrackSurface"
	mesh_instance.mesh = st.commit()

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.22, 0.22, 0.27)
	mesh_instance.material_override = mat
	add_child(mesh_instance)


func _generate_walls() -> void:
	var half_w := track_width / 2.0
	var n := TRACK_POINTS.size()

	for i in range(n):
		var p0 := TRACK_POINTS[i]
		var p1 := TRACK_POINTS[(i + 1) % n]
		var seg_dir := (p1 - p0).normalized()
		var perp := Vector3(-seg_dir.z, 0.0, seg_dir.x)
		var seg_length := p0.distance_to(p1) + wall_overlap * 2.0
		var center := (p0 + p1) / 2.0
		var angle := atan2(seg_dir.x, seg_dir.z)

		# Left wall (inner)
		_create_wall("Wall_L_%d" % i, center + perp * half_w, angle, seg_length)
		# Right wall (outer)
		_create_wall("Wall_R_%d" % i, center - perp * half_w, angle, seg_length)


func _create_wall(wall_name: String, pos: Vector3, angle: float, length: float) -> void:
	var wall := StaticBody3D.new()
	wall.name = wall_name
	wall.position = Vector3(pos.x, wall_height / 2.0, pos.z)
	wall.rotation.y = angle
	wall.collision_layer = WALL_COLLISION_LAYER
	wall.collision_mask = 0
	add_child(wall)

	var shape := BoxShape3D.new()
	shape.size = Vector3(wall_thickness, wall_height, length)
	var col := CollisionShape3D.new()
	col.shape = shape
	wall.add_child(col)

	var mesh := BoxMesh.new()
	mesh.size = Vector3(wall_thickness, wall_height, length)
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.75, 0.2, 0.15)
	mesh_instance.material_override = mat
	wall.add_child(mesh_instance)
