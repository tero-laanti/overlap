extends Node
## Dev-only verification probe. Dormant unless user://autopilot.flag exists
## (created by tooling before a run). When active it drives the car through a
## scripted lap segment via simulated input, prints telemetry, and saves
## periodic screenshots to user://dev/ so an agent can verify behavior
## without a human at the wheel. Never active in release builds.

const FLAG_PATH := "user://autopilot.flag"
const SHOT_DIR := "user://dev"
const TELEMETRY_INTERVAL := 0.5
const SCREENSHOT_INTERVAL := 1.5
const DONE_AT := 14.0

## Each step: [end_time, actions_held]
const SCRIPT: Array = [
	[1.4, ["accelerate"]],
	[2.0, ["accelerate", "steer_right"]],
	[3.3, ["accelerate"]],
	[3.9, ["accelerate", "steer_right"]],
	[6.1, ["accelerate"]],
	[6.7, ["accelerate", "steer_right", "drift"]],
	[8.0, ["accelerate"]],
	[8.6, ["accelerate", "steer_right"]],
	[DONE_AT, ["accelerate"]],
]

var _active := false
var _elapsed := 0.0
var _next_telemetry := 0.0
var _next_screenshot := 0.0
var _shot_index := 0
var _held: Array[String] = []
var _car: Car


func _ready() -> void:
	_active = OS.is_debug_build() and FileAccess.file_exists(FLAG_PATH)
	if not _active:
		set_process(false)
		return
	DirAccess.make_dir_recursive_absolute(SHOT_DIR)
	_car = get_tree().get_first_node_in_group("player_car")
	print("[PROBE] active, car=%s" % [_car])


func _process(delta: float) -> void:
	_elapsed += delta
	if _car == null:
		return

	_apply_script()

	if _elapsed >= _next_telemetry:
		_next_telemetry += TELEMETRY_INTERVAL
		print("[PROBE] t=%.1f pos=(%.0f, %.0f) speed=%.0f rot_deg=%.0f" % [
			_elapsed, _car.global_position.x, _car.global_position.y,
			_car.velocity.length(), rad_to_deg(_car.rotation),
		])

	if _elapsed >= _next_screenshot:
		_next_screenshot += SCREENSHOT_INTERVAL
		_save_screenshot()

	if _elapsed >= DONE_AT:
		_release_all()
		print("[PROBE] done")
		set_process(false)


func _apply_script() -> void:
	var wanted: Array = []
	for step: Array in SCRIPT:
		if _elapsed < float(step[0]):
			wanted = step[1]
			break
	for action in _held.duplicate():
		if action not in wanted:
			Input.action_release(action)
			_held.erase(action)
	for action: String in wanted:
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
