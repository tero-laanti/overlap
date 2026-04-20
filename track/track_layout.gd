@tool
class_name TrackLayout
extends Resource

const TrackDirectionRef := preload("res://track/track_direction.gd")
const TrackLayoutTileResource := preload("res://track/track_layout_tile.gd")

const CONNECTION_EPSILON := 0.05

## StringName encoding for the optional procedural centerline generator. Leave
## empty for the tile-based pipeline. Recognised values: "figure_eight".
const SHAPE_FIGURE_EIGHT := &"figure_eight"
const FIGURE_EIGHT_MIN_SEGMENTS := 32

@export var display_name: String = ""
@export_range(16.0, 64.0, 1.0) var tile_size: float = 36.0
@export_range(0.0, 1.0, 0.01) var lap_start_progress: float = 0.0
@export var tiles: Array[TrackLayoutTileResource] = []

## When non-null, `Main` swaps `main.tscn`'s default `vehicle_scene` for this
## scene on round start. Lets a layout request a specific controller (e.g.
## the figure-eight's bridge crossing benefits from PhysicsCar). Null means
## keep the main.tscn default.
@export var preferred_vehicle: PackedScene = null

## When non-empty, the centerline is generated procedurally and `tiles` is
## ignored. Self-intersecting shapes (figure_eight) also signal TestTrack to
## switch to the split-lobe ground renderer.
@export var procedural_shape: StringName = &""
@export var procedural_half_size: Vector2 = Vector2(60.0, 40.0)
@export_range(32, 256, 4) var procedural_segment_count: int = 128
@export var procedural_bridge_height: float = 4.5
@export_range(0.04, 0.5, 0.01) var procedural_bridge_fraction: float = 0.18

var _observed_tiles: Array[TrackLayoutTileResource] = []


## TestTrack calls this after loading or swapping layouts so nested tile
## resources still bubble `changed` up without relying on setter exports.
## Resource load populates `tiles` after `_init` runs, so wiring observers
## here (instead of in `_init`) is the only way to see the real tiles.
func refresh_tile_observers() -> void:
	_refresh_tile_observers()


func build_centerline_points() -> Array[Vector3]:
	if procedural_shape == SHAPE_FIGURE_EIGHT:
		return _build_figure_eight_points()

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


func has_self_crossing() -> bool:
	return procedural_shape == SHAPE_FIGURE_EIGHT


func _build_figure_eight_points() -> Array[Vector3]:
	var centerline_points: Array[Vector3] = []
	var segment_count: int = _get_resolved_segment_count()
	var half_width: float = maxf(procedural_half_size.x, 1.0)
	var half_depth: float = maxf(procedural_half_size.y, 1.0)
	# Lemniscate of Gerono: x = cos(t), z = sin(t)*cos(t). The two crossings
	# at t=PI/2 and t=3*PI/2 both land on the XZ origin — we elevate the first
	# crossing into a bridge so the two passes resolve in 3D.
	for index in range(segment_count):
		var t: float = float(index) / float(segment_count) * TAU
		var x: float = half_width * cos(t)
		var z: float = half_depth * 2.0 * sin(t) * cos(t)
		var y: float = _figure_eight_bridge_height(t)
		centerline_points.append(Vector3(x, y, z))
	return centerline_points


func _figure_eight_bridge_height(t: float) -> float:
	if procedural_bridge_height <= 0.0 or procedural_bridge_fraction <= 0.0:
		return 0.0

	var delta: float = wrapf(t - PI * 0.5, -PI, PI)
	var window: float = TAU * procedural_bridge_fraction * 0.5
	if window <= 0.0 or absf(delta) >= window:
		return 0.0

	var normalized: float = absf(delta) / window
	return procedural_bridge_height * 0.5 * (1.0 + cos(normalized * PI))


func _get_resolved_segment_count() -> int:
	var requested: int = procedural_segment_count
	# Clamp up to the minimum and force divisible-by-4 so the two crossings
	# fall on explicit centerline points instead of mid-segment.
	var safe: int = maxi(requested, FIGURE_EIGHT_MIN_SEGMENTS)
	return safe - (safe % 4)


func get_validation_issues() -> PackedStringArray:
	if procedural_shape == SHAPE_FIGURE_EIGHT:
		return _get_figure_eight_validation_issues()

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


func _get_figure_eight_validation_issues() -> PackedStringArray:
	var issues: PackedStringArray = PackedStringArray()
	var layout_name: String = _get_layout_name()

	if procedural_half_size.x <= 0.0 or procedural_half_size.y <= 0.0:
		issues.append("%s: procedural_half_size must be positive in both axes." % layout_name)
	if procedural_segment_count < FIGURE_EIGHT_MIN_SEGMENTS:
		issues.append(
			"%s: procedural_segment_count %d is below the required minimum %d." % [
				layout_name,
				procedural_segment_count,
				FIGURE_EIGHT_MIN_SEGMENTS,
			]
		)
	if procedural_bridge_height < 2.0:
		issues.append(
			"%s: procedural_bridge_height %f is too low for the crossing to clear the ground walls." % [
				layout_name,
				procedural_bridge_height,
			]
		)

	return issues
