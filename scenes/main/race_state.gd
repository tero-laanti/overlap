class_name RaceState
extends Node
## Owns lap timing: current lap clock, last and best lap times. Listens to
## Track lap signals (wired by Main) and announces completed laps on the
## Events bus. Zero means "no lap set yet".

var current_lap_time := 0.0
var last_lap_time := 0.0
var best_lap_time := 0.0
var lap_count := 0

var _running := false


func _process(delta: float) -> void:
	if _running:
		current_lap_time += delta


func on_lap_started() -> void:
	_running = true
	current_lap_time = 0.0


func on_lap_completed() -> void:
	last_lap_time = current_lap_time
	var is_best := best_lap_time == 0.0 or last_lap_time < best_lap_time
	if is_best:
		best_lap_time = last_lap_time
	lap_count += 1
	Events.lap_completed.emit(last_lap_time, is_best)
