class_name TrackMutatorValidator
extends SceneTree

const LAYOUT_DIRECTORY := "res://track/layouts"
const ITERATIONS_PER_LAYOUT := 6

const TrackLayoutResource := preload("res://track/track_layout.gd")
const TrackMutatorResource := preload("res://track/track_mutator.gd")


func _initialize() -> void:
	var layout_paths: Array[String] = _get_layout_paths()
	var has_failures: bool = false
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
			var mutated: TrackLayout = mutator.mutate_layout(current_layout, [] as Array[Vector3])
			if mutated == null:
				push_error("%s iteration %d: mutator returned null" % [layout_path, iteration])
				has_failures = true
				break

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
				"%s iter %d: tiles=%d, centerline_points=%d" % [
					layout_path.get_file(),
					iteration,
					mutated.tiles.size(),
					centerline_size,
				]
			)
			current_layout = mutated

		var end_length: int = _centerline_length(current_layout)
		print("%s: %d -> %d centerline points" % [layout_path.get_file(), start_length, end_length])

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
