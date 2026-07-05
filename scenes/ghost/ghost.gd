class_name Ghost
extends Node2D
## Replays one LapRecording by interpolation. No physics body, no
## collision, no decisions — CLAUDE.md hard rule 5. playback_offset lets a
## fleet spread clones around the track instead of stacking them.

signal lap_finished

var playback_offset := 0.0

var _recording: LapRecording
var _elapsed := 0.0


func set_recording(recording: LapRecording) -> void:
	_recording = recording
	_elapsed = 0.0
	visible = recording != null


func _process(delta: float) -> void:
	if _recording == null:
		return
	var previous_lap := int((_elapsed + playback_offset) / _recording.lap_time)
	_elapsed += delta
	var current_lap := int((_elapsed + playback_offset) / _recording.lap_time)
	if current_lap > previous_lap:
		lap_finished.emit()
	var xf := _recording.transform_at(_elapsed + playback_offset)
	global_position = xf.origin
	rotation = xf.get_rotation()
