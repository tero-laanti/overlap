class_name MainSceneController
extends Node3D

const BOOST_PAD_SCENE: PackedScene = preload("res://race/boost_pad.tscn")
const PLACEMENT_LABEL_MARGIN := Vector2(24.0, 24.0)

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

var _track: TestTrack = null
var _car: Car = null
var _run_state: RunState = null
var _round_end_screen: RoundEndScreen = null
var _camera: GameCamera = null
var _car_spawn_transform: Transform3D = Transform3D.IDENTITY
var _pending_start_time_bonus: float = 0.0
var _pending_boost_pad_count: int = 0
var _boost_pad_root: Node3D = null
var _placement_overlay: CanvasLayer = null
var _placement_label: Label = null
var _placement_preview: BoostPad = null
var _placement_progress: float = 0.0
var _placement_lateral_offset: float = 0.0
var _is_placement_active: bool = false


func _ready() -> void:
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
	_ensure_placement_overlay()

	if _round_end_screen:
		_round_end_screen.configure_buy_time_option(buy_time_cost, buy_time_seconds)
		_round_end_screen.configure_buy_boost_pad_option(buy_boost_pad_cost)
		_round_end_screen.set_pending_start_time_bonus(_pending_start_time_bonus)
		_round_end_screen.set_pending_boost_pad_count(_pending_boost_pad_count)

		if not _round_end_screen.buy_time_requested.is_connected(_on_buy_time_requested):
			_round_end_screen.buy_time_requested.connect(_on_buy_time_requested)
		if not _round_end_screen.buy_boost_pad_requested.is_connected(_on_buy_boost_pad_requested):
			_round_end_screen.buy_boost_pad_requested.connect(_on_buy_boost_pad_requested)
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
	if not _is_placement_active or event.is_echo():
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


func _on_continue_requested() -> void:
	if not _car or not _run_state or _run_state.is_round_active or _is_placement_active:
		return

	if _pending_boost_pad_count > 0:
		_begin_boost_pad_placement()
		return

	_start_next_round()


func _on_round_finished() -> void:
	_update_car_controls()


func _on_round_started(_round_number: int) -> void:
	_is_placement_active = false
	_clear_placement_preview()
	_update_car_controls()
	_update_placement_overlay()
	_focus_camera_on(_car, false)


func _start_next_round() -> void:
	if not _car or not _run_state or _run_state.is_round_active:
		return

	var extra_start_time: float = _pending_start_time_bonus
	_pending_start_time_bonus = 0.0
	if _round_end_screen:
		_round_end_screen.set_pending_start_time_bonus(_pending_start_time_bonus)
		_round_end_screen.set_pending_boost_pad_count(_pending_boost_pad_count)

	_car.reset_to_transform(_car_spawn_transform)
	_focus_camera_on(_car, true)
	_run_state.start_round(extra_start_time)


func _begin_boost_pad_placement() -> void:
	if not _track or BOOST_PAD_SCENE == null:
		_start_next_round()
		return

	_is_placement_active = true
	_placement_lateral_offset = clampf(
		_placement_lateral_offset,
		-_track.get_boost_pad_max_lateral_offset(boost_pad_track_clearance),
		_track.get_boost_pad_max_lateral_offset(boost_pad_track_clearance)
	)

	if _car:
		_car.reset_to_transform(_car_spawn_transform)

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

	var can_place: bool = _track.is_boost_pad_position_valid(
		_placement_progress,
		_placement_lateral_offset,
		boost_pad_track_clearance
	)
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
	else:
		_is_placement_active = false
		_update_placement_overlay()
		_focus_camera_on(_car, true)
		_start_next_round()


func _update_placement_input(delta: float) -> void:
	var progress_input: float = Input.get_action_strength("throttle") - Input.get_action_strength("brake")
	var lateral_input: float = Input.get_action_strength("steer_right") - Input.get_action_strength("steer_left")
	var max_lateral_offset: float = _track.get_boost_pad_max_lateral_offset(boost_pad_track_clearance)

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
	var can_place: bool = _track.is_boost_pad_position_valid(
		_placement_progress,
		_placement_lateral_offset,
		boost_pad_track_clearance
	)
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


func _ensure_boost_pad_root() -> void:
	if _track == null:
		return

	_boost_pad_root = _track.get_node_or_null("BoostPads") as Node3D
	if _boost_pad_root:
		return

	_boost_pad_root = Node3D.new()
	_boost_pad_root.name = "BoostPads"
	_track.add_child(_boost_pad_root)


func _ensure_placement_overlay() -> void:
	if _placement_overlay != null and _placement_label != null:
		return

	_placement_overlay = CanvasLayer.new()
	_placement_overlay.name = "BoostPadPlacementOverlay"
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

	_placement_overlay.visible = _is_placement_active
	if not _is_placement_active:
		return

	var can_place: bool = _track != null and _track.is_boost_pad_position_valid(
		_placement_progress,
		_placement_lateral_offset,
		boost_pad_track_clearance
	)
	var remaining_after_place: int = maxi(_pending_boost_pad_count - 1, 0)
	var status_text: String = "Ready to place on tarmac"
	if not can_place:
		status_text = "Move onto the tarmac to place"

	_placement_label.text = "Place Boost Pad\nThrottle / Brake: move around the track\nSteer: shift across the lane\nSpace / Enter: place\n%s\nPads left after this: %d" % [
		status_text,
		remaining_after_place,
	]
	_placement_label.modulate = Color(0.95, 0.97, 1.0, 1.0) if can_place else Color(1.0, 0.72, 0.68, 1.0)


func _update_car_controls() -> void:
	if _car == null:
		return

	var controls_should_be_enabled: bool = _run_state != null and _run_state.is_round_active and not _is_placement_active
	_car.set_controls_enabled(controls_should_be_enabled)


func _focus_camera_on(target: Node3D, snap: bool) -> void:
	if _camera == null or target == null:
		return

	_camera.target = target
	if snap:
		_camera.snap_to_target()
