class_name RunHUD
extends CanvasLayer


class SpeedometerGauge:
	extends Control

	const START_ANGLE := deg_to_rad(160.0)
	const END_ANGLE := deg_to_rad(380.0)
	const TRACK_COLOR := Color(0.16, 0.19, 0.25, 1.0)
	const TICK_COLOR := Color(0.43, 0.5, 0.61, 1.0)
	const VALUE_COLOR := Color(0.99, 0.8, 0.38, 1.0)
	const NEEDLE_COLOR := Color(1.0, 0.93, 0.84, 1.0)
	const HUB_COLOR := Color(0.08, 0.1, 0.14, 1.0)
	const GLOW_COLOR := Color(0.99, 0.68, 0.22, 0.22)

	var speed_ratio: float = 0.0


	func update_speed_ratio(value: float) -> void:
		speed_ratio = clampf(value, 0.0, 1.0)
		queue_redraw()


	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			queue_redraw()


	func _draw() -> void:
		var gauge_size: Vector2 = size
		if gauge_size.x <= 0.0 or gauge_size.y <= 0.0:
			return

		var center: Vector2 = Vector2(gauge_size.x * 0.5, gauge_size.y * 0.86)
		var radius: float = minf(gauge_size.x * 0.38, gauge_size.y * 0.78)
		var dial_width: float = maxf(radius * 0.13, 8.0)
		var active_angle: float = lerpf(START_ANGLE, END_ANGLE, speed_ratio)

		draw_arc(center, radius, START_ANGLE, END_ANGLE, 64, TRACK_COLOR, dial_width, true)
		draw_arc(center, radius + 2.0, START_ANGLE, active_angle, 64, GLOW_COLOR, dial_width + 6.0, true)
		draw_arc(center, radius, START_ANGLE, active_angle, 64, VALUE_COLOR, dial_width, true)

		for tick_index in range(7):
			var tick_ratio: float = float(tick_index) / 6.0
			var tick_angle: float = lerpf(START_ANGLE, END_ANGLE, tick_ratio)
			var tick_direction: Vector2 = Vector2.RIGHT.rotated(tick_angle)
			var outer_point: Vector2 = center + tick_direction * (radius + 4.0)
			var inner_radius: float = radius - (radius * (0.18 if tick_index % 3 == 0 else 0.12))
			var inner_point: Vector2 = center + tick_direction * inner_radius
			draw_line(inner_point, outer_point, TICK_COLOR, 3.0, true)

		var needle_direction: Vector2 = Vector2.RIGHT.rotated(active_angle)
		var needle_end: Vector2 = center + needle_direction * (radius - dial_width * 0.9)
		draw_line(center, needle_end, NEEDLE_COLOR, 4.0, true)
		draw_circle(center, radius * 0.16, HUB_COLOR)
		draw_circle(center, radius * 0.08, VALUE_COLOR)


const TIMER_URGENCY_THRESHOLD := 10.0
const ROUND_END_HIDE_DELAY := 0.65
const SPEEDOMETER_FALLBACK_MAX_SPEED := 30.0

const HUD_MARGIN := 22
const PANEL_PADDING := 16
const PANEL_CORNER_RADIUS := 18
const PANEL_SHADOW_SIZE := 18

const HUD_CARD_BG := Color(0.07, 0.09, 0.13, 0.84)
const HUD_CARD_ALT_BG := Color(0.09, 0.11, 0.16, 0.9)
const HUD_CARD_BORDER := Color(0.48, 0.58, 0.7, 0.52)
const TIMER_CARD_BG := Color(0.13, 0.1, 0.08, 0.92)
const TIMER_CARD_BORDER := Color(1.0, 0.84, 0.58, 0.78)
const TIMER_URGENCY_BG := Color(0.19, 0.08, 0.08, 0.94)
const TIMER_URGENCY_BORDER := Color(1.0, 0.44, 0.34, 0.9)
const TRACK_PROGRESS_BG := Color(0.13, 0.16, 0.2, 1.0)
const TRACK_PROGRESS_FILL := Color(0.96, 0.77, 0.38, 1.0)

const PRIMARY_TEXT_COLOR := Color(0.96, 0.97, 1.0, 1.0)
const DETAIL_TEXT_COLOR := Color(0.84, 0.9, 0.97, 1.0)
const SUBTLE_TEXT_COLOR := Color(0.68, 0.77, 0.87, 1.0)
const ACCENT_TEXT_COLOR := Color(1.0, 0.89, 0.68, 1.0)
const TIMER_DEFAULT_COLOR := Color(1.0, 0.95, 0.8, 1.0)
const TIMER_URGENCY_COLOR := Color(1.0, 0.42, 0.32, 1.0)
const CASH_TEXT_COLOR := Color(0.89, 1.0, 0.82, 1.0)

@export var lap_tracker_path: NodePath
@export var run_state_path: NodePath
@export var car_path: NodePath

@onready var content: MarginContainer = $Margin
@onready var root_layout: VBoxContainer = $Margin/VBox
@onready var lap_label: Label = $Margin/VBox/LapLabel
@onready var speed_label: Label = $Margin/VBox/SpeedLabel
@onready var lap_time_label: Label = $Margin/VBox/LapTimeLabel
@onready var last_lap_label: Label = $Margin/VBox/LastLapLabel
@onready var round_time_label: Label = $Margin/VBox/RoundTimeLabel
@onready var multiplier_label: Label = $Margin/VBox/MultiplierLabel
@onready var currency_label: Label = $Margin/VBox/CurrencyLabel

var _lap_tracker: LapTracker = null
var _run_state: RunState = null
var _car: Car = null
var _hide_timer: Timer = null

var _top_bar: HBoxContainer = null
var _bottom_bar: HBoxContainer = null
var _left_column: VBoxContainer = null
var _status_panel: PanelContainer = null
var _timer_panel: PanelContainer = null
var _telemetry_panel: PanelContainer = null
var _phase_label: Label = null
var _round_label: Label = null
var _timer_caption_label: Label = null
var _lap_progress_label: Label = null
var _lap_progress_bar: ProgressBar = null
var _speedometer_gauge: SpeedometerGauge = null


func _ready() -> void:
	_build_layout()
	_lap_tracker = get_node_or_null(lap_tracker_path) as LapTracker
	_run_state = get_node_or_null(run_state_path) as RunState
	_car = get_node_or_null(car_path) as Car
	_hide_timer = Timer.new()
	_hide_timer.one_shot = true
	add_child(_hide_timer)
	if not _hide_timer.timeout.is_connected(_on_hide_timer_timeout):
		_hide_timer.timeout.connect(_on_hide_timer_timeout)

	if not _lap_tracker:
		push_warning("RunHUD could not find the lap tracker.")
		lap_label.text = "Lap --"
	else:
		if not _lap_tracker.lap_changed.is_connected(_on_lap_changed):
			_lap_tracker.lap_changed.connect(_on_lap_changed)
		_on_lap_changed(_lap_tracker.current_lap)

	if not _car:
		push_warning("RunHUD could not find the car.")

	if not _run_state:
		push_warning("RunHUD could not find the run state.")
		_show_missing_state()
		return

	if not _run_state.round_time_changed.is_connected(_on_round_time_changed):
		_run_state.round_time_changed.connect(_on_round_time_changed)
	if not _run_state.lap_time_changed.is_connected(_on_lap_time_changed):
		_run_state.lap_time_changed.connect(_on_lap_time_changed)
	if not _run_state.last_lap_time_changed.is_connected(_on_last_lap_time_changed):
		_run_state.last_lap_time_changed.connect(_on_last_lap_time_changed)
	if not _run_state.multiplier_changed.is_connected(_on_multiplier_changed):
		_run_state.multiplier_changed.connect(_on_multiplier_changed)
	if not _run_state.currency_changed.is_connected(_on_currency_changed):
		_run_state.currency_changed.connect(_on_currency_changed)
	if not _run_state.round_started.is_connected(_on_round_started):
		_run_state.round_started.connect(_on_round_started)
	if not _run_state.round_finished.is_connected(_on_round_finished):
		_run_state.round_finished.connect(_on_round_finished)

	content.visible = _run_state.is_round_active
	_update_round_label()
	_on_round_time_changed(_run_state.round_time_remaining)
	_on_lap_time_changed(_run_state.current_lap_time)
	_on_last_lap_time_changed(_run_state.last_lap_time)
	_on_multiplier_changed(_run_state.current_multiplier)
	_on_currency_changed(_run_state.currency)
	_update_lap_progress()
	_update_speedometer()


func _process(_delta: float) -> void:
	if not content.visible:
		return

	_update_speedometer()
	_update_lap_progress()


## Lets `Main` rebind the HUD when the vehicle scene is swapped at round
## start. Without this, `_car` stays pinned to the freed pre-swap instance.
func set_car(car: Car) -> void:
	_car = car


func _on_lap_changed(current_lap: int) -> void:
	lap_label.text = "Lap %d" % current_lap


func _on_round_time_changed(time_remaining: float) -> void:
	if _run_state and not _run_state.is_round_active and time_remaining <= 0.0:
		if _timer_caption_label:
			_timer_caption_label.text = "Round Over"
		round_time_label.text = "Time Up"
		_apply_timer_visual_state(true)
		return

	if _timer_caption_label:
		_timer_caption_label.text = "Time Left"
	round_time_label.text = _format_round_time(time_remaining)
	_apply_timer_visual_state(time_remaining <= TIMER_URGENCY_THRESHOLD)


func _on_lap_time_changed(current_lap_time: float) -> void:
	lap_time_label.text = "Current %s" % _format_lap_time(current_lap_time)


func _on_last_lap_time_changed(last_lap_time: float) -> void:
	var last_lap_text: String = "--:--.--"
	if last_lap_time > 0.0:
		last_lap_text = _format_lap_time(last_lap_time)
	last_lap_label.text = "Last %s" % last_lap_text


func _on_multiplier_changed(multiplier: int) -> void:
	multiplier_label.text = "Multiplier x%d" % multiplier


func _on_currency_changed(currency: int) -> void:
	currency_label.text = "Cash $%d" % currency


func _on_round_finished() -> void:
	content.visible = true
	if _timer_caption_label:
		_timer_caption_label.text = "Round Over"
	round_time_label.text = "Time Up"
	_apply_timer_visual_state(true)
	_hide_timer.start(ROUND_END_HIDE_DELAY)


func _on_round_started(round_number: int) -> void:
	if _hide_timer:
		_hide_timer.stop()

	content.visible = true
	_update_round_label(round_number)
	if _timer_caption_label:
		_timer_caption_label.text = "Time Left"
	_apply_timer_visual_state(false)


func _on_hide_timer_timeout() -> void:
	if _run_state and not _run_state.is_round_active:
		content.visible = false


func _show_missing_state() -> void:
	_update_round_label()
	lap_label.text = "Lap --"
	lap_time_label.text = "Current --:--.--"
	last_lap_label.text = "Last --:--.--"
	round_time_label.text = "--:--.-"
	multiplier_label.text = "Multiplier x--"
	currency_label.text = "Cash $--"
	if _lap_progress_label:
		_lap_progress_label.text = "Track --%"
	if _lap_progress_bar:
		_lap_progress_bar.value = 0.0
	if _speedometer_gauge:
		_speedometer_gauge.update_speed_ratio(0.0)


func _build_layout() -> void:
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 0.0
	content.offset_top = 0.0
	content.offset_right = 0.0
	content.offset_bottom = 0.0
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("margin_left", HUD_MARGIN)
	content.add_theme_constant_override("margin_top", HUD_MARGIN)
	content.add_theme_constant_override("margin_right", HUD_MARGIN)
	content.add_theme_constant_override("margin_bottom", HUD_MARGIN)

	root_layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_layout.add_theme_constant_override("separation", 16)

	if _top_bar != null:
		return

	_top_bar = HBoxContainer.new()
	_top_bar.name = "TopBar"
	_top_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top_bar.alignment = BoxContainer.ALIGNMENT_BEGIN
	_top_bar.add_theme_constant_override("separation", 16)
	root_layout.add_child(_top_bar)

	_left_column = VBoxContainer.new()
	_left_column.name = "LeftColumn"
	_left_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_left_column.add_theme_constant_override("separation", 14)
	_top_bar.add_child(_left_column)

	var top_spacer: Control = Control.new()
	top_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_top_bar.add_child(top_spacer)

	_timer_panel = _create_panel(TIMER_CARD_BG, TIMER_CARD_BORDER)
	_timer_panel.custom_minimum_size = Vector2(300.0, 0.0)
	_left_column.add_child(_timer_panel)
	var timer_box: VBoxContainer = _create_panel_box(_timer_panel, 4)
	_timer_caption_label = _make_label("Time Left", 14, ACCENT_TEXT_COLOR, HORIZONTAL_ALIGNMENT_CENTER)
	timer_box.add_child(_timer_caption_label)
	_move_control(round_time_label, timer_box)
	_style_label(round_time_label, 42, TIMER_DEFAULT_COLOR, true)

	_status_panel = _create_panel(HUD_CARD_BG, HUD_CARD_BORDER)
	_status_panel.custom_minimum_size = Vector2(300.0, 0.0)
	_left_column.add_child(_status_panel)
	var status_box: VBoxContainer = _create_panel_box(_status_panel, 10)
	_phase_label = _make_label("Drive Phase", 14, ACCENT_TEXT_COLOR, HORIZONTAL_ALIGNMENT_LEFT)
	status_box.add_child(_phase_label)
	_move_control(lap_label, status_box)
	_style_label(lap_label, 34, PRIMARY_TEXT_COLOR, false)
	_lap_progress_label = _make_label("Track 0%", 14, SUBTLE_TEXT_COLOR, HORIZONTAL_ALIGNMENT_LEFT)
	status_box.add_child(_lap_progress_label)
	_lap_progress_bar = ProgressBar.new()
	_lap_progress_bar.name = "LapProgressBar"
	_lap_progress_bar.show_percentage = false
	_lap_progress_bar.max_value = 100.0
	_lap_progress_bar.custom_minimum_size = Vector2(0.0, 12.0)
	_lap_progress_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lap_progress_bar.add_theme_stylebox_override("background", _create_progress_style(TRACK_PROGRESS_BG))
	_lap_progress_bar.add_theme_stylebox_override("fill", _create_progress_style(TRACK_PROGRESS_FILL))
	status_box.add_child(_lap_progress_bar)
	_move_control(lap_time_label, status_box)
	_style_label(lap_time_label, 18, DETAIL_TEXT_COLOR, false)
	_move_control(last_lap_label, status_box)
	_style_label(last_lap_label, 18, SUBTLE_TEXT_COLOR, false)

	var view_spacer: Control = Control.new()
	view_spacer.name = "ViewSpacer"
	view_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_layout.add_child(view_spacer)

	_bottom_bar = HBoxContainer.new()
	_bottom_bar.name = "BottomBar"
	_bottom_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bottom_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bottom_bar.add_theme_constant_override("separation", 16)
	root_layout.add_child(_bottom_bar)

	var bottom_spacer: Control = Control.new()
	bottom_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bottom_bar.add_child(bottom_spacer)

	_telemetry_panel = _create_panel(HUD_CARD_ALT_BG, HUD_CARD_BORDER)
	_telemetry_panel.custom_minimum_size = Vector2(220.0, 0.0)
	_bottom_bar.add_child(_telemetry_panel)
	var telemetry_box: VBoxContainer = _create_panel_box(_telemetry_panel, 10)
	_round_label = _make_label("Round --", 14, ACCENT_TEXT_COLOR, HORIZONTAL_ALIGNMENT_CENTER)
	telemetry_box.add_child(_round_label)
	_move_control(multiplier_label, telemetry_box)
	_style_label(multiplier_label, 24, Color(0.83, 0.93, 1.0, 1.0), true)
	_speedometer_gauge = SpeedometerGauge.new()
	_speedometer_gauge.name = "SpeedometerGauge"
	_speedometer_gauge.custom_minimum_size = Vector2(0.0, 110.0)
	_speedometer_gauge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_speedometer_gauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	telemetry_box.add_child(_speedometer_gauge)
	_move_control(currency_label, telemetry_box)
	_style_label(currency_label, 22, CASH_TEXT_COLOR, true)
	_move_control(speed_label, telemetry_box)
	speed_label.visible = false


func _create_panel(background_color: Color, border_color: Color) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	panel.add_theme_stylebox_override("panel", _create_panel_style(background_color, border_color))
	return panel


func _create_panel_box(panel: PanelContainer, separation: int) -> VBoxContainer:
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", PANEL_PADDING)
	margin.add_theme_constant_override("margin_top", PANEL_PADDING)
	margin.add_theme_constant_override("margin_right", PANEL_PADDING)
	margin.add_theme_constant_override("margin_bottom", PANEL_PADDING)
	panel.add_child(margin)

	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", separation)
	margin.add_child(box)
	return box


func _create_panel_style(background_color: Color, border_color: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = background_color
	style.corner_radius_top_left = PANEL_CORNER_RADIUS
	style.corner_radius_top_right = PANEL_CORNER_RADIUS
	style.corner_radius_bottom_right = PANEL_CORNER_RADIUS
	style.corner_radius_bottom_left = PANEL_CORNER_RADIUS
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = border_color
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.28)
	style.shadow_size = PANEL_SHADOW_SIZE
	return style


func _create_progress_style(color: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6
	return style


func _make_label(text_value: String, font_size: int, color: Color, alignment: HorizontalAlignment) -> Label:
	var label: Label = Label.new()
	label.text = text_value
	label.horizontal_alignment = alignment
	_style_label(label, font_size, color, false)
	return label


func _style_label(label: Label, font_size: int, color: Color, centered: bool) -> void:
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", 0)
	if centered:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _move_control(control: Control, new_parent: Node) -> void:
	var old_parent: Node = control.get_parent()
	if old_parent == new_parent:
		return
	if old_parent != null:
		old_parent.remove_child(control)
	new_parent.add_child(control)


func _update_round_label(round_number: int = -1) -> void:
	if _round_label == null:
		return

	var display_round: int = round_number
	if display_round < 0 and _run_state != null:
		display_round = maxi(_run_state.round_number, 1)

	if display_round < 0:
		_round_label.text = "Round --"
	else:
		_round_label.text = "Round %d" % display_round


func _update_lap_progress() -> void:
	if _lap_progress_label == null or _lap_progress_bar == null:
		return
	if _lap_tracker == null:
		_lap_progress_label.text = "Track --%"
		_lap_progress_bar.value = 0.0
		return

	var progress_ratio: float = clampf(_lap_tracker.current_progress, 0.0, 1.0)
	_lap_progress_bar.value = progress_ratio * 100.0
	_lap_progress_label.text = "Track %d%%" % int(roundf(progress_ratio * 100.0))


func _apply_timer_visual_state(is_urgent: bool) -> void:
	if _timer_panel == null or _timer_caption_label == null:
		return

	var panel_background: Color = TIMER_CARD_BG
	var panel_border: Color = TIMER_CARD_BORDER
	var timer_color: Color = TIMER_DEFAULT_COLOR
	if is_urgent:
		panel_background = TIMER_URGENCY_BG
		panel_border = TIMER_URGENCY_BORDER
		timer_color = TIMER_URGENCY_COLOR

	_timer_panel.add_theme_stylebox_override("panel", _create_panel_style(panel_background, panel_border))
	_timer_caption_label.add_theme_color_override("font_color", timer_color)
	round_time_label.add_theme_color_override("font_color", timer_color)


func _format_lap_time(seconds: float) -> String:
	var safe_seconds: float = maxf(seconds, 0.0)
	var total_seconds: int = int(safe_seconds)
	var minutes: int = int(total_seconds / 60.0)
	var whole_seconds: int = total_seconds % 60
	var centiseconds: int = int(roundf(fposmod(safe_seconds, 1.0) * 100.0))

	if centiseconds >= 100:
		centiseconds = 0
		whole_seconds += 1
	if whole_seconds >= 60:
		whole_seconds -= 60
		minutes += 1

	return "%d:%02d.%02d" % [minutes, whole_seconds, centiseconds]


func _format_round_time(seconds: float) -> String:
	var safe_seconds: float = maxf(seconds, 0.0)
	var total_seconds: int = int(safe_seconds)
	var minutes: int = int(total_seconds / 60.0)
	var whole_seconds: int = total_seconds % 60
	var tenths: int = int(floor(fmod(safe_seconds, 1.0) * 10.0))
	return "%d:%02d.%01d" % [minutes, whole_seconds, tenths]


func _update_speedometer() -> void:
	if _speedometer_gauge == null:
		return
	if _car == null:
		_speedometer_gauge.update_speed_ratio(0.0)
		return

	var planar_velocity: Vector3 = _car.linear_velocity
	planar_velocity.y = 0.0
	var speed: float = planar_velocity.length()
	var max_display_speed: float = SPEEDOMETER_FALLBACK_MAX_SPEED
	if _car.stats:
		max_display_speed = maxf(_car.stats.max_speed * 1.2, 1.0)

	_speedometer_gauge.update_speed_ratio(speed / max_display_speed)
