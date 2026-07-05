extends Node2D
## Owns the ghost instances on the track. Every ghost replays the single
## best lap — beating your PB upgrades the whole fleet at once. Fleet size
## comes from Bank.ghost_slots; clones are staggered evenly around the lap
## so they spread instead of stacking.

const GHOST_SCENE := preload("res://scenes/ghost/ghost.tscn")
const GhostScript = preload("res://scenes/ghost/ghost.gd")
const LapRecordingScript = preload("res://scenes/ghost/lap_recording.gd")
## Deterministic per-index tint cycles: alpha and hue repeat at different
## periods so neighbouring clones read as distinct, stable individuals.
const TINT_ALPHA_STEPS := 3
const TINT_HUE_STEPS := 5

var _recording: LapRecordingScript


func _ready() -> void:
	Events.best_lap_recorded.connect(_on_best_lap_recorded)
	Events.ghost_hired.connect(func(_count: int) -> void: _sync())


func _on_best_lap_recorded(recording: LapRecordingScript) -> void:
	_recording = recording
	_sync()


func _sync() -> void:
	if _recording == null:
		return
	while get_child_count() < Bank.ghost_slots:
		var ghost: GhostScript = GHOST_SCENE.instantiate()
		ghost.lap_finished.connect(Events.ghost_lap_completed.emit)
		add_child(ghost)
	var count := get_child_count()
	for i in count:
		var ghost: GhostScript = get_child(i)
		ghost.playback_offset = float(i) * _recording.lap_time / count
		ghost.modulate = _fleet_tint(i)
		ghost.set_recording(_recording)


## Stable per-index variation within the cyan-blue family; never drifts
## toward the red player car.
func _fleet_tint(index: int) -> Color:
	var alpha_t := float(index % TINT_ALPHA_STEPS) / float(TINT_ALPHA_STEPS - 1)
	var hue_t := float(index % TINT_HUE_STEPS) / float(TINT_HUE_STEPS - 1)
	return Color(
		1.0,
		lerpf(1.0, 0.72, hue_t),
		1.0,
		lerpf(0.35, 0.5, alpha_t),
	)
