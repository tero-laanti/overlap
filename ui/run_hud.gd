class_name RunHUD
extends CanvasLayer

const TIMER_URGENCY_THRESHOLD := 10.0
const TIMER_URGENCY_COLOR := Color(1.0, 0.35, 0.3, 1.0)
const ROUND_END_HIDE_DELAY := 0.65

@export var lap_tracker_path: NodePath
@export var run_state_path: NodePath
@export var car_path: NodePath

@onready var content: MarginContainer = $Margin
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
var _timer_default_color: Color
var _hide_timer: Timer = null


func _ready() -> void:
	_lap_tracker = get_node_or_null(lap_tracker_path) as LapTracker
	_run_state = get_node_or_null(run_state_path) as RunState
	_car = get_node_or_null(car_path) as Car
	_timer_default_color = round_time_label.get_theme_color("font_color")
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
	_on_round_time_changed(_run_state.round_time_remaining)
	_on_lap_time_changed(_run_state.current_lap_time)
	_on_last_lap_time_changed(_run_state.last_lap_time)
	_on_multiplier_changed(_run_state.current_multiplier)
	_on_currency_changed(_run_state.currency)
	_update_speed_label()


func _process(_delta: float) -> void:
	if content.visible:
		_update_speed_label()


func _on_lap_changed(current_lap: int) -> void:
	lap_label.text = "Lap %d" % current_lap


func _on_round_time_changed(time_remaining: float) -> void:
	if _run_state and not _run_state.is_round_active and time_remaining <= 0.0:
		round_time_label.text = "Time Up"
		round_time_label.add_theme_color_override("font_color", TIMER_URGENCY_COLOR)
		return

	round_time_label.text = "Time Left %s" % _format_round_time(time_remaining)
	if time_remaining <= TIMER_URGENCY_THRESHOLD:
		round_time_label.add_theme_color_override("font_color", TIMER_URGENCY_COLOR)
	else:
		round_time_label.add_theme_color_override("font_color", _timer_default_color)


func _on_lap_time_changed(current_lap_time: float) -> void:
	lap_time_label.text = "Lap Time %s" % _format_lap_time(current_lap_time)


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
	round_time_label.text = "Time Up"
	round_time_label.add_theme_color_override("font_color", TIMER_URGENCY_COLOR)
	_hide_timer.start(ROUND_END_HIDE_DELAY)


func _on_round_started(_round_number: int) -> void:
	if _hide_timer:
		_hide_timer.stop()

	content.visible = true
	round_time_label.add_theme_color_override("font_color", _timer_default_color)


func _on_hide_timer_timeout() -> void:
	if _run_state and not _run_state.is_round_active:
		content.visible = false


func _show_missing_state() -> void:
	lap_label.text = "Lap --"
	speed_label.text = "Speed --"
	lap_time_label.text = "Lap Time --:--.--"
	last_lap_label.text = "Last --:--.--"
	round_time_label.text = "Time Left --"
	multiplier_label.text = "Multiplier x--"
	currency_label.text = "Cash $--"


func _format_lap_time(seconds: float) -> String:
	var safe_seconds: float = maxf(seconds, 0.0)
	var total_seconds: int = int(safe_seconds)
	var minutes: int = total_seconds / 60
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
	var minutes: int = total_seconds / 60
	var whole_seconds: int = total_seconds % 60
	var tenths: int = int(floor(fmod(safe_seconds, 1.0) * 10.0))
	return "%d:%02d.%01d" % [minutes, whole_seconds, tenths]


func _update_speed_label() -> void:
	if _car == null:
		speed_label.text = "Speed --"
		return

	var planar_velocity: Vector3 = _car.linear_velocity
	planar_velocity.y = 0.0
	speed_label.text = "Speed %d" % int(roundf(planar_velocity.length()))
