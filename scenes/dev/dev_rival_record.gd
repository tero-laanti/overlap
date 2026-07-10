extends Node
## Dev-only rival author. Dormant unless user://rivalrecord.flag exists
## (never together with autopilot/calibrate flags). Wipes the profile,
## then per ladder tier: buys that tier's car spec, drives the ring with
## the shared autopilot, slows the stage-best lap by the tier handicap,
## and writes data/rivals/<id>.tres (commit the results). Each rival is
## "the bot at that spec, slightly slower", so a player who reaches the
## spec can beat it. Rerun after any change that shifts car pace.

const FLAG_PATH := "user://rivalrecord.flag"
const OUT_DIR := "res://data/rivals"
const LAPS_PER_STAGE := 4
const TIMEOUT := 600.0
const GRANT := 100000.0

## Handicaps sized so the previous tier's spec ALMOST beats the next
## tier: a clean base-car lap beats AMBER, one Top Speed level beats
## COBALT, the three-upgrade spec beats ONYX.
const STAGES: Array[Dictionary] = [
	{"id": "amber", "name": "AMBER", "upgrades": {},
		"handicap": 1.04,
		"body": Color(1.0, 0.62, 0.18), "stripe": Color(0.28, 0.16, 0.07, 0.9)},
	{"id": "cobalt", "name": "COBALT", "upgrades": {"top_speed": 1},
		"handicap": 1.02,
		"body": Color(0.25, 0.5, 1.0), "stripe": Color(0.08, 0.12, 0.28, 0.9)},
	{"id": "onyx", "name": "ONYX",
		"upgrades": {"top_speed": 2, "acceleration": 2, "grip": 1},
		"handicap": 1.02,
		"body": Color(0.16, 0.16, 0.19), "stripe": Color(0.95, 0.95, 0.98, 0.9)},
]

const DevDriverScript = preload("res://scenes/dev/dev_driver.gd")
const RoutesScript = preload("res://scenes/dev/dev_probe_routes.gd")
const LapRecordingScript = preload("res://scenes/ghost/lap_recording.gd")
const RivalDefScript = preload("res://scenes/ghost/rival_def.gd")

var _driver: DevDriverScript = DevDriverScript.new()
var _stage := 0
var _stage_laps := 0
var _elapsed := 0.0


func _ready() -> void:
	if not (OS.is_debug_build() and FileAccess.file_exists(FLAG_PATH)):
		set_process(false)
		return
	Bank.reset_profile()
	Bank.currency = GRANT
	_driver.car = get_tree().get_first_node_in_group("player_car")
	_driver.set_route(RoutesScript.RING)
	Events.lap_completed.connect(_on_lap_completed)
	_enter_stage(0)


func _process(delta: float) -> void:
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
	print("[RIVAL] stage %s — recording at spec %s" % [stage.id, stage.upgrades])


func _on_lap_completed(route_id: String, lap_time: float, _is_best: bool) -> void:
	if route_id != "ring":
		return
	_stage_laps += 1
	print("[RIVAL] %s lap %d: %.2f" % [STAGES[_stage].id, _stage_laps, lap_time])
	if _stage_laps < LAPS_PER_STAGE:
		return
	# The Bank PB is monotonic and each stage's car is faster, so the
	# current PB at stage end IS the stage best.
	_write_stage(STAGES[_stage], Bank.route_records.get("ring"))
	if _stage + 1 < STAGES.size():
		_enter_stage(_stage + 1)
	else:
		_finish()


func _write_stage(stage: Dictionary, best: LapRecordingScript) -> void:
	if best == null:
		push_error("[RIVAL] no ring recording for stage %s" % stage.id)
		return
	var slowed: LapRecordingScript = best.duplicate()
	slowed.sample_dt = best.sample_dt * float(stage.handicap)
	slowed.lap_time = best.lap_time * float(stage.handicap)
	var rival: RivalDefScript = RivalDefScript.new()
	rival.id = stage.id
	rival.display_name = stage.name
	rival.route_id = "ring"
	rival.recording = slowed
	rival.body_color = stage.body
	rival.stripe_color = stage.stripe
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var path := "%s/%s.tres" % [OUT_DIR, stage.id]
	var err := ResourceSaver.save(rival, path)
	print("[RIVAL] wrote %s lap_time=%.2f err=%d" % [path, slowed.lap_time, err])


func _finish() -> void:
	_driver.release_all()
	set_process(false)
	print("[RIVAL] done")
	if DisplayServer.get_name() == "headless":
		get_tree().quit()
