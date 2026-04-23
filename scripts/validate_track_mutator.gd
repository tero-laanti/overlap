class_name TrackMutatorValidator
extends SceneTree

const LAYOUT_DIRECTORY := "res://track/layouts"
const ITERATIONS_PER_LAYOUT := 6
const OCCUPANCY_OFFSET_FRACTION := 0.25

const TrackLayoutResource := preload("res://track/track_layout.gd")
const TrackMutatorResource := preload("res://track/track_mutator.gd")


func _initialize() -> void:
	var layout_paths: Array[String] = _get_layout_paths()
	var has_failures: bool = false
	var exercised_occupancy_rule: bool = false
	var mutator: TrackMutator = TrackMutatorResource.new()

	for layout_path in layout_paths:
		var layout: TrackLayout = load(layout_path) as TrackLayout
		if layout == null:
			push_error("Could not load layout: %s" % layout_path)
			has_failures = true
			continue

		var current_layout: TrackLayout = layout
		var start_length: int = _centerline_length(current_layout)
		for iteration in range(ITERATIONS_PER_LAYOUT):
			var occupancy_check_exercised: bool = _validate_occupied_position_safety(
				mutator,
				current_layout,
				layout_path,
				iteration
			)
			exercised_occupancy_rule = exercised_occupancy_rule or occupancy_check_exercised

			var result: TrackMutationResult = mutator.mutate_layout(current_layout, [] as Array[Vector3])
			if result == null or result.layout == null:
				push_error("%s iteration %d: mutator returned null layout" % [layout_path, iteration])
				has_failures = true
				break

			var mutated: TrackLayout = result.layout
			var issues: PackedStringArray = mutated.get_validation_issues()
			if not issues.is_empty():
				for issue in issues:
					push_error("%s iteration %d: %s" % [layout_path, iteration, issue])
				has_failures = true
				break

			var centerline_size: int = mutated.build_centerline_points().size()
			if centerline_size < 3:
				push_error("%s iteration %d: centerline too short (%d)" % [layout_path, iteration, centerline_size])
				has_failures = true
				break

			print(
				"%s iter %d: changed=%s tiles=%d centerline_points=%d" % [
					layout_path.get_file(),
					iteration,
					result.changed,
					mutated.tiles.size(),
					centerline_size,
				]
			)
			current_layout = mutated

		var end_length: int = _centerline_length(current_layout)
		print("%s: %d -> %d centerline points" % [layout_path.get_file(), start_length, end_length])

	if not exercised_occupancy_rule:
		push_error("Track mutator validator never exercised occupied-position safety.")
		has_failures = true

	quit(1 if has_failures else 0)


func _centerline_length(layout: TrackLayout) -> int:
	return layout.build_centerline_points().size()


func _get_layout_paths() -> Array[String]:
	var layout_paths: Array[String] = []
	var directory: DirAccess = DirAccess.open(LAYOUT_DIRECTORY)
	if directory == null:
		push_error("Could not open %s." % LAYOUT_DIRECTORY)
		return layout_paths

	directory.list_dir_begin()
	var file_name: String = directory.get_next()
	while not file_name.is_empty():
		if not directory.current_is_dir() and file_name.ends_with(".tres"):
			layout_paths.append("%s/%s" % [LAYOUT_DIRECTORY, file_name])
		file_name = directory.get_next()
	directory.list_dir_end()

	layout_paths.sort()
	return layout_paths


func _validate_occupied_position_safety(
	mutator: TrackMutator,
	layout: TrackLayout,
	layout_path: String,
	iteration: int
) -> bool:
	var candidate_indexes: Array[int] = _get_candidate_tile_indexes(mutator, layout)
	if candidate_indexes.is_empty():
		print("%s iter %d: no mutation candidates to occupancy-check" % [layout_path.get_file(), iteration])
		return false

	var occupied_positions: Array[Vector3] = []
	for tile_index in candidate_indexes:
		var layout_tile: TrackLayoutTile = layout.tiles[tile_index]
		occupied_positions.append(_build_off_center_occupied_position(layout_tile, layout.tile_size))

	var blocked_result: TrackMutationResult = mutator.mutate_layout(layout, occupied_positions)
	if blocked_result == null or blocked_result.layout == null:
		push_error("%s iteration %d: occupied-position safety returned null layout" % [layout_path, iteration])
		return true
	if blocked_result.changed:
		push_error(
			"%s iteration %d: occupied positions should block all mutation candidates, but mutator still changed layout" % [
				layout_path,
				iteration,
			]
		)
		return true

	print(
		"%s iter %d: occupied positions blocked %d candidate tiles" % [
			layout_path.get_file(),
			iteration,
			candidate_indexes.size(),
		]
	)
	return true


func _get_candidate_tile_indexes(mutator: TrackMutator, layout: TrackLayout) -> Array[int]:
	var candidate_indexes: Array[int] = []
	var seen_indexes: Dictionary[int, bool] = {}
	var candidates: Array[Dictionary] = mutator._collect_candidates(layout, [] as Array[Vector3])
	for candidate in candidates:
		var tile_index: int = candidate["tile_index"]
		if seen_indexes.has(tile_index):
			continue
		seen_indexes[tile_index] = true
		candidate_indexes.append(tile_index)
	return candidate_indexes


func _build_off_center_occupied_position(layout_tile: TrackLayoutTile, tile_size: float) -> Vector3:
	var occupied_cells: Array[Vector2i] = layout_tile.get_occupied_cells()
	var sampled_cell: Vector2i = occupied_cells[0]
	var cell_center: Vector3 = Vector3(sampled_cell.x * tile_size, 0.0, sampled_cell.y * tile_size)
	var offset: float = tile_size * OCCUPANCY_OFFSET_FRACTION
	return cell_center - Vector3(offset, 0.0, offset)
