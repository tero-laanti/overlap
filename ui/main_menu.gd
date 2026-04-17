class_name MainMenu
extends Node3D

const GAME_SCENE_PATH := "res://main.tscn"
## Slow orbit so the map drifts around a fixed frame rather than spinning.
const ORBIT_RADIANS_PER_SECOND := 0.08

@export var track_path: NodePath
@export var camera_path: NodePath
@export var camera_height: float = 90.0
@export var camera_radius: float = 40.0

var _track: TestTrack = null
var _menu_camera: Camera3D = null
var _orbit_focus: Vector3 = Vector3.ZERO
var _orbit_angle: float = 0.0


func _ready() -> void:
	_track = get_node_or_null(track_path) as TestTrack
	_menu_camera = get_node_or_null(camera_path) as Camera3D
	_refresh_orbit_focus()
	_update_camera_pose()


func _process(delta: float) -> void:
	_orbit_angle = wrapf(_orbit_angle + ORBIT_RADIANS_PER_SECOND * delta, 0.0, TAU)
	_update_camera_pose()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if not _is_start_trigger(event):
		return
	get_viewport().set_input_as_handled()
	_start_game()


func _is_start_trigger(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed:
		return true
	if event is InputEventMouseButton and event.pressed:
		return true
	if event is InputEventJoypadButton and event.pressed:
		return true
	return false


func _start_game() -> void:
	get_tree().change_scene_to_file(GAME_SCENE_PATH)


func _refresh_orbit_focus() -> void:
	if _track != null:
		_orbit_focus = _track.get_bounds_center()
	else:
		_orbit_focus = Vector3.ZERO


func _update_camera_pose() -> void:
	if _menu_camera == null:
		return

	var orbit_offset: Vector3 = Vector3(
		camera_radius * cos(_orbit_angle),
		camera_height,
		camera_radius * sin(_orbit_angle)
	)
	_menu_camera.global_position = _orbit_focus + orbit_offset
	_menu_camera.look_at(_orbit_focus, Vector3.UP)
