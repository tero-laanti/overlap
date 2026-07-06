extends Node
## Dev-only photo mode. Dormant unless user://photo.flag exists. Flies a
## free camera to authored viewpoints across the island and saves one
## PNG per spot to user://dev/, then quits — the visual-verification
## loop for art passes (macOS headless can't screenshot; this runs
## windowed in seconds). Doesn't touch the profile or move the car.

const FLAG_PATH := "user://photo.flag"
const SHOT_DIR := "user://dev"
## Frames to let rendering settle after each camera jump.
const SETTLE_FRAMES := 8

## name -> [world position, zoom]
const SPOTS := {
	"island": [Vector2(0, -700), 0.115],
	"start": [Vector2(150, 480), 0.55],
	"hub_west": [Vector2(-1050, 0), 0.5],
	"x_crossing": [Vector2(300, -480), 0.55],
	"cliff_gate": [Vector2(1250, -700), 0.55],
	"ladder": [Vector2(1950, -1470), 0.4],
	"lighthouse": [Vector2(2300, -2020), 0.55],
	"esses": [Vector2(1100, -2250), 0.45],
	"descent": [Vector2(280, -1300), 0.45],
	"petal": [Vector2(-1500, 0), 0.45],
	"forest_gap": [Vector2(-660, -800), 0.55],
	"shore_south": [Vector2(0, 1350), 0.5],
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
	add_child(_camera)
	_shoot_all.call_deferred()


func _shoot_all() -> void:
	_camera.make_current()
	for spot_name: String in SPOTS:
		_camera.global_position = SPOTS[spot_name][0]
		_camera.zoom = Vector2.ONE * (SPOTS[spot_name][1] as float)
		for i in SETTLE_FRAMES:
			await get_tree().process_frame
		var image := get_viewport().get_texture().get_image()
		if image != null:
			var path := "%s/photo_%s.png" % [SHOT_DIR, spot_name]
			image.save_png(path)
			print("[PHOTO] saved %s" % path)
	print("[PHOTO] done")
	get_tree().quit()
