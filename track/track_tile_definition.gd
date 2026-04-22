@tool
class_name TrackTileDefinition
extends Resource

const TrackDirectionRef := preload("res://track/track_direction.gd")

@export var display_name: String = ""
## Heading for the entry socket. Stored as an int (0=N, 1=NE, 2=E, ... 7=NW). Any of
## the eight directions is allowed regardless of footprint. Multi-cell tiles may only
## be placed at 90-degree rotation_steps (0/2/4/6) so the footprint stays grid-aligned;
## diagonal intrinsic directions are preserved across those 90-degree rotations.
@export var entry_direction: int = TrackDirectionRef.Heading.W
## Heading for the exit socket. See entry_direction for the encoding.
@export var exit_direction: int = TrackDirectionRef.Heading.E
@export var footprint: Vector2i = Vector2i.ONE
@export var entry_cell: Vector2i = Vector2i.ZERO
@export var exit_cell: Vector2i = Vector2i.ZERO
@export var center_feature_tag: StringName = &""
@export var interior_points: PackedVector3Array = PackedVector3Array()
## Authored 3D tile scene instanced by `TestTrack` at the tile's grid
## position and rotation. When null, the tile contributes a centerline but
## no geometry — useful while only some tiles have been authored. Scenes
## are authored in absolute world units matching the layout's `tile_size`
## (a 1×1 tile at tile_size=36 means the scene covers ±18 on X and Z),
## with the drivable surface's top face at Y=0 and the scene origin on the
## center of the entry-cell.
@export var scene: PackedScene = null


func get_entry_direction(rotation_steps: int = 0, reverse_path: bool = false) -> int:
	var rotated_entry_direction: int = TrackDirectionRef.rotate(entry_direction, rotation_steps)
	var rotated_exit_direction: int = TrackDirectionRef.rotate(exit_direction, rotation_steps)
	return rotated_exit_direction if reverse_path else rotated_entry_direction


func get_exit_direction(rotation_steps: int = 0, reverse_path: bool = false) -> int:
	var rotated_entry_direction: int = TrackDirectionRef.rotate(entry_direction, rotation_steps)
	var rotated_exit_direction: int = TrackDirectionRef.rotate(exit_direction, rotation_steps)
	return rotated_entry_direction if reverse_path else rotated_exit_direction


func get_entry_cell(rotation_steps: int = 0, reverse_path: bool = false) -> Vector2i:
	var base_cell: Vector2i = exit_cell if reverse_path else entry_cell
	if not supports_rotation(rotation_steps):
		return base_cell
	return _rotate_cell(base_cell, rotation_steps)


func get_exit_cell(rotation_steps: int = 0, reverse_path: bool = false) -> Vector2i:
	var base_cell: Vector2i = entry_cell if reverse_path else exit_cell
	if not supports_rotation(rotation_steps):
		return base_cell
	return _rotate_cell(base_cell, rotation_steps)


func get_rotated_footprint(rotation_steps: int = 0) -> Vector2i:
	var sanitized_footprint: Vector2i = get_sanitized_footprint()
	if sanitized_footprint == Vector2i.ONE:
		return sanitized_footprint

	var normalized_steps: int = TrackDirectionRef.wrap_direction(rotation_steps)
	if normalized_steps % 2 != 0:
		return sanitized_footprint

	var quarter_turns: int = _get_quarter_turns(normalized_steps)
	return sanitized_footprint if quarter_turns % 2 == 0 else Vector2i(sanitized_footprint.y, sanitized_footprint.x)


func get_occupied_cells(rotation_steps: int = 0) -> Array[Vector2i]:
	var occupied_cells: Array[Vector2i] = []
	var sanitized_footprint: Vector2i = get_sanitized_footprint()
	if not supports_rotation(rotation_steps):
		return occupied_cells

	for y in range(sanitized_footprint.y):
		for x in range(sanitized_footprint.x):
			occupied_cells.append(_rotate_cell(Vector2i(x, y), rotation_steps))

	return occupied_cells


func get_configuration_issues(rotation_steps: int = 0) -> PackedStringArray:
	var issues: PackedStringArray = PackedStringArray()
	var sanitized_footprint: Vector2i = get_sanitized_footprint()

	if footprint.x < 1 or footprint.y < 1:
		issues.append("Footprint must be at least 1x1.")

	if not _is_cell_inside(entry_cell, sanitized_footprint):
		issues.append("Entry cell %s is outside the %s footprint." % [entry_cell, sanitized_footprint])

	if not _is_cell_inside(exit_cell, sanitized_footprint):
		issues.append("Exit cell %s is outside the %s footprint." % [exit_cell, sanitized_footprint])

	if sanitized_footprint != Vector2i.ONE and TrackDirectionRef.wrap_direction(rotation_steps) % 2 != 0:
		issues.append("Multi-cell footprints only support 90-degree rotation steps.")

	return issues


func get_sanitized_footprint() -> Vector2i:
	return Vector2i(maxi(footprint.x, 1), maxi(footprint.y, 1))


func supports_rotation(rotation_steps: int) -> bool:
	return get_sanitized_footprint() == Vector2i.ONE or TrackDirectionRef.wrap_direction(rotation_steps) % 2 == 0


func get_local_points(reverse_path: bool = false) -> PackedVector3Array:
	var local_points: PackedVector3Array = PackedVector3Array()
	local_points.append(_get_socket_local_point(entry_cell, entry_direction))
	for interior_point in interior_points:
		local_points.append(interior_point)
	local_points.append(_get_socket_local_point(exit_cell, exit_direction))

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
	var tile_origin: Vector3 = Vector3(grid_position.x * tile_size, 0.0, grid_position.y * tile_size)

	for local_point in get_local_points(reverse_path):
		var rotated_point: Vector3 = _rotate_local_point(local_point, rotation_steps)
		var scaled_point: Vector3 = Vector3(rotated_point.x * tile_size, rotated_point.y, rotated_point.z * tile_size)
		world_points.append(tile_origin + scaled_point)

	return world_points


func _get_socket_local_point(socket_cell: Vector2i, direction: int) -> Vector3:
	var cell_origin: Vector3 = Vector3(socket_cell.x, 0.0, socket_cell.y)
	return cell_origin + TrackDirectionRef.get_boundary_point(direction)


func _rotate_local_point(point: Vector3, rotation_steps: int) -> Vector3:
	var normalized_steps: int = TrackDirectionRef.wrap_direction(rotation_steps)
	if get_sanitized_footprint() == Vector2i.ONE:
		var rotation_angle: float = deg_to_rad(float(-normalized_steps) * 45.0)
		return Basis(Vector3.UP, rotation_angle) * point

	if normalized_steps % 2 != 0:
		var unsupported_angle: float = deg_to_rad(float(-normalized_steps) * 45.0)
		return Basis(Vector3.UP, unsupported_angle) * point

	return _rotate_axis_aligned_point(point, normalized_steps)


func _rotate_axis_aligned_point(point: Vector3, rotation_steps: int) -> Vector3:
	var sanitized_footprint: Vector2i = get_sanitized_footprint()
	var quarter_turns: int = _get_quarter_turns(TrackDirectionRef.wrap_direction(rotation_steps))

	match quarter_turns:
		0:
			return point
		1:
			return Vector3(float(sanitized_footprint.y - 1) - point.z, point.y, point.x)
		2:
			return Vector3(float(sanitized_footprint.x - 1) - point.x, point.y, float(sanitized_footprint.y - 1) - point.z)
		3:
			return Vector3(point.z, point.y, float(sanitized_footprint.x - 1) - point.x)
		_:
			return point


func _rotate_cell(cell: Vector2i, rotation_steps: int) -> Vector2i:
	var sanitized_footprint: Vector2i = get_sanitized_footprint()
	var quarter_turns: int = _get_quarter_turns(TrackDirectionRef.wrap_direction(rotation_steps))

	match quarter_turns:
		0:
			return cell
		1:
			return Vector2i(sanitized_footprint.y - 1 - cell.y, cell.x)
		2:
			return Vector2i(sanitized_footprint.x - 1 - cell.x, sanitized_footprint.y - 1 - cell.y)
		3:
			return Vector2i(cell.y, sanitized_footprint.x - 1 - cell.x)
		_:
			return cell


func _is_cell_inside(cell: Vector2i, bounds: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < bounds.x and cell.y < bounds.y


func _get_quarter_turns(normalized_steps: int) -> int:
	return (normalized_steps >> 1) % 4
