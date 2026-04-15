class_name LapTracker
extends Node

signal lap_changed(current_lap: int)
signal lap_completed(completed_laps: int)

@export var car_path: NodePath
@export var track_path: NodePath
@export_range(0.05, 0.95, 0.01) var checkpoint_progress: float = 0.5
@export_range(0.01, 0.25, 0.01) var finish_window: float = 0.12
@export_range(0.00005, 0.002, 0.00005) var minimum_forward_progress: float = 0.0002

var current_lap: int = 1
var completed_laps: int = 0
var current_progress: float = 0.0

var _car: Car = null
var _track: TestTrack = null
var _lap_armed: bool = false
var _has_last_progress: bool = false
var _last_progress: float = 0.0


func _physics_process(_delta: float) -> void:
	if not _resolve_references():
		return

	var raw_progress: float = _track.get_progress_at_position(_car.global_position)
	var relative_progress: float = wrapf(raw_progress - _track.get_lap_start_progress(), 0.0, 1.0)
	current_progress = relative_progress

	if not _has_last_progress:
		_last_progress = relative_progress
		_has_last_progress = true
		return

	var progress_delta: float = _get_signed_progress_delta(relative_progress, _last_progress)

	if progress_delta > minimum_forward_progress and relative_progress >= checkpoint_progress:
		_lap_armed = true

	var crossed_finish_forward: bool = (
		_lap_armed
		and _last_progress > 1.0 - finish_window
		and relative_progress < finish_window
		and progress_delta > minimum_forward_progress
	)

	if crossed_finish_forward:
		completed_laps += 1
		current_lap = completed_laps + 1
		_lap_armed = false
		lap_completed.emit(completed_laps)
		lap_changed.emit(current_lap)

	_last_progress = relative_progress


func _resolve_references() -> bool:
	if not is_instance_valid(_car):
		_car = get_node_or_null(car_path) as Car
	if not is_instance_valid(_track):
		_track = get_node_or_null(track_path) as TestTrack
	return _car != null and _track != null


func _get_signed_progress_delta(current_progress_value: float, previous_progress_value: float) -> float:
	var delta: float = current_progress_value - previous_progress_value
	if delta > 0.5:
		delta -= 1.0
	elif delta < -0.5:
		delta += 1.0
	return delta
