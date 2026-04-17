class_name HazardPlacementController
extends Node

## Owns the pit-stop hazard drafting + position-selection flow. Main configures the
## controller with the active track and clearance, pushes the drafted hazard type in,
## then calls begin_placement with the current occupied-position list. The controller
## spawns preview nodes, handles browse/confirm input via its public methods, and
## emits signals so main can drive camera focus, UI visibility, and round progression.

signal placement_begun(focused_preview: Node3D)
signal focus_changed(focused_preview: Node3D)
signal placement_confirmed
signal placement_abandoned

const HazardTypeRegistry := preload("res://race/hazard_type.gd")
const HAZARD_ROOT_NAME := "Hazards"
const CANDIDATE_COUNT := 3
const MAX_PLACEMENT_ATTEMPTS := 96

@export var min_hazard_distance: float = 8.0

var _track: TestTrack = null
var _track_clearance: float = 1.5
var _pending_hazard_type: int = HazardTypeRegistry.NONE
var _hazard_root: Node3D = null
var _position_previews: Array[Node3D] = []
var _focused_index: int = 0
var _is_active: bool = false


func configure(track: TestTrack, track_clearance: float) -> void:
	_track = track
	_track_clearance = track_clearance
	_ensure_hazard_root()


func is_active() -> bool:
	return _is_active


func has_pending_draft() -> bool:
	return HazardTypeRegistry.is_valid_type(_pending_hazard_type)


func set_pending_hazard_type(hazard_type: int) -> void:
	if not HazardTypeRegistry.is_valid_type(hazard_type):
		return
	_pending_hazard_type = hazard_type


func get_pending_hazard_type() -> int:
	return _pending_hazard_type


func clear_pending() -> void:
	_pending_hazard_type = HazardTypeRegistry.NONE


func clear_selection() -> void:
	_clear_selection_internal(null)


func get_hazard_root() -> Node3D:
	return _hazard_root


func get_position_count() -> int:
	return _position_previews.size()


func get_focused_index() -> int:
	return _focused_index


## Starts the placement flow. Returns true if previews spawned and the flow is active;
## returns false (and emits placement_abandoned) if the drafted hazard could not be
## placed, so main can resume the round start sequence.
func begin_placement(occupied_positions: Array[Vector3]) -> bool:
	if _track == null or not has_pending_draft():
		_pending_hazard_type = HazardTypeRegistry.NONE
		placement_abandoned.emit()
		return false

	_ensure_hazard_root()
	if _hazard_root == null:
		_pending_hazard_type = HazardTypeRegistry.NONE
		placement_abandoned.emit()
		return false

	_clear_selection_internal(null)

	var generated_positions: Array[Dictionary] = _generate_positions(occupied_positions)
	if generated_positions.size() < CANDIDATE_COUNT:
		push_warning("HazardPlacementController could not find %d valid hazard placement positions." % CANDIDATE_COUNT)
		_pending_hazard_type = HazardTypeRegistry.NONE
		placement_abandoned.emit()
		return false

	for candidate in generated_positions:
		var preview_transform: Transform3D = candidate["transform"]
		var preview: Node3D = _spawn_preview(_pending_hazard_type, preview_transform)
		if preview == null:
			continue
		_position_previews.append(preview)

	if _position_previews.size() < CANDIDATE_COUNT:
		push_warning("HazardPlacementController failed to prepare %d hazard placement previews." % CANDIDATE_COUNT)
		_clear_selection_internal(null)
		_pending_hazard_type = HazardTypeRegistry.NONE
		placement_abandoned.emit()
		return false

	_focused_index = 0
	_is_active = true
	_update_focus_visuals()
	placement_begun.emit(_position_previews[_focused_index])
	return true


func confirm() -> void:
	if not _is_active or _position_previews.is_empty():
		return

	var safe_index: int = clampi(_focused_index, 0, _position_previews.size() - 1)
	var chosen: Node3D = _position_previews[safe_index]
	if chosen == null:
		return

	HazardPreviewHelper.set_preview(chosen, false, true, true)
	_clear_selection_internal(chosen)

	var base_name: String = HazardTypeRegistry.get_node_name(_pending_hazard_type)
	chosen.name = "%s%d" % [base_name, _count_hazards_with_base_name(base_name, chosen) + 1]
	_pending_hazard_type = HazardTypeRegistry.NONE
	placement_confirmed.emit()


func cycle(direction: int) -> void:
	if _position_previews.is_empty():
		return
	focus_index(_focused_index + direction)


func focus_index(index: int) -> void:
	if _position_previews.is_empty():
		return

	_focused_index = wrapi(index, 0, _position_previews.size())
	_update_focus_visuals()
	focus_changed.emit(_position_previews[_focused_index])


func _ensure_hazard_root() -> void:
	if _track == null:
		return

	_hazard_root = _track.get_node_or_null(HAZARD_ROOT_NAME) as Node3D
	if _hazard_root:
		return

	_hazard_root = Node3D.new()
	_hazard_root.name = HAZARD_ROOT_NAME
	_track.add_child(_hazard_root)


func _generate_positions(occupied_positions: Array[Vector3]) -> Array[Dictionary]:
	var positions: Array[Dictionary] = []
	if _track == null:
		return positions

	var local_occupied: Array[Vector3] = occupied_positions.duplicate()
	var max_lateral_offset: float = _track.get_max_lateral_offset(_track_clearance)
	var prefer_corner_inside: bool = _pending_hazard_type == HazardTypeRegistry.Type.CONE_CHICANE
	# First half of the attempt budget enforces corner-inside when a hazard
	# asks for it; the second half relaxes the constraint so straight-heavy
	# tracks still yield a full set of candidates rather than failing the
	# placement flow outright.
	var strict_attempt_cap: int = MAX_PLACEMENT_ATTEMPTS / 2

	var attempts: int = 0
	while positions.size() < CANDIDATE_COUNT and attempts < MAX_PLACEMENT_ATTEMPTS:
		attempts += 1

		var progress: float = randf()
		var lateral_offset: float = randf_range(-max_lateral_offset, max_lateral_offset)

		if prefer_corner_inside:
			var inside_sign: int = _track.get_inside_lateral_sign(progress)
			if inside_sign != 0:
				lateral_offset = absf(lateral_offset) * float(inside_sign)
			elif attempts <= strict_attempt_cap:
				continue

		if not _track.is_track_position_valid(progress, lateral_offset, _track_clearance):
			continue

		var candidate_transform: Transform3D = _track.get_track_transform(progress, lateral_offset)
		var candidate_position: Vector3 = candidate_transform.origin
		if _is_position_blocked(candidate_position, local_occupied):
			continue

		local_occupied.append(candidate_position)
		positions.append({
			"progress": progress,
			"lateral_offset": lateral_offset,
			"transform": candidate_transform,
		})

	if positions.size() < CANDIDATE_COUNT:
		return []

	return positions


func _spawn_preview(hazard_type: int, preview_transform: Transform3D) -> Node3D:
	var preview_scene: PackedScene = load(HazardTypeRegistry.get_scene_path(hazard_type)) as PackedScene
	if preview_scene == null:
		push_warning("HazardPlacementController failed to load a hazard scene for type %d." % hazard_type)
		return null

	var preview_node: Node3D = preview_scene.instantiate() as Node3D
	if preview_node == null:
		push_warning("HazardPlacementController failed to instantiate a hazard preview for type %d." % hazard_type)
		return null

	preview_node.name = "%sPreview" % HazardTypeRegistry.get_node_name(hazard_type)
	HazardPreviewHelper.set_preview(preview_node, true, true, false)
	_hazard_root.add_child(preview_node)
	preview_node.global_transform = preview_transform
	return preview_node


func _update_focus_visuals() -> void:
	for preview_index in range(_position_previews.size()):
		var preview: Node3D = _position_previews[preview_index]
		if preview == null:
			continue
		HazardPreviewHelper.set_preview_focus(preview, preview_index == _focused_index)


func _clear_selection_internal(kept_preview: Node3D) -> void:
	for preview in _position_previews:
		if preview == null or preview == kept_preview:
			continue
		preview.queue_free()

	_position_previews.clear()
	_focused_index = 0
	_is_active = false


func _count_hazards_with_base_name(base_name: String, exclude: Node3D) -> int:
	if _hazard_root == null:
		return 0
	var count: int = 0
	for child in _hazard_root.get_children():
		if child == exclude:
			continue
		if child.name.begins_with(base_name):
			count += 1
	return count


func _is_position_blocked(candidate_position: Vector3, occupied_positions: Array[Vector3]) -> bool:
	for occupied_position in occupied_positions:
		if occupied_position.distance_to(candidate_position) < min_hazard_distance:
			return true
	return false
