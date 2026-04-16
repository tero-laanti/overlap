@tool
class_name TrackTileDefinition
extends Resource

const TrackDirectionRef := preload("res://track/track_direction.gd")

var _display_name: String = ""
var _entry_direction: int = TrackDirectionRef.Heading.W
var _exit_direction: int = TrackDirectionRef.Heading.E
var _footprint: Vector2i = Vector2i.ONE
var _center_feature_tag: StringName = &""
var _interior_points: PackedVector3Array = PackedVector3Array()

@export var display_name: String:
	get:
		return _display_name
	set(value):
		_display_name = value
		emit_changed()
@export_enum("N:0", "NE:1", "E:2", "SE:3", "S:4", "SW:5", "W:6", "NW:7") var entry_direction: int:
	get:
		return _entry_direction
	set(value):
		_entry_direction = value
		emit_changed()
@export_enum("N:0", "NE:1", "E:2", "SE:3", "S:4", "SW:5", "W:6", "NW:7") var exit_direction: int:
	get:
		return _exit_direction
	set(value):
		_exit_direction = value
		emit_changed()
@export var footprint: Vector2i:
	get:
		return _footprint
	set(value):
		_footprint = value
		emit_changed()
@export var center_feature_tag: StringName:
	get:
		return _center_feature_tag
	set(value):
		_center_feature_tag = value
		emit_changed()
@export var interior_points: PackedVector3Array:
	get:
		return _interior_points
	set(value):
		_interior_points = value
		emit_changed()


func get_entry_direction(rotation_steps: int = 0, reverse_path: bool = false) -> int:
	var rotated_entry_direction: int = TrackDirectionRef.rotate(entry_direction, rotation_steps)
	var rotated_exit_direction: int = TrackDirectionRef.rotate(exit_direction, rotation_steps)
	return rotated_exit_direction if reverse_path else rotated_entry_direction


func get_exit_direction(rotation_steps: int = 0, reverse_path: bool = false) -> int:
	var rotated_entry_direction: int = TrackDirectionRef.rotate(entry_direction, rotation_steps)
	var rotated_exit_direction: int = TrackDirectionRef.rotate(exit_direction, rotation_steps)
	return rotated_entry_direction if reverse_path else rotated_exit_direction


func get_local_points(reverse_path: bool = false) -> PackedVector3Array:
	var local_points: PackedVector3Array = PackedVector3Array()
	local_points.append(TrackDirectionRef.get_boundary_point(entry_direction))
	for interior_point in interior_points:
		local_points.append(interior_point)
	local_points.append(TrackDirectionRef.get_boundary_point(exit_direction))

	if not reverse_path:
		return local_points

	var reversed_points: PackedVector3Array = PackedVector3Array()
	for point_index in range(local_points.size() - 1, -1, -1):
		reversed_points.append(local_points[point_index])
	return reversed_points


func get_world_points(
	tile_size: float,
	grid_position: Vector2i,
	rotation_steps: int = 0,
	reverse_path: bool = false
) -> Array[Vector3]:
	var world_points: Array[Vector3] = []
	var rotation_angle: float = deg_to_rad(float(-TrackDirectionRef.wrap_direction(rotation_steps)) * 45.0)
	var rotation_basis: Basis = Basis(Vector3.UP, rotation_angle)
	var tile_origin: Vector3 = Vector3(grid_position.x * tile_size, 0.0, grid_position.y * tile_size)

	for local_point in get_local_points(reverse_path):
		var scaled_point: Vector3 = Vector3(local_point.x * tile_size, local_point.y, local_point.z * tile_size)
		world_points.append(tile_origin + rotation_basis * scaled_point)

	return world_points
