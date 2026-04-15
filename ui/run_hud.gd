class_name RunHUD
extends CanvasLayer

const TIMER_URGENCY_THRESHOLD := 10.0
const TIMER_URGENCY_COLOR := Color(1.0, 0.35, 0.3, 1.0)

@export var lap_tracker_path: NodePath
@export var run_state_path: NodePath

@onready var lap_label: Label = $Margin/VBox/LapLabel
@onready var lap_time_label: Label = $Margin/VBox/LapTimeLabel
@onready var last_lap_label: Label = $Margin/VBox/LastLapLabel
@onready var round_time_label: Label = $Margin/VBox/RoundTimeLabel
@onready var multiplier_label: Label = $Margin/VBox/MultiplierLabel
@onready var currency_label: Label = $Margin/VBox/CurrencyLabel

var _lap_tracker: LapTracker = null
var _run_state: RunState = null
var _timer_default_color: Color


func _ready() -> void:
	_lap_tracker = get_node_or_null(lap_tracker_path) as LapTracker
	_run_state = get_node_or_null(run_state_path) as RunState
	_timer_default_color = round_time_label.get_theme_color("font_color")

	if not _lap_tracker:
		push_warning("RunHUD could not find the lap tracker.")
		lap_label.text = "Lap --"
	else:
		if not _lap_tracker.lap_changed.is_connected(_on_lap_changed):
			_lap_tracker.lap_changed.connect(_on_lap_changed)
		_on_lap_changed(_lap_tracker.current_lap)

	if not _run_state:
		push_warning("RunHUD could not find the run state.")
		_show_missing_state()
		set_process(false)
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
	if not _run_state.round_finished.is_connected(_on_round_finished):
		_run_state.round_finished.connect(_on_round_finished)

	_on_round_time_changed(_run_state.round_time_remaining)
	_on_lap_time_changed(_run_state.current_lap_time)
	_on_last_lap_time_changed(_run_state.last_lap_time)
	_on_multiplier_changed(_run_state.current_multiplier)
	_on_currency_changed(_run_state.currency)


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
	lap_time_label.text = "Lap Time %s" % _format_lap_time(current_lap_time, "0:00.00")


func _on_last_lap_time_changed(last_lap_time: float) -> void:
	last_lap_label.text = "Last %s" % _format_lap_time(last_lap_time, "--:--.--")


func _on_multiplier_changed(multiplier: int) -> void:
	multiplier_label.text = "Multiplier x%d" % multiplier


func _on_currency_changed(currency: int) -> void:
	currency_label.text = "Cash $%d" % currency


func _on_round_finished() -> void:
	round_time_label.text = "Time Up"


func _show_missing_state() -> void:
	lap_label.text = "Lap --"
	lap_time_label.text = "Lap Time --:--.--"
	last_lap_label.text = "Last --:--.--"
	round_time_label.text = "Time Left --"
	multiplier_label.text = "Multiplier x--"
	currency_label.text = "Cash $--"


func _format_lap_time(seconds: float, empty_value: String) -> String:
	if seconds <= 0.0:
		return empty_value

	var total_seconds: int = int(seconds)
	var minutes: int = total_seconds / 60
	var whole_seconds: int = total_seconds % 60
	var centiseconds: int = int(roundf(fmod(seconds, 1.0) * 100.0))

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
