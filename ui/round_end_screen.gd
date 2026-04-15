class_name RoundEndScreen
extends CanvasLayer

signal buy_time_requested
signal continue_requested

@export var run_state_path: NodePath
@export var lap_tracker_path: NodePath

@onready var stats_label: Label = $Center/Panel/Margin/VBox/StatsLabel
@onready var next_round_label: Label = $Center/Panel/Margin/VBox/NextRoundLabel
@onready var buy_time_button: Button = $Center/Panel/Margin/VBox/BuyTimeButton

var _run_state: RunState = null
var _lap_tracker: LapTracker = null
var _buy_time_cost: int = 0
var _buy_time_seconds: float = 0.0
var _pending_start_time_bonus: float = 0.0


func _ready() -> void:
	visible = false
	_run_state = get_node_or_null(run_state_path) as RunState
	_lap_tracker = get_node_or_null(lap_tracker_path) as LapTracker

	if not _run_state:
		push_warning("RoundEndScreen could not find the run state.")
	else:
		if not _run_state.round_finished.is_connected(_on_round_finished):
			_run_state.round_finished.connect(_on_round_finished)
		if not _run_state.round_started.is_connected(_on_round_started):
			_run_state.round_started.connect(_on_round_started)
		if not _run_state.currency_changed.is_connected(_on_currency_changed):
			_run_state.currency_changed.connect(_on_currency_changed)

	if not _lap_tracker:
		push_warning("RoundEndScreen could not find the lap tracker.")

	if not buy_time_button.pressed.is_connected(_on_buy_time_button_pressed):
		buy_time_button.pressed.connect(_on_buy_time_button_pressed)

	_refresh_display()


func configure_buy_time_option(cost: int, seconds: float) -> void:
	_buy_time_cost = maxi(cost, 0)
	_buy_time_seconds = maxf(seconds, 0.0)
	_refresh_display()


func set_pending_start_time_bonus(seconds: float) -> void:
	_pending_start_time_bonus = maxf(seconds, 0.0)
	_refresh_display()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or event.is_echo():
		return
	if event.is_action_pressed("buy_time"):
		get_viewport().set_input_as_handled()
		buy_time_requested.emit()
	elif event.is_action_pressed("continue_round"):
		get_viewport().set_input_as_handled()
		continue_requested.emit()


func _on_round_finished() -> void:
	visible = true
	_refresh_display()


func _on_round_started(_round_number: int) -> void:
	visible = false


func _on_currency_changed(_currency: int) -> void:
	_refresh_display()


func _on_buy_time_button_pressed() -> void:
	buy_time_requested.emit()


func _refresh_display() -> void:
	if not is_node_ready():
		return

	var completed_laps: int = _lap_tracker.completed_laps if _lap_tracker else 0
	var round_number: int = _run_state.round_number if _run_state else 0
	var multiplier: int = _run_state.current_multiplier if _run_state else 1
	var round_earnings: int = _run_state.round_earnings if _run_state else 0
	var currency: int = _run_state.currency if _run_state else 0
	var next_round_time: float = (
		_run_state.starting_round_time + _pending_start_time_bonus if _run_state else _pending_start_time_bonus
	)

	stats_label.text = "Round %d\nLaps %d\nEnding Multiplier x%d\nRound Cash $%d\nTotal Cash $%d" % [
		round_number,
		completed_laps,
		multiplier,
		round_earnings,
		currency,
	]
	next_round_label.text = "Next Round Starts With %s" % _format_round_time(next_round_time)
	if _pending_start_time_bonus > 0.0:
		next_round_label.text += " (%s bonus)" % _format_bonus_seconds(_pending_start_time_bonus)

	buy_time_button.text = "[B] Buy +%s Next Round ($%d)" % [
		_format_bonus_seconds(_buy_time_seconds),
		_buy_time_cost,
	]
	buy_time_button.disabled = (
		_run_state == null
		or _buy_time_cost <= 0
		or _buy_time_seconds <= 0.0
		or currency < _buy_time_cost
	)


func _format_bonus_seconds(seconds: float) -> String:
	if is_zero_approx(fposmod(seconds, 1.0)):
		return "%ds" % int(seconds)
	return "%.1fs" % seconds


func _format_round_time(seconds: float) -> String:
	var safe_seconds: float = maxf(seconds, 0.0)
	var total_seconds: int = int(safe_seconds)
	var minutes: int = total_seconds / 60
	var whole_seconds: int = total_seconds % 60
	var tenths: int = int(floor(fposmod(safe_seconds, 1.0) * 10.0))
	return "%d:%02d.%01d" % [minutes, whole_seconds, tenths]
