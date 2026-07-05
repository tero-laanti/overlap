extends CanvasLayer
## Race HUD. Presentation only: reads RaceState and the car each frame,
## reacts to track/Events signals. No math beyond formatting. Main injects
## references and wires track signals.

const PIP_EMPTY := "○"
const PIP_FULL := "●"
const TOAST_SECONDS := 2.2
const CarScript = preload("res://scenes/car/car.gd")
const RaceStateScript = preload("res://scenes/main/race_state.gd")

var race_state: RaceStateScript
var car: CarScript

var _pips_filled := 0
var _pips_total := 3
var _toast_tween: Tween

@onready var _current_label: Label = %CurrentLap
@onready var _best_label: Label = %BestLap
@onready var _last_label: Label = %LastLap
@onready var _pips_label: Label = %CheckpointPips
@onready var _speed_label: Label = %Speed
@onready var _toast_label: Label = %Toast
@onready var _money_label: Label = %Money
@onready var _income_label: Label = %IncomeRate


func _ready() -> void:
	Events.lap_completed.connect(_on_lap_completed)
	Events.offline_earnings_granted.connect(_on_offline_earnings_granted)
	_toast_label.modulate.a = 0.0
	_refresh_pips()


func _process(_delta: float) -> void:
	if race_state != null:
		_current_label.text = format_time(race_state.current_lap_time)
		_best_label.text = "BEST %s" % format_time(race_state.best_lap_time)
		_last_label.text = "LAST %s" % format_time(race_state.last_lap_time)
	if car != null:
		_speed_label.text = "%d" % int(car.velocity.length() / 10.0)
	_money_label.text = "$ %s" % format_money(Bank.currency)
	_income_label.text = "+%.1f/s" % Bank.income_per_second()


func on_lap_started() -> void:
	_pips_filled = 0
	_refresh_pips()


func on_checkpoint_crossed(index: int, total: int) -> void:
	_pips_total = total
	_pips_filled = index + 1
	_refresh_pips()


func _on_lap_completed(lap_time: float, is_best: bool) -> void:
	_pips_filled = 0
	_refresh_pips()
	_show_toast(
		"NEW BEST  %s" % format_time(lap_time) if is_best
		else "LAP  %s" % format_time(lap_time),
		is_best,
	)


func _on_offline_earnings_granted(amount: float, elapsed_seconds: float) -> void:
	_show_toast(
		"Away %s  +$%s" % [_format_duration(elapsed_seconds), format_money(amount)],
		true,
	)


func _show_toast(message: String, highlight: bool) -> void:
	_toast_label.text = message
	_toast_label.self_modulate = Color(1.0, 0.85, 0.3) if highlight else Color.WHITE
	if _toast_tween:
		_toast_tween.kill()
	_toast_label.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(TOAST_SECONDS)
	_toast_tween.tween_property(_toast_label, "modulate:a", 0.0, 0.5)


func _refresh_pips() -> void:
	var pips := ""
	for i in _pips_total:
		pips += PIP_FULL if i < _pips_filled else PIP_EMPTY
	_pips_label.text = pips


static func format_money(amount: float) -> String:
	if amount >= 1_000_000.0:
		return "%.2fM" % (amount / 1_000_000.0)
	if amount >= 10_000.0:
		return "%.1fk" % (amount / 1_000.0)
	return "%d" % int(amount)


static func format_time(seconds: float) -> String:
	if seconds <= 0.0:
		return "-:--.--"
	return "%d:%05.2f" % [int(seconds / 60.0), fmod(seconds, 60.0)]


static func _format_duration(seconds: float) -> String:
	if seconds >= 3600.0:
		return "%dh %02dm" % [int(seconds / 3600.0), int(fmod(seconds, 3600.0) / 60.0)]
	if seconds >= 60.0:
		return "%dm %02ds" % [int(seconds / 60.0), int(fmod(seconds, 60.0))]
	return "%ds" % int(seconds)
