class_name MainSceneController
extends Node3D

@export var car_path: NodePath
@export var run_state_path: NodePath
@export var round_end_screen_path: NodePath
@export var camera_path: NodePath
@export var buy_time_cost: int = 20
@export var buy_time_seconds: float = 15.0

var _car: Car = null
var _run_state: RunState = null
var _round_end_screen: RoundEndScreen = null
var _camera: GameCamera = null
var _car_spawn_transform: Transform3D = Transform3D.IDENTITY
var _pending_start_time_bonus: float = 0.0


func _ready() -> void:
	_car = get_node_or_null(car_path) as Car
	_run_state = get_node_or_null(run_state_path) as RunState
	_round_end_screen = get_node_or_null(round_end_screen_path) as RoundEndScreen
	_camera = get_node_or_null(camera_path) as GameCamera

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

	if _round_end_screen:
		_round_end_screen.configure_buy_time_option(buy_time_cost, buy_time_seconds)
		_round_end_screen.set_pending_start_time_bonus(_pending_start_time_bonus)

		if not _round_end_screen.buy_time_requested.is_connected(_on_buy_time_requested):
			_round_end_screen.buy_time_requested.connect(_on_buy_time_requested)
		if not _round_end_screen.continue_requested.is_connected(_on_continue_requested):
			_round_end_screen.continue_requested.connect(_on_continue_requested)


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


func _on_continue_requested() -> void:
	if not _car or not _run_state or _run_state.is_round_active:
		return

	var extra_start_time: float = _pending_start_time_bonus
	_pending_start_time_bonus = 0.0
	if _round_end_screen:
		_round_end_screen.set_pending_start_time_bonus(_pending_start_time_bonus)

	_car.reset_to_transform(_car_spawn_transform)
	if _camera:
		_camera.snap_to_target()

	_run_state.start_round(extra_start_time)
