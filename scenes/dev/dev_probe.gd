extends Node
## Dev-only verification probe. Dormant unless user://autopilot.flag exists
## (created by tooling before a run). Runs a phased full-loop test with a
## waypoint autopilot: drive PB laps, idle to earn, buy a ghost slot and an
## upgrade through the real Bank APIs, re-drive with the upgraded car, then
## watch fleet income. Prints telemetry and saves screenshots to user://dev/.
## Never active in release builds.

enum Phase { DRIVE, EARN, SPEND, REDRIVE, WATCH, DONE }

const FLAG_PATH := "user://autopilot.flag"
const SHOT_DIR := "user://dev"
const TELEMETRY_INTERVAL := 1.0
const SCREENSHOT_INTERVAL := 3.0
const TIMEOUT := 150.0
const DRIVE_LAPS := 2
const EARN_TARGET := 110.0  # ghost slot (25) + top speed (75) + slack
const WATCH_SECONDS := 16.0

const WAYPOINTS: Array[Vector2] = [
	Vector2(-1050, 550), Vector2(-1050, -550),
	Vector2(1050, -550), Vector2(1050, 550),
]
const WAYPOINT_REACHED_DISTANCE := 240.0
const STEER_DEADZONE := 0.06
const COAST_ANGLE := 1.3
const COAST_MIN_SPEED := 550.0

var _phase := Phase.DRIVE
var _elapsed := 0.0
var _next_telemetry := 0.0
var _next_screenshot := 0.0
var _shot_index := 0
var _held: Array[String] = []
var _car: Car
var _waypoint_index := 0
var _laps_done := 0
var _redrive_target := 0
var _watch_until := 0.0


func _ready() -> void:
	if not (OS.is_debug_build() and FileAccess.file_exists(FLAG_PATH)):
		set_process(false)
		return
	DirAccess.make_dir_recursive_absolute(SHOT_DIR)
	_car = get_tree().get_first_node_in_group("player_car")
	Events.lap_completed.connect(_on_lap_completed)
	Events.best_lap_recorded.connect(func(rec: LapRecording) -> void:
		print("[PROBE] best_lap_recorded samples=%d lap_time=%.2f" % [
			rec.positions.size(), rec.lap_time]))
	Events.ghost_lap_completed.connect(func() -> void:
		print("[PROBE] ghost_lap_completed money=%.0f" % Bank.currency))
	var track: Track = get_tree().get_first_node_in_group("track")
	if track:
		track.lap_started.connect(func() -> void: print("[PROBE] lap_started"))
	print("[PROBE] loaded money=%.0f best=%.2f slots=%d" % [
		Bank.currency,
		Bank.best_recording.lap_time if Bank.best_recording else 0.0,
		Bank.ghost_slots,
	])


func _process(delta: float) -> void:
	_elapsed += delta
	if _car == null:
		return

	match _phase:
		Phase.DRIVE:
			_drive()
			if _laps_done >= DRIVE_LAPS:
				_release_all()
				_enter(Phase.EARN, "idling until $%d" % int(EARN_TARGET))
		Phase.EARN:
			if Bank.currency >= EARN_TARGET:
				_spend()
		Phase.SPEND:
			pass  # transitions inside _spend()
		Phase.REDRIVE:
			_drive()
			if _laps_done >= _redrive_target:
				_release_all()
				_watch_until = _elapsed + WATCH_SECONDS
				var shop := get_node_or_null("/root/Main/Shop")
				if shop:
					shop.visible = true  # show shop for screenshots
				_enter(Phase.WATCH, "watching fleet income")
		Phase.WATCH:
			if _elapsed >= _watch_until:
				print("[PROBE] done t=%.1f money=%.0f income=%.2f/s slots=%d laps=%d" % [
					_elapsed, Bank.currency, Bank.income_per_second(),
					Bank.ghost_slots, _laps_done,
				])
				_enter(Phase.DONE, "finished")
				set_process(false)
				return
		Phase.DONE:
			return

	if _elapsed >= TIMEOUT and _phase != Phase.DONE:
		_release_all()
		print("[PROBE] TIMEOUT at phase %s money=%.0f" % [Phase.keys()[_phase], Bank.currency])
		set_process(false)
		return

	if _elapsed >= _next_telemetry:
		_next_telemetry += TELEMETRY_INTERVAL
		var ghosts := get_tree().get_nodes_in_group("ghost")
		print("[PROBE] t=%.1f phase=%s pos=(%.0f, %.0f) speed=%.0f money=%.0f ghosts=%d" % [
			_elapsed, Phase.keys()[_phase], _car.global_position.x,
			_car.global_position.y, _car.velocity.length(), Bank.currency,
			ghosts.size(),
		])

	if _elapsed >= _next_screenshot:
		_next_screenshot += SCREENSHOT_INTERVAL
		_save_screenshot()


func _spend() -> void:
	_enter(Phase.SPEND, "buying")
	var slot_ok := Bank.try_buy_ghost_slot()
	var upgrade_ok := Bank.try_buy_upgrade("top_speed")
	print("[PROBE] bought ghost_slot=%s top_speed=%s money=%.0f slots=%d max_speed=%.0f" % [
		slot_ok, upgrade_ok, Bank.currency, Bank.ghost_slots,
		_car.effective_stats().max_speed,
	])
	_redrive_target = _laps_done + 1
	_enter(Phase.REDRIVE, "one lap with upgraded car")


func _enter(phase: Phase, note: String) -> void:
	_phase = phase
	print("[PROBE] phase=%s — %s" % [Phase.keys()[phase], note])


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
