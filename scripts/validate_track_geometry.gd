class_name TrackGeometryValidator
extends SceneTree

const TILE_DIRECTORY := "res://track/tiles"
const LAYOUT_DIRECTORY := "res://track/layouts"
const VALIDATION_TILE_SIZE := 36.0
const MIN_CURVE_TURN_ANGLE := deg_to_rad(15.0)
const MAX_TILE_SEAM_GAP := 0.05
const TrackCurveRef := preload("res://track/track_curve.gd")
const TrackLayoutResource := preload("res://track/track_layout.gd")
const TrackTileDefinitionResource := preload("res://track/track_tile_definition.gd")
const TileGeometryScript := preload("res://track/tiles/tile_geometry.gd")


func _initialize() -> void:
	var has_failures: bool = false

	for tile_path in _get_resource_paths(TILE_DIRECTORY):
		var tile_definition: TrackTileDefinition = load(tile_path) as TrackTileDefinition
		if tile_definition == null:
			push_error("Could not load tile definition at %s." % tile_path)
			has_failures = true
			continue
		if not _validate_tile_geometry(tile_path, tile_definition):
			has_failures = true

	for layout_path in _get_resource_paths(LAYOUT_DIRECTORY):
		var layout: TrackLayout = load(layout_path) as TrackLayout
		if layout == null:
			push_error("Could not load track layout resource at %s." % layout_path)
			has_failures = true
			continue
		if not _validate_layout_sampling(layout_path, layout):
			has_failures = true
		if not _validate_layout_tile_seams(layout_path, layout):
			has_failures = true

	quit(1 if has_failures else 0)


func _validate_tile_geometry(tile_path: String, tile_definition: TrackTileDefinition) -> bool:
	var raw_points: Array[Vector3] = tile_definition.get_world_points(VALIDATION_TILE_SIZE, Vector2i.ZERO)
	var sampled_points: Array[Vector3] = TileGeometryScript.build_sampled_path(tile_definition, VALIDATION_TILE_SIZE)
	var validation_ok: bool = true
	var endpoint_tangents: Array[Vector3] = TileGeometryScript.get_endpoint_tangents(tile_definition)

	if raw_points.size() >= 3:
		var raw_turn_angle: float = _get_accumulated_turn_angle(raw_points)
		if raw_turn_angle >= MIN_CURVE_TURN_ANGLE and sampled_points.size() <= raw_points.size():
			push_error("%s did not add curve samples for a turning tile." % tile_path)
			validation_ok = false

	if sampled_points.size() < 2:
		push_error("%s did not produce enough sampled points." % tile_path)
		return false

	var road_right: Array[Vector3] = TileGeometryScript.build_offset_polyline(
		sampled_points,
		TileGeometryScript.TRACK_WIDTH * 0.5,
		endpoint_tangents[0],
		endpoint_tangents[1]
	)
	var road_left: Array[Vector3] = TileGeometryScript.build_offset_polyline(
		sampled_points,
		-TileGeometryScript.TRACK_WIDTH * 0.5,
		endpoint_tangents[0],
		endpoint_tangents[1]
	)
	var sand_right: Array[Vector3] = TileGeometryScript.build_offset_polyline(
		sampled_points,
		TileGeometryScript.TRACK_WIDTH * 0.5 + TileGeometryScript.SAND_WIDTH,
		endpoint_tangents[0],
		endpoint_tangents[1]
	)
	var sand_left: Array[Vector3] = TileGeometryScript.build_offset_polyline(
		sampled_points,
		-(TileGeometryScript.TRACK_WIDTH * 0.5 + TileGeometryScript.SAND_WIDTH),
		endpoint_tangents[0],
		endpoint_tangents[1]
	)

	var strips_to_check: Dictionary = {
		"road": [road_right, road_left],
		"sand_right": [sand_right, road_right],
		"sand_left": [road_left, sand_left],
	}

	for label in strips_to_check.keys():
		var strip_points: Array = strips_to_check[label]
		if _has_inverted_strip_quad(strip_points[0] as Array[Vector3], strip_points[1] as Array[Vector3]):
			push_error("%s generated an inverted %s strip segment." % [tile_path, label])
			validation_ok = false

	print("%s: raw=%d sampled=%d" % [tile_path.get_file(), raw_points.size(), sampled_points.size()])
	return validation_ok


func _validate_layout_sampling(layout_path: String, layout: TrackLayout) -> bool:
	var raw_points: Array[Vector3] = layout.build_centerline_points()
	if raw_points.size() < 3:
		push_error("%s did not build enough raw centerline points." % layout_path)
		return false

	var sampled_points: Array[Vector3] = TrackCurveRef.build_smoothed_path(raw_points, true)
	if _get_accumulated_turn_angle(raw_points) >= MIN_CURVE_TURN_ANGLE and sampled_points.size() <= raw_points.size():
		push_error("%s did not increase the centerline sample density for a curved layout." % layout_path)
		return false

	print("%s: centerline raw=%d sampled=%d" % [layout_path.get_file(), raw_points.size(), sampled_points.size()])
	return true


func _validate_layout_tile_seams(layout_path: String, layout: TrackLayout) -> bool:
	var valid_tiles: Array[TrackLayoutTile] = []
	for layout_tile in layout.tiles:
		if layout_tile != null and layout_tile.tile != null:
			valid_tiles.append(layout_tile)

	if valid_tiles.size() < 2:
		return true

	var validation_ok: bool = true
	var road_half_width: float = TileGeometryScript.TRACK_WIDTH * 0.5
	var sand_outer_offset: float = road_half_width + TileGeometryScript.SAND_WIDTH

	for tile_index in range(valid_tiles.size()):
		var current_tile: TrackLayoutTile = valid_tiles[tile_index]
		var next_tile: TrackLayoutTile = valid_tiles[(tile_index + 1) % valid_tiles.size()]
		var current_sampled_points: Array[Vector3] = _get_layout_tile_sampled_points(layout, current_tile)
		var next_sampled_points: Array[Vector3] = _get_layout_tile_sampled_points(layout, next_tile)
		if current_sampled_points.size() < 2 or next_sampled_points.size() < 2:
			continue

		var current_tangents: Array[Vector3] = TileGeometryScript.get_endpoint_tangents(
			current_tile.tile,
			current_tile.rotation_steps,
			current_tile.reverse_path
		)
		var next_tangents: Array[Vector3] = TileGeometryScript.get_endpoint_tangents(
			next_tile.tile,
			next_tile.rotation_steps,
			next_tile.reverse_path
		)
		var gap_labels: PackedStringArray = PackedStringArray()
		gap_labels.append_array(_get_gap_labels(
			TileGeometryScript.build_offset_polyline(
				current_sampled_points,
				road_half_width,
				current_tangents[0],
				current_tangents[1]
			),
			TileGeometryScript.build_offset_polyline(
				next_sampled_points,
				road_half_width,
				next_tangents[0],
				next_tangents[1]
			),
			"road_outer"
		))
		gap_labels.append_array(_get_gap_labels(
			TileGeometryScript.build_offset_polyline(
				current_sampled_points,
				-road_half_width,
				current_tangents[0],
				current_tangents[1]
			),
			TileGeometryScript.build_offset_polyline(
				next_sampled_points,
				-road_half_width,
				next_tangents[0],
				next_tangents[1]
			),
			"road_inner"
		))
		gap_labels.append_array(_get_gap_labels(
			TileGeometryScript.build_offset_polyline(
				current_sampled_points,
				sand_outer_offset,
				current_tangents[0],
				current_tangents[1]
			),
			TileGeometryScript.build_offset_polyline(
				next_sampled_points,
				sand_outer_offset,
				next_tangents[0],
				next_tangents[1]
			),
			"sand_outer"
		))
		gap_labels.append_array(_get_gap_labels(
			TileGeometryScript.build_offset_polyline(
				current_sampled_points,
				-sand_outer_offset,
				current_tangents[0],
				current_tangents[1]
			),
			TileGeometryScript.build_offset_polyline(
				next_sampled_points,
				-sand_outer_offset,
				next_tangents[0],
				next_tangents[1]
			),
			"sand_inner"
		))

		if not gap_labels.is_empty():
			push_error(
				"%s seam %d (%s -> %s) exceeded %.2fm at %s." % [
					layout_path,
					tile_index,
					current_tile.get_display_name(),
					next_tile.get_display_name(),
					MAX_TILE_SEAM_GAP,
					", ".join(PackedStringArray(gap_labels)),
				]
			)
			validation_ok = false
		else:
			print(
				"%s seam %d ok: %s -> %s" % [
					layout_path.get_file(),
					tile_index,
					current_tile.get_display_name(),
					next_tile.get_display_name(),
				]
			)

	return validation_ok


func _get_accumulated_turn_angle(points: Array[Vector3]) -> float:
	var turn_angle: float = 0.0
	for point_index in range(1, points.size() - 1):
		var before: Vector2 = Vector2(points[point_index].x - points[point_index - 1].x, points[point_index].z - points[point_index - 1].z)
		var after: Vector2 = Vector2(points[point_index + 1].x - points[point_index].x, points[point_index + 1].z - points[point_index].z)
		if before.is_zero_approx() or after.is_zero_approx():
			continue
		turn_angle += absf(before.normalized().angle_to(after.normalized()))
	return turn_angle


func _has_inverted_strip_quad(side_a_points: Array[Vector3], side_b_points: Array[Vector3]) -> bool:
	var point_count: int = mini(side_a_points.size(), side_b_points.size())
	for point_index in range(point_count - 1):
		var side_a_start: Vector2 = Vector2(side_a_points[point_index].x, side_a_points[point_index].z)
		var side_a_end: Vector2 = Vector2(side_a_points[point_index + 1].x, side_a_points[point_index + 1].z)
		var side_b_start: Vector2 = Vector2(side_b_points[point_index].x, side_b_points[point_index].z)
		var side_b_end: Vector2 = Vector2(side_b_points[point_index + 1].x, side_b_points[point_index + 1].z)
		if Geometry2D.segment_intersects_segment(side_a_start, side_a_end, side_b_start, side_b_end) != null:
			return true
		if side_a_start.distance_squared_to(side_b_start) <= 0.0001:
			return true
		if side_a_end.distance_squared_to(side_b_end) <= 0.0001:
			return true
	return false


func _get_layout_tile_sampled_points(layout: TrackLayout, layout_tile: TrackLayoutTile) -> Array[Vector3]:
	var sampled_points: Array[Vector3] = TileGeometryScript.build_sampled_path(
		layout_tile.tile,
		layout.tile_size,
		layout_tile.rotation_steps,
		layout_tile.reverse_path
	)
	var tile_offset: Vector3 = Vector3(
		layout_tile.grid_position.x * layout.tile_size,
		0.0,
		layout_tile.grid_position.y * layout.tile_size
	)
	return _translate_points(sampled_points, tile_offset)


func _translate_points(points: Array[Vector3], offset: Vector3) -> Array[Vector3]:
	var translated_points: Array[Vector3] = []
	translated_points.resize(points.size())
	for point_index in range(points.size()):
		translated_points[point_index] = points[point_index] + offset
	return translated_points


func _get_gap_labels(current_points: Array[Vector3], next_points: Array[Vector3], label: String) -> PackedStringArray:
	var labels: PackedStringArray = PackedStringArray()
	if current_points.is_empty() or next_points.is_empty():
		return labels

	var gap: float = current_points[-1].distance_to(next_points[0])
	if gap > MAX_TILE_SEAM_GAP:
		labels.append("%s=%.3f" % [label, gap])
	return labels


func _get_resource_paths(directory_path: String) -> Array[String]:
	var resource_paths: Array[String] = []
	var directory: DirAccess = DirAccess.open(directory_path)
	if directory == null:
		push_error("Could not open %s." % directory_path)
		return resource_paths

	directory.list_dir_begin()
	var file_name: String = directory.get_next()
	while not file_name.is_empty():
		if not directory.current_is_dir() and file_name.ends_with(".tres"):
			resource_paths.append("%s/%s" % [directory_path, file_name])
		file_name = directory.get_next()
	directory.list_dir_end()

	resource_paths.sort()
	return resource_paths
