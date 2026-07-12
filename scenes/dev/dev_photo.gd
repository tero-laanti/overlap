extends Node
## Dev-only photo mode. Dormant unless user://photo.flag exists. Flies a
## free camera to authored viewpoints across the island and saves one
## PNG per spot to user://dev/, then quits — the visual-verification
## loop for art passes (macOS headless can't screenshot; this runs
## windowed in seconds). Doesn't touch the profile. A spot with a
## third element `true` also teleports the CAR there (dead stop), so
## car-anchored UI — the per-island minimap — renders that island's
## state; position isn't persisted, so the profile stays untouched.

const FLAG_PATH := "user://photo.flag"
const SHOT_DIR := "user://dev"
## Frames to let rendering settle after each camera jump.
const SETTLE_FRAMES := 8

## name -> [world position, zoom]. Island v2 hub viewpoints; annex
## slices add their own.
const SPOTS := {
	"island": [Vector2(-1150, -900), 0.115],
	"start": [Vector2(500, 1150), 0.5],
	"t1_fork": [Vector2(-2600, 1050), 0.45],
	"riser": [Vector2(-2500, -300), 0.4],
	"top_kink": [Vector2(0, -1400), 0.45],
	"ne_sweep": [Vector2(2100, -1050), 0.45],
	"esses": [Vector2(2150, 0), 0.4],
	"carousel": [Vector2(2450, 950), 0.45],
	"shore_south": [Vector2(0, 2050), 0.5],
	"dune_bowl": [Vector2(-3900, -100), 0.3],
	"dune_merge": [Vector2(-2900, -1000), 0.45],
	"forest_gap": [Vector2(-2830, -1560), 0.55],
	"woods": [Vector2(-1600, -2600), 0.3],
	"archipelago": [Vector2(1400, -200), 0.115],
	"strait_out": [Vector2(3670, -590), 0.4],
	"strait_back": [Vector2(3670, 760), 0.4],
	"port_island": [Vector2(6200, -200), 0.115, true],
	"port_maze": [Vector2(6300, -475), 0.4, true],
	"port_dock": [Vector2(7250, 250), 0.45, true],
	"port_garage": [Vector2(5800, 970), 0.5, true],
}

var _camera: Camera2D


func _ready() -> void:
	if not (OS.is_debug_build() and FileAccess.file_exists(FLAG_PATH)):
		return
	if DisplayServer.get_name() == "headless":
		print("[PHOTO] headless can't capture — run windowed")
		get_tree().quit()
		return
	DirAccess.make_dir_recursive_absolute(SHOT_DIR)
	_camera = Camera2D.new()
	# Physics interpolation forces cameras to physics process anyway;
	# declaring it avoids the engine's override warning.
	_camera.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	add_child(_camera)
	_shoot_all.call_deferred()


func _shoot_all() -> void:
	_camera.make_current()
	var car: Node2D = get_tree().get_first_node_in_group("player_car")
	for spot_name: String in SPOTS:
		var spot: Array = SPOTS[spot_name]
		_camera.global_position = spot[0]
		_camera.zoom = Vector2.ONE * (spot[1] as float)
		if spot.size() > 2 and spot[2] and car != null:
			car.global_position = spot[0]
			car.velocity = Vector2.ZERO
		await _snap(spot_name)
	var menu := get_node_or_null("/root/Main/PauseMenu")
	if menu != null:
		menu.visible = true
		await _snap("menu")
		menu.visible = false
	print("[PHOTO] done")
	get_tree().quit()


func _snap(shot_name: String) -> void:
	for i in SETTLE_FRAMES:
		await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	if image != null:
		var path := "%s/photo_%s.png" % [SHOT_DIR, shot_name]
		image.save_png(path)
		print("[PHOTO] saved %s" % path)
