extends CanvasLayer
## Race HUD. Presentation only: reads RaceState each frame, does no math
## beyond formatting. Main injects the RaceState reference.

var race_state: RaceState

@onready var _current_label: Label = %CurrentLap
@onready var _best_label: Label = %BestLap
@onready var _last_label: Label = %LastLap


func _process(_delta: float) -> void:
	if race_state == null:
		return
	_current_label.text = "LAP  %s" % format_time(race_state.current_lap_time)
	_best_label.text = "BEST %s" % format_time(race_state.best_lap_time)
	_last_label.text = "LAST %s" % format_time(race_state.last_lap_time)


static func format_time(seconds: float) -> String:
	if seconds <= 0.0:
		return "-:--.--"
	return "%d:%05.2f" % [int(seconds / 60.0), fmod(seconds, 60.0)]
