extends Node
## Dev-only rival author. Dormant unless user://rivalrecord.flag exists
## (never together with autopilot/calibrate flags). Wipes the profile so
## the car is base-spec, drives the ring with the shared autopilot, then
## slows the best lap by RIVAL_HANDICAP and writes it to
## res://data/rivals/ring_rival.tres (commit the result). Rerun after
## any change that shifts base-car pace.

const FLAG_PATH := "user://rivalrecord.flag"
const OUT_PATH := "res://data/rivals/ring_rival.tres"
const LAPS := 4
const TIMEOUT := 240.0
## The rival is the bot's clean base-car line slowed just enough that
## first-session laps beat it within a few tries (probe lap 1 ≈ 15.4s).
const RIVAL_HANDICAP := 1.07

const DevDriverScript = preload("res://scenes/dev/dev_driver.gd")
const RoutesScript = preload("res://scenes/dev/dev_probe_routes.gd")
const LapRecordingScript = preload("res://scenes/ghost/lap_recording.gd")
const RivalDefScript = preload("res://scenes/ghost/rival_def.gd")

var _driver: DevDriverScript = DevDriverScript.new()
var _laps := 0
var _elapsed := 0.0


func _ready() -> void:
	if not (OS.is_debug_build() and FileAccess.file_exists(FLAG_PATH)):
		set_process(false)
		return
	Bank.reset_profile()
	_driver.car = get_tree().get_first_node_in_group("player_car")
	_driver.set_route(RoutesScript.RING)
	Events.lap_completed.connect(_on_lap_completed)
	print("[RIVAL] recording base-car ring laps")


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= TIMEOUT:
		print("[RIVAL] TIMEOUT after %d laps" % _laps)
		_finish()
		return
	_driver.drive(delta)


func _on_lap_completed(route_id: String, lap_time: float, _is_best: bool) -> void:
	if route_id != "ring":
		return
	_laps += 1
	print("[RIVAL] lap %d: %.2f" % [_laps, lap_time])
	if _laps >= LAPS:
		_finish()


func _finish() -> void:
	_driver.release_all()
	set_process(false)
	var best: LapRecordingScript = Bank.route_records.get("ring")
	if best == null:
		push_error("[RIVAL] no ring recording to author from")
	else:
		var slowed: LapRecordingScript = best.duplicate()
		slowed.sample_dt = best.sample_dt * RIVAL_HANDICAP
		slowed.lap_time = best.lap_time * RIVAL_HANDICAP
		var rival: RivalDefScript = RivalDefScript.new()
		rival.id = "ring_rival"
		rival.display_name = "AMBER"
		rival.route_id = "ring"
		rival.recording = slowed
		DirAccess.make_dir_recursive_absolute(OUT_PATH.get_base_dir())
		var err := ResourceSaver.save(rival, OUT_PATH)
		print("[RIVAL] wrote %s lap_time=%.2f err=%d" % [OUT_PATH, slowed.lap_time, err])
	if DisplayServer.get_name() == "headless":
		get_tree().quit()
