class_name TrackLayoutValidator
extends SceneTree

const LAYOUT_DIRECTORY := "res://track/layouts"
const TrackLayoutResource := preload("res://track/track_layout.gd")


func _initialize() -> void:
	var layout_paths: Array[String] = _get_layout_paths()
	var has_failures: bool = false

	for layout_path in layout_paths:
		var layout: TrackLayoutResource = load(layout_path) as TrackLayoutResource
		if layout == null:
			push_error("Could not load track layout resource at %s." % layout_path)
			has_failures = true
			continue

		for issue in layout.get_validation_issues():
			push_error("%s: %s" % [layout_path, issue])
			has_failures = true

		if layout.build_centerline_points().size() < 3:
			push_error("%s did not build enough centerline points for the runtime track pipeline." % layout_path)
			has_failures = true

	quit(1 if has_failures else 0)


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
