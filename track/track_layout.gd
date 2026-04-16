@tool
class_name TrackLayout
extends Resource

const TrackDirectionRef := preload("res://track/track_direction.gd")
const TrackLayoutTileResource := preload("res://track/track_layout_tile.gd")

const CONNECTION_EPSILON := 0.05

var _display_name: String = ""
var _tile_size: float = 36.0
var _lap_start_progress: float = 0.0
var _tiles: Array[TrackLayoutTileResource] = []

@export var display_name: String:
	get:
		return _display_name
	set(value):
		_display_name = value
		emit_changed()
@export_range(16.0, 64.0, 1.0) var tile_size: float:
	get:
		return _tile_size
	set(value):
		_tile_size = value
		emit_changed()
@export_range(0.0, 1.0, 0.01) var lap_start_progress: float:
	get:
		return _lap_start_progress
	set(value):
		_lap_start_progress = value
		emit_changed()
@export var tiles: Array[TrackLayoutTileResource]:
	get:
		return _tiles
	set(value):
		_tiles = value
		_refresh_tile_observers()
		emit_changed()

var _observed_tiles: Array[TrackLayoutTileResource] = []


func _init() -> void:
	_refresh_tile_observers()


func build_centerline_points() -> Array[Vector3]:
	var centerline_points: Array[Vector3] = []

	for layout_tile in tiles:
		if layout_tile == null:
			continue

		var tile_points: Array[Vector3] = layout_tile.get_world_points(tile_size)
		if tile_points.is_empty():
			continue

		if centerline_points.is_empty():
			centerline_points.append_array(tile_points)
			continue

		var starts_on_previous_exit: bool = centerline_points[-1].distance_to(tile_points[0]) <= CONNECTION_EPSILON
		var start_index: int = 1 if starts_on_previous_exit else 0
		for point_index in range(start_index, tile_points.size()):
			centerline_points.append(tile_points[point_index])

	if centerline_points.size() > 1 and centerline_points[-1].distance_to(centerline_points[0]) <= CONNECTION_EPSILON:
		centerline_points.remove_at(centerline_points.size() - 1)

	return centerline_points


func get_validation_issues() -> PackedStringArray:
	var issues: PackedStringArray = PackedStringArray()
	var valid_tiles: Array[TrackLayoutTileResource] = []
	var occupied_cells: Dictionary = {}
	var layout_name: String = _get_layout_name()

	for layout_tile in tiles:
		if layout_tile != null and layout_tile.tile != null:
			valid_tiles.append(layout_tile)

	if valid_tiles.size() < 3:
		issues.append("TrackLayout needs at least three placed tiles to form a loop.")
		return issues

	for tile_index in range(valid_tiles.size()):
		var current_tile: TrackLayoutTileResource = valid_tiles[tile_index]
		var current_tile_name: String = current_tile.get_display_name()
		for tile_issue in current_tile.get_configuration_issues():
			issues.append("%s tile %d (%s): %s" % [layout_name, tile_index + 1, current_tile_name, tile_issue])

		for occupied_cell in current_tile.get_occupied_cells():
			if occupied_cells.has(occupied_cell):
				var overlapping_tile_index: int = occupied_cells[occupied_cell]
				issues.append(
					"%s tile %d (%s) overlaps tile %d (%s) at grid cell %s." % [
						layout_name,
						tile_index + 1,
						current_tile_name,
						overlapping_tile_index + 1,
						valid_tiles[overlapping_tile_index].get_display_name(),
						occupied_cell,
					]
				)
				continue

			occupied_cells[occupied_cell] = tile_index

	for tile_index in range(valid_tiles.size()):
		var current_tile: TrackLayoutTileResource = valid_tiles[tile_index]
		var next_tile: TrackLayoutTileResource = valid_tiles[(tile_index + 1) % valid_tiles.size()]
		var current_tile_name: String = current_tile.get_display_name()
		var next_tile_name: String = next_tile.get_display_name()
		var expected_next_entry_cell: Vector2i = current_tile.get_exit_grid_position() + TrackDirectionRef.get_grid_offset(current_tile.get_exit_direction())
		var next_entry_cell: Vector2i = next_tile.get_entry_grid_position()
		if expected_next_entry_cell != next_entry_cell:
			issues.append(
				"%s tile %d (%s) exits toward grid cell %s, but tile %d (%s) enters from %s." % [
					layout_name,
					tile_index + 1,
					current_tile_name,
					expected_next_entry_cell,
					(tile_index + 1) % valid_tiles.size() + 1,
					next_tile_name,
					next_entry_cell,
				]
			)

		if not TrackDirectionRef.are_opposites(current_tile.get_exit_direction(), next_tile.get_entry_direction()):
			issues.append(
				"%s tile %d (%s) exits %s but tile %d (%s) enters %s." % [
					layout_name,
					tile_index + 1,
					current_tile_name,
					TrackDirectionRef.get_label(current_tile.get_exit_direction()),
					(tile_index + 1) % valid_tiles.size() + 1,
					next_tile_name,
					TrackDirectionRef.get_label(next_tile.get_entry_direction()),
				]
			)

		var current_points: Array[Vector3] = current_tile.get_world_points(tile_size)
		var next_points: Array[Vector3] = next_tile.get_world_points(tile_size)
		if current_points.is_empty() or next_points.is_empty():
			continue

		if current_points[-1].distance_to(next_points[0]) > CONNECTION_EPSILON:
			issues.append(
				"%s tile %d (%s) does not line up with tile %d (%s)." % [
					layout_name,
					tile_index + 1,
					current_tile_name,
					(tile_index + 1) % valid_tiles.size() + 1,
					next_tile_name,
				]
			)

	return issues


func _refresh_tile_observers() -> void:
	for observed_tile in _observed_tiles:
		if observed_tile != null and observed_tile.changed.is_connected(_on_layout_tile_changed):
			observed_tile.changed.disconnect(_on_layout_tile_changed)

	_observed_tiles.clear()

	for layout_tile in tiles:
		if layout_tile == null or _observed_tiles.has(layout_tile):
			continue

		_observed_tiles.append(layout_tile)
		if not layout_tile.changed.is_connected(_on_layout_tile_changed):
			layout_tile.changed.connect(_on_layout_tile_changed)


func _on_layout_tile_changed() -> void:
	emit_changed()


func _get_layout_name() -> String:
	return display_name if not display_name.is_empty() else "TrackLayout"
