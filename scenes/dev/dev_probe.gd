extends Node
## Dev-only verification probe. Dormant unless user://autopilot.flag exists
## (created by tooling before a run). Runs a phased full-loop test with the
## shared waypoint autopilot on the island v2 hub: drive PB laps, idle to
## earn, buy a ghost slot and an upgrade through the real Bank APIs,
## re-drive, watch fleet income, buy the island gate, discover the Island
## Cut, and buy one mastery unlock. Prints telemetry and saves screenshots
## to user://dev/. Never active in release builds. For par calibration use
## user://calibrate.flag (DevCalibrate) instead — not both at once.

enum Phase {
	DRIVE, EARN, SPEND, REDRIVE, WATCH,
	BUY_GATE, DRIVE_CUT, WATCH_CUT,
	EARN_DUNE, BUY_DUNE, DRIVE_DUNE, WATCH_DUNE,
	DONE,
}

const FLAG_PATH := "user://autopilot.flag"
const SHOT_DIR := "user://dev"
const TELEMETRY_INTERVAL := 1.0
const SCREENSHOT_INTERVAL := 3.0
const TIMEOUT := 420.0
const DRIVE_LAPS := 2
const REDRIVE_LAPS := 2
const CUT_LAPS := 2
const DUNE_LAPS := 2
const EARN_TARGET := 110.0  # ghost slot (25) + top speed (75) + slack
const DUNE_EARN_TARGET := 280.0  # Dune Gate (250) + slack
const WATCH_SECONDS := 16.0
const WATCH_CUT_SECONDS := 12.0
const WATCH_DUNE_SECONDS := 12.0
const GATE_ID := "island_chord"
const DUNE_GATE_ID := "west_dunes"
const MASTERY_ROUTE_ID := "ring"

const CarScript = preload("res://scenes/car/car.gd")
const LapRecordingScript = preload("res://scenes/ghost/lap_recording.gd")
const TrackScript = preload("res://scenes/track/track.gd")
const DevDriverScript = preload("res://scenes/dev/dev_driver.gd")
const RoutesScript = preload("res://scenes/dev/dev_probe_routes.gd")
const ReportScript = preload("res://scenes/dev/dev_probe_report.gd")

var _phase := Phase.DRIVE
var _elapsed := 0.0
var _next_telemetry := 0.0
var _next_screenshot := 0.0
var _shot_index := 0
var _car: CarScript
var _driver: DevDriverScript = DevDriverScript.new()
var _laps_done := 0
var _lap_target := 0
var _watch_until := 0.0


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
	_driver.car = _car
	_driver.set_route(RoutesScript.RING)
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
	Events.medal_unlocked.connect(func(route_id: String) -> void:
		print("[PROBE] medal_unlocked route=%s money=%.0f" % [route_id, Bank.currency]))
	Events.car_reset_to_road.connect(func() -> void:
		print("[PROBE] splash reset pos=(%.0f, %.0f)" % [
			_car.global_position.x, _car.global_position.y]))
	Events.secret_unlocked.connect(func(secret_id: String) -> void:
		print("[PROBE] secret_unlocked id=%s" % secret_id))
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
			_driver.drive(delta)
			if _laps_done >= DRIVE_LAPS:
				_driver.release_all()
				_enter(Phase.EARN, "idling until $%d" % int(EARN_TARGET))
		Phase.EARN:
			if Bank.currency >= EARN_TARGET:
				_spend()
		Phase.SPEND:
			pass  # transitions inside _spend()
		Phase.REDRIVE:
			_driver.drive(delta)
			if _laps_done >= _lap_target:
				_driver.release_all()
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
			_driver.drive(delta)
			if _laps_done >= _lap_target:
				_driver.release_all()
				_watch_until = _elapsed + WATCH_CUT_SECONDS
				_enter(Phase.WATCH_CUT, "watching both fleets")
		Phase.WATCH_CUT:
			if _elapsed >= _watch_until:
				print("[PROBE] cut done money=%.0f income=%.2f/s cut_pb=%.2f" % [
					Bank.currency, Bank.income_per_second(), Bank.route_pb("cut"),
				])
				_enter(Phase.EARN_DUNE, "idling until $%d" % int(DUNE_EARN_TARGET))
		Phase.EARN_DUNE:
			if Bank.currency >= DUNE_EARN_TARGET:
				_buy_dune_gate()
		Phase.BUY_DUNE:
			pass  # transitions inside _buy_dune_gate()
		Phase.DRIVE_DUNE:
			_driver.drive(delta)
			if _laps_done >= _lap_target:
				_driver.release_all()
				_watch_until = _elapsed + WATCH_DUNE_SECONDS
				_enter(Phase.WATCH_DUNE, "watching every fleet")
		Phase.WATCH_DUNE:
			if _elapsed >= _watch_until:
				var mastery_ok := Bank.try_buy_medal_unlock(MASTERY_ROUTE_ID)
				print("[PROBE] bought mastery_ring=%s money=%.0f" % [mastery_ok, Bank.currency])
				ReportScript.dump_route_log(get_tree())
				print("[PROBE] done t=%.1f money=%.0f income=%.2f/s slots=%d laps=%d routes=%d cut_pb=%.2f dune_pb=%.2f ghosts=%d" % [
					_elapsed, Bank.currency, Bank.income_per_second(),
					Bank.ghost_slots, _laps_done, Bank.discovered_routes.size(),
					Bank.route_pb("cut"), Bank.route_pb("dune"),
					get_tree().get_nodes_in_group("ghost").size(),
				])
				_enter(Phase.DONE, "finished")
				set_process(false)
				if DisplayServer.get_name() == "headless":
					get_tree().quit()
				return
		Phase.DONE:
			return

	if _elapsed >= TIMEOUT and _phase != Phase.DONE:
		_driver.release_all()
		print("[PROBE] TIMEOUT at phase %s money=%.0f" % [Phase.keys()[_phase], Bank.currency])
		set_process(false)
		return

	if _elapsed >= _next_telemetry:
		_next_telemetry += TELEMETRY_INTERVAL
		var ghosts := get_tree().get_nodes_in_group("ghost")
		print("[PROBE] t=%.1f phase=%s pos=(%.0f, %.0f) speed=%.0f money=%.0f ghosts=%d trails=%d" % [
			_elapsed, Phase.keys()[_phase], _car.global_position.x,
			_car.global_position.y, _car.velocity.length(), Bank.currency,
			ghosts.size(), ReportScript.trail_count(_car),
		])

	if _elapsed >= _next_screenshot:
		_next_screenshot += SCREENSHOT_INTERVAL
		_shot_index = ReportScript.save_screenshot(get_viewport(), SHOT_DIR, _shot_index)


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
	ReportScript.dump_route_log(get_tree())
	_driver.set_route(RoutesScript.CUT)
	_lap_target = _laps_done + CUT_LAPS
	_enter(Phase.DRIVE_CUT, "driving the island cut")


func _buy_dune_gate() -> void:
	_enter(Phase.BUY_DUNE, "buying the dune gate")
	var gate_ok := Bank.try_buy_gate(DUNE_GATE_ID)
	print("[PROBE] bought dune_gate=%s money=%.0f" % [gate_ok, Bank.currency])
	ReportScript.dump_route_log(get_tree())
	_driver.set_route(RoutesScript.DUNE)
	_lap_target = _laps_done + DUNE_LAPS
	_enter(Phase.DRIVE_DUNE, "driving the dune bend")


func _enter(phase: Phase, note: String) -> void:
	_phase = phase
	print("[PROBE] phase=%s — %s" % [Phase.keys()[phase], note])


func _on_lap_completed(route_id: String, lap_time: float, is_best: bool) -> void:
	_laps_done += 1
	print("[PROBE] LAP %d route=%s completed in %.2fs best=%s" % [
		_laps_done, route_id, lap_time, is_best])
