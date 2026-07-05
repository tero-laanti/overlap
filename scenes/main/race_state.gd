class_name RaceState
extends Node
## Owns lap timing and the recording lifecycle: current lap clock, last
## lap time, per-route best times, and transform sampling of the car
## during each lap. On a new route best it publishes the LapRecording on
## the Events bus. Zero means "no lap set yet". best_lap_time is the PB
## of the most recently completed (or adopted) route, for the HUD. Main
## injects the car reference.

const SAMPLE_EVERY_TICKS := 2
const CarScript = preload("res://scenes/car/car.gd")
const LapRecordingScript = preload("res://scenes/ghost/lap_recording.gd")

var car: CarScript

var current_lap_time := 0.0
var last_lap_time := 0.0
var best_lap_time := 0.0
var lap_count := 0

var _route_bests := {}
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


## Adopt a persisted route best (loaded by Bank) so PB comparisons and
## the HUD survive restarts.
func adopt_best(route_id: String, recording: LapRecordingScript) -> void:
	_route_bests[route_id] = recording.lap_time
	if best_lap_time == 0.0 or recording.lap_time < best_lap_time:
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


func on_lap_completed(route_id: String) -> void:
	last_lap_time = current_lap_time
	var previous: float = _route_bests.get(route_id, 0.0)
	var is_best := previous == 0.0 or last_lap_time < previous
	if is_best:
		_route_bests[route_id] = last_lap_time
	best_lap_time = _route_bests[route_id]
	lap_count += 1
	if is_best and _positions.size() > 2:
		var recording := LapRecordingScript.new()
		recording.sample_dt = float(SAMPLE_EVERY_TICKS) / Engine.physics_ticks_per_second
		recording.positions = _positions.duplicate()
		recording.rotations = _rotations.duplicate()
		recording.lap_time = last_lap_time
		Events.best_lap_recorded.emit(route_id, recording)
	Events.lap_completed.emit(route_id, last_lap_time, is_best)
