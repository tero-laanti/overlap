class_name RaceState
extends Node
## Owns lap timing and the recording lifecycle: current lap clock, last and
## best lap times, and transform sampling of the car during each lap. On a
## new best it publishes the LapRecording on the Events bus. Zero means
## "no lap set yet". Main injects the car reference.

const SAMPLE_EVERY_TICKS := 2

var car: Car
var best_recording: LapRecording

var current_lap_time := 0.0
var last_lap_time := 0.0
var best_lap_time := 0.0
var lap_count := 0

var _running := false
var _recording := false
var _tick := 0
var _positions := PackedVector2Array()
var _rotations := PackedFloat32Array()


func _process(delta: float) -> void:
	if _running:
		current_lap_time += delta


func _physics_process(_delta: float) -> void:
	if not _recording or car == null:
		return
	_tick += 1
	if _tick % SAMPLE_EVERY_TICKS != 0:
		return
	_positions.append(car.global_position)
	_rotations.append(car.rotation)


## Adopt a persisted best lap (loaded by Bank) so PB comparisons and the
## HUD survive restarts.
func adopt_best(recording: LapRecording) -> void:
	best_recording = recording
	best_lap_time = recording.lap_time


func on_lap_started() -> void:
	_running = true
	current_lap_time = 0.0
	_recording = car != null
	_tick = 0
	_positions.clear()
	_rotations.clear()
	if car != null:
		_positions.append(car.global_position)
		_rotations.append(car.rotation)


func on_lap_completed() -> void:
	last_lap_time = current_lap_time
	var is_best := best_lap_time == 0.0 or last_lap_time < best_lap_time
	if is_best:
		best_lap_time = last_lap_time
	lap_count += 1
	if is_best and _positions.size() > 2:
		best_recording = LapRecording.new()
		best_recording.sample_dt = float(SAMPLE_EVERY_TICKS) / Engine.physics_ticks_per_second
		best_recording.positions = _positions.duplicate()
		best_recording.rotations = _rotations.duplicate()
		best_recording.lap_time = last_lap_time
		Events.best_lap_recorded.emit(best_recording)
	Events.lap_completed.emit(last_lap_time, is_best)
