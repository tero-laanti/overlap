class_name Track
extends Node2D
## Base track script. Owns lap validity: the player must cross every
## checkpoint in order, then the start line, for a lap to count. Crossing
## the start line early (a cut) is silently ignored — the running lap just
## continues. Timing lives in RaceState, not here.

signal lap_started
signal lap_completed
signal checkpoint_crossed(index: int, total: int)

@export var def: TrackDef

var _checkpoints: Array[Area2D] = []
var _next_checkpoint := 0
var _lap_active := false


func _ready() -> void:
	for child in $Checkpoints.get_children():
		var area := child as Area2D
		var index := _checkpoints.size()
		_checkpoints.append(area)
		area.body_entered.connect(_on_checkpoint_entered.bind(index))
	($StartLineArea as Area2D).body_entered.connect(_on_start_line_entered)


func _on_checkpoint_entered(body: Node2D, index: int) -> void:
	if not body.is_in_group("player_car"):
		return
	if index != _next_checkpoint:
		return
	_next_checkpoint += 1
	checkpoint_crossed.emit(index, _checkpoints.size())


func _on_start_line_entered(body: Node2D) -> void:
	if not body.is_in_group("player_car"):
		return
	if _lap_active and _next_checkpoint >= _checkpoints.size():
		lap_completed.emit()
		_next_checkpoint = 0
		lap_started.emit()
	elif not _lap_active:
		_lap_active = true
		_next_checkpoint = 0
		lap_started.emit()
	# Any other crossing is a cut or a reverse — ignored.
