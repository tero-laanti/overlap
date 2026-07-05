extends Node2D
## Owns the ghost fleets, one per route that has a PB recording. Every
## ghost in a route's fleet replays that route's best lap — beating a
## route PB upgrades its whole fleet at once. Fleet size comes from
## Bank.ghost_slots (applies to each route); clones are staggered evenly
## around the lap so they spread instead of stacking.

const GHOST_SCENE := preload("res://scenes/ghost/ghost.tscn")
const GhostScript = preload("res://scenes/ghost/ghost.gd")
const LapRecordingScript = preload("res://scenes/ghost/lap_recording.gd")
## Deterministic per-index tint cycles: alpha and hue repeat at different
## periods so neighbouring clones read as distinct, stable individuals.
const TINT_ALPHA_STEPS := 3
const TINT_HUE_STEPS := 5

var _recordings := {}


func _ready() -> void:
	Events.best_lap_recorded.connect(_on_best_lap_recorded)
	Events.ghost_hired.connect(func(_count: int) -> void: _sync_all())


func _on_best_lap_recorded(route_id: String, recording: LapRecordingScript) -> void:
	_recordings[route_id] = recording
	_sync_route(route_id)


func _sync_all() -> void:
	for route_id: String in _recordings:
		_sync_route(route_id)


func _sync_route(route_id: String) -> void:
	var recording: LapRecordingScript = _recordings[route_id]
	var fleet := _fleet_for(route_id)
	while fleet.get_child_count() < Bank.ghost_slots:
		var ghost: GhostScript = GHOST_SCENE.instantiate()
		ghost.lap_finished.connect(func() -> void:
			Events.ghost_lap_completed.emit(route_id))
		fleet.add_child(ghost)
	var count := fleet.get_child_count()
	for i in count:
		var ghost: GhostScript = fleet.get_child(i)
		ghost.playback_offset = float(i) * recording.lap_time / count
		ghost.modulate = _fleet_tint(i)
		ghost.set_recording(recording)


func _fleet_for(route_id: String) -> Node2D:
	var fleet: Node2D = get_node_or_null(NodePath(route_id))
	if fleet == null:
		fleet = Node2D.new()
		fleet.name = route_id
		add_child(fleet)
	return fleet


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
