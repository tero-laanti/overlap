extends Node
## Dev-only rival author. Dormant unless user://rivalrecord.flag exists
## (never together with autopilot/calibrate flags). Wipes the profile,
## opens every gate, then per rival tier: buys that tier's car spec,
## drives its route with the shared autopilot, slows the stage-best lap
## by the tier handicap, and writes data/rivals/<id>.tres (commit the
## results, and keep track02_network.tres's rivals array in sync). Each
## rival is "the bot at that spec, slightly slower", so a player who
## reaches the spec beats it. Rerun after any change that shifts pace.

const FLAG_PATH := "user://rivalrecord.flag"
const OUT_DIR := "res://data/rivals"
const LAPS_PER_STAGE := 4
const TIMEOUT := 1800.0
const GRANT := 1000000.0

## Ring tiers are the onboarding ladder (handicaps sized so the
## previous tier's spec almost beats the next); the rest are zone
## residents at their gate's expected arrival spec.
const STAGES: Array[Dictionary] = [
	{"id": "amber", "name": "AMBER", "route": "ring", "upgrades": {},
		"handicap": 1.04,
		"body": Color(1.0, 0.62, 0.18), "stripe": Color(0.28, 0.16, 0.07, 0.9)},
	{"id": "cobalt", "name": "COBALT", "route": "ring",
		"upgrades": {"top_speed": 1}, "handicap": 1.02,
		"body": Color(0.25, 0.5, 1.0), "stripe": Color(0.08, 0.12, 0.28, 0.9)},
	{"id": "onyx", "name": "ONYX", "route": "ring",
		"upgrades": {"top_speed": 2, "acceleration": 2, "grip": 1},
		"handicap": 1.02, "hires": true,
		"body": Color(0.16, 0.16, 0.19), "stripe": Color(0.95, 0.95, 0.98, 0.9)},
	{"id": "sienna", "name": "SIENNA", "route": "dune", "gate": "west_dunes",
		"upgrades": {"top_speed": 3, "acceleration": 3, "grip": 2},
		"handicap": 1.04,
		"body": Color(0.82, 0.45, 0.2), "stripe": Color(0.35, 0.16, 0.06, 0.9)},
	{"id": "rust", "name": "RUST", "route": "port", "gate": "jump_kit",
		"upgrades": {"top_speed": 3, "acceleration": 3, "grip": 2},
		"handicap": 1.05,
		"body": Color(0.62, 0.26, 0.14), "stripe": Color(0.9, 0.75, 0.3, 0.9)},
]

const DevDriverScript = preload("res://scenes/dev/dev_driver.gd")
const RoutesScript = preload("res://scenes/dev/dev_probe_routes.gd")
const LapRecordingScript = preload("res://scenes/ghost/lap_recording.gd")
const RivalDefScript = preload("res://scenes/ghost/rival_def.gd")

var _driver: DevDriverScript = DevDriverScript.new()
var _stage := 0
var _stage_laps := 0
var _elapsed := 0.0
var _route_points := {}
var _route_reach := {}
var _route_loop_from := {}


func _ready() -> void:
	if not (OS.is_debug_build() and FileAccess.file_exists(FLAG_PATH)):
		set_process(false)
		set_physics_process(false)
		return
	DevDriverScript.apply_dev_time_scale()
	_route_points = {
		"ring": RoutesScript.RING, "dune": RoutesScript.DUNE,
		"port": RoutesScript.PORT,
	}
	_route_reach = {}
	_route_loop_from = {"port": RoutesScript.PORT_LOOP_FROM}
	Bank.reset_profile()
	Bank.currency = GRANT
	_driver.car = get_tree().get_first_node_in_group("player_car")
	Events.lap_completed.connect(_on_lap_completed)
	# Gate prices need the active network, which Bank learns in
	# Main._ready — prep after that.
	_prep.call_deferred()


func _prep() -> void:
	for gate in Bank.unpurchased_gates():
		Bank.try_buy_gate(gate.id)
	Bank.try_buy_jump_kit()
	_enter_stage(0)


## Physics-tick stepping, not _process: the driver must decide at the
## same game-time cadence regardless of Engine.time_scale.
func _physics_process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= TIMEOUT:
		print("[RIVAL] TIMEOUT at stage %d" % _stage)
		_finish()
		return
	_driver.drive(delta)


func _enter_stage(index: int) -> void:
	_stage = index
	_stage_laps = 0
	var stage := STAGES[_stage]
	for id: String in stage.upgrades:
		while Bank.upgrade_level(id) < int(stage.upgrades[id]):
			if not Bank.try_buy_upgrade(id):
				push_error("[RIVAL] cannot buy %s for stage %s" % [id, stage.id])
				break
	_driver.set_route(_route_points[stage.route], float(_route_reach.get(
			stage.route, DevDriverScript.WAYPOINT_REACHED_DISTANCE)),
			int(_route_loop_from.get(stage.route, 0)))
	print("[RIVAL] stage %s — %s at spec %s" % [stage.id, stage.route, stage.upgrades])


func _on_lap_completed(route_id: String, lap_time: float, _is_best: bool) -> void:
	if route_id != String(STAGES[_stage].route):
		return
	_stage_laps += 1
	print("[RIVAL] %s lap %d: %.2f" % [STAGES[_stage].id, _stage_laps, lap_time])
	if _stage_laps < LAPS_PER_STAGE:
		return
	# The Bank PB is monotonic and specs only grow, so the current PB
	# at stage end IS the stage best for that route.
	_write_stage(STAGES[_stage], Bank.route_records.get(route_id))
	if _stage + 1 < STAGES.size():
		_enter_stage(_stage + 1)
	else:
		_finish()


func _write_stage(stage: Dictionary, best: LapRecordingScript) -> void:
	if best == null:
		push_error("[RIVAL] no %s recording for stage %s" % [stage.route, stage.id])
		return
	var slowed: LapRecordingScript = best.duplicate()
	slowed.sample_dt = best.sample_dt * float(stage.handicap)
	slowed.lap_time = best.lap_time * float(stage.handicap)
	var rival: RivalDefScript = RivalDefScript.new()
	rival.id = stage.id
	rival.display_name = stage.name
	rival.route_id = stage.route
	rival.recording = slowed
	rival.body_color = stage.body
	rival.stripe_color = stage.stripe
	rival.required_gate = String(stage.get("gate", ""))
	rival.hires_first_ghost = bool(stage.get("hires", false))
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var path := "%s/%s.tres" % [OUT_DIR, stage.id]
	var err := ResourceSaver.save(rival, path)
	print("[RIVAL] wrote %s lap_time=%.2f err=%d" % [path, slowed.lap_time, err])


func _finish() -> void:
	_driver.release_all()
	set_process(false)
	set_physics_process(false)
	print("[RIVAL] done")
	if DisplayServer.get_name() == "headless":
		get_tree().quit()
