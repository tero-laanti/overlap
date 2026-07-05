extends Node
## Dev-only verification probe. Dormant unless user://autopilot.flag exists
## (created by tooling before a run). Runs a phased full-loop test with a
## waypoint autopilot: drive PB laps, idle to earn, buy a ghost slot and an
## upgrade through the real Bank APIs, re-drive with the upgraded car, watch
## fleet income, then buy the island gate and discover the Island Cut route.
## Prints telemetry and saves screenshots to user://dev/. Never active in
## release builds.

enum Phase { DRIVE, EARN, SPEND, REDRIVE, WATCH, BUY_GATE, DRIVE_CUT, WATCH_CUT, DONE }

const FLAG_PATH := "user://autopilot.flag"
const SHOT_DIR := "user://dev"
const TELEMETRY_INTERVAL := 1.0
const SCREENSHOT_INTERVAL := 3.0
const TIMEOUT := 180.0
const DRIVE_LAPS := 2
const REDRIVE_LAPS := 2
const CUT_LAPS := 2
const EARN_TARGET := 110.0  # ghost slot (25) + top speed (75) + slack
const WATCH_SECONDS := 16.0
const WATCH_CUT_SECONDS := 12.0
const GATE_ID := "island_chord"

const RING_WAYPOINTS: Array[Vector2] = [
	Vector2(-1050, 550), Vector2(-1050, -550),
	Vector2(1050, -550), Vector2(1050, 550),
]
const CUT_WAYPOINTS: Array[Vector2] = [
	Vector2(-1050, 550), Vector2(-1050, -550),
	Vector2(300, -550), Vector2(300, -100), Vector2(300, 550),
]
const WAYPOINT_REACHED_DISTANCE := 240.0
const STEER_DEADZONE := 0.06
const COAST_ANGLE := 1.3
const COAST_MIN_SPEED := 550.0

const CarScript = preload("res://scenes/car/car.gd")
const LapRecordingScript = preload("res://scenes/ghost/lap_recording.gd")
const TrackScript = preload("res://scenes/track/track.gd")

var _phase := Phase.DRIVE
var _elapsed := 0.0
var _next_telemetry := 0.0
var _next_screenshot := 0.0
var _shot_index := 0
var _held: Array[String] = []
var _car: CarScript
var _waypoints: Array[Vector2] = RING_WAYPOINTS
var _waypoint_index := 0
var _laps_done := 0
var _lap_target := 0
var _watch_until := 0.0
var _stuck_time := 0.0
var _reverse_until := 0.0


func _ready() -> void:
	if not (OS.is_debug_build() and FileAccess.file_exists(FLAG_PATH)):
		set_process(false)
		return
	# Every probe run starts from zero through the real reset path, so
	# the debug wipe is exercised on every verification loop. Runs
	# before Main._ready, which then adopts the (now empty) records.
	Bank.reset_profile()
	print("[PROBE] profile reset")
	DirAccess.make_dir_recursive_absolute(SHOT_DIR)
	_car = get_tree().get_first_node_in_group("player_car")
	Events.lap_completed.connect(_on_lap_completed)
	Events.best_lap_recorded.connect(func(route_id: String, rec: LapRecordingScript) -> void:
		print("[PROBE] best_lap_recorded route=%s samples=%d lap_time=%.2f" % [
			route_id, rec.positions.size(), rec.lap_time]))
	Events.ghost_lap_completed.connect(func(route_id: String) -> void:
		print("[PROBE] ghost_lap_completed route=%s money=%.0f" % [route_id, Bank.currency]))
	Events.route_discovered.connect(func(route_id: String, display_name: String) -> void:
		print("[PROBE] route_discovered id=%s name=%s" % [route_id, display_name]))
	Events.gate_purchased.connect(func(gate_id: String) -> void:
		print("[PROBE] gate_purchased id=%s money=%.0f" % [gate_id, Bank.currency]))
	var track: TrackScript = get_tree().get_first_node_in_group("track")
	if track:
		track.lap_started.connect(func() -> void: print("[PROBE] lap_started"))
	print("[PROBE] loaded money=%.0f ring_pb=%.2f slots=%d routes=%d" % [
		Bank.currency, Bank.route_pb("ring"), Bank.ghost_slots,
		Bank.discovered_routes.size(),
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
			if _laps_done >= _lap_target:
				_release_all()
				_watch_until = _elapsed + WATCH_SECONDS
				var shop := get_node_or_null("/root/Main/Shop")
				if shop:
					shop.visible = true  # show shop for screenshots
				_enter(Phase.WATCH, "watching fleet income")
		Phase.WATCH:
			if _elapsed >= _watch_until:
				print("[PROBE] ring done money=%.0f income=%.2f/s slots=%d laps=%d" % [
					Bank.currency, Bank.income_per_second(), Bank.ghost_slots, _laps_done,
				])
				_buy_gate()
		Phase.BUY_GATE:
			pass  # transitions inside _buy_gate()
		Phase.DRIVE_CUT:
			_drive()
			if _laps_done >= _lap_target:
				_release_all()
				_watch_until = _elapsed + WATCH_CUT_SECONDS
				_enter(Phase.WATCH_CUT, "watching both fleets")
		Phase.WATCH_CUT:
			if _elapsed >= _watch_until:
				_dump_route_log()
				print("[PROBE] done t=%.1f money=%.0f income=%.2f/s slots=%d laps=%d routes=%d cut_pb=%.2f ghosts=%d" % [
					_elapsed, Bank.currency, Bank.income_per_second(),
					Bank.ghost_slots, _laps_done, Bank.discovered_routes.size(),
					Bank.route_pb("cut"), get_tree().get_nodes_in_group("ghost").size(),
				])
				_enter(Phase.DONE, "finished")
				set_process(false)
				if DisplayServer.get_name() == "headless":
					get_tree().quit()
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
		print("[PROBE] t=%.1f phase=%s pos=(%.0f, %.0f) speed=%.0f money=%.0f ghosts=%d trails=%d" % [
			_elapsed, Phase.keys()[_phase], _car.global_position.x,
			_car.global_position.y, _car.velocity.length(), Bank.currency,
			ghosts.size(), _trail_count(),
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
	_lap_target = _laps_done + REDRIVE_LAPS
	_enter(Phase.REDRIVE, "clearing stale lap, then one upgraded lap")


func _buy_gate() -> void:
	_enter(Phase.BUY_GATE, "buying the island gate")
	var gate_ok := Bank.try_buy_gate(GATE_ID)
	print("[PROBE] bought gate=%s money=%.0f" % [gate_ok, Bank.currency])
	_dump_route_log()
	_waypoints = CUT_WAYPOINTS
	_waypoint_index = 0
	_lap_target = _laps_done + CUT_LAPS
	_enter(Phase.DRIVE_CUT, "driving the island cut")


func _dump_route_log() -> void:
	var route_log := get_node_or_null("/root/Main/RouteLog")
	if route_log == null:
		return
	for line: String in route_log.entries_text():
		print("[PROBE] routelog | %s" % line)


func _enter(phase: Phase, note: String) -> void:
	_phase = phase
	print("[PROBE] phase=%s — %s" % [Phase.keys()[phase], note])


func _drive() -> void:
	# Nose-in-wall recovery: back straight up for a moment, then resume.
	if _elapsed < _reverse_until:
		_hold(["brake"])
		return
	if _car.velocity.length() < 40.0:
		_stuck_time += get_process_delta_time()
		if _stuck_time > 2.0:
			_stuck_time = 0.0
			_reverse_until = _elapsed + 1.3
			return
	else:
		_stuck_time = 0.0

	var target := _waypoints[_waypoint_index]
	if _car.global_position.distance_to(target) < WAYPOINT_REACHED_DISTANCE:
		_waypoint_index = (_waypoint_index + 1) % _waypoints.size()
		target = _waypoints[_waypoint_index]

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


func _on_lap_completed(route_id: String, lap_time: float, is_best: bool) -> void:
	_laps_done += 1
	print("[PROBE] LAP %d route=%s completed in %.2fs best=%s" % [
		_laps_done, route_id, lap_time, is_best])


func _hold(wanted: Array[String]) -> void:
	for action in _held.duplicate():
		if action not in wanted:
			Input.action_release(action)
			_held.erase(action)
	for action in wanted:
		if action not in _held:
			Input.action_press(action)
			_held.append(action)


## Drift trail Line2Ds live as siblings of the car; the count rising in
## corners and falling again proves per-stint spawn + fade-out cleanup.
func _trail_count() -> int:
	var container := _car.get_parent()
	if container == null:
		return 0
	var count := 0
	for child in container.get_children():
		if child is Line2D:
			count += 1
	return count


func _release_all() -> void:
	for action in _held:
		Input.action_release(action)
	_held.clear()


func _save_screenshot() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var image := get_viewport().get_texture().get_image()
	if image == null:
		return
	var path := "%s/frame_%02d.png" % [SHOT_DIR, _shot_index]
	image.save_png(path)
	_shot_index += 1
