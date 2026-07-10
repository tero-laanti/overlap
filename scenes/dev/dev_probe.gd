extends Node
## Dev-only verification probe. Dormant unless user://autopilot.flag exists
## (created by tooling before a run). Plays the whole game shape with the
## shared waypoint autopilot: the onboarding rival ladder (drive to earn,
## buy the ONYX spec piece by piece, beat AMBER/COBALT/ONYX), the first
## ghost, then every gate in concertina order — driving each annex and
## watching every fleet. Prints telemetry and saves screenshots to
## user://dev/. Never active in release builds. For par calibration use
## user://calibrate.flag (DevCalibrate) instead — not both at once.

enum Phase { LADDER, EARN, REDRIVE, WATCH, GATE_EARN, GATE_DRIVE, GATE_WATCH, DONE }

const FLAG_PATH := "user://autopilot.flag"
const SHOT_DIR := "user://dev"
const TELEMETRY_INTERVAL := 1.0
const SCREENSHOT_INTERVAL := 3.0
const TIMEOUT := 900.0
const REDRIVE_LAPS := 2
const WATCH_SECONDS := 16.0
const SLOT_EARN_TARGET := 30.0  # ghost slot ($25) + slack
const MASTERY_ROUTE_ID := "ring"

## The ladder phase buys these in order as lap earnings allow — ending
## exactly at ONYX's authored spec, which beats ONYX by its handicap.
const LADDER_BUYS: Array[Array] = [
	["top_speed", 1], ["top_speed", 2], ["acceleration", 1],
	["acceleration", 2], ["grip", 1],
]

const CarScript = preload("res://scenes/car/car.gd")
const LapRecordingScript = preload("res://scenes/ghost/lap_recording.gd")
const TrackScript = preload("res://scenes/track/track.gd")
const DevDriverScript = preload("res://scenes/dev/dev_driver.gd")
const RoutesScript = preload("res://scenes/dev/dev_probe_routes.gd")
const ReportScript = preload("res://scenes/dev/dev_probe_report.gd")

var _phase := Phase.LADDER
var _elapsed := 0.0
var _next_telemetry := 0.0
var _next_screenshot := 0.0
var _shot_index := 0
var _car: CarScript
var _driver: DevDriverScript = DevDriverScript.new()
var _laps_done := 0
var _lap_target := 0
var _watch_until := 0.0
var _gate_index := 0
## Concertina order; earn targets are gate price + slack.
var _gates: Array[Dictionary] = []


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
	# Earn targets cover the gate PLUS that zone's arrival spec (the
	# resident rival's authored spec — reaching it beats the resident).
	_gates = [
		{"id": "island_chord", "route": "cut", "points": RoutesScript.CUT,
			"reach": DevDriverScript.WAYPOINT_REACHED_DISTANCE,
			"earn": 130.0, "laps": 2, "watch": 12.0, "buys": []},
		{"id": "west_dunes", "route": "dune", "points": RoutesScript.DUNE,
			"reach": DevDriverScript.WAYPOINT_REACHED_DISTANCE,
			"earn": 630.0, "laps": 2, "watch": 12.0,
			"buys": [["top_speed", 3], ["acceleration", 3], ["grip", 2]]},
		{"id": "cliff_gate", "route": "climb", "points": RoutesScript.CLIMB,
			"reach": RoutesScript.CLIFF_REACH,
			"earn": 1370.0, "laps": 2, "watch": 12.0,
			"buys": [["acceleration", 4], ["grip", 4]]},
		{"id": "harbor_gate", "route": "harbor", "points": RoutesScript.HARBOR,
			"reach": 130.0, "earn": 3100.0, "laps": 2, "watch": 12.0,
			"buys": [["acceleration", 6], ["grip", 5]]},
	]
	_car = get_tree().get_first_node_in_group("player_car")
	_driver.car = _car
	_driver.set_route(RoutesScript.RING)
	_connect_logging()
	print("[PROBE] loaded money=%.0f ring_pb=%.2f slots=%d routes=%d garage=%s" % [
		Bank.currency, Bank.route_pb("ring"), Bank.ghost_slots,
		Bank.discovered_routes.size(), Bank.garage_unlocked,
	])


func _connect_logging() -> void:
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
	Events.garage_unlocked.connect(func() -> void:
		print("[PROBE] garage_unlocked money=%.0f" % Bank.currency))
	Events.rival_race_finished.connect(func(rival_id: String, _n: String,
			player_time: float, rival_time: float, won: bool) -> void:
		print("[PROBE] rival_race id=%s player=%.2f rival=%.2f won=%s" % [
			rival_id, player_time, rival_time, won]))
	Events.rival_beaten.connect(func(rival_id: String) -> void:
		print("[PROBE] rival_beaten id=%s slots=%d mult=x%.0f" % [
			rival_id, Bank.ghost_slots, Bank.rival_multiplier()]))
	Events.ghost_hired.connect(func(count: int) -> void:
		print("[PROBE] ghost_hired slots=%d" % count))
	var track: TrackScript = get_tree().get_first_node_in_group("track")
	if track:
		track.lap_started.connect(func() -> void: print("[PROBE] lap_started"))


func _process(delta: float) -> void:
	_elapsed += delta
	if _car == null:
		return

	match _phase:
		Phase.LADDER:
			_driver.drive(delta)
			if Bank.ghost_slots >= 1:
				_driver.release_all()
				print("[PROBE] ladder done laps=%d money=%.0f mult=x%.0f" % [
					_laps_done, Bank.currency, Bank.rival_multiplier()])
				_enter(Phase.EARN, "idling until $%d" % int(SLOT_EARN_TARGET))
		Phase.EARN:
			if Bank.currency >= SLOT_EARN_TARGET:
				var slot_ok := Bank.try_buy_ghost_slot()
				print("[PROBE] bought ghost_slot=%s money=%.0f slots=%d" % [
					slot_ok, Bank.currency, Bank.ghost_slots])
				_lap_target = _laps_done + REDRIVE_LAPS
				_enter(Phase.REDRIVE, "re-driving the ring with the fleet out")
		Phase.REDRIVE:
			_driver.drive(delta)
			if _laps_done >= _lap_target:
				_driver.release_all()
				_watch_until = _elapsed + WATCH_SECONDS
				_enter(Phase.WATCH, "watching fleet income")
		Phase.WATCH:
			if _elapsed >= _watch_until:
				print("[PROBE] ring done money=%.0f income=%.2f/s slots=%d laps=%d" % [
					Bank.currency, Bank.income_per_second(), Bank.ghost_slots, _laps_done,
				])
				_enter(Phase.GATE_EARN, "idling until $%d" % int(_gates[0].earn))
		Phase.GATE_EARN:
			var gate: Dictionary = _gates[_gate_index]
			if Bank.currency >= float(gate.earn):
				var gate_ok := Bank.try_buy_gate(gate.id)
				print("[PROBE] bought gate %s=%s money=%.0f" % [gate.id, gate_ok, Bank.currency])
				for buy: Array in gate.buys:
					while Bank.upgrade_level(buy[0]) < int(buy[1]) \
							and Bank.try_buy_upgrade(buy[0]):
						pass
					print("[PROBE] spec %s=%d money=%.0f" % [
						buy[0], Bank.upgrade_level(buy[0]), Bank.currency])
				ReportScript.dump_route_log(get_tree())
				_driver.set_route(gate.points, float(gate.reach))
				_lap_target = _laps_done + int(gate.laps)
				_enter(Phase.GATE_DRIVE, "driving %s" % gate.route)
		Phase.GATE_DRIVE:
			_driver.drive(delta)
			# Lap minimum AND the resident beaten — its fleet is the point.
			if _laps_done >= _lap_target \
					and Bank.is_route_fleet_active(_gates[_gate_index].route):
				_driver.release_all()
				_watch_until = _elapsed + float(_gates[_gate_index].watch)
				_enter(Phase.GATE_WATCH, "watching every fleet")
		Phase.GATE_WATCH:
			if _elapsed >= _watch_until:
				var gate: Dictionary = _gates[_gate_index]
				print("[PROBE] %s done money=%.0f income=%.2f/s pb=%.2f" % [
					gate.route, Bank.currency, Bank.income_per_second(),
					Bank.route_pb(gate.route)])
				_gate_index += 1
				if _gate_index < _gates.size():
					_enter(Phase.GATE_EARN,
							"idling until $%d" % int(_gates[_gate_index].earn))
				else:
					_finish()
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


func _finish() -> void:
	var mastery_ok := Bank.try_buy_medal_unlock(MASTERY_ROUTE_ID)
	print("[PROBE] bought mastery_ring=%s money=%.0f" % [mastery_ok, Bank.currency])
	ReportScript.dump_route_log(get_tree())
	print("[PROBE] done t=%.1f money=%.0f income=%.2f/s slots=%d laps=%d routes=%d cut_pb=%.2f dune_pb=%.2f climb_pb=%.2f harbor_pb=%.2f ghosts=%d" % [
		_elapsed, Bank.currency, Bank.income_per_second(),
		Bank.ghost_slots, _laps_done, Bank.discovered_routes.size(),
		Bank.route_pb("cut"), Bank.route_pb("dune"),
		Bank.route_pb("climb"), Bank.route_pb("harbor"),
		get_tree().get_nodes_in_group("ghost").size(),
	])
	_enter(Phase.DONE, "finished")
	set_process(false)
	if DisplayServer.get_name() == "headless":
		get_tree().quit()


func _enter(phase: Phase, note: String) -> void:
	_phase = phase
	print("[PROBE] phase=%s — %s" % [Phase.keys()[phase], note])


func _on_lap_completed(route_id: String, lap_time: float, is_best: bool) -> void:
	_laps_done += 1
	print("[PROBE] LAP %d route=%s completed in %.2fs best=%s" % [
		_laps_done, route_id, lap_time, is_best])
	# During the ladder, spend lap earnings toward the ONYX spec the
	# moment each piece is affordable — the intended player arc.
	if _phase == Phase.LADDER:
		for buy: Array in LADDER_BUYS:
			if Bank.upgrade_level(buy[0]) < int(buy[1]) \
					and Bank.try_buy_upgrade(buy[0]):
				print("[PROBE] bought %s=%d money=%.0f" % [
					buy[0], Bank.upgrade_level(buy[0]), Bank.currency])
