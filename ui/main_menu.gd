class_name MainMenu
extends Node3D

const GAME_SCENE_PATH := "res://main.tscn"
## Slow orbit so the map drifts around a fixed frame rather than spinning.
const ORBIT_RADIANS_PER_SECOND := 0.08
const SELECTED_BUTTON_COLOR := Color(1.0, 0.92, 0.65, 1.0)
const SELECTED_BUTTON_BG := Color(0.18, 0.22, 0.32, 1.0)
const SELECTED_BUTTON_BORDER := Color(1.0, 0.92, 0.65, 0.9)

@export var track_path: NodePath
@export var camera_path: NodePath
@export var track_row_path: NodePath
@export var camera_height: float = 90.0
@export var camera_radius: float = 40.0

var _track: TestTrack = null
var _menu_camera: Camera3D = null
var _track_buttons: Array[Button] = []
var _orbit_focus: Vector3 = Vector3.ZERO
var _orbit_angle: float = 0.0


func _ready() -> void:
	_track = get_node_or_null(track_path) as TestTrack
	_menu_camera = get_node_or_null(camera_path) as Camera3D
	_collect_track_buttons()
	_apply_selection(GameSession.selected_track_index)


func _process(delta: float) -> void:
	_orbit_angle = wrapf(_orbit_angle + ORBIT_RADIANS_PER_SECOND * delta, 0.0, TAU)
	_update_camera_pose()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return

	if event is InputEventKey and event.pressed:
		var track_index: int = _track_index_for_key(event.keycode)
		if track_index >= 0:
			get_viewport().set_input_as_handled()
			_apply_selection(track_index)
			return

	if not _is_start_trigger(event):
		return
	get_viewport().set_input_as_handled()
	_start_game()


func _track_index_for_key(keycode: int) -> int:
	match keycode:
		KEY_1, KEY_KP_1:
			return 0
		KEY_2, KEY_KP_2:
			return 1
		KEY_3, KEY_KP_3:
			return 2
		KEY_4, KEY_KP_4:
			return 3
		KEY_5, KEY_KP_5:
			return 4
		_:
			return -1


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


func _collect_track_buttons() -> void:
	var track_row: Node = get_node_or_null(track_row_path)
	if track_row == null:
		return

	for child in track_row.get_children():
		var button: Button = child as Button
		if button == null:
			continue
		_track_buttons.append(button)
		var button_index: int = _track_buttons.size() - 1
		if not button.pressed.is_connected(_on_track_button_pressed):
			button.pressed.connect(_on_track_button_pressed.bind(button_index))


func _on_track_button_pressed(track_index: int) -> void:
	_apply_selection(track_index)


func _apply_selection(track_index: int) -> void:
	var available_count: int = 0
	if _track != null:
		available_count = _track.starter_layouts.size()
	elif not _track_buttons.is_empty():
		available_count = _track_buttons.size()

	var safe_index: int = clampi(track_index, 0, maxi(available_count - 1, 0))
	GameSession.selected_track_index = safe_index

	if _track != null:
		_track.set_starter_layout_index(safe_index)
		_orbit_focus = _track.get_bounds_center()

	_refresh_button_styles(safe_index)
	_update_camera_pose()


func _refresh_button_styles(selected_index: int) -> void:
	for i in range(_track_buttons.size()):
		var button: Button = _track_buttons[i]
		if i == selected_index:
			button.add_theme_stylebox_override("normal", _make_selected_button_style())
			button.add_theme_stylebox_override("hover", _make_selected_button_style())
			button.add_theme_color_override("font_color", SELECTED_BUTTON_COLOR)
		else:
			button.remove_theme_stylebox_override("normal")
			button.remove_theme_stylebox_override("hover")
			button.remove_theme_color_override("font_color")


func _make_selected_button_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = SELECTED_BUTTON_BG
	style.border_color = SELECTED_BUTTON_BORDER
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	return style


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
