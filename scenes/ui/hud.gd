extends CanvasLayer
## Race HUD. Presentation only: reads RaceState and the car each frame,
## reacts to track/Events signals. No math beyond formatting. Main injects
## references and wires track signals.

const PIP_EMPTY := "○"
const PIP_FULL := "●"
const TOAST_SECONDS := 2.2

var race_state: RaceState
var car: Car

var _pips_filled := 0
var _pips_total := 3
var _toast_tween: Tween

@onready var _current_label: Label = %CurrentLap
@onready var _best_label: Label = %BestLap
@onready var _last_label: Label = %LastLap
@onready var _pips_label: Label = %CheckpointPips
@onready var _speed_label: Label = %Speed
@onready var _toast_label: Label = %Toast


func _ready() -> void:
	Events.lap_completed.connect(_on_lap_completed)
	_toast_label.modulate.a = 0.0
	_refresh_pips()


func _process(_delta: float) -> void:
	if race_state != null:
		_current_label.text = format_time(race_state.current_lap_time)
		_best_label.text = "BEST %s" % format_time(race_state.best_lap_time)
		_last_label.text = "LAST %s" % format_time(race_state.last_lap_time)
	if car != null:
		_speed_label.text = "%d" % int(car.velocity.length() / 10.0)


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


static func format_time(seconds: float) -> String:
	if seconds <= 0.0:
		return "-:--.--"
	return "%d:%05.2f" % [int(seconds / 60.0), fmod(seconds, 60.0)]
