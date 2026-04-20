class_name PauseMenu
extends CanvasLayer

const MAIN_MENU_PATH := "res://ui/main_menu.tscn"
const PAUSE_ACTION := "pause"
const PANEL_BG := Color(0.08, 0.1, 0.14, 0.94)
const PANEL_BORDER := Color(1.0, 0.92, 0.65, 0.3)
const DIM_COLOR := Color(0.0, 0.0, 0.0, 0.55)
const TEXT_COLOR := Color(0.95, 0.97, 1.0, 1.0)
const TITLE_COLOR := Color(1.0, 0.92, 0.65, 1.0)
const PANEL_WIDTH := 480.0
const DEBUG_PANEL_WIDTH := 560.0
const TITLE_FONT_SIZE := 30
const GROUP_FONT_SIZE := 18
const BUTTON_FONT_SIZE := 20
const ROW_FONT_SIZE := 15
const BUTTON_MIN_HEIGHT := 44.0
const PANEL_CORNER_RADIUS := 18
const TUNER_SPINBOX_MIN_WIDTH := 130.0
const SCROLL_HEIGHT_RATIO := 0.55
const SCROLL_HEIGHT_MIN := 320.0
const SCROLL_HEIGHT_MAX := 780.0

# [property_name, min, max, step, display label]
const TUNER_GROUPS := [
	["Speed", [
		["max_speed", 1.0, 200.0, 0.5, "Max speed"],
		["acceleration_force", 1.0, 300.0, 1.0, "Acceleration force"],
		["brake_force", 1.0, 300.0, 1.0, "Brake force"],
		["reverse_max_speed", 0.5, 60.0, 0.5, "Reverse max speed"],
		["reverse_acceleration_factor", 0.1, 1.0, 0.01, "Reverse accel factor"],
	]],
	["Handling", [
		["turn_speed", 0.1, 10.0, 0.1, "Turn speed"],
		["steering_response", 1.0, 80.0, 0.5, "Steering response"],
		["speed_for_full_turn", 0.5, 40.0, 0.5, "Speed for full turn"],
		["grip", 0.1, 40.0, 0.1, "Grip"],
		["air_steering_response", 1.0, 80.0, 0.5, "Air steering response"],
		["air_steer_factor", 0.0, 2.0, 0.05, "Air steer factor"],
	]],
	["Drift", [
		["drift_grip", 0.0, 20.0, 0.05, "Drift grip"],
		["drift_grip_recovery_duration", 0.0, 2.0, 0.05, "Drift grip recovery"],
		["drift_threshold", 0.1, 15.0, 0.1, "Drift entry threshold"],
		["drift_min_speed", 0.0, 40.0, 0.5, "Drift min speed"],
		["drift_turn_multiplier", 0.5, 3.0, 0.05, "Drift turn mult"],
		["drift_boost_force", 0.0, 60.0, 0.5, "Drift boost force"],
	]],
	["Physics", [
		["linear_drag", 0.0, 5.0, 0.05, "Linear drag"],
		["air_drag", 0.0, 1.0, 0.01, "Air drag"],
		["ground_stick_force", 0.0, 40.0, 0.5, "Ground stick force"],
		["uphill_acceleration_bonus", 0.0, 2.0, 0.05, "Uphill accel bonus"],
		["proxy_angular_damp", 0.0, 15.0, 0.1, "Angular damp"],
	]],
]

var _car: Car = null
var _is_open: bool = false
var _showing_debug: bool = false
var _dim: ColorRect = null
var _main_center: CenterContainer = null
var _debug_center: CenterContainer = null
var _tuner_spinboxes: Dictionary[String, SpinBox] = {}
var _tuner_notice_label: Label = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	visible = false
	_build_ui()


func bind_car(car: Car) -> void:
	_car = car
	_sync_tuner_values()
	_update_tuner_notice()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if not event.is_action_pressed(PAUSE_ACTION):
		return

	get_viewport().set_input_as_handled()
	if not _is_open:
		_open()
	elif _showing_debug:
		_show_main_panel()
	else:
		_resume()


func _open() -> void:
	_is_open = true
	_showing_debug = false
	get_tree().paused = true
	_sync_tuner_values()
	_apply_visibility()


func _resume() -> void:
	_is_open = false
	_showing_debug = false
	get_tree().paused = false
	_apply_visibility()


func _show_main_panel() -> void:
	_showing_debug = false
	_apply_visibility()


func _show_debug_panel() -> void:
	_showing_debug = true
	_sync_tuner_values()
	_apply_visibility()


func _exit_to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU_PATH)


func _apply_visibility() -> void:
	visible = _is_open
	if _main_center:
		_main_center.visible = _is_open and not _showing_debug
	if _debug_center:
		_debug_center.visible = _is_open and _showing_debug


func _build_ui() -> void:
	_dim = ColorRect.new()
	_dim.name = "Dim"
	_dim.color = DIM_COLOR
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)

	_main_center = CenterContainer.new()
	_main_center.name = "MainCenter"
	_main_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_main_center.mouse_filter = Control.MOUSE_FILTER_PASS
	_main_center.add_child(_build_main_panel())
	add_child(_main_center)

	_debug_center = CenterContainer.new()
	_debug_center.name = "DebugCenter"
	_debug_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_debug_center.mouse_filter = Control.MOUSE_FILTER_PASS
	_debug_center.visible = false
	_debug_center.add_child(_build_debug_panel())
	add_child(_debug_center)


func _build_main_panel() -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "MainPanel"
	panel.add_theme_stylebox_override("panel", _make_panel_style())
	panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0.0)

	var margin: MarginContainer = _make_margin(22)
	panel.add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	vbox.add_child(_make_label("Paused", TITLE_FONT_SIZE, TITLE_COLOR, HORIZONTAL_ALIGNMENT_CENTER))
	vbox.add_child(HSeparator.new())
	vbox.add_child(_make_menu_button("Continue", _resume))
	vbox.add_child(_make_menu_button("Debug Menu", _show_debug_panel))
	vbox.add_child(_make_menu_button("Exit to Menu", _exit_to_menu))
	return panel


func _build_debug_panel() -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "DebugPanel"
	panel.add_theme_stylebox_override("panel", _make_panel_style())
	panel.custom_minimum_size = Vector2(DEBUG_PANEL_WIDTH, 0.0)

	var margin: MarginContainer = _make_margin(18)
	panel.add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	vbox.add_child(_make_label("Car Tuning", TITLE_FONT_SIZE, TITLE_COLOR, HORIZONTAL_ALIGNMENT_CENTER))
	_tuner_notice_label = _make_label(
		"PhysicsCar-only. SphereCar ignores CarStats — swap vehicle_scene in main.tscn to tune.",
		14,
		Color(1.0, 0.78, 0.4, 1.0),
		HORIZONTAL_ALIGNMENT_CENTER,
	)
	_tuner_notice_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tuner_notice_label.visible = false
	vbox.add_child(_tuner_notice_label)
	vbox.add_child(HSeparator.new())

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0.0, _compute_scroll_height())
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	var tuners_vbox: VBoxContainer = VBoxContainer.new()
	tuners_vbox.add_theme_constant_override("separation", 14)
	tuners_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(tuners_vbox)

	for group in TUNER_GROUPS:
		var group_name: String = group[0]
		var fields: Array = group[1]
		tuners_vbox.add_child(_make_label(group_name, GROUP_FONT_SIZE, TITLE_COLOR, HORIZONTAL_ALIGNMENT_LEFT))

		var grid: GridContainer = GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 14)
		grid.add_theme_constant_override("v_separation", 6)
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tuners_vbox.add_child(grid)

		for field in fields:
			_add_tuner_row(grid, field)

	vbox.add_child(HSeparator.new())

	var buttons_hbox: HBoxContainer = HBoxContainer.new()
	buttons_hbox.alignment = BoxContainer.ALIGNMENT_END
	buttons_hbox.add_theme_constant_override("separation", 10)
	vbox.add_child(buttons_hbox)
	buttons_hbox.add_child(_make_menu_button("Back", _show_main_panel))

	return panel


func _add_tuner_row(grid: GridContainer, field: Array) -> void:
	var prop_name: String = field[0]
	var min_val: float = field[1]
	var max_val: float = field[2]
	var step_val: float = field[3]
	var label_text: String = field[4]

	var name_label: Label = _make_label(label_text, ROW_FONT_SIZE, TEXT_COLOR, HORIZONTAL_ALIGNMENT_LEFT)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(name_label)

	var spin: SpinBox = SpinBox.new()
	spin.min_value = min_val
	spin.max_value = max_val
	spin.step = step_val
	spin.custom_minimum_size = Vector2(TUNER_SPINBOX_MIN_WIDTH, 0.0)
	spin.allow_greater = true
	spin.value_changed.connect(_on_tuner_changed.bind(prop_name))
	grid.add_child(spin)
	_tuner_spinboxes[prop_name] = spin


func _sync_tuner_values() -> void:
	if not is_instance_valid(_car) or _car.stats == null:
		return
	for prop_name in _tuner_spinboxes:
		var spin: SpinBox = _tuner_spinboxes[prop_name]
		if spin == null:
			continue
		var current_value: Variant = _car.stats.get(prop_name)
		if current_value == null:
			continue
		spin.set_block_signals(true)
		spin.value = float(current_value)
		spin.set_block_signals(false)


func _update_tuner_notice() -> void:
	if _tuner_notice_label == null:
		return
	var has_valid_car: bool = is_instance_valid(_car)
	_tuner_notice_label.visible = has_valid_car and not (_car is PhysicsCar)


func _on_tuner_changed(new_value: float, prop_name: String) -> void:
	if not is_instance_valid(_car) or _car.stats == null:
		return
	_car.stats.set(prop_name, new_value)


func _make_panel_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.border_color = PANEL_BORDER
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = PANEL_CORNER_RADIUS
	style.corner_radius_top_right = PANEL_CORNER_RADIUS
	style.corner_radius_bottom_left = PANEL_CORNER_RADIUS
	style.corner_radius_bottom_right = PANEL_CORNER_RADIUS
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
	style.shadow_size = 18
	return style


func _make_margin(amount: int) -> MarginContainer:
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", amount)
	margin.add_theme_constant_override("margin_right", amount)
	margin.add_theme_constant_override("margin_top", amount)
	margin.add_theme_constant_override("margin_bottom", amount)
	return margin


func _make_label(text: String, font_size: int, color: Color, align: HorizontalAlignment) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
	label.add_theme_constant_override("outline_size", 4)
	label.horizontal_alignment = align
	return label


func _make_menu_button(text: String, on_pressed: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", BUTTON_FONT_SIZE)
	button.custom_minimum_size = Vector2(0.0, BUTTON_MIN_HEIGHT)
	button.pressed.connect(on_pressed)
	return button


func _compute_scroll_height() -> float:
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return SCROLL_HEIGHT_MIN
	var viewport_height: float = viewport.get_visible_rect().size.y
	return clampf(viewport_height * SCROLL_HEIGHT_RATIO, SCROLL_HEIGHT_MIN, SCROLL_HEIGHT_MAX)
