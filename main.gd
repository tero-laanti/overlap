class_name MainSceneController
extends Node3D

const HazardTypeRegistry := preload("res://race/hazard_type.gd")
const PositiveTypeRegistry := preload("res://race/positive_type.gd")
const COIN_SCENE: PackedScene = preload("res://race/coin.tscn")
const TRACK_COIN_ROOT_NAME := "Coins"
const TRACK_POSITIVE_ROOT_NAME := "Positives"
const COIN_TRACK_Y_OFFSET := 0.01
const COIN_PLACEMENT_BAND_ATTEMPTS := 5
const COIN_PLACEMENT_FALLBACK_ATTEMPTS := 48
const COIN_PROGRESS_JITTER_RATIO := 0.35
const COIN_TRACK_CLEARANCE := 1.25
const COIN_MIN_OCCUPIED_DISTANCE := 3.0
const COIN_LATERAL_OFFSET_RATIO := 0.2
const TRACK_ITEM_PLACEMENT_SAMPLE_CLEARANCE := 1.0
const CAR_START_CLEARANCE := 0.12
const TRACK_ITEM_FOOTPRINT_SAMPLES := [
	Vector2.ZERO,
	Vector2(-1.0, 0.0),
	Vector2(1.0, 0.0),
	Vector2(0.0, -1.0),
	Vector2(0.0, 1.0),
	Vector2(-1.0, -1.0),
	Vector2(-1.0, 1.0),
	Vector2(1.0, -1.0),
	Vector2(1.0, 1.0),
]
const PLACEMENT_LABEL_MARGIN := Vector2(24.0, 24.0)
const PLACEMENT_PANEL_MIN_WIDTH := 360.0
const HAZARD_DRAFT_OPTION_COUNT := 2
const PLACEMENT_PANEL_BG := Color(0.08, 0.1, 0.14, 0.9)
const PLACEMENT_PANEL_BORDER := Color(0.48, 0.58, 0.72, 0.5)
const PLACEMENT_WARNING_BORDER := Color(1.0, 0.45, 0.35, 0.9)
const PLACEMENT_TEXT_COLOR := Color(0.95, 0.97, 1.0, 1.0)
const PLACEMENT_WARNING_TEXT_COLOR := Color(1.0, 0.78, 0.72, 1.0)

@export var track_path: NodePath
@export var car_path: NodePath
@export var run_state_path: NodePath
@export var round_end_screen_path: NodePath
@export var camera_path: NodePath
@export_range(0, 32, 1) var coin_count: int = 6
@export var placement_progress_speed: float = 0.18
@export var placement_lateral_speed: float = 7.0
@export var boost_pad_track_clearance: float = 1.5
## Fixed RNG seed for deterministic runs. 0 = use randomize() (non-deterministic).
@export var deterministic_seed: int = 0
## World Y below which the car is considered fallen off the map and gets
## respawned at the start line. Guards against high-speed overshoots that
## clear the ground collider.
@export var fall_respawn_y: float = -10.0

@export_group("Track Mutation")
@export var track_mutation_enabled: bool = true
## The first round after which the track starts mutating. Round 1 plays
## on the authored layout so players establish a baseline racing line.
@export_range(2, 32, 1) var track_mutation_start_round: int = 2

@export_group("Debug")
## Prints per-round lap times to stdout when true. Lets playtest sessions
## show how detours reshape lap pacing across a run.
@export var debug_round_telemetry: bool = false

var _track: TestTrack = null
var _car: Car = null
var _run_state: RunState = null
var _round_end_screen: RoundEndScreen = null
var _camera: GameCamera = null
var _car_spawn_transform: Transform3D = Transform3D.IDENTITY
var _default_vehicle_scene: PackedScene = null
var _default_vehicle_scene_path: String = ""
var _current_positive_offers: Array[int] = []
var _pending_positive_queue: Array[int] = []
var _positive_root: Node3D = null
var _placement_overlay: CanvasLayer = null
var _placement_panel: PanelContainer = null
var _placement_label: Label = null
var _placement_preview: Node3D = null
var _placement_preview_type: int = PositiveTypeRegistry.NONE
var _placement_progress: float = 0.0
var _placement_lateral_offset: float = 0.0
var _is_placement_active: bool = false
var _track_mutator: TrackMutator = TrackMutator.new()
var _round_lap_times: Array[float] = []
var _pause_menu: PauseMenu = null

@onready var _hazard_controller: HazardPlacementController = $HazardPlacementController
@onready var _mutation_preview: MutationPreviewController = $MutationPreviewController


func _ready() -> void:
	if deterministic_seed == 0:
		randomize()
	else:
		seed(deterministic_seed)
	_track = get_node_or_null(track_path) as TestTrack
	if _track == null:
		_track = get_node_or_null("Track") as TestTrack
	_car = get_node_or_null(car_path) as Car
	_run_state = get_node_or_null(run_state_path) as RunState
	_round_end_screen = get_node_or_null(round_end_screen_path) as RoundEndScreen
	_camera = get_node_or_null(camera_path) as GameCamera
	_cache_default_vehicle_scene()

	if not _track:
		push_warning("MainSceneController could not find the track.")
	else:
		var game_session: Node = _get_game_session()
		if game_session != null:
			_track.set_starter_layout_index(int(game_session.get("selected_track_index")))

	# Must run after the track's active layout is resolved (so we can read the
	# layout's preferred vehicle) and before `_car_spawn_transform` is captured
	# or any eager consumer is rebound (pause menu, coin rebuild).
	apply_preferred_vehicle()

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

	_ensure_positive_root()
	_hazard_controller.configure(_track, boost_pad_track_clearance)
	_mutation_preview.configure(_track, _camera)
	_rebuild_track_coins()
	_ensure_placement_overlay()
	_ensure_pause_menu()

	if not _hazard_controller.placement_begun.is_connected(_on_hazard_placement_begun):
		_hazard_controller.placement_begun.connect(_on_hazard_placement_begun)
	if not _hazard_controller.focus_changed.is_connected(_on_hazard_focus_changed):
		_hazard_controller.focus_changed.connect(_on_hazard_focus_changed)
	if not _hazard_controller.placement_confirmed.is_connected(_on_hazard_placement_resolved):
		_hazard_controller.placement_confirmed.connect(_on_hazard_placement_resolved)
	if not _hazard_controller.placement_abandoned.is_connected(_on_hazard_placement_resolved):
		_hazard_controller.placement_abandoned.connect(_on_hazard_placement_resolved)

	if _round_end_screen:
		_round_end_screen.configure_positive_offers(_current_positive_offers)
		_round_end_screen.set_pending_positive_types(_pending_positive_queue)
		_round_end_screen.clear_hazard_draft()

		if not _round_end_screen.positive_offer_requested.is_connected(_on_positive_offer_requested):
			_round_end_screen.positive_offer_requested.connect(_on_positive_offer_requested)
		if not _round_end_screen.hazard_drafted.is_connected(_on_hazard_drafted):
			_round_end_screen.hazard_drafted.connect(_on_hazard_drafted)
		if not _round_end_screen.continue_requested.is_connected(_on_continue_requested):
			_round_end_screen.continue_requested.connect(_on_continue_requested)

	if _run_state:
		_run_state.set_external_clock_driver(true)
		if not _run_state.round_finished.is_connected(_on_round_finished):
			_run_state.round_finished.connect(_on_round_finished)
		if not _run_state.round_started.is_connected(_on_round_started):
			_run_state.round_started.connect(_on_round_started)
		if not _run_state.time_bank_cost_changed.is_connected(_on_time_bank_cost_changed):
			_run_state.time_bank_cost_changed.connect(_on_time_bank_cost_changed)
		if not _run_state.run_failed.is_connected(_on_run_failed):
			_run_state.run_failed.connect(_on_run_failed)
		if not _run_state.last_lap_time_changed.is_connected(_on_last_lap_time_changed):
			_run_state.last_lap_time_changed.connect(_on_last_lap_time_changed)

	if _track:
		_placement_progress = _track.get_lap_start_progress()
		if _car:
			_car.reset_to_transform(_get_car_start_transform())

	_focus_camera_on(_car, false)
	_update_car_controls()
	_update_placement_overlay()


func _physics_process(delta: float) -> void:
	if _run_state:
		_run_state.advance_round_clock(delta)
	_respawn_car_if_fallen()


func _respawn_car_if_fallen() -> void:
	if _car == null:
		return
	if _run_state == null or not _run_state.is_round_active:
		return
	if _car.global_position.y < fall_respawn_y:
		_car.reset_to_transform(_get_car_start_transform())


## Swaps the live Car to match the active layout: `preferred_vehicle` when set,
## otherwise the main-scene default cached from the original `Car` child. Kept
## public so validators can re-exercise the path after forcing a layout change
## without re-entering `_ready`.
func apply_preferred_vehicle() -> void:
	if _track == null or _car == null:
		return
	var desired_vehicle_scene: PackedScene = _get_desired_vehicle_scene()
	if desired_vehicle_scene == null:
		return
	var desired_vehicle_path: String = desired_vehicle_scene.resource_path
	if desired_vehicle_path.is_empty():
		desired_vehicle_path = _default_vehicle_scene_path
	if not desired_vehicle_path.is_empty() and _car.scene_file_path == desired_vehicle_path:
		return

	var old_car: Car = _car
	var parent: Node = old_car.get_parent()
	if parent == null:
		return
	var new_car: Car = desired_vehicle_scene.instantiate() as Car
	if new_car == null:
		push_warning("MainSceneController preferred_vehicle did not instantiate a Car.")
		return
	var spawn_transform: Transform3D = old_car.global_transform
	var sibling_index: int = old_car.get_index()
	var old_name: StringName = old_car.name
	var old_car_was_frozen: bool = old_car.is_frozen()
	var old_controls_enabled: bool = old_car.controls_enabled
	parent.remove_child(old_car)
	# `queue_free()` on a just-detached car leaves a valid-but-out-of-tree node
	# around until an idle frame flushes the queue. Lazy readers such as
	# LapTracker can hit that stale reference window, so retire the old vehicle
	# immediately once the replacement is ready.
	old_car.free()
	new_car.name = old_name
	parent.add_child(new_car)
	parent.move_child(new_car, sibling_index)
	# `reset_to_transform` syncs the proxy and resets physics interpolation —
	# needed because each controller's `_ready` teleports the proxy to whatever
	# `global_transform` was at instantiate time (identity), not to the real
	# spawn pose.
	new_car.reset_to_transform(spawn_transform)
	new_car.set_frozen(old_car_was_frozen)
	new_car.set_controls_enabled(old_controls_enabled)
	_car = new_car

	_rebind_eager_car_consumers()


func _cache_default_vehicle_scene() -> void:
	if _car == null:
		return
	if not _default_vehicle_scene_path.is_empty() and _default_vehicle_scene != null:
		return
	_default_vehicle_scene_path = _car.scene_file_path
	if _default_vehicle_scene_path.is_empty():
		push_warning("MainSceneController could not resolve the default vehicle scene path.")
		return
	_default_vehicle_scene = load(_default_vehicle_scene_path) as PackedScene
	if _default_vehicle_scene == null:
		push_warning("MainSceneController failed to load the default vehicle scene %s." % _default_vehicle_scene_path)


func _get_desired_vehicle_scene() -> PackedScene:
	# Priority: track's hard preference > player's car pick > main.tscn
	# default. The track-author intent wins because certain layouts are
	# designed around a specific controller — the picker controller_label
	# is a hint, not a guarantee.
	var active_layout: TrackLayout = _track.get_active_layout() if _track != null else null
	if active_layout != null and active_layout.preferred_vehicle != null:
		return active_layout.preferred_vehicle
	var car_option: CarOption = CarOptions.get_option(_read_selected_car_index())
	if car_option != null and car_option.controller_override != null:
		return car_option.controller_override
	return _default_vehicle_scene


func _read_selected_car_index() -> int:
	var game_session: Node = _get_game_session()
	if game_session == null:
		return 0
	return int(game_session.get("selected_car_index"))


func _rebind_eager_car_consumers() -> void:
	# Eagerly-resolved consumers need fresh references; lazy ones (LapTracker,
	# hazards resolving through body collisions) re-hydrate on their own tick.
	if _camera != null:
		_camera.target = _car
	var run_hud: RunHUD = get_node_or_null(^"RunHUD") as RunHUD
	if run_hud != null:
		run_hud.set_car(_car)
	if _pause_menu != null:
		_pause_menu.bind_car(_car)


func _process(delta: float) -> void:
	if not _is_placement_active or not _track:
		return

	_update_placement_input(delta)
	_update_placement_preview()


func _get_game_session() -> Node:
	var scene_tree: SceneTree = get_tree()
	if scene_tree == null:
		return null
	return scene_tree.root.get_node_or_null(^"GameSession")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return

	if _mutation_preview.is_active():
		if event.is_action_pressed("continue_round") or event.is_action_pressed("place_boost_pad"):
			get_viewport().set_input_as_handled()
			_dismiss_mutation_preview()
		return

	if _hazard_controller.is_active():
		if event.is_action_pressed("steer_left"):
			get_viewport().set_input_as_handled()
			_hazard_controller.cycle(-1)
		elif event.is_action_pressed("steer_right"):
			get_viewport().set_input_as_handled()
			_hazard_controller.cycle(1)
		elif event.is_action_pressed("draft_hazard_1"):
			get_viewport().set_input_as_handled()
			_hazard_controller.focus_index(0)
		elif event.is_action_pressed("draft_hazard_2"):
			get_viewport().set_input_as_handled()
			_hazard_controller.focus_index(1)
		elif event.is_action_pressed("draft_hazard_3"):
			get_viewport().set_input_as_handled()
			_hazard_controller.focus_index(2)
		elif event.is_action_pressed("place_boost_pad"):
			get_viewport().set_input_as_handled()
			_hazard_controller.confirm()
		return

	if not _is_placement_active:
		return
	if event.is_action_pressed("place_boost_pad"):
		get_viewport().set_input_as_handled()
		_confirm_positive_placement()


func _on_positive_offer_requested(offer_index: int) -> void:
	if _run_state == null or _run_state.is_round_active:
		return
	if offer_index < 0 or offer_index >= _current_positive_offers.size():
		return

	var positive_type: int = _current_positive_offers[offer_index]
	var delivery_mode: int = PositiveTypeRegistry.get_delivery_mode(positive_type)
	if delivery_mode == PositiveTypeRegistry.DeliveryMode.INSTANT:
		if not _try_apply_instant_positive(positive_type):
			return
	else:
		var cost: int = PositiveTypeRegistry.get_base_cost(positive_type)
		if cost <= 0 or not _run_state.spend_currency(cost):
			return
		_pending_positive_queue.append(positive_type)

	_sync_round_end_screen()


func _try_apply_instant_positive(positive_type: int) -> bool:
	if positive_type == PositiveTypeRegistry.Type.TIME_BANK:
		return _run_state.try_buy_time_bank() > 0.0
	push_warning("MainSceneController has no handler for instant positive type %d." % positive_type)
	return false


func _on_time_bank_cost_changed(_cost: int) -> void:
	_sync_round_end_screen()


func _on_hazard_drafted(hazard_type: int) -> void:
	_hazard_controller.set_pending_hazard_type(hazard_type)


func _on_continue_requested() -> void:
	if not _car or not _run_state or _run_state.is_round_active:
		return
	if _is_placement_active or _hazard_controller.is_active():
		return
	if _should_require_hazard_draft() and not _hazard_controller.has_pending_draft():
		return

	if not _pending_positive_queue.is_empty():
		_begin_positive_placement()
		return

	if _hazard_controller.has_pending_draft():
		_begin_hazard_position_selection()
		return

	_start_next_round()


func _on_round_finished() -> void:
	_log_round_telemetry()
	var mutation_result: TrackMutationResult = _mutate_track_if_needed()
	_current_positive_offers = _get_positive_offer_types()
	_hazard_controller.clear_pending()
	if _car:
		_car.set_frozen(true)
	if _round_end_screen:
		_round_end_screen.configure_positive_offers(_current_positive_offers)
		_round_end_screen.set_pending_positive_types(_pending_positive_queue)
		_round_end_screen.configure_hazard_draft(_get_hazard_draft_options())
	_update_car_controls()

	if mutation_result.changed:
		if _round_end_screen:
			_round_end_screen.visible = false
		_mutation_preview.show_preview(mutation_result)


func _mutate_track_if_needed() -> TrackMutationResult:
	var empty_result: TrackMutationResult = TrackMutationResult.new()
	if not track_mutation_enabled:
		return empty_result
	if _track == null or _run_state == null:
		return empty_result
	if _run_state.round_number < track_mutation_start_round:
		return empty_result

	var active_layout: TrackLayout = _track.get_active_layout()
	if active_layout == null:
		return empty_result

	var result: TrackMutationResult = _track_mutator.mutate_layout(
		active_layout,
		_get_occupied_track_item_positions()
	)
	if result.changed and result.layout != null and result.layout != active_layout:
		_track.set_active_layout(result.layout)
	return result


## Hides the mutation preview and, when the user dismissed it mid-pit-stop,
## restores the game camera and round-end screen. Called from input
## handling as well as the run-failed / round-started cleanup paths via
## `_mutation_preview.hide_preview()` directly — this helper is only the
## "user pressed continue" branch.
func _dismiss_mutation_preview() -> void:
	_mutation_preview.hide_preview()
	if _run_state and _run_state.is_run_over:
		return
	if _run_state and _run_state.is_round_active:
		return
	if _car:
		_focus_camera_on(_car, true)
	if _round_end_screen:
		_round_end_screen.visible = true


func _on_last_lap_time_changed(lap_time: float) -> void:
	if lap_time <= 0.0:
		return
	_round_lap_times.append(lap_time)


func _log_round_telemetry() -> void:
	if not debug_round_telemetry or _run_state == null:
		return

	var formatted_times: PackedStringArray = PackedStringArray()
	for lap_time in _round_lap_times:
		formatted_times.append("%.2fs" % lap_time)

	print(
		"[round-telemetry] round=%d laps=%d times=[%s]" % [
			_run_state.round_number,
			_round_lap_times.size(),
			", ".join(formatted_times),
		]
	)


func _on_run_failed(_last_round_number: int, _final_currency: int) -> void:
	# The GameOverScreen handles the UI; main just has to make sure nothing
	# drifts into the pit-stop flow — no hazard draft, car stays frozen, no
	# lingering placement preview or mutation preview.
	_current_positive_offers.clear()
	_pending_positive_queue.clear()
	_hazard_controller.clear_pending()
	_is_placement_active = false
	_clear_placement_preview()
	_mutation_preview.hide_preview()
	if _car:
		_car.set_frozen(true)
	if _round_end_screen:
		_round_end_screen.visible = false
		_round_end_screen.clear_positive_offers()
		_round_end_screen.set_pending_positive_types(_pending_positive_queue)
		_round_end_screen.clear_hazard_draft()
	_update_car_controls()
	_update_placement_overlay()


func _on_round_started(_round_number: int) -> void:
	_current_positive_offers.clear()
	_pending_positive_queue.clear()
	_is_placement_active = false
	_clear_placement_preview()
	_mutation_preview.hide_preview()
	_hazard_controller.clear_selection()
	_hazard_controller.clear_pending()
	_round_lap_times.clear()
	_rebuild_track_coins()
	if _car:
		_car.set_frozen(false)
	if _round_end_screen:
		_round_end_screen.clear_positive_offers()
		_round_end_screen.set_pending_positive_types(_pending_positive_queue)
		_round_end_screen.clear_hazard_draft()
	_update_car_controls()
	_update_placement_overlay()
	_focus_camera_on(_car, false)


func _sync_round_end_screen() -> void:
	if _round_end_screen == null or _run_state == null:
		return

	_round_end_screen.configure_positive_offers(_current_positive_offers)
	_round_end_screen.set_pending_positive_types(_pending_positive_queue)


func _start_next_round() -> void:
	if not _car or not _run_state or _run_state.is_round_active:
		return
	if _is_placement_active or _hazard_controller.is_active():
		return
	if not _pending_positive_queue.is_empty():
		_begin_positive_placement()
		return

	_car.reset_to_transform(_get_car_start_transform())
	_focus_camera_on(_car, true)
	_run_state.start_round()


func _begin_positive_placement() -> void:
	if not _track or _pending_positive_queue.is_empty():
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
	if _placement_preview == null:
		if not _pending_positive_queue.is_empty():
			_pending_positive_queue.remove_at(0)
			_sync_round_end_screen()
		_is_placement_active = false
		_update_car_controls()
		_update_placement_overlay()
		if not _pending_positive_queue.is_empty():
			_begin_positive_placement()
			return
		if _hazard_controller.has_pending_draft():
			_begin_hazard_position_selection()
		else:
			_start_next_round()
		return

	_update_car_controls()
	_update_placement_preview()
	_update_placement_overlay()
	_focus_camera_on(_placement_preview, true)


func _confirm_positive_placement() -> void:
	if not _track or not _placement_preview:
		return

	var can_place: bool = _can_place_positive(_placement_progress, _placement_lateral_offset)
	if not can_place:
		return

	HazardPreviewHelper.set_preview(_placement_preview, false, true, true)
	var base_name: String = PositiveTypeRegistry.get_node_name(_placement_preview_type)
	_placement_preview.name = "%s%d" % [
		base_name,
		_count_track_items_with_base_name(base_name, _positive_root, _placement_preview) + 1,
	]
	_placement_preview = null
	_placement_preview_type = PositiveTypeRegistry.NONE
	if not _pending_positive_queue.is_empty():
		_pending_positive_queue.remove_at(0)
	_sync_round_end_screen()

	if not _pending_positive_queue.is_empty():
		_spawn_placement_preview()
		_update_placement_preview()
		if _placement_preview:
			_focus_camera_on(_placement_preview, true)
		return

	_is_placement_active = false
	_update_car_controls()
	_update_placement_overlay()
	if _hazard_controller.has_pending_draft():
		_begin_hazard_position_selection()
		return

	_start_next_round()


func _begin_hazard_position_selection() -> void:
	if _track == null:
		_start_next_round()
		return
	_hazard_controller.begin_placement(_get_occupied_track_item_positions())


func _on_hazard_placement_begun(focused_preview: Node3D) -> void:
	if _car:
		_car.reset_to_transform(_get_car_start_transform())
	if _round_end_screen:
		_round_end_screen.visible = false
	_update_car_controls()
	_update_placement_overlay()
	_focus_camera_on(focused_preview, true)


func _on_hazard_focus_changed(focused_preview: Node3D) -> void:
	_focus_camera_on(focused_preview, true)
	_update_placement_overlay()


func _on_hazard_placement_resolved() -> void:
	_update_car_controls()
	_update_placement_overlay()
	_start_next_round()


func _update_placement_input(delta: float) -> void:
	var progress_input: float = Input.get_action_strength("throttle") - Input.get_action_strength("brake")
	# +lateral_offset is the right-hand side of travel direction (see
	# `TestTrack.get_track_transform`), so steer_right must drive +input.
	var lateral_input: float = Input.get_action_strength("steer_right") - Input.get_action_strength("steer_left")
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
	var can_place: bool = _can_place_positive(_placement_progress, _placement_lateral_offset)
	_placement_preview.global_transform = preview_transform
	HazardPreviewHelper.set_preview(_placement_preview, true, can_place, true)
	_update_placement_overlay()


func _spawn_placement_preview() -> void:
	_clear_placement_preview()
	if _positive_root == null:
		_ensure_positive_root()
	if _positive_root == null or _pending_positive_queue.is_empty():
		return

	_placement_preview_type = _pending_positive_queue[0]
	var scene_path: String = PositiveTypeRegistry.get_scene_path(_placement_preview_type)
	if scene_path.is_empty():
		push_warning("MainSceneController has no placeable scene for positive type %d." % _placement_preview_type)
		return

	var preview_scene: PackedScene = load(scene_path) as PackedScene
	if preview_scene == null:
		push_warning("MainSceneController failed to load a positive scene for type %d." % _placement_preview_type)
		return

	_placement_preview = preview_scene.instantiate() as Node3D
	if _placement_preview == null:
		push_warning("MainSceneController failed to instantiate the positive preview for type %d." % _placement_preview_type)
		_placement_preview_type = PositiveTypeRegistry.NONE
		return

	_placement_preview.name = "%sPreview" % PositiveTypeRegistry.get_node_name(_placement_preview_type)
	HazardPreviewHelper.set_preview(_placement_preview, true, true, true)
	_positive_root.add_child(_placement_preview)


func _clear_placement_preview() -> void:
	if _placement_preview == null:
		return

	_placement_preview.queue_free()
	_placement_preview = null
	_placement_preview_type = PositiveTypeRegistry.NONE


func _ensure_positive_root() -> void:
	if _track == null:
		return

	_positive_root = _track.get_node_or_null(TRACK_POSITIVE_ROOT_NAME) as Node3D
	if _positive_root:
		return

	_positive_root = Node3D.new()
	_positive_root.name = TRACK_POSITIVE_ROOT_NAME
	_track.add_child(_positive_root)


func _ensure_placement_overlay() -> void:
	if _placement_overlay != null and _placement_panel != null and _placement_label != null:
		return

	_placement_overlay = CanvasLayer.new()
	_placement_overlay.name = "TrackPlacementOverlay"
	_placement_overlay.layer = 3
	add_child(_placement_overlay)

	_placement_panel = PanelContainer.new()
	_placement_panel.name = "PlacementPanel"
	_placement_panel.position = PLACEMENT_LABEL_MARGIN
	_placement_panel.custom_minimum_size = Vector2(PLACEMENT_PANEL_MIN_WIDTH, 0.0)
	_placement_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_placement_panel.add_theme_stylebox_override("panel", _create_placement_panel_style(PLACEMENT_PANEL_BORDER))
	_placement_overlay.add_child(_placement_panel)

	var panel_margin: MarginContainer = MarginContainer.new()
	panel_margin.add_theme_constant_override("margin_left", 16)
	panel_margin.add_theme_constant_override("margin_top", 14)
	panel_margin.add_theme_constant_override("margin_right", 16)
	panel_margin.add_theme_constant_override("margin_bottom", 14)
	_placement_panel.add_child(panel_margin)

	_placement_label = Label.new()
	_placement_label.name = "PlacementLabel"
	_placement_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_placement_label.add_theme_font_size_override("font_size", 20)
	_placement_label.add_theme_color_override("font_color", PLACEMENT_TEXT_COLOR)
	_placement_label.add_theme_constant_override("line_spacing", 6)
	_placement_label.add_theme_constant_override("outline_size", 0)
	panel_margin.add_child(_placement_label)


func _ensure_pause_menu() -> void:
	if _pause_menu != null:
		return
	_pause_menu = PauseMenu.new()
	_pause_menu.name = "PauseMenu"
	add_child(_pause_menu)
	if _car != null:
		_pause_menu.bind_car(_car)


func _update_placement_overlay() -> void:
	if _placement_overlay == null or _placement_panel == null or _placement_label == null:
		return

	_placement_overlay.visible = _is_placement_active or _hazard_controller.is_active()
	_placement_panel.visible = _placement_overlay.visible
	if not _placement_overlay.visible:
		return

	if _is_placement_active:
		var is_on_valid_track: bool = _track != null and _track.is_track_position_valid(
			_placement_progress,
			_placement_lateral_offset,
			boost_pad_track_clearance
		)
		var is_overlapping_existing_item: bool = false
		if is_on_valid_track:
			var placement_transform: Transform3D = _track.get_track_transform(_placement_progress, _placement_lateral_offset)
			is_overlapping_existing_item = not _is_track_item_clear(
				_placement_preview,
				placement_transform,
				_get_occupied_track_item_positions()
			)

		var can_place: bool = is_on_valid_track and not is_overlapping_existing_item
		var remaining_after_place: int = maxi(_pending_positive_queue.size() - 1, 0)
		var status_text: String = "Ready to place on tarmac"
		if not is_on_valid_track:
			status_text = "Move onto the tarmac to place"
		elif is_overlapping_existing_item:
			status_text = "Move away from another placed item"

		_placement_label.text = "Place %s\nThrottle / Brake: move around the track\nSteer: shift across the lane\nSpace / Enter: place\n%s\nQueued after this: %d" % [
			PositiveTypeRegistry.get_display_name(_placement_preview_type),
			status_text,
			remaining_after_place,
		]
		_placement_label.add_theme_color_override(
			"font_color",
			PLACEMENT_TEXT_COLOR if can_place else PLACEMENT_WARNING_TEXT_COLOR
		)
		_placement_panel.add_theme_stylebox_override(
			"panel",
			_create_placement_panel_style(PLACEMENT_PANEL_BORDER if can_place else PLACEMENT_WARNING_BORDER)
		)
		return

	var total_positions: int = maxi(_hazard_controller.get_position_count(), 1)
	var focused_position: int = mini(_hazard_controller.get_focused_index() + 1, total_positions)
	_placement_label.text = "Place %s\nPosition %d/%d\nSteer / 1-%d: browse positions\nSpace / Enter: confirm" % [
		HazardTypeRegistry.get_display_name(_hazard_controller.get_pending_hazard_type()),
		focused_position,
		total_positions,
		total_positions,
	]
	_placement_label.add_theme_color_override("font_color", PLACEMENT_TEXT_COLOR)
	_placement_panel.add_theme_stylebox_override("panel", _create_placement_panel_style(PLACEMENT_PANEL_BORDER))


func _create_placement_panel_style(border_color: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = PLACEMENT_PANEL_BG
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_right = 18
	style.corner_radius_bottom_left = 18
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = border_color
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.32)
	style.shadow_size = 18
	return style


func _update_car_controls() -> void:
	if _car == null:
		return

	var controls_should_be_enabled: bool = _run_state != null \
		and _run_state.is_round_active \
		and not _is_placement_active \
		and not _hazard_controller.is_active()
	_car.set_controls_enabled(controls_should_be_enabled)


func _focus_camera_on(target: Node3D, snap: bool) -> void:
	if _camera == null or target == null:
		return

	_camera.target = target
	if snap:
		_camera.snap_to_target()


func _can_place_positive(progress: float, lateral_offset: float) -> bool:
	if _track == null or _placement_preview == null:
		return false
	if not _track.is_track_position_valid(progress, lateral_offset, boost_pad_track_clearance):
		return false

	var placement_transform: Transform3D = _track.get_track_transform(progress, lateral_offset)
	return _is_track_item_clear(_placement_preview, placement_transform, _get_occupied_track_item_positions())


func _get_hazard_draft_options() -> Array[int]:
	if not _should_require_hazard_draft():
		return []
	var offered: Array[int] = []
	var line_tax_type: int = _pick_weighted_hazard_type(
		HazardTypeRegistry.get_available_types_for_category(HazardTypeRegistry.Category.LINE_TAX)
	)
	var hard_reroute_type: int = _pick_weighted_hazard_type(
		HazardTypeRegistry.get_available_types_for_category(HazardTypeRegistry.Category.HARD_REROUTE)
	)
	if HazardTypeRegistry.is_valid_type(line_tax_type):
		offered.append(line_tax_type)
	if HazardTypeRegistry.is_valid_type(hard_reroute_type):
		offered.append(hard_reroute_type)
	return offered


func _get_positive_offer_types() -> Array[int]:
	var offered: Array[int] = []
	for category in PositiveTypeRegistry.get_offer_categories():
		var positive_type: int = _pick_weighted_positive_type(
			PositiveTypeRegistry.get_available_types_for_category(category)
		)
		if PositiveTypeRegistry.is_valid_type(positive_type):
			offered.append(positive_type)
	return offered


func _pick_weighted_positive_type(candidates: Array[int]) -> int:
	return _pick_weighted_type(
		candidates,
		func(candidate: int) -> int:
			return PositiveTypeRegistry.get_offer_weight(candidate),
		PositiveTypeRegistry.NONE
	)


func _pick_weighted_hazard_type(candidates: Array[int]) -> int:
	return _pick_weighted_type(
		candidates,
		func(candidate: int) -> int:
			return HazardTypeRegistry.get_draft_weight(candidate),
		HazardTypeRegistry.NONE
	)


func _pick_weighted_type(candidates: Array[int], weight_getter: Callable, fallback: int) -> int:
	if candidates.is_empty():
		return fallback

	var total_weight: int = 0
	for candidate in candidates:
		total_weight += maxi(int(weight_getter.call(candidate)), 0)

	if total_weight <= 0:
		return candidates[0]

	var roll: int = randi_range(1, total_weight)
	var running_weight: int = 0
	for candidate in candidates:
		running_weight += maxi(int(weight_getter.call(candidate)), 0)
		if roll <= running_weight:
			return candidate

	return candidates[0]


func _should_require_hazard_draft() -> bool:
	return _run_state != null and _run_state.round_number >= 1


func _get_occupied_track_item_positions() -> Array[Vector3]:
	var occupied_positions: Array[Vector3] = []
	_append_node_footprint_samples(_car, occupied_positions, _get_car_start_transform(), true)
	_append_track_item_positions(_positive_root, occupied_positions)
	_append_track_item_positions(_hazard_controller.get_hazard_root(), occupied_positions)
	return occupied_positions


func _append_track_item_positions(root: Node3D, occupied_positions: Array[Vector3]) -> void:
	if root == null:
		return

	for child in root.get_children():
		var track_item: Node3D = child as Node3D
		if track_item == null or track_item == _placement_preview:
			continue
		_append_node_footprint_samples(track_item, occupied_positions)


func _append_node_footprint_samples(
	node: Node3D,
	occupied_positions: Array[Vector3],
	root_transform: Transform3D = Transform3D.IDENTITY,
	use_root_transform: bool = false
) -> void:
	if node == null:
		return

	occupied_positions.append_array(_get_node_footprint_samples(node, root_transform, use_root_transform))


func _get_node_footprint_samples(
	node: Node3D,
	root_transform: Transform3D = Transform3D.IDENTITY,
	use_root_transform: bool = false
) -> Array[Vector3]:
	var sample_positions: Array[Vector3] = []
	if node == null:
		return sample_positions

	var sample_transform: Transform3D = root_transform if use_root_transform else node.global_transform
	sample_positions.append(sample_transform.origin)

	for collision_shape in _get_collision_shapes(node):
		if collision_shape == null or collision_shape.shape == null:
			continue

		var half_extents: Vector2 = _get_collision_half_extents(collision_shape.shape)
		if half_extents.length_squared() <= 0.0001:
			continue

		# Sample ring is symmetric around the origin in both axes, so we only
		# need two orthonormal ground-plane basis vectors — the sign of the
		# local Z axis (Godot's `back`) does not matter here.
		var collision_transform: Transform3D = sample_transform * collision_shape.transform
		var width_axis: Vector3 = collision_transform.basis.x
		var depth_axis: Vector3 = collision_transform.basis.z
		if width_axis.length_squared() < 0.0001:
			width_axis = Vector3.RIGHT
		else:
			width_axis = width_axis.normalized()
		if depth_axis.length_squared() < 0.0001:
			depth_axis = Vector3.BACK
		else:
			depth_axis = depth_axis.normalized()

		for sample in TRACK_ITEM_FOOTPRINT_SAMPLES:
			var sample_position: Vector3 = collision_transform.origin \
				+ width_axis * (sample.x * half_extents.x) \
				+ depth_axis * (sample.y * half_extents.y)
			sample_positions.append(sample_position)

	return sample_positions


## Collects only direct `CollisionShape3D` children. Compound bodies that
## nest shapes under intermediate Node3Ds (none today) would need deeper
## traversal; the placement filter silently ignores any unreachable shape.
func _get_collision_shapes(node: Node3D) -> Array[CollisionShape3D]:
	var collision_shapes: Array[CollisionShape3D] = []
	for child in node.get_children():
		var collision_shape: CollisionShape3D = child as CollisionShape3D
		if collision_shape != null:
			collision_shapes.append(collision_shape)
	return collision_shapes


func _is_track_item_clear(
	node: Node3D,
	item_transform: Transform3D,
	occupied_positions: Array[Vector3]
) -> bool:
	var candidate_positions: Array[Vector3] = _get_node_footprint_samples(node, item_transform, true)
	for candidate_position in candidate_positions:
		for occupied_position in occupied_positions:
			if candidate_position.distance_to(occupied_position) < TRACK_ITEM_PLACEMENT_SAMPLE_CLEARANCE:
				return false
	return true


func _count_track_items_with_base_name(base_name: String, root: Node3D, exclude: Node3D) -> int:
	if root == null:
		return 0
	var count: int = 0
	for child in root.get_children():
		if child == exclude:
			continue
		if child.name.begins_with(base_name):
			count += 1
	return count


func _get_collision_half_extents(shape: Shape3D) -> Vector2:
	if shape is BoxShape3D:
		var box_shape: BoxShape3D = shape as BoxShape3D
		return Vector2(box_shape.size.x * 0.5, box_shape.size.z * 0.5)
	if shape is CylinderShape3D:
		var cylinder_shape: CylinderShape3D = shape as CylinderShape3D
		return Vector2(cylinder_shape.radius, cylinder_shape.radius)
	if shape is CapsuleShape3D:
		# CapsuleShape3D is Y-axis oriented; its `height` sits along world Y
		# once placed on the track so the ground footprint is just the radius.
		var capsule_shape: CapsuleShape3D = shape as CapsuleShape3D
		return Vector2(capsule_shape.radius, capsule_shape.radius)
	if shape is SphereShape3D:
		var sphere_shape: SphereShape3D = shape as SphereShape3D
		return Vector2(sphere_shape.radius, sphere_shape.radius)
	return Vector2.ZERO


func _get_car_start_transform() -> Transform3D:
	if _track != null:
		return _track.get_start_transform(_car_spawn_transform.origin.y + CAR_START_CLEARANCE)
	return _car_spawn_transform


func _rebuild_track_coins() -> void:
	if _track == null:
		return

	var coin_root: Node3D = _ensure_coin_root()
	if coin_root == null:
		return

	for child in coin_root.get_children():
		child.queue_free()

	if coin_count <= 0 or COIN_SCENE == null:
		return

	var coin_transforms: Array[Transform3D] = _build_coin_transforms()
	for coin_index in range(coin_transforms.size()):
		var coin: Coin = COIN_SCENE.instantiate() as Coin
		if coin == null:
			push_warning("MainSceneController failed to instantiate a coin.")
			continue

		coin.name = "Coin%d" % (coin_index + 1)
		coin_root.add_child(coin)
		coin.global_transform = coin_transforms[coin_index]

	if coin_transforms.size() < coin_count:
		push_warning(
			"MainSceneController placed %d/%d coins on the current track." % [
				coin_transforms.size(),
				coin_count,
			]
		)


func _ensure_coin_root() -> Node3D:
	if _track == null:
		return null

	var coin_root: Node3D = _track.get_node_or_null(TRACK_COIN_ROOT_NAME) as Node3D
	if coin_root != null:
		return coin_root

	coin_root = Node3D.new()
	coin_root.name = TRACK_COIN_ROOT_NAME
	_track.add_child(coin_root)
	return coin_root


func _build_coin_transforms() -> Array[Transform3D]:
	var coin_transforms: Array[Transform3D] = []
	if _track == null or coin_count <= 0:
		return coin_transforms

	var occupied_positions: Array[Vector3] = _get_occupied_track_item_positions()
	var lateral_candidates: Array[float] = _get_coin_lateral_candidates()
	var spacing: float = 1.0 / float(coin_count)
	var lap_start_progress: float = _track.get_lap_start_progress()

	for coin_index in range(coin_count):
		var band_center_progress: float = wrapf(
			lap_start_progress + spacing * (float(coin_index) + 0.5),
			0.0,
			1.0
		)
		for attempt in range(COIN_PLACEMENT_BAND_ATTEMPTS):
			var attempt_ratio: float = 0.0
			if COIN_PLACEMENT_BAND_ATTEMPTS > 1:
				attempt_ratio = float(attempt) / float(COIN_PLACEMENT_BAND_ATTEMPTS - 1)
			var progress_offset: float = lerpf(
				-spacing * COIN_PROGRESS_JITTER_RATIO,
				spacing * COIN_PROGRESS_JITTER_RATIO,
				attempt_ratio
			)
			var candidate_progress: float = wrapf(band_center_progress + progress_offset, 0.0, 1.0)
			if _append_coin_transform_if_valid(
				candidate_progress,
				lateral_candidates,
				occupied_positions,
				coin_transforms
			):
				break

	var fallback_attempts: int = 0
	while coin_transforms.size() < coin_count and fallback_attempts < COIN_PLACEMENT_FALLBACK_ATTEMPTS:
		fallback_attempts += 1
		var candidate_progress: float = randf()
		_append_coin_transform_if_valid(
			candidate_progress,
			lateral_candidates,
			occupied_positions,
			coin_transforms
		)

	return coin_transforms


func _append_coin_transform_if_valid(
	progress: float,
	lateral_candidates: Array[float],
	occupied_positions: Array[Vector3],
	coin_transforms: Array[Transform3D]
) -> bool:
	if _track == null:
		return false

	for lateral_offset in lateral_candidates:
		if not _track.is_track_position_valid(progress, lateral_offset, COIN_TRACK_CLEARANCE):
			continue

		var coin_transform: Transform3D = _track.get_track_transform(progress, lateral_offset, COIN_TRACK_Y_OFFSET)
		var coin_position: Vector3 = coin_transform.origin
		if _is_coin_position_blocked(coin_position, occupied_positions):
			continue

		occupied_positions.append(coin_position)
		coin_transforms.append(coin_transform)
		return true

	return false


func _get_coin_lateral_candidates() -> Array[float]:
	var lateral_candidates: Array[float] = [0.0]
	if _track == null:
		return lateral_candidates

	var max_lateral_offset: float = _track.get_max_lateral_offset(COIN_TRACK_CLEARANCE)
	var lane_offset: float = minf(max_lateral_offset, _track.track_width * COIN_LATERAL_OFFSET_RATIO)
	if is_zero_approx(lane_offset):
		return lateral_candidates

	lateral_candidates.append(lane_offset)
	lateral_candidates.append(-lane_offset)
	return lateral_candidates


func _is_coin_position_blocked(candidate_position: Vector3, occupied_positions: Array[Vector3]) -> bool:
	for occupied_position in occupied_positions:
		if occupied_position.distance_to(candidate_position) < COIN_MIN_OCCUPIED_DISTANCE:
			return true
	return false
