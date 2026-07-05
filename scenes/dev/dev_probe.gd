extends Node
## Dev-only verification probe. Dormant unless user://autopilot.flag exists
## (created by tooling before a run). When active it drives the car around
## the circuit with a waypoint-following autopilot, prints telemetry and
## race events, and saves periodic screenshots to user://dev/ so an agent
## can verify behavior without a human at the wheel. Never active in
## release builds.

const FLAG_PATH := "user://autopilot.flag"
const SHOT_DIR := "user://dev"
const TELEMETRY_INTERVAL := 1.0
const SCREENSHOT_INTERVAL := 3.0
const TIMEOUT := 60.0
const TARGET_LAPS := 3

## Corner apex targets at road center, clockwise from the spawn point.
const WAYPOINTS: Array[Vector2] = [
	Vector2(-1050, 550), Vector2(-1050, -550),
	Vector2(1050, -550), Vector2(1050, 550),
]
const WAYPOINT_REACHED_DISTANCE := 240.0
const STEER_DEADZONE := 0.06
const COAST_ANGLE := 1.3
const COAST_MIN_SPEED := 550.0

var _elapsed := 0.0
var _next_telemetry := 0.0
var _next_screenshot := 0.0
var _shot_index := 0
var _held: Array[String] = []
var _car: Car
var _waypoint_index := 0
var _laps_done := 0


func _ready() -> void:
	if not (OS.is_debug_build() and FileAccess.file_exists(FLAG_PATH)):
		set_process(false)
		return
	DirAccess.make_dir_recursive_absolute(SHOT_DIR)
	_car = get_tree().get_first_node_in_group("player_car")
	Events.lap_completed.connect(_on_lap_completed)
	Events.best_lap_recorded.connect(func(rec: LapRecording) -> void:
		print("[PROBE] best_lap_recorded samples=%d dt=%.4f lap_time=%.2f" % [
			rec.positions.size(), rec.sample_dt, rec.lap_time]))
	var track: Track = get_tree().get_first_node_in_group("track")
	if track:
		track.lap_started.connect(func() -> void: print("[PROBE] lap_started"))
		track.checkpoint_crossed.connect(func(i: int, n: int) -> void:
			print("[PROBE] checkpoint %d/%d" % [i + 1, n]))
	print("[PROBE] active, car=%s track=%s" % [_car, track])


func _process(delta: float) -> void:
	_elapsed += delta
	if _car == null:
		return

	_drive()

	if _elapsed >= _next_telemetry:
		_next_telemetry += TELEMETRY_INTERVAL
		var line := "[PROBE] t=%.1f pos=(%.0f, %.0f) speed=%.0f wp=%d" % [
			_elapsed, _car.global_position.x, _car.global_position.y,
			_car.velocity.length(), _waypoint_index,
		]
		var ghost: Ghost = get_tree().get_first_node_in_group("ghost")
		if ghost != null:
			line += " ghost=(%.0f, %.0f)" % [ghost.global_position.x, ghost.global_position.y]
		print(line)

	if _elapsed >= _next_screenshot:
		_next_screenshot += SCREENSHOT_INTERVAL
		_save_screenshot()

	if _laps_done >= TARGET_LAPS or _elapsed >= TIMEOUT:
		_release_all()
		print("[PROBE] done laps=%d t=%.1f" % [_laps_done, _elapsed])
		set_process(false)


func _drive() -> void:
	var target := WAYPOINTS[_waypoint_index]
	if _car.global_position.distance_to(target) < WAYPOINT_REACHED_DISTANCE:
		_waypoint_index = (_waypoint_index + 1) % WAYPOINTS.size()
		target = WAYPOINTS[_waypoint_index]

	var heading := _car.rotation - PI / 2.0
	var desired := (target - _car.global_position).angle()
	var error := angle_difference(heading, desired)

	var wanted: Array[String] = []
	if error > STEER_DEADZONE:
		wanted.append("steer_right")
	elif error < -STEER_DEADZONE:
		wanted.append("steer_left")
	var sharp_turn := absf(error) > COAST_ANGLE
	if not (sharp_turn and _car.velocity.length() > COAST_MIN_SPEED):
		wanted.append("accelerate")
	_hold(wanted)


func _on_lap_completed(lap_time: float, is_best: bool) -> void:
	_laps_done += 1
	print("[PROBE] LAP %d completed in %.2fs best=%s" % [_laps_done, lap_time, is_best])


func _hold(wanted: Array[String]) -> void:
	for action in _held.duplicate():
		if action not in wanted:
			Input.action_release(action)
			_held.erase(action)
	for action in wanted:
		if action not in _held:
			Input.action_press(action)
			_held.append(action)


func _release_all() -> void:
	for action in _held:
		Input.action_release(action)
	_held.clear()


func _save_screenshot() -> void:
	var image := get_viewport().get_texture().get_image()
	if image == null:
		return
	var path := "%s/frame_%02d.png" % [SHOT_DIR, _shot_index]
	image.save_png(path)
	_shot_index += 1
