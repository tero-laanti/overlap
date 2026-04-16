class_name MainSceneController
extends Node3D

const HazardTypeRegistry := preload("res://race/hazard_type.gd")
const BOOST_PAD_SCENE: PackedScene = preload("res://race/boost_pad.tscn")
const PLACEMENT_LABEL_MARGIN := Vector2(24.0, 24.0)
## Approximate radius of a boost pad for overlap checks (half the pad's longest extent).
const BOOST_PAD_FOOTPRINT_RADIUS := 2.3
const HAZARD_DRAFT_OPTION_COUNT := 3
const HAZARD_POSITION_CANDIDATE_COUNT := 3
const HAZARD_POSITION_MAX_ATTEMPTS := 96

@export var track_path: NodePath
@export var car_path: NodePath
@export var run_state_path: NodePath
@export var round_end_screen_path: NodePath
@export var camera_path: NodePath
@export var buy_time_cost: int = 20
@export var buy_time_seconds: float = 15.0
@export var buy_boost_pad_cost: int = 30
@export var placement_progress_speed: float = 0.18
@export var placement_lateral_speed: float = 7.0
@export var boost_pad_track_clearance: float = 1.5
@export var _min_hazard_distance: float = 8.0

var _track: TestTrack = null
var _car: Car = null
var _run_state: RunState = null
var _round_end_screen: RoundEndScreen = null
var _camera: GameCamera = null
var _car_spawn_transform: Transform3D = Transform3D.IDENTITY
var _pending_start_time_bonus: float = 0.0
var _pending_boost_pad_count: int = 0
var _pending_hazard_type: int = HazardTypeRegistry.NONE
var _boost_pad_root: Node3D = null
var _hazard_root: Node3D = null
var _placement_overlay: CanvasLayer = null
var _placement_label: Label = null
var _placement_preview: BoostPad = null
var _placement_progress: float = 0.0
var _placement_lateral_offset: float = 0.0
var _is_placement_active: bool = false
var _hazard_position_previews: Array[Node3D] = []
var _hazard_position_data: Array[Dictionary] = []
var _hazard_focused_index: int = 0
var _is_hazard_position_selection_active: bool = false


func _ready() -> void:
	randomize()
	_track = get_node_or_null(track_path) as TestTrack
	if _track == null:
		_track = get_node_or_null("Track") as TestTrack
	_car = get_node_or_null(car_path) as Car
	_run_state = get_node_or_null(run_state_path) as RunState
	_round_end_screen = get_node_or_null(round_end_screen_path) as RoundEndScreen
	_camera = get_node_or_null(camera_path) as GameCamera

	if not _track:
		push_warning("MainSceneController could not find the track.")
	if not _car:
		push_warning("MainSceneController could not find the car.")
	else:
		_car_spawn_transform = _car.global_transform

	if not _run_state:
		push_warning("MainSceneController could not find the run state.")
	if not _round_end_screen:
		push_warning("MainSceneController could not find the round-end screen.")
	if not _camera:
		push_warning("MainSceneController could not find the camera.")

	_ensure_boost_pad_root()
	_ensure_hazard_root()
	_ensure_placement_overlay()

	if _round_end_screen:
		_round_end_screen.configure_buy_time_option(buy_time_cost, buy_time_seconds)
		_round_end_screen.configure_buy_boost_pad_option(buy_boost_pad_cost)
		_round_end_screen.set_pending_start_time_bonus(_pending_start_time_bonus)
		_round_end_screen.set_pending_boost_pad_count(_pending_boost_pad_count)
		_round_end_screen.clear_hazard_draft()

		if not _round_end_screen.buy_time_requested.is_connected(_on_buy_time_requested):
			_round_end_screen.buy_time_requested.connect(_on_buy_time_requested)
		if not _round_end_screen.buy_boost_pad_requested.is_connected(_on_buy_boost_pad_requested):
			_round_end_screen.buy_boost_pad_requested.connect(_on_buy_boost_pad_requested)
		if not _round_end_screen.hazard_drafted.is_connected(_on_hazard_drafted):
			_round_end_screen.hazard_drafted.connect(_on_hazard_drafted)
		if not _round_end_screen.continue_requested.is_connected(_on_continue_requested):
			_round_end_screen.continue_requested.connect(_on_continue_requested)

	if _run_state:
		if not _run_state.round_finished.is_connected(_on_round_finished):
			_run_state.round_finished.connect(_on_round_finished)
		if not _run_state.round_started.is_connected(_on_round_started):
			_run_state.round_started.connect(_on_round_started)

	if _track:
		_placement_progress = _track.get_lap_start_progress()

	_focus_camera_on(_car, false)
	_update_car_controls()
	_update_placement_overlay()


func _process(delta: float) -> void:
	if not _is_placement_active or not _track:
		return

	_update_placement_input(delta)
	_update_placement_preview()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return

	if _is_hazard_position_selection_active:
		if event.is_action_pressed("steer_left"):
			get_viewport().set_input_as_handled()
			_cycle_hazard_position(-1)
		elif event.is_action_pressed("steer_right"):
			get_viewport().set_input_as_handled()
			_cycle_hazard_position(1)
		elif event.is_action_pressed("draft_hazard_1"):
			get_viewport().set_input_as_handled()
			_focus_hazard_position(0)
		elif event.is_action_pressed("draft_hazard_2"):
			get_viewport().set_input_as_handled()
			_focus_hazard_position(1)
		elif event.is_action_pressed("draft_hazard_3"):
			get_viewport().set_input_as_handled()
			_focus_hazard_position(2)
		elif event.is_action_pressed("place_boost_pad"):
			get_viewport().set_input_as_handled()
			_confirm_hazard_position()
		return

	if not _is_placement_active:
		return
	if event.is_action_pressed("place_boost_pad"):
		get_viewport().set_input_as_handled()
		_confirm_boost_pad_placement()


func _on_buy_time_requested() -> void:
	if not _run_state or _run_state.is_round_active:
		return
	if buy_time_cost <= 0 or buy_time_seconds <= 0.0:
		return
	if not _run_state.spend_currency(buy_time_cost):
		return

	_pending_start_time_bonus += buy_time_seconds
	if _round_end_screen:
		_round_end_screen.set_pending_start_time_bonus(_pending_start_time_bonus)


func _on_buy_boost_pad_requested() -> void:
	if not _run_state or _run_state.is_round_active:
		return
	if buy_boost_pad_cost <= 0:
		return
	if not _run_state.spend_currency(buy_boost_pad_cost):
		return

	_pending_boost_pad_count += 1
	if _round_end_screen:
		_round_end_screen.set_pending_boost_pad_count(_pending_boost_pad_count)


func _on_hazard_drafted(hazard_type: int) -> void:
	if not HazardTypeRegistry.is_valid_type(hazard_type):
		return
	_pending_hazard_type = hazard_type


func _on_continue_requested() -> void:
	if not _car or not _run_state or _run_state.is_round_active:
		return
	if _is_placement_active or _is_hazard_position_selection_active:
		return
	if _should_require_hazard_draft() and not _has_pending_hazard_draft():
		return

	if _pending_boost_pad_count > 0:
		_begin_boost_pad_placement()
		return

	if _has_pending_hazard_draft():
		_begin_hazard_position_selection()
		return

	_start_next_round()


func _on_round_finished() -> void:
	_pending_hazard_type = HazardTypeRegistry.NONE
	if _round_end_screen:
		_round_end_screen.configure_hazard_draft(_get_hazard_draft_options())
	_update_car_controls()


func _on_round_started(_round_number: int) -> void:
	_is_placement_active = false
	_clear_placement_preview()
	_clear_hazard_position_selection()
	_pending_hazard_type = HazardTypeRegistry.NONE
	if _round_end_screen:
		_round_end_screen.clear_hazard_draft()
	_update_car_controls()
	_update_placement_overlay()
	_focus_camera_on(_car, false)


func _start_next_round() -> void:
	if not _car or not _run_state or _run_state.is_round_active:
		return
	if _is_placement_active or _is_hazard_position_selection_active:
		return

	var extra_start_time: float = _pending_start_time_bonus
	_pending_start_time_bonus = 0.0
	if _round_end_screen:
		_round_end_screen.set_pending_start_time_bonus(_pending_start_time_bonus)
		_round_end_screen.set_pending_boost_pad_count(_pending_boost_pad_count)

	_car.reset_to_transform(_get_car_start_transform())
	_focus_camera_on(_car, true)
	_run_state.start_round(extra_start_time)


func _begin_boost_pad_placement() -> void:
	if not _track or BOOST_PAD_SCENE == null:
		_start_next_round()
		return

	_is_placement_active = true
	_placement_lateral_offset = clampf(
		_placement_lateral_offset,
		-_track.get_max_lateral_offset(boost_pad_track_clearance),
		_track.get_max_lateral_offset(boost_pad_track_clearance)
	)

	if _car:
		_car.reset_to_transform(_get_car_start_transform())

	if _round_end_screen:
		_round_end_screen.visible = false

	_spawn_placement_preview()
	_update_car_controls()
	_update_placement_preview()
	_update_placement_overlay()
	_focus_camera_on(_placement_preview, true)


func _confirm_boost_pad_placement() -> void:
	if not _track or not _placement_preview:
		return

	var can_place: bool = _can_place_boost_pad(_placement_progress, _placement_lateral_offset)
	if not can_place:
		return

	_placement_preview.set_preview_mode(false)
	_placement_preview.name = "BoostPad"
	_placement_preview = null
	_pending_boost_pad_count = maxi(_pending_boost_pad_count - 1, 0)
	if _round_end_screen:
		_round_end_screen.set_pending_boost_pad_count(_pending_boost_pad_count)

	if _pending_boost_pad_count > 0:
		_spawn_placement_preview()
		_update_placement_preview()
		_focus_camera_on(_placement_preview, true)
		return

	_is_placement_active = false
	_update_car_controls()
	_update_placement_overlay()
	if _has_pending_hazard_draft():
		_begin_hazard_position_selection()
		return

	_start_next_round()


func _begin_hazard_position_selection() -> void:
	if not _track or not _has_pending_hazard_draft():
		_start_next_round()
		return
	if _hazard_root == null:
		_ensure_hazard_root()
	if _hazard_root == null:
		_start_next_round()
		return

	_clear_hazard_position_selection()

	var generated_positions: Array[Dictionary] = _generate_hazard_positions()
	if generated_positions.size() < HAZARD_POSITION_CANDIDATE_COUNT:
		push_warning("MainSceneController could not find %d valid hazard placement positions." % HAZARD_POSITION_CANDIDATE_COUNT)
		_pending_hazard_type = HazardTypeRegistry.NONE
		_start_next_round()
		return

	if _car:
		_car.reset_to_transform(_get_car_start_transform())
	if _round_end_screen:
		_round_end_screen.visible = false

	var spawned_position_data: Array[Dictionary] = []
	for candidate_data in generated_positions:
		var preview_transform: Transform3D = candidate_data["transform"]
		var preview_node: Node3D = _spawn_hazard_preview(_pending_hazard_type, preview_transform)
		if preview_node == null:
			continue

		_hazard_position_previews.append(preview_node)
		spawned_position_data.append(candidate_data)

	if _hazard_position_previews.size() < HAZARD_POSITION_CANDIDATE_COUNT:
		push_warning("MainSceneController failed to prepare %d hazard placement previews." % HAZARD_POSITION_CANDIDATE_COUNT)
		_clear_hazard_position_selection()
		_pending_hazard_type = HazardTypeRegistry.NONE
		_start_next_round()
		return

	_hazard_position_data = spawned_position_data
	_is_hazard_position_selection_active = true
	_hazard_focused_index = 0
	_update_hazard_preview_focus()
	_focus_camera_on(_hazard_position_previews[_hazard_focused_index], true)
	_update_car_controls()
	_update_placement_overlay()


func _confirm_hazard_position() -> void:
	if not _is_hazard_position_selection_active:
		return
	if _hazard_position_previews.is_empty():
		return

	var safe_index: int = clampi(_hazard_focused_index, 0, _hazard_position_previews.size() - 1)
	var chosen_preview: Node3D = _hazard_position_previews[safe_index]
	if chosen_preview == null:
		return

	HazardPreviewHelper.set_preview(chosen_preview, false, true, true)
	_clear_hazard_position_selection(chosen_preview)

	var base_name: String = HazardTypeRegistry.get_node_name(_pending_hazard_type)
	chosen_preview.name = "%s%d" % [base_name, _count_hazards_with_base_name(base_name, chosen_preview) + 1]
	_pending_hazard_type = HazardTypeRegistry.NONE
	_update_car_controls()
	_update_placement_overlay()
	_start_next_round()


func _cycle_hazard_position(direction: int) -> void:
	if _hazard_position_previews.is_empty():
		return

	var next_index: int = _hazard_focused_index + direction
	_focus_hazard_position(next_index)


func _focus_hazard_position(index: int) -> void:
	if _hazard_position_previews.is_empty():
		return

	_hazard_focused_index = wrapi(index, 0, _hazard_position_previews.size())
	_update_hazard_preview_focus()
	var focused_preview: Node3D = _hazard_position_previews[_hazard_focused_index]
	_focus_camera_on(focused_preview, true)
	_update_placement_overlay()


func _generate_hazard_positions() -> Array[Dictionary]:
	var generated_positions: Array[Dictionary] = []
	if _track == null:
		return generated_positions

	var occupied_positions: Array[Vector3] = _get_occupied_track_item_positions()
	var max_lateral_offset: float = _track.get_max_lateral_offset(boost_pad_track_clearance)

	var attempts: int = 0
	while generated_positions.size() < HAZARD_POSITION_CANDIDATE_COUNT and attempts < HAZARD_POSITION_MAX_ATTEMPTS:
		attempts += 1

		var progress: float = randf()
		var lateral_offset: float = randf_range(-max_lateral_offset, max_lateral_offset)
		if not _track.is_track_position_valid(progress, lateral_offset, boost_pad_track_clearance):
			continue

		var candidate_transform: Transform3D = _track.get_track_transform(progress, lateral_offset)
		var candidate_position: Vector3 = candidate_transform.origin
		if _is_hazard_position_blocked(candidate_position, occupied_positions):
			continue

		occupied_positions.append(candidate_position)
		generated_positions.append({
			"progress": progress,
			"lateral_offset": lateral_offset,
			"transform": candidate_transform,
		})

	if generated_positions.size() < HAZARD_POSITION_CANDIDATE_COUNT:
		return []

	return generated_positions


func _update_placement_input(delta: float) -> void:
	var progress_input: float = Input.get_action_strength("throttle") - Input.get_action_strength("brake")
	var lateral_input: float = Input.get_action_strength("steer_left") - Input.get_action_strength("steer_right")
	var max_lateral_offset: float = _track.get_max_lateral_offset(boost_pad_track_clearance)

	_placement_progress = wrapf(_placement_progress + progress_input * placement_progress_speed * delta, 0.0, 1.0)
	_placement_lateral_offset = clampf(
		_placement_lateral_offset + lateral_input * placement_lateral_speed * delta,
		-max_lateral_offset,
		max_lateral_offset
	)


func _update_placement_preview() -> void:
	if not _track or not _placement_preview:
		return

	var preview_transform: Transform3D = _track.get_track_transform(_placement_progress, _placement_lateral_offset)
	var can_place: bool = _can_place_boost_pad(_placement_progress, _placement_lateral_offset)
	_placement_preview.global_transform = preview_transform
	_placement_preview.set_preview_valid(can_place)
	_update_placement_overlay()


func _spawn_placement_preview() -> void:
	_clear_placement_preview()
	if _boost_pad_root == null:
		_ensure_boost_pad_root()
	if _boost_pad_root == null:
		return

	_placement_preview = BOOST_PAD_SCENE.instantiate() as BoostPad
	if _placement_preview == null:
		push_warning("MainSceneController failed to instantiate the boost pad preview.")
		return

	_placement_preview.name = "BoostPadPreview"
	_placement_preview.set_preview_mode(true)
	_boost_pad_root.add_child(_placement_preview)


func _clear_placement_preview() -> void:
	if _placement_preview == null:
		return

	_placement_preview.queue_free()
	_placement_preview = null


func _clear_hazard_position_selection(kept_preview: Node3D = null) -> void:
	for preview in _hazard_position_previews:
		if preview == null or preview == kept_preview:
			continue
		preview.queue_free()

	_hazard_position_previews.clear()
	_hazard_position_data.clear()
	_hazard_focused_index = 0
	_is_hazard_position_selection_active = false


func _update_hazard_preview_focus() -> void:
	for preview_index in range(_hazard_position_previews.size()):
		var preview: Node3D = _hazard_position_previews[preview_index]
		if preview == null:
			continue
		HazardPreviewHelper.set_preview_focus(preview, preview_index == _hazard_focused_index)


func _ensure_boost_pad_root() -> void:
	if _track == null:
		return

	_boost_pad_root = _track.get_node_or_null("BoostPads") as Node3D
	if _boost_pad_root:
		return

	_boost_pad_root = Node3D.new()
	_boost_pad_root.name = "BoostPads"
	_track.add_child(_boost_pad_root)


func _ensure_hazard_root() -> void:
	if _track == null:
		return

	_hazard_root = _track.get_node_or_null("Hazards") as Node3D
	if _hazard_root:
		return

	_hazard_root = Node3D.new()
	_hazard_root.name = "Hazards"
	_track.add_child(_hazard_root)


func _ensure_placement_overlay() -> void:
	if _placement_overlay != null and _placement_label != null:
		return

	_placement_overlay = CanvasLayer.new()
	_placement_overlay.name = "TrackPlacementOverlay"
	_placement_overlay.layer = 3
	add_child(_placement_overlay)

	_placement_label = Label.new()
	_placement_label.name = "PlacementLabel"
	_placement_label.position = PLACEMENT_LABEL_MARGIN
	_placement_label.add_theme_font_size_override("font_size", 22)
	_placement_label.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0, 1.0))
	_placement_label.add_theme_color_override("font_outline_color", Color(0.05, 0.06, 0.08, 0.95))
	_placement_label.add_theme_constant_override("outline_size", 5)
	_placement_overlay.add_child(_placement_label)


func _update_placement_overlay() -> void:
	if _placement_overlay == null or _placement_label == null:
		return

	_placement_overlay.visible = _is_placement_active or _is_hazard_position_selection_active
	if not _placement_overlay.visible:
		return

	if _is_placement_active:
		var is_on_valid_track: bool = _track != null and _track.is_track_position_valid(
			_placement_progress,
			_placement_lateral_offset,
			boost_pad_track_clearance
		)
		var is_overlapping_existing_pad: bool = false
		if is_on_valid_track:
			var placement_position: Vector3 = _track.get_track_transform(_placement_progress, _placement_lateral_offset).origin
			is_overlapping_existing_pad = _does_boost_pad_overlap_existing(placement_position)

		var can_place: bool = is_on_valid_track and not is_overlapping_existing_pad
		var remaining_after_place: int = maxi(_pending_boost_pad_count - 1, 0)
		var status_text: String = "Ready to place on tarmac"
		if not is_on_valid_track:
			status_text = "Move onto the tarmac to place"
		elif is_overlapping_existing_pad:
			status_text = "Move away from another boost pad"

		_placement_label.text = "Place Boost Pad\nThrottle / Brake: move around the track\nSteer: shift across the lane\nSpace / Enter: place\n%s\nPads left after this: %d" % [
			status_text,
			remaining_after_place,
		]
		_placement_label.modulate = Color(0.95, 0.97, 1.0, 1.0) if can_place else Color(1.0, 0.72, 0.68, 1.0)
		return

	var total_positions: int = maxi(_hazard_position_data.size(), 1)
	var focused_position: int = mini(_hazard_focused_index + 1, total_positions)
	_placement_label.text = "Place %s\nPosition %d/%d\nSteer / 1-%d: browse positions\nSpace / Enter: confirm" % [
		HazardTypeRegistry.get_display_name(_pending_hazard_type),
		focused_position,
		total_positions,
		total_positions,
	]
	_placement_label.modulate = Color(1.0, 0.9, 0.72, 1.0)


func _update_car_controls() -> void:
	if _car == null:
		return

	var controls_should_be_enabled: bool = _run_state != null \
		and _run_state.is_round_active \
		and not _is_placement_active \
		and not _is_hazard_position_selection_active
	_car.set_controls_enabled(controls_should_be_enabled)


func _focus_camera_on(target: Node3D, snap: bool) -> void:
	if _camera == null or target == null:
		return

	_camera.target = target
	if snap:
		_camera.snap_to_target()


func _can_place_boost_pad(progress: float, lateral_offset: float) -> bool:
	if _track == null:
		return false
	if not _track.is_track_position_valid(progress, lateral_offset, boost_pad_track_clearance):
		return false

	var placement_position: Vector3 = _track.get_track_transform(progress, lateral_offset).origin
	return not _does_boost_pad_overlap_existing(placement_position)


func _does_boost_pad_overlap_existing(placement_position: Vector3) -> bool:
	if _boost_pad_root == null:
		return false

	var minimum_center_distance: float = BOOST_PAD_FOOTPRINT_RADIUS * 2.0
	var placement_point: Vector2 = Vector2(placement_position.x, placement_position.z)
	for child in _boost_pad_root.get_children():
		var existing_pad: BoostPad = child as BoostPad
		if existing_pad == null or existing_pad == _placement_preview:
			continue

		var existing_position: Vector3 = existing_pad.global_transform.origin
		var existing_point: Vector2 = Vector2(existing_position.x, existing_position.z)
		if placement_point.distance_to(existing_point) < minimum_center_distance:
			return true

	return false


func _get_hazard_draft_options() -> Array[int]:
	if not _should_require_hazard_draft():
		return []
	var all_types: Array[int] = HazardTypeRegistry.get_available_types()
	all_types.shuffle()
	var offered: Array[int] = []
	for i in range(mini(HAZARD_DRAFT_OPTION_COUNT, all_types.size())):
		offered.append(all_types[i])
	return offered


func _should_require_hazard_draft() -> bool:
	return _run_state != null and _run_state.round_number >= 1


func _has_pending_hazard_draft() -> bool:
	return HazardTypeRegistry.is_valid_type(_pending_hazard_type)


func _spawn_hazard_preview(hazard_type: int, preview_transform: Transform3D) -> Node3D:
	var preview_scene: PackedScene = load(HazardTypeRegistry.get_scene_path(hazard_type)) as PackedScene
	if preview_scene == null:
		push_warning("MainSceneController failed to load a hazard scene for type %d." % hazard_type)
		return null

	var preview_node: Node3D = preview_scene.instantiate() as Node3D
	if preview_node == null:
		push_warning("MainSceneController failed to instantiate a hazard preview for type %d." % hazard_type)
		return null

	preview_node.name = "%sPreview" % HazardTypeRegistry.get_node_name(hazard_type)
	HazardPreviewHelper.set_preview(preview_node, true, true, false)
	_hazard_root.add_child(preview_node)
	preview_node.global_transform = preview_transform
	return preview_node


func _get_occupied_track_item_positions() -> Array[Vector3]:
	var occupied_positions: Array[Vector3] = []
	occupied_positions.append(_get_car_start_transform().origin)
	_append_track_item_positions(_boost_pad_root, occupied_positions)
	_append_track_item_positions(_hazard_root, occupied_positions)
	return occupied_positions


func _append_track_item_positions(root: Node3D, occupied_positions: Array[Vector3]) -> void:
	if root == null:
		return

	for child in root.get_children():
		var track_item: Node3D = child as Node3D
		if track_item == null or track_item == _placement_preview:
			continue
		occupied_positions.append(track_item.global_transform.origin)


func _count_hazards_with_base_name(base_name: String, exclude: Node3D = null) -> int:
	if _hazard_root == null:
		return 0
	var count: int = 0
	for child in _hazard_root.get_children():
		if child == exclude:
			continue
		if child.name.begins_with(base_name):
			count += 1
	return count


func _is_hazard_position_blocked(candidate_position: Vector3, occupied_positions: Array[Vector3]) -> bool:
	for occupied_position in occupied_positions:
		if occupied_position.distance_to(candidate_position) < _min_hazard_distance:
			return true
	return false


func _get_car_start_transform() -> Transform3D:
	if _track != null:
		return _track.get_start_transform(_car_spawn_transform.origin.y)
	return _car_spawn_transform
