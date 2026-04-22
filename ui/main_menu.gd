class_name MainMenu
extends Node3D

const GAME_SCENE_PATH := "res://main.tscn"
const CAR_PICKER_SCENE_PATH := "res://ui/car_picker.tscn"
## Slow orbit so the map drifts around a fixed frame rather than spinning.
const ORBIT_RADIANS_PER_SECOND := 0.08
const SELECTED_BUTTON_COLOR := Color(1.0, 0.92, 0.65, 1.0)
const SELECTED_BUTTON_BG := Color(0.18, 0.22, 0.32, 1.0)
const SELECTED_BUTTON_BORDER := Color(1.0, 0.92, 0.65, 0.9)
## Input actions that select the matching track index.
const TRACK_SELECT_ACTIONS: Array[StringName] = [
	&"menu_track_1",
	&"menu_track_2",
	&"menu_track_3",
	&"menu_track_4",
	&"menu_track_5",
]
## Key events whose standalone press shouldn't start the game (Shift tap, Caps
## Lock, etc.). Gameplay-adjacent UI, so a targeted keycode filter is simpler
## than adding a per-modifier InputMap action.
const START_TRIGGER_IGNORED_KEYCODES: Array[int] = [
	KEY_SHIFT,
	KEY_CTRL,
	KEY_META,
	KEY_ALT,
	KEY_CAPSLOCK,
	KEY_NUMLOCK,
	KEY_SCROLLLOCK,
]

@export var track_path: NodePath
@export var camera_path: NodePath
@export var track_row_path: NodePath
@export var mute_button_path: NodePath
@export var choose_car_button_path: NodePath
@export var car_selection_label_path: NodePath
@export var camera_height: float = 90.0
@export var camera_radius: float = 40.0

var _track: TestTrack = null
var _menu_camera: Camera3D = null
var _mute_button: Button = null
var _choose_car_button: Button = null
var _car_selection_label: Label = null
var _track_buttons: Array[Button] = []
var _orbit_focus: Vector3 = Vector3.ZERO
var _orbit_angle: float = 0.0
var _buttons_collected: bool = false


func _ready() -> void:
	_track = get_node_or_null(track_path) as TestTrack
	_menu_camera = get_node_or_null(camera_path) as Camera3D
	if _menu_camera != null:
		# Orbit pose is written from `_process`. Opt out of physics
		# interpolation so the engine does not double-interpolate it and so
		# the write does not trigger the "interpolated node modified outside
		# physics process" warning.
		_menu_camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_mute_button = get_node_or_null(mute_button_path) as Button
	_choose_car_button = get_node_or_null(choose_car_button_path) as Button
	_car_selection_label = get_node_or_null(car_selection_label_path) as Label
	_collect_track_buttons()
	_warn_about_track_option_drift()
	_apply_selection(GameSession.selected_track_index)
	_setup_mute_button()
	_setup_choose_car_button()
	_refresh_car_selection_label()


func _process(delta: float) -> void:
	_orbit_angle = wrapf(_orbit_angle + ORBIT_RADIANS_PER_SECOND * delta, 0.0, TAU)
	_update_camera_pose()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return

	var track_index: int = _track_index_for_event(event)
	if track_index >= 0:
		get_viewport().set_input_as_handled()
		_apply_selection(track_index)
		return

	if not _is_start_trigger(event):
		return
	get_viewport().set_input_as_handled()
	_start_game()


func _track_index_for_event(event: InputEvent) -> int:
	for action_index in range(TRACK_SELECT_ACTIONS.size()):
		if event.is_action_pressed(TRACK_SELECT_ACTIONS[action_index]):
			return action_index
	return -1


func _is_start_trigger(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed:
		return not START_TRIGGER_IGNORED_KEYCODES.has(event.keycode)
	if event is InputEventMouseButton and event.pressed:
		return true
	if event is InputEventJoypadButton and event.pressed:
		return true
	return false


func _start_game() -> void:
	get_tree().change_scene_to_file(GAME_SCENE_PATH)


func _collect_track_buttons() -> void:
	if _buttons_collected:
		return

	var track_row: Node = get_node_or_null(track_row_path)
	if track_row == null:
		return

	_track_buttons.clear()
	for child in track_row.get_children():
		var button: Button = child as Button
		if button == null:
			continue
		var button_index: int = _track_buttons.size()
		_track_buttons.append(button)
		button.pressed.connect(_apply_selection.bind(button_index))
	_buttons_collected = true


func _warn_about_track_option_drift() -> void:
	if _track != null and not _track_buttons.is_empty() and _track.starter_layouts.size() != _track_buttons.size():
		push_warning(
			"MainMenu has %d track buttons but Track exposes %d starter layouts." % [
				_track_buttons.size(),
				_track.starter_layouts.size(),
			]
		)
	if not _track_buttons.is_empty() and _track_buttons.size() != TRACK_SELECT_ACTIONS.size():
		push_warning(
			"MainMenu has %d track buttons but %d menu_track actions." % [
				_track_buttons.size(),
				TRACK_SELECT_ACTIONS.size(),
			]
		)


## The layouts array on the menu's Track and on main.tscn's Track should stay
## in sync; clamping here keeps button rows authored with extra entries from
## writing an out-of-range index into GameSession.
func _apply_selection(track_index: int) -> void:
	var available_count: int = 0
	if _track != null and not _track_buttons.is_empty():
		available_count = mini(_track.starter_layouts.size(), _track_buttons.size())
	elif _track != null:
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


func _setup_mute_button() -> void:
	if _mute_button == null:
		return
	if not _mute_button.pressed.is_connected(_on_mute_button_pressed):
		_mute_button.pressed.connect(_on_mute_button_pressed)
	_refresh_mute_button_label()


func _setup_choose_car_button() -> void:
	if _choose_car_button == null:
		return
	if not _choose_car_button.pressed.is_connected(_on_choose_car_pressed):
		_choose_car_button.pressed.connect(_on_choose_car_pressed)


func _on_choose_car_pressed() -> void:
	get_tree().change_scene_to_file(CAR_PICKER_SCENE_PATH)


func _refresh_car_selection_label() -> void:
	if _car_selection_label == null:
		return
	var option: CarOption = CarOptions.get_option(GameSession.selected_car_index)
	var name_text: String = option.display_name if option != null else "Unknown"
	_car_selection_label.text = "Currently: %s" % name_text


func _on_mute_button_pressed() -> void:
	GameSession.toggle_audio_muted()
	_refresh_mute_button_label()


func _refresh_mute_button_label() -> void:
	if _mute_button == null:
		return
	_mute_button.text = "Sound Off" if GameSession.is_audio_muted else "Sound On"


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
